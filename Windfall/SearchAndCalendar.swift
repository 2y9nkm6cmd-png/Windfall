//
//  SearchAndCalendar.swift
//  Windfall
//
//  The search that reads across every kind of record.
//
//  The calendar that used to share this file is now the Year page, in
//  YearView.swift.
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
