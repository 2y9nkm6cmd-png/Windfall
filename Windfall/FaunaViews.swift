//
//  FaunaViews.swift
//  Windfall
//
//  Browsing the species reference, and the questions it can now answer:
//  what visits this plant, what should I plant for this animal, and which
//  flower shapes is my garden missing.
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

            Section("Species") {
                ForEach(filtered) { animal in
                    NavigationLink(value: animal) {
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
        .searchable(text: $search, prompt: "Search species")
        .navigationTitle("Species")
        .paperScreen()
        .navigationDestination(for: Fauna.self) { FaunaDetailView(fauna: $0) }
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

    var body: some View {
        Form {
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
