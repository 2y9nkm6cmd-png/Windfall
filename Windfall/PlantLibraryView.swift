//
//  PlantLibraryView.swift
//  Windfall
//
//  The Plants screen: search, a row of filter buttons, and the plant
//  detail with the eight category groups from the spreadsheet.
//
//  The sums behind the filters are in PlantFilter.swift.
//

import SwiftUI
import SwiftData

// MARK: - Library

struct PlantLibraryView: View {

    @Query(sort: [SortDescriptor(\Plant.commonName)])
    private var plants: [Plant]

    @Environment(\.modelContext) private var context

    /// Everything chosen with the buttons along the top, and the search.
    /// One value, so "Clear" can put it all back in one go.
    @State private var filter = PlantFilter.fromLaunchArguments()
    @State private var showingImport = false

    /// This month, 1 to 12.
    private var today: Int { Calendar.current.component(.month, from: .now) }

    var body: some View {
        let shown = filter.filter(plants, today: today)

        VStack(spacing: 0) {
            if !plants.isEmpty {
                filterButtons
            }

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
                } else if shown.isEmpty {
                    ContentUnavailableView {
                        Label("No plants match", systemImage: "line.3.horizontal.decrease.circle")
                    } description: {
                        Text("Nothing in the library fits everything chosen above.")
                    } actions: {
                        Button("Clear filters") { clearFilters() }
                            .buttonStyle(.borderedProminent)
                    }
                }

                ForEach(shown) { plant in
                    NavigationLink(value: plant) {
                        PlantRow(plant: plant)
                    }
                }
            }
        }
        .searchable(text: $filter.search, prompt: "Search plants")
        .navigationTitle("Plants")
        .paperScreen()
        .navigationDestination(for: Plant.self) { PlantDetailView(plant: $0) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingImport = true
                } label: {
                    Label("Garden data", systemImage: "tray.and.arrow.down")
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
            if !shown.isEmpty {
                Text("^[\(shown.count) plant](inflect: true)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 8)
            }
        }
    }

    // MARK: The buttons along the top

    /// One button for each way of narrowing the list. Each opens a menu.
    /// The numbers in a menu say how many plants each option would show,
    /// with the other buttons' choices still applied.
    private var filterButtons: some View {
        // Sideways scrolling, so the buttons never squash on an iPhone.
        ScrollView(.horizontal, showsIndicators: false) {
            // Lets neighbouring pieces of glass share one layer.
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    statusButton
                    kindButton
                    layerButton
                    familyButton
                    seasonButton
                    roleButton
                    if filter.isNarrowed {
                        clearButton
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    private var statusButton: some View {
        Menu {
            Picker("Show", selection: $filter.status) {
                Text("Growing").tag(PlantStatus?.some(.growing))
                Text("To buy").tag(PlantStatus?.some(.wanted))
                Text("Previously owned").tag(PlantStatus?.some(.previouslyOwned))
                Text("All plants").tag(PlantStatus?.none)
            }
            .pickerStyle(.inline)
        } label: {
            FilterButtonLabel(title: statusTitle)
        }
        .filterButton(isChosen: filter.status != PlantFilter.standard.status)
    }

    private var statusTitle: String {
        switch filter.status {
        case .growing: return "Growing"
        case .wanted: return "To buy"
        case .previouslyOwned: return "Previously owned"
        case nil: return "All plants"
        }
    }

    private var kindButton: some View {
        Menu {
            Picker("Kind", selection: $filter.kind) {
                Text("Any kind").tag(PlantKind?.none)
                ForEach(filter.kindChoices(plants, today: today)) { option in
                    Text(option.menuText).tag(PlantKind(rawValue: option.key))
                }
            }
            .pickerStyle(.inline)
        } label: {
            FilterButtonLabel(title: filter.kind?.rawValue ?? "Fruit, veg…")
        }
        .filterButton(isChosen: filter.kind != nil)
    }

    private var layerButton: some View {
        Menu {
            Picker("Permaculture layer", selection: $filter.layer) {
                Text("Any layer").tag(String?.none)
                ForEach(filter.layerChoices(plants, today: today)) { option in
                    Text(option.menuText).tag(String?.some(option.key))
                }
            }
            .pickerStyle(.inline)
        } label: {
            FilterButtonLabel(title: filter.layer ?? "Layer")
        }
        .filterButton(isChosen: filter.layer != nil)
    }

    private var familyButton: some View {
        let choices = filter.familyChoices(plants, today: today)
        return Menu {
            Picker("Family", selection: $filter.family) {
                Text("Any family").tag(String?.none)
                ForEach(choices) { option in
                    Text(option.menuText).tag(String?.some(option.key))
                }
            }
            .pickerStyle(.inline)
        } label: {
            // The family's name as the records spell it, such as "Brassicas".
            FilterButtonLabel(title: filter.family.map { key in
                choices.first { $0.key == key }?.title ?? key.capitalized
            } ?? "Family")
        }
        .filterButton(isChosen: filter.family != nil)
    }

    private var seasonButton: some View {
        Menu {
            Picker("What", selection: $filter.season) {
                Text("Any time of year").tag(PlantSeason?.none)
                ForEach(filter.seasonChoices(plants, today: today)) { option in
                    Text(option.menuText).tag(PlantSeason(rawValue: option.key))
                }
            }
            .pickerStyle(.inline)

            // `.menu` inside a menu becomes a second menu that opens to
            // the side, which keeps the twelve months out of the way.
            Picker("When", selection: $filter.seasonMonth) {
                Text("This month (\(PlantFilter.monthName(today)))").tag(Int?.none)
                ForEach(1...12, id: \.self) { month in
                    Text(PlantFilter.monthName(month)).tag(Int?.some(month))
                }
            }
            .pickerStyle(.menu)
        } label: {
            FilterButtonLabel(title: seasonTitle)
        }
        .filterButton(isChosen: filter.season != nil)
    }

    /// "Season" with nothing chosen, "Sowing now" for this month, and
    /// "Flowering in June" for another.
    private var seasonTitle: String {
        guard let season = filter.season else { return "Season" }
        guard let month = filter.seasonMonth else { return "\(season.rawValue) now" }
        return season.phrase(month: month)
    }

    private var roleButton: some View {
        Menu {
            Section("Plants that are all of these") {
                ForEach(filter.roleChoices(plants, today: today)) { option in
                    if let role = PlantRole(rawValue: option.key) {
                        // A switch for each role: more than one can be on.
                        Toggle(option.menuText, isOn: Binding(
                            get: { filter.roles.contains(role) },
                            set: { isOn in
                                if isOn { filter.roles.insert(role) } else { filter.roles.remove(role) }
                            }))
                    }
                }
            }
        } label: {
            FilterButtonLabel(title: roleTitle)
        }
        .filterButton(isChosen: !filter.roles.isEmpty)
    }

    /// "Role", or the role chosen, or the first and how many more.
    private var roleTitle: String {
        let chosen = PlantRole.allCases.filter { filter.roles.contains($0) }
        guard let first = chosen.first else { return "Role" }
        return chosen.count == 1 ? first.rawValue : "\(first.rawValue) +\(chosen.count - 1)"
    }

    private var clearButton: some View {
        Button {
            clearFilters()
        } label: {
            HStack(spacing: 6) {
                WIconView(.close, size: 12)
                Text("Clear")
                    .font(.subheadline)
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Theme.card.opacity(0.4)).interactive(), in: .capsule)
    }

    /// Puts every button back as it was. What is typed in the search box
    /// stays.
    private func clearFilters() {
        withAnimation(.smooth(duration: 0.25)) {
            let typed = filter.search
            filter = .standard
            filter.search = typed
        }
    }
}

// MARK: - Filter buttons

/// The words on a filter button, with a small arrow to say it opens a menu.
private struct FilterButtonLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.subheadline)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.semibold))
                .accessibilityHidden(true)
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 14)
        .frame(height: 40)
        .contentShape(.capsule)
    }
}

private extension View {
    /// The look shared by every filter button: a capsule of glass, filled
    /// with pale green when something is chosen on it, as on the Year page.
    func filterButton(isChosen: Bool) -> some View {
        self
            // Show the label as it is, rather than as Apple's own pop-up
            // button, which would draw a second frame around it.
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .fontWeight(isChosen ? .semibold : .regular)
            .glassEffect(.regular.tint((isChosen ? Theme.leafFill : Theme.card).opacity(isChosen ? 0.8 : 0.4)).interactive(),
                         in: .capsule)
            .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}

private extension PlantFilter.Choice {
    /// How a option reads in a menu: "Brassicas (14)".
    var menuText: String { "\(title) (\(count))" }
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
        // Tells Eira which plant is open. See EiraScreen.
        .eiraLooksAt("the plant \(EiraSight.name(plant.commonName, variety: plant.variety))",
                     short: EiraSight.name(plant.commonName, variety: plant.variety))
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
