//
//  SnowdropDrawing.swift
//  WindfallShared
//
//  How Eira's snowdrop is coloured, drawn and moved.
//
//  The snowdrop is the app icon's own, without the bee (William, 15
//  November 2026). Its outlines are in SnowdropArt.swift, which a script
//  copies out of the icon's drawing. This file is the part written by
//  hand: which colour each part is, how wide its line is, and how the
//  plant bends in the wind.
//
//  It lives in WindfallShared so that the app and the widgets draw the
//  very same snowdrop. Until now the widgets kept a second copy.
//
//  Why shapes and not a picture file: a picture can only be moved or
//  turned as a whole. Kept as separate shapes, the stalk can lean and
//  the flower head can swing on it, which is what lets the snowdrop sway.
//

import SwiftUI

// MARK: - Reading the outlines

extension Path {

    /// Makes a shape from path text, the way an SVG file writes one:
    /// "M98.5,262.0 C98.4,256.9 ..." and so on. The shape keeps the
    /// text's own numbers. Whoever draws it moves and scales it to fit.
    init(outline text: String) {
        // Split the text into letters and numbers. "M-53,79" becomes
        // "M", "-53", "79".
        var tokens: [String] = []
        var current = ""
        for character in text {
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
        func point() -> CGPoint {
            let x = number(), y = number()
            return CGPoint(x: x, y: y)
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
        self = path
    }
}

/// The snowdrop's parts as shapes, read from the text once and kept.
/// `static let` means each is worked out the first time it is asked for
/// and never again, so a swaying snowdrop is not re-read sixty times a
/// second.
enum SnowdropParts {
    static let stalk = Path(outline: SnowdropArt.stalk)
    static let leaves = SnowdropArt.leaves.map { Path(outline: $0) }
    static let petals = SnowdropArt.petals.map { Path(outline: $0) }
    static let cup = SnowdropArt.cup.map { Path(outline: $0) }
    static let vMark = Path(outline: SnowdropArt.vMark)
    static let cap = Path(outline: SnowdropArt.cap)
}

// MARK: - Colours

/// What one part of the snowdrop is painted with.
enum SnowdropInk: Sendable {
    /// A named colour.
    case colour(Color)
    /// Whatever colour the surroundings ask for (`.foregroundStyle`).
    /// The Lock Screen widget uses this, because iOS chooses its colour.
    case surrounding
    /// No paint: this rubs out what is underneath, leaving a thin gap
    /// that the background shows through. It keeps the petals apart
    /// when the whole snowdrop is one colour.
    case gap
}

/// One way of colouring the snowdrop. There are three, at the foot.
///
/// The line widths are in the icon's own numbers, where the circle is
/// 400 across. A line of 8 is therefore a fiftieth of the circle's width
/// at any size.
struct SnowdropStyle: Sendable {

    /// The circle behind the snowdrop.
    var disc: Color

    var stalk: SnowdropInk
    var stalkWidth: CGFloat

    var leaf: SnowdropInk
    var leafLine: SnowdropInk
    var leafWidth: CGFloat

    /// A pale outline round the whole flower, drawn underneath it, so the
    /// dark lines of the petals stand out on the dark circle. `nil`
    /// means there is none.
    var halo: SnowdropInk?

    var petal: SnowdropInk
    var cap: SnowdropInk
    var vMark: SnowdropInk
    /// The line round the petals, the cup and the cap.
    var flowerLine: SnowdropInk
    var petalWidth: CGFloat = 8.8
    var cupWidth: CGFloat = 6.4
    var capWidth: CGFloat = 8.7

    // The icon's colours, from Design/colours.json. They are the same in
    // light and dark mode: which of them a part gets is decided below.
    private static let green = Color("Colours/IconGreen")
    private static let cream = Color("Colours/IconCream")
    private static let leafGreen = Color("Colours/IconLeaf")

    /// On a green circle: the dark app icon's drawing, with cream lines
    /// on the stalk and leaves and a cream outline round the flower.
    static let onGreen = SnowdropStyle(
        disc: green,
        stalk: .colour(cream), stalkWidth: 8.0,
        leaf: .colour(leafGreen), leafLine: .colour(cream), leafWidth: 5.0,
        halo: .colour(cream),
        petal: .colour(.white), cap: .colour(leafGreen), vMark: .colour(leafGreen),
        flowerLine: .colour(green))

    /// On a cream circle: the light app icon's drawing, with green lines.
    static let onCream = SnowdropStyle(
        disc: cream,
        stalk: .colour(green), stalkWidth: 12.9,
        leaf: .colour(leafGreen), leafLine: .colour(green), leafWidth: 9.1,
        halo: nil,
        petal: .colour(.white), cap: .colour(leafGreen), vMark: .colour(leafGreen),
        flowerLine: .colour(green))

    /// One colour and no circle, for places where iOS picks the colour,
    /// such as the Lock Screen. The icon's lines become thin gaps.
    static let oneColour = SnowdropStyle(
        disc: .clear,
        stalk: .surrounding, stalkWidth: 12.9,
        leaf: .surrounding, leafLine: .gap, leafWidth: 9,
        halo: nil,
        petal: .surrounding, cap: .surrounding, vMark: .gap,
        flowerLine: .gap,
        petalWidth: 9, cupWidth: 7, capWidth: 9)

    /// The style for a symbol standing on the app's own pages. In light
    /// mode Eira's circle is green, so the drawing is the dark icon's.
    /// In dark mode the circle is cream and the drawing is the light
    /// icon's. The two swap over, as her old symbol did.
    static func following(_ colourScheme: ColorScheme) -> SnowdropStyle {
        colourScheme == .dark ? .onCream : .onGreen
    }
}

// MARK: - The sway

/// Where the snowdrop bends, and by how much.
///
/// The wind gives two numbers (see SnowdropWind in the app): `lean`, how
/// far the plant is pushed over, and `nod`, how far the flower head
/// swings. The new flower fills far more of the circle than the old one
/// did, so each part takes only a share of those numbers. At full
/// strength the old drawing would throw the flower out of the circle.
enum SnowdropSway {
    /// Where the leaves meet the ground, just under the circle's rim.
    /// The whole plant leans about this point.
    static let ground = CGPoint(x: 98, y: 400)
    /// The foot of the stalk, hidden behind the tall leaf. The stalk
    /// bends a little further about this point, taking the flower along.
    static let stalkBase = CGPoint(x: 98.5, y: 262)
    /// The tip of the stalk, under the cap. The flower head swings here.
    static let stalkTip = CGPoint(x: 256.5, y: 84)

    static let plantShare = 0.15
    static let stalkShare = 0.35
    static let nodShare = 0.5
}

// MARK: - The drawing

/// The snowdrop alone, with no circle.
///
/// `lean` tips the plant over, in degrees. A negative number leans left.
/// `nod` swings the flower head on its stalk.
struct SnowdropView: View {

    var style: SnowdropStyle
    var lean: Double = 0
    var nod: Double = 0

    var body: some View {
        // A Canvas is a blank sheet that the code draws on directly, one
        // shape after another, like painting. The parts go on in the
        // icon's order: stalk, leaves, then the flower on top.
        Canvas { context, size in
            // `drawLayer` gives a clear sheet of its own to draw on, so
            // that a `.gap` rubs out only the snowdrop and never what is
            // behind it.
            context.drawLayer { sheet in
                Self.draw(style, lean: lean, nod: nod, on: &sheet, size: size)
            }
        }
        .accessibilityHidden(true)
    }

    private static func draw(_ style: SnowdropStyle, lean: Double, nod: Double,
                             on sheet: inout GraphicsContext, size: CGSize) {
        // Line the sheet up with the icon's numbers: the circle's middle
        // (200, 215) goes to the middle of the space, and 400 of the
        // icon's units fill its width. After this, every shape and line
        // width below can be given in the icon's own numbers.
        let scale = min(size.width, size.height) / (2 * SnowdropArt.radius)
        sheet.translateBy(x: size.width / 2, y: size.height / 2)
        sheet.scaleBy(x: scale, y: scale)
        sheet.translateBy(x: -SnowdropArt.centre.x, y: -SnowdropArt.centre.y)

        // Three copies of the sheet, each turned a little more than the
        // last. Whatever is drawn on a copy comes out turned with it.
        var plant = sheet
        plant.turn(lean * SnowdropSway.plantShare, about: SnowdropSway.ground)
        var stalk = plant
        stalk.turn(lean * SnowdropSway.stalkShare, about: SnowdropSway.stalkBase)
        var head = stalk
        head.turn(nod * SnowdropSway.nodShare, about: SnowdropSway.stalkTip)

        // The stalk first, so the leaves cover its foot and the cap its tip.
        stalk.paint(SnowdropParts.stalk, fill: nil, line: style.stalk, width: style.stalkWidth)
        for leaf in SnowdropParts.leaves {
            plant.paint(leaf, fill: style.leaf, line: style.leafLine, width: style.leafWidth)
        }

        // The pale outline: a fatter copy of the flower, underneath it.
        if let halo = style.halo {
            for petal in SnowdropParts.petals { head.paint(petal, fill: halo, line: halo, width: 16.8) }
            for piece in SnowdropParts.cup { head.paint(piece, fill: halo, line: halo, width: 14.4) }
            head.paint(SnowdropParts.cap, fill: halo, line: halo, width: 16.7)
        }

        for petal in SnowdropParts.petals {
            head.paint(petal, fill: style.petal, line: style.flowerLine, width: style.petalWidth)
        }
        for piece in SnowdropParts.cup {
            head.paint(piece, fill: style.petal, line: style.flowerLine, width: style.cupWidth)
        }
        head.paint(SnowdropParts.vMark, fill: style.vMark, line: nil, width: 0)
        head.paint(SnowdropParts.cap, fill: style.cap, line: style.flowerLine, width: style.capWidth)
    }
}

private extension GraphicsContext {

    /// Turns the sheet about a point, as a page turns about a pin.
    /// Turning always happens about the sheet's corner, so the pin is
    /// moved to the corner, the sheet turned, and the pin moved back.
    mutating func turn(_ degrees: Double, about point: CGPoint) {
        translateBy(x: point.x, y: point.y)
        rotate(by: .degrees(degrees))
        translateBy(x: -point.x, y: -point.y)
    }

    /// Fills a shape, then draws the line round it. Either may be left out.
    func paint(_ path: Path, fill: SnowdropInk?, line: SnowdropInk?, width: CGFloat) {
        if let fill {
            let (sheet, paint) = brush(fill)
            sheet.fill(path, with: paint)
        }
        if let line {
            let (sheet, paint) = brush(line)
            // Round ends and round corners, as the icon draws them.
            sheet.stroke(path, with: paint, style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }
    }

    /// The sheet and the paint for one ink. A gap is painted with a
    /// rubber: `destinationOut` removes whatever the shape covers.
    private func brush(_ ink: SnowdropInk) -> (GraphicsContext, Shading) {
        switch ink {
        case .colour(let colour):
            return (self, .color(colour))
        case .surrounding:
            return (self, .foreground)
        case .gap:
            var rubber = self
            rubber.blendMode = .destinationOut
            return (rubber, .color(.black))
        }
    }
}

/// The snowdrop on its circle. The circle's rim trims the leaves, and
/// trims the flower too if the wind throws it that far.
struct SnowdropOnDisc: View {

    var style: SnowdropStyle
    var size: CGFloat = 54
    var lean: Double = 0
    var nod: Double = 0

    var body: some View {
        ZStack {
            Circle().fill(style.disc)
            SnowdropView(style: style, lean: lean, nod: nod)
                .clipShape(Circle())
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
