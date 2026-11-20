//
//  SpeaksFirstPlan.swift
//  Windfall
//
//  The rules for Eira speaking first (piece 5 of doc 119, its first
//  part): a frost warning when a garden's forecast drops below 1 °C,
//  and, from April to September, a note on a day good enough for a FIT
//  count. Fixed rules and fixed wording. No model is asked anything.
//
//  This file only decides WHAT to say and WHEN. It touches neither the
//  network nor the notification system, so the logic tests can hand it
//  a made-up forecast and a made-up clock and check every answer.
//  The fetching and the handing over to the system are in
//  SpeaksFirst.swift.
//
//  ⚠️ CHECK: every number below is Claude's choice (20 November 2026,
//  doc 142), not William's. The FIT count's own weather rules (13 °C in
//  sun, 15 °C otherwise, dry, not windy) are the ones the app already
//  uses during a count (`SkyCondition.minimumTemperatureC`,
//  `CurrentConditions.isWindy` in WeatherService.swift).
//

import Foundation

/// One day of the forecast for one garden.
struct SpeakForecastDay: Equatable {
    /// The day, written "2026-11-21".
    var dayKey: String
    /// The lowest the air is forecast to reach that day, in °C. The
    /// coldest hour is usually just before dawn, so this is the night
    /// before the day as much as the day itself.
    var minC: Double?
    var maxC: Double?
    var rainMM: Double?
    /// The strongest steady wind of the day (not a gust), in km/h.
    var windMaxKMH: Double?
    var sunshineHours: Double?
}

/// A garden's forecast, a few days ahead.
struct SpeakGardenForecast: Equatable {
    var gardenName: String
    var days: [SpeakForecastDay]
}

/// A notification ready to be handed to the system. `id` names it, so
/// the next plan can take its place rather than add a second.
struct SpeakNotice: Equatable {
    var id: String
    var title: String
    var body: String
    var fireAt: Date
}

enum SpeaksFirstPlan {

    // MARK: The numbers (⚠️ CHECK, all Claude's)

    /// Every notice Windfall plans here starts with this, so that they
    /// can be found and replaced without touching any other reminder.
    static let idPrefix = "windfall.speaks."
    static let frostPrefix = idPrefix + "frost."
    static let fitPrefix = idPrefix + "fit."

    /// A forecast low below this is worth a warning. William asked for
    /// 1 °C: a forecast for the air at two metres, and grass and low
    /// plants can be a degree or two colder (a ground frost).
    static let frostBelowC = 1.0
    /// How many nights ahead to warn about. A forecast further out
    /// changes too often to be worth a notice that may never be
    /// replaced if Windfall is not opened again.
    static let frostNightsAhead = 3
    /// The warning comes at 4 in the afternoon the day before, while
    /// there is light left to cover things.
    static let frostHour = 16
    /// After this hour a warning that is late is not sent at all.
    static let lateHour = 22

    /// The FIT count season, April to September (UK PoMS).
    static let fitMonths = 4...9
    /// The note comes at half past nine, before the counting hours.
    static let fitHour = 9
    static let fitMinute = 30
    /// Today and this many days after it are looked at.
    static let fitDaysAhead = 2
    /// A note for today that has missed half past nine is sent at once,
    /// but not after one o'clock: by then the day is half gone.
    static let fitLatestHour = 13
    /// Dry enough: no more rain than this in the whole day.
    static let fitDryMM = 0.5
    /// Still enough: the strongest steady wind no more than this. The
    /// same 20 km/h (about Beaufort 4) as `CurrentConditions.isWindy`.
    static let fitWindKMH = 20.0
    /// With this much sun forecast the day counts as sunny, and 13 °C is
    /// warm enough. Otherwise 15 °C is needed.
    static let sunnyHours = 5.0

    // MARK: Frost

    /// The frost warnings to plan, one for each night ahead with a garden
    /// forecast below `frostBelowC`. A warning names every garden that
    /// is forecast that cold, coldest first.
    static func frostNotices(_ gardens: [SpeakGardenForecast], now: Date,
                             calendar: Calendar = .current) -> [SpeakNotice] {
        var notices: [SpeakNotice] = []
        let today = calendar.startOfDay(for: now)
        // Day 1 is tomorrow: the night just ending this morning has
        // already happened.
        for ahead in 1...frostNightsAhead {
            guard let frostDay = calendar.date(byAdding: .day, value: ahead, to: today),
                  let dayBefore = calendar.date(byAdding: .day, value: ahead - 1, to: today) else { continue }
            let key = WeatherDiary.dayKey(for: frostDay, calendar: calendar)
            // Every garden forecast too cold that night, coldest first.
            let cold: [(name: String, low: Double)] = gardens.compactMap { forecast in
                guard let day = forecast.days.first(where: { $0.dayKey == key }),
                      let low = day.minC, low < frostBelowC else { return nil }
                return (forecast.gardenName, low)
            }.sorted { $0.low < $1.low }
            guard let coldest = cold.first else { continue }
            guard let fireAt = when(on: dayBefore, hour: frostHour, minute: 0,
                                    latestHour: lateHour, now: now, calendar: calendar) else { continue }

            let places = cold.map { "\(degrees($0.low)) at \($0.name)" }
            let morning = weekday(frostDay, calendar: calendar)
            let title = coldest.low <= 0 ? "Frost tonight" : "Near frost tonight"
            let body = "Forecast low by \(morning) morning: \(listed(places)). Cover or bring in anything tender."
            notices.append(SpeakNotice(id: frostPrefix + key, title: title, body: body, fireAt: fireAt))
        }
        return notices
    }

    // MARK: A good day for a FIT count

    /// Whether a day's forecast suits a FIT count: dry, not windy, and
    /// warm enough for the sky forecast. Nil (no) when a figure is
    /// missing, since a guess is worse than silence.
    static func suitsFITCount(_ day: SpeakForecastDay) -> Bool {
        guard let high = day.maxC, let rain = day.rainMM, let wind = day.windMaxKMH else { return false }
        let sunny = (day.sunshineHours ?? 0) >= sunnyHours
        let warmEnough = high >= (sunny ? 13 : 15)
        return rain <= fitDryMM && wind <= fitWindKMH && warmEnough
    }

    /// At most one note: the first day, from today on, in the season,
    /// with no FIT count already made that day, when at least one garden
    /// suits a count. Only one, so that a fine spell does not mean a
    /// note every morning; the next is planned the next time Windfall is
    /// opened.
    ///
    /// - `countedOn`: the days (as keys) a FIT count has been made.
    static func fitNotices(_ gardens: [SpeakGardenForecast], countedOn: Set<String>, now: Date,
                           calendar: Calendar = .current) -> [SpeakNotice] {
        let today = calendar.startOfDay(for: now)
        for ahead in 0...fitDaysAhead {
            guard let day = calendar.date(byAdding: .day, value: ahead, to: today),
                  fitMonths.contains(calendar.component(.month, from: day)) else { continue }
            let key = WeatherDiary.dayKey(for: day, calendar: calendar)
            guard !countedOn.contains(key) else { continue }
            // The gardens that suit, warmest first.
            let good: [(name: String, high: Double)] = gardens.compactMap { forecast in
                guard let day = forecast.days.first(where: { $0.dayKey == key }),
                      suitsFITCount(day), let high = day.maxC else { return nil }
                return (forecast.gardenName, high)
            }.sorted { $0.high > $1.high }
            guard let warmest = good.first,
                  let fireAt = when(on: day, hour: fitHour, minute: fitMinute,
                                    latestHour: fitLatestHour, now: now, calendar: calendar) else { continue }
            let places = listed(good.map(\.name))
            let body = "Dry, light winds and up to \(degrees(warmest.high)) at \(places): warm enough for a FIT count. Ten minutes watching one patch of flowers."
            return [SpeakNotice(id: fitPrefix + key, title: "A good day for a FIT count",
                                body: body, fireAt: fireAt)]
        }
        return []
    }

    // MARK: Small pieces

    /// The moment a notice should come: the hour asked for on that day;
    /// or, if that has passed, a minute from now, provided it is still
    /// before `latestHour` on that same day. Nil if it is too late.
    static func when(on day: Date, hour: Int, minute: Int, latestHour: Int,
                     now: Date, calendar: Calendar) -> Date? {
        guard let planned = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
              let latest = calendar.date(bySettingHour: latestHour, minute: 0, second: 0, of: day) else { return nil }
        if planned > now { return planned }
        let soon = now.addingTimeInterval(60)
        return soon < latest ? soon : nil
    }

    /// "−2 °C", "0 °C", "18 °C": whole degrees, with a true minus sign.
    static func degrees(_ value: Double) -> String {
        let whole = Int(value.rounded())
        return whole < 0 ? "\u{2212}\(-whole) °C" : "\(whole) °C"
    }

    /// "a", "a and b", "a, b and c". No comma before "and".
    static func listed(_ items: [String]) -> String {
        guard items.count > 1 else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " and " + (items.last ?? "")
    }

    /// "Saturday", in English whatever the device's language.
    static func weekday(_ date: Date, calendar: Calendar) -> String {
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return names[(calendar.component(.weekday, from: date) - 1) % 7]
    }

    // MARK: The forecast

    /// The web address for a garden's forecast: today and the next three
    /// days, a day at a time. One small request a garden, at most once an
    /// hour (`SpeaksFirst.restSeconds`).
    static func forecastURL(latitude: Double, longitude: Double, timeZone: TimeZone = .current) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            // About a hundred metres, as everywhere else in Windfall.
            URLQueryItem(name: "latitude", value: String(format: "%.3f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.3f", longitude)),
            URLQueryItem(name: "daily", value: "temperature_2m_min,temperature_2m_max,precipitation_sum,wind_speed_10m_max,sunshine_duration"),
            URLQueryItem(name: "forecast_days", value: String(frostNightsAhead + 1)),
            URLQueryItem(name: "timezone", value: timeZone.identifier)
        ]
        return components?.url
    }

    private struct Reply: Decodable {
        struct Daily: Decodable {
            let time: [String]
            let temperature_2m_min: [Double?]?
            let temperature_2m_max: [Double?]?
            let precipitation_sum: [Double?]?
            let wind_speed_10m_max: [Double?]?
            let sunshine_duration: [Double?]?
        }
        let daily: Daily?
    }

    /// Reads the weather service's reply. Nil if it is not a forecast.
    static func forecastDays(from data: Data) -> [SpeakForecastDay]? {
        guard let daily = (try? JSONDecoder().decode(Reply.self, from: data))?.daily else { return nil }
        func value(_ figures: [Double?]?, _ index: Int) -> Double? {
            guard let figures, figures.indices.contains(index) else { return nil }
            return figures[index]
        }
        return daily.time.enumerated().map { index, key in
            SpeakForecastDay(dayKey: key,
                             minC: value(daily.temperature_2m_min, index),
                             maxC: value(daily.temperature_2m_max, index),
                             rainMM: value(daily.precipitation_sum, index),
                             windMaxKMH: value(daily.wind_speed_10m_max, index),
                             // The service gives sunshine in seconds.
                             sunshineHours: value(daily.sunshine_duration, index).map { $0 / 3600 })
        }
    }
}
