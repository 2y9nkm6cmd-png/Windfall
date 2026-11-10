//
//  BedViews.swift
//  Windfall
//
//  The first screen backed by real data.
//
//  Two new things to learn here:
//
//  @Query          asks SwiftData for objects and keeps the view up to date.
//                  You never call it or refresh it — change the data anywhere
//                  in the app and every view holding a matching @Query redraws
//                  itself. It only works on @Model types.
//
//  @Environment(\.modelContext)
//                  the handle for *writing*. Inserting or deleting goes
//                  through the context. Saving is automatic, so there is no
//                  save() call to forget.
//

import SwiftUI
import SwiftData

// MARK: - Bed list

struct BedListView: View {

    /// Every bed, ordered as they sit on the plan. `filter` excludes
    /// retired beds — they still exist so old plantings resolve, but
    /// there is no reason to show them.
    @Query(filter: #Predicate<Bed> { $0.retiredAt == nil },
           sort: [SortDescriptor(\Bed.displayOrder)])
    private var beds: [Bed]

    @Environment(\.modelContext) private var context

    @State private var showingNewBed = false
    @State private var newBedName = ""
    @State private var newBedSections = 6
    @State private var newBedSite: GardenSite = .allotment

    var body: some View {
        Group {
            if beds.isEmpty {
                emptyState
            } else {
                bedList
            }
        }
        .navigationTitle("Beds")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewBed = true
                } label: {
                    Label("Add bed", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewBed) {
            newBedSheet
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No beds yet", systemImage: "square.grid.3x3")
        } description: {
            Text("Add your beds to start recording what grows where.")
        } actions: {
            Button("Set up the allotment") {
                createAllotmentBeds()
            }
            .buttonStyle(.borderedProminent)

            Button("Add a bed") {
                showingNewBed = true
            }
        }
    }

    // MARK: List

    private var bedList: some View {
        List {
            ForEach(GardenSite.allCases) { site in
                let sited = beds.filter { $0.site == site }
                if !sited.isEmpty {
                    Section(site.displayName) {
                        ForEach(sited) { bed in
                            NavigationLink(value: bed) {
                                BedRow(bed: bed)
                            }
                        }
                        .onDelete { offsets in
                            retire(sited, at: offsets)
                        }
                    }
                }
            }
        }
        .navigationDestination(for: Bed.self) { bed in
            BedDetailView(bed: bed)
        }
    }

    // MARK: New bed sheet

    private var newBedSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $newBedName, prompt: Text("Bed 5"))

                    Picker("Garden", selection: $newBedSite) {
                        ForEach(GardenSite.allCases) { site in
                            Text(site.displayName).tag(site)
                        }
                    }
                }

                Section {
                    Stepper("\(newBedSections) sections", value: $newBedSections, in: 1...26)
                } footer: {
                    Text("Sections are lettered A onwards, 1.2 m each.")
                }
            }
            .navigationTitle("New bed")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { resetNewBed() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addBed() }
                        .disabled(newBedName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: Actions

    private func addBed() {
        let bed = Bed(name: newBedName.trimmingCharacters(in: .whitespaces), site: newBedSite)
        bed.displayOrder = (beds.map(\.displayOrder).max() ?? -1) + 1
        bed.addSections(count: newBedSections)

        // insert() is the only step. SwiftData saves on its own.
        context.insert(bed)
        resetNewBed()
    }

    private func resetNewBed() {
        newBedName = ""
        newBedSections = 6
        newBedSite = .allotment
        showingNewBed = false
    }

    /// Sets up the four allotment beds with A–F sections, as on the plan.
    private func createAllotmentBeds() {
        for i in 1...4 {
            let bed = Bed(name: "Bed \(i)", site: .allotment)
            bed.displayOrder = i - 1
            bed.isRaised = true
            // Bed 4 has hügelkultur in the bottom, per the plan
            bed.hasHugelkultur = (i == 4)
            bed.addSections(count: 6)
            context.insert(bed)
        }
    }

    /// Retires rather than deletes, so planting history keeps its bed.
    private func retire(_ list: [Bed], at offsets: IndexSet) {
        for index in offsets {
            list[index].retiredAt = .now
        }
    }
}

// MARK: - Row

private struct BedRow: View {

    let bed: Bed

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(bed.name)
                .font(.headline)

            HStack(spacing: 6) {
                Text("^[\(bed.orderedSections.count) section](inflect: true)")

                if bed.isRaised {
                    Text("·")
                    Text("Raised")
                }
                if bed.hasHugelkultur {
                    Text("·")
                    Text("Hügelkultur")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Bed detail

struct BedDetailView: View {

    /// `@Bindable` lets the form write straight back into the model.
    /// Available because @Model types are Observable.
    @Bindable var bed: Bed

    @Environment(\.modelContext) private var context

    private let columns = [GridItem(.adaptive(minimum: 84), spacing: 8)]

    var body: some View {
        Form {
            Section("Sections") {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(bed.orderedSections) { section in
                        SectionTile(section: section)
                    }
                }
                .padding(.vertical, 4)

                Button {
                    addSection()
                } label: {
                    Label("Add section", systemImage: "plus")
                }
            }

            Section {
                NavigationLink {
                    BedCompanionCheckView(bed: bed)
                } label: {
                    Label("Check companions", systemImage: "square.on.square")
                }
            }

            Section("Details") {
                TextField("Name", text: $bed.name)

                Picker("Garden", selection: Binding(
                    get: { bed.site },
                    set: { bed.site = $0 }
                )) {
                    ForEach(GardenSite.allCases) { site in
                        Text(site.displayName).tag(site)
                    }
                }

                Toggle("Raised bed", isOn: $bed.isRaised)
                Toggle("Hügelkultur base", isOn: $bed.hasHugelkultur)
            }

            Section("Dimensions") {
                LabeledContent("Length") {
                    TextField("m", value: $bed.lengthMetres, format: .number)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Width") {
                    TextField("m", value: $bed.widthMetres, format: .number)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Notes") {
                TextField("Soil", text: Binding(
                    get: { bed.soilNotes ?? "" },
                    set: { bed.soilNotes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)

                TextField("Notes", text: Binding(
                    get: { bed.notes ?? "" },
                    set: { bed.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
            }
        }
        .navigationTitle(bed.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func addSection() {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let next = bed.orderedSections.count
        let section = BedSection()
        section.label = next < letters.count ? String(letters[next]) : "S\(next + 1)"
        section.displayOrder = next
        section.bed = self.bed
        bed.sections?.append(section)
    }
}

// MARK: - Section tile

private struct SectionTile: View {

    let section: BedSection

    /// Plantings that haven't finished. Computed rather than stored,
    /// so it can't fall out of step.
    private var activePlantings: [Planting] {
        (section.plantings ?? []).filter {
            $0.status != .finished && $0.status != .failed
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(section.label)
                .font(.title3.weight(.semibold))

            if let first = activePlantings.first?.plant?.commonName {
                Text(first)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            } else {
                Text("Empty")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(activePlantings.isEmpty
                      ? Color.secondary.opacity(0.10)
                      : Color.green.opacity(0.18))
        )
    }
}

// MARK: - Previews

#Preview("Bed list") {
    NavigationStack {
        BedListView()
    }
    .modelContainer(for: [Bed.self, BedSection.self, Planting.self, Plant.self],
                    inMemory: true)
}
