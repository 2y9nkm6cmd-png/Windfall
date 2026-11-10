//
//  OSGridReference.swift
//  Windfall
//
//  Converts GPS coordinates into an Ordnance Survey grid reference,
//  which is what iRecord and PoMS require — they will not take lat/long.
//
//  Three steps, none of them optional:
//
//  1. GPS gives WGS84 latitude and longitude. The OS grid is built on a
//     different, older model of the Earth's shape (Airy 1830), chosen in
//     the 1830s because it fits Britain well even though it fits the
//     world badly.
//
//  2. So the point is converted to 3D Cartesian coordinates, shifted and
//     rotated onto the Airy datum (a "Helmert transformation"), and turned
//     back into latitude and longitude.
//
//  3. Those are then projected onto the flat National Grid, and the
//     eastings and northings converted into the familiar letter-pair form.
//
//  Accuracy: this uses the standard Helmert parameters, which are good to
//  around five metres. The official transformation, OSTN15, is accurate to
//  centimetres but needs a large lookup file. Five metres is far inside the
//  100 m precision you will publish records at, so this is fine — but it
//  would not be fine for surveying.
//

import Foundation
import CoreLocation

enum OSGridReference {

    // MARK: - Ellipsoids

    /// The shape of the Earth as GPS models it.
    private struct Ellipsoid {
        let a: Double   // semi-major axis, metres
        let b: Double   // semi-minor axis, metres
    }

    private static let wgs84 = Ellipsoid(a: 6_378_137.000, b: 6_356_752.314245)
    private static let airy1830 = Ellipsoid(a: 6_377_563.396, b: 6_356_256.909)

    /// Shift, rotation and scale to move a point from WGS84 onto OSGB36.
    private struct Helmert {
        let tx, ty, tz: Double      // translation, metres
        let rx, ry, rz: Double      // rotation, seconds of arc
        let s: Double               // scale factor, parts per million
    }

    private static let wgs84ToOSGB36 = Helmert(
        tx: -446.448, ty: 125.157, tz: -542.060,
        rx: -0.1502,  ry: -0.2470, rz: -0.8421,
        s: 20.4894
    )

    // MARK: - Public entry point

    /// Turns a coordinate into a grid reference such as "SO 8234 2145".
    ///
    /// - Parameters:
    ///   - coordinate: WGS84 latitude and longitude, as CoreLocation gives it.
    ///   - precisionMetres: 1, 10, 100 or 1000. Coarser precision publishes
    ///     a garden record without pinpointing the house.
    /// - Returns: The reference, or nil if the point is outside the grid.
    static func from(_ coordinate: CLLocationCoordinate2D,
                     precisionMetres: Int = 100) -> String? {

        guard let (easting, northing) = eastingNorthing(from: coordinate) else { return nil }
        return gridReference(easting: easting, northing: northing,
                             precisionMetres: precisionMetres)
    }

    /// The numeric form, for anything that wants raw eastings and northings.
    static func eastingNorthing(from coordinate: CLLocationCoordinate2D)
        -> (easting: Double, northing: Double)? {

        guard coordinate.latitude.isFinite, coordinate.longitude.isFinite else { return nil }

        let osgb = convertDatum(latitude: coordinate.latitude,
                                longitude: coordinate.longitude)
        return project(latitude: osgb.latitude, longitude: osgb.longitude)
    }

    // MARK: - Step 1 and 2: datum conversion

    private static func convertDatum(latitude: Double, longitude: Double)
        -> (latitude: Double, longitude: Double) {

        let φ = latitude.radians
        let λ = longitude.radians

        // Geodetic to Cartesian, on the WGS84 ellipsoid
        let a = wgs84.a, b = wgs84.b
        let sinφ = sin(φ), cosφ = cos(φ)
        let sinλ = sin(λ), cosλ = cos(λ)
        let eSq = (a * a - b * b) / (a * a)
        let ν = a / sqrt(1 - eSq * sinφ * sinφ)

        let x1 = ν * cosφ * cosλ
        let y1 = ν * cosφ * sinλ
        let z1 = (1 - eSq) * ν * sinφ

        // Helmert transformation
        let h = wgs84ToOSGB36
        let s1 = h.s / 1e6 + 1                      // ppm to a plain multiplier
        let rx = (h.rx / 3600).radians              // seconds of arc to radians
        let ry = (h.ry / 3600).radians
        let rz = (h.rz / 3600).radians

        let x2 = h.tx + x1 * s1 - y1 * rz + z1 * ry
        let y2 = h.ty + x1 * rz + y1 * s1 - z1 * rx
        let z2 = h.tz - x1 * ry + y1 * rx + z1 * s1

        // Cartesian back to geodetic, now on Airy 1830
        let a2 = airy1830.a, b2 = airy1830.b
        let precision = 4.0 / a2
        let eSq2 = (a2 * a2 - b2 * b2) / (a2 * a2)
        let p = sqrt(x2 * x2 + y2 * y2)

        var φ2 = atan2(z2, p * (1 - eSq2))
        var φPrev = 2 * Double.pi
        var ν2 = a2

        // Iterative: latitude depends on ν, which depends on latitude.
        var iterations = 0
        while abs(φ2 - φPrev) > precision && iterations < 20 {
            ν2 = a2 / sqrt(1 - eSq2 * sin(φ2) * sin(φ2))
            φPrev = φ2
            φ2 = atan2(z2 + eSq2 * ν2 * sin(φ2), p)
            iterations += 1
        }

        let λ2 = atan2(y2, x2)
        return (φ2.degrees, λ2.degrees)
    }

    // MARK: - Step 3: projection onto the National Grid

    private static func project(latitude: Double, longitude: Double)
        -> (easting: Double, northing: Double) {

        let φ = latitude.radians
        let λ = longitude.radians

        let a = airy1830.a, b = airy1830.b
        let F0 = 0.9996012717                 // central meridian scale factor
        let φ0 = 49.0.radians                 // true origin: 49°N, 2°W
        let λ0 = (-2.0).radians
        let N0 = -100_000.0                   // northing of true origin
        let E0 = 400_000.0                    // easting of true origin

        let eSq = (a * a - b * b) / (a * a)
        let n = (a - b) / (a + b)
        let n2 = n * n, n3 = n * n * n

        let cosφ = cos(φ), sinφ = sin(φ)
        let ν = a * F0 / sqrt(1 - eSq * sinφ * sinφ)
        let ρ = a * F0 * (1 - eSq) / pow(1 - eSq * sinφ * sinφ, 1.5)
        let η2 = ν / ρ - 1

        let Ma = (1 + n + 1.25 * n2 + 1.25 * n3) * (φ - φ0)
        let Mb = (3 * n + 3 * n2 + 2.625 * n3) * sin(φ - φ0) * cos(φ + φ0)
        let Mc = (1.875 * n2 + 1.875 * n3) * sin(2 * (φ - φ0)) * cos(2 * (φ + φ0))
        let Md = (35.0 / 24.0) * n3 * sin(3 * (φ - φ0)) * cos(3 * (φ + φ0))
        let M = b * F0 * (Ma - Mb + Mc - Md)

        let cos3φ = cosφ * cosφ * cosφ
        let cos5φ = cos3φ * cosφ * cosφ
        let tan2φ = tan(φ) * tan(φ)
        let tan4φ = tan2φ * tan2φ

        let I = M + N0
        let II = (ν / 2) * sinφ * cosφ
        let III = (ν / 24) * sinφ * cos3φ * (5 - tan2φ + 9 * η2)
        let IIIA = (ν / 720) * sinφ * cos5φ * (61 - 58 * tan2φ + tan4φ)
        let IV = ν * cosφ
        let V = (ν / 6) * cos3φ * (ν / ρ - tan2φ)
        let VI = (ν / 120) * cos5φ * (5 - 18 * tan2φ + tan4φ + 14 * η2 - 58 * tan2φ * η2)

        let Δλ = λ - λ0
        let Δλ2 = Δλ * Δλ
        let Δλ3 = Δλ2 * Δλ
        let Δλ4 = Δλ3 * Δλ
        let Δλ5 = Δλ4 * Δλ
        let Δλ6 = Δλ5 * Δλ

        let northing = I + II * Δλ2 + III * Δλ4 + IIIA * Δλ6
        let easting = E0 + IV * Δλ + V * Δλ3 + VI * Δλ5

        return (easting, northing)
    }

    // MARK: - Grid letters

    /// The National Grid is divided into 100 km squares, each with a
    /// two-letter code. 'I' is skipped, which is why the maths below
    /// nudges past it.
    static func gridReference(easting: Double, northing: Double,
                              precisionMetres: Int = 100) -> String? {

        guard easting >= 0, northing >= 0,
              easting < 700_000, northing < 1_300_000 else { return nil }

        let e100k = Int(floor(easting / 100_000))
        let n100k = Int(floor(northing / 100_000))

        var l1 = (19 - n100k) - (19 - n100k) % 5 + (e100k + 10) / 5
        var l2 = (19 - n100k) * 5 % 25 + e100k % 5

        if l1 > 7 { l1 += 1 }   // skip 'I'
        if l2 > 7 { l2 += 1 }

        guard let first = asciiLetter(l1), let second = asciiLetter(l2) else { return nil }

        // Digits: how many depends on the precision asked for.
        let digits: Int
        switch precisionMetres {
        case 1:     digits = 5
        case 10:    digits = 4
        case 100:   digits = 3
        case 1000:  digits = 2
        case 10000: digits = 1
        default:    digits = 3
        }

        let divisor = pow(10.0, Double(5 - digits))
        let e = Int(floor((easting.truncatingRemainder(dividingBy: 100_000)) / divisor))
        let n = Int(floor((northing.truncatingRemainder(dividingBy: 100_000)) / divisor))

        let eStr = String(format: "%0\(digits)d", e)
        let nStr = String(format: "%0\(digits)d", n)

        return "\(first)\(second) \(eStr) \(nStr)"
    }

    private static func asciiLetter(_ index: Int) -> Character? {
        guard index >= 0, index < 26 else { return nil }
        return Character(UnicodeScalar(UInt8(65 + index)))
    }
}

// MARK: - Small helpers

private extension Double {
    var radians: Double { self * .pi / 180 }
    var degrees: Double { self * 180 / .pi }
}
