import SwiftUI

// The plant drawings on screen. PlantDrawings.swift says which drawing
// goes with which plant. This file shows them.
//
// A plant's page has two cards of drawings: "Life stages" (the plant from
// seed to crop) and "Leaf and flower" (close-ups). Both are the same
// thing underneath: a title and a row of tiles. That row is
// `PlantPictureRow`, so the two cards look and behave alike.
//
// Tapping a tile opens `PlantPictureDetailView`: the drawing large, with
// the rest of the card's drawings in a row beneath it to step through.
// The page grows out of the tile that was tapped and shrinks back into
// it on the way back, as William asked for every tile (GrowFromTile.swift).

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
/// with its name beneath. Tap one to see it large.
struct PlantStagesCard: View {

    let kind: PlantDrawings.Kind
    /// The plant's own name, for the enlarged page: "Leeks". The kind's
    /// name if none is given.
    var plantName: String? = nil

    var body: some View {
        PlantPictureRow(title: "Life stages", plantName: plantName ?? kind.name, drawings: PlantPicture.stages(of: kind))
    }
}

/// A card for a plant's page: the close-ups of its leaf and its flower.
/// Tap one to see it large.
struct PlantPartsCard: View {

    let kind: PlantDrawings.Kind
    let parts: [PlantParts.Part]
    var plantName: String? = nil

    var body: some View {
        PlantPictureRow(title: "Leaf and flower", plantName: plantName ?? kind.name,
                        drawings: PlantPicture.parts(parts, kind: kind.slug))
    }
}

/// A titled card holding a row of drawings, each with its label beneath.
/// The row slides sideways when it is too long for the card.
struct PlantPictureRow: View {

    let title: String
    /// The kind's name, for the heading of the enlarged page.
    let plantName: String
    let drawings: [PlantPicture]

    /// How big each tile is, in points.
    private let tile: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(drawings) { drawing in
                        // GrowingLink is a NavigationLink whose page grows
                        // out of the tile. The page is handed every
                        // drawing in the row and told which to start on.
                        GrowingLink {
                            PlantPictureDetailView(title: title, plantName: plantName,
                                                   drawings: drawings, firstShown: drawing)
                        } label: {
                            PlantPictureTile(drawing: drawing, size: tile)
                        }
                        // Without this a link tints its words blue.
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the drawing larger")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 14)
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

/// One drawing shown large, on a page of its own, with the other drawings
/// from the same card in a row beneath it. Tapping one of those swaps it
/// in, so the life stages can be stepped through without going back.
struct PlantPictureDetailView: View {

    /// The card it came from: "Life stages".
    let title: String
    let plantName: String
    let drawings: [PlantPicture]

    /// Which drawing is shown large. `@State` because tapping a tile in
    /// the row below changes it, and the page must redraw when it does.
    @State private var shown: PlantPicture

    init(title: String, plantName: String, drawings: [PlantPicture], firstShown: PlantPicture) {
        self.title = title
        self.plantName = plantName
        self.drawings = drawings
        // `_shown` is the box behind `shown`. A starting value for an
        // @State is put straight into the box like this.
        _shown = State(initialValue: firstShown)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // The drawing as large as the page allows, up to 560
                // points. The drawings are kept as vector shapes, so they
                // stay sharp at any size.
                Image(shown.pictureName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 560, maxHeight: 560)
                    .frame(maxWidth: .infinity)
                    .glassCard(padding: 20)
                    .accessibilityLabel("\(plantName): \(shown.label)")

                VStack(alignment: .leading, spacing: 6) {
                    Text(plantName)
                        .font(.body)
                        .foregroundStyle(Theme.inkSoft)
                    Text(shown.label)
                        .font(.screenTitle)
                        .foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                }

                if drawings.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(drawings) { drawing in
                                Button {
                                    // A short fade between one drawing and the next.
                                    withAnimation(.easeInOut(duration: 0.2)) { shown = drawing }
                                } label: {
                                    PlantPictureTile(drawing: drawing, size: 64, isChosen: drawing == shown)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .glassCard(padding: 12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .navigationTitle(title)
        #if os(iOS)
        // The small title in the bar. The large words are on the page.
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .paperScreen()
    }
}
