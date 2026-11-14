import SwiftUI

// The plant drawings on screen. PlantDrawings.swift says which drawing
// goes with which plant. This file shows them.

/// One drawing of one plant at one stage, square.
struct PlantDrawingView: View {

    /// The kind's short name, as in the picture's name: "broad-bean".
    let kind: String
    /// The stage, as in the picture's name: "crop".
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
/// with its name beneath. The row slides sideways when it is too long.
struct PlantStagesCard: View {

    let kind: PlantDrawings.Kind
    private let tile: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Life stages")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(kind.stages) { stage in
                        VStack(spacing: 6) {
                            PlantDrawingView(kind: kind.slug, stage: stage.stage, size: tile)
                            Text(stage.label)
                                .font(.footnote)
                                .foregroundStyle(Theme.inkSoft)
                                .multilineTextAlignment(.center)
                                .frame(width: tile)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        // VoiceOver reads each stage as its name alone.
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(stage.label)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 14)
    }
}
