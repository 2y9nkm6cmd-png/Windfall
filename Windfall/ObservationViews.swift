//
//  ObservationViews.swift
//  Windfall
//
//  Recording a wildlife sighting.
//
//  The design principle running through this: a machine guess is never
//  promoted to a record. `provisionalID` and `confirmedID` stay separate,
//  and only the confirmed one is ever exported. The app can suggest; only
//  you can decide.
//

import SwiftUI
import SwiftData
import PhotosUI

// MARK: - List

struct ObservationListView: View {

    @Query(sort: [SortDescriptor(\WildlifeObservation.observedAt, order: .reverse)])
    private var observations: [WildlifeObservation]

    @Environment(\.modelContext) private var context

    @State private var newObservation: WildlifeObservation?
    @State private var search = ""
    @State private var groupFilter: TaxonGroup?

    private var filtered: [WildlifeObservation] {
        observations.filter { observation in
            if let groupFilter, observation.taxonGroup != groupFilter { return false }
            guard !search.isEmpty else { return true }
            let needle = search.lowercased()
            return (observation.bestAvailableName?.lowercased().contains(needle) ?? false)
                || (observation.associatedPlantName?.lowercased().contains(needle) ?? false)
        }
    }

    var body: some View {
        // Drawn like Today and Wildlife: the serif title and glass
        // cards. Until 13 November 2026 it was a plain list.
        GeometryReader { geometry in
            let isNarrow = geometry.size.width < 600
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .bottom, spacing: 10) {
                        ScreenHeader(title: "Sightings", detail: summary)
                        Button {
                            create()
                        } label: {
                            Label("New sighting", systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.glassProminent)
                        .tint(Theme.leaf)
                        .foregroundStyle(Theme.onLeaf)
                    }

                    groupChips

                    if filtered.isEmpty {
                        Text(observations.isEmpty
                             ? "No sightings yet. Record what you see: insects, birds, amphibians, anything."
                             : "No sightings match. Clear the search or choose \"All groups\".")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard()
                    }

                    // Two cards to a row where there is room.
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
                                             count: geometry.size.width >= 840 ? 2 : 1),
                              spacing: 12) {
                        ForEach(filtered) { observation in
                            NavigationLink(value: observation) {
                                ObservationRow(observation: observation)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete", role: .destructive) { context.delete(observation) }
                            }
                        }
                    }
                }
                .padding(.leading, isNarrow ? 16 : 14)
                .padding(.trailing, isNarrow ? 16 : 24)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .searchable(text: $search, prompt: "Search sightings")
        .navigationTitle("Sightings")
        .paperScreen()
        .navigationDestination(for: WildlifeObservation.self) {
            ObservationEditor(observation: $0)
        }
        // The form brings its own title and buttons (SheetPage).
        .sheet(item: $newObservation) { observation in
            ObservationEditor(observation: observation, isNew: true)
        }
    }

    /// "14 sightings · 2 to confirm".
    private var summary: String {
        let waiting = observations.filter { !$0.isConfirmed }.count
        let count = "\(observations.count) \(observations.count == 1 ? "sighting" : "sightings")"
        return waiting > 0 ? "\(count) · \(waiting) to confirm" : count
    }

    /// A row of buttons, one for each group that has a sighting.
    private var groupChips: some View {
        let present = TaxonGroup.allCases.filter { group in observations.contains { $0.taxonGroup == group } }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All groups", isOn: groupFilter == nil) { groupFilter = nil }
                ForEach(present) { group in
                    chip(group.displayName, isOn: groupFilter == group) { groupFilter = group }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(_ words: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(words)
                .font(.caption)
                .fontWeight(isOn ? .semibold : .regular)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint((isOn ? Theme.leafFill : Theme.card).opacity(isOn ? 0.9 : 0.5)), in: .capsule)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func create() {
        let observation = WildlifeObservation()
        observation.recorderName = UserDefaults.standard.string(forKey: "recorderName")
        observation.gridPrecisionMetres = UserDefaults.standard.integer(forKey: "gridPrecision")
        if observation.gridPrecisionMetres == 0 { observation.gridPrecisionMetres = 100 }
        context.insert(observation)
        newObservation = observation
    }
}

private struct ObservationRow: View {

    let observation: WildlifeObservation

    var body: some View {
        let name = observation.bestAvailableName ?? "Unidentified"
        HStack(alignment: .top, spacing: 12) {
            if let photo = observation.photos?.first {
                PhotoThumbnail(photo: photo, size: 52)
            } else {
                // The app's own drawing: a butterfly, a bee or a
                // ladybird if the name says so, otherwise binoculars.
                WIconView(RecentRecord.picture(forSighting: name, group: observation.taxonGroup?.displayName), size: 30)
                    .foregroundStyle(Theme.leaf)
                    .frame(width: 52, height: 52)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)

                Text(observation.observedAt, format: .dateTime.weekday(.abbreviated).day().month(.wide))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)

                if let plant = observation.associatedPlantName {
                    Text("On \(plant)")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }

                HStack(spacing: 6) {
                    if observation.isConfirmed {
                        StatusTag(text: "Confirmed", fill: Theme.leafFill)
                    } else {
                        StatusTag(text: "Provisional", fill: Theme.amber)
                    }
                    if observation.submittedToIRecord {
                        StatusTag(text: "Sent to iRecord", fill: Theme.leafFill)
                    }
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 4)
            WIconView(.chevronRight, size: 14)
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 14)
        .contentShape(.rect)
    }
}


struct ObservationEditor: View {

    @Bindable var observation: WildlifeObservation
    var isNew = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Fauna.commonName)]) private var fauna: [Fauna]
    @Query(sort: [SortDescriptor(\Plant.commonName)]) private var plants: [Plant]

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var speciesSearch = ""
    @State private var isLoadingPhotos = false

    /// Fauna matching what's been typed, active species first — a bee that
    /// isn't flying in February is a less likely match than one that is.
    private var suggestions: [Fauna] {
        guard speciesSearch.count >= 2 else { return [] }
        let needle = speciesSearch.lowercased()
        return fauna
            .filter {
                $0.commonName.lowercased().contains(needle)
                    || ($0.scientificName?.lowercased().contains(needle) ?? false)
            }
            .sorted { a, b in
                if a.isActiveThisMonth != b.isActiveThisMonth { return a.isActiveThisMonth }
                return a.commonName < b.commonName
            }
            .prefix(6)
            .map { $0 }
    }

    /// What this species is known to visit — shown once identified, so the
    /// association can be filled in with one tap.
    private var knownAssociations: [PlantFaunaLink] {
        guard let name = observation.commonName?.lowercased() else { return [] }
        return (fauna.first { $0.commonName.lowercased() == name }?.plantLinks ?? [])
    }

    /// True when it is shown in a sheet for something already recorded,
    /// which then needs a Done button of its own.
    var inSheet = false

    var body: some View {
        // The same cards serve three settings: a sheet for a new
        // sighting, a sheet for confirming an old one, and a page pushed
        // on from a list. Only the frame around the cards differs.
        // (Until 13 November 2026 this was a standard form, which
        // William said "doesn't match the vibe".)
        Group {
            if isNew {
                SheetPage("New sighting", detail: "What you saw, where and when.",
                          onDismiss: {
                              // Cancelling throws the unfinished record away.
                              context.delete(observation)
                              dismiss()
                          },
                          confirmTitle: "Save", onConfirm: { dismiss() }) {
                    SheetScroll { cards }
                }
            } else if inSheet {
                SheetPage(observation.bestAvailableName ?? "Sighting", detail: whenWords, dismissTitle: "Done") {
                    SheetScroll { cards }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ScreenHeader(title: observation.bestAvailableName ?? "Sighting", detail: whenWords)
                        cards
                    }
                    // A form reads best in a column, not across a wide window.
                    .frame(maxWidth: 640, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle("Sighting")
                .paperScreen()
            }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await loadPhotos(items) }
        }
    }

    private var whenWords: String {
        "Sighting · " + observation.observedAt.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
    }

    // MARK: The cards

    @ViewBuilder
    private var cards: some View {
        photosCard
        nameCard
        identificationCard
        detailsCard
        associationCard
        whereCard
        recordingCard
        if !observation.validationProblems.isEmpty {
            ProblemsCard(problems: observation.validationProblems,
                         footnote: "It can be saved as it is. These are only needed before it goes to iRecord.")
        }
    }

    private var photosCard: some View {
        SheetCard("Photos") {
            if let photos = observation.photos, !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photos) { photo in
                            PhotoThumbnail(photo: photo, size: 96)
                                .contextMenu {
                                    Button("Remove", role: .destructive) { context.delete(photo) }
                                }
                        }
                    }
                }
            }
            HStack(spacing: 10) {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 5, matching: .images) {
                    HStack(spacing: 8) {
                        WIconView(.photo, size: 18)
                        Text("Add photos")
                    }
                    .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.glass)
                .tint(Theme.leaf)
                if isLoadingPhotos {
                    ProgressView().controlSize(.small)
                }
            }
        }
    }

    private var nameCard: some View {
        SheetCard("What was it?") {
            FieldBox { TextField("Search the species list", text: $speciesSearch) }

            ForEach(suggestions) { match in
                Button {
                    apply(match)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(match.commonName)
                                .font(.subheadline)
                                .foregroundStyle(Theme.ink)
                            if let latin = match.scientificName {
                                Text(latin).font(.caption).italic()
                                    .foregroundStyle(Theme.inkSoft)
                            }
                        }
                        Spacer()
                        if !match.isActiveThisMonth {
                            StatusTag(text: "Out of season", fill: Theme.amber)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .background(Theme.leafFill.opacity(0.35), in: .rect(cornerRadius: 12))
            }

            named("Common name") {
                TextField("Such as Tree bumblebee", text: Binding(
                    get: { observation.commonName ?? "" },
                    set: { observation.commonName = $0.isEmpty ? nil : $0 }
                ))
            }
            named("Scientific name") {
                TextField("Such as Bombus hypnorum", text: Binding(
                    get: { observation.scientificName ?? "" },
                    set: { observation.scientificName = $0.isEmpty ? nil : $0 }
                ))
            }
        }
    }

    private var identificationCard: some View {
        SheetCard("Identification") {
            Text("How sure are you?")
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
            GlassSwitch(choices: Array(IDConfidence.allCases), selection: Binding(
                get: { observation.provisionalConfidence ?? .probable },
                set: { observation.provisionalConfidence = $0 }
            )) { $0.displayName }

            Button {
                setConfirmed(!observation.isConfirmed)
            } label: {
                HStack(spacing: 10) {
                    TickBox(isOn: observation.isConfirmed)
                    Text("I'm confident in this identification")
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(observation.isConfirmed ? .isSelected : [])

            Text("Only confirmed identifications are exported to iRecord. Leave this unticked if you are unsure. An unconfirmed record is still useful to you.")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private var detailsCard: some View {
        SheetCard("Details") {
            SettingRow("When") {
                DatePicker("When", selection: $observation.observedAt)
                    .labelsHidden()
            }
            SettingRow("How many") {
                NumberStepper(value: Binding(
                    get: { max(observation.quantity ?? 1, 1) },
                    set: { observation.quantity = $0 }
                ), range: 1...999)
            }
            SettingRow("Life stage") {
                ChoiceMenu(shown: observation.lifeStage ?? "Adult") {
                    Picker("Life stage", selection: Binding(
                        get: { observation.lifeStage ?? "Adult" },
                        set: { observation.lifeStage = $0 }
                    )) {
                        ForEach(["Adult", "Larva", "Nymph", "Egg", "Pupa", "Juvenile", "Not recorded"], id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                }
            }
            SettingRow("Group") {
                ChoiceMenu(shown: (observation.taxonGroup ?? .insect).displayName) {
                    Picker("Group", selection: Binding(
                        get: { observation.taxonGroup ?? .insect },
                        set: { observation.taxonGroup = $0 }
                    )) {
                        ForEach(TaxonGroup.allCases) { each in
                            Text(each.displayName).tag(each)
                        }
                    }
                }
            }
        }
    }

    private var associationCard: some View {
        SheetCard("On a plant?") {
            SettingRow("Which plant") {
                ChoiceMenu(shown: observation.associatedPlant?.displayName ?? observation.associatedPlantName ?? "None") {
                    Picker("Which plant", selection: $observation.associatedPlant) {
                        Text("None").tag(Plant?.none)
                        ForEach(plants) { plant in
                            Text(plant.displayName).tag(Plant?.some(plant))
                        }
                    }
                }
            }
            .onChange(of: observation.associatedPlant) { _, plant in
                observation.associatedPlantName = plant?.commonName
            }

            named("What was it doing?") {
                TextField("Feeding, resting, laying eggs", text: Binding(
                    get: { observation.interaction ?? "" },
                    set: { observation.interaction = $0.isEmpty ? nil : $0 }
                ))
            }

            if !knownAssociations.isEmpty {
                Text("Known from your reference data. Tap one to fill it in.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                ForEach(knownAssociations) { link in
                    Button {
                        observation.associatedPlantName = link.plantName
                        observation.associatedPlant = link.plant
                        observation.interaction = link.relationship.displayName
                    } label: {
                        HStack {
                            Text(link.plantName)
                                .font(.subheadline)
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text(link.relationship.displayName)
                                .font(.caption)
                                .foregroundStyle(Theme.inkSoft)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .background(Theme.leafFill.opacity(0.35), in: .rect(cornerRadius: 12))
                }
            }
        }
    }

    private var whereCard: some View {
        SheetCard("Where") {
            FieldBox {
                GridReferenceField(
                    gridReference: $observation.gridReference,
                    latitude: $observation.latitude,
                    longitude: $observation.longitude,
                    precisionMetres: observation.gridPrecisionMetres
                )
            }
            Text("How exact")
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
            GlassSwitch(choices: [10, 100, 1000], selection: $observation.gridPrecisionMetres) { metres in
                metres >= 1000 ? "1 km" : "\(metres) m"
            }
        }
    }

    private var recordingCard: some View {
        SheetCard("Recording") {
            named("Recorder") {
                TextField("Your name, for iRecord", text: Binding(
                    get: { observation.recorderName ?? "" },
                    set: { observation.recorderName = $0.isEmpty ? nil : $0 }
                ))
            }
            named("Notes") {
                TextField("Anything else worth keeping", text: Binding(
                    get: { observation.notes ?? "" },
                    set: { observation.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(2...6)
            }
        }
    }

    /// A small label over a box to type in.
    private func named<Field: View>(_ label: String, @ViewBuilder field: @escaping () -> Field) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
            FieldBox(content: field)
        }
    }

    /// Ticks or unticks "confident". Ticking records what it was
    /// confirmed as and when.
    private func setConfirmed(_ confirmed: Bool) {
        if confirmed {
            observation.confirmedID = observation.acceptedScientificName
                ?? observation.scientificName
                ?? observation.commonName
            observation.confirmedAt = .now
        } else {
            observation.confirmedID = nil
            observation.confirmedAt = nil
        }
    }

    private func apply(_ match: Fauna) {
        observation.commonName     = match.commonName
        observation.scientificName = match.scientificName
        observation.acceptedScientificName = match.acceptedName ?? match.scientificName
        observation.family         = match.family
        observation.schemeGroupName = match.recordingGroup
        observation.taxonGroup     = match.taxonGroup ?? .insect
        observation.provisionalSource = .speciesLookup
        speciesSearch = ""
    }

    @MainActor
    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        isLoadingPhotos = true
        defer { isLoadingPhotos = false; pickerItems = [] }

        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let photo = Photo()
            photo.imageData = data
            photo.thumbnailData = DiaryEntryEditor.thumbnail(from: data)
            photo.sourceLocalIdentifier = item.itemIdentifier
            photo.observation = observation
            observation.photos?.append(photo)
        }
    }
}

/// A menu drawn as one of the app's own boxes: the chosen value and a
/// small arrow. `choices` is usually a Picker, which gives a list with a
/// tick beside the chosen one.
struct ChoiceMenu<Choices: View>: View {

    let shown: String
    @ViewBuilder let choices: () -> Choices

    var body: some View {
        Menu {
            choices()
                .pickerStyle(.inline)
                .labelsHidden()
        } label: {
            HStack(spacing: 6) {
                Text(shown)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .font(.subheadline)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.card.opacity(0.7), in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Theme.hairline)
            }
            .contentShape(.rect)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }
}
