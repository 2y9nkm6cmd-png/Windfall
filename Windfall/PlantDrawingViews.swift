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
// For the life stages that is the card's own row made much bigger: one
// long strip that fills the page and is dragged along sideways. For a
// close-up it is that one drawing large. The zoomed page grows out of
// the card that was tapped and shrinks back into it on the way back
// (GrowFromTile.swift).
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

/// One tile in a card's row: the drawing and its label beneath.
struct PlantPictureTile: View {

    let drawing: PlantPicture
    var size: CGFloat = 96

    var body: some View {
        VStack(spacing: 6) {
            PlantDrawingView(kind: drawing.kind, stage: drawing.key, size: size)
                .padding(4)
            Text(drawing.label)
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .frame(width: size + 8)
                .fixedSize(horizontal: false, vertical: true)
        }
        // The whole tile answers a tap, not only the drawn lines.
        .contentShape(Rectangle())
        // VoiceOver reads each tile as its label alone.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(drawing.label)
    }
}

/// A card zoomed in, on a page of its own.
///
/// For the life stages it is the card's own row made much bigger: every
/// stage in one long strip, each with its name beneath, as tall as the
/// page allows. Drag sideways to travel along it from seed to winter.
/// The strip glides and stops wherever it is let go. For a close-up
/// there is just the one drawing, in the middle.
///
/// Until 13:00 on 15 November 2026 this was a slideshow: one drawing to
/// a page, snapping from page to page, with arrows, a "3 of 5" count
/// and a second row of small tiles beneath. William asked for the card
/// itself to fill the screen and be scrolled along, so all of that went.
struct PlantPicturesZoomed: View {

    /// The card it came from: "Life stages", "Leaf".
    let title: String
    let plantName: String
    let drawings: [PlantPicture]

    /// For the checking aid on the plant page (`-demoPlantDrawing crop`):
    /// the drawing to have in the middle when the page opens. From a card
    /// this is left as `nil` ("nothing") and the strip opens at its
    /// start, as the card does.
    var firstShown: PlantPicture? = nil

    /// How much of the page's width one drawing may take when there are
    /// several. A little over half, so the next stage always shows at
    /// the edge and it is plain that the strip carries on. Make this
    /// smaller to see more stages at once, larger for bigger drawings.
    private static let shareOfWidth: CGFloat = 0.58

    /// How wide and tall each drawing is, in points, on a page this size.
    ///
    /// `static` means the sum belongs to the type and not to one page of
    /// it: it uses nothing but the numbers handed to it.
    private static func side(in page: CGSize, alone: Bool) -> CGFloat {
        // Up and down: the page's height, less the plant's name above,
        // the stage's name beneath and the gaps round them.
        let roomUp = page.height - 150
        // Across: a lone close-up may fill the width. A strip keeps to
        // its share, so that more than one stage is in view.
        let roomAcross = alone ? page.width - 72 : page.width * shareOfWidth
        // The smaller of the two, never under 160 points nor over 720.
        return max(160, min(roomUp, roomAcross, 720))
    }

    var body: some View {
        // GeometryReader measures the page and hands its size over as
        // `page`, so the drawings can be sized to fit it.
        GeometryReader { page in
            let side = Self.side(in: page.size, alone: drawings.count == 1)

            VStack(alignment: .leading, spacing: 10) {
                Text(plantName)
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)

                // The two Spacers, one above the card and one below,
                // share out any height left over, which puts the card in
                // the middle of a tall page (an iPhone held upright).
                Spacer(minLength: 0)

                // `ScrollViewReader` hands over a `proxy`: a remote
                // control for the strip, whose `scrollTo` slides it to
                // the drawing with a given id. Only the checking aid
                // uses it.
                ScrollViewReader { proxy in
                    // A plain sideways ScrollView. With nothing said
                    // about where it may stop, it glides freely and
                    // rests wherever the finger leaves it.
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: side * 0.1) {
                            ForEach(drawings) { drawing in
                                stage(drawing, side: side)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        // If the strip is narrower than the card (a lone
                        // close-up, or a very wide Mac window) this
                        // stretches it to the card's width, and a frame
                        // puts what it holds in its middle.
                        .frame(minWidth: max(0, page.size.width - 32))
                    }
                    // The scroll bar shows for a moment when the page
                    // opens: a hint that there is more to the side.
                    .scrollIndicatorsFlash(onAppear: true)
                    // A tenth of a second's wait lets the strip be laid
                    // out first, or there is nothing yet to slide.
                    .task {
                        guard let start = firstShown, start.id != drawings.first?.id else { return }
                        try? await Task.sleep(for: .milliseconds(100))
                        proxy.scrollTo(start.id, anchor: .center)
                    }
                }
                // Cuts the strip to the card's rounded corners, so a
                // drawing sliding past does not poke out of them.
                .clipShape(.rect(cornerRadius: Theme.cardRadius))
                .glassCard(padding: 0)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationTitle(title)
        #if os(iOS)
        // The small title in the bar, to leave the page to the strip.
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .paperScreen()
    }

    /// One stage of the strip: the drawing, and its name beneath.
    private func stage(_ drawing: PlantPicture, side: CGFloat) -> some View {
        VStack(spacing: 10) {
            Image(drawing.pictureName)
                .resizable()
                // The drawings are vector shapes, so they stay sharp at
                // any size.
                .aspectRatio(1, contentMode: .fit)
                .frame(width: side, height: side)
            Text(drawing.label)
                .font(.title3.weight(.medium))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .frame(width: side)
        }
        // The name `scrollTo` looks for.
        .id(drawing.id)
        // VoiceOver reads each stage as one thing: "Garlic: Seedling".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(plantName): \(drawing.label)")
    }
}
