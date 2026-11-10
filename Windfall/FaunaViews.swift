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
                            Text(animal.commonName).font(.subheadline.weight(.medium))
                            if let latin = animal.scientificName {
                                Text(latin).font(.caption).italic().foregroundStyle(.secondary)
                            }
                            HStack(spacing: 6) {
                                if let group = animal.recordingGroup { Text(group) }
                                if let tongue = animal.tongueLength, tongue != "n/a" {
                                    Text("· \(tongue) tongue")
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Search species")
        .navigationTitle("Species")
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
                                Text(link.plantName).font(.subheadline)
                                Spacer()
                                Text(link.relationship.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        (link.relationship.pollinatesPlant ? Color.green : Color.orange)
                                            .opacity(0.15),
                                        in: Capsule())
                            }
                            if let shape = link.flowerShape {
                                Text(shape).font(.caption2).foregroundStyle(.secondary)
                            }
                            if let notes = link.notes, !notes.isEmpty {
                                Text(notes).font(.caption2).foregroundStyle(.secondary)
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
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Flower shape coverage

/// The book's advice is "have as many different flower shapes as possible".
/// This counts them, so it becomes a measurable thing rather than a maxim.
struct FlowerShapeCoverageView: View {

    @Query private var shapes: [FlowerShape]
    @Query private var links: [PlantFaunaLink]
    @Query(sort: [SortDescriptor(\Plant.commonName)]) private var plants: [Plant]

    /// Shapes present in the garden, from plants you actually grow.
    private var covered: Set<String> {
        let growing = Set(plants
            .filter { $0.status == .growing }
            .map { $0.commonName.lowercased() })

        return Set(links
            .filter { growing.contains($0.plantName.lowercased()) }
            .compactMap { $0.shapeOnly })
    }

    private var missing: [FlowerShape] {
        shapes.filter { !covered.contains($0.name) }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Shapes present", value: "\(covered.count) of \(shapes.count)")
            } footer: {
                Text("Each flower shape serves a different set of insects. A garden of eleven bilabiates feeds one guild very well and everything else not at all.")
            }

            Section("You have") {
                ForEach(shapes.filter { covered.contains($0.name) }) { shape in
                    shapeRow(shape, present: true)
                }
            }

            if !missing.isEmpty {
                Section("Gaps") {
                    ForEach(missing) { shape in
                        shapeRow(shape, present: false)
                    }
                }
            }
        }
        .navigationTitle("Flower shapes")
    }

    @ViewBuilder
    private func shapeRow(_ shape: FlowerShape, present: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(shape.name).font(.subheadline.weight(.medium))
                Spacer()
                Image(systemName: present ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(present ? .green : .secondary)
            }
            if let description = shape.shapeDescription {
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
            if let insects = shape.insectsServed {
                Text(insects).font(.caption2).foregroundStyle(.tertiary)
            }
            if !present, let examples = shape.examplePlants {
                Text("Try: \(examples)")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Cascades

struct CascadeListView: View {

    @Query private var cascades: [Cascade]

    var body: some View {
        List {
            ForEach(cascades) { cascade in
                VStack(alignment: .leading, spacing: 6) {
                    Text(cascade.cascadeType)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(alignment: .top, spacing: 4) {
                        step(cascade.plantStep, colour: .green)
                        if cascade.herbivoreStep != nil {
                            Image(systemName: "arrow.right")
                                .font(.caption2).foregroundStyle(.tertiary)
                            step(cascade.herbivoreStep, colour: .orange)
                        }
                        if cascade.predatorStep != nil {
                            Image(systemName: "arrow.right")
                                .font(.caption2).foregroundStyle(.tertiary)
                            step(cascade.predatorStep, colour: .purple)
                        }
                    }

                    if let notes = cascade.notes, !notes.isEmpty {
                        Text(notes).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Cascades")
    }

    @ViewBuilder
    private func step(_ text: String?, colour: Color) -> some View {
        if let text {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(colour.opacity(0.15), in: RoundedRectangle(cornerRadius: 5))
        }
    }
}
