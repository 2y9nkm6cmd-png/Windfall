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
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNew = true
                } label: {
                    Label("New sowing", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Toggle("Show finished", isOn: $showFinished)
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
        NavigationStack {
            Form {
                Section("Plant") {
                    if let selectedPlant {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(selectedPlant.displayName)
                                if let latin = selectedPlant.latinName {
                                    Text(latin).font(.caption).italic()
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Change") { self.selectedPlant = nil }
                                .font(.caption)
                        }

                        if let round = suggestedRound {
                            Label("Succession round \(round)", systemImage: "repeat")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        TextField("Search plants", text: $plantSearch)
                        ForEach(matchingPlants.prefix(8)) { plant in
                            Button {
                                selectedPlant = plant
                                plantSearch = ""
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(plant.displayName)
                                    if let latin = plant.latinName {
                                        Text(latin).font(.caption).italic()
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Where") {
                    Picker("Bed", selection: $selectedBed) {
                        Text("Not placed").tag(Bed?.none)
                        ForEach(beds) { bed in
                            Text(bed.name).tag(Bed?.some(bed))
                        }
                    }
                    .onChange(of: selectedBed) { _, _ in selectedSections = [] }

                    if let selectedBed {
                        SectionPicker(bed: selectedBed, selected: $selectedSections)
                    }
                }

                Section("Sowing") {
                    DatePicker("Date sown", selection: $dateSown, displayedComponents: .date)

                    Picker("Location", selection: $sowingLocation) {
                        Text("Indoors").tag(SowingLocation.indoors)
                        Text("Outdoors").tag(SowingLocation.outdoors)
                        Text("Under cover").tag(SowingLocation.undercover)
                        Text("Direct sown").tag(SowingLocation.directSown)
                    }

                    LabeledContent("Quantity sown") {
                        TextField("seeds", text: $quantitySown)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                    }
                }

                Section("Notes") {
                    TextField("Anything worth recording", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("New sowing")
            .paperScreen()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(selectedPlant == nil)
                }
            }
        }
    }

    private func save() {
        guard let selectedPlant else { return }

        let planting = Planting()
        planting.plant = selectedPlant
        planting.dateSown = dateSown
        planting.sowingLocation = sowingLocation
        planting.status = .sown
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
                .foregroundStyle(.secondary)

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
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selected.contains(section.id)
                                          ? Color.accentColor.opacity(0.25)
                                          : Color.secondary.opacity(0.10))
                            )
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

struct HarvestEditor: View {

    let planting: Planting

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var date = Date.now
    @State private var quantity = ""
    @State private var unit: HarvestUnit = .grams
    @State private var destination: HarvestDestination = .eaten
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)

                LabeledContent("Quantity") {
                    TextField("0", text: $quantity)
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }

                Picker("Unit", selection: $unit) {
                    ForEach(HarvestUnit.allCases) { u in
                        Text(u.displayName).tag(u)
                    }
                }

                Section {
                    Picker("Destination", selection: $destination) {
                        ForEach(HarvestDestination.allCases) { d in
                            Text(d.rawValue.capitalized).tag(d)
                        }
                    }
                } footer: {
                    Text("Recording where it went is what separates what you grew from what you actually used.")
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("Harvest")
            .paperScreen()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(Double(quantity) == nil)
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
