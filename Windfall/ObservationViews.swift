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
        List {
            if observations.isEmpty {
                ContentUnavailableView {
                    Label("No sightings yet", systemImage: "ant")
                } description: {
                    Text("Record what you see — insects, birds, amphibians, anything.")
                } actions: {
                    Button("Record a sighting") { create() }
                        .buttonStyle(.borderedProminent)
                }
            }

            ForEach(filtered) { observation in
                NavigationLink(value: observation) {
                    ObservationRow(observation: observation)
                }
            }
            .onDelete { offsets in
                for i in offsets { context.delete(filtered[i]) }
            }
        }
        .searchable(text: $search, prompt: "Search sightings")
        .navigationTitle("Sightings")
        .paperScreen()
        .navigationDestination(for: WildlifeObservation.self) {
            ObservationEditor(observation: $0)
        }
        .toolbar {
            ToolbarItem(placement: .besideMain) {
                Picker("Group", selection: $groupFilter) {
                    Text("All groups").tag(TaxonGroup?.none)
                    ForEach(TaxonGroup.allCases) { group in
                        Text(group.displayName).tag(TaxonGroup?.some(group))
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { create() } label: {
                    Label("New sighting", systemImage: "plus")
                }
            }
        }
        .sheet(item: $newObservation) { observation in
            NavigationStack {
                ObservationEditor(observation: observation, isNew: true)
            }
        }
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
        HStack(spacing: 10) {
            if let photo = observation.photos?.first {
                PhotoThumbnail(photo: photo, size: 48)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(observation.bestAvailableName ?? "Unidentified")
                    .font(.subheadline.weight(.medium))

                if let plant = observation.associatedPlantName {
                    Text("on \(plant)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    Text(observation.observedAt, format: .dateTime.day().month())

                    if !observation.isConfirmed {
                        Label("Unconfirmed", systemImage: "questionmark.circle")
                            .foregroundStyle(.orange)
                    }
                    if observation.submittedToIRecord {
                        Image(systemName: "checkmark.seal").foregroundStyle(.green)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Editor

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

    var body: some View {
        Form {
            Section("Photos") {
                if let photos = observation.photos, !photos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(photos) { photo in
                                PhotoThumbnail(photo: photo, size: 96)
                                    .contextMenu {
                                        Button("Remove", role: .destructive) {
                                            context.delete(photo)
                                        }
                                    }
                            }
                        }
                    }
                }

                PhotosPicker(selection: $pickerItems, maxSelectionCount: 5, matching: .images) {
                    Label("Add photos", systemImage: "camera")
                }

                if isLoadingPhotos {
                    HStack { ProgressView(); Text("Loading…").foregroundStyle(.secondary) }
                }
            }

            Section("What was it?") {
                TextField("Search species", text: $speciesSearch)

                ForEach(suggestions) { match in
                    Button {
                        apply(match)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(match.commonName)
                                if let latin = match.scientificName {
                                    Text(latin).font(.caption).italic()
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if !match.isActiveThisMonth {
                                Text("out of season")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                TextField("Common name", text: Binding(
                    get: { observation.commonName ?? "" },
                    set: { observation.commonName = $0.isEmpty ? nil : $0 }
                ))

                TextField("Scientific name", text: Binding(
                    get: { observation.scientificName ?? "" },
                    set: { observation.scientificName = $0.isEmpty ? nil : $0 }
                ))
            }

            Section {
                Picker("Confidence", selection: Binding(
                    get: { observation.provisionalConfidence ?? .probable },
                    set: { observation.provisionalConfidence = $0 }
                )) {
                    ForEach(IDConfidence.allCases) { c in
                        Text(c.displayName).tag(c)
                    }
                }

                Toggle("I'm confident in this identification", isOn: Binding(
                    get: { observation.isConfirmed },
                    set: { confirmed in
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
                ))
            } header: {
                Text("Identification")
            } footer: {
                Text("Only confirmed identifications are exported to iRecord. Leave this off if you're unsure — an unconfirmed record is still useful to you.")
            }

            Section("Details") {
                DatePicker("When", selection: $observation.observedAt)

                LabeledContent("How many") {
                    TextField("1", value: $observation.quantity, format: .number)
                        .multilineTextAlignment(.trailing)
                }

                Picker("Life stage", selection: Binding(
                    get: { observation.lifeStage ?? "Adult" },
                    set: { observation.lifeStage = $0 }
                )) {
                    ForEach(["Adult", "Larva", "Nymph", "Egg", "Pupa", "Juvenile", "Not recorded"], id: \.self) {
                        Text($0).tag($0)
                    }
                }

                Picker("Group", selection: Binding(
                    get: { observation.taxonGroup ?? .insect },
                    set: { observation.taxonGroup = $0 }
                )) {
                    ForEach(TaxonGroup.allCases) { g in
                        Text(g.displayName).tag(g)
                    }
                }
            }

            Section {
                Picker("On which plant", selection: $observation.associatedPlant) {
                    Text("None").tag(Plant?.none)
                    ForEach(plants) { plant in
                        Text(plant.displayName).tag(Plant?.some(plant))
                    }
                }
                .onChange(of: observation.associatedPlant) { _, plant in
                    observation.associatedPlantName = plant?.commonName
                }

                TextField("What was it doing?", text: Binding(
                    get: { observation.interaction ?? "" },
                    set: { observation.interaction = $0.isEmpty ? nil : $0 }
                ))

                if !knownAssociations.isEmpty {
                    ForEach(knownAssociations) { link in
                        Button {
                            observation.associatedPlantName = link.plantName
                            observation.associatedPlant = link.plant
                            observation.interaction = link.relationship.displayName
                        } label: {
                            HStack {
                                Text(link.plantName)
                                Spacer()
                                Text(link.relationship.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("Association")
            } footer: {
                if !knownAssociations.isEmpty {
                    Text("Known associations from your reference data — tap to fill in.")
                }
            }

            Section("Where") {
                GridReferenceField(
                    gridReference: $observation.gridReference,
                    latitude: $observation.latitude,
                    longitude: $observation.longitude,
                    precisionMetres: observation.gridPrecisionMetres
                )

                Picker("Precision", selection: $observation.gridPrecisionMetres) {
                    Text("10 m").tag(10)
                    Text("100 m").tag(100)
                    Text("1 km").tag(1000)
                }
            }

            Section("Recording") {
                TextField("Recorder", text: Binding(
                    get: { observation.recorderName ?? "" },
                    set: { observation.recorderName = $0.isEmpty ? nil : $0 }
                ))

                TextField("Notes", text: Binding(
                    get: { observation.notes ?? "" },
                    set: { observation.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
            }

            if !observation.validationProblems.isEmpty {
                Section("Not ready for iRecord") {
                    ForEach(observation.validationProblems, id: \.self) { problem in
                        Label(problem, systemImage: "exclamationmark.circle")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .navigationTitle(isNew ? "New sighting" : "Sighting")
        .paperScreen()
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if isNew {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        context.delete(observation)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { dismiss() }
                }
            }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await loadPhotos(items) }
        }
    }

    /// Fills in everything the reference data knows about this species.
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
