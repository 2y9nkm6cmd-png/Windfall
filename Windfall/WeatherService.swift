//
//  WeatherService.swift
//  Windfall
//
//  Current conditions, and the list of frosts.
//
//  The day-by-day record, and the frosts found in it, are in
//  WeatherDiary.swift.
//
//  Uses Open-Meteo rather than Apple's WeatherKit or a commercial API,
//  for one decisive reason: it needs no API key, no account and no
//  billing, and its non-commercial tier is free. WeatherKit would need
//  the Developer Programme membership plus an entitlement; OpenWeather
//  and the rest want a card on file.
//
//  What it's used for:
//  - Auto-filling FIT Count conditions, so the protocol thresholds are
//    checked against real numbers rather than a guess.
//

import Foundation
import CoreLocation
import SwiftData

// MARK: - Response shapes

/// Only the fields actually used. Decoding everything a weather API
/// returns is a lot of code for no benefit.
private struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        let temperature_2m: Double?
        let relative_humidity_2m: Double?
        let precipitation: Double?
        let cloud_cover: Double?
        let wind_speed_10m: Double?
        let weather_code: Int?
    }
    let current: Current?
}

// MARK: - Conditions

struct CurrentConditions {
    let temperatureC: Double
    let cloudCoverPercent: Double
    let precipitationMM: Double
    let windSpeedKMH: Double

    /// Mapped onto the PoMS sky categories, which is what the FIT Count
    /// protocol actually asks for.
    var skyCondition: SkyCondition {
        switch cloudCoverPercent {
        case ..<30:  return .sunny
        case ..<70:  return .partlyCloudy
        default:     return .cloudy
        }
    }

    var isDry: Bool { precipitationMM < 0.1 }

    /// Wind strong enough to affect a count — roughly Beaufort 4 upwards.
    var isWindy: Bool { windSpeedKMH > 20 }

    /// Whether a FIT Count would be valid right now.
    var suitsFITCount: Bool {
        isDry && !isWindy && temperatureC >= skyCondition.minimumTemperatureC
    }

    var fitCountBlockers: [String] {
        var blockers: [String] = []
        if !isDry { blockers.append("It's raining") }
        if isWindy { blockers.append("Too windy") }
        if temperatureC < skyCondition.minimumTemperatureC {
            blockers.append(String(format: "Only %.0f°C — needs %.0f°C in %@",
                                   temperatureC,
                                   skyCondition.minimumTemperatureC,
                                   skyCondition.displayName.lowercased()))
        }
        return blockers
    }
}

// MARK: - Service

@Observable
@MainActor
final class WeatherService {

    /// One for the whole app, so the last answer is kept while moving
    /// between screens.
    static let shared = WeatherService()

    private(set) var current: CurrentConditions?
    /// The week ahead, a day at a time, for "This week" on the Today
    /// screen. It arrives in the same reply as the current conditions,
    /// so it costs no extra request. Empty until the first reply.
    private(set) var outlook: [OutlookDay] = []
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var lastFetched: Date?
    /// Where the conditions were last asked for: a garden, or the device
    /// when no garden has a location.
    private(set) var lastPlace: CLLocationCoordinate2D?
    /// Days fetched for the journal, by day key, so each is asked once.
    private var hoursByDay: [String: WeatherHours] = [:]

    /// Cached for fifteen minutes. Conditions don't change fast enough to
    /// justify hammering a free service, and it works offline in between.
    private let cacheInterval: TimeInterval = 900

    /// The weather at any hour, for a place with no weather diary. Asks
    /// the service for that whole day, once, and keeps it.
    ///
    /// The last 60 days come from the ordinary address. Older days come
    /// from the long-term record, which runs about six days behind, so
    /// the days between are always the ordinary address. (Doc 14: asked
    /// for more than 64 days, the ordinary address leaves the oldest
    /// blank.)
    func conditions(at date: Date, near coordinate: CLLocationCoordinate2D,
                    calendar: Calendar = .current) async -> CurrentConditions? {
        let key = WeatherDiary.dayKey(for: date, calendar: calendar)
        let hour = calendar.component(.hour, from: date)
        if let hours = hoursByDay[key] { return hours.conditions(atHour: hour) }

        let today = calendar.startOfDay(for: .now)
        let daysBack = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: today).day ?? 0
        guard daysBack >= 0 else { return nil }   // The future has no record.
        let request: WeatherDiary.Request = daysBack <= 60
            ? .recent(pastDays: max(daysBack, 1))
            : .archive(start: key, end: key)
        guard let url = WeatherDiary.url(for: request, latitude: coordinate.latitude,
                                         longitude: coordinate.longitude) else { return nil }
        do {
            let data = try await WeatherDiary.download(url)
            // One question brings back several days. Keep them all.
            for reading in try WeatherDiary.readings(from: data) {
                hoursByDay[reading.dayKey] = reading.hourly
            }
        } catch {
            return nil
        }
        return hoursByDay[key]?.conditions(atHour: hour)
    }

    func conditions(at coordinate: CLLocationCoordinate2D,
                    force: Bool = false) async -> CurrentConditions? {
        // Kept so that other screens, such as the journal, can ask about
        // other hours at the same place.
        lastPlace = coordinate

        if !force, let lastFetched, Date.now.timeIntervalSince(lastFetched) < cacheInterval {
            return current
        }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            // Three decimal places is about a hundred metres: plenty for
            // weather, and no more exact than it needs to be. (Until
            // 13 November 2026 this sent the location in full, which was
            // more than Settings says is sent.)
            URLQueryItem(name: "latitude", value: String(format: "%.3f", coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.3f", coordinate.longitude)),
            URLQueryItem(name: "current",
                         value: "temperature_2m,relative_humidity_2m,precipitation,cloud_cover,wind_speed_10m,weather_code"),
            // Today and the seven days after it, for the frost, wind
            // and dry-spell warnings in "This week".
            URLQueryItem(name: "daily", value: "temperature_2m_min,precipitation_sum,wind_gusts_10m_max"),
            URLQueryItem(name: "forecast_days", value: "8"),
            URLQueryItem(name: "timezone", value: "Europe/London")
        ]

        guard let url = components.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

            guard let c = decoded.current, let temperature = c.temperature_2m else {
                lastError = "No weather data returned."
                return nil
            }

            let conditions = CurrentConditions(
                temperatureC: temperature,
                cloudCoverPercent: c.cloud_cover ?? 50,
                precipitationMM: c.precipitation ?? 0,
                windSpeedKMH: c.wind_speed_10m ?? 0
            )

            current = conditions
            outlook = WeekJobs.outlook(from: data)
            lastFetched = .now
            return conditions

        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
}

// MARK: - Frost view

import SwiftUI

struct FrostRecordsView: View {

    @Query(sort: [SortDescriptor(\FrostRecord.date, order: .reverse)])
    private var frosts: [FrostRecord]

    @Environment(\.modelContext) private var context

    @State private var diary = WeatherDiaryService()

    /// The two dates that actually shape the growing year.
    private var lastSpringFrost: FrostRecord? {
        let year = Calendar.current.component(.year, from: .now)
        return frosts
            .filter {
                Calendar.current.component(.year, from: $0.date) == year
                    && (1...6).contains(Calendar.current.component(.month, from: $0.date))
            }
            .max { $0.date < $1.date }
    }

    private var firstAutumnFrost: FrostRecord? {
        let year = Calendar.current.component(.year, from: .now)
        return frosts
            .filter {
                Calendar.current.component(.year, from: $0.date) == year
                    && (7...12).contains(Calendar.current.component(.month, from: $0.date))
            }
            .min { $0.date < $1.date }
    }

    var body: some View {
        List {
            Section {
                if let last = lastSpringFrost {
                    LabeledContent("Last spring frost",
                                   value: last.date.formatted(date: .abbreviated, time: .omitted))
                } else {
                    Text("No spring frost recorded this year")
                        .foregroundStyle(.secondary)
                }

                if let first = firstAutumnFrost {
                    LabeledContent("First autumn frost",
                                   value: first.date.formatted(date: .abbreviated, time: .omitted))
                } else {
                    Text("No autumn frost yet")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("This year")
            } footer: {
                Text("The gap between these two is your growing season. It's what decides whether a crop sown in July will ripen.")
            }

            Section("All records") {
                ForEach(frosts) { frost in
                    HStack {
                        Text(frost.date, format: .dateTime.day().month().year())
                        Spacer()
                        if let minimum = frost.minimumTemperatureC {
                            Text(String(format: "%.1f°C", minimum))
                                .foregroundStyle(minimum < -3 ? .red : .blue)
                        }
                    }
                }
                .onDelete { offsets in
                    for i in offsets { context.delete(frosts[i]) }
                }
            }
        }
        .navigationTitle("Frost")
        .paperScreen()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await refresh() }
                } label: {
                    Label("Check", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    /// Frosts are found in the weather diary, so bringing that up to date
    /// brings these up to date.
    private func refresh() async {
        await diary.bringUpToDate(in: context, force: true)
    }
}
