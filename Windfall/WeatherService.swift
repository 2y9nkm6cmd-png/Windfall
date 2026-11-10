//
//  WeatherService.swift
//  Windfall
//
//  Current conditions and frost detection.
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
//  - Detecting frosts, which are what turn "the beans were poor" into
//    "the beans were poor because of the frost on the 12th".
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
    struct Daily: Decodable {
        let time: [String]?
        let temperature_2m_min: [Double?]?
        let temperature_2m_max: [Double?]?
        let precipitation_sum: [Double?]?
    }
    let current: Current?
    let daily: Daily?
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

    private(set) var current: CurrentConditions?
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var lastFetched: Date?

    /// Cached for fifteen minutes. Conditions don't change fast enough to
    /// justify hammering a free service, and it works offline in between.
    private let cacheInterval: TimeInterval = 900

    func conditions(at coordinate: CLLocationCoordinate2D,
                    force: Bool = false) async -> CurrentConditions? {

        if !force, let lastFetched, Date.now.timeIntervalSince(lastFetched) < cacheInterval {
            return current
        }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "current",
                         value: "temperature_2m,relative_humidity_2m,precipitation,cloud_cover,wind_speed_10m,weather_code"),
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
            lastFetched = .now
            return conditions

        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    // MARK: Frost detection

    /// Looks back over recent days and records any night below zero.
    ///
    /// Called on launch rather than continuously — a frost three days ago
    /// is just as useful to know about as one this morning, and this way
    /// the app doesn't need to be open at dawn.
    func detectFrosts(at coordinate: CLLocationCoordinate2D,
                      into context: ModelContext,
                      daysBack: Int = 10) async {

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "daily", value: "temperature_2m_min,temperature_2m_max,precipitation_sum"),
            URLQueryItem(name: "past_days", value: String(daysBack)),
            URLQueryItem(name: "forecast_days", value: "3"),
            URLQueryItem(name: "timezone", value: "Europe/London")
        ]

        guard let url = components.url else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

            guard let daily = decoded.daily,
                  let dates = daily.time,
                  let minima = daily.temperature_2m_min else { return }

            let existing = try context.fetch(FetchDescriptor<FrostRecord>())
            let known = Set(existing.map { Calendar.current.startOfDay(for: $0.date) })

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "Europe/London")

            for (index, dateString) in dates.enumerated() {
                guard index < minima.count,
                      let minimum = minima[index], minimum <= 0,
                      let date = formatter.date(from: dateString) else { continue }

                let day = Calendar.current.startOfDay(for: date)
                guard !known.contains(day) else { continue }

                let record = FrostRecord()
                record.date = day
                record.minimumTemperatureC = minimum
                record.kind = Self.classifyFrost(on: day)
                context.insert(record)
            }

        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Spring frosts before the end of May are candidates for "last spring
    /// frost"; autumn ones from September onwards for "first autumn frost".
    /// Deep winter frosts are just frosts.
    private static func classifyFrost(on date: Date) -> FrostKind {
        let month = Calendar.current.component(.month, from: date)
        switch month {
        case 3...5:  return .lastSpringFrost
        case 9...11: return .firstAutumnFrost
        default:     return .other
        }
    }
}

// MARK: - Frost view

import SwiftUI

struct FrostRecordsView: View {

    @Query(sort: [SortDescriptor(\FrostRecord.date, order: .reverse)])
    private var frosts: [FrostRecord]

    @Environment(\.modelContext) private var context
    @Environment(LocationManager.self) private var location

    @State private var weather = WeatherService()

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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await refresh() }
                } label: {
                    Label("Check", systemImage: "arrow.clockwise")
                }
            }
        }
        .task { await refresh() }
    }

    private func refresh() async {
        guard let fix = await location.currentLocation() else { return }
        await weather.detectFrosts(at: fix.coordinate, into: context)
    }
}
