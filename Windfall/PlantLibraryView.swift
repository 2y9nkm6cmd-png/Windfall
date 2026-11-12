//
//  PlantLibraryView.swift
//  Windfall
//
//  The Library tab: search, filter, and the plant detail with the eight
//  collapsible category groups from the spreadsheet.
//

import SwiftUI
import SwiftData

// MARK: - Library

struct PlantLibraryView: View {

    @Query(sort: [SortDescriptor(\Plant.commonName)])
    private var plants: [Plant]

    @Environment(\.modelContext) private var context

    @State private var search = ""
    @State private var statusFilter: PlantStatus? = .growing
    @State private var showPollinatorsOnly = false
    @State private var sowableNow = false
    @State private var showingImport = false

    private var filtered: [Plant] {
        let month = Calendar.current.component(.month, from: .now)

        return plants.filter { plant in
            if let statusFilter, plant.status != statusFilter { return false }
            if showPollinatorsOnly && !plant.isPollinator { return false }

            if sowableNow {
                let indoors = MonthParser.months(in: plant.sowIndoorsMonthsText)
                let outdoors = MonthParser.months(in: plant.sowOutdoorsMonthsText)
                if !indoors.contains(month) && !outdoors.contains(month) { return false }
            }

            guard !search.isEmpty else { return true }
            let needle = search.lowercased()
            return plant.commonName.lowercased().contains(needle)
                || (plant.latinName?.lowercased().contains(needle) ?? false)
                || (plant.variety?.lowercased().contains(needle) ?? false)
                || (plant.group?.lowercased().contains(needle) ?? false)
        }
    }

    var body: some View {
        List {
            if plants.isEmpty {
                ContentUnavailableView {
                    Label("No plants yet", systemImage: "leaf")
                } description: {
                    Text("Load the starter data, or import a file of your own.")
                } actions: {
                    Button("Add garden data") { showingImport = true }
                        .buttonStyle(.borderedProminent)
                }
            }

            ForEach(filtered) { plant in
                NavigationLink(value: plant) {
                    PlantRow(plant: plant)
                }
            }
        }
        .searchable(text: $search, prompt: "Search plants")
        .navigationTitle("Library")
        .paperScreen()
        .navigationDestination(for: Plant.self) { PlantDetailView(plant: $0) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Status", selection: $statusFilter) {
                        Text("Growing").tag(PlantStatus?.some(.growing))
                        Text("To buy").tag(PlantStatus?.some(.wanted))
                        Text("Previously owned").tag(PlantStatus?.some(.previouslyOwned))
                        Text("All").tag(PlantStatus?.none)
                    }

                    Divider()

                    Toggle("Pollinator plants only", isOn: $showPollinatorsOnly)
                    Toggle("Sowable this month", isOn: $sowableNow)

                    Divider()

                    Button {
                        showingImport = true
                    } label: {
                        Label("Garden data", systemImage: "tray.and.arrow.down")
                    }
                } label: {
                    Label("Options", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showingImport) {
            NavigationStack {
                GardenDataView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingImport = false }
                        }
                    }
            }
            .macSheetSize(width: 520, height: 560)
        }
        .overlay(alignment: .bottom) {
            if !filtered.isEmpty {
                Text("^[\(filtered.count) plant](inflect: true)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 8)
            }
        }
    }

}

// MARK: - Row

private struct PlantRow: View {

    let plant: Plant

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(plant.displayName)
                .font(.headline)

            if let latin = plant.latinName {
                Text(latin)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                if plant.isPollinator      { Tag("Pollinator", .orange) }
                if plant.isNitrogenFixer   { Tag("N-fixer", .green) }
                if plant.isDynamicAccumulator { Tag("Accumulator", .brown) }
                if plant.isGroundCover     { Tag("Ground cover", .teal) }
                if plant.status == .wanted { Tag("To buy", .blue) }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct Tag: View {
    let text: String
    let colour: Color
    init(_ text: String, _ colour: Color) { self.text = text; self.colour = colour }

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(colour.opacity(0.18), in: Capsule())
            .foregroundStyle(colour)
    }
}

// MARK: - Detail

struct PlantDetailView: View {

    @Bindable var plant: Plant

    var body: some View {
        Form {
            Section {
                if let latin = plant.latinName {
                    LabeledContent("Latin name") { Text(latin).italic() }
                }
                if let variety = plant.variety   { LabeledContent("Variety", value: variety) }
                if let group = plant.group       { LabeledContent("Group", value: group) }
                if let c = plant.classification  { LabeledContent("Classification", value: c) }
            }

            // The eight category groups from the spreadsheet, as sections.
            group("Growth Patterns") {
                monthRow("Flowering", plant.floweringMonthsText)
                monthRow("Stem growth", plant.stemGrowthMonthsText)
                monthRow("Foliage", plant.foliageMonthsText)
                monthRow("Fruiting", plant.fruitingMonthsText)
                row("Plant type", plant.plantType)
                row("Habits", plant.habits)
            }

            group("Growth Habits") {
                row("Max height", plant.maxHeightM)
                row("Spread", plant.spreadM)
                row("Root depth", plant.rootDepthM)
                row("Spacing", plant.spacingM)
                row("Flower form", plant.flowerForm)
                row("Layer", plant.layer)
            }

            Section("Permaculture Category") {
                if plant.isPollinator         { Label("Pollinator plant", systemImage: "ant") }
                if plant.isRepeller           { Label("Pest repeller", systemImage: "shield") }
                if plant.isUmbelliferous      { Label("Umbelliferous", systemImage: "circle.grid.cross") }
                if plant.isNitrogenFixer      { Label("Nitrogen fixer", systemImage: "leaf.circle") }
                if plant.isDynamicAccumulator { Label("Dynamic accumulator", systemImage: "arrow.up.circle") }
                if plant.isGroundCover        { Label("Ground cover", systemImage: "square.grid.3x3.fill") }
            }

            group("Sowing from Seed") {
                monthRow("Sow indoors", plant.sowIndoorsMonthsText)
                monthRow("Sow outdoors", plant.sowOutdoorsMonthsText)
                monthRow("Plant out", plant.plantOutMonthsText)
                monthRow("Harvest", plant.harvestMonthsText)
                rangeRow("Germination", plant.germinationDaysText, unit: "days")
                rangeRow("Sow to crop", plant.sowToCropText, unit: "days")
                row("Sowing depth", plant.sowingDepthMM)
                row("Propagation", plant.propagation)
            }

            group("Growth Constraints") {
                row("Sun / shade", plant.sunShade)
                row("Position", plant.position)
                row("Hardiness", plant.hardiness)
                row("Soil pH", plant.soilPH)
                row("Soil conditions", plant.preferredSoilConditions)
                row("Pests", plant.knownPests)
                row("Diseases", plant.knownDiseases)
            }

            group("Human Management") {
                row("Pruning", plant.pruning)
                row("Pruning group", plant.pruningGroup)
                row("Culinary uses", plant.culinaryUses)
                row("Medicinal uses", plant.medicinalUses)
                row("Toxicity", plant.toxicityCautions)
            }

            Section {
                NavigationLink {
                    CompanionView(plantName: plant.commonName)
                } label: {
                    Label("Companion planting", systemImage: "square.on.square")
                }
            }

            group("Ecological Interactions") {
                row("Partner plants", plant.partnerPlants)
                row("Antagonistic plants", plant.antagonisticPlants)
                row("Pollinators", plant.pollinators)
            }

            group("Description") {
                row("Appearance", plant.appearance)
                row("History", plant.history)
                row("Notes", plant.notes)
            }

            if let plantings = plant.plantings, !plantings.isEmpty {
                Section("Sowings") {
                    ForEach(plantings.sorted { ($0.dateSown ?? .distantPast) > ($1.dateSown ?? .distantPast) }) { planting in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(planting.bedNames.isEmpty ? "Unplaced" : planting.bedNames)
                                .font(.subheadline)
                            if let sown = planting.dateSown {
                                Text(sown, format: .dateTime.day().month().year())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(plant.commonName)
        .paperScreen()
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: Row builders

    /// Hides a whole section when every field in it is empty — most plants
    /// don't have all 69 columns filled, and empty headings are noise.
    @ViewBuilder
    private func group<Content: View>(_ title: String,
                                      @ViewBuilder content: () -> Content) -> some View {
        Section(title) { content() }
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            LabeledContent(label) {
                Text(value)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    @ViewBuilder
    private func monthRow(_ label: String, _ text: String?) -> some View {
        let months = MonthParser.months(in: text)
        if !months.isEmpty {
            LabeledContent(label) {
                Text(MonthParser.describe(months))
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    @ViewBuilder
    private func rangeRow(_ label: String, _ text: String?, unit: String) -> some View {
        if let range = RangeParser.range(in: text) {
            LabeledContent(label, value: "\(range.description) \(unit)")
        }
    }
}
