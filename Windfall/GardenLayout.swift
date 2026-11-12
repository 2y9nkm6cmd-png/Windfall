//
//  GardenLayout.swift
//  Windfall
//
//  Gardens you can add yourself, and the things in and around them.
//
//  Until now there were exactly two gardens, written into the code as
//  `GardenSite`. That was fine for one gardener. It could not hold a
//  third plot, and nobody else could draw their own.
//
//  This file adds two kinds of record:
//
//    Garden         one plot: its size, which way it faces, its slope,
//                   soil and location
//    GardenFeature  anything on the plan that is not a bed: a shed, a
//                   path, a pond, a tree, a neighbour's house
//
//  How beds find their garden: every bed already stores a short piece of
//  text, `siteRaw`, saying which garden it is in ("allotment" or
//  "permaculture"). A Garden's `siteKey` holds that same text. Nothing
//  about existing beds, surveys or frost records has to change, and old
//  backups still restore.
//
//  The screens still use `GardenSite` for now. Moving them over to these
//  records is the next step and needs a build in Xcode.
//

import Foundation
import SwiftData

// MARK: - Choices

/// How steeply the ground falls.
enum SlopeSteepness: String, Codable, CaseIterable, Identifiable {
    case gentle, moderate, steep

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

/// The broad soil types gardeners use.
enum SoilKind: String, Codable, CaseIterable, Identifiable {
    case clay, loam, silt, sand, chalk, peat

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

/// What a feature on the plan is.
enum FeatureKind: String, Codable, CaseIterable, Identifiable {
    case path, shed, greenhouse, compost, water, tree, hedge, fence, building, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .path: return "Path"
        case .shed: return "Shed"
        case .greenhouse: return "Greenhouse"
        case .compost: return "Compost"
        case .water: return "Pond, tap or water butt"
        case .tree: return "Tree or bush"
        case .hedge: return "Hedge"
        case .fence: return "Fence or wall"
        case .building: return "House or building"
        case .other: return "Other"
        }
    }

    /// Trees and ponds are drawn round. Everything else is a rectangle.
    var isRound: Bool { self == .tree || self == .water }

    /// A height to fill in when a new feature is added, in metres. These
    /// are only starting values for the gardener to correct.
    /// ⚠️ CHECK: typical heights chosen by Claude.
    var startingHeight: Double {
        switch self {
        case .path, .water: return 0
        case .compost: return 1
        case .shed, .greenhouse: return 2.2
        case .hedge, .fence: return 1.8
        case .tree: return 4
        case .building: return 6
        case .other: return 0
        }
    }
}

// MARK: - Garden

@Model
final class Garden {

    var id: UUID = UUID()

    /// The text that beds, surveys and frost records store to say which
    /// garden they belong to. Set once and never changed, so renaming a
    /// garden does not orphan its beds.
    var siteKey: String = ""

    /// What you call it. Change it whenever you like.
    var name: String = ""
    var displayOrder: Int = 0

    // Size of the plot, in metres. Across is left to right on the plan,
    // down is top to bottom. Empty until measured.
    var widthMetres: Double?
    var depthMetres: Double?

    /// Which way the top edge of the plan faces, as a compass bearing in
    /// degrees: 0 north, 90 east, 180 south, 270 west. Everything about
    /// sun and shade depends on this.
    var topFacesDegrees: Double = 0

    /// The compass bearing the ground falls towards. Empty means flat.
    var slopeDownDegrees: Double?
    var slopeSteepnessRaw: String?

    var soilRaw: String?

    // Where it is. Latitude decides how high the sun climbs.
    var latitude: Double?
    var longitude: Double?

    var notes: String?
    var createdAt: Date = Date.now
    /// Set rather than deleted when a garden is given up, so its history
    /// survives.
    var retiredAt: Date?

    init(name: String = "", siteKey: String = UUID().uuidString) {
        self.name = name
        self.siteKey = siteKey
    }

    var isActive: Bool { retiredAt == nil }

    var slopeSteepness: SlopeSteepness? {
        get { slopeSteepnessRaw.flatMap(SlopeSteepness.init(rawValue:)) }
        set { slopeSteepnessRaw = newValue?.rawValue }
    }

    var soil: SoilKind? {
        get { soilRaw.flatMap(SoilKind.init(rawValue:)) }
        set { soilRaw = newValue?.rawValue }
    }

    /// "Faces north", for the top of the plan.
    var facingDescription: String {
        "Top of the plan faces \(Compass.name(forBearing: topFacesDegrees))"
    }

    /// "Slopes gently down to the south", or "Flat".
    var slopeDescription: String {
        guard let bearing = slopeDownDegrees else { return "Flat" }
        let how: String
        switch slopeSteepness {
        case .gentle: how = " gently"
        case .moderate: how = " moderately"
        case .steep: how = " steeply"
        case nil: how = ""
        }
        return "Slopes\(how) down to the \(Compass.name(forBearing: bearing))"
    }
}

// MARK: - Feature

@Model
final class GardenFeature {

    var id: UUID = UUID()
    var name: String = ""
    var kindRaw: String = FeatureKind.other.rawValue

    /// Which garden's plan it is drawn on. Matches `Garden.siteKey`.
    var siteRaw: String = GardenSite.allotment.rawValue

    // Position and size in metres, measured from the top-left corner of
    // the plot. A negative position is outside the plot, which is how a
    // neighbour's tree or the house next door is recorded.
    var originX: Double = 0
    var originY: Double = 0
    var lengthMetres: Double = 1
    var widthMetres: Double = 1
    /// Clockwise turn about its first corner, in degrees.
    var rotationDegrees: Double = 0

    /// How tall it is. Zero means it casts no shade.
    var heightMetres: Double = 0
    /// Switch off for things you can see through, such as a fruit cage,
    /// so they are drawn but cast no shadow.
    var blocksLight: Bool = true

    var notes: String?
    var createdAt: Date = Date.now
    /// Set rather than deleted when it is taken down or felled.
    var removedAt: Date?

    init(name: String = "", kind: FeatureKind = .other, siteKey: String = GardenSite.allotment.rawValue) {
        self.name = name
        self.kindRaw = kind.rawValue
        self.siteRaw = siteKey
        self.heightMetres = kind.startingHeight
    }

    var kind: FeatureKind {
        get { FeatureKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var isPresent: Bool { removedAt == nil }

    /// Its outline on the plan.
    var outline: [PlanPoint] {
        kind.isRound
            ? PlanGeometry.ellipse(x: originX, y: originY, length: lengthMetres,
                                   width: widthMetres, rotation: rotationDegrees)
            : PlanGeometry.rectangle(x: originX, y: originY, length: lengthMetres,
                                     width: widthMetres, rotation: rotationDegrees)
    }

    /// The outline with its height, for shade. Nil when it casts none.
    var shadeShape: PlanShape? {
        guard isPresent, blocksLight, heightMetres > 0 else { return nil }
        return PlanShape(corners: outline, height: heightMetres)
    }

    /// True when all of it lies beyond the edge of the plot. Unknown plot
    /// size counts as inside.
    func isOutside(_ garden: Garden) -> Bool {
        guard let width = garden.widthMetres, let depth = garden.depthMetres else {
            return outline.allSatisfy { $0.x < 0 || $0.y < 0 }
        }
        return outline.allSatisfy { $0.x < 0 || $0.y < 0 || $0.x > width || $0.y > depth }
    }
}

// MARK: - Beds on the plan

extension Bed {

    /// Lengths used when a bed has not been measured yet. They match the
    /// figures the map has always assumed.
    static let unmeasuredLength = 7.2
    static let unmeasuredWidth = 1.2

    /// The bed's outline on the plan.
    var outline: [PlanPoint] {
        PlanGeometry.rectangle(x: originX, y: originY,
                               length: lengthMetres ?? Bed.unmeasuredLength,
                               width: widthMetres ?? Bed.unmeasuredWidth,
                               rotation: rotationDegrees)
    }

    /// Points spread over the bed, for counting sun.
    var samplePoints: [PlanPoint] {
        PlanGeometry.samplePoints(x: originX, y: originY,
                                  length: lengthMetres ?? Bed.unmeasuredLength,
                                  width: widthMetres ?? Bed.unmeasuredWidth,
                                  rotation: rotationDegrees)
    }

    /// The bed as something that casts shade. Nil for a bed at ground
    /// level, or one with no height recorded.
    var shadeShape: PlanShape? {
        guard isActive, let height = heightMetres, height > 0 else { return nil }
        return PlanShape(corners: outline, height: height)
    }

    /// The compass bearing the bed's long side faces, choosing the side
    /// nearer the midday sun. A bed running east to west has a long side
    /// facing south.
    func longSideFaces(in garden: Garden) -> Double {
        let downThePlan = Compass.normalised(garden.topFacesDegrees + rotationDegrees + 180)
        let upThePlan = Compass.normalised(garden.topFacesDegrees + rotationDegrees)
        // In the northern half of the world the midday sun is in the south.
        let sunward: Double = (garden.latitude ?? 51) >= 0 ? 180 : 0
        return Compass.difference(downThePlan, sunward) <= Compass.difference(upThePlan, sunward)
            ? downThePlan : upThePlan
    }
}

// MARK: - Working things out for a whole garden

enum GardenPlan {

    /// The two gardens the app has always had. Their keys match what
    /// existing beds already store.
    static let startingGardens: [(key: String, name: String)] = [
        (GardenSite.allotment.rawValue, GardenSite.allotment.displayName),
        (GardenSite.permaculture.rawValue, GardenSite.permaculture.displayName)
    ]

    /// Makes sure the two original gardens exist as records. Safe to call
    /// every time the app opens: it only adds what is missing. Returns how
    /// many it added.
    @discardableResult
    static func ensureStartingGardens(in context: ModelContext) -> Int {
        let existing = Set(((try? context.fetch(FetchDescriptor<Garden>())) ?? []).map(\.siteKey))
        var added = 0
        for (index, starting) in startingGardens.enumerated() where !existing.contains(starting.key) {
            let record = Garden(name: starting.name, siteKey: starting.key)
            record.displayOrder = index
            context.insert(record)
            added += 1
        }
        if added > 0 { try? context.save() }
        return added
    }

    /// Everything in one garden that casts shade, leaving out one bed if
    /// asked, so a bed is not counted as shading itself.
    static func shadeShapes(beds: [Bed], features: [GardenFeature],
                            siteKey: String, excluding bed: Bed? = nil) -> [PlanShape] {
        let fromBeds = beds
            .filter { $0.siteRaw == siteKey && $0.id != bed?.id }
            .compactMap(\.shadeShape)
        let fromFeatures = features
            .filter { $0.siteRaw == siteKey }
            .compactMap(\.shadeShape)
        return fromBeds + fromFeatures
    }

    /// Hours of direct sun on a bed for each month, January first. Nil
    /// when the garden has no latitude, because the sun's height cannot be
    /// worked out without one.
    static func monthlySunHours(for bed: Bed, in garden: Garden,
                                beds: [Bed], features: [GardenFeature]) -> [SunHours]? {
        guard let latitude = garden.latitude else { return nil }
        return Shade.monthlySunHours(
            on: bed.samplePoints,
            obstacles: shadeShapes(beds: beds, features: features, siteKey: garden.siteKey, excluding: bed),
            topFaces: garden.topFacesDegrees,
            latitude: latitude)
    }

    /// Hours of direct sun on every bed in a garden on one day of the
    /// year, worked out together. Nil when the garden has no latitude.
    ///
    /// The answers are the same as asking bed by bed, and arrive several
    /// times sooner, because each shadow is worked out once and not once
    /// for every bed. The garden editor uses this each time it redraws.
    static func sunHours(forBedsIn garden: Garden, beds: [Bed], features: [GardenFeature],
                         dayOfYear: Int, stepMinutes: Double = 15) -> [UUID: SunHours]? {
        guard let latitude = garden.latitude else { return nil }
        let sited = beds.filter { $0.siteRaw == garden.siteKey }
        var obstacles: [PlanShape] = []
        var owners: [Int?] = []
        for (index, bed) in sited.enumerated() {
            if let shape = bed.shadeShape {
                obstacles.append(shape)
                owners.append(index)
            }
        }
        for feature in features where feature.siteRaw == garden.siteKey {
            if let shape = feature.shadeShape {
                obstacles.append(shape)
                owners.append(nil)
            }
        }
        let hours = Shade.sunHours(onEach: sited.map(\.samplePoints), obstacles: obstacles, owners: owners,
                                   topFaces: garden.topFacesDegrees, latitude: latitude,
                                   dayOfYear: dayOfYear, stepMinutes: stepMinutes)
        var byBed: [UUID: SunHours] = [:]
        for (index, bed) in sited.enumerated() { byBed[bed.id] = hours[index] }
        return byBed
    }

    /// Pairs of beds in one garden that sit on top of each other. The
    /// editor can warn about these.
    static func overlappingBeds(_ beds: [Bed], siteKey: String) -> [(Bed, Bed)] {
        let sited = beds.filter { $0.siteRaw == siteKey && $0.isActive }
        var pairs: [(Bed, Bed)] = []
        for i in 0..<sited.count {
            for j in (i + 1)..<sited.count where PlanGeometry.overlap(sited[i].outline, sited[j].outline) {
                pairs.append((sited[i], sited[j]))
            }
        }
        return pairs
    }

    /// Gives a starting place to beds that have never been positioned.
    ///
    /// A bed counts as unplaced when it sits at the very corner (0, 0),
    /// which is where every new bed starts. If two or more beds in a
    /// garden are there, they are stacked down the plan with a path
    /// between. Beds that have been placed are left alone. Returns how
    /// many it moved.
    @discardableResult
    static func placeUnpositionedBeds(_ beds: [Bed], siteKey: String) -> Int {
        let unplaced = beds
            .filter { $0.siteRaw == siteKey && $0.isActive && $0.originX == 0 && $0.originY == 0 }
            .sorted { $0.displayOrder < $1.displayOrder }
        guard unplaced.count > 1 else { return 0 }
        let positions = PlanGeometry.stackedPositions(sizes: unplaced.map {
            (length: $0.lengthMetres ?? Bed.unmeasuredLength, width: $0.widthMetres ?? Bed.unmeasuredWidth)
        })
        for (bed, position) in zip(unplaced, positions) {
            bed.originX = position.x
            bed.originY = position.y
        }
        return unplaced.count
    }
}
