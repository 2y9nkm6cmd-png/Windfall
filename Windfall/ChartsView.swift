//
//  ChartsView.swift
//  Windfall
//
//  What the records add up to.
//
//  Swift Charts, which is built into the OS — nothing to install. The
//  charts here are chosen because they answer questions the spreadsheet
//  can't: yield by month, pollinator groups over the season, and whether
//  what's flowering matches what's flying.
//

import SwiftUI
import SwiftData
import Charts

struct ChartsView: View {

    @Query private var harvests: [Harvest]
    @Query private var surveys: [Survey]
    @Query private var phenology: [PhenologyEvent]
    @Query private var plantings: [Planting]

    @State private var year = Calendar.current.component(.year, from: .now)

    private var availableYears: [Int] {
        let fromHarvests = harvests.map { Calendar.current.component(.year, from: $0.date) }
        let fromSurveys = surveys.map { Calendar.current.component(.year, from: $0.startedAt) }
        let all = Set(fromHarvests + fromSurveys + [Calendar.current.component(.year, from: .now)])
        return all.sorted(by: >)
    }

    var body: some View {
        List {
            Section {
                Picker("Year", selection: $year) {
                    ForEach(availableYears, id: \.self) { Text(String($0)).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            harvestByMonth
            harvestByDestination
            pollinatorsOverSeason
            floweringVsFlying
            topCrops
        }
        .navigationTitle("Charts")
        .paperScreen()
    }

    // MARK: Harvest by month

    private var harvestByMonth: some View {
        Section {
            let data = monthlyHarvest()

            if data.allSatisfy({ $0.kilograms == 0 }) {
                Text("No harvests recorded for \(String(year)).")
                    .foregroundStyle(.secondary)
            } else {
                Chart(data, id: \.month) { point in
                    BarMark(
                        x: .value("Month", shortMonth(point.month)),
                        y: .value("Kilograms", point.kilograms)
                    )
                    .foregroundStyle(.orange.gradient)
                }
                .frame(height: 180)
                .chartYAxisLabel("kg")
            }
        } header: {
            Text("Harvest by month")
        } footer: {
            Text("Gaps here are the useful part — they show when the garden isn't feeding you, which is what succession sowing is meant to fix.")
        }
    }

    // MARK: Where it went

    private var harvestByDestination: some View {
        Section {
            let data = harvestDestinations()

            if data.isEmpty {
                Text("Nothing recorded yet.").foregroundStyle(.secondary)
            } else {
                Chart(data, id: \.destination) { point in
                    SectorMark(
                        angle: .value("Kilograms", point.kilograms),
                        innerRadius: .ratio(0.55),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Destination", point.destination))
                    .cornerRadius(3)
                }
                .frame(height: 200)

                if let composted = data.first(where: { $0.destination == "composted" }) {
                    let total = data.reduce(0) { $0 + $1.kilograms }
                    let share = total > 0 ? composted.kilograms / total : 0
                    if share > 0.15 {
                        Label("\(Int(share * 100))% went to the compost — worth sowing less of something",
                              systemImage: "lightbulb")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        } header: {
            Text("Where the harvest went")
        }
    }

    // MARK: Pollinators

    private var pollinatorsOverSeason: some View {
        Section {
            let data = pollinatorCounts()

            if data.isEmpty {
                Text("No FIT Counts recorded for \(String(year)).")
                    .foregroundStyle(.secondary)
            } else {
                Chart(data, id: \.id) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Count", point.count)
                    )
                    .foregroundStyle(by: .value("Group", point.group))
                    .symbol(by: .value("Group", point.group))
                }
                .frame(height: 220)
                .chartYAxisLabel("insects per count")
            }
        } header: {
            Text("Pollinators through the season")
        } footer: {
            Text("Each point is one ten-minute count. Comparing across dates only means anything because the protocol keeps the effort constant.")
        }
    }

    // MARK: Flowering vs flying

    /// The chart that connects the two halves of the app: are the
    /// pollinators arriving when things are actually in flower?
    private var floweringVsFlying: some View {
        Section {
            let flowering = floweringByMonth()
            let insects = insectsByMonth()

            if flowering.allSatisfy({ $0.count == 0 }) && insects.allSatisfy({ $0.count == 0 }) {
                Text("Record flowering dates and FIT Counts to compare them.")
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(flowering, id: \.month) { point in
                        BarMark(
                            x: .value("Month", shortMonth(point.month)),
                            y: .value("In flower", point.count)
                        )
                        .foregroundStyle(.pink.opacity(0.5))
                    }
                    ForEach(insects, id: \.month) { point in
                        LineMark(
                            x: .value("Month", shortMonth(point.month)),
                            y: .value("Insects", point.count)
                        )
                        .foregroundStyle(.blue)
                        .symbol(.circle)
                    }
                }
                .frame(height: 200)
            }
        } header: {
            Text("Flowering against flying")
        } footer: {
            Text("Pink bars are plants recorded in flower; the blue line is insects counted. A gap where the line runs ahead of the bars is a month worth planting into.")
        }
    }

    // MARK: Top crops

    private var topCrops: some View {
        Section("Best croppers") {
            let data = cropTotals().prefix(8)

            if data.isEmpty {
                Text("No harvests yet.").foregroundStyle(.secondary)
            } else {
                Chart(Array(data), id: \.name) { point in
                    BarMark(
                        x: .value("Kilograms", point.kilograms),
                        y: .value("Crop", point.name)
                    )
                    .foregroundStyle(.green.gradient)
                }
                .frame(height: CGFloat(data.count) * 28 + 20)
            }
        }
    }

    // MARK: - Aggregation

    private struct MonthPoint { let month: Int; let kilograms: Double }
    private struct CountPoint { let month: Int; let count: Int }
    private struct GroupPoint { let id: String; let date: Date; let group: String; let count: Int }
    private struct NamePoint { let name: String; let kilograms: Double }
    private struct DestinationPoint { let destination: String; let kilograms: Double }

    private func inYear(_ date: Date) -> Bool {
        Calendar.current.component(.year, from: date) == year
    }

    private func monthlyHarvest() -> [MonthPoint] {
        var totals = [Int: Double]()
        for harvest in harvests where inYear(harvest.date) {
            let month = Calendar.current.component(.month, from: harvest.date)
            totals[month, default: 0] += harvest.weightInGrams / 1000
        }
        return (1...12).map { MonthPoint(month: $0, kilograms: totals[$0] ?? 0) }
    }

    private func harvestDestinations() -> [DestinationPoint] {
        var totals = [String: Double]()
        for harvest in harvests where inYear(harvest.date) {
            let key = harvest.destination?.rawValue ?? "unrecorded"
            totals[key, default: 0] += harvest.weightInGrams / 1000
        }
        return totals
            .filter { $0.value > 0 }
            .map { DestinationPoint(destination: $0.key, kilograms: $0.value) }
            .sorted { $0.kilograms > $1.kilograms }
    }

    private func pollinatorCounts() -> [GroupPoint] {
        var points: [GroupPoint] = []
        for survey in surveys where survey.scheme == .fitCount && inYear(survey.startedAt) {
            for tally in survey.tallies ?? [] where tally.quantity > 0 {
                points.append(GroupPoint(
                    id: "\(survey.id)-\(tally.groupName)",
                    date: survey.startedAt,
                    group: tally.groupName,
                    count: tally.quantity
                ))
            }
        }
        return points.sorted { $0.date < $1.date }
    }

    private func floweringByMonth() -> [CountPoint] {
        var counts = [Int: Int]()
        for event in phenology
        where inYear(event.date) && (event.stage == .firstFlower || event.stage == .fullFlower) {
            let month = Calendar.current.component(.month, from: event.date)
            counts[month, default: 0] += 1
        }
        return (1...12).map { CountPoint(month: $0, count: counts[$0] ?? 0) }
    }

    private func insectsByMonth() -> [CountPoint] {
        var counts = [Int: Int]()
        for survey in surveys where survey.scheme == .fitCount && inYear(survey.startedAt) {
            let month = Calendar.current.component(.month, from: survey.startedAt)
            counts[month, default: 0] += survey.totalCount
        }
        return (1...12).map { CountPoint(month: $0, count: counts[$0] ?? 0) }
    }

    private func cropTotals() -> [NamePoint] {
        var totals = [String: Double]()
        for harvest in harvests where inYear(harvest.date) {
            guard let name = harvest.planting?.plant?.commonName else { continue }
            totals[name, default: 0] += harvest.weightInGrams / 1000
        }
        return totals
            .map { NamePoint(name: $0.key, kilograms: $0.value) }
            .sorted { $0.kilograms > $1.kilograms }
    }

    private func shortMonth(_ month: Int) -> String {
        let formatter = DateFormatter()
        return formatter.shortMonthSymbols[max(0, min(11, month - 1))]
    }
}
