//
//  PlantingViews.swift
//  Windfall
//
//  Sowing something, and everything that happens to it afterwards.
//
//  This is the screen the rest of the app hangs off. A Planting is the
//  join between a Plant (reference data) and a piece of ground, and
//  harvests, phenology and problems all point back at it.
//

import SwiftUI
import SwiftData

// MARK: - Planting list

struct PlantingListView: View {

    @Query(sort: [SortDescriptor(\Planting.dateSown, order: .reverse)])
    private var plantings: [Planting]

    @Environment(\.modelContext) private var context

    @State private var showingNew = false
    @State private var showFinished = false

    private var visible: [Planting] {
        showFinished
            ? plantings
            : plantings.filter { $0.status != .finished && $0.status != .failed }
    }

    var body: some View {
        List {
            if visible.isEmpty {
                ContentUnavailableView {
                    Label("Nothing sown yet", systemImage: "leaf")
                } description: {
                    Text("Record a sowing to start tracking it through to harvest.")
                } actions: {
                    Button("Record a sowing") { showingNew = true }
                        .buttonStyle(.borderedProminent)
                }
            }

            ForEach(visible) { planting in
                NavigationLink(value: planting) {
                    PlantingRow(planting: planting)
                }
            }
            .onDelete { offsets in
                for i in offsets { context.delete(visible[i]) }
            }
        }
        .navigationTitle("Sowings")
        .paperScreen()
        .navigationDestination(for: Planting.self) { PlantingDetailView(planting: $0) }
        .toolbar {
            ToolbarItem(placement: .besideMain) {
                Toggle("Show finished", isOn: $showFinished)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNew = true
                } label: {
                    Label("New sowing", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNew) {
            NewPlantingView()
        }
    }
}

private struct PlantingRow: View {

    let planting: Planting

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(planting.plant?.displayName ?? "Unknown plant")
                    .font(.headline)

                if let round = planting.successionRound {
                    Text("#\(round)")
                        .font(.caption)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.secondary.opacity(0.15), in: Capsule())
                }

                Spacer()

                StatusBadge(status: planting.status)
            }

            if !planting.bedNames.isEmpty {
                Text(planting.bedNames)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                if let sown = planting.dateSown {
                    Label(sown.formatted(.dateTime.day().month()), systemImage: "calendar")
                }
                if planting.totalHarvestGrams > 0 {
                    Label("\((planting.totalHarvestGrams / 1000).formatted(.number.precision(.fractionLength(0...2)))) kg",
                          systemImage: "basket")
                }
                if let rate = planting.germinationRate {
                    Label("\(Int(rate * 100))% up", systemImage: "chart.line.uptrend.xyaxis")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct StatusBadge: View {
    let status: PlantingStatus

    var body: some View {
        Text(label)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(colour.opacity(0.18), in: Capsule())
            .foregroundStyle(colour)
    }

    private var label: String {
        switch status {
        case .planned:    return "Planned"
        case .sown:       return "Sown"
        case .germinated: return "Up"
        case .plantedOut: return "Planted out"
        case .growing:    return "Growing"
        case .harvesting: return "Harvesting"
        case .finished:   return "Finished"
        case .failed:     return "Failed"
        }
    }

    private var colour: Color {
        switch status {
        case .planned:                return .gray
        case .sown, .germinated:      return .blue
        case .plantedOut, .growing:   return .green
        case .harvesting:             return .orange
        case .finished:               return .secondary
        case .failed:                 return .red
        }
    }
}

// MARK: - New planting

struct NewPlantingView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Plant.commonName)]) private var plants: [Plant]
    @Query(filter: #Predicate<Bed> { $0.retiredAt == nil },
           sort: [SortDescriptor(\Bed.displayOrder)]) private var beds: [Bed]

    @State private var selectedPlant: Plant?
    @State private var selectedBed: Bed?
    @State private var selectedSections: Set<UUID> = []
    @State private var sowingLocation: SowingLocation = .outdoors
    @State private var dateSown = Date.now
    @State private var quantitySown = ""
    @State private var notes = ""
    @State private var plantSearch = ""
    /// The plant that was chosen before "Choose another" was pressed,
    /// so there is a way back to it.
    @State private var previousPlant: Plant?

    // How it was started, and its parents if it is saved or crossed
    // seed. Only asked for plants where the answer matters: see
    // SeedTruth.swift.
    @State private var begun: PlantingStart = .packetSeed
    @State private var pollenParent = ""
    @State private var crossedByHand = false
    /// The recorded cross this seed came from, if one was picked.
    @State private var chosenCross: PlantCross?

    /// Every cross on record. See Crosses.swift.
    @Query(sort: [SortDescriptor(\PlantCross.date, order: .reverse)]) private var crosses: [PlantCross]

    /// The crosses whose seed this could be: made on this plant first,
    /// then on others of its kind.
    private var offeredCrosses: [PlantCross] {
        guard let selectedPlant else { return [] }
        let lines = crosses.map {
            CrossBook.Line(id: $0.id, seedParentKey: $0.seedParentKey, seedParentName: $0.seedParentName, date: $0.date)
        }
        let order = CrossBook.offered(forPlantKey: selectedPlant.id.uuidString,
                                      named: selectedPlant.commonName, from: lines)
        return order.compactMap { wanted in crosses.first { $0.id == wanted } }
    }

    /// How the chosen plant behaves from seed.
    private var habit: SeedHabit {
        selectedPlant.map { SeedTruth.habit(commonName: $0.commonName) } ?? .notKnown
    }

    private var isF1: Bool { SeedTruth.isF1(variety: selectedPlant?.variety) }

    /// The ways of starting on offer for this plant. Empty means the
    /// form does not ask.
    private var starts: [PlantingStart] { SeedTruth.starts(for: habit, isF1: isF1) }

    /// True when a tree, a plant or a tuber is going in, not seed.
    private var isPlanting: Bool { !starts.isEmpty && begun == .plant }

    /// Other varieties of the same plant, to offer as the pollen parent.
    /// "Apple (Cider)" and "Apple" count as the same plant.
    private var relatives: [Plant] {
        guard let selectedPlant else { return [] }
        func base(_ name: String) -> String {
            (name.split(separator: "(").first.map(String.init) ?? name)
                .trimmingCharacters(in: .whitespaces).lowercased()
        }
        let wanted = base(selectedPlant.commonName)
        return plants.filter { $0.id != selectedPlant.id && base($0.commonName) == wanted }
    }

    private var matchingPlants: [Plant] {
        guard !plantSearch.isEmpty else { return plants }
        let needle = plantSearch.lowercased()
        return plants.filter {
            $0.commonName.lowercased().contains(needle)
                || ($0.latinName?.lowercased().contains(needle) ?? false)
        }
    }

    /// Next succession round for this plant this year — so carrots sown
    /// every ten days number themselves.
    private var suggestedRound: Int? {
        guard let selectedPlant else { return nil }
        let year = Calendar.current.component(.year, from: dateSown)
        let thisYear = (selectedPlant.plantings ?? []).filter {
            guard let sown = $0.dateSown else { return false }
            return Calendar.current.component(.year, from: sown) == year
        }
        return thisYear.isEmpty ? nil : thisYear.count + 1
    }

    var body: some View {
        // Built from the pieces in SheetParts.swift, so that it matches
        // the screen it is opened from. It was a standard Form.
        SheetPage("New sowing",
                  confirmTitle: "Save",
                  canConfirm: selectedPlant != nil,
                  onConfirm: save) {
            SheetScroll {
                SheetCard("Plant") {
                    if let selectedPlant {
                        HStack {
                            plantWords(selectedPlant)
                            Spacer()
                            Button("Choose another") {
                                previousPlant = selectedPlant
                                self.selectedPlant = nil
                            }
                            .buttonStyle(QuietGlassButton())
                        }
                        if let round = suggestedRound {
                            Text("Succession round \(round)")
                                .font(.caption)
                                .foregroundStyle(Theme.inkSoft)
                        }
                    } else {
                        // The way back, if a plant had been chosen
                        // before the list was opened again.
                        if let previousPlant {
                            Button {
                                selectedPlant = previousPlant
                                plantSearch = ""
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "chevron.left")
                                        .font(.caption.weight(.semibold))
                                    Text("Back to \(previousPlant.displayName)")
                                }
                            }
                            .buttonStyle(QuietGlassButton())
                        }
                        FieldBox {
                            TextField("Search plants", text: $plantSearch)
                        }
                        // The first eight matches, each a row to tap.
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(matchingPlants.prefix(8)) { plant in
                                Button {
                                    selectedPlant = plant
                                    plantSearch = ""
                                } label: {
                                    plantWords(plant)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 7)
                                        .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                Divider()
                                    .overlay(Theme.hairline)
                            }
                        }
                        if matchingPlants.isEmpty {
                            Text("No plant in the library matches that.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                }

                if selectedPlant != nil, !starts.isEmpty {
                    startedCard
                }

                SheetCard("Where") {
                    SettingRow("Bed") {
                        Picker("Bed", selection: $selectedBed) {
                            Text("Not placed").tag(Bed?.none)
                            ForEach(beds) { bed in
                                Text(bed.name).tag(Bed?.some(bed))
                            }
                        }
                        .labelsHidden()
                        .onChange(of: selectedBed) { _, _ in selectedSections = [] }
                    }

                    if let selectedBed {
                        SectionPicker(bed: selectedBed, selected: $selectedSections)
                    }
                }

                SheetCard(isPlanting ? "Planting" : "Sowing") {
                    SettingRow(isPlanting ? "Date planted" : "Date sown") {
                        DatePicker("Date", selection: $dateSown, displayedComponents: .date)
                            .labelsHidden()
                    }

                    // Indoors, outdoors and so on are about seed. A tree
                    // going into the ground is not asked.
                    if !isPlanting {
                        GlassSwitch(choices: SowingLocation.allCases, selection: $sowingLocation) { $0.words }
                    }

                    SettingRow(isPlanting ? "How many" : "Quantity sown") {
                        FieldBox {
                            TextField(isPlanting ? "plants" : "seeds", text: $quantitySown)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                        }
                    }
                }

                SheetCard("Notes") {
                    FieldBox {
                        TextField("Anything worth recording", text: $notes, axis: .vertical)
                            .lineLimit(2...5)
                    }
                }
            }
        }
    }

    /// A plant's name with its Latin name underneath.
    /// Asks how it was started, for a plant where that matters, and for
    /// seed that was saved or crossed, what its parents were.
    private var startedCard: some View {
        SheetCard("How it was started") {
            GlassSwitch(choices: starts, selection: $begun) { SeedTruth.title(of: $0, habit: habit) }

            if let advice = SeedTruth.advice(habit: habit, isF1: isF1, begun: begun,
                                             name: selectedPlant?.commonName ?? "") {
                Text(advice)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if begun == .savedSeed {
                // Crosses written down when they were made. Picking one
                // fills in the parents below from it.
                if !offeredCrosses.isEmpty {
                    SettingRow("From a cross you recorded") {
                        ChoiceMenu(shown: chosenCross?.title ?? "Choose") {
                            ForEach(offeredCrosses) { crossing in
                                Button("\(crossing.title), \(crossing.date.formatted(.dateTime.year()))") {
                                    chosenCross = crossing
                                    pollenParent = crossing.pollenParentName ?? ""
                                    crossedByHand = crossing.wasByHand
                                }
                            }
                            Button("None of these") { chosenCross = nil }
                        }
                    }
                }

                SettingRow("Seed parent") {
                    Text(chosenCross?.seedParentName ?? selectedPlant?.displayName ?? "")
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.trailing)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Pollen parent, if you know it")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                    FieldBox {
                        TextField("Not known (open pollinated)", text: $pollenParent)
                    }
                    if !relatives.isEmpty {
                        // A menu of the other varieties in the library.
                        // Choosing one writes its name in the box above.
                        ChoiceMenu(shown: "Choose from your plants") {
                            ForEach(relatives) { relative in
                                Button(relative.displayName) { pollenParent = relative.displayName }
                            }
                        }
                    }
                }

                Button {
                    crossedByHand.toggle()
                } label: {
                    HStack(spacing: 10) {
                        TickBox(isOn: crossedByHand)
                        Text("I crossed them by hand")
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink)
                        Spacer(minLength: 0)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(crossedByHand ? .isSelected : [])
            }
        }
        // A different plant has different choices. Start from its usual one.
        .onChange(of: selectedPlant?.id, initial: true) { _, _ in
            begun = starts.first ?? .packetSeed
            pollenParent = ""
            crossedByHand = false
            chosenCross = nil
        }
    }

    private func plantWords(_ plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(plant.displayName)
                .foregroundStyle(Theme.ink)
            if let latin = plant.latinName {
                Text(latin)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private func save() {
        guard let selectedPlant else { return }

        let planting = Planting()
        planting.plant = selectedPlant
        planting.dateSown = dateSown
        if starts.isEmpty {
            // Nothing was asked, so nothing is claimed.
            planting.sowingLocation = sowingLocation
            planting.status = .sown
        } else {
            planting.startedFrom = begun
            if begun == .plant {
                // A tree or a tuber in the ground is growing, not sown.
                planting.status = .growing
            } else {
                planting.sowingLocation = sowingLocation
                planting.status = .sown
            }
            if begun == .savedSeed {
                let pollen = pollenParent.trimmingCharacters(in: .whitespaces)
                // A recorded cross gives its own seed parent, which may
                // be another variety of the same kind of plant.
                planting.seedParentName = chosenCross?.seedParentName ?? selectedPlant.displayName
                planting.pollenParentName = pollen.isEmpty ? nil : pollen
                planting.wasHandCrossed = crossedByHand
                planting.crossKey = chosenCross?.id.uuidString
            }
        }
        planting.successionRound = suggestedRound
        planting.quantitySown = Int(quantitySown)
        planting.notes = notes.isEmpty ? nil : notes

        if let bed = selectedBed {
            planting.sections = bed.orderedSections.filter { selectedSections.contains($0.id) }
        }

        context.insert(planting)
        dismiss()
    }
}

// MARK: - Section picker

private struct SectionPicker: View {

    let bed: Bed
    @Binding var selected: Set<UUID>

    private let columns = [GridItem(.adaptive(minimum: 60), spacing: 6)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sections")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(bed.orderedSections) { section in
                    Button {
                        if selected.contains(section.id) {
                            selected.remove(section.id)
                        } else {
                            selected.insert(section.id)
                        }
                    } label: {
                        Text(section.label)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(selected.contains(section.id) ? Theme.leafFill : Theme.card.opacity(0.7),
                                        in: .rect(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Theme.hairline)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Planting detail

struct PlantingDetailView: View {

    @Bindable var planting: Planting

    @Environment(\.modelContext) private var context

    @State private var addingHarvest = false
    @State private var addingPhenology = false
    @State private var addingProblem = false

    var body: some View {
        Form {
            Section {
                Picker("Status", selection: Binding(
                    get: { planting.status },
                    set: { planting.status = $0 }
                )) {
                    ForEach(PlantingStatus.allCases) { status in
                        Text(String(describing: status).capitalized).tag(status)
                    }
                }

                if !planting.bedNames.isEmpty {
                    LabeledContent("Where", value: planting.bedNames)
                }
                if let round = planting.successionRound {
                    LabeledContent("Succession round", value: "\(round)")
                }
            }

            Section("Dates") {
                DatePicker("Sown", selection: Binding(
                    get: { planting.dateSown ?? .now },
                    set: { planting.dateSown = $0 }
                ), displayedComponents: .date)

                DatePicker("Germinated", selection: Binding(
                    get: { planting.dateGerminated ?? .now },
                    set: { planting.dateGerminated = $0 }
                ), displayedComponents: .date)

                DatePicker("Planted out", selection: Binding(
                    get: { planting.datePlantedOut ?? .now },
                    set: { planting.datePlantedOut = $0 }
                ), displayedComponents: .date)

                if let days = planting.daysToGermination {
                    LabeledContent("Days to germinate", value: "\(days)")
                }
            }

            Section("Numbers") {
                LabeledContent("Sown") {
                    TextField("0", value: $planting.quantitySown, format: .number)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Survived") {
                    TextField("0", value: $planting.quantitySurvived, format: .number)
                        .multilineTextAlignment(.trailing)
                }
                if let rate = planting.germinationRate {
                    LabeledContent("Germination rate", value: "\(Int(rate * 100))%")
                }
            }

            // MARK: Harvests
            Section {
                ForEach((planting.harvests ?? []).sorted { $0.date > $1.date }) { harvest in
                    HStack {
                        Text(harvest.date, format: .dateTime.day().month())
                        Spacer()
                        Text("\(harvest.quantity.formatted()) \(harvest.unit.displayName)")
                        if let destination = harvest.destination {
                            Text(destination.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    let sorted = (planting.harvests ?? []).sorted { $0.date > $1.date }
                    for i in offsets { context.delete(sorted[i]) }
                }

                Button {
                    addingHarvest = true
                } label: {
                    Label("Record a picking", systemImage: "basket")
                }
            } header: {
                HStack {
                    Text("Harvests")
                    Spacer()
                    if planting.totalHarvestGrams > 0 {
                        Text("\((planting.totalHarvestGrams / 1000).formatted(.number.precision(.fractionLength(0...2)))) kg total")
                            .font(.caption)
                            .textCase(nil)
                    }
                }
            }

            // MARK: Phenology
            Section("Flowering & fruiting") {
                ForEach((planting.phenologyEvents ?? []).sorted { $0.date > $1.date }) { event in
                    HStack {
                        Text(event.stage.displayName)
                        Spacer()
                        Text(event.date, format: .dateTime.day().month())
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    let sorted = (planting.phenologyEvents ?? []).sorted { $0.date > $1.date }
                    for i in offsets { context.delete(sorted[i]) }
                }

                Button {
                    addingPhenology = true
                } label: {
                    Label("Record a stage", systemImage: "camera.macro")
                }
            }

            // MARK: Problems
            Section("Pests & diseases") {
                ForEach((planting.pestDiseaseEvents ?? []).sorted { $0.date > $1.date }) { event in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(event.name)
                            Spacer()
                            Text(event.date, format: .dateTime.day().month())
                                .foregroundStyle(.secondary)
                        }
                        Text(event.severity.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    let sorted = (planting.pestDiseaseEvents ?? []).sorted { $0.date > $1.date }
                    for i in offsets { context.delete(sorted[i]) }
                }

                Button {
                    addingProblem = true
                } label: {
                    Label("Record a problem", systemImage: "exclamationmark.triangle")
                }
            }

            Section("Notes") {
                TextField("Notes", text: Binding(
                    get: { planting.notes ?? "" },
                    set: { planting.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(2...6)
            }
        }
        .navigationTitle(planting.plant?.commonName ?? "Sowing")
        .paperScreen()
        // Tells Eira which sowing is open. See EiraScreen.
        .eiraLooksAt("a sowing of \(planting.plant?.commonName ?? "a plant")",
                     short: "this sowing of \(planting.plant?.commonName ?? "a plant")")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $addingHarvest) { HarvestEditor(planting: planting) }
        .sheet(isPresented: $addingPhenology) { PhenologyEditor(planting: planting) }
        .sheet(isPresented: $addingProblem) { ProblemEditor(planting: planting) }
    }
}

// MARK: - Harvest editor

extension SowingLocation {
    /// Where a sowing was made, in plain words.
    var words: String {
        switch self {
        case .indoors: return "Indoors"
        case .outdoors: return "Outdoors"
        case .undercover: return "Under cover"
        case .directSown: return "Direct sown"
        }
    }
}

extension HarvestDestination {
    /// The destination in plain words: "Given away", not "Givenaway".
    var words: String {
        switch self {
        case .eaten: return "Eaten"
        case .stored: return "Stored"
        case .frozen: return "Frozen"
        case .preserved: return "Preserved"
        case .givenAway: return "Given away"
        case .sold: return "Sold"
        case .seedSaved: return "Seed saved"
        case .composted: return "Composted"
        case .lost: return "Lost"
        }
    }
}


struct HarvestEditor: View {

    let planting: Planting
    /// Set when this form was reached from a list of sowings in the
    /// same sheet. The plain button then reads "Back" and returns there.
    var onBack: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var date = Date.now
    @State private var quantity = ""
    @State private var unit: HarvestUnit = .grams
    @State private var destination: HarvestDestination = .eaten
    @State private var notes = ""

    /// What was sown and where, for the line under the title.
    private var sowingLine: String {
        let name = planting.plant?.displayName ?? "Unknown plant"
        return planting.bedNames.isEmpty ? name : "\(name). \(planting.bedNames)"
    }

    var body: some View {
        SheetPage("Harvest",
                  detail: sowingLine,
                  dismissTitle: onBack == nil ? "Cancel" : "Back",
                  onDismiss: onBack,
                  confirmTitle: "Save",
                  canConfirm: Double(quantity) != nil,
                  onConfirm: save) {
            SheetScroll {
                SheetCard("How much") {
                    SettingRow("Date") {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                    }
                    SettingRow("Quantity") {
                        FieldBox {
                            TextField("0", text: $quantity)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                        }
                    }
                    GlassSwitch(choices: HarvestUnit.allCases, selection: $unit) { $0.displayName }
                }

                SheetCard("Where it went") {
                    SettingRow("Destination") {
                        Picker("Destination", selection: $destination) {
                            ForEach(HarvestDestination.allCases) { place in
                                Text(place.words).tag(place)
                            }
                        }
                        .labelsHidden()
                    }
                    Text("Recording where it went is what separates what you grew from what you actually used.")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }

                SheetCard("Notes") {
                    FieldBox {
                        TextField("Optional", text: $notes, axis: .vertical)
                            .lineLimit(2...5)
                    }
                }
            }
        }
    }

    private func save() {
        guard let value = Double(quantity) else { return }
        let harvest = Harvest()
        harvest.date = date
        harvest.quantity = value
        harvest.unit = unit
        harvest.destination = destination
        harvest.notes = notes.isEmpty ? nil : notes
        harvest.planting = planting
        planting.harvests?.append(harvest)

        if planting.status == .growing || planting.status == .plantedOut {
            planting.status = .harvesting
        }
        dismiss()
    }
}

// MARK: - Phenology editor

struct PhenologyEditor: View {

    let planting: Planting

    @Environment(\.dismiss) private var dismiss

    @State private var date = Date.now
    @State private var stage: PhenologyStage = .firstFlower
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)

                Picker("Stage", selection: $stage) {
                    ForEach(PhenologyStage.allCases) { s in
                        Text(s.displayName).tag(s)
                    }
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                }

                Section {
                    Label("Bloom dates set against pollinator counts show whether what's flowering matches what's flying.",
                          systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Stage")
            .paperScreen()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let event = PhenologyEvent()
                        event.date = date
                        event.stage = stage
                        event.notes = notes.isEmpty ? nil : notes
                        event.planting = planting
                        planting.phenologyEvents?.append(event)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Problem editor

struct ProblemEditor: View {

    let planting: Planting

    @Environment(\.dismiss) private var dismiss

    @State private var date = Date.now
    @State private var kind: ProblemKind = .pest
    @State private var name = ""
    @State private var severity: ProblemSeverity = .light
    @State private var treatment = ""

    /// What the spreadsheet says this plant is prone to — offered as
    /// suggestions rather than left for you to type from memory.
    private var likely: [String] {
        let source = kind == .pest
            ? planting.plant?.knownPests
            : planting.plant?.knownDiseases
        guard let source else { return [] }
        return source
            .components(separatedBy: CharacterSet(charactersIn: ",;"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)

                Picker("Type", selection: $kind) {
                    Text("Pest").tag(ProblemKind.pest)
                    Text("Disease").tag(ProblemKind.disease)
                    Text("Disorder").tag(ProblemKind.disorder)
                    Text("Damage").tag(ProblemKind.damage)
                }

                TextField("What is it?", text: $name)

                if !likely.isEmpty {
                    Section("Known for this plant") {
                        ForEach(likely, id: \.self) { suggestion in
                            Button(suggestion) { name = suggestion }
                        }
                    }
                }

                Picker("Severity", selection: $severity) {
                    ForEach(ProblemSeverity.allCases) { s in
                        Text(s.rawValue.capitalized).tag(s)
                    }
                }

                Section("Treatment") {
                    TextField("What did you do?", text: $treatment, axis: .vertical)
                }
            }
            .navigationTitle("Problem")
            .paperScreen()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let event = PestDiseaseEvent()
                        event.date = date
                        event.kind = kind
                        event.name = name
                        event.severity = severity
                        event.treatment = treatment.isEmpty ? nil : treatment
                        event.planting = planting
                        planting.pestDiseaseEvents?.append(event)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
