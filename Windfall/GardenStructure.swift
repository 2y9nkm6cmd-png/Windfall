//
//  GardenStructure.swift
//  Windfall
//
//  Beds, sections, and the environmental records that apply to them.
//
//  Design note: beds and sections are entities with stable UUIDs and a
//  *separate* display label. If you renumber the beds or turn them through
//  ninety degrees, the label changes and the identity doesn't — so five
//  years of planting history stays attached to the right piece of ground.
//  Never key anything on the string "Bed 3C".
//

import Foundation
import SwiftData

enum GardenSite: String, Codable, CaseIterable, Identifiable {
    case allotment
    case permaculture

    var id: String { rawValue }
    var displayName: String {
        self == .allotment ? "Allotment" : "Permaculture garden"
    }
}

// MARK: - Bed

@Model
final class Bed {

    var id: UUID = UUID()

    /// What you call it now — "Bed 3". Editable without consequence.
    var name: String = ""
    var siteRaw: String = GardenSite.allotment.rawValue

    /// Ordering on the plan, so beds can be renumbered or reordered.
    var displayOrder: Int = 0

    // Geometry, for the map view. Metres, relative to a site origin.
    var originX: Double = 0
    var originY: Double = 0
    var lengthMetres: Double?
    var widthMetres: Double?
    /// Rotation in degrees. Turning the beds the other way is a value change,
    /// not a data migration.
    var rotationDegrees: Double = 0
    /// How far the bed stands above the ground, in metres, including any
    /// tall frame or crop support you want counted as casting shade.
    /// Empty means ground level.
    var heightMetres: Double?

    // Construction
    var isRaised: Bool = false
    var hasHugelkultur: Bool = false
    var soilNotes: String?
    var notes: String?

    var createdAt: Date = Date.now
    /// Set rather than deleted when a bed is dismantled, so history survives.
    var retiredAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \BedSection.bed)
    var sections: [BedSection]? = []

    init(name: String = "", site: GardenSite = .allotment) {
        self.name = name
        self.siteRaw = site.rawValue
    }

    var site: GardenSite {
        get { GardenSite(rawValue: siteRaw) ?? .allotment }
        set { siteRaw = newValue.rawValue }
    }

    var isActive: Bool { retiredAt == nil }

    var orderedSections: [BedSection] {
        (sections ?? []).sorted { $0.displayOrder < $1.displayOrder }
    }

    /// Creates lettered sections A, B, C… of a given length.
    func addSections(count: Int, lengthMetres: Double = 1.2) {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        for i in 0..<count {
            let section = BedSection()
            section.label = i < letters.count ? String(letters[i]) : "S\(i + 1)"
            section.displayOrder = i
            section.lengthMetres = lengthMetres
            section.bed = self
            sections?.append(section)
        }
    }
}

// MARK: - Section

/// A 1.2 m division of a bed. The smallest addressable piece of ground.
@Model
final class BedSection {

    var id: UUID = UUID()
    var label: String = ""
    var displayOrder: Int = 0
    var lengthMetres: Double = 1.2
    var notes: String?

    var bed: Bed?

    @Relationship(inverse: \Planting.sections)
    var plantings: [Planting]? = []

    init() {}

    /// "Bed 3 · C" — for display only. Never stored as a key.
    var fullLabel: String {
        guard let bedName = bed?.name, !bedName.isEmpty else { return label }
        return "\(bedName) · \(label)"
    }
}

// MARK: - Frost and weather

enum FrostKind: String, Codable, CaseIterable, Identifiable {
    case lastSpringFrost
    case firstAutumnFrost
    case other

    var id: String { rawValue }
}

/// A recorded frost. Last spring and first autumn frosts drive every
/// sowing decision, and turn "the beans were poor" into "the beans were
/// poor because of the frost on the 12th".
@Model
final class FrostRecord {

    var id: UUID = UUID()
    var date: Date = Date.now
    var kindRaw: String = FrostKind.other.rawValue
    var siteRaw: String?
    var minimumTemperatureC: Double?
    var damageNotes: String?
    var notes: String?

    init() {}

    var kind: FrostKind {
        get { FrostKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var site: GardenSite? {
        get { siteRaw.flatMap(GardenSite.init(rawValue:)) }
        set { siteRaw = newValue?.rawValue }
    }
}

/// Conditions at a moment. Populated automatically for surveys, and
/// optionally logged daily.
@Model
final class WeatherSnapshot {

    var id: UUID = UUID()
    var recordedAt: Date = Date.now
    var temperatureC: Double?
    var minTemperatureC: Double?
    var maxTemperatureC: Double?
    var rainfallMM: Double?
    var windSpeedMPH: Double?
    var conditionsSummary: String?
    var siteRaw: String?

    init() {}
}
