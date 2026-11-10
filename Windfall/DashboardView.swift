//
//  DashboardView.swift
//  Windfall
//
//  What to do now.
//
//  Everything on this screen is derived, never stored — what's sowable
//  this month comes from parsing the spreadsheet's month text, survey
//  prompts come from the PoMS season and today's conditions, rotation
//  warnings come from what grew in each bed before.
//
//  Nothing here needs maintaining. It follows the data.
//

import SwiftUI
import SwiftData

struct DashboardView: View {

    @Query(sort: [SortDescriptor(\Plant.commonName)]) private var plants: [Plant]
    @Query private var plantings: [Planting]
    @Query private var surveys: [Survey]
    @Query private var seedPackets: [SeedPacket]
    @Query(filter: #Predicate<Bed> { $0.retiredAt == nil },
           sort: [SortDescriptor(\Bed.displayOrder)]) private var beds: [Bed]

    private var month: Int { Calendar.current.component(.month, from: .now) }

    // MARK: Derived lists

    /// Plants whose sowing window includes this month, and which you
    /// haven't already sown this year.
    private var sowableNow: [Plant] {
        let year = Calendar.current.component(.year, from: .now)

        return plants.filter { plant in
            guard plant.status == .growing else { return false }

            let indoors = MonthParser.months(in: plant.sowIndoorsMonthsText)
            let outdoors = MonthParser.months(in: plant.sowOutdoorsMonthsText)
            guard indoors.contains(month) || outdoors.contains(month) else { return false }

            let sownThisYear = (plant.plantings ?? []).contains { planting in
                guard let sown = planting.dateSown else { return false }
                return Calendar.current.component(.year, from: sown) == year
            }
            // Succession crops are worth suggesting again regardless.
            let isSuccession = (plant.plantings ?? []).contains { $0.successionRound != nil }
            return !sownThisYear || isSuccession
        }
    }

    /// Sowings that should be ready around now, from sow-to-crop time.
    private var dueToHarvest: [Planting] {
        plantings.filter { planting in
            guard planting.status == .growing || planting.status == .plantedOut,
                  let sown = planting.dateSown,
                  let days = RangeParser.midpoint(in: planting.plant?.sowToCropText)
            else { return false }

            let expected = sown.addingTimeInterval(days * 86_400)
            return expected <= Date.now.addingTimeInterval(14 * 86_400)
        }
    }

    private var isFITSeason: Bool { (4...9).contains(month) }

    private var daysSinceLastFITCount: Int? {
        let counts = surveys.filter { $0.scheme == .fitCount }
        guard let latest = counts.map(\.startedAt).max() else { return nil }
        return Calendar.current.dateComponents([.day], from: latest, to: .now).day
    }

    private var isWormSeason: Bool { [3, 4, 5, 9, 10, 11].contains(month) }

    /// Packets past their use-by, or with measured viability under half.
    private var failingSeed: [SeedPacket] {
        seedPackets.filter { packet in
            packet.isExpired || (packet.viabilityRate.map { $0 < 0.5 } ?? false)
        }
    }

    /// Beds where the same plant family is about to follow itself.
    private var rotationWarnings: [(bed: Bed, group: String)] {
        var warnings: [(Bed, String)] = []
        let year = Calendar.current.component(.year, from: .now)

        for bed in beds {
            let sections = bed.orderedSections
            let all = sections.flatMap { $0.plantings ?? [] }

            let thisYear = Set(all.compactMap { planting -> String? in
                guard let sown = planting.dateSown,
                      Calendar.current.component(.year, from: sown) == year
                else { return nil }
                return planting.plant?.group
            })

            let lastYear = Set(all.compactMap { planting -> String? in
                guard let sown = planting.dateSown,
                      Calendar.current.component(.year, from: sown) == year - 1
                else { return nil }
                return planting.plant?.group
            })

            for group in thisYear.intersection(lastYear) {
                warnings.append((bed, group))
            }
        }
        return warnings
    }

    // MARK: Body

    var body: some View {
        List {
            Section {
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.title3.weight(.medium))
            }

            // Survey prompts
            if isFITSeason {
                Section("Pollinator counts") {
                    if let days = daysSinceLastFITCount {
                        Label(days > 14
                              ? "No FIT Count for \(days) days"
                              : "Last count \(days) days ago",
                              systemImage: days > 14 ? "exclamationmark.circle" : "checkmark.circle")
                            .foregroundStyle(days > 14 ? .orange : .green)
                    } else {
                        Label("No FIT Counts recorded yet", systemImage: "camera.macro")
                    }

                    Text("Season runs to 30 September. Needs dry weather, 13°C in sun or 15°C in cloud.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    NavigationLink("Go to surveys", value: DashboardRoute.surveys)
                }
            }

            if isWormSeason {
                Section("Earthworm counts") {
                    Label("Good conditions this month", systemImage: "chart.bar.doc.horizontal")
                    Text("Spring and autumn only — worms sit deeper in high summer and hard frost, so counts made then undercount badly.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Sowing
            if !sowableNow.isEmpty {
                Section("Sowable this month") {
                    ForEach(sowableNow.prefix(10)) { plant in
                        NavigationLink(value: plant) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plant.displayName)
                                sowingWindow(for: plant)
                            }
                        }
                    }
                    if sowableNow.count > 10 {
                        Text("and \(sowableNow.count - 10) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Harvest
            if !dueToHarvest.isEmpty {
                Section("Ready soon") {
                    ForEach(dueToHarvest) { planting in
                        NavigationLink(value: planting) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(planting.plant?.displayName ?? "Unknown")
                                if let sown = planting.dateSown {
                                    Text("Sown \(sown.formatted(.dateTime.day().month()))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            // Rotation
            if !rotationWarnings.isEmpty {
                Section {
                    ForEach(rotationWarnings, id: \.group) { warning in
                        Label("\(warning.group) in \(warning.bed.name) two years running",
                              systemImage: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.orange)
                            .font(.callout)
                    }
                } header: {
                    Text("Rotation")
                } footer: {
                    Text("Growing the same family in the same ground builds up soil-borne pests and diseases.")
                }
            }

            // Seed
            if !failingSeed.isEmpty {
                Section("Seed stock") {
                    ForEach(failingSeed) { packet in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(packet.plant?.displayName ?? "Unknown seed")
                            if packet.isExpired {
                                Text("Past its use-by date")
                                    .font(.caption).foregroundStyle(.orange)
                            } else if let rate = packet.viabilityRate {
                                Text("Germinating at \(Int(rate * 100))% — sow \(packet.suggestedSowingMultiplier().map { String(format: "%.1f", $0) } ?? "1")× as thickly")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }

            // Summary
            Section("This year") {
                let year = Calendar.current.component(.year, from: .now)
                let thisYearPlantings = plantings.filter {
                    guard let sown = $0.dateSown else { return false }
                    return Calendar.current.component(.year, from: sown) == year
                }
                let totalHarvest = thisYearPlantings.reduce(0.0) { $0 + $1.totalHarvestGrams }

                LabeledContent("Sowings", value: "\(thisYearPlantings.count)")
                LabeledContent("Harvested",
                               value: "\((totalHarvest / 1000).formatted(.number.precision(.fractionLength(0...1)))) kg")
                LabeledContent("Surveys",
                               value: "\(surveys.filter { Calendar.current.component(.year, from: $0.startedAt) == year }.count)")
            }
        }
        .navigationTitle("Windfall")
        .navigationDestination(for: Plant.self) { PlantDetailView(plant: $0) }
        .navigationDestination(for: Planting.self) { PlantingDetailView(planting: $0) }
        .navigationDestination(for: DashboardRoute.self) { route in
            switch route {
            case .surveys: SurveyListView()
            }
        }
    }

    @ViewBuilder
    private func sowingWindow(for plant: Plant) -> some View {
        let indoors = MonthParser.months(in: plant.sowIndoorsMonthsText)
        let outdoors = MonthParser.months(in: plant.sowOutdoorsMonthsText)

        HStack(spacing: 6) {
            if indoors.contains(month) {
                Label("Indoors", systemImage: "house")
            }
            if outdoors.contains(month) {
                Label("Outdoors", systemImage: "sun.max")
            }
            if let days = RangeParser.range(in: plant.germinationDaysText) {
                Text("· up in \(days.description) days")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}

enum DashboardRoute: Hashable {
    case surveys
}
