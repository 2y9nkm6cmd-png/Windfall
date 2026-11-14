//
//  FlowerShapeViews.swift
//  Windfall
//
//  The Flower shapes pages: every shape in the guide with its drawing,
//  and a page for each shape that grows out of its tile.
//
//  Asked for by William on 14 November 2026, in three steps:
//    "We need graphics for these."
//    "Make them a bit more detailed."
//    "Icons next to text and then when you tap them they can expand into
//     a bigger tile page that has a bigger image and details and then
//     examples of what we have that has these flowers."
//
//  WHERE THE DRAWINGS COME FROM
//  There are twenty, one for each shape, kept as small SVG files in
//  `Design/Icons` with names that start `shape-`. They are drawn by
//  `Tools/design/flower_shapes.py`.
//
//  They began as one-colour outlines that the app tinted. On the same
//  evening William asked for them to be "more realistic, but still
//  graphicky", with shading, so they are now in colour: flat petal
//  colours, a darker tone for shade, and the app's dark green outline.
//  A coloured drawing is shown as drawn, like the bee and the butterfly.
//  Unlike those, it is the same drawing in light and dark mode: William
//  preferred the dark green outline left as it is on the dark background.
//
//  WHERE THE SUMS ARE
//  Which drawing goes with a shape, and which plants have a shape, are
//  worked out by `FlowerShapeGuide` in FaunaModels.swift. They live there
//  and not here so that they can be tested without a Mac.
//
//  `FlowerShapeCoverageView` was in FaunaViews.swift until this date, as
//  a plain list of words.
//

import SwiftUI
import SwiftData

// MARK: - The drawing

/// One flower shape's drawing, at a size.
///
/// The drawing is in colour and is shown as drawn. `faded` washes most
/// of the colour out and thins it, which the list uses for a shape the
/// garden does not have yet.
struct FlowerShapePicture: View {
    /// The shape's name as the guide writes it, such as "Rotate, umbellate".
    let shapeTitle: String
    var size: CGFloat = 52
    var faded: Bool = false

    var body: some View {
        Image(FlowerShapeGuide.pictureName(forShape: shapeTitle))
            // `resizable` lets the picture be drawn at any size, and
            // `scaledToFit` keeps its proportions when it is.
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            // `saturation` is how strong the colours are: 1 is as drawn
            // and 0 is grey. `opacity` is how solid the picture is.
            .saturation(faded ? 0.15 : 1)
            .opacity(faded ? 0.6 : 1)
            // The picture is decoration. The words beside it say what it
            // is, so VoiceOver skips it.
            .accessibilityHidden(true)
    }
}

// MARK: - The list of shapes

/// The book's advice is "have as many different flower shapes as possible".
/// This counts them, so it becomes a measurable thing rather than a maxim.
struct FlowerShapeCoverageView: View {

    // `@Query` asks the database for every record of a kind, and keeps
    // the page up to date if any of them changes.
    @Query(sort: [SortDescriptor(\FlowerShape.name)]) private var shapes: [FlowerShape]
    @Query private var links: [PlantFaunaLink]
    @Query(sort: [SortDescriptor(\Plant.commonName)]) private var plants: [Plant]

    /// The shapes the garden has, from plants that are growing.
    private var grownKeys: Set<String> {
        FlowerShapeGuide.shapeKeysGrowing(in: plants, guideLinks: links)
    }

    private func isGrown(_ shape: FlowerShape, among keys: Set<String>) -> Bool {
        guard let key = FlowerShapeGuide.shapeKey(in: shape.name) else { return false }
        return keys.contains(key)
    }

    var body: some View {
        // Worked out once for the whole page, not once for every tile.
        let keys = grownKeys
        let have = shapes.filter { isGrown($0, among: keys) }
        let gaps = shapes.filter { !isGrown($0, among: keys) }

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                summaryCard(have: have.count)

                if !have.isEmpty {
                    HubSectionTitle("You have")
                    tiles(for: have, present: true)
                }
                if !gaps.isEmpty {
                    HubSectionTitle("Gaps")
                    tiles(for: gaps, present: false)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .navigationTitle("Flower shapes")
        .paperScreen()
    }

    /// "Shapes present: 5 of 20", and why it matters.
    private func summaryCard(have: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Shapes present")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(have) of \(shapes.count)")
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)
            }
            Text("Each flower shape serves a different set of insects. A garden of eleven bilabiates feeds one guild very well and everything else not at all.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 16)
    }

    /// One tile for each shape. Tapping a tile grows that shape's page
    /// out of it (GrowFromTile.swift), and the swipe back shrinks it in.
    private func tiles(for group: [FlowerShape], present: Bool) -> some View {
        // "Lazy" means a tile is only made when it is about to scroll
        // into view.
        LazyVStack(spacing: 10) {
            ForEach(group) { shape in
                GrowingLink {
                    FlowerShapeDetailView(shape: shape)
                } label: {
                    FlowerShapeTile(shape: shape, present: present)
                }
                // Without this a link tints all its words blue.
                .buttonStyle(.plain)
            }
        }
    }
}

/// One shape in the list: its drawing, then its name and two lines about
/// it, then a tick if the garden has it. A gap's drawing is faded.
struct FlowerShapeTile: View {
    let shape: FlowerShape
    let present: Bool

    var body: some View {
        // `HStack` sets things side by side: the drawing, the words, the mark.
        HStack(alignment: .top, spacing: 14) {
            FlowerShapePicture(shapeTitle: shape.name, size: 56, faded: !present)

            VStack(alignment: .leading, spacing: 3) {
                Text(shape.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                if let description = shape.shapeDescription {
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }
                if let insects = shape.insectsServed {
                    Text(insects)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft.opacity(0.75))
                }
            }
            // Takes all the room left over, which pushes the mark to
            // the right-hand edge.
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: present ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(present ? Color.green : Theme.inkSoft)
                .accessibilityHidden(true)
        }
        .glassCard(padding: 14)
        // Makes the whole tile take the tap, not only its words.
        .contentShape(.rect)
        // VoiceOver reads the tile as one thing.
        .accessibilityElement(children: .combine)
        .accessibilityValue(present ? "In your garden" : "A gap")
    }
}

// MARK: - One shape's page

/// The page for one flower shape: the drawing large, what the shape is,
/// who it feeds, and the plants that have it.
struct FlowerShapeDetailView: View {

    let shape: FlowerShape

    @Query private var links: [PlantFaunaLink]
    @Query(sort: [SortDescriptor(\Plant.commonName)]) private var plants: [Plant]

    var body: some View {
        // The three lists the page is built from.
        let growing = FlowerShapeGuide.plantsHaving(shapeTitle: shape.name, in: plants, guideLinks: links, keeping: .growing)
        let toBuy = FlowerShapeGuide.plantsHaving(shapeTitle: shape.name, in: plants, guideLinks: links, keeping: .wanted)
        let visitors = FlowerShapeGuide.visitorNames(ofShape: shape.name, guideLinks: links)

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                picture
                heading(present: !growing.isEmpty)
                aboutCard
                feedsCard(visitors: visitors)
                gardenCard(growing: growing)
                if !toBuy.isEmpty {
                    plantCard(title: "On your list to buy", plants: toBuy)
                }
                examplesCard(hasNone: growing.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .navigationTitle(shape.name)
        #if os(iOS)
        // The small title in the bar. The large one is on the page itself.
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .paperScreen()
    }

    // MARK: The pieces

    /// The drawing, large, on a card of its own. Always in full colour:
    /// this is the page to learn the shape from, grown or not.
    private var picture: some View {
        FlowerShapePicture(shapeTitle: shape.name, size: 200)
            .frame(maxWidth: .infinity)
            .glassCard(padding: 20)
    }

    /// The name in the serif used for page titles, the plain word for the
    /// shape above it, and a tag saying whether the garden has it.
    private func heading(present: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let plain = shape.plainDescription {
                Text(plain)
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)
            }
            Text(shape.name)
                .font(.screenTitle)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            StatusTag(text: present ? "In your garden" : "A gap in your garden",
                      fill: present ? Theme.leafFill : Theme.amber)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// What the shape is, and the guide's note on why it matters.
    private var aboutCard: some View {
        card("The shape") {
            if let description = shape.shapeDescription {
                Text(description)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
            }
            if let notes = shape.notes, !notes.isEmpty {
                Text(notes)
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    /// The insects the guide says the shape serves, then the animals the
    /// links sheet records on flowers of this shape.
    @ViewBuilder
    private func feedsCard(visitors: [String]) -> some View {
        if shape.insectsServed != nil || !visitors.isEmpty {
            card("Who it feeds") {
                if let insects = shape.insectsServed {
                    Text(insects)
                        .font(.body)
                        .foregroundStyle(Theme.ink)
                }
                if !visitors.isEmpty {
                    Text("Recorded on flowers of this shape")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                    // Small labels that wrap on to a new row when they
                    // run out of room (PlantLibraryCards.swift).
                    ChipFlow(spacing: 6) {
                        ForEach(visitors, id: \.self) { visitor in
                            StatusTag(text: visitor, fill: Theme.journalCard)
                        }
                    }
                }
            }
        }
    }

    /// "Examples of what we have that has these flowers."
    @ViewBuilder
    private func gardenCard(growing: [Plant]) -> some View {
        if growing.isEmpty {
            card("In your garden") {
                Text("Nothing you grow is recorded with this shape yet.")
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)
            }
        } else {
            plantCard(title: "In your garden", plants: growing)
        }
    }

    /// A card listing plants. Each one opens that plant's own page.
    private func plantCard(title: String, plants listed: [Plant]) -> some View {
        card(title) {
            ForEach(listed) { plant in
                NavigationLink {
                    PlantDetailView(plant: plant)
                } label: {
                    HStack(spacing: 10) {
                        WIconView(.plants, size: 20)
                            .foregroundStyle(Theme.leaf)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(plant.displayName)
                                .font(.body)
                                .foregroundStyle(Theme.ink)
                            if let latin = plant.latinName, !latin.isEmpty {
                                Text(latin)
                                    .font(.footnote)
                                    .italic()
                                    .foregroundStyle(Theme.inkSoft)
                            }
                        }
                        Spacer()
                        WIconView(.chevronRight, size: 14)
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// The guide's own examples. For a gap they are what to try.
    @ViewBuilder
    private func examplesCard(hasNone: Bool) -> some View {
        if let examples = shape.examplePlants, !examples.isEmpty {
            card(hasNone ? "Plants to try" : "Other plants with this shape") {
                Text(examples)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
            }
        }
    }

    /// A glass card with a heading. `Content` in the angle brackets stands
    /// for "whatever views are handed in", which is what lets one function
    /// make every card on the page.
    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 16)
    }
}

// MARK: - A checking aid

/// One shape's page by name, for `-demoFlowerShape Bilabiate`. It lets a
/// still picture be taken of the page without tapping through to it.
struct DemoFlowerShapePage: View {

    let shapeTitle: String

    @Query private var shapes: [FlowerShape]

    var body: some View {
        if let found = shapes.first(where: { $0.name.lowercased() == shapeTitle.lowercased() }) {
            FlowerShapeDetailView(shape: found)
        } else {
            Text("No flower shape called \(shapeTitle).")
        }
    }
}
