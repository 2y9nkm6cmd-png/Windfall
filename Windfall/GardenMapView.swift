//
//  GardenMapView.swift
//  Windfall
//
//  The visual layout, drawn from the geometry stored on each Bed.
//
//  This is why beds carry originX, originY, length, width and rotation
//  rather than being a plain list. Turn the beds ninety degrees on the
//  ground and you change one number here — the identities, and every
//  planting attached to them, are untouched.
//

import SwiftUI
import SwiftData

struct GardenMapView: View {

    @Query(filter: #Predicate<Bed> { $0.retiredAt == nil },
           sort: [SortDescriptor(\Bed.displayOrder)])
    private var beds: [Bed]

    @State private var site: GardenSite = .allotment
    @State private var selectedSection: BedSection?
    @State private var isEditingLayout = false

    private var sited: [Bed] { beds.filter { $0.site == site } }

    /// Metres of garden across the widest point, for scaling to the screen.
    private var extent: CGSize {
        let maxX = sited.map { $0.originX + ($0.lengthMetres ?? 6) }.max() ?? 10
        let maxY = sited.map { $0.originY + ($0.widthMetres ?? 1.2) }.max() ?? 10
        return CGSize(width: max(maxX, 1), height: max(maxY, 1))
    }

    var body: some View {
        VStack(spacing: 0) {
            GlassSwitch(choices: Array(GardenSite.allCases), selection: $site) { $0.displayName }
                .padding()

            if sited.isEmpty {
                ContentUnavailableView {
                    Label("No beds here yet", systemImage: "map")
                } description: {
                    Text("Add beds to see them laid out.")
                }
            } else {
                GeometryReader { geometry in
                    let scale = min(
                        (geometry.size.width - 32) / extent.width,
                        (geometry.size.height - 32) / extent.height
                    )

                    ZStack(alignment: .topLeading) {
                        ForEach(sited) { bed in
                            BedShape(bed: bed, scale: scale, selected: $selectedSection)
                                .offset(x: bed.originX * scale + 16,
                                        y: bed.originY * scale + 16)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }

            if let selectedSection {
                SectionSummary(section: selectedSection)
                    .transition(.move(edge: .bottom))
            }
        }
        .navigationTitle("Garden map")
        .paperScreen()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isEditingLayout.toggle()
                } label: {
                    Label("Arrange", systemImage: "arrow.up.left.and.arrow.down.right")
                }
            }
        }
        .sheet(isPresented: $isEditingLayout) {
            LayoutEditorView(beds: sited)
        }
        .animation(.default, value: selectedSection?.id)
    }
}

// MARK: - One bed

private struct BedShape: View {

    let bed: Bed
    let scale: CGFloat
    @Binding var selected: BedSection?

    private var length: CGFloat { CGFloat(bed.lengthMetres ?? 7.2) * scale }
    private var width: CGFloat { CGFloat(bed.widthMetres ?? 1.2) * scale }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(bed.name)
                .font(.caption2.weight(.medium))

            HStack(spacing: 1) {
                ForEach(bed.orderedSections) { section in
                    Button {
                        selected = (selected?.id == section.id) ? nil : section
                    } label: {
                        Rectangle()
                            .fill(colour(for: section))
                            .overlay {
                                Text(section.label)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .overlay {
                                if selected?.id == section.id {
                                    Rectangle().strokeBorder(.primary, lineWidth: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: length, height: width)
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .rotationEffect(.degrees(bed.rotationDegrees))
    }

    /// Colour by what's growing there. Empty ground reads as pale, so
    /// the map answers "where is there space?" at a glance.
    private func colour(for section: BedSection) -> Color {
        let active = (section.plantings ?? []).filter {
            $0.status != .finished && $0.status != .failed
        }
        guard let first = active.first else { return .secondary.opacity(0.25) }

        // Consistent colour per plant family, so rotation is visible.
        let group = first.plant?.group ?? first.plant?.commonName ?? ""
        let palette: [Color] = [.green, .orange, .purple, .teal, .pink, .indigo, .brown, .mint]
        let index = abs(group.hashValue) % palette.count
        return palette[index].opacity(0.75)
    }
}

// MARK: - Selected section

private struct SectionSummary: View {

    let section: BedSection

    private var active: [Planting] {
        (section.plantings ?? []).filter { $0.status != .finished && $0.status != .failed }
    }

    private var history: [Planting] {
        (section.plantings ?? [])
            .filter { $0.status == .finished || $0.status == .failed }
            .sorted { ($0.dateSown ?? .distantPast) > ($1.dateSown ?? .distantPast) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.fullLabel)
                .font(.headline)

            if active.isEmpty {
                Text("Empty").foregroundStyle(.secondary)
            } else {
                ForEach(active) { planting in
                    NavigationLink(value: planting) {
                        HStack {
                            Text(planting.plant?.displayName ?? "Unknown")
                            Spacer()
                            if let sown = planting.dateSown {
                                Text(sown, format: .dateTime.day().month())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if !history.isEmpty {
                Text("Previously")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                ForEach(history.prefix(3)) { planting in
                    HStack {
                        Text(planting.plant?.commonName ?? "Unknown")
                        Spacer()
                        if let sown = planting.dateSown {
                            Text(sown, format: .dateTime.year())
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
    }
}

// MARK: - Layout editor

/// Positions are in metres from a corner of the site. Typed rather than
/// dragged: measuring the plot once with a tape gives a more accurate map
/// than nudging rectangles about, and the numbers stay meaningful.
struct LayoutEditorView: View {

    let beds: [Bed]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                ForEach(beds) { bed in
                    Section(bed.name) {
                        LabeledContent("Position across (m)") {
                            TextField("0", value: Binding(
                                get: { bed.originX },
                                set: { bed.originX = $0 }
                            ), format: .number)
                            .multilineTextAlignment(.trailing)
                        }

                        LabeledContent("Position down (m)") {
                            TextField("0", value: Binding(
                                get: { bed.originY },
                                set: { bed.originY = $0 }
                            ), format: .number)
                            .multilineTextAlignment(.trailing)
                        }

                        LabeledContent("Length (m)") {
                            TextField("7.2", value: Binding(
                                get: { bed.lengthMetres ?? 7.2 },
                                set: { bed.lengthMetres = $0 }
                            ), format: .number)
                            .multilineTextAlignment(.trailing)
                        }

                        LabeledContent("Width (m)") {
                            TextField("1.2", value: Binding(
                                get: { bed.widthMetres ?? 1.2 },
                                set: { bed.widthMetres = $0 }
                            ), format: .number)
                            .multilineTextAlignment(.trailing)
                        }

                        LabeledContent("Rotation (°)") {
                            TextField("0", value: Binding(
                                get: { bed.rotationDegrees },
                                set: { bed.rotationDegrees = $0 }
                            ), format: .number)
                            .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
            .navigationTitle("Arrange beds")
            .paperScreen()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
