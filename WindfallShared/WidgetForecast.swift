//
//  WidgetForecast.swift
//  WindfallShared
//
//  Lets a widget fetch the forecast for itself.
//
//  Why. A widget reads the summary file the app writes (see
//  WidgetSummary.swift). Until 14 November 2026 the forecast in that file
//  was only ever put there by the app, so "Frost and weather" showed
//  whatever the forecast had been the last time Windfall was opened, and
//  nothing at all if it had been more than a week.
//
//  Now the file also holds the place the app asks the weather about,
//  rounded to about a hundred metres. Each time iOS or macOS asks a
//  widget for its cards, the widget looks at how old the forecast is. If
//  it is more than three hours old it fetches a new one from the same
//  service the app uses, Open-Meteo, and writes it into the file.
//
//  What a widget does not do. It never finds the device's location
//  itself, and it does not work out the frost and wind jobs for "This
//  week", which need the records. Those jobs are still written by the
//  app. So the app has to have been opened once, with the weather
//  fetched, before a widget can keep itself up to date.
//
//  `nonisolated` says each piece may be used from any thread: a widget
//  does this work away from the main thread.
//

import Foundation
#if canImport(FoundationNetworking)
// Only for checking this file on a computer that is not Apple's.
import FoundationNetworking
#endif

/// Where the app asks the weather about, as kept in the widgets' file.
nonisolated struct WidgetPlace: Codable, Equatable {
    /// Rounded to three decimal places, about a hundred metres: exactly
    /// what is sent to the weather service, and no more.
    var latitude: Double
    var longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = (latitude * 1000).rounded() / 1000
        self.longitude = (longitude * 1000).rounded() / 1000
    }
}

nonisolated enum WidgetForecast {

    /// A forecast older than this is fetched again: three hours.
    static let goodFor: TimeInterval = 3 * 3600
    /// After a failed fetch, how long before trying again: an hour. The
    /// system allows a widget only so many refreshes a day, so a device
    /// with no signal should not spend them all on trying.
    static let retryAfter: TimeInterval = 3600
    /// How many days to ask for: today and the seven after it, the same
    /// as the app.
    static let days = 8

    /// True when a widget should fetch a new forecast: the file names a
    /// place, and the forecast in it is missing or more than three hours
    /// old.
    static func isDue(_ summary: WidgetSummary?, now: Date = .now) -> Bool {
        guard let summary, summary.place != nil else { return false }
        guard let fetched = summary.forecastFetched else { return true }
        // A time in the future means the clock was changed. Fetch again.
        return now.timeIntervalSince(fetched) > goodFor || fetched > now
    }

    /// When the widget should next be asked for its cards: three hours
    /// after the forecast was fetched, or in an hour if there is a place
    /// but no forecast could be had. Nil when there is no place,
    /// which leaves the widget to wait for the app.
    static func nextLook(_ summary: WidgetSummary?, now: Date = .now) -> Date? {
        guard let summary, summary.place != nil else { return nil }
        guard let fetched = summary.forecastFetched, fetched <= now else {
            return now.addingTimeInterval(retryAfter)
        }
        let due = fetched.addingTimeInterval(goodFor)
        return due > now ? due : now.addingTimeInterval(retryAfter)
    }

    /// The web address for a place's forecast.
    static func url(for place: WidgetPlace, timeZone: TimeZone = .current) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.3f", place.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.3f", place.longitude)),
            URLQueryItem(name: "daily", value: "temperature_2m_min,precipitation_sum,wind_gusts_10m_max"),
            URLQueryItem(name: "forecast_days", value: String(days)),
            // Days are counted in the device's own time, not Greenwich's.
            URLQueryItem(name: "timezone", value: timeZone.identifier)
        ]
        return components?.url
    }

    /// The shape of the service's reply. Only the parts used are named.
    private nonisolated struct Reply: Decodable {
        nonisolated struct Daily: Decodable {
            let time: [String]
            let temperature_2m_min: [Double?]?
            let precipitation_sum: [Double?]?
            let wind_gusts_10m_max: [Double?]?
        }
        let daily: Daily?
    }

    /// Turns the service's reply into one entry a day. A reply that
    /// cannot be read, or has no days in it, gives an empty list.
    static func nights(from data: Data) -> [WidgetNight] {
        guard let daily = (try? JSONDecoder().decode(Reply.self, from: data))?.daily else { return [] }
        func value(_ figures: [Double?]?, _ index: Int) -> Double? {
            guard let figures, figures.indices.contains(index) else { return nil }
            return figures[index]
        }
        return daily.time.enumerated().map { index, day in
            WidgetNight(dayKey: day,
                        lowC: value(daily.temperature_2m_min, index),
                        rainMM: value(daily.precipitation_sum, index),
                        gustKMH: value(daily.wind_gusts_10m_max, index))
        }
    }

    /// Puts a new forecast into a summary, and notes when it was fetched.
    /// A forecast with no temperatures in it changes nothing, so a bad
    /// reply can never wipe a good forecast.
    static func adding(_ nights: [WidgetNight], to summary: WidgetSummary, fetched: Date) -> WidgetSummary {
        guard nights.contains(where: { $0.lowC != nil }) else { return summary }
        var changed = summary
        changed.nights = nights
        changed.forecastFetched = fetched
        return changed
    }

    /// Fetches a new forecast if one is due and writes it into the file.
    /// Returns the summary as it now stands, changed or not.
    ///
    /// The file is read again just before it is written, because the app
    /// or another widget may have written it while this one was waiting
    /// for the weather service. Only the forecast is put in. Everything
    /// else in the file is left exactly as it was found.
    static func refreshIfDue(now: Date = .now) async -> WidgetSummary? {
        let summary = WidgetSummaryStore.read()
        guard isDue(summary, now: now), let place = summary?.place, let url = url(for: place) else { return summary }
        var request = URLRequest(url: url)
        // A widget is given only a few seconds to make its cards.
        request.timeoutInterval = 10
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return summary }
        let fresh = nights(from: data)
        guard let latest = WidgetSummaryStore.read() else { return summary }
        // Another widget got there first while this one was waiting.
        guard isDue(latest, now: now) else { return latest }
        let changed = adding(fresh, to: latest, fetched: now)
        if changed != latest { WidgetSummaryStore.write(changed) }
        return changed
    }
}
