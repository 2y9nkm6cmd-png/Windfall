import SwiftUI

// The plant drawings on screen. PlantDrawings.swift says which drawing
// goes with which plant. This file shows them.
//
// A plant's page has three cards of drawings:
//
//   - "Life stages": the plant from seed to crop, in a row of tiles.
//   - "Leaf" and "Flower": a close-up each, two cards side by side.
//
// Tapping anywhere on a card opens it zoomed in (`PlantPicturesZoomed`).
// For the life stages that is every stage large, one at a time, swiped
// through sideways. For a close-up it is that one drawing large. The
// zoomed page grows out of the card that was tapped and shrinks back
// into it on the way back (GrowFromTile.swift).
//
// Until 15 November 2026, midday, each little tile was its own link and
// "Leaf and flower" was one card with two tiles. William asked for the
// whole card to be the thing that is tapped, and for the leaf and the
// flower to be two cards of their own.

/// One drawing of one plant at one stage, square.
struct PlantDrawingView: View {

    /// The kind's short name, as in the drawing's name: "broad-bean".
    let kind: String
    /// The stage or close-up, as in the drawing's name: "crop", "leaf".
    let stage: String
    /// How wide and tall to draw it, in points.
    var size: CGFloat = 60

    var body: some View {
        Image(PlantDrawings.pictureName(kind: kind, stage: stage))
            .resizable()        // may be drawn at any size
            .scaledToFit()      // without being stretched
            .frame(width: size, height: size)
            // The words beside a drawing already say what it is.
            .accessibilityHidden(true)
    }
}

/// A card for a plant's page: every stage of its life in a row, each
/// with its name beneath. Tap anywhere on the card to see it zoomed in.
struct PlantStagesCard: View {

    let kind: PlantDrawings.Kind
    /// The plant's own name, for the zoomed page: "Leeks". The kind's
    /// name if none is given.
    var plantName: String? = nil

    /// How big each tile is, in points.
    private let tile: CGFloat = 96

    var body: some View {
        let drawings = PlantPicture.stages(of: kind)
        let name = plantName ?? kind.name

        // The whole card is the link's label, so a tap anywhere on it,
        // on a drawing, a label, the title or the glass between them,
        // opens the zoomed page.
        GrowingLink {
            PlantPicturesZoomed(title: "Life stages", plantName: name, drawings: drawings)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text("Life stages")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                // The row still slides sideways when it is too long for
                // the card. A slide is a drag, not a tap, so it moves
                // the row and does not open the page.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(drawings) { drawing in
                            PlantPictureTile(drawing: drawing, size: tile)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(padding: 14)
            // The shape that answers a tap: the whole rounded card.
            .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        }
        // Without this a link tints its words blue.
        .buttonStyle(.plain)
        .accessibilityLabel("Life stages, \(drawings.count) drawings")
        .accessibilityHint("Opens the life stages larger")
    }
}

/// The close-ups of a plant's leaf and its flower: two cards side by
/// side, the same height. A plant with only a leaf (Ginkgo, Shallot and
/// a few more) shows the leaf card alone, at the same half width, so it
/// is the same size on every page.
struct PlantPartsCard: View {

    let kind: PlantDrawings.Kind
    let parts: [PlantParts.Part]
    var plantName: String? = nil

    var body: some View {
        let drawings = PlantPicture.parts(parts, kind: kind.slug)
        let name = plantName ?? kind.name

        HStack(alignment: .top, spacing: 14) {
            ForEach(drawings) { drawing in
                PlantCloseUpCard(drawing: drawing, plantName: name)
            }
            // An empty space in place of the missing flower card.
            if drawings.count == 1 {
                Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
            }
        }
        // `fixedSize(vertical:)` makes the row only as tall as its
        // tallest card wants, and each card's `maxHeight: .infinity`
        // then stretches it to that height, so the two cards match even
        // when one title runs to two lines ("Flowers, inside the fig").
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// One close-up card: its title ("Leaf", "Flower", "Blossom") and the
/// drawing filling the card. Tap anywhere on it to see it zoomed in.
struct PlantCloseUpCard: View {

    let drawing: PlantPicture
    let plantName: String

    var body: some View {
        GrowingLink {
            PlantPicturesZoomed(title: drawing.label, plantName: plantName, drawings: [drawing])
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(drawing.label)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Image(drawing.pictureName)
                    .resizable()
                    // A square, as wide as the card allows, up to 200
                    // points. The drawings are vector shapes, so they
                    // stay sharp at any size.
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: 200)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .glassCard(padding: 14)
            .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(drawing.label), close-up")
        .accessibilityHint("Opens the drawing larger")
    }
}

/// One tile in a row: the drawing and its label beneath.
struct PlantPictureTile: View {

    let drawing: PlantPicture
    var size: CGFloat = 96
    /// True when this is the drawing shown large, on the enlarged page.
    var isChosen = false

    var body: some View {
        VStack(spacing: 6) {
            PlantDrawingView(kind: drawing.kind, stage: drawing.key, size: size)
                .padding(4)
                .overlay {
                    // A ring round the drawing that is shown large.
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.leaf, lineWidth: isChosen ? 2 : 0)
                }
            Text(drawing.label)
                .font(.footnote.weight(isChosen ? .semibold : .regular))
                .foregroundStyle(isChosen ? Theme.ink : Theme.inkSoft)
                .multilineTextAlignment(.center)
                .frame(width: size + 8)
                .fixedSize(horizontal: false, vertical: true)
        }
        // The whole tile answers a tap, not only the drawn lines.
        .contentShape(Rectangle())
        // VoiceOver reads each tile as its label alone.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(drawing.label)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}

/// A card zoomed in, on a page of its own.
///
/// For the life stages: each stage as large as the screen allows, one
/// at a time. Swipe sideways (or use the arrows, or the arrow keys on a
/// Mac) to step through the life cycle while staying zoomed in. The
/// small tiles at the foot show where you are and jump straight to a
/// stage. For a close-up there is just the one drawing.
struct PlantPicturesZoomed: View {

    /// The card it came from: "Life stages", "Leaf".
    let title: String
    let plantName: String
    let drawings: [PlantPicture]

    /// Which drawing is in view, by its id ("seedling", "crop").
    ///
    /// `@State` because swiping or tapping changes it. It is optional
    /// (`String?`) because that is what `scrollPosition(id:)` below
    /// works with: the scroll view writes the id of the drawing it has
    /// settled on into this box, and when a button writes an id into it,
    /// the scroll view slides to that drawing. One box, both directions.
    @State private var shownID: String?

    /// Where a button (an arrow, or a small tile) has asked the row to
    /// slide to. Kept apart from `shownID`, which the row itself writes
    /// as it moves, so the two never pull against each other.
    @State private var target: String?

    /// `firstShown` is for the checking aid on the plant page
    /// (`-demoPlantDrawing crop`). From a card the page starts at the
    /// first drawing, as the card does.
    init(title: String, plantName: String, drawings: [PlantPicture], firstShown: PlantPicture? = nil) {
        self.title = title
        self.plantName = plantName
        self.drawings = drawings
        // `_shownID` is the box behind `shownID`. A starting value for
        // an @State is put straight into the box like this.
        _shownID = State(initialValue: (firstShown ?? drawings.first)?.id)
    }

    /// Where the shown drawing is in the row: 0 for the first.
    private var shownIndex: Int {
        drawings.firstIndex { $0.id == shownID } ?? 0
    }

    /// Slides to the drawing `step` places along (-1 back, +1 on), if
    /// there is one.
    private func move(_ step: Int) {
        let next = shownIndex + step
        guard drawings.indices.contains(next) else { return }
        target = drawings[next].id
    }

    var body: some View {
        // GeometryReader says how tall the page is, so a drawing is never
        // so big that its name falls off the foot of an iPad on its side.
        GeometryReader { page in
            let side = min(560, max(220, page.size.height * 0.6))

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(plantName)
                        .font(.body)
                        .foregroundStyle(Theme.inkSoft)

                    // The zoomed-in row. Each drawing is one "page" as wide
                    // as the card (`containerRelativeFrame`), and
                    // `.paging` makes a swipe stop exactly on the next
                    // one rather than halfway between two.
                    //
                    // `ScrollViewReader` hands over a `proxy`: a remote
                    // control for the row, whose `scrollTo` slides it to
                    // the drawing with a given id.
                    ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(drawings) { drawing in
                                VStack(spacing: 12) {
                                    Image(drawing.pictureName)
                                        .resizable()
                                        .aspectRatio(1, contentMode: .fit)
                                        .frame(maxWidth: side, maxHeight: side)
                                        .accessibilityLabel("\(plantName): \(drawing.label)")
                                    Text(drawing.label)
                                        .font(.screenTitle)
                                        .foregroundStyle(Theme.ink)
                                        .multilineTextAlignment(.center)
                                        .accessibilityHidden(true)
                                }
                                .padding(20)
                                .containerRelativeFrame(.horizontal)
                                // The name `scrollTo` looks for.
                                .id(drawing.id)
                            }
                        }
                        // Tells the scroll view that each drawing above
                        // is a place it may come to rest.
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $shownID)
                    // A button has asked for another drawing: slide to it.
                    .onChange(of: target) { _, id in
                        guard let id else { return }
                        withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(id, anchor: .leading) }
                        target = nil
                    }
                    // A page opened part-way along (the checking aid
                    // `-demoPlantDrawing crop`) starts on that drawing. A
                    // tenth of a second's wait lets the row be laid out
                    // first, or there is nothing yet to slide.
                    .task {
                        guard let start = shownID, start != drawings.first?.id else { return }
                        try? await Task.sleep(for: .milliseconds(100))
                        proxy.scrollTo(start, anchor: .leading)
                    }
                    .glassCard(padding: 0)
                    }

                    if drawings.count > 1 {
                        steps
                        strip
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle(title)
        #if os(iOS)
        // The small title in the bar. The large words are on the page.
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .paperScreen()
    }

    /// Back and on arrows either side of "3 of 7". On a Mac, where there
    /// is no swipe on a mouse, these and the arrow keys do the stepping.
    private var steps: some View {
        HStack(spacing: 18) {
            Button { move(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.leaf)
            .disabled(shownIndex == 0)
            .opacity(shownIndex == 0 ? 0.3 : 1)
            .keyboardShortcut(.leftArrow, modifiers: [])
            .accessibilityLabel("Earlier")

            Text("\(shownIndex + 1) of \(drawings.count)")
                .font(.body.monospacedDigit())
                .foregroundStyle(Theme.inkSoft)

            Button { move(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.leaf)
            .disabled(shownIndex == drawings.count - 1)
            .opacity(shownIndex == drawings.count - 1 ? 0.3 : 1)
            .keyboardShortcut(.rightArrow, modifiers: [])
            .accessibilityLabel("Later")
        }
        .frame(maxWidth: .infinity)
    }

    /// Every drawing small, the one in view ringed. Tap one to slide
    /// straight to it.
    private var strip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(drawings) { drawing in
                    Button {
                        target = drawing.id
                    } label: {
                        PlantPictureTile(drawing: drawing, size: 64, isChosen: drawing.id == shownID)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .glassCard(padding: 12)
    }
}
