//
//  GardenDrawSteps.swift
//  Windfall
//
//  Drawing a garden one question at a time, and the page that offers
//  every way of drawing side by side for trying out.
//
//  The app asks and you answer with the tape measure in your hand. Each
//  question has a picture of exactly what to measure:
//
//    1  How big is the plot?     starting from where you come in
//    2  Which way is north?      the ring, the compass or the map
//    3  Where is each bed?       its size and two distances
//    4  Sheds, paths and trees   the same, for everything else
//
//  It saves as you go, into the same records the other editors use, so
//  you can leave part way and carry on in any of them.
//
//  Two parts:
//
//    GardenDrawSteps     the four steps
//    GardenDrawChooser   the page behind "Edit layout" on a plan card,
//                        with links to every editor and every way of
//                        setting north. It is there for testing: once
//                        William has chosen, it can go.
//

import SwiftUI
import SwiftData

// MARK: - The picture for step 1

/// A plain plot with its two sides named, and where you stand.
private struct PlotPicture: View {

    let width: Double
    let depth: Double

    var body: some View {
        Canvas { context, size in
            // Leave room for the labels, then fit a box of the plot's
            // proportions into what is left.
            let space = CGSize(width: size.width - 110, height: size.height - 78)
            let scale = min(space.width / CGFloat(max(width, 1)), space.height / CGFloat(max(depth, 1)))
            let box = CGRect(x: (size.width - CGFloat(width) * scale) / 2 + 20, y: 36,
                             width: CGFloat(width) * scale, height: CGFloat(depth) * scale)
            context.fill(Path(box), with: .color(Theme.card))
            context.stroke(Path(box), with: .color(Theme.inkSoft), lineWidth: 1.4)

            // Width along the top, depth down the left.
            var lines = Path()
            lines.move(to: CGPoint(x: box.minX, y: box.minY - 14))
            lines.addLine(to: CGPoint(x: box.maxX, y: box.minY - 14))
            lines.move(to: CGPoint(x: box.minX - 14, y: box.minY))
            lines.addLine(to: CGPoint(x: box.minX - 14, y: box.maxY))
            context.stroke(lines, with: .color(Theme.leaf), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

            func label(_ words: String, at point: CGPoint, strong: Bool = true) {
                context.draw(Text(words).font(.footnote.weight(strong ? .semibold : .regular))
                    .foregroundStyle(strong ? Theme.leaf : Theme.inkSoft), at: point)
            }
            label("Width", at: CGPoint(x: box.midX, y: box.minY - 26))
            label("Depth", at: CGPoint(x: box.minX - 40, y: box.midY))
            label("the far edge is the top", at: CGPoint(x: box.midX, y: box.minY + 14), strong: false)

            // You, on the bottom edge.
            let you = CGRect(x: box.midX - 7, y: box.maxY - 7, width: 14, height: 14)
            context.fill(Path(ellipseIn: you), with: .color(Theme.leaf))
            context.draw(Text("You come in here").font(.footnote.weight(.semibold)).foregroundStyle(Theme.ink),
                         at: CGPoint(x: box.midX, y: box.maxY + 20))
        }
        .accessibilityElement()
        .accessibilityLabel("A picture of the plot. Width runs left to right. Depth runs from the far edge to where you come in.")
    }
}

// MARK: - The steps

struct GardenDrawSteps: View {

    @Bindable var garden: Garden

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Bed> { $0.retiredAt == nil },
           sort: [SortDescriptor(\Bed.displayOrder)]) private var allBeds: [Bed]
    @Query(sort: [SortDescriptor(\GardenFeature.createdAt)]) private var allFeatures: [GardenFeature]

    /// Which of the four steps is showing.
    @State private var step = 1
    /// The bed being asked about in step 3.
    @State private var bedID: UUID?
    /// The shed, path or tree being asked about in step 4.
    @State private var featureID: UUID?

    private let stepNames = ["The plot", "North", "Beds", "Sheds, paths and trees"]

    private var beds: [Bed] { allBeds.filter { $0.siteRaw == garden.siteKey } }
    private var features: [GardenFeature] { allFeatures.filter { $0.siteRaw == garden.siteKey && $0.isPresent } }
    private var bed: Bed? { beds.first { $0.id == bedID } }
    private var feature: GardenFeature? { features.first { $0.id == featureID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepLine
            switch step {
            case 1: plotStep
            case 2: northStep
            case 3: bedsStep
            default: restStep
            }
            footer
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .paperScreen()
        .navigationTitle(garden.name.isEmpty ? "Garden" : garden.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: Shared pieces

    /// "Step 2 of 4 · North", with four short bars filling up.
    private var stepLine: some View {
        HStack {
            Text("Step \(step) of 4 · \(stepNames[step - 1])")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
            Spacer()
            HStack(spacing: 4) {
                ForEach(1...4, id: \.self) { number in
                    Capsule()
                        .fill(number <= step ? Theme.leaf : Theme.hairline)
                        .frame(width: 22, height: 4)
                }
            }
            .accessibilityHidden(true)
        }
    }

    private func question(_ words: String, _ help: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(words)
                .font(.system(.title, design: .serif, weight: .medium))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text(help)
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if step > 1 {
                Button("Back") { step -= 1 }
                    .buttonStyle(QuietGlassButton())
            }
            Spacer()
            Button {
                if step < 4 { step += 1 } else { dismiss() }
            } label: {
                Text(step < 4 ? "Next" : "Finish")
                    .fontWeight(.semibold)
                    .frame(minWidth: 90)
            }
            .leafButton()
            .controlSize(.large)
        }
    }

    /// A row of names to choose between, with the chosen one filled in.
    private func chips(_ names: [(id: UUID, name: String)], chosen: UUID?, choose: @escaping (UUID) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(names, id: \.id) { entry in
                    Button(entry.name) { choose(entry.id) }
                        .font(.body.weight(entry.id == chosen ? .semibold : .regular))
                        .foregroundStyle(entry.id == chosen ? Theme.onLeaf : Theme.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(entry.id == chosen ? Theme.leaf : Theme.card.opacity(0.7), in: .capsule)
                        .overlay { Capsule().strokeBorder(entry.id == chosen ? Theme.leaf : Theme.hairline) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    /// The plan as a picture, marking one thing's two distances.
    private func picture(marking id: UUID) -> some View {
        GardenDrawBoard(garden: garden, beds: beds, features: features, chosenID: .constant(id), isLive: false)
            .frame(maxHeight: 250)
            .frame(maxWidth: .infinity)
            .glassCard(cornerRadius: 18, padding: 4)
    }

    // MARK: Step 1

    private var plotStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                question("How big is the plot?",
                         "Stand where you usually come in. The edge nearest you is the bottom of the plan.")
                PlotPicture(width: garden.widthMetres ?? 14, depth: garden.depthMetres ?? 10)
                    .frame(height: 250)
                    .glassCard(cornerRadius: 18, padding: 8)
                Grid(horizontalSpacing: 10) {
                    GridRow {
                        DrawNumberField(title: "Width, left to right",
                                        value: DrawBindings.plot($garden.widthMetres, startingAt: 10))
                        DrawNumberField(title: "Depth, front to back",
                                        value: DrawBindings.plot($garden.depthMetres, startingAt: 10))
                    }
                }
            }
        }
    }

    // MARK: Step 2

    private var northStep: some View {
        // Not in a ScrollView: scrolling would fight the drag on the ring.
        VStack(alignment: .leading, spacing: 12) {
            question("Which way is north?", "Drag N round the ring until it points north from where you stand.")
            VStack(spacing: 8) {
                NorthRing(garden: garden, beds: beds, features: features, size: 230)
                NorthWords(garden: garden)
            }
            .frame(maxWidth: .infinity)
            .glassCard()
            HStack(spacing: 8) {
                NavigationLink("Use the compass") { NorthByPointing(garden: garden) }
                NavigationLink("Use the map") { NorthByMap(garden: garden) }
            }
            .buttonStyle(QuietGlassButton())
            Spacer(minLength: 0)
        }
    }

    // MARK: Step 3

    private var bedsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let bed {
                    question("Where is \(bed.planName)?", "Its size, then how far it is in from the left and from the top.")
                    chips(beds.map { ($0.id, $0.planName) }, chosen: bedID) { bedID = $0 }
                    picture(marking: bed.id)
                    FieldBox {
                        TextField("Name", text: Binding(get: { bed.name }, set: { bed.name = $0 }))
                    }
                    DrawFourNumbers(thing: bed)
                    HStack(spacing: 8) {
                        Button("Another like it") {
                            // One copy, a path's width below this one.
                            let made = DrawMaker.repeatBed(bed, count: 1, gap: 0.6, goingDown: true,
                                                           in: garden, beds: beds, context: context)
                            bedID = made.first?.id ?? bedID
                        }
                        Button("A different bed") { addBed() }
                    }
                    .buttonStyle(QuietGlassButton())
                } else {
                    question("Add your first bed", "Give it a size, then say how far it is in from the left and from the top.")
                    Button("Add a bed") { addBed() }
                        .buttonStyle(QuietGlassButton())
                }
            }
        }
        .onAppear { if bedID == nil { bedID = beds.first?.id } }
    }

    /// A new bed the size of the last one, in a clear place, then chosen.
    private func addBed() {
        let last = beds.last
        let name = GardenDrawing.nextBedNames(existing: beds.map(\.name), count: 1).first ?? "Bed"
        let made = DrawMaker.addBed(named: name, sections: max(last?.orderedSections.count ?? 6, 1),
                                    length: last?.planLength ?? 4.8, width: last?.planWidth ?? 1.2,
                                    at: DrawMaker.freeSpot(beds: beds, features: features),
                                    to: garden, after: beds, in: context)
        bedID = made.id
    }

    // MARK: Step 4

    private var restStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                question("Sheds, paths and trees",
                         "Anything that is not a bed. A neighbour's tree counts too if it shades you: give it a distance below zero.")
                Menu {
                    ForEach(FeatureKind.allCases) { kind in
                        Button(kind.displayName) {
                            let made = DrawMaker.addFeature(kind, at: DrawMaker.freeSpot(beds: beds, features: features),
                                                            to: garden, in: context)
                            featureID = made.id
                        }
                    }
                } label: {
                    Label("Add one", systemImage: "plus")
                }
                .buttonStyle(QuietGlassButton())
                if !features.isEmpty {
                    chips(features.map { ($0.id, $0.planName) }, chosen: featureID) { featureID = $0 }
                }
                if let feature {
                    picture(marking: feature.id)
                    FieldBox {
                        TextField("Name", text: Binding(get: { feature.name }, set: { feature.name = $0 }))
                    }
                    DrawFourNumbers(thing: feature)
                    DrawNumberField(title: "Height, for its shade",
                                    value: Binding(get: { feature.heightMetres }, set: { feature.heightMetres = max(0, $0) }))
                    Button("Remove it") {
                        feature.removedAt = .now
                        featureID = nil
                    }
                    .buttonStyle(QuietGlassButton())
                }
            }
        }
        .onAppear { if featureID == nil { featureID = features.first?.id } }
    }
}

// MARK: - Every way, side by side

/// The page behind "Draw this garden" and "Edit layout" on a plan card.
///
/// For now it offers every editor and every way of setting north, so
/// they can be tried against each other on a real garden.
struct GardenDrawChooser: View {

    @Bindable var garden: Garden

    @Query(filter: #Predicate<Bed> { $0.retiredAt == nil },
           sort: [SortDescriptor(\Bed.displayOrder)]) private var allBeds: [Bed]
    @Query private var allFeatures: [GardenFeature]

    private var beds: [Bed] { allBeds.filter { $0.siteRaw == garden.siteKey } }
    private var features: [GardenFeature] { allFeatures.filter { $0.siteRaw == garden.siteKey && $0.isPresent } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ScreenHeader(title: garden.name.isEmpty ? "Draw the garden" : "Draw \(garden.name)",
                             detail: "Every way of drawing, side by side, to try out")
                GardenPlanView(garden: garden, beds: beds, features: features)
                    .frame(maxWidth: .infinity, maxHeight: 220)
                    .glassCard()

                HubSectionTitle("Draw it")
                way("Drag it, then type the number",
                    "Work on the plan itself. Tap any number to type it from the tape.") {
                    GardenDrawView(garden: garden)
                }
                way("One question at a time",
                    "The plot, north, each bed, then sheds and trees, with a picture for each.") {
                    GardenDrawSteps(garden: garden)
                }
                way("The form of numbers", "The editor as it was, with slope, soil and where the garden is.") {
                    GardenEditorView(garden: garden)
                }

                HubSectionTitle("Say where north is")
                Text(GardenDrawing.facingWords(garden.topFacesDegrees) + " at the moment.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                way("Move north round the plan", "Drag an N round a ring. Works on every device.") {
                    NorthRingSetter(garden: garden)
                }
                way("Stand and point", "Stand at the bottom edge and point across the garden. iPhone and iPad.") {
                    NorthByPointing(garden: garden)
                }
                way("Line it up with the map", "Turn the plot's outline over a satellite picture from Apple Maps.") {
                    NorthByMap(garden: garden)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .paperScreen()
        .navigationTitle(garden.name.isEmpty ? "Garden" : garden.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// One way of doing it, as a card that leads to its page.
    private func way<Destination: View>(_ title: String, _ detail: String,
                                        @ViewBuilder to destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.ink)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                WIconView(.chevronRight, size: 14)
                    .foregroundStyle(Theme.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(padding: 14)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
