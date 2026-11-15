//
//  Snowdrop.swift
//  Windfall
//
//  Eira's symbol: a single snowdrop in a circle, and the wind that
//  moves it.
//
//  The snowdrop is the app icon's own, without the bee (William, 15
//  November 2026). Until then it was his earlier, finer drawing from the
//  logo sheet (Design/Reference, "eira-logo-sheet"), painted in one
//  colour.
//
//  The drawing itself is shared with the widgets, so it lives in
//  WindfallShared:
//    SnowdropArt.swift      the outlines, copied from the icon by a script
//    SnowdropDrawing.swift  the colours, the line widths and the sway
//

import SwiftUI

/// Eira's symbol: the snowdrop on its circle.
///
/// Light mode is the dark icon's drawing on a green circle. Dark mode is
/// the light icon's drawing on a cream circle. `colorScheme` is how a
/// view asks which of the two modes it is being shown in.
struct EiraSymbol: View {

    var size: CGFloat = 54
    var lean: Double = 0
    var nod: Double = 0

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SnowdropOnDisc(style: .following(colorScheme), size: size, lean: lean, nod: nod)
    }
}

/// A checking page: Eira's symbol at every size the app uses, both ways
/// round, leaning as far as the wind pushes it, and in one colour.
/// Opened with `-demoOpen widgets -demoWidgetPage 3`. See WidgetGallery.
struct SnowdropSheet: View {

    private let sizes: [CGFloat] = [88, 54, 44, 36, 28, 22]
    /// The furthest lean each way with the nod that goes with it, and
    /// the first swing back. See SnowdropWind.
    private let poses: [(lean: Double, nod: Double)] = [(0, 0), (24, 45.6), (-24, -45.6), (-15, -28.5)]

    var body: some View {
        VStack(spacing: 14) {
            group(.onGreen, on: Color(hex: 0xF8F1E5))
            group(.onCream, on: Color(hex: 0x0C1C14))
            HStack(spacing: 18) {
                // As on the Lock Screen: white on a dim circle.
                ZStack {
                    Circle().fill(.white.opacity(0.22))
                    SnowdropView(style: .oneColour).padding(9)
                }
                .frame(width: 58, height: 58)
                .foregroundStyle(.white)
                SnowdropView(style: .oneColour).frame(width: 120, height: 120).foregroundStyle(.white)
                SnowdropView(style: .oneColour).frame(width: 36, height: 36).foregroundStyle(.white)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Color(hex: 0x3A4A44), in: .rect(cornerRadius: 20))
        }
        .padding(.horizontal, 14)
    }

    private func group(_ style: SnowdropStyle, on page: Color) -> some View {
        VStack(spacing: 14) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(sizes, id: \.self) { SnowdropOnDisc(style: style, size: $0) }
            }
            HStack(spacing: 10) {
                ForEach(poses.indices, id: \.self) { index in
                    SnowdropOnDisc(style: style, size: 76, lean: poses[index].lean, nod: poses[index].nod)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(page, in: .rect(cornerRadius: 20))
    }
}

// MARK: - Wind

/// How the snowdrop moves when a gust carries it along.
enum SnowdropWind {

    /// The shortest time the plant is carried, in seconds.
    static let travel = 0.55
    /// How long the swaying takes to die away once it has stopped.
    static let settled = 3.0

    /// How far the plant leans at a moment after the gust began.
    ///
    /// While it is carried, the wind bends it over in the direction it is
    /// going. When it stops, it springs back past upright and sways to
    /// rest, each swing smaller than the last.
    ///
    /// `direction` is -1 for travelling left and 1 for travelling right.
    /// `travel` is how long it is carried for.
    static func lean(at seconds: Double, direction: Double, travel: Double = travel) -> Double {
        guard seconds >= 0, seconds < travel + settled else { return 0 }
        if seconds < travel {
            // Half a sine wave: over, then back up as it arrives.
            return direction * 24 * sin(.pi * seconds / travel)
        }
        let after = seconds - travel
        // exp(...) shrinks towards nothing, which makes each swing smaller.
        // sin(...) is the swinging itself.
        return -direction * 15 * exp(-2.2 * after) * sin(11 * after)
    }

    /// The flower head swings further than the stem, and a moment later.
    static func nod(at seconds: Double, direction: Double, travel: Double = travel) -> Double {
        max(-55, min(55, lean(at: seconds - 0.07, direction: direction, travel: travel) * 1.9))
    }
}
