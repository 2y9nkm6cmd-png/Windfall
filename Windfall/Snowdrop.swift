//
//  Snowdrop.swift
//  Windfall
//
//  Eira's symbol: a single snowdrop in a circle.
//
//  The outlines are William's own drawing, taken from his logo sheet
//  (Design/Reference, "eira-logo-sheet"). They are kept here as the same
//  path text an SVG file uses, and turned into shapes the app can draw.
//
//  Why shapes and not a picture file: a picture can only be moved or
//  turned as a whole. Kept as separate shapes, the stem can lean and the
//  flower head can swing on its stalk, which is what lets the snowdrop
//  sway in the wind.
//

import SwiftUI

// MARK: - The drawing

/// The snowdrop's outlines. The numbers are positions on a grid that runs
/// from -100 to 100 each way, with the middle of Eira's circle at 0, 0.
///
/// In this text M means "move to", C means "curve to" (two control points
/// then the end point), L means "line to" and Z means "close the shape".
enum SnowdropArt {

    static let stem = "M-53,79 C-56,31 -51,-8 -33,-42 C-17,-71 4,-83 24,-77 C38,-73 47,-61 50,-47 L45,-46 C41,-62 33,-70 22,-73 C3,-78 -14,-62 -28,-39 C-46,-6 -47,34 -47,79 Z"

    /// The small swelling the petals hang from.
    static let ovary = "M45,-48 C44,-43 43,-38 43,-35 C47,-32 52,-31 55,-32 C55,-38 53,-44 49,-48 C48,-49 47,-49 45,-48Z"

    static let petals = [
        "M44,-34 C36,-30 30,-23 26,-11 C21,3 19,19 22,24 C25,28 33,18 38,8 C44,-4 47,-24 44,-34Z",
        "M49,-32 C45,-23 43,-8 44,6 C45,21 50,35 54,35 C59,33 63,16 61,1 C59,-14 55,-26 49,-32Z",
        "M56,-32 C66,-28 78,-19 84,-7 C89,4 90,16 87,19 C83,22 72,15 66,8 C59,0 55,-16 56,-32Z"
    ]

    static let leaves = [
        "M-50,80 C-58,60 -73,47 -85,39 C-78,40 -62,42 -49,55 C-43,62 -46,71 -50,80Z",
        "M-50,80 C-45,64 -36,53 -21,44 C-27,60 -37,72 -50,80Z"
    ]

    /// Where the plant meets the ground. It leans about this point.
    static let base = UnitPoint(x: (-50.0 + 100) / 200, y: (80.0 + 100) / 200)
    /// The tip of the arching stalk. The flower head swings about this point.
    static let stalkTip = UnitPoint(x: (47.0 + 100) / 200, y: (-47.0 + 100) / 200)
}

/// Turns path text into a shape, scaled to fit whatever space it is given.
struct SVGOutline: Shape {

    let pathText: String

    func path(in rect: CGRect) -> Path {
        // Split the text into letters and numbers. "M-53,79" becomes
        // "M", "-53", "79".
        var tokens: [String] = []
        var current = ""
        for character in pathText {
            if character.isLetter {
                if !current.isEmpty { tokens.append(current); current = "" }
                tokens.append(String(character))
            } else if character == "," || character == " " {
                if !current.isEmpty { tokens.append(current); current = "" }
            } else if character == "-" && !current.isEmpty {
                // A minus sign straight after a number starts a new number.
                tokens.append(current)
                current = "-"
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { tokens.append(current) }

        // Walk through the tokens, drawing as we go.
        var path = Path()
        var index = 0

        func number() -> CGFloat {
            defer { index += 1 }
            return index < tokens.count ? CGFloat(Double(tokens[index]) ?? 0) : 0
        }
        // Moves a point from the -100 to 100 grid into the space given.
        func point() -> CGPoint {
            let x = number(), y = number()
            return CGPoint(x: rect.minX + (x + 100) / 200 * rect.width,
                           y: rect.minY + (y + 100) / 200 * rect.height)
        }

        while index < tokens.count {
            let command = tokens[index]
            index += 1
            switch command {
            case "M": path.move(to: point())
            case "L": path.addLine(to: point())
            case "C":
                let first = point(), second = point(), end = point()
                path.addCurve(to: end, control1: first, control2: second)
            case "Z", "z": path.closeSubpath()
            default: break
            }
        }
        return path
    }
}

// MARK: - The snowdrop

/// The snowdrop, drawn in whatever colour surrounds it.
///
/// `lean` tips the whole plant over from its base, in degrees. A negative
/// number leans left. `nod` swings the flower head on its stalk.
struct SnowdropView: View {

    var lean: Double = 0
    var nod: Double = 0

    var body: some View {
        ZStack {
            SVGOutline(pathText: SnowdropArt.stem)
            ForEach(SnowdropArt.leaves, id: \.self) { SVGOutline(pathText: $0) }

            // The flower head is grouped so it can swing as one piece.
            ZStack {
                SVGOutline(pathText: SnowdropArt.ovary)
                ForEach(SnowdropArt.petals, id: \.self) { SVGOutline(pathText: $0) }
            }
            .rotationEffect(.degrees(nod), anchor: SnowdropArt.stalkTip)
        }
        .rotationEffect(.degrees(lean), anchor: SnowdropArt.base)
        .accessibilityHidden(true)
    }
}

/// Eira's symbol: the snowdrop on its circle.
///
/// Light mode is a white flower on a green circle. Dark mode is a green
/// flower on a cream circle. The two colours come from the theme, which
/// swaps them over.
struct EiraSymbol: View {

    var size: CGFloat = 54
    var lean: Double = 0
    var nod: Double = 0

    var body: some View {
        ZStack {
            Circle().fill(Theme.eiraDisc)
            SnowdropView(lean: lean, nod: nod)
                .foregroundStyle(Theme.eiraFlower)
                // The circle clips the plant, so a leaning stem never
                // pokes out past the edge.
                .clipShape(Circle())
        }
        .frame(width: size, height: size)
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
