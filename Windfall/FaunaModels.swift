//
//  FaunaModels.swift
//  Windfall
//
//  The animal half of the reference data, matching the Fauna and
//  Plant-Fauna Links sheets.
//
//  Until now WildlifeObservation held species names as free text with
//  nothing to check them against. These models give Eira — and you —
//  something to look them up in, and make "what should I plant for
//  hairy-footed flower bees?" a query rather than a guess.
//

import Foundation
import SwiftData

// MARK: - Fauna

/// A species or group, the animal equivalent of Plant.
@Model
final class Fauna {

    var id: UUID = UUID()

    var commonName: String = ""
    var scientificName: String?
    var acceptedName: String?
    var family: String?
    var genus: String?

    var taxonGroupRaw: String?
    /// The recording-scheme bucket — "Bumblebees", "Hoverflies", "Anecic".
    var recordingGroup: String?

    /// Short, medium or long. What makes flower-shape matching work
    /// rather than being a rule of thumb.
    var tongueLength: String?

    var favouredPlants: String?
    var flightPeriodText: String?
    var conservationStatus: String?
    var notes: String?

    /// The table in the imported data file this came from.
    var sourceSheet: String?
    var lastSyncedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \PlantFaunaLink.fauna)
    var plantLinks: [PlantFaunaLink]? = []

    init(commonName: String = "") {
        self.commonName = commonName
    }

    var taxonGroup: TaxonGroup? {
        get { taxonGroupRaw.flatMap(TaxonGroup.init(rawValue:)) }
        set { taxonGroupRaw = newValue?.rawValue }
    }

    var displayName: String {
        guard let scientificName, !scientificName.isEmpty else { return commonName }
        return "\(commonName) (\(scientificName))"
    }

    var flightMonths: [Int] { MonthParser.months(in: flightPeriodText) }

    /// Whether this is on the wing now — for "what should I be looking for?"
    var isActiveThisMonth: Bool {
        let month = Calendar.current.component(.month, from: .now)
        let months = flightMonths
        return months.isEmpty ? true : months.contains(month)
    }
}

// MARK: - Relationship

/// How an animal uses a plant. Deliberately not a simple "visits" link:
/// nectar, pollen, larval host and nectar-robbing are different outcomes
/// for the plant, and collapsing them loses the distinction that makes
/// mullein worth growing.
enum FaunaRelationship: String, Codable, CaseIterable, Identifiable {
    case nectar
    case pollen
    case nectarAndPollen
    case larvalHost
    case nectarRobbing
    case obligate
    case shelter
    case perchOrMating

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nectar:           return "Nectar"
        case .pollen:           return "Pollen"
        case .nectarAndPollen:  return "Nectar and pollen"
        case .larvalHost:       return "Larval host"
        case .nectarRobbing:    return "Nectar-robbing"
        case .obligate:         return "Obligate dependency"
        case .shelter:          return "Shelter"
        case .perchOrMating:    return "Perch and mating site"
        }
    }

    /// Whether the plant benefits. Nectar-robbing is a taking without
    /// pollination; larval host means being eaten.
    var pollinatesPlant: Bool {
        switch self {
        case .nectar, .pollen, .nectarAndPollen, .obligate: return true
        case .larvalHost, .nectarRobbing, .shelter, .perchOrMating: return false
        }
    }

    static func parse(_ text: String?) -> FaunaRelationship {
        guard let lower = text?.lowercased() else { return .nectar }
        if lower.contains("robbing")            { return .nectarRobbing }
        if lower.contains("larval") || lower.contains("host") { return .larvalHost }
        if lower.contains("obligate")           { return .obligate }
        if lower.contains("perch") || lower.contains("mating") { return .perchOrMating }
        if lower.contains("shelter")            { return .shelter }
        if lower.contains("nectar") && lower.contains("pollen") { return .nectarAndPollen }
        if lower.contains("pollen")             { return .pollen }
        return .nectar
    }
}

@Model
final class PlantFaunaLink {

    var id: UUID = UUID()

    var plant: Plant?
    var fauna: Fauna?

    /// Kept as text too, so a link survives even when the plant or animal
    /// isn't in the database yet — the reference sheet mentions species
    /// you don't grow.
    var plantName: String = ""
    var plantLatinName: String?
    var faunaName: String = ""
    var faunaLatinName: String?

    var relationshipRaw: String = FaunaRelationship.nectar.rawValue
    /// "Bilabiate: Shallow tubular" — floret shape then plain description.
    var flowerShape: String?
    var seasonText: String?
    var notes: String?

    var lastSyncedAt: Date?

    init() {}

    var relationship: FaunaRelationship {
        get { FaunaRelationship(rawValue: relationshipRaw) ?? .nectar }
        set { relationshipRaw = newValue.rawValue }
    }

    /// Just the shape, without the description after the colon.
    var shapeOnly: String? {
        flowerShape?.components(separatedBy: ":").first?
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Flower form reference

/// The shape glossary, so the app can answer "which guilds am I missing?"
@Model
final class FlowerShape {

    var id: UUID = UUID()
    var name: String = ""
    var shapeDescription: String?
    var plainDescription: String?
    var examplePlants: String?
    var insectsServed: String?
    var notes: String?

    init(name: String = "") { self.name = name }
}

// MARK: - Cascades

/// Plant to herbivore to predator. Three columns because the chains are
/// three steps — marjoram needs red ants present before the large blue
/// can use it, and a two-column table cannot say that.
@Model
final class Cascade {

    var id: UUID = UUID()
    var cascadeType: String = ""
    var plantStep: String = ""
    var herbivoreStep: String?
    var predatorStep: String?
    var notes: String?

    init() {}
}
