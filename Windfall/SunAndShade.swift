//
//  SunAndShade.swift
//  Windfall
//
//  Where the sun is, and where shadows fall on the garden plan.
//
//  This file is plain arithmetic. It knows nothing about the database or
//  the screens, which is what lets it be tested without a Mac.
//
//  Three parts:
//    1. Sun        where the sun is in the sky at a given place and time
//    2. PlanGeometry   shapes on the plan: corners, overlaps, shadows
//    3. Shade      hours of direct sun on a piece of ground
//
//  What it leaves out, on purpose:
//    - The slope of the ground. Everything is treated as flat.
//    - Hills, and anything not drawn on the plan.
//    - Partial shade. A tree in leaf and a bare tree cast the same shadow.
//    - The bending of light near the horizon, which adds a few minutes of
//      daylight at each end of the day.
//
//  So the answers are a good guide for placing plants, not a survey.
//
//  ⚠️ CHECK: written by Claude from standard solar geometry. The tests
//  compare it with known values (midday sun height, day length, sunrise
//  direction), not with measurements in the garden.
//

import Foundation

// MARK: - The sun

/// Where the sun is in the sky.
struct SunPosition: Equatable {
    /// Height above the horizon in degrees. Below zero means night.
    var altitude: Double
    /// Compass bearing in degrees: 0 north, 90 east, 180 south, 270 west.
    var azimuth: Double
}

enum Sun {

    /// How far north or south of the equator the sun is overhead on a
    /// given day, in degrees. About +23.4 at midsummer, -23.4 at midwinter
    /// and 0 at the equinoxes in March and September.
    ///
    /// This is Cooper's formula, accurate to within about a degree.
    /// `dayOfYear` is 1 for 1 January.
    static func declination(dayOfYear: Int) -> Double {
        23.45 * sin(radians(360.0 / 365.0 * Double(284 + dayOfYear)))
    }

    /// The sun's position at a latitude, on a day, at a time by the sun.
    ///
    /// `solarHour` is time by the sun, where 12 is the moment the sun is
    /// highest. It differs from clock time by up to about half an hour in
    /// Britain, more in summer because of British Summer Time. Use
    /// `solarHour(utcHour:longitude:dayOfYear:)` to convert.
    static func position(latitude: Double, dayOfYear: Int, solarHour: Double) -> SunPosition {
        let phi = radians(latitude)
        let delta = radians(declination(dayOfYear: dayOfYear))
        // The hour angle: 15 degrees for each hour before or after midday,
        // because the earth turns 360 degrees in 24 hours.
        let hourAngle = radians(15 * (solarHour - 12))

        let sinAltitude = sin(phi) * sin(delta) + cos(phi) * cos(delta) * cos(hourAngle)
        let altitude = degrees(asin(max(-1, min(1, sinAltitude))))

        // atan2 gives the bearing measured from due south, positive towards
        // the west. Adding 180 turns it into an ordinary compass bearing.
        let fromSouth = atan2(sin(hourAngle), cos(hourAngle) * sin(phi) - tan(delta) * cos(phi))
        let azimuth = Compass.normalised(degrees(fromSouth) + 180)

        return SunPosition(altitude: altitude, azimuth: azimuth)
    }

    /// How high the sun is at midday by the sun.
    static func noonAltitude(latitude: Double, dayOfYear: Int) -> Double {
        position(latitude: latitude, dayOfYear: dayOfYear, solarHour: 12).altitude
    }

    /// Hours between sunrise and sunset. 0 in polar night, 24 in the
    /// midnight sun.
    static func dayLength(latitude: Double, dayOfYear: Int) -> Double {
        let x = -tan(radians(latitude)) * tan(radians(declination(dayOfYear: dayOfYear)))
        if x >= 1 { return 0 }
        if x <= -1 { return 24 }
        return 2 * degrees(acos(x)) / 15
    }

    /// Sunrise and sunset as hours by the sun. Midday is always 12, so
    /// they sit the same distance either side of it.
    static func sunriseAndSunset(latitude: Double, dayOfYear: Int) -> (sunrise: Double, sunset: Double) {
        let half = dayLength(latitude: latitude, dayOfYear: dayOfYear) / 2
        return (12 - half, 12 + half)
    }

    /// How many minutes a sundial runs ahead of a clock on a given day.
    /// It swings between about -14 in February and +16 in early November,
    /// because the earth's orbit is not a perfect circle and its axis is
    /// tilted. This is called the equation of time.
    static func equationOfTimeMinutes(dayOfYear: Int) -> Double {
        let b = radians(360.0 / 364.0 * Double(dayOfYear - 81))
        return 9.87 * sin(2 * b) - 7.53 * cos(b) - 1.5 * sin(b)
    }

    /// Turns clock time into time by the sun.
    ///
    /// `utcHour` is the time in Greenwich Mean Time as a decimal, so 13.5
    /// is half past one. `longitude` is degrees east, so Bristol is about
    /// -2.6. Each degree west makes the sun four minutes later.
    static func solarHour(utcHour: Double, longitude: Double, dayOfYear: Int) -> Double {
        utcHour + longitude / 15 + equationOfTimeMinutes(dayOfYear: dayOfYear) / 60
    }

    /// The same, from a date. The date's own time zone does not matter,
    /// because the sums are done in Greenwich Mean Time.
    static func position(latitude: Double, longitude: Double, at date: Date) -> SunPosition {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        let utcHour = Double(parts.hour ?? 12) + Double(parts.minute ?? 0) / 60 + Double(parts.second ?? 0) / 3600
        return position(latitude: latitude, dayOfYear: day,
                        solarHour: solarHour(utcHour: utcHour, longitude: longitude, dayOfYear: day))
    }

    /// The middle day of each month, counted from 1 January. Used to give
    /// one typical figure for each month.
    static let midMonthDays = [15, 46, 74, 105, 135, 166, 196, 227, 258, 288, 319, 349]

    static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
}

// MARK: - Compass bearings

enum Compass {

    static let pointNames = ["north", "north-east", "east", "south-east",
                             "south", "south-west", "west", "north-west"]

    /// Brings any number of degrees into the range 0 up to 360.
    static func normalised(_ degrees: Double) -> Double {
        let remainder = degrees.truncatingRemainder(dividingBy: 360)
        return remainder < 0 ? remainder + 360 : remainder
    }

    /// The nearest of the eight compass points, in words.
    static func name(forBearing degrees: Double) -> String {
        pointNames[Int((normalised(degrees) / 45).rounded()) % 8]
    }

    /// The smallest angle between two bearings, from 0 to 180.
    static func difference(_ a: Double, _ b: Double) -> Double {
        let d = abs(normalised(a) - normalised(b))
        return d > 180 ? 360 - d : d
    }
}

// MARK: - Shapes on the plan

/// A point on the garden plan, in metres. `x` runs across from the left
/// edge and `y` runs down from the top edge, the way a screen is drawn.
/// A negative number is outside the plot, beyond the left or top edge.
struct PlanPoint: Equatable {
    var x: Double
    var y: Double
}

/// Something with a flat outline and a height: a bed, a shed, a tree.
struct PlanShape {
    /// The outline's corners in order round the shape.
    var corners: [PlanPoint]
    /// How tall it is, in metres. Zero casts no shade.
    var height: Double
}

enum PlanGeometry {

    /// The four corners of a rectangle on the plan.
    ///
    /// `x` and `y` place its first corner. `length` runs across the plan
    /// and `width` runs down it. `rotation` turns it clockwise about that
    /// first corner, in degrees, so the corner you measured stays put.
    static func rectangle(x: Double, y: Double, length: Double, width: Double,
                          rotation: Double = 0) -> [PlanPoint] {
        [(0.0, 0.0), (length, 0.0), (length, width), (0.0, width)].map {
            turned(dx: $0.0, dy: $0.1, about: PlanPoint(x: x, y: y), by: rotation)
        }
    }

    /// An oval that fills the same box, for trees and ponds. It is drawn
    /// as a many-sided shape so the same sums work for it.
    static func ellipse(x: Double, y: Double, length: Double, width: Double,
                        rotation: Double = 0, sides: Int = 16) -> [PlanPoint] {
        (0..<max(sides, 3)).map { i in
            let angle = 2 * Double.pi * Double(i) / Double(max(sides, 3))
            return turned(dx: length / 2 + cos(angle) * length / 2,
                          dy: width / 2 + sin(angle) * width / 2,
                          about: PlanPoint(x: x, y: y), by: rotation)
        }
    }

    private static func turned(dx: Double, dy: Double, about origin: PlanPoint, by rotation: Double) -> PlanPoint {
        let r = Sun.radians(rotation)
        return PlanPoint(x: origin.x + dx * cos(r) - dy * sin(r),
                         y: origin.y + dx * sin(r) + dy * cos(r))
    }

    /// One metre in a compass direction, as a step on the plan.
    ///
    /// `topFaces` is the compass bearing that the top edge of the plan
    /// faces. With north at the top, north is straight up the plan, which
    /// is (0, -1) because `y` runs downwards.
    static func step(towardsBearing bearing: Double, topFaces: Double) -> PlanPoint {
        let angle = Sun.radians(bearing - topFaces)
        return PlanPoint(x: sin(angle), y: -cos(angle))
    }

    /// The outline of the shadow a shape casts on flat ground, including
    /// the ground under the shape itself. Nil when the sun is down or the
    /// shape has no height.
    ///
    /// The shadow of a flat-topped block is the block's outline, a copy of
    /// that outline slid away from the sun, and everything between the two.
    /// Wrapping a band round both outlines gives exactly that.
    static func shadow(of shape: PlanShape, sun: SunPosition, topFaces: Double) -> [PlanPoint]? {
        guard shape.height > 0, sun.altitude > 0.5, shape.corners.count >= 3 else { return nil }
        // A low sun makes a long shadow: height divided by the tangent of
        // the sun's height. At 45 degrees the shadow is as long as the
        // object is tall.
        let length = shape.height / tan(Sun.radians(sun.altitude))
        // The shadow points directly away from the sun.
        let away = step(towardsBearing: sun.azimuth + 180, topFaces: topFaces)
        let tips = shape.corners.map { PlanPoint(x: $0.x + away.x * length, y: $0.y + away.y * length) }
        return hull(of: shape.corners + tips)
    }

    /// The tightest outline that wraps a set of points, like a rubber band
    /// stretched round nails. This is Andrew's method.
    static func hull(of points: [PlanPoint]) -> [PlanPoint] {
        let sorted = points.sorted { $0.x != $1.x ? $0.x < $1.x : $0.y < $1.y }
        guard sorted.count > 2 else { return sorted }
        // Which way three points turn: positive one way, negative the other.
        func cross(_ c0: PlanPoint, _ c1: PlanPoint, _ c2: PlanPoint) -> Double {
            (c1.x - c0.x) * (c2.y - c0.y) - (c1.y - c0.y) * (c2.x - c0.x)
        }
        var lower: [PlanPoint] = []
        for p in sorted {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 { lower.removeLast() }
            lower.append(p)
        }
        var upper: [PlanPoint] = []
        for p in sorted.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 { upper.removeLast() }
            upper.append(p)
        }
        return Array(lower.dropLast()) + Array(upper.dropLast())
    }

    /// True when a point is inside an outline. It counts how many edges a
    /// line drawn from the point to the right would cross: an odd number
    /// means inside.
    static func contains(_ spot: PlanPoint, in outline: [PlanPoint]) -> Bool {
        guard outline.count >= 3 else { return false }
        var inside = false
        var j = outline.count - 1
        for i in 0..<outline.count {
            let start = outline[i], end = outline[j]
            if (start.y > spot.y) != (end.y > spot.y) {
                let crossingX = (end.x - start.x) * (spot.y - start.y) / (end.y - start.y) + start.x
                if spot.x < crossingX { inside.toggle() }
            }
            j = i
        }
        return inside
    }

    /// True when two outlines with no dents overlap. Touching edges do not
    /// count, so beds can sit side by side.
    ///
    /// The test: if you can find a straight line with one shape wholly on
    /// each side, they do not overlap. It is enough to try the directions
    /// square to each edge.
    static func overlap(_ a: [PlanPoint], _ b: [PlanPoint]) -> Bool {
        guard a.count >= 3, b.count >= 3 else { return false }
        for shape in [a, b] {
            for i in 0..<shape.count {
                let p = shape[i], q = shape[(i + 1) % shape.count]
                let axis = PlanPoint(x: -(q.y - p.y), y: q.x - p.x)
                func spread(_ points: [PlanPoint]) -> (Double, Double) {
                    let values = points.map { $0.x * axis.x + $0.y * axis.y }
                    return (values.min() ?? 0, values.max() ?? 0)
                }
                let (minA, maxA) = spread(a), (minB, maxB) = spread(b)
                if maxA <= minB + 1e-9 || maxB <= minA + 1e-9 { return false }
            }
        }
        return true
    }

    /// Evenly spread points inside a rectangle, used to sample a bed.
    static func samplePoints(x: Double, y: Double, length: Double, width: Double,
                             rotation: Double = 0, along: Int = 6, across: Int = 2) -> [PlanPoint] {
        var points: [PlanPoint] = []
        for i in 0..<max(along, 1) {
            for j in 0..<max(across, 1) {
                points.append(turned(dx: length * (Double(i) + 0.5) / Double(max(along, 1)),
                                     dy: width * (Double(j) + 0.5) / Double(max(across, 1)),
                                     about: PlanPoint(x: x, y: y), by: rotation))
            }
        }
        return points
    }

    /// Starting positions for beds that have never been placed, stacked
    /// down the plan with a path between them so none sit on top of each
    /// other. The gardener then moves them to their measured places.
    static func stackedPositions(sizes: [(length: Double, width: Double)],
                                 pathWidth: Double = 0.6, margin: Double = 0.5) -> [PlanPoint] {
        var y = margin
        return sizes.map { size in
            defer { y += size.width + pathWidth }
            return PlanPoint(x: margin, y: y)
        }
    }
}

// MARK: - Hours of sun

/// The result of counting sun on a piece of ground for one day.
struct SunHours: Equatable {
    /// Hours the sun is up and high enough to count.
    var possible: Double
    /// Hours of that in which the ground is not in shadow, averaged over
    /// the whole piece of ground.
    var direct: Double

    /// The usual gardening words for this much sun.
    /// ⚠️ CHECK: the six-hour and three-hour lines are the common rule of
    /// thumb for "full sun" and "part shade", written by Claude.
    var label: String {
        if direct >= 6 { return "full sun" }
        if direct >= 3 { return "part shade" }
        return "shade"
    }
}

enum Shade {

    /// Counts the hours of direct sun on a set of points for one day.
    ///
    /// It steps through the day, a few minutes at a time. At each step it
    /// works out where the sun is, draws every obstacle's shadow and sees
    /// what fraction of the points are outside all of them.
    ///
    /// - Parameters:
    ///   - points: places on the ground to test, from `samplePoints`.
    ///   - obstacles: everything tall enough to cast shade.
    ///   - topFaces: the compass bearing the top of the plan faces.
    ///   - minimumAltitude: sun lower than this is not counted. Very low
    ///     sun is weak and usually blocked by things beyond the plan.
    static func sunHours(on points: [PlanPoint], obstacles: [PlanShape], topFaces: Double,
                         latitude: Double, dayOfYear: Int,
                         stepMinutes: Double = 10, minimumAltitude: Double = 5) -> SunHours {
        guard !points.isEmpty, stepMinutes > 0 else { return SunHours(possible: 0, direct: 0) }
        let (sunrise, sunset) = Sun.sunriseAndSunset(latitude: latitude, dayOfYear: dayOfYear)
        let step = stepMinutes / 60
        var possible = 0.0, direct = 0.0

        // Each step is judged at its middle moment.
        var hour = sunrise + step / 2
        while hour < sunset {
            let sun = Sun.position(latitude: latitude, dayOfYear: dayOfYear, solarHour: hour)
            if sun.altitude >= minimumAltitude {
                let shadows = obstacles.compactMap { PlanGeometry.shadow(of: $0, sun: sun, topFaces: topFaces) }
                let lit = points.filter { spot in
                    !shadows.contains { PlanGeometry.contains(spot, in: $0) }
                }.count
                possible += step
                direct += step * Double(lit) / Double(points.count)
            }
            hour += step
        }
        return SunHours(possible: possible, direct: direct)
    }

    /// One figure for each month, January first, taken at mid-month.
    static func monthlySunHours(on points: [PlanPoint], obstacles: [PlanShape], topFaces: Double,
                                latitude: Double) -> [SunHours] {
        Sun.midMonthDays.map {
            sunHours(on: points, obstacles: obstacles, topFaces: topFaces,
                     latitude: latitude, dayOfYear: $0, stepMinutes: 15)
        }
    }
}
