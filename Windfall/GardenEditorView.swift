//
//  GardenEditorView.swift
//  Windfall
//
//  Where a garden is drawn from its measurements.
//
//  This is a first version: a form of numbers with the plan above it,
//  redrawing as you type. Everything is measured in metres from the
//  top-left corner of the plot, so a tape measure is all you need.
//
//  What it edits:
//    the plot      size, which way it faces, slope, soil, where it is
//    each bed      position, size, turn and height
//    features      sheds, paths, ponds, trees, hedges, fences, buildings
//
//  A position below zero is outside the plot. That is how a neighbour's
//  tree or the house next door is recorded, so its shade can be counted.
//

import SwiftUI
import SwiftData
import CoreLocation

struct GardenEditorView: View {

    // @Bindable lets the form's fields write straight into the record.
    @Bindable var garden: Garden

    @Environment(\.modelContext) private var context
    @Environment(LocationManager.self) private var locationManager

    @Query(filter: #Predicate<Bed> { $0.retiredAt == nil },
           sort: [SortDescriptor(\Bed.displayOrder)]) private var allBeds: [Bed]
    @Query(sort: [SortDescriptor(\GardenFeature.createdAt)]) private var allFeatures: [GardenFeature]

    @State private var compass = CompassHeading()
    @State private var isFindingLocation = false

    private var beds: [Bed] { allBeds.filter { $0.siteRaw == garden.siteKey } }
    private var features: [GardenFeature] {
        allFeatures.filter { $0.siteRaw == garden.siteKey && $0.isPresent }
    }

    var body: some View {
        Form {
            Section {
                GardenPlanView(garden: garden, beds: beds, features: features)
                    .frame(height: 220)
                if GardenPlanView.hasUnplacedBeds(beds) {
                    Button("Spread out the beds that have not been placed") {
                        GardenPlan.placeUnpositionedBeds(beds, siteKey: garden.siteKey)
                    }
                }
            } footer: {
                Text("Positions are measured in metres from the top-left corner of the plot.")
            }

            plotSection
            placeSection
            sunSection

            Section("Beds") {
                if beds.isEmpty {
                    Text("No beds here yet. Add them in Gardens, then Beds.")
                        .foregroundStyle(.secondary)
                }
                ForEach(beds) { bed in
                    DisclosureGroup(bed.name.isEmpty ? "Bed" : bed.name) {
                        BedLayoutFields(bed: bed)
                    }
                }
            }

            Section {
                ForEach(features) { feature in
                    DisclosureGroup(feature.name.isEmpty ? feature.kind.displayName : feature.name) {
                        FeatureLayoutFields(feature: feature)
                    }
                }
                Menu("Add") {
                    ForEach(FeatureKind.allCases) { kind in
                        Button(kind.displayName) { add(kind) }
                    }
                }
            } header: {
                Text("Sheds, paths, trees and the rest")
            } footer: {
                Text("Use a position below zero for something outside the plot, such as a neighbour's tree. Give it a height and its shade is counted.")
            }
        }
        .navigationTitle(garden.name.isEmpty ? "Garden" : garden.name)
        .paperScreen()
        .onDisappear { compass.stop() }
    }

    // MARK: The plot

    private var plotSection: some View {
        Section("The plot") {
            TextField("Name", text: $garden.name)
            NumberRow("Width, left to right (m)", value: $garden.widthMetres)
            NumberRow("Depth, top to bottom (m)", value: $garden.depthMetres)

            LabeledContent("Top of the plan faces") {
                HStack(spacing: 6) {
                    TextField("0", value: $garden.topFacesDegrees, format: .number.precision(.fractionLength(0)))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 70)
                    Text("° · \(Compass.name(forBearing: garden.topFacesDegrees))")
                        .foregroundStyle(.secondary)
                }
            }
            if compass.isAvailable {
                compassSetter
            }

            Picker("Slopes down towards", selection: $garden.slopeDownDegrees) {
                Text("Flat").tag(Double?.none)
                ForEach(0..<8, id: \.self) { index in
                    Text(Compass.pointNames[index].capitalized).tag(Double?.some(Double(index) * 45))
                }
            }
            if garden.slopeDownDegrees != nil {
                Picker("How steep", selection: Binding(
                    get: { garden.slopeSteepness ?? .gentle },
                    set: { garden.slopeSteepness = $0 }
                )) {
                    ForEach(SlopeSteepness.allCases) { Text($0.displayName).tag($0) }
                }
            }
            Picker("Soil", selection: Binding(
                get: { garden.soil },
                set: { garden.soil = $0 }
            )) {
                Text("Not set").tag(SoilKind?.none)
                ForEach(SoilKind.allCases) { Text($0.displayName).tag(SoilKind?.some($0)) }
            }
        }
    }

    /// Sets which way the plan faces from the device's own compass.
    private var compassSetter: some View {
        HStack {
            if let heading = compass.degrees {
                CompassRose(north: -heading, size: 28, isLive: true)
                VStack(alignment: .leading) {
                    Text("You are facing \(Compass.name(forBearing: heading)), \(Int(heading.rounded()))°")
                    Text("Face the way the top of your plan faces, then tap Use.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Use") {
                    garden.topFacesDegrees = heading.rounded()
                    compass.stop()
                }
                .buttonStyle(.glassProminent)
            } else {
                Button("Set from the compass") { compass.start() }
            }
        }
    }

    private var placeSection: some View {
        Section {
            NumberRow("Latitude", value: $garden.latitude, decimals: 4)
            NumberRow("Longitude", value: $garden.longitude, decimals: 4)
            Button {
                Task {
                    isFindingLocation = true
                    if let fix = await locationManager.currentLocation() {
                        // Four decimal places is about ten metres.
                        garden.latitude = (fix.coordinate.latitude * 10_000).rounded() / 10_000
                        garden.longitude = (fix.coordinate.longitude * 10_000).rounded() / 10_000
                    }
                    isFindingLocation = false
                }
            } label: {
                HStack {
                    Text("Use where I am now")
                    if isFindingLocation { ProgressView().controlSize(.small) }
                }
            }
        } header: {
            Text("Where it is")
        } footer: {
            Text("Latitude decides how high the sun climbs, which sets how long the shadows are. It stays on this device.")
        }
    }

    // MARK: Sun

    /// Hours of direct sun on each bed for the present month, worked out
    /// from the heights and positions above.
    @ViewBuilder
    private var sunSection: some View {
        if let latitude = garden.latitude, !beds.isEmpty {
            let month = Calendar.current.component(.month, from: .now)
            Section {
                ForEach(beds) { bed in
                    let hours = Shade.sunHours(
                        on: bed.samplePoints,
                        obstacles: GardenPlan.shadeShapes(beds: beds, features: features,
                                                          siteKey: garden.siteKey, excluding: bed),
                        topFaces: garden.topFacesDegrees,
                        latitude: latitude,
                        dayOfYear: Sun.midMonthDays[month - 1],
                        stepMinutes: 15)
                    LabeledContent(bed.name) {
                        Text("\(hours.direct.formatted(.number.precision(.fractionLength(1)))) of \(hours.possible.formatted(.number.precision(.fractionLength(1)))) hours · \(hours.label)")
                    }
                }
            } header: {
                Text("Direct sun this month")
            } footer: {
                Text("For a clear day in the middle of \(Date.now.formatted(.dateTime.month(.wide))), on flat ground. A guide, not a survey.")
            }
        }
    }

    private func add(_ kind: FeatureKind) {
        let feature = GardenFeature(name: kind.displayName, kind: kind, siteKey: garden.siteKey)
        // Start it just inside the corner, where it is easy to see.
        feature.originX = 0.5
        feature.originY = 0.5
        feature.lengthMetres = kind == .path ? 4 : 2
        feature.widthMetres = kind == .path ? 0.6 : 2
        context.insert(feature)
    }
}

// MARK: - Rows

/// One line of the form holding a number that may be empty.
private struct NumberRow: View {

    let title: String
    @Binding var value: Double?
    var decimals = 2

    init(_ title: String, value: Binding<Double?>, decimals: Int = 2) {
        self.title = title
        self._value = value
        self.decimals = decimals
    }

    var body: some View {
        LabeledContent(title) {
            TextField("Not set", value: $value, format: .number.precision(.fractionLength(0...decimals)))
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.numbersAndPunctuation)
                #endif
        }
    }
}

/// The measurements of one bed.
private struct BedLayoutFields: View {

    @Bindable var bed: Bed

    var body: some View {
        TextField("Name", text: $bed.name)
        NumberRow("From left edge (m)", value: orZero($bed.originX))
        NumberRow("From top edge (m)", value: orZero($bed.originY))
        NumberRow("Length (m)", value: $bed.lengthMetres)
        NumberRow("Width (m)", value: $bed.widthMetres)
        NumberRow("Turned clockwise (°)", value: orZero($bed.rotationDegrees))
        NumberRow("Height (m)", value: $bed.heightMetres)
    }
}

/// The measurements of one shed, path, tree or other feature.
private struct FeatureLayoutFields: View {

    @Bindable var feature: GardenFeature

    var body: some View {
        TextField("Name", text: $feature.name)
        Picker("What it is", selection: Binding(
            get: { feature.kind },
            set: { feature.kind = $0 }
        )) {
            ForEach(FeatureKind.allCases) { Text($0.displayName).tag($0) }
        }
        NumberRow("From left edge (m)", value: orZero($feature.originX))
        NumberRow("From top edge (m)", value: orZero($feature.originY))
        NumberRow("Length (m)", value: orZero($feature.lengthMetres))
        NumberRow("Width (m)", value: orZero($feature.widthMetres))
        NumberRow("Turned clockwise (°)", value: orZero($feature.rotationDegrees))
        NumberRow("Height (m)", value: orZero($feature.heightMetres))
        Toggle("Casts shade", isOn: $feature.blocksLight)
        Button("Remove", role: .destructive) {
            // Marked as removed, not deleted, so the record of it survives.
            feature.removedAt = .now
        }
    }
}

/// Lets a number that is always present use a field built for one that
/// may be empty. Clearing the field sets it to zero.
private func orZero(_ binding: Binding<Double>) -> Binding<Double?> {
    Binding<Double?>(
        get: { binding.wrappedValue },
        set: { binding.wrappedValue = $0 ?? 0 }
    )
}
