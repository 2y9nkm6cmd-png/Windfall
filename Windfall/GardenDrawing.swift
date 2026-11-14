//
//  GardenDrawing.swift
//  Windfall
//
//  The sums behind drawing a garden by hand: snapping to the nearest ten
//  centimetres, turning a bed, repeating a bed in a row, and turning
//  "north is over there" into the bearing the plan stores.
//
//  There are no screens in this file. Everything here is a plain
//  function that takes numbers and gives numbers back, so it can be
//  tested without the app running. The screens that use it are
//  GardenDrawView.swift (drag, then type), GardenDrawSteps.swift (one
//  question at a time) and NorthSetters.swift (three ways to say where
//  north is).
//
//  (William, 14 November 2026: "The main issues are the drawing of the
//  garden and orientation of it, that interface was difficult to use.")
//

import Foundation

// MARK: - Anything that sits on a plan

/// A bed, a shed, a tree: anything with a place, a size and a turn.
///
/// A protocol is a list of things a type promises to have. Beds and
/// features are different kinds of record, but both can be dragged about
/// a plan in the same way, so the drawing screen asks only for "something
/// that is PlanPlaceable" and does not care which it has been given.
protocol PlanPlaceable: AnyObject {
    var originX: Double { get set }
    var originY: Double { get set }
    var rotationDegrees: Double { get set }
    /// How long it is, across the plan before any turn. Never empty.
    var planLength: Double { get set }
    /// How wide it is, down the plan before any turn. Never empty.
    var planWidth: Double { get set }
    var planName: String { get }
    var planID: UUID { get }
    /// Trees and ponds are drawn round.
    var planIsRound: Bool { get }
}

extension Bed: PlanPlaceable {
    // A bed's length may be empty in the records ("not measured yet").
    // On the plan it always has one, so the usual stand-in is used.
    var planLength: Double {
        get { lengthMetres ?? Bed.unmeasuredLength }
        set { lengthMetres = newValue }
    }
    var planWidth: Double {
        get { widthMetres ?? Bed.unmeasuredWidth }
        set { widthMetres = newValue }
    }
    var planName: String { name.isEmpty ? "Bed" : name }
    var planID: UUID { id }
    var planIsRound: Bool { false }
}

extension GardenFeature: PlanPlaceable {
    var planLength: Double {
        get { lengthMetres }
        set { lengthMetres = newValue }
    }
    var planWidth: Double {
        get { widthMetres }
        set { widthMetres = newValue }
    }
    var planName: String { name.isEmpty ? kind.displayName : name }
    var planID: UUID { id }
    var planIsRound: Bool { kind.isRound }
}

// MARK: - The sums

enum GardenDrawing {

    /// Nothing on a plan can be made smaller than this, in metres, so a
    /// slip of the finger cannot shrink a bed to nothing.
    static let smallestSize = 0.2

    // MARK: Snapping

    /// The nearest ten centimetres. A dragged bed lands on a tidy number
    /// such as 1.5, not 1.4837.
    static func snapped(_ metres: Double, to step: Double = 0.1) -> Double {
        // The second rounding clears the tiny errors computers make with
        // decimals (0.1 + 0.2 comes out as 0.30000000000000004).
        ((metres / step).rounded() * step * 1000).rounded() / 1000
    }

    /// A turn brought to the nearest five degrees, and pulled on to a
    /// quarter turn when it is within four degrees of one, because most
    /// beds run square to the plot.
    static func snappedTurn(_ degrees: Double) -> Double {
        let turn = Compass.normalised(degrees)
        let quarter = (turn / 90).rounded() * 90
        if abs(turn - quarter) <= 4 { return Compass.normalised(quarter) }
        return Compass.normalised((turn / 5).rounded() * 5)
    }

    /// "8.4 m".
    static func metres(_ value: Double) -> String {
        "\((value * 100).rounded() / 100) m"
    }

    // MARK: Moving, sizing and turning

    /// Splits a move on the plan into how far it goes along a turned
    /// thing's length and how far across its width.
    ///
    /// Dragging the corner of a bed that has been turned should stretch
    /// the bed along its own length, not along the edge of the screen.
    /// `dx` and `dy` are the move in metres, across and down the plan.
    static func alongAcross(dx: Double, dy: Double, rotation: Double) -> (along: Double, across: Double) {
        let turn = rotation * .pi / 180
        return (dx * cos(turn) + dy * sin(turn), -dx * sin(turn) + dy * cos(turn))
    }

    /// The middle of a thing on the plan.
    static func middle(x: Double, y: Double, length: Double, width: Double, rotation: Double) -> PlanPoint {
        let turn = rotation * .pi / 180
        return PlanPoint(x: x + (length / 2) * cos(turn) - (width / 2) * sin(turn),
                         y: y + (length / 2) * sin(turn) + (width / 2) * cos(turn))
    }

    /// A quarter turn that keeps the thing's middle where it is.
    ///
    /// The records turn a bed about its first corner, so adding ninety
    /// degrees alone would swing the bed round that corner and probably
    /// off the plot. This works out where the first corner has to move to
    /// so that the bed turns on the spot.
    static func quarterTurn(x: Double, y: Double, length: Double, width: Double,
                            rotation: Double) -> (x: Double, y: Double, rotation: Double) {
        let centre = middle(x: x, y: y, length: length, width: width, rotation: rotation)
        let turned = Compass.normalised(rotation + 90)
        let turn = turned * .pi / 180
        let newX = centre.x - (length / 2) * cos(turn) + (width / 2) * sin(turn)
        let newY = centre.y - (length / 2) * sin(turn) - (width / 2) * cos(turn)
        return (snapped(newX), snapped(newY), turned)
    }

    /// How much room a thing takes up across and down the plan once it
    /// has been turned: the box drawn round it.
    static func extent(length: Double, width: Double, rotation: Double) -> (across: Double, down: Double) {
        let turn = rotation * .pi / 180
        let c = abs(cos(turn)), s = abs(sin(turn))
        return (length * c + width * s, length * s + width * c)
    }

    // MARK: Repeating

    /// Where each copy goes when a bed is repeated in a row.
    ///
    /// `count` is how many more to make. `gap` is the path between them.
    /// Going down, each copy sits below the last. Going across, to its
    /// right.
    static func repeatPositions(x: Double, y: Double, length: Double, width: Double, rotation: Double,
                                count: Int, gap: Double, goingDown: Bool) -> [PlanPoint] {
        guard count > 0 else { return [] }
        let box = extent(length: length, width: width, rotation: rotation)
        return (1...count).map { copy in
            goingDown
                ? PlanPoint(x: x, y: snapped(y + Double(copy) * (box.down + gap)))
                : PlanPoint(x: snapped(x + Double(copy) * (box.across + gap)), y: y)
        }
    }

    /// Names for new beds, carrying on from the highest number in use:
    /// after "Bed 4" come "Bed 5" and "Bed 6".
    static func nextBedNames(existing: [String], count: Int) -> [String] {
        guard count > 0 else { return [] }
        let numbers = existing.compactMap { name in name.split(separator: " ").last.flatMap { Int($0) } }
        let highest = numbers.max() ?? existing.count
        return (1...count).map { "Bed \(highest + $0)" }
    }

    /// A clear place for something new: just inside the left edge, below
    /// everything already drawn.
    static func freeSpot(below outlines: [[PlanPoint]], gap: Double = 0.6) -> PlanPoint {
        guard let lowest = outlines.flatMap({ $0 }).map(\.y).max() else { return PlanPoint(x: 0.5, y: 0.5) }
        return PlanPoint(x: 0.5, y: snapped(lowest + gap))
    }

    // MARK: North

    /// The angle of a touch, measured clockwise from straight up.
    /// `dx` and `dy` are how far the touch is from the middle of the
    /// ring, across and down the screen.
    static func angle(dx: Double, dy: Double) -> Double {
        Compass.normalised(atan2(dx, -dy) * 180 / .pi)
    }

    /// The bearing the top of the plan faces, given where north has been
    /// put round the ring.
    ///
    /// If north is a quarter turn to the left of straight up (270), then
    /// straight up is a quarter turn to the right of north: east (90).
    static func topFaces(whenNorthIsAt angle: Double) -> Double {
        Compass.normalised(-angle)
    }

    /// The other way round: where to draw north on the ring.
    static func northAngle(whenTopFaces bearing: Double) -> Double {
        Compass.normalised(-bearing)
    }

    /// "The top of your plan faces north-east".
    static func facingWords(_ bearing: Double) -> String {
        "The top of your plan faces \(Compass.name(forBearing: bearing))"
    }

    // MARK: On a map

    /// Turns a step on the plan into metres east and metres north.
    ///
    /// `planX` and `planY` are metres across and down the plan from any
    /// starting point. `topFaces` is the bearing the top of the plan
    /// faces.
    static func worldOffset(planX: Double, planY: Double, topFaces: Double) -> (east: Double, north: Double) {
        let turn = topFaces * .pi / 180
        return (planX * cos(turn) - planY * sin(turn), -planX * sin(turn) - planY * cos(turn))
    }

    /// A place a number of metres east and north of another, as latitude
    /// and longitude. Good to well under a metre across a garden.
    static func coordinate(latitude: Double, longitude: Double,
                           east: Double, north: Double) -> (latitude: Double, longitude: Double) {
        // One degree of latitude is about 111.32 km everywhere. A degree
        // of longitude shrinks towards the poles by the cosine of the
        // latitude.
        let metresPerDegree = 111_320.0
        let shrink = max(cos(latitude * .pi / 180), 0.01)
        return (latitude + north / metresPerDegree, longitude + east / (metresPerDegree * shrink))
    }

    /// The four corners of the plot on a map, in the order top-left,
    /// top-right, bottom-right, bottom-left. `latitude` and `longitude`
    /// are where the middle of the plot is.
    static func plotCorners(latitude: Double, longitude: Double, width: Double, depth: Double,
                            topFaces: Double) -> [(latitude: Double, longitude: Double)] {
        let corners = [(-width / 2, -depth / 2), (width / 2, -depth / 2), (width / 2, depth / 2), (-width / 2, depth / 2)]
        return corners.map { corner in
            let step = worldOffset(planX: corner.0, planY: corner.1, topFaces: topFaces)
            return coordinate(latitude: latitude, longitude: longitude, east: step.east, north: step.north)
        }
    }
}
