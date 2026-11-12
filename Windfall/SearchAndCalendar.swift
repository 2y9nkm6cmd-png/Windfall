//
//  SearchAndCalendar.swift
//  Windfall
//
//  Two views that read across everything: one searching, one planning.
//

import SwiftUI
import SwiftData

// MARK: - Universal search

/// Searches every record type at once. Same approach as the timeline —
/// SwiftData can't query across types, so each is fetched and merged.
struct UniversalSearchView: View {

    @Query private var plants: [Plant]
    @Query private var plantings: [Planting]
    @Query private var observations: [WildlifeObservation]
    @Query private var diary: [DiaryEntry]
    @Query private var fauna: [Fauna]
    @Query private var harvests: [Harvest]

    @State private var query: String

    /// `initialQuery` lets Eira's bar open the search with words already in it.
    init(initialQuery: String = "") {
        // The underscore reaches the storage behind @State, which is how a
        // starting value is handed in from outside.
        _query = State(initialValue: initialQuery)
    }

    private var results: [SearchResult] {
        guard query.count >= 2 else { return [] }
        let needle = query.lowercased()
        var found: [SearchResult] = []

        for plant in plants where
            plant.commonName.lowercased().contains(needle)
            || (plant.latinName?.lowercased().contains(needle) ?? false) {
            found.append(SearchResult(
                kind: "Plant", title: plant.displayName,
                detail: plant.latinName, symbol: "leaf",
                destination: .plant(plant)))
        }

        for animal in fauna where
            animal.commonName.lowercased().contains(needle)
            || (animal.scientificName?.lowercased().contains(needle) ?? false) {
            found.append(SearchResult(
                kind: "Species", title: animal.commonName,
                detail: animal.scientificName, symbol: "ant",
                destination: .fauna(animal)))
        }

        for planting in plantings where
            (planting.plant?.commonName.lowercased().contains(needle) ?? false)
            || (planting.notes?.lowercased().contains(needle) ?? false) {
            found.append(SearchResult(
                kind: "Sowing", title: planting.plant?.displayName ?? "Sowing",
                detail: planting.bedNames.isEmpty ? nil : planting.bedNames,
                symbol: "leaf.arrow.circlepath",
                destination: .planting(planting)))
        }

        for observation in observations where
            (observation.bestAvailableName?.lowercased().contains(needle) ?? false)
            || (observation.notes?.lowercased().contains(needle) ?? false) {
            found.append(SearchResult(
                kind: "Sighting", title: observation.bestAvailableName ?? "Sighting",
                detail: observation.observedAt.formatted(date: .abbreviated, time: .omitted),
                symbol: "eye", destination: .observation(observation)))
        }

        for entry in diary where
            entry.body.lowercased().contains(needle)
            || (entry.title?.lowercased().contains(needle) ?? false) {
            found.append(SearchResult(
                kind: "Diary", title: entry.displayTitle,
                detail: entry.date.formatted(date: .abbreviated, time: .omitted),
                symbol: "book.closed", destination: .diary(entry)))
        }

        for harvest in harvests where
            harvest.planting?.plant?.commonName.lowercased().contains(needle) ?? false {
            found.append(SearchResult(
                kind: "Harvest",
                title: "\(harvest.planting?.plant?.commonName ?? "") — \(harvest.quantity.formatted()) \(harvest.unit.displayName)",
                detail: harvest.date.formatted(date: .abbreviated, time: .omitted),
                symbol: "basket", destination: .none))
        }

        return found
    }

    private var grouped: [(kind: String, items: [SearchResult])] {
        Dictionary(grouping: results, by: \.kind)
            .map { (kind: $0.key, items: $0.value) }
            .sorted { $0.kind < $1.kind }
    }

    var body: some View {
        List {
            if query.count >= 2 && results.isEmpty {
                ContentUnavailableView.search(text: query)
            }

            ForEach(grouped, id: \.kind) { group in
                Section("\(group.kind) (\(group.items.count))") {
                    ForEach(group.items) { result in
                        SearchRow(result: result)
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Search everything")
        .navigationTitle("Search")
        .paperScreen()
        .navigationDestination(for: Plant.self) { PlantDetailView(plant: $0) }
        .navigationDestination(for: Planting.self) { PlantingDetailView(planting: $0) }
        .navigationDestination(for: Fauna.self) { FaunaDetailView(fauna: $0) }
        .navigationDestination(for: WildlifeObservation.self) { ObservationEditor(observation: $0) }
    }
}

struct SearchResult: Identifiable {
    let id = UUID()
    let kind: String
    let title: String
    let detail: String?
    let symbol: String
    let destination: SearchDestination
}

enum SearchDestination {
    case plant(Plant)
    case planting(Planting)
    case fauna(Fauna)
    case observation(WildlifeObservation)
    case diary(DiaryEntry)
    case none
}

private struct SearchRow: View {

    let result: SearchResult

    var body: some View {
        switch result.destination {
        case .plant(let plant):
            NavigationLink(value: plant) { content }
        case .planting(let planting):
            NavigationLink(value: planting) { content }
        case .fauna(let fauna):
            NavigationLink(value: fauna) { content }
        case .observation(let observation):
            NavigationLink(value: observation) { content }
        case .diary, .none:
            content
        }
    }

    private var content: some View {
        HStack(spacing: 10) {
            Image(systemName: result.symbol)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title).font(.subheadline)
                if let detail = result.detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Sowing calendar

/// The whole year on one screen, built from the spreadsheet's month text.
///
/// This is the view the spreadsheet can't give you: it reads "mar apr may"
/// and "Oct-Mar" out of 265 rows and lays them all against the same twelve
/// columns, so the gaps in the year become visible.
struct SowingCalendarView: View {

    @Query(sort: [SortDescriptor(\Plant.commonName)]) private var plants: [Plant]

    @State private var filter: CalendarFilter = .sowOutdoors
    @State private var search = ""

    enum CalendarFilter: String, CaseIterable, Identifiable {
        case sowIndoors = "Sow indoors"
        case sowOutdoors = "Sow outdoors"
        case plantOut = "Plant out"
        case harvest = "Harvest"
        case flowering = "Flowering"

        var id: String { rawValue }

        func months(for plant: Plant) -> [Int] {
            switch self {
            case .sowIndoors:  return MonthParser.months(in: plant.sowIndoorsMonthsText)
            case .sowOutdoors: return MonthParser.months(in: plant.sowOutdoorsMonthsText)
            case .plantOut:    return MonthParser.months(in: plant.plantOutMonthsText)
            case .harvest:     return MonthParser.months(in: plant.harvestMonthsText)
            case .flowering:   return MonthParser.months(in: plant.floweringMonthsText)
            }
        }

        var colour: Color {
            switch self {
            case .sowIndoors:  return .blue
            case .sowOutdoors: return .green
            case .plantOut:    return .teal
            case .harvest:     return .orange
            case .flowering:   return .pink
            }
        }
    }

    private var rows: [(plant: Plant, months: [Int])] {
        plants
            .filter { $0.status == .growing }
            .filter { search.isEmpty || $0.commonName.lowercased().contains(search.lowercased()) }
            .map { (plant: $0, months: filter.months(for: $0)) }
            .filter { !$0.months.isEmpty }
            .sorted { ($0.months.first ?? 13) < ($1.months.first ?? 13) }
    }

    private var thisMonth: Int { Calendar.current.component(.month, from: .now) }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Show", selection: $filter) {
                ForEach(CalendarFilter.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)

            // Month header
            HStack(spacing: 1) {
                Text("").frame(width: 110, alignment: .leading)
                ForEach(1...12, id: \.self) { month in
                    Text(shortMonth(month).prefix(1))
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(month == thisMonth ? .primary : .secondary)
                        .fontWeight(month == thisMonth ? .bold : .regular)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            Divider()

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(rows, id: \.plant.id) { row in
                        HStack(spacing: 1) {
                            Text(row.plant.commonName)
                                .font(.caption)
                                .lineLimit(1)
                                .frame(width: 110, alignment: .leading)

                            ForEach(1...12, id: \.self) { month in
                                Rectangle()
                                    .fill(row.months.contains(month)
                                          ? filter.colour.opacity(0.75)
                                          : Color.secondary.opacity(0.08))
                                    .frame(height: 18)
                                    .overlay {
                                        if month == thisMonth {
                                            Rectangle()
                                                .strokeBorder(.primary.opacity(0.4), lineWidth: 1)
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.vertical, 4)
            }

            if rows.isEmpty {
                ContentUnavailableView {
                    Label("Nothing to show", systemImage: "calendar")
                } description: {
                    Text("No plants have \(filter.rawValue.lowercased()) months recorded.")
                }
            }
        }
        .searchable(text: $search, prompt: "Filter plants")
        .navigationTitle("Sowing calendar")
        .paperScreen()
    }

    private func shortMonth(_ month: Int) -> String {
        let formatter = DateFormatter()
        return formatter.shortMonthSymbols[month - 1]
    }
}
