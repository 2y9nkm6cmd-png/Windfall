//
//  CornerSprigs.swift
//  Windfall
//
//  The twelve drawings for Today's corner, one for each month, and the
//  bee from the app icon.
//
//  Every drawing is made on a grid 150 wide and 96 high, the same grid
//  the old fixed drawing used, and is built from two kinds of thing:
//
//    - stems: curved lines, each from a start, past a bend, to an end
//    - parts: a leaf, a flower, a fruit and so on, fixed part way along
//      a stem
//
//  Keeping them apart is what lets the drawing move. When the wind bends
//  a stem, everything fixed to it goes with it.
//
//  The design was worked out on a canvas first (knowledge base doc 49,
//  project file design/living-corner.js). This file is that design
//  carried across, drawing for drawing.
//

import SwiftUI

// MARK: - Small sums

enum CornerMath {
    /// A value part way from one number to another. amount 0 gives the
    /// first, 1 the second.
    static func lerp(_ from: Double, _ to: Double, _ amount: Double) -> Double { from + (to - from) * amount }

    /// Keeps a value between 0 and 1.
    static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }

    /// Eases a 0 to 1 value so it starts and stops gently.
    static func smooth(_ value: Double) -> Double { let x = clamp(value); return x * x * (3 - 2 * x) }

    /// Eases a 0 to 1 value so it goes a little past the end and comes
    /// back: what makes a leaf pop open.
    static func back(_ value: Double) -> Double {
        let x = clamp(value), spring = 1.70158
        return 1 + (spring + 1) * pow(x - 1, 3) + spring * pow(x - 1, 2)
    }

    /// The point part way along a curve (0 at its start, 1 at its end).
    static func point(_ start: CGPoint, _ bend: CGPoint, _ end: CGPoint, _ along: Double) -> CGPoint {
        let rest = 1 - along
        return CGPoint(x: rest * rest * start.x + 2 * rest * along * bend.x + along * along * end.x,
                       y: rest * rest * start.y + 2 * rest * along * bend.y + along * along * end.y)
    }

    /// The direction a curve is heading at a point along it, in radians.
    static func heading(_ start: CGPoint, _ bend: CGPoint, _ end: CGPoint, _ along: Double) -> Double {
        let rest = 1 - along
        return atan2(2 * rest * (bend.y - start.y) + 2 * along * (end.y - bend.y),
                     2 * rest * (bend.x - start.x) + 2 * along * (end.x - bend.x))
    }

    static let degree = Double.pi / 180
}

// MARK: - Colours

/// A colour kept as three numbers, so two colours can be mixed. A fruit
/// ripening is one colour mixed slowly into another.
struct CornerRGB: Equatable {
    var red: Double
    var green: Double
    var blue: Double

    /// From the six-figure code a colour is usually written as: 0xC4DC84.
    init(_ code: UInt32) {
        red = Double((code >> 16) & 0xFF) / 255
        green = Double((code >> 8) & 0xFF) / 255
        blue = Double(code & 0xFF) / 255
    }

    init(red: Double, green: Double, blue: Double) { self.red = red; self.green = green; self.blue = blue }

    func mixed(with other: CornerRGB, by amount: Double) -> CornerRGB {
        let share = CornerMath.clamp(amount)
        return CornerRGB(red: CornerMath.lerp(red, other.red, share),
                         green: CornerMath.lerp(green, other.green, share),
                         blue: CornerMath.lerp(blue, other.blue, share))
    }

    func color(_ opacity: Double = 1) -> Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity) }
}

/// The corner's colours, for light mode and for dark.
///
/// The first six repeat Design/colours.json (Leaf, LeafFill, Petal, Sun,
/// PlantOut and Flowering), written out again here because mixing needs
/// the numbers. The rest are new and are Claude's proposal, waiting for
/// William to check (doc 49). The bee's are the app icon's own (doc 47).
struct CornerInks {
    let isDark: Bool
    let lineInk: CornerRGB
    let leafFill: CornerRGB
    let petal: CornerRGB
    let sun: CornerRGB
    let bud: CornerRGB
    let violet: CornerRGB
    let blossom: CornerRGB
    let primrose: CornerRGB
    let sage: CornerRGB
    let paleRose: CornerRGB
    let berry: CornerRGB
    let bramble: CornerRGB
    let rust: CornerRGB
    let amber: CornerRGB
    let catkin: CornerRGB
    let pearFruit: CornerRGB
    let anther: CornerRGB
    let frost: CornerRGB
    let unripe: CornerRGB
    let ivy: CornerRGB
    let beeBody: CornerRGB
    let beeGold: CornerRGB
    let beeEdge: CornerRGB
    let iconLeaf: CornerRGB
    let wing: CornerRGB

    static let light = CornerInks(
        isDark: false,
        lineInk: CornerRGB(0x06472A), leafFill: CornerRGB(0xC4DC84), petal: CornerRGB(0xF4C3CC), sun: CornerRGB(0xF2B632),
        bud: CornerRGB(0xE87BA4), violet: CornerRGB(0xA99BEA),
        blossom: CornerRGB(0xFFFDF8), primrose: CornerRGB(0xF7E58A), sage: CornerRGB(0xB7CBA2), paleRose: CornerRGB(0xFAE3E4),
        berry: CornerRGB(0xC9453C), bramble: CornerRGB(0x3F2B4F), rust: CornerRGB(0xC4682F), amber: CornerRGB(0xE9A93A),
        catkin: CornerRGB(0xE6D684), pearFruit: CornerRGB(0xDDD67A), anther: CornerRGB(0x8E2F3A), frost: CornerRGB(0x9CC3DC),
        unripe: CornerRGB(0xB4D182), ivy: CornerRGB(0x8DB56B),
        beeBody: CornerRGB(0x06421B), beeGold: CornerRGB(0xFECC50), beeEdge: CornerRGB(0x06421B),
        iconLeaf: CornerRGB(0xC0D76D), wing: CornerRGB(0xFFFFFF))

    static let dark = CornerInks(
        isDark: true,
        lineInk: CornerRGB(0xBCEC8C), leafFill: CornerRGB(0x35522A), petal: CornerRGB(0xB98592), sun: CornerRGB(0xF2B632),
        bud: CornerRGB(0xD55181), violet: CornerRGB(0x9085E9),
        blossom: CornerRGB(0xF1EADB), primrose: CornerRGB(0xE3CF6E), sage: CornerRGB(0x4C6A4C), paleRose: CornerRGB(0xFAE3E4),
        berry: CornerRGB(0xD9655A), bramble: CornerRGB(0x8E74A8), rust: CornerRGB(0xB8683A), amber: CornerRGB(0xC98500),
        catkin: CornerRGB(0xB9A552), pearFruit: CornerRGB(0xA9A650), anther: CornerRGB(0xB5505C), frost: CornerRGB(0xA9CBE0),
        unripe: CornerRGB(0x5E7F3F), ivy: CornerRGB(0x2C5A34),
        beeBody: CornerRGB(0x06421B), beeGold: CornerRGB(0xFECC50), beeEdge: CornerRGB(0xFAEEE0),
        iconLeaf: CornerRGB(0x7FA050), wing: CornerRGB(0xFFFFFF))
}

/// A way of naming one of the colours above without saying light or
/// dark: `\.petal` means "the petal colour of whichever set is in use".
typealias CornerInk = KeyPath<CornerInks, CornerRGB>

// MARK: - Stems and parts

/// One curved line of a drawing.
struct CornerStem {
    var start: CGPoint
    var bend: CGPoint
    var end: CGPoint
    /// The stem this one grows from, or -1 if it comes out of the ground.
    var parentIndex: Int
    /// How far along its parent it starts.
    var joinsAt: Double
    /// The foot of the whole plant. The wind bends everything about it.
    var foot: CGPoint
    var lineWidth: Double
    var waits: Double
    /// A stem that is there to hold parts but is not itself drawn.
    var isHidden: Bool
    /// When it starts to draw, and for how long, in seconds after the
    /// screen opens. Worked out by `setTimes`.
    var startsAt = 0.0
    var takes = 0.0
}

/// Where the bee settles on a part, measured from the part's own start
/// and along its own direction, and which way the bee then faces.
struct CornerPerch {
    var x: Double
    var y: Double
    var headingDegrees: Double
}

/// One outline taken from a picture file, with how to paint it.
struct CornerArtPath {
    let artOutline: Path
    let fill: CornerInk?
    let lineWidth: Double
}

/// What a part is and the numbers that shape it.
enum CornerShape {
    case leaf(length: Double, bulge: Double, fill: CornerInk, vein: Bool, pale: Double, tint: Double)
    case ivyLeaf(length: Double)
    case flower(radius: Double, fill: CornerInk, budFill: CornerInk, centre: CornerInk, anthers: CornerInk?, open: Double)
    case daffodil(radius: Double, open: Double)
    case catkin(length: Double)
    case bell(length: Double, isOpen: Bool)
    case berry(radius: Double, ripe: Double)
    case pear(tall: Double, ripe: Double)
    case apple(radius: Double, ripe: Double)
    case umbel(radius: Double, ripe: Double)
    case pearl(radius: Double)
    case thorn
    case art(paths: [CornerArtPath], scale: Double, pivot: CGPoint, clip: CGRect?)

    /// A leaf with the usual settings, so each drawing only says what
    /// is different about its leaves.
    static func plainLeaf(_ length: Double, bulge: Double = 0.26, fill: CornerInk = \.leafFill,
                          vein: Bool = false, pale: Double = 0, tint: Double = 0) -> CornerShape {
        .leaf(length: length, bulge: bulge, fill: fill, vein: vein, pale: pale, tint: tint)
    }
}

/// One thing fixed to a stem.
struct CornerPart {
    var stemIndex: Int
    /// How far along the stem: 0 at its start, 1 at its end.
    var along: Double
    var cornerShape: CornerShape

    /// The angle it points, in degrees, measured from the stem's own
    /// direction. When nil, `angle` is used, measured from the page.
    var relativeAngle: Double?
    var angle = 0.0
    /// A part that hangs straight down and swings like a weight.
    var hangs = false
    /// For a hanging part: how far off straight down, in degrees.
    var fan = 0.0
    /// How freely a hanging part swings.
    var swing = 1.0
    /// How much it flutters in the wind. 0 is not at all.
    var flutter = 1.0
    var waits = 0.0

    var perch: CornerPerch?
    /// True when the perch is the exact place for the middle of the
    /// bee's front part, as on the app icon.
    var perchIsExact = false
    /// True where the bee stays longer: the snowdrop.
    var beeLingers = false
    /// True for a foxglove bell, which the bee climbs into.
    var beeClimbsIn = false
    /// Petals or leaves fall from here.
    var sheds = false
    /// The apple that drops.
    var isWindfall = false
    /// Turns with the tip of its stem and not with the wind's flutter:
    /// the snowdrop's stalk.
    var turnsWithTip = false

    /// When it opens, in seconds after the screen opens.
    var startsAt = 0.0

    init(_ stemIndex: Int, _ along: Double, _ cornerShape: CornerShape) {
        self.stemIndex = stemIndex
        self.along = along
        self.cornerShape = cornerShape
    }

    /// The length of a foxglove bell, which the bee needs to know how
    /// far to climb in. 0 for anything else.
    var bellLength: Double {
        if case .bell(let length, _) = cornerShape { return length }
        return 0
    }

    /// True for a leaf, which droops in great heat.
    var isLeaf: Bool {
        switch cornerShape {
        case .leaf, .ivyLeaf: return true
        default: return false
        }
    }

    /// False for a flower still in bud, which the bee does not visit.
    var isOpenEnoughForBee: Bool {
        if case .flower(_, _, _, _, _, let open) = cornerShape { return open >= 0.3 }
        return true
    }
}

/// A whole drawing: its stems and its parts.
struct CornerSprig {
    var stems: [CornerStem] = []
    var parts: [CornerPart] = []

    /// Adds a stem that comes out of the ground. Gives back its number,
    /// which parts and side stems use to say which stem they are on.
    @discardableResult
    mutating func stem(_ start: CGPoint, _ bend: CGPoint, _ end: CGPoint,
                       width: Double = 1.3, waits: Double = 0, isHidden: Bool = false) -> Int {
        stems.append(CornerStem(start: start, bend: bend, end: end, parentIndex: -1, joinsAt: 0, foot: start,
                                lineWidth: width, waits: waits, isHidden: isHidden))
        return stems.count - 1
    }

    /// Adds a side stem. `bendBy` and `endBy` are how far its bend and
    /// its end sit from the point where it leaves its parent.
    @discardableResult
    mutating func branch(_ parentIndex: Int, _ joinsAt: Double, _ bendBy: CGPoint, _ endBy: CGPoint,
                         width: Double = 1.05) -> Int {
        let parent = stems[parentIndex]
        let from = CornerMath.point(parent.start, parent.bend, parent.end, joinsAt)
        stems.append(CornerStem(start: from,
                                bend: CGPoint(x: from.x + bendBy.x, y: from.y + bendBy.y),
                                end: CGPoint(x: from.x + endBy.x, y: from.y + endBy.y),
                                parentIndex: parentIndex, joinsAt: joinsAt, foot: parent.foot,
                                lineWidth: width, waits: 0, isHidden: false))
        return stems.count - 1
    }

    /// Fixes a part to a stem. The last piece, in curly brackets, sets
    /// anything about the part that is not the usual.
    mutating func add(_ stemIndex: Int, _ along: Double, _ cornerShape: CornerShape,
                      _ setUp: (inout CornerPart) -> Void = { _ in }) {
        var sprigPart = CornerPart(stemIndex, along, cornerShape)
        setUp(&sprigPart)
        parts.append(sprigPart)
    }

    /// Works out when each stem and part appears as the drawing grows
    /// in: a stem starts when its parent has grown as far as the join,
    /// and a part opens when its stem reaches it.
    mutating func setTimes() {
        for index in stems.indices {
            let stem = stems[index]
            let length = hypot(stem.bend.x - stem.start.x, stem.bend.y - stem.start.y)
                + hypot(stem.end.x - stem.bend.x, stem.end.y - stem.bend.y)
            stems[index].takes = min(max(length / 95, 0.22), 1.15)
            stems[index].startsAt = stem.parentIndex < 0
                ? stem.waits
                : stems[stem.parentIndex].startsAt + stem.joinsAt * stems[stem.parentIndex].takes
        }
        for index in parts.indices {
            let stem = stems[parts[index].stemIndex]
            parts[index].startsAt = stem.startsAt + parts[index].along * stem.takes + parts[index].waits
        }
    }
}

// MARK: - The twelve months

extension CornerSprig {

    private static func at(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

    /// The drawing for a month. `progress` runs from 0 on the 1st to 1 on
    /// the last day, and moves each drawing on a little: buds open, fruit
    /// ripens, leaves thin.
    static func make(monthNumber: Int, monthProgress progress: Double) -> CornerSprig {
        let t = CornerMath.clamp(progress)
        var sprig: CornerSprig
        switch monthNumber {
        case 1: sprig = hazel(t)
        case 2: sprig = snowdrop(t)
        case 3: sprig = daffodil(t)
        case 4: sprig = pearBlossom(t)
        case 5: sprig = appleBlossom(t)
        case 6: sprig = foxglove(t)
        case 7: sprig = lavender(t)
        case 8: sprig = blackberry(t)
        case 9: sprig = pear(t)
        case 10: sprig = apple(t)
        case 11: sprig = ivy(t)
        default: sprig = mistletoe(t)
        }
        sprig.setTimes()
        return sprig
    }

    // January: hazel catkins on a bare twig. They lengthen through the month.
    private static func hazel(_ t: Double) -> CornerSprig {
        var twig = CornerSprig()
        let a = twig.stem(at(6, 90), at(58, 88), at(114, 38), width: 1.5)
        let b = twig.branch(a, 0.4, at(14, -8), at(27, -23))
        let c = twig.branch(a, 0.7, at(14, -2), at(31, 3))
        let buds: [(Int, Double, Double)] = [(a, 0.16, -62), (a, 0.3, 42), (a, 0.58, -60), (a, 0.88, 40), (b, 0.55, -70), (c, 0.5, 62)]
        for bud in buds {
            twig.add(bud.0, bud.1, .plainLeaf(5, bulge: 0.34)) { $0.relativeAngle = bud.2; $0.flutter = 0 }
        }
        let length = CornerMath.lerp(15, 27, t)
        let catkins: [(Int, Double, Double, Double)] = [(a, 1, -9, 1), (a, 1, 4, 0.82), (a, 1, 15, 0.66), (b, 1, -8, 0.9), (b, 1, 7, 0.7),
                                                        (c, 1, -10, 0.72), (c, 1, 3, 0.92), (c, 1, 14, 0.6), (a, 0.5, 6, 0.6)]
        for (index, catkin) in catkins.enumerated() {
            twig.add(catkin.0, catkin.1, .catkin(length: length * catkin.3)) {
                $0.hangs = true; $0.fan = catkin.2; $0.swing = 0.8 + Double(index % 3) * 0.25
            }
        }
        return twig
    }

    // February: the snowdrop of the app icon, from the icon's own
    // outlines (CornerIconArt.swift). The bee hangs under the flower.
    private static func snowdrop(_ t: Double) -> CornerSprig {
        var twig = CornerSprig()
        // `scale` turns the icon's positions into grid positions. The
        // foot of the plant, at 100, 407 on the icon, sits at 88, 93.
        let scale = 0.16, left = 88 - 100 * scale, top = 93 - 407 * scale
        func place(_ x: Double, _ y: Double) -> CGPoint { at(left + x * scale, top + y * scale) }
        let foot = CGPoint(x: 100, y: 407), tip = CGPoint(x: 256.5, y: 86)
        // A stem that is not drawn. It runs from the foot to the tip of
        // the stalk, so the flower has something to hang from.
        let a = twig.stem(place(100, 407), place(150, 230), place(256.5, 86), isHidden: true)
        twig.add(a, 0, .art(paths: CornerIconArt.stalk, scale: scale, pivot: foot, clip: nil)) { $0.turnsWithTip = true }
        for (index, leaf) in CornerIconArt.leaves.enumerated() {
            twig.add(a, 0, .art(paths: [leaf], scale: scale * CornerMath.lerp(0.84, 1, t), pivot: foot,
                             clip: CGRect(x: 0, y: 0, width: 460, height: 407.5))) {
                $0.flutter = 0.35 + Double(index) * 0.2; $0.waits = 0.1 * Double(index)
            }
        }
        // The bee's place is where the icon has it: 185.5 below the
        // stalk's tip and 8.5 to its right.
        twig.add(a, 1, .art(paths: CornerIconArt.flower, scale: scale, pivot: tip, clip: nil)) {
            $0.hangs = true; $0.swing = 0.55
            $0.perch = CornerPerch(x: 185.5 * scale, y: -8.5 * scale, headingDegrees: 169)
            $0.perchIsExact = true; $0.beeLingers = true
        }
        return twig
    }

    // March: two daffodils. One opens early, the second follows.
    private static func daffodil(_ t: Double) -> CornerSprig {
        var twig = CornerSprig()
        struct Bulb { let x: Double; let bend: CGPoint; let end: CGPoint; let radius: Double; let order: Double
                      let leafAngles: [Double]; let leafLengths: [Double]; let faces: Double }
        let bulbs = [Bulb(x: 96, bend: at(93, 62), end: at(87, 37), radius: 15, order: 0,
                          leafAngles: [-80, -104, -92], leafLengths: [50, 44, 30], faces: 25),
                     Bulb(x: 109, bend: at(113, 72), end: at(121, 53), radius: 12, order: 1,
                          leafAngles: [-68, -96], leafLengths: [38, 32], faces: -20)]
        for bulb in bulbs {
            let open = CornerMath.clamp(t * 2.4 + 0.7 - bulb.order * 1.1)
            let a = twig.stem(at(bulb.x, 95), bulb.bend, bulb.end, width: 1.5, waits: bulb.order * 0.25)
            for (index, angle) in bulb.leafAngles.enumerated() {
                twig.add(a, 0, .plainLeaf(bulb.leafLengths[index], bulge: 0.062)) { $0.angle = angle; $0.flutter = 0.45 }
            }
            twig.add(a, 1, .daffodil(radius: bulb.radius, open: open)) {
                $0.angle = open < 0.35 ? (bulb.order > 0 ? -40 : -150) : bulb.faces
                $0.flutter = 0.6
                if open >= 0.35 { $0.perch = CornerPerch(x: 0, y: 0, headingDegrees: bulb.order > 0 ? 200 : 140) }
            }
        }
        return twig
    }

    // April: pear blossom. White petals, dark red anthers.
    private static func pearBlossom(_ t: Double) -> CornerSprig {
        var twig = CornerSprig()
        let a = twig.stem(at(6, 90), at(62, 86), at(106, 42), width: 1.4)
        let leaves: [(Double, Double, Double)] = [(0.24, -58, 14), (0.4, 26, 13), (0.55, -62, 16), (0.68, 20, 14), (0.8, -75, 13)]
        for leaf in leaves {
            twig.add(a, leaf.0, .plainLeaf(leaf.2 * CornerMath.lerp(0.8, 1.15, t), bulge: 0.3)) { $0.relativeAngle = leaf.1 }
        }
        let flowers: [(Double, CGPoint, CGPoint, Double, Double)] = [(1, at(3, -6), at(9, -13), 12, 0.5), (0.86, at(-2, -8), at(-5, -19), 10, 0),
                                                                     (0.95, at(9, 1), at(20, 2), 9.5, -0.5), (0.72, at(5, 6), at(12, 10), 8, -1.6)]
        for (index, flower) in flowers.enumerated() {
            let b = twig.branch(a, flower.0, flower.1, flower.2)
            let open = CornerMath.clamp(t * 2.4 + flower.4 + 0.35)
            twig.add(b, 1, .flower(radius: flower.3, fill: \.blossom, budFill: \.blossom, centre: \.unripe, anthers: \.anther, open: open)) {
                $0.angle = Double(index) * 23; $0.flutter = 0.6; $0.sheds = true; $0.waits = 0.1
                $0.perch = CornerPerch(x: 0, y: 0, headingDegrees: -30 + Double(index) * 40)
            }
        }
        return twig
    }

    // May: apple blossom. Close to the drawing the app had before.
    private static func appleBlossom(_ t: Double) -> CornerSprig {
        var twig = CornerSprig()
        let a = twig.stem(at(6, 90), at(62, 86), at(108, 40), width: 1.4)
        let leaves: [(Double, Double, Double)] = [(0.2, -55, 24), (0.33, 20, 22), (0.47, -62, 28), (0.6, 12, 24), (0.76, -70, 24), (0.5, -120, 18)]
        for leaf in leaves {
            twig.add(a, leaf.0, .plainLeaf(leaf.2 * 0.92, vein: true)) { $0.relativeAngle = leaf.1 + 30 }
        }
        let flowers: [(Double, CGPoint, CGPoint, Double, Double)] = [(1, at(3, -5), at(8, -11), 14, 0.6), (0.88, at(-3, -8), at(-9, -18), 10.5, 0.1),
                                                                     (0.96, at(9, 3), at(21, 6), 9, -0.5), (0.8, at(3, -8), at(5, -17), 6, -1.4)]
        for (index, flower) in flowers.enumerated() {
            let b = twig.branch(a, flower.0, flower.1, flower.2)
            let open = CornerMath.clamp(t * 2.2 + flower.4 + 0.3)
            twig.add(b, 1, .flower(radius: flower.3, fill: \.petal, budFill: \.bud, centre: \.sun, anthers: nil, open: open)) {
                $0.angle = Double(index) * 31; $0.flutter = 0.6; $0.sheds = true; $0.waits = 0.1
                $0.perch = CornerPerch(x: 0, y: 0, headingDegrees: 20 + Double(index) * 50)
            }
        }
        return twig
    }

    // June: a foxglove. The bells open from the bottom up, and the bee
    // climbs right inside one.
    private static func foxglove(_ t: Double) -> CornerSprig {
        var twig = CornerSprig()
        let a = twig.stem(at(56, 95), at(62, 56), at(86, 6), width: 1.6)
        twig.add(a, 0.02, .plainLeaf(26, bulge: 0.3, vein: true)) { $0.angle = -158 }
        twig.add(a, 0.05, .plainLeaf(28, bulge: 0.3, vein: true)) { $0.angle = -12 }
        twig.add(a, 0.12, .plainLeaf(20, bulge: 0.3, vein: true)) { $0.angle = -118 }
        let openCount = Int(CornerMath.lerp(4, 8, t).rounded())
        // Counted from the top down, so each lower bell is drawn over
        // the one above it, like tiles on a roof.
        for index in stride(from: 10, through: 0, by: -1) {
            let place = Double(index)
            let along = index < 8 ? 0.24 + place * 0.086 : 0.88 + (place - 8) * 0.045
            let length = index < 8 ? CornerMath.lerp(19, 9, place / 7) : 5 - (place - 8)
            let isOpen = index < openCount
            twig.add(a, along, .bell(length: length, isOpen: isOpen)) {
                $0.angle = CornerMath.lerp(40, 8, place / 10); $0.flutter = 0.8; $0.beeClimbsIn = true
                if isOpen && index > 0 && index < openCount - 1 {
                    $0.perch = CornerPerch(x: length + 7, y: 1, headingDegrees: 180)
                }
            }
        }
        return twig
    }

    // July: lavender. Five stems, each swaying on its own. The spikes
    // colour up from the bottom.
    private static func lavender(_ t: Double) -> CornerSprig {
        var twig = CornerSprig()
        let stalks: [(Double, CGPoint, CGPoint)] = [(84, at(78, 60), at(66, 30)), (88, at(86, 56), at(84, 20)), (92, at(96, 58), at(103, 24)),
                                                    (95, at(104, 64), at(120, 36)), (80, at(70, 70), at(52, 48))]
        for (number, stalk) in stalks.enumerated() {
            let odd = number % 2 == 1
            let a = twig.stem(at(stalk.0, 95), stalk.1, stalk.2, width: 1.1, waits: Double(number) * 0.08)
            let leaves: [(Double, Double)] = [(0.12, 34), (0.12, -34), (0.27, odd ? 30 : -30)]
            for leaf in leaves {
                twig.add(a, leaf.0, .plainLeaf(odd ? 9 : 11, bulge: 0.12, fill: \.sage)) { $0.relativeAngle = leaf.1; $0.flutter = 0.6 }
            }
            for floret in 0..<5 {
                let place = Double(floret)
                let out = CornerMath.clamp(t * 2.2 + 0.55 - place * 0.28)
                for side in [52.0, -52.0] {
                    twig.add(a, 0.64 + place * 0.08, .plainLeaf(5.2 - place * 0.35, bulge: 0.42, fill: \.violet, pale: 1 - out)) {
                        $0.relativeAngle = side; $0.flutter = 0.3
                    }
                }
            }
            twig.add(a, 1, .plainLeaf(5, bulge: 0.4, fill: \.violet, pale: 1 - CornerMath.clamp(t * 2.2 - 0.6))) {
                $0.relativeAngle = 0; $0.flutter = 0.3
                if number < 4 { $0.perch = CornerPerch(x: -5, y: 0, headingDegrees: 0); $0.perchIsExact = true }
            }
        }
        return twig
    }

    // August: blackberry. Flower and fruit together, the berries
    // ripening green, red, black.
    private static func blackberry(_ t: Double) -> CornerSprig {
        var twig = CornerSprig()
        let a = twig.stem(at(6, 88), at(64, 86), at(112, 48), width: 1.4)
        let thorns: [(Double, Double)] = [(0.12, -90), (0.28, 90), (0.5, -90), (0.68, 90)]
        for thorn in thorns {
            twig.add(a, thorn.0, .thorn) { $0.relativeAngle = thorn.1 + 90; $0.flutter = 0 }
        }
        let leafStalks: [(Double, CGPoint, CGPoint)] = [(0.24, at(-3, -8), at(-2, -15)), (0.42, at(9, 1), at(17, -1)), (0.62, at(-5, -8), at(-6, -16))]
        for leafStalk in leafStalks {
            let b = twig.branch(a, leafStalk.0, leafStalk.1, leafStalk.2)
            for turn in [-52.0, 0, 52] {
                twig.add(b, 1, .plainLeaf(turn == 0 ? 15 : 12, bulge: 0.38, vein: true)) { $0.relativeAngle = turn }
            }
        }
        let berries: [(CGPoint, CGPoint, Double, Double)] = [(at(4, -4), at(10, -11), 0.75, 5.2), (at(8, 2), at(19, 1), 0.45, 4.8), (at(-1, -8), at(-3, -19), 0.15, 4.4),
                                                             (at(9, -9), at(22, -15), -0.2, 4.2), (at(4, 6), at(10, 13), 0.3, 4.4)]
        for berry in berries {
            let b = twig.branch(a, 1, berry.0, berry.1)
            twig.add(b, 1, .berry(radius: berry.3, ripe: CornerMath.clamp(t * 1.25 + berry.2 * 0.6))) { $0.relativeAngle = 0; $0.flutter = 0.5 }
        }
        let f = twig.branch(a, 0.84, at(-2, -9), at(-8, -20))
        twig.add(f, 1, .flower(radius: 8.5, fill: \.paleRose, budFill: \.paleRose, centre: \.unripe, anthers: nil, open: 1)) {
            $0.angle = 12; $0.flutter = 0.6; $0.perch = CornerPerch(x: 0, y: 0, headingDegrees: 150)
        }
        return twig
    }

    // September: pears on a bough. They swell and yellow.
    private static func pear(_ t: Double) -> CornerSprig {
        var twig = CornerSprig()
        let a = twig.stem(at(6, 90), at(38, 30), at(126, 27), width: 1.7)
        let leaves: [(Double, Double, Double)] = [(0.3, -62, 20), (0.43, 52, 21), (0.56, -52, 23), (0.7, 46, 19), (0.8, -50, 22), (0.93, 40, 17), (1, 4, 17)]
        for (index, leaf) in leaves.enumerated() {
            twig.add(a, leaf.0, .plainLeaf(leaf.2, bulge: 0.3, vein: true)) {
                $0.relativeAngle = leaf.1
                if index == 4 { $0.perch = CornerPerch(x: 8, y: 0, headingDegrees: 0) }
            }
        }
        twig.add(a, 0.62, .pear(tall: CornerMath.lerp(21, 27, t), ripe: t)) { $0.hangs = true; $0.fan = -3; $0.swing = 0.55 }
        twig.add(a, 0.88, .pear(tall: CornerMath.lerp(17, 22, t), ripe: t * 0.8)) { $0.hangs = true; $0.fan = 4; $0.swing = 0.7 }
        return twig
    }

    // October: apples. The leaves turn and thin, and one apple drops.
    private static func apple(_ t: Double) -> CornerSprig {
        var twig = CornerSprig()
        let a = twig.stem(at(6, 90), at(40, 30), at(128, 28), width: 1.7)
        let turned: [CornerInk?] = [nil, \.amber, nil, \.rust, \.amber, nil, \.rust]
        let kept = Int(CornerMath.lerp(7, 4, t).rounded())
        let leaves: [(Double, Double, Double)] = [(0.3, -60, 20), (0.4, -64, 18), (0.57, -56, 22), (0.64, 40, 15), (0.8, -50, 21), (0.86, 38, 15), (1, 2, 16)]
        for (index, leaf) in leaves.enumerated() where (index * 3) % 7 < kept {
            // A leaf still green is tinted towards amber as the month goes on.
            let shape: CornerShape
            if let turnedInk = turned[index] {
                shape = CornerShape.plainLeaf(leaf.2, bulge: 0.3, fill: turnedInk, vein: true)
            } else {
                shape = CornerShape.plainLeaf(leaf.2, bulge: 0.3, vein: true, tint: t * 0.6)
            }
            twig.add(a, leaf.0, shape) { $0.relativeAngle = leaf.1; $0.sheds = true }
        }
        let ripe = CornerMath.clamp(0.72 + t * 0.3)
        twig.add(a, 0.5, .apple(radius: 7.6, ripe: ripe)) { $0.hangs = true; $0.fan = -4; $0.swing = 0.5 }
        twig.add(a, 0.72, .apple(radius: 8.6, ripe: ripe)) { $0.hangs = true; $0.fan = 3; $0.swing = 0.45; $0.isWindfall = true }
        twig.add(a, 0.93, .apple(radius: 7, ripe: ripe * 0.9)) { $0.hangs = true; $0.fan = 6; $0.swing = 0.6 }
        return twig
    }

    // November: ivy in flower, the last flowers of the year. Late in
    // the month they set green berries.
    private static func ivy(_ t: Double) -> CornerSprig {
        var twig = CornerSprig()
        let a = twig.stem(at(6, 84), at(60, 84), at(112, 46), width: 1.4)
        let leaves: [(Double, Double, Double)] = [(0.16, -70, 17), (0.31, 62, 15), (0.45, -64, 20), (0.6, 58, 15), (0.74, -70, 17)]
        for leaf in leaves {
            let above = leaf.1 < 0
            let b = twig.branch(a, leaf.0, above ? at(0, -4) : at(3, 2), above ? at(-1, -8) : at(7, 3))
            twig.add(b, 1, .ivyLeaf(length: leaf.2)) { $0.relativeAngle = above ? 0 : 12 }
        }
        let heads: [(Double, CGPoint, CGPoint, Double, Double, Double)] = [(1, at(3, -6), at(8, -13), 9.5, -70, 0), (0.9, at(8, 3), at(19, 4), 8, -8, 0.25),
                                                                           (0.84, at(-4, -7), at(-8, -17), 7.5, -112, 0.4)]
        for (index, head) in heads.enumerated() {
            let b = twig.branch(a, head.0, head.1, head.2)
            twig.add(b, 1, .umbel(radius: head.3, ripe: CornerMath.clamp((t - 0.45) * 2.2 + head.5))) {
                $0.angle = head.4; $0.flutter = 0.5
                if index == 0 { $0.perch = CornerPerch(x: head.3 + 2, y: 0, headingDegrees: 180) }
            }
        }
        return twig
    }

    // December: mistletoe on a bare apple bough. It forks in two, and
    // in two again. More berries as the month goes on.
    private static func mistletoe(_ t: Double) -> CornerSprig {
        var twig = CornerSprig()
        let a = twig.stem(at(6, 91), at(62, 93), at(142, 66), width: 1.9)
        twig.add(a, 0.2, .plainLeaf(5, bulge: 0.34)) { $0.relativeAngle = -50; $0.flutter = 0 }
        twig.add(a, 0.84, .plainLeaf(5, bulge: 0.34)) { $0.relativeAngle = -55; $0.flutter = 0 }
        let spur = twig.branch(a, 0.9, at(3, -5), at(9, -8))
        twig.add(spur, 1, .plainLeaf(5, bulge: 0.34)) { $0.relativeAngle = 0; $0.flutter = 0 }
        let berryCount = Int(CornerMath.lerp(3, 8, t).rounded())
        var tipNumber = 0
        let spread = [0.0, 21, 29, 42]
        // `fork` calls itself: each stem ends in two shorter stems,
        // until `forksLeft` runs out and it ends in a pair of leaves.
        func fork(from parentIndex: Int, degrees: Double, length: Double, forksLeft: Int) {
            let across = cos(degrees * CornerMath.degree) * length, down = sin(degrees * CornerMath.degree) * length
            let b = twig.branch(parentIndex, parentIndex == a ? 0.52 : 1, at(across * 0.5, down * 0.5), at(across, down), width: 1.25)
            if forksLeft == 0 {
                twig.add(b, 1, .plainLeaf(12, bulge: 0.17)) { $0.angle = degrees - 16; $0.flutter = 0.7 }
                twig.add(b, 1, .plainLeaf(12, bulge: 0.17)) { $0.angle = degrees + 16; $0.flutter = 0.7 }
                if (tipNumber * 5) % 8 < berryCount {
                    twig.add(b, 1, .pearl(radius: 2.2)) { $0.angle = degrees; $0.waits = 0.25; $0.flutter = 0 }
                }
                tipNumber += 1
                return
            }
            fork(from: b, degrees: degrees - spread[forksLeft], length: length * 0.84, forksLeft: forksLeft - 1)
            fork(from: b, degrees: degrees + spread[forksLeft], length: length * 0.84, forksLeft: forksLeft - 1)
        }
        fork(from: a, degrees: -86, length: 15, forksLeft: 3)
        return twig
    }
}

// MARK: - Shapes

enum CornerPaths {

    /// A pointed leaf lying along the x axis: two curves from its base
    /// to its tip and back. The same shape the old drawing used.
    static func leaf(_ length: Double, _ bulge: Double) -> Path {
        var path = Path()
        path.move(to: .zero)
        path.addQuadCurve(to: CGPoint(x: length, y: 0), control: CGPoint(x: length * 0.45, y: length * bulge))
        path.addQuadCurve(to: .zero, control: CGPoint(x: length * 0.45, y: -length * bulge))
        return path
    }

    static func dot(_ x: Double, _ y: Double, _ radius: Double) -> Path {
        Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
    }

    /// An oval, turned by `turn` radians about its own middle.
    static func oval(_ x: Double, _ y: Double, _ halfWidth: Double, _ halfHeight: Double, turn: Double = 0) -> Path {
        Path(ellipseIn: CGRect(x: -halfWidth, y: -halfHeight, width: halfWidth * 2, height: halfHeight * 2))
            .applying(CGAffineTransform(translationX: x, y: y).rotated(by: turn))
    }

    static func line(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.addLines(points)
        return path
    }

    /// One of the bee's wings: narrow where it joins the body, widest
    /// near its rounded tip. It lies along the x axis.
    static func wing(_ length: Double, _ halfWidth: Double) -> Path {
        let c = length - halfWidth, round = halfWidth * 0.5523
        var path = Path()
        path.move(to: .zero)
        path.addCurve(to: CGPoint(x: c, y: halfWidth), control1: CGPoint(x: c * 0.08, y: halfWidth * 0.55), control2: CGPoint(x: c * 0.55, y: halfWidth))
        // The rounded tip: half a circle made of two curves.
        path.addCurve(to: CGPoint(x: length, y: 0), control1: CGPoint(x: c + round, y: halfWidth), control2: CGPoint(x: length, y: round))
        path.addCurve(to: CGPoint(x: c, y: -halfWidth), control1: CGPoint(x: length, y: -round), control2: CGPoint(x: c + round, y: -halfWidth))
        path.addCurve(to: .zero, control1: CGPoint(x: c * 0.55, y: -halfWidth), control2: CGPoint(x: c * 0.08, y: -halfWidth * 0.55))
        return path
    }

    /// Turns the path text a picture file uses into a shape. It reads
    /// the four instructions the icon's outlines use: M (move to),
    /// L (line to), C (curve to: two control points, then the end) and
    /// Z (close the shape).
    static func fromText(_ text: String) -> Path {
        var path = Path()
        var letter: Character = "M"
        var numbers: [Double] = []
        var digits = ""

        func point(_ index: Int) -> CGPoint { CGPoint(x: numbers[index], y: numbers[index + 1]) }
        func useNumbers() {
            if let value = Double(digits) { numbers.append(value) }
            digits = ""
            switch letter {
            case "M" where numbers.count == 2: path.move(to: point(0)); numbers = []; letter = "L"
            case "L" where numbers.count == 2: path.addLine(to: point(0)); numbers = []
            case "C" where numbers.count == 6: path.addCurve(to: point(4), control1: point(0), control2: point(2)); numbers = []
            default: break
            }
        }
        for character in text {
            if character.isLetter {
                useNumbers()
                if character == "Z" || character == "z" { path.closeSubpath() } else { letter = character }
                numbers = []
            } else if character == " " || character == "," {
                useNumbers()
            } else if character == "-" && !digits.isEmpty {
                useNumbers(); digits = "-"
            } else {
                digits.append(character)
            }
        }
        useNumbers()
        return path
    }
}

// MARK: - Drawing a part

enum CornerDraw {

    /// Fills a shape and draws its outline in the line colour.
    static func paint(_ path: Path, in g: inout GraphicsContext, _ inks: CornerInks,
                              fill: CornerRGB?, lineOpacity: Double = 0.7, lineWidth: Double = 1) {
        if let fill { g.fill(path, with: .color(fill.color())) }
        g.stroke(path, with: .color(inks.lineInk.color(lineOpacity)),
                 style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }

    private static func stroke(_ path: Path, in g: inout GraphicsContext, _ colour: Color, _ lineWidth: Double) {
        g.stroke(path, with: .color(colour), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }

    private static func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

    /// Draws one part. The drawing space has already been moved, turned
    /// and scaled so that the part starts at 0, 0 and points along x.
    static func sprigPart(_ sprigPart: CornerPart, in g: inout GraphicsContext, _ inks: CornerInks) {
        switch sprigPart.cornerShape {

        case .leaf(let length, let bulge, let fill, let vein, let pale, let tint):
            var colour = inks[keyPath: fill]
            if pale > 0 { colour = colour.mixed(with: inks.sage, by: pale) }
            if tint > 0 { colour = colour.mixed(with: inks.amber, by: tint) }
            let small = length < 7
            paint(CornerPaths.leaf(length, bulge), in: &g, inks, fill: colour, lineOpacity: small ? 0.5 : 0.7, lineWidth: small ? 0.7 : 1)
            if vein { stroke(CornerPaths.line([p(1, 0), p(length * 0.78, 0)]), in: &g, inks.lineInk.color(0.3), 0.7) }

        case .ivyLeaf(let l):
            var path = Path()
            path.move(to: .zero)
            path.addQuadCurve(to: p(0.42 * l, -0.6 * l), control: p(0.02 * l, -0.56 * l))
            path.addQuadCurve(to: p(0.56 * l, -0.24 * l), control: p(0.5 * l, -0.4 * l))
            path.addQuadCurve(to: p(l, 0), control: p(0.82 * l, -0.24 * l))
            path.addQuadCurve(to: p(0.56 * l, 0.24 * l), control: p(0.82 * l, 0.24 * l))
            path.addQuadCurve(to: p(0.42 * l, 0.6 * l), control: p(0.5 * l, 0.4 * l))
            path.addQuadCurve(to: .zero, control: p(0.02 * l, 0.56 * l))
            paint(path, in: &g, inks, fill: inks.ivy)
            var veins = Path()
            veins.move(to: p(1, 0)); veins.addLine(to: p(l * 0.8, 0))
            veins.move(to: p(1, 0)); veins.addLine(to: p(0.36 * l, -0.42 * l))
            veins.move(to: p(1, 0)); veins.addLine(to: p(0.36 * l, 0.42 * l))
            stroke(veins, in: &g, inks.lineInk.color(0.3), 0.7)

        case .flower(let radius, let fill, let budFill, let centre, let anthers, let open):
            if open < 0.3 {
                paint(CornerPaths.dot(0, 0, radius * 0.34), in: &g, inks, fill: inks[keyPath: budFill], lineOpacity: 0.55, lineWidth: 0.8)
                return
            }
            let k = CornerMath.lerp(0.62, 1, (open - 0.3) / 0.7) * radius
            for petal in 0..<5 {
                var turned = g
                turned.rotate(by: .degrees(Double(petal) * 72))
                paint(CornerPaths.oval(0, -0.52 * k, 0.43 * k, 0.476 * k), in: &turned, inks, fill: inks[keyPath: fill], lineOpacity: 0.45, lineWidth: 0.8)
            }
            g.fill(CornerPaths.dot(0, 0, 0.22 * k), with: .color(inks[keyPath: centre].color()))
            if let anthers {
                for anther in 0..<6 {
                    let turn = Double(anther) * Double.pi / 3 + 0.4
                    g.fill(CornerPaths.dot(cos(turn) * 0.36 * k, sin(turn) * 0.36 * k, max(0.7, 0.075 * k)),
                           with: .color(inks[keyPath: anthers].color()))
                }
            }

        case .daffodil(let radius, let open):
            if open < 0.35 { // in bud: one closed, pointed shape
                paint(CornerPaths.leaf(radius * 1.15, 0.2), in: &g, inks, fill: inks.primrose.mixed(with: inks.leafFill, by: 0.35), lineOpacity: 0.6, lineWidth: 0.9)
                return
            }
            let k = CornerMath.lerp(0.7, 1, (open - 0.35) / 0.65) * radius
            for petal in 0..<6 {
                var turned = g
                turned.rotate(by: .radians(Double(petal) * Double.pi / 3 + 0.3))
                paint(CornerPaths.leaf(k, 0.36), in: &turned, inks, fill: inks.primrose, lineOpacity: 0.5, lineWidth: 0.85)
            }
            paint(CornerPaths.dot(0, 0, k * 0.4), in: &g, inks, fill: inks.sun, lineOpacity: 0.55, lineWidth: 0.9)
            stroke(CornerPaths.dot(0, 0, k * 0.2), in: &g, inks.lineInk.color(0.3), 0.7)

        case .catkin(let l):
            stroke(CornerPaths.line([p(0, 0), p(2, 0)]), in: &g, inks.lineInk.color(0.7), 0.9)
            var body = Path()
            body.move(to: p(3.6, -1.9)); body.addLine(to: p(l - 1.6, -1.6))
            body.addQuadCurve(to: p(l - 1.6, 1.6), control: p(l + 0.6, 0))
            body.addLine(to: p(3.6, 1.9)); body.addQuadCurve(to: p(3.6, -1.9), control: p(1.4, 0))
            paint(body, in: &g, inks, fill: inks.catkin, lineOpacity: 0.6, lineWidth: 0.8)
            var ticks = Path()
            var x = 5.4
            while x < l - 1.5 { ticks.move(to: p(x, -1.7)); ticks.addLine(to: p(x + 0.9, 1.7)); x += 2.7 }
            stroke(ticks, in: &g, inks.lineInk.color(0.28), 0.6)

        case .bell(let l, let isOpen):
            let w = l * 0.3
            if !isOpen {
                paint(CornerPaths.leaf(l * 0.55, 0.3), in: &g, inks, fill: inks.bud.mixed(with: inks.leafFill, by: 0.55), lineOpacity: 0.6, lineWidth: 0.9)
                return
            }
            var path = Path()
            path.move(to: p(0, -1))
            path.addCurve(to: p(l, -w * 1.05), control1: p(l * 0.18, -w * 0.95), control2: p(l * 0.7, -w * 0.8))
            path.addQuadCurve(to: p(l + w * 0.55, w * 1.15), control: p(l + w * 0.3, -w * 0.2))
            path.addCurve(to: p(0, 1), control1: p(l * 0.7, w * 0.95), control2: p(l * 0.2, w * 0.95))
            path.closeSubpath()
            paint(path, in: &g, inks, fill: inks.bud, lineOpacity: 0.6, lineWidth: 0.9)
            g.fill(CornerPaths.oval(l * 0.97, w * 0.12, l * 0.13, w * 0.86, turn: -0.25), with: .color(inks.blossom.color(0.7)))
            let spot = inks.anther.color()
            g.fill(CornerPaths.dot(l * 0.95, -w * 0.25, 0.7), with: .color(spot))
            g.fill(CornerPaths.dot(l, w * 0.3, 0.7), with: .color(spot))
            g.fill(CornerPaths.dot(l * 0.93, w * 0.55, 0.6), with: .color(spot))

        case .berry(let radius, let ripe):
            let colour = ripe < 0.5
                ? inks.unripe.mixed(with: inks.berry, by: CornerMath.smooth(ripe / 0.5))
                : inks.berry.mixed(with: inks.bramble, by: CornerMath.smooth((ripe - 0.5) / 0.5))
            stroke(CornerPaths.line([p(-2.5, 0), p(0, 0)]), in: &g, inks.lineInk.color(0.7), 0.9)
            // A blackberry is a cluster of small round drupelets: six
            // in a ring and one in the middle.
            for drupelet in 0..<7 {
                let turn = Double(drupelet) * Double.pi / 3, out = drupelet == 6 ? 0 : radius * 0.58
                paint(CornerPaths.dot(radius + cos(turn) * out * 1.08, sin(turn) * out, radius * 0.42), in: &g, inks,
                      fill: colour, lineOpacity: 0.42, lineWidth: 0.65)
            }

        case .pear(let tall, let ripe):
            let k = tall / 24
            stroke(CornerPaths.line([p(0, 0), p(5, 0)]), in: &g, inks.lineInk.color(0.75), 1.1)
            g.translateBy(x: 3.5, y: 0)
            var path = Path()
            path.move(to: p(k, 0))
            path.addCurve(to: p(11 * k, 5.2 * k), control1: p(k, 3 * k), control2: p(7 * k, 3.4 * k))
            path.addCurve(to: p(24 * k, 0), control1: p(16.5 * k, 8.4 * k), control2: p(24 * k, 8.2 * k))
            path.addCurve(to: p(11 * k, -5.2 * k), control1: p(24 * k, -8.2 * k), control2: p(16.5 * k, -8.4 * k))
            path.addCurve(to: p(k, 0), control1: p(7 * k, -3.4 * k), control2: p(k, -3 * k))
            paint(path, in: &g, inks, fill: inks.unripe.mixed(with: inks.pearFruit, by: ripe))
            stroke(CornerPaths.line([p(23.2 * k, -1.2), p(24.6 * k, 0), p(23.2 * k, 1.2)]), in: &g, inks.lineInk.color(0.5), 0.8)

        case .apple(let r, let ripe):
            stroke(CornerPaths.line([p(0, 0), p(5 + 0.5 * r, 0)]), in: &g, inks.lineInk.color(0.75), 1.1)
            g.translateBy(x: 4.5, y: 0)
            var path = Path()
            path.move(to: p(0.3 * r, 0))
            path.addCurve(to: p(1.45 * r, -0.92 * r), control1: p(-0.15 * r, -0.9 * r), control2: p(0.85 * r, -1.22 * r))
            path.addCurve(to: p(1.45 * r, 0.92 * r), control1: p(2.05 * r, -0.6 * r), control2: p(2.05 * r, 0.6 * r))
            path.addCurve(to: p(0.3 * r, 0), control1: p(0.85 * r, 1.22 * r), control2: p(-0.15 * r, 0.9 * r))
            let colour = ripe < 0.5
                ? inks.unripe.mixed(with: inks.amber, by: ripe * 2)
                : inks.amber.mixed(with: inks.berry, by: (ripe - 0.5) * 2)
            paint(path, in: &g, inks, fill: colour)
            stroke(CornerPaths.line([p(1.9 * r, -1), p(2.02 * r, 0), p(1.9 * r, 1)]), in: &g, inks.lineInk.color(0.45), 0.8)

        case .umbel(let r, let ripe):
            let colour = inks.catkin.mixed(with: inks.ivy, by: ripe)
            var spokes = Path()
            for spoke in 0..<9 {
                let turn = (-112 + Double(spoke) * 28) * CornerMath.degree
                spokes.move(to: .zero); spokes.addLine(to: p(cos(turn) * r, sin(turn) * r))
            }
            stroke(spokes, in: &g, inks.lineInk.color(0.55), 0.7)
            for spoke in 0..<9 {
                let turn = (-112 + Double(spoke) * 28) * CornerMath.degree
                paint(CornerPaths.dot(cos(turn) * r, sin(turn) * r, r * 0.21), in: &g, inks, fill: colour, lineOpacity: 0.55, lineWidth: 0.7)
            }
            paint(CornerPaths.dot(r * 0.45, 0, r * 0.2), in: &g, inks, fill: colour, lineOpacity: 0.55, lineWidth: 0.7)

        case .pearl(let radius):
            paint(CornerPaths.dot(0, 0, radius), in: &g, inks, fill: inks.blossom, lineOpacity: 0.6, lineWidth: 0.8)
            g.fill(CornerPaths.dot(radius * 0.35, 0, 0.5), with: .color(inks.lineInk.color(0.55)))

        case .thorn:
            var path = Path()
            path.move(to: p(-1.1, 0)); path.addLine(to: p(0.5, -2.7)); path.addLine(to: p(1.1, 0))
            g.fill(path, with: .color(inks.lineInk.color(0.7)))

        case .art(let paths, let scale, let pivot, let clip):
            // A hanging part has been turned to point down. The icon's
            // outlines already have down as down, so turn back first.
            if sprigPart.hangs { g.rotate(by: .degrees(-90)) }
            g.scaleBy(x: scale, y: scale)
            g.translateBy(x: -pivot.x, y: -pivot.y)
            if let clip { g.clip(to: Path(clip)) }
            for artPiece in paths {
                if let fill = artPiece.fill { g.fill(artPiece.artOutline, with: .color(inks[keyPath: fill].color())) }
                if artPiece.lineWidth > 0 {
                    g.stroke(artPiece.artOutline, with: .color(inks.lineInk.color(0.82)),
                             style: StrokeStyle(lineWidth: artPiece.lineWidth, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    /// How many grid units one unit of the app icon's drawing is. The
    /// bee and February's snowdrop both use it, so they keep the
    /// icon's proportions.
    static let iconScale = 0.16

    /// The bee of the app icon, seen from above as it is there: a round
    /// front part, an egg-shaped back part with one gold band, and two
    /// wings each side, the short back wing mostly hidden behind the
    /// long front one. It faces along the x axis with the middle of its
    /// front part at 0, 0. The numbers are the icon's own.
    static func bee(in g: inout GraphicsContext, _ inks: CornerInks, isFlying: Bool, time: Double) {
        var b = g
        b.scaleBy(x: iconScale, y: iconScale)
        let body = inks.beeBody.color()
        if !isFlying { // two short legs holding on
            var legs = Path()
            legs.move(to: p(18, -12)); legs.addLine(to: p(36, -13))
            legs.move(to: p(18, 12)); legs.addLine(to: p(36, 13))
            b.stroke(legs, with: .color(body), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        }
        let backPart = CornerPaths.oval(-50, 0, 38, 34.5), frontPart = CornerPaths.dot(0, 0, 24.5)
        if inks.isDark { // a thin cream edge, as the dark icon has
            b.stroke(backPart, with: .color(inks.beeEdge.color()), lineWidth: 7)
            b.stroke(frontPart, with: .color(inks.beeEdge.color()), lineWidth: 7)
        }
        b.fill(backPart, with: .color(body))
        b.fill(frontPart, with: .color(body))
        var band = b
        band.clip(to: CornerPaths.oval(-50, 0, 32.5, 29.5))
        band.fill(Path(CGRect(x: -50, y: -40, width: 28, height: 80)), with: .color(inks.beeGold.color()))
        // In flight the wings are spread and beating. At rest they fold
        // back at the angles the icon has.
        let beat = isFlying ? sin(time * 70) : 0
        let frontOut = isFlying ? 78 + 14 * beat : 39, backOut = isFlying ? 58 + 12 * beat : 21
        for isFrontWing in [false, true] {
            for side in [-1.0, 1.0] {
                var w = b
                w.translateBy(x: isFrontWing ? 0 : -5, y: side * (isFrontWing ? 10 : 9))
                w.rotate(by: .degrees(side * (180 - (isFrontWing ? frontOut : backOut))))
                let wing = isFrontWing ? CornerPaths.wing(60, 11.5) : CornerPaths.wing(49, 9.5)
                w.fill(wing, with: .color(inks.wing.color(isFlying ? 0.8 : 0.96)))
                w.stroke(wing, with: .color(body), style: StrokeStyle(lineWidth: 5.5, lineJoin: .round))
            }
        }
    }
}
