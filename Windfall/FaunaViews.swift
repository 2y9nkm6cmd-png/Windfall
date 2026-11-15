//
//  FaunaViews.swift
//  Windfall
//
//  Browsing the species reference, and the questions it can now answer:
//  what visits this plant, what should I plant for this animal, and which
//  flower shapes is my garden missing.
//
//  Since 15 November 2026 the list also opens the UK wildlife reference
//  (WildlifeBookViews.swift), and each of William's own species shows the
//  drawing of its kind from it.
//

import SwiftUI
import SwiftData

// MARK: - Fauna list

struct FaunaListView: View {

    @Query(sort: [SortDescriptor(\Fauna.commonName)]) private var fauna: [Fauna]
    @Query private var links: [PlantFaunaLink]
    @Query private var shapes: [FlowerShape]
    @Query private var cascades: [Cascade]

    @State private var search = ""
    @State private var activeOnly = false

    private var filtered: [Fauna] {
        fauna.filter { animal in
            if activeOnly && !animal.isActiveThisMonth { return false }
            guard !search.isEmpty else { return true }
            let needle = search.lowercased()
            return animal.commonName.lowercased().contains(needle)
                || (animal.scientificName?.lowercased().contains(needle) ?? false)
                || (animal.recordingGroup?.lowercased().contains(needle) ?? false)
        }
    }

    var body: some View {
        List {
            if fauna.isEmpty {
                ContentUnavailableView {
                    Label("No reference data", systemImage: "books.vertical")
                } description: {
                    Text("Import it from Settings to look species up and see what they visit.")
                }
            }

            // The UK wildlife reference: every animal you could meet,
            // by kind, each kind with a drawing (WildlifeBookViews.swift).
            // It ships inside the app and is not part of the records.
            if !WildlifeReference.shared.animals.isEmpty {
                Section {
                    NavigationLink {
                        WildlifeBookView()
                    } label: {
                        HStack(spacing: 12) {
                            WildlifeKindPicture(slug: "bumblebee", size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("All UK wildlife").font(.body.weight(.medium))
                                Text("\(WildlifeReference.shared.animals.count) animals by kind, with drawings")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    // Diagrams of the common plant diseases
                    // (PlantDiseaseViews.swift). ⚠️ Kept here for now, beside
                    // the pests. William has not said where it belongs.
                    if !PlantDiseases.shared.list.isEmpty {
                        NavigationLink {
                            PlantDiseaseListView()
                        } label: {
                            HStack(spacing: 12) {
                                PlantDiseasePicture(slug: "rust", size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Plant diseases").font(.body.weight(.medium))
                                    Text("\(PlantDiseases.shared.list.count) common ones, each with a diagram")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            if !shapes.isEmpty {
                Section {
                    NavigationLink {
                        FlowerShapeCoverageView()
                    } label: {
                        Label("Flower shape coverage", systemImage: "chart.pie")
                    }
                    NavigationLink {
                        CascadeListView()
                    } label: {
                        Label("Cascades", systemImage: "arrow.triangle.branch")
                    }
                }
            }

            // William's own list, from his Fauna sheet, with his notes.
            Section("Your species") {
                ForEach(filtered) { animal in
                    // Each row is given its page outright, the way the
                    // two rows above ("Flower shape coverage" and
                    // "Cascades") are given theirs.
                    //
                    // Until 15 November 2026 a row only handed over the
                    // animal (`NavigationLink(value: animal)`) and left
                    // it to a separate line lower down,
                    // `.navigationDestination(for: Fauna.self)`, to say
                    // which page an animal opens. On William's iPad the
                    // row went grey when tapped and no page came. That
                    // is what a link does when it cannot find that line.
                    // (Not proven: the fix was written away from the Mac
                    // and the fault could not be made to happen there.)
                    // A link that carries its own page has nothing to
                    // look for, so it cannot miss.
                    NavigationLink {
                        FaunaDetailView(fauna: animal)
                    } label: {
                        HStack(spacing: 12) {
                            // Its drawing, found by its scientific name in
                            // the UK wildlife list: its own if it has one,
                            // otherwise its kind's. A species the list
                            // does not hold shows a close relative's, or
                            // its kind's, found by its genus (the first
                            // word of the name): "Andrena spp." finds the
                            // early mining bee and Myrmica sabuleti the
                            // red ant.
                            if let found = WildlifeReference.shared.drawing(forScientificName: animal.scientificName) {
                                Image(found.pictureName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 44, height: 44)
                                    .accessibilityHidden(true)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(animal.commonName).font(.body.weight(.medium))
                                if let latin = animal.scientificName {
                                    Text(latin).font(.footnote).italic().foregroundStyle(.secondary)
                                }
                                HStack(spacing: 6) {
                                    if let group = animal.recordingGroup { Text(group) }
                                    if let tongue = animal.tongueLength, tongue != "n/a" {
                                        Text("· \(tongue) tongue")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        // The search rests as a magnifying glass on an iPhone and iPad
        // and opens when tapped. See `tuckedSearch` in CollapsingSearch.swift.
        .tuckedSearch(text: $search, prompt: "Search species")
        .navigationTitle("Species")
        .paperScreen()
        // (`.navigationDestination(for: Fauna.self)` stood here. The
        // rows above now carry their own page, so it is not needed.)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Toggle("On the wing now", isOn: $activeOnly)
            }
        }
    }
}

// MARK: - Fauna detail

struct FaunaDetailView: View {

    let fauna: Fauna

    @Query private var links: [PlantFaunaLink]

    private var associations: [PlantFaunaLink] {
        links.filter {
            $0.faunaName.lowercased() == fauna.commonName.lowercased()
                || $0.fauna?.id == fauna.id
        }
    }

    /// This species in the UK wildlife list, if it is there. It gives the
    /// page its drawing and a link to the months it is recorded in.
    private var ukListing: WildlifeAnimal? {
        WildlifeReference.shared.animal(scientificName: fauna.scientificName)
    }

    /// The drawing for this species: its own, a close relative's or its
    /// kind's. Nil only when nothing of its genus is in the UK list.
    private var ukDrawing: WildlifeReference.Drawing? {
        WildlifeReference.shared.drawing(forScientificName: fauna.scientificName)
    }

    var body: some View {
        Form {
            if let found = ukDrawing {
                Section {
                    // A species with more than one drawing (in flight,
                    // the female, the caterpillar) shows the row of them
                    // here too, as its page in All UK wildlife does.
                    if let listing = ukListing, listing.hasOtherPictures {
                        WildlifeAnimalGallery(creature: listing, size: 160)
                    } else {
                        Image(found.pictureName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 160, height: 160)
                            .frame(maxWidth: .infinity)
                            .accessibilityHidden(true)
                    }
                    // The link to the UK page is only for a species the
                    // list holds. That page also has its other drawings.
                    if let listing = ukListing {
                        NavigationLink {
                            WildlifeAnimalPage(creature: listing)
                        } label: {
                            Text("When it is recorded in the UK")
                        }
                    }
                } footer: {
                    if let note = found.note {
                        Text(note)
                    }
                }
            }

            Section {
                if let latin = fauna.scientificName {
                    LabeledContent("Scientific name") { Text(latin).italic() }
                }
                if let family = fauna.family { LabeledContent("Family", value: family) }
                if let group = fauna.recordingGroup { LabeledContent("Recording group", value: group) }
                if let tongue = fauna.tongueLength, tongue != "n/a" {
                    LabeledContent("Tongue length", value: tongue)
                }
                if let status = fauna.conservationStatus, !status.isEmpty {
                    LabeledContent("Status", value: status)
                }
            }

            if let favoured = fauna.favouredPlants {
                Section("Habits") {
                    Text(favoured)
                }
            }

            if !associations.isEmpty {
                Section {
                    ForEach(associations) { link in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(link.plantName).font(.body)
                                Spacer()
                                Text(link.relationship.displayName)
                                    .font(.footnote)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        (link.relationship.pollinatesPlant ? Color.green : Color.orange)
                                            .opacity(0.15),
                                        in: Capsule())
                            }
                            if let shape = link.flowerShape {
                                Text(shape).font(.caption).foregroundStyle(.secondary)
                            }
                            if let notes = link.notes, !notes.isEmpty {
                                Text(notes).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Plants it uses")
                } footer: {
                    Text("Green means the plant is pollinated in return. Orange means it isn't — nectar-robbing takes without pollinating, and a larval host is being eaten.")
                }
            }
        }
        .navigationTitle(fauna.commonName)
        .paperScreen()
        // Tells Eira which species is open. See EiraScreen.
        .eiraLooksAt("the species \(fauna.commonName)", short: fauna.commonName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Flower shape coverage
//
// `FlowerShapeCoverageView` moved to FlowerShapeViews.swift on
// 14 November 2026, when it gained drawings and a page for each shape.

// MARK: - Cascades

struct CascadeListView: View {

    @Query private var cascades: [Cascade]

    var body: some View {
        List {
            ForEach(cascades) { cascade in
                VStack(alignment: .leading, spacing: 6) {
                    Text(cascade.cascadeType)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(alignment: .top, spacing: 4) {
                        step(cascade.plantStep, colour: .green)
                        if cascade.herbivoreStep != nil {
                            Image(systemName: "arrow.right")
                                .font(.caption).foregroundStyle(.tertiary)
                            step(cascade.herbivoreStep, colour: .orange)
                        }
                        if cascade.predatorStep != nil {
                            Image(systemName: "arrow.right")
                                .font(.caption).foregroundStyle(.tertiary)
                            step(cascade.predatorStep, colour: .purple)
                        }
                    }

                    if let notes = cascade.notes, !notes.isEmpty {
                        Text(notes).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Cascades")
        .paperScreen()
    }

    @ViewBuilder
    private func step(_ text: String?, colour: Color) -> some View {
        if let text {
            Text(text)
                .font(.footnote)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(colour.opacity(0.15), in: RoundedRectangle(cornerRadius: 5))
        }
    }
}
