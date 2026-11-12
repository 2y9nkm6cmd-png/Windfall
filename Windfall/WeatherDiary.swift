//
//  WeatherDiary.swift
//  Windfall
//
//  A record of every day's weather at each garden: the coldest and
//  warmest it got, rain, wind, sunshine, soil temperature, and the
//  figures hour by hour.
//
//  How it stays complete without anyone doing anything: each time the
//  app opens it looks at which days it already holds, asks the weather
//  service for every day since, and stores them. A fortnight away from
//  the app leaves no gap, because the service keeps the past too.
//
//  The service is Open-Meteo, as for the conditions on Today. It needs
//  no account and no key. Its figures come from weather models run by
//  national weather services, worked out for the garden's spot on the
//  map. They are not readings taken in the garden itself. For that, see
//  the plan for garden sensors in the project notes.
//
//  Nothing in this file draws anything, so it can be tested without a
//  screen. The Weather page is in WeatherDiaryView.swift.
//

import Foundation
import SwiftData

// MARK: - The record

/// One day's weather at one garden.
@Model
final class WeatherDay {

    var id: UUID = UUID()
    /// The day, written "2026-11-12". Text rather than a date, so it can
    /// never slip into the day before or after when clocks change.
    var dayKey: String = ""
    /// Midday on that day, for putting days in order and drawing charts.
    var date: Date = Date.now
    /// Which garden the weather is for (the garden's key).
    var siteRaw: String = ""

    var minTemperatureC: Double?
    var maxTemperatureC: Double?
    var rainfallMM: Double?
    /// The strongest steady wind of the day, in kilometres an hour.
    var windMaxKMH: Double?
    var sunshineHours: Double?
    /// How much water a lawn would have lost to the air, in millimetres.
    /// Set beside the rainfall it says whether the ground is gaining or
    /// losing water.
    var evaporationMM: Double?
    /// The day's average a few centimetres down, where seeds sit.
    var soilTemperatureC: Double?
    /// The weather services' shared code for the kind of day: 0 is a
    /// clear sky, 61 is light rain, and so on. See `WeatherDiary.words`.
    var weatherCode: Int?

    /// The figures hour by hour, packed as JSON. Unpacked by
    /// `WeatherDiary.hours(of:)`.
    var hourlyData: Data?

    /// False for today, whose figures are part forecast. Once a day has
    /// ended it is fetched one last time and marked complete.
    var isComplete: Bool = false
    /// "recent" from the forecast service's memory of the last three
    /// months, or "archive" from the long-term record.
    var sourceRaw: String = "recent"
    var fetchedAt: Date = Date.now

    init() {}

    /// True when the air went to freezing or below.
    var hadFrost: Bool { (minTemperatureC ?? 1) <= 0 }
}

/// A day's figures hour by hour. Each list has 24 entries, midnight
/// first. An entry is nil where the service had no figure.
struct WeatherHours: Codable, Equatable {
    var temperatureC: [Double?] = []
    var rainMM: [Double?] = []
    var cloudPercent: [Double?] = []
    var windKMH: [Double?] = []
    var soilC: [Double?] = []

    /// The conditions at one hour of the day, 0 to 23. This is what lets
    /// the journal say "it was 9°C and raining this morning".
    func conditions(atHour hour: Int) -> CurrentConditions? {
        guard temperatureC.indices.contains(hour), let temperature = temperatureC[hour] else { return nil }
        func value(_ list: [Double?]) -> Double? { list.indices.contains(hour) ? list[hour] : nil }
        return CurrentConditions(temperatureC: temperature,
                                 cloudCoverPercent: value(cloudPercent) ?? 50,
                                 precipitationMM: value(rainMM) ?? 0,
                                 windSpeedKMH: value(windKMH) ?? 0)
    }
}

// MARK: - The sums

enum WeatherDiary {

    /// How far back the service's ordinary address remembers, in days.
    static let recentDays = 92
    /// How long to wait before asking the service again.
    static let restSeconds: TimeInterval = 3600

    // MARK: Days as text

    /// "2026-11-12" for a moment in time, in the given calendar.
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Midday on the day a key names, or nil if the key is not a date.
    static func date(forKey key: String, calendar: Calendar = .current) -> Date? {
        let numbers = key.split(separator: "-").compactMap { Int($0) }
        guard numbers.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: numbers[0], month: numbers[1], day: numbers[2], hour: 12))
    }

    /// How many days from one key to a later one. Nil if either is not a date.
    static func days(from first: String, to second: String, calendar: Calendar = .current) -> Int? {
        guard let start = date(forKey: first, calendar: calendar),
              let end = date(forKey: second, calendar: calendar) else { return nil }
        return calendar.dateComponents([.day], from: start, to: end).day
    }

    // MARK: What to ask for

    /// One question to put to the weather service.
    enum Request: Equatable {
        /// The last so-many days and today, from the ordinary address.
        case recent(pastDays: Int)
        /// A stretch of older days, from the long-term record.
        case archive(start: String, end: String)
    }

    /// Decides what, if anything, to fetch.
    ///
    /// - `complete`: the days already held and finished.
    /// - `today`: today's key.
    ///
    /// With nothing held it asks for the full three months. Otherwise it
    /// asks from the earliest missing day within those three months, which
    /// is usually just yesterday and today.
    static func request(complete: Set<String>, today: String, calendar: Calendar = .current) -> Request {
        guard let todayDate = date(forKey: today, calendar: calendar) else { return .recent(pastDays: 1) }
        var earliestMissing = 0
        for back in 1...recentDays {
            guard let day = calendar.date(byAdding: .day, value: -back, to: todayDate) else { continue }
            if !complete.contains(dayKey(for: day, calendar: calendar)) { earliestMissing = back }
        }
        // Always at least yesterday: it is re-read once after it ends.
        return .recent(pastDays: max(earliestMissing, 1))
    }

    /// How many days behind the long-term record runs.
    static let archiveLagDays = 6

    /// A second question, for days the ordinary address could not supply.
    ///
    /// Found on 12 November 2026: asked for 92 days, the ordinary address
    /// sent figures for only the newest 64 and blanks before that. Those
    /// older days are asked of the long-term record instead. Nil when no
    /// day old enough for that record is missing.
    static func gapRequest(complete: Set<String>, today: String, calendar: Calendar = .current) -> Request? {
        guard let todayDate = date(forKey: today, calendar: calendar) else { return nil }
        var missing: [String] = []
        for back in archiveLagDays...recentDays {
            guard let day = calendar.date(byAdding: .day, value: -back, to: todayDate) else { continue }
            let key = dayKey(for: day, calendar: calendar)
            if !complete.contains(key) { missing.append(key) }
        }
        guard let start = missing.min(), let end = missing.max() else { return nil }
        return .archive(start: start, end: end)
    }

    /// The year before the earliest day held, for "fetch earlier weather".
    /// Nil when nothing is held yet. The long-term record runs about five
    /// days behind, so the newest days always come from `recent`.
    static func earlierRequest(earliest: String?, calendar: Calendar = .current) -> Request? {
        guard let earliest, let first = date(forKey: earliest, calendar: calendar),
              let end = calendar.date(byAdding: .day, value: -1, to: first),
              let start = calendar.date(byAdding: .year, value: -1, to: first) else { return nil }
        return .archive(start: dayKey(for: start, calendar: calendar), end: dayKey(for: end, calendar: calendar))
    }

    /// The web address for a request.
    static func url(for request: Request, latitude: Double, longitude: Double,
                    timeZone: TimeZone = .current) -> URL? {
        let daily = "temperature_2m_min,temperature_2m_max,precipitation_sum,wind_speed_10m_max,sunshine_duration,et0_fao_evapotranspiration,weather_code"
        let hourly = "temperature_2m,precipitation,cloud_cover,wind_speed_10m,"
        var components: URLComponents?
        var items = [
            // Three decimal places is about a hundred metres: plenty for
            // weather, and no more exact than it needs to be.
            URLQueryItem(name: "latitude", value: String(format: "%.3f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.3f", longitude)),
            URLQueryItem(name: "daily", value: daily),
            // Days are counted in the garden's own time, not Greenwich's.
            URLQueryItem(name: "timezone", value: timeZone.identifier)
        ]
        switch request {
        case .recent(let pastDays):
            components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
            items += [URLQueryItem(name: "hourly", value: hourly + "soil_temperature_6cm"),
                      URLQueryItem(name: "past_days", value: String(min(max(pastDays, 1), recentDays))),
                      URLQueryItem(name: "forecast_days", value: "1")]
        case .archive(let start, let end):
            components = URLComponents(string: "https://archive-api.open-meteo.com/v1/archive")
            // The long-term record names its soil layer differently.
            items += [URLQueryItem(name: "hourly", value: hourly + "soil_temperature_0_to_7cm"),
                      URLQueryItem(name: "start_date", value: start),
                      URLQueryItem(name: "end_date", value: end)]
        }
        components?.queryItems = items
        return components?.url
    }

    // MARK: Reading the reply

    /// One day as it comes back from the service, before it is stored.
    struct Reading: Equatable {
        var dayKey: String
        var minTemperatureC: Double?
        var maxTemperatureC: Double?
        var rainfallMM: Double?
        var windMaxKMH: Double?
        var sunshineHours: Double?
        var evaporationMM: Double?
        var soilTemperatureC: Double?
        var weatherCode: Int?
        var hourly = WeatherHours()
    }

    /// The shape of the service's reply. Only the parts used are named.
    private struct Reply: Decodable {
        struct Daily: Decodable {
            let time: [String]
            let temperature_2m_min: [Double?]?
            let temperature_2m_max: [Double?]?
            let precipitation_sum: [Double?]?
            let wind_speed_10m_max: [Double?]?
            let sunshine_duration: [Double?]?
            let et0_fao_evapotranspiration: [Double?]?
            let weather_code: [Double?]?
        }
        struct Hourly: Decodable {
            let time: [String]
            let temperature_2m: [Double?]?
            let precipitation: [Double?]?
            let cloud_cover: [Double?]?
            let wind_speed_10m: [Double?]?
            let soil_temperature_6cm: [Double?]?
            let soil_temperature_0_to_7cm: [Double?]?
        }
        let daily: Daily?
        let hourly: Hourly?
        /// Present when the service refuses: it says why.
        let reason: String?
    }

    struct ReplyError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Turns the service's reply into one reading per day.
    static func readings(from data: Data) throws -> [Reading] {
        let reply = try JSONDecoder().decode(Reply.self, from: data)
        guard let daily = reply.daily else {
            throw ReplyError(message: reply.reason ?? "The weather service sent no daily figures.")
        }

        func value(_ list: [Double?]?, _ index: Int) -> Double? {
            guard let list, list.indices.contains(index) else { return nil }
            return list[index]
        }

        // Sort the hourly figures into days. Each hour's time starts with
        // its day, as in "2026-11-12T09:00".
        var hoursByDay: [String: WeatherHours] = [:]
        if let hourly = reply.hourly {
            let soil = hourly.soil_temperature_6cm ?? hourly.soil_temperature_0_to_7cm
            for (index, time) in hourly.time.enumerated() {
                let day = String(time.prefix(10))
                var dayHours = hoursByDay[day] ?? WeatherHours()
                dayHours.temperatureC.append(value(hourly.temperature_2m, index))
                dayHours.rainMM.append(value(hourly.precipitation, index))
                dayHours.cloudPercent.append(value(hourly.cloud_cover, index))
                dayHours.windKMH.append(value(hourly.wind_speed_10m, index))
                dayHours.soilC.append(value(soil, index))
                hoursByDay[day] = dayHours
            }
        }

        return daily.time.enumerated().map { index, day in
            let dayHours = hoursByDay[day] ?? WeatherHours()
            let soil = dayHours.soilC.compactMap { $0 }
            return Reading(dayKey: day,
                           minTemperatureC: value(daily.temperature_2m_min, index),
                           maxTemperatureC: value(daily.temperature_2m_max, index),
                           rainfallMM: value(daily.precipitation_sum, index),
                           windMaxKMH: value(daily.wind_speed_10m_max, index),
                           // The service counts sunshine in seconds.
                           sunshineHours: value(daily.sunshine_duration, index).map { $0 / 3600 },
                           evaporationMM: value(daily.et0_fao_evapotranspiration, index),
                           soilTemperatureC: soil.isEmpty ? nil : soil.reduce(0, +) / Double(soil.count),
                           weatherCode: value(daily.weather_code, index).map { Int($0) },
                           hourly: dayHours)
        }
    }

    /// A stored day's figures for each hour, midnight first. Nil for a day
    /// stored without any.
    static func hours(of day: WeatherDay) -> WeatherHours? {
        day.hourlyData.flatMap { try? JSONDecoder().decode(WeatherHours.self, from: $0) }
    }

    // MARK: Storing

    /// Stores readings for a garden. A day already held is brought up to
    /// date, never doubled. A day that was complete stays as it was.
    /// Returns how many days were added or changed.
    @discardableResult
    static func store(_ readings: [Reading], site: String, source: String, today: String,
                      into context: ModelContext, calendar: Calendar = .current) -> Int {
        let held = ((try? context.fetch(FetchDescriptor<WeatherDay>())) ?? []).filter { $0.siteRaw == site }
        var byKey: [String: WeatherDay] = [:]
        for day in held { byKey[day.dayKey] = day }

        var changed = 0
        for reading in readings {
            // Days after today are forecast only and are not kept.
            guard reading.dayKey <= today, let date = date(forKey: reading.dayKey, calendar: calendar) else { continue }
            // A day the service has no figures for is left for another
            // time or another source: the ordinary address goes blank
            // after about two months, and the long-term record's newest
            // few days are blank too.
            guard reading.minTemperatureC != nil, reading.maxTemperatureC != nil else { continue }
            // A finished day must have its rain as well, or it would be
            // marked complete with a hole in it.
            if reading.dayKey < today, reading.rainfallMM == nil { continue }

            let day: WeatherDay
            if let existing = byKey[reading.dayKey] {
                if existing.isComplete { continue }
                day = existing
            } else {
                day = WeatherDay()
                day.dayKey = reading.dayKey
                day.siteRaw = site
                context.insert(day)
                byKey[reading.dayKey] = day
            }
            day.date = date
            day.minTemperatureC = reading.minTemperatureC
            day.maxTemperatureC = reading.maxTemperatureC
            day.rainfallMM = reading.rainfallMM
            day.windMaxKMH = reading.windMaxKMH
            day.sunshineHours = reading.sunshineHours
            day.evaporationMM = reading.evaporationMM
            day.soilTemperatureC = reading.soilTemperatureC
            day.weatherCode = reading.weatherCode
            day.hourlyData = try? JSONEncoder().encode(reading.hourly)
            day.isComplete = reading.dayKey < today
            day.sourceRaw = source
            day.fetchedAt = .now
            changed += 1
        }
        return changed
    }

    /// Adds a frost record for each finished day that went to freezing or
    /// below, unless that date already has one. Returns how many it added.
    @discardableResult
    static func recordFrosts(from days: [WeatherDay], into context: ModelContext,
                             calendar: Calendar = .current) -> Int {
        let existing = (try? context.fetch(FetchDescriptor<FrostRecord>())) ?? []
        var known = Set(existing.map { dayKey(for: $0.date, calendar: calendar) })
        var added = 0
        for day in days where day.isComplete && day.hadFrost && !known.contains(day.dayKey) {
            let record = FrostRecord()
            record.date = calendar.startOfDay(for: day.date)
            record.minimumTemperatureC = day.minTemperatureC
            record.siteRaw = day.siteRaw
            record.kind = frostKind(month: calendar.component(.month, from: day.date))
            context.insert(record)
            known.insert(day.dayKey)
            added += 1
        }
        return added
    }

    /// Spring frosts up to the end of May may turn out to be the last of
    /// spring, and autumn ones from September the first of autumn. Deep
    /// winter frosts are just frosts.
    static func frostKind(month: Int) -> FrostKind {
        switch month {
        case 3...5: return .lastSpringFrost
        case 9...11: return .firstAutumnFrost
        default: return .other
        }
    }

    // MARK: Which gardens

    /// A garden to keep weather for.
    struct Place: Equatable {
        var site: String
        var name: String
        var latitude: Double
        var longitude: Double
    }

    /// The gardens that have a location, leaving out any within about a
    /// mile of one already listed: they share the same weather, so one
    /// diary serves both.
    static func places(for gardens: [Garden]) -> [Place] {
        var found: [Place] = []
        for garden in gardens where garden.isActive {
            guard let latitude = garden.latitude, let longitude = garden.longitude else { continue }
            let isNearAnother = found.contains { kilometres(from: $0, latitude: latitude, longitude: longitude) < 1.5 }
            if !isNearAnother {
                found.append(Place(site: garden.siteKey, name: garden.name, latitude: latitude, longitude: longitude))
            }
        }
        return found
    }

    /// Roughly how far a spot is from a place. Good to a few per cent over
    /// short distances, which is all that is needed here.
    static func kilometres(from place: Place, latitude: Double, longitude: Double) -> Double {
        let north = (latitude - place.latitude) * 111.2
        let east = (longitude - place.longitude) * 111.2 * cos(place.latitude * .pi / 180)
        return (north * north + east * east).squareRoot()
    }

    // MARK: Words

    /// The kind of day in a word or two, from the weather services'
    /// shared code.
    static func words(forCode code: Int?) -> String? {
        guard let code else { return nil }
        switch code {
        case 0: return "Clear"
        case 1: return "Mostly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61: return "Light rain"
        case 63: return "Rain"
        case 65: return "Heavy rain"
        case 66, 67: return "Freezing rain"
        case 71, 73, 75, 77: return "Snow"
        case 80, 81, 82: return "Showers"
        case 85, 86: return "Snow showers"
        case 95, 96, 99: return "Thunderstorm"
        default: return nil
        }
    }

    /// Kilometres an hour as miles an hour, which is how wind is spoken
    /// of in Britain.
    static func milesPerHour(_ kilometresPerHour: Double) -> Double { kilometresPerHour / 1.609344 }

    /// A day in a sentence: "Low 2°, high 7°. Dry. 6.6 hours of sun."
    static func summary(of day: WeatherDay) -> String {
        var parts: [String] = []
        if let low = day.minTemperatureC, let high = day.maxTemperatureC {
            parts.append("Low \(degrees(low)), high \(degrees(high))")
        }
        if let rain = day.rainfallMM {
            parts.append(rain < 0.1 ? "Dry" : "\(rain.formatted(.number.precision(.fractionLength(1)))) mm of rain")
        }
        if let sunshine = day.sunshineHours, sunshine >= 0.5 {
            parts.append("\(sunshine.formatted(.number.precision(.fractionLength(1)))) hours of sun")
        }
        return parts.isEmpty ? "No figures" : parts.joined(separator: ". ") + "."
    }

    /// "7°", or "-2°" below zero.
    static func degrees(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        // Avoids "-0°" for a value just below zero.
        return "\(rounded == 0 ? 0 : rounded)°"
    }

    // MARK: Fetching

    /// Fetches a web address. Kept as one small function so the tests can
    /// put a stand-in in its place and never touch the network.
    static func download(_ url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
}

// MARK: - The service

/// Brings the diary up to date. One of these is made when the app opens.
@Observable
@MainActor
final class WeatherDiaryService {

    private(set) var isWorking = false
    private(set) var lastError: String?
    /// What the last run did, in words, for the Weather page.
    private(set) var lastMessage: String?

    private let defaults: UserDefaults
    private let fetch: (URL) async throws -> Data

    init(defaults: UserDefaults = .standard,
         fetch: @escaping (URL) async throws -> Data = WeatherDiary.download) {
        self.defaults = defaults
        self.fetch = fetch
    }

    private func restKey(_ site: String) -> String { "weatherDiaryFetched-\(site)" }

    /// Fills in every missing day for every garden that has a location,
    /// then records any frosts. Safe to call often: it asks the service at
    /// most once an hour for each garden unless `force` is true.
    func bringUpToDate(in context: ModelContext, now: Date = .now, force: Bool = false,
                       calendar: Calendar = .current) async {
        guard !isWorking else { return }
        let gardens = (try? context.fetch(FetchDescriptor<Garden>())) ?? []
        let places = WeatherDiary.places(for: gardens.sorted { $0.displayOrder < $1.displayOrder })
        guard !places.isEmpty else {
            lastMessage = "No garden has a location yet."
            return
        }

        isWorking = true
        lastError = nil
        defer { isWorking = false }

        let today = WeatherDiary.dayKey(for: now, calendar: calendar)
        var added = 0
        for place in places {
            var held = ((try? context.fetch(FetchDescriptor<WeatherDay>())) ?? []).filter { $0.siteRaw == place.site }
            // Rest only if today is already here. A diary that is empty,
            // or was last filled yesterday, is never made to wait.
            let lastAsked = defaults.double(forKey: restKey(place.site))
            let askedLately = lastAsked > 0 && now.timeIntervalSince1970 - lastAsked < WeatherDiary.restSeconds
            if !force, askedLately, held.contains(where: { $0.dayKey == today }) { continue }

            var complete = Set(held.filter(\.isComplete).map(\.dayKey))
            let request = WeatherDiary.request(complete: complete, today: today, calendar: calendar)
            added += await run(request, for: place, today: today, in: context, calendar: calendar)

            // Anything older that the ordinary address left blank is asked
            // of the long-term record.
            if lastError == nil {
                held = ((try? context.fetch(FetchDescriptor<WeatherDay>())) ?? []).filter { $0.siteRaw == place.site }
                complete = Set(held.filter(\.isComplete).map(\.dayKey))
                if let gap = WeatherDiary.gapRequest(complete: complete, today: today, calendar: calendar) {
                    added += await run(gap, for: place, today: today, in: context, calendar: calendar)
                }
            }
            if lastError == nil { defaults.set(now.timeIntervalSince1970, forKey: restKey(place.site)) }
        }

        let days = (try? context.fetch(FetchDescriptor<WeatherDay>())) ?? []
        WeatherDiary.recordFrosts(from: days, into: context, calendar: calendar)
        if lastError == nil {
            lastMessage = added == 0 ? "Up to date." : "\(added) day\(added == 1 ? "" : "s") added or brought up to date."
        }
    }

    /// Fetches the year before the earliest day held, for each garden,
    /// from the long-term record.
    func fetchEarlier(in context: ModelContext, now: Date = .now, calendar: Calendar = .current) async {
        guard !isWorking else { return }
        let gardens = (try? context.fetch(FetchDescriptor<Garden>())) ?? []
        let places = WeatherDiary.places(for: gardens.sorted { $0.displayOrder < $1.displayOrder })
        isWorking = true
        lastError = nil
        defer { isWorking = false }

        let today = WeatherDiary.dayKey(for: now, calendar: calendar)
        var added = 0
        for place in places {
            let held = ((try? context.fetch(FetchDescriptor<WeatherDay>())) ?? []).filter { $0.siteRaw == place.site }
            guard let request = WeatherDiary.earlierRequest(earliest: held.map(\.dayKey).min(), calendar: calendar) else { continue }
            added += await run(request, for: place, today: today, in: context, calendar: calendar)
        }
        let days = (try? context.fetch(FetchDescriptor<WeatherDay>())) ?? []
        WeatherDiary.recordFrosts(from: days, into: context, calendar: calendar)
        if lastError == nil { lastMessage = "\(added) earlier day\(added == 1 ? "" : "s") added." }
    }

    /// Puts one question to the service and stores the answer. Returns how
    /// many days were added or changed.
    private func run(_ request: WeatherDiary.Request, for place: WeatherDiary.Place, today: String,
                     in context: ModelContext, calendar: Calendar) async -> Int {
        guard let url = WeatherDiary.url(for: request, latitude: place.latitude, longitude: place.longitude,
                                         timeZone: calendar.timeZone) else { return 0 }
        do {
            let data = try await fetch(url)
            let readings = try WeatherDiary.readings(from: data)
            let source: String
            if case .archive = request { source = "archive" } else { source = "recent" }
            return WeatherDiary.store(readings, site: place.site, source: source, today: today,
                                      into: context, calendar: calendar)
        } catch {
            lastError = error.localizedDescription
            return 0
        }
    }
}
