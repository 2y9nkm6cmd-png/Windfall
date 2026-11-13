//
//  PlantModels.swift
//  Windfall
//
//  Plant is reference data: true wherever it grows, stored once.
//  Planting is an instance: this carrot sowing, in these sections, on this date.
//  Harvest, phenology, and pest/disease events all hang off a Planting.
//
//  Field names are normalised (isUmbelliferous, isDynamicAccumulator);
//  the sheet's original spellings live in the import mapping layer.
//

import Foundation
import SwiftData

enum PlantStatus: String, Codable, CaseIterable, Identifiable {
    case growing          // in the main sheets
    case wanted           // "Plants to buy"
    case previouslyOwned  // "Previously Owned Plants"

    var id: String { rawValue }
}

// MARK: - Plant (reference data)

@Model
final class Plant {

    var id: UUID = UUID()

    // Identity
    var commonName: String = ""
    var latinName: String?
    var variety: String?
    var group: String?              // "Alliums" — drives crop rotation
    var classification: String?     // Annual / Perennial / Biennial
    var typeLabel: String?          // "Plant" / "Seeds"
    var statusRaw: String = PlantStatus.growing.rawValue
    /// Which garden's list or lists this came from.
    var sourceSites: [String] = []

    // Growth patterns — stored as raw sheet text, parsed into months on read
    var floweringMonthsText: String?
    var stemGrowthMonthsText: String?
    var foliageMonthsText: String?
    var fruitingMonthsText: String?
    var plantType: String?
    var foliagePattern: String?
    var habits: String?

    // Growth habits
    var maxHeightM: String?
    var timeToUltimateHeight: String?
    var spreadM: String?
    var rootDepthM: String?
    var rootSpreadM: String?
    var leafSizeCM: String?
    var spacingM: String?
    var leafDescription: String?
    var leafColour: String?
    var flowerSizeCM: String?
    var flowerForm: String?
    var fruitSizeCM: String?
    var fruitType: String?
    var pollinationGroup: String?
    var ploidy: String?
    var layer: String?              // permaculture layer

    // Permaculture roles
    var isPollinator: Bool = false
    var isRepeller: Bool = false
    var isUmbelliferous: Bool = false
    var isNitrogenFixer: Bool = false
    var isDynamicAccumulator: Bool = false
    var isGroundCover: Bool = false

    // Sowing
    var sowIndoorsMonthsText: String?
    var plantOutMonthsText: String?
    var sowOutdoorsMonthsText: String?
    var harvestMonthsText: String?
    var germinationDaysText: String?
    var sowToCropText: String?
    var sowingDepthMM: String?
    var sowingTemperatureC: String?
    var sowingPreference: String?
    var needsPropagator: Bool = false
    var rootstock: String?
    var propagation: String?

    // Constraints
    var sunShade: String?
    var position: String?
    var hardiness: String?
    var soilPH: String?
    var preferredSoilConditions: String?
    var knownPests: String?          // what it *might* get
    var knownDiseases: String?

    // Management
    var maintenancePropagationFrequency: String?
    var pruning: String?
    var pruningGroup: String?
    var culinaryUses: String?
    var medicinalUses: String?
    var toxicityCautions: String?

    // Ecology
    var partnerPlants: String?
    var antagonisticPlants: String?
    var pollinators: String?

    // Description
    var appearance: String?
    var history: String?
    var notes: String?

    // Where the record came from in the imported data file. Nothing is
    // written back to a spreadsheet any more.
    var sourceSheet: String?
    var sourceRow: Int?
    var lastSyncedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \Planting.plant)
    var plantings: [Planting]? = []

    @Relationship(deleteRule: .cascade, inverse: \SeedPacket.plant)
    var seedPackets: [SeedPacket]? = []

    init(commonName: String = "") {
        self.commonName = commonName
    }

    var status: PlantStatus {
        get { PlantStatus(rawValue: statusRaw) ?? .growing }
        set { statusRaw = newValue.rawValue }
    }

    var displayName: String {
        guard let variety, !variety.isEmpty else { return commonName }
        return "\(commonName) — \(variety)"
    }

    /// Derived rather than stored, so it can't drift from the plantings.
    var totalHarvestGrams: Double {
        (plantings ?? []).reduce(0) { $0 + $1.totalHarvestGrams }
    }
}

// MARK: - Planting

enum PlantingStatus: String, Codable, CaseIterable, Identifiable {
    case planned, sown, germinated, plantedOut, growing
    case harvesting, finished, failed

    var id: String { rawValue }
}

enum SowingLocation: String, Codable, CaseIterable, Identifiable {
    case indoors, outdoors, undercover, directSown

    var id: String { rawValue }
}

/// One sowing. Carrots every ten days means one Planting per sowing,
/// all pointing at the same Plant, distinguished by successionRound.
@Model
final class Planting {

    var id: UUID = UUID()
    var createdAt: Date = Date.now

    var plant: Plant?

    /// A planting can span several sections — 3B through 3D.
    var sections: [BedSection]? = []

    /// Which sowing in the run this is. Nil for one-off plantings.
    var successionRound: Int?

    var sowingLocationRaw: String?
    var dateSown: Date?
    var dateGerminated: Date?
    var datePlantedOut: Date?

    var quantitySown: Int?
    var quantitySurvived: Int?

    var statusRaw: String = PlantingStatus.planned.rawValue
    var notes: String?

    // How it was started and, for seed that was saved or crossed, its
    // parents. See SeedTruth.swift. All four may be empty: records made
    // before 13 November 2026 have none of them, and a database made
    // then still opens, because adding a property that may be empty
    // needs no conversion.
    /// "packetSeed", "savedSeed" or "plant".
    var startedFromRaw: String?
    /// The plant the seed came from, in words.
    var seedParentName: String?
    /// The plant whose pollen fertilised the flower, in words. Empty if
    /// it is not known.
    var pollenParentName: String?
    /// True if the cross was made by hand.
    var wasHandCrossed: Bool?
    /// The recorded cross this seed came from, if it was picked from
    /// the list: that cross's identifier, as text. See Crosses.swift.
    var crossKey: String?

    /// Which seed packet this came from, so germination rates can be
    /// fed back into viability.
    var seedPacket: SeedPacket?

    @Relationship(deleteRule: .cascade, inverse: \Harvest.planting)
    var harvests: [Harvest]? = []

    @Relationship(deleteRule: .cascade, inverse: \PhenologyEvent.planting)
    var phenologyEvents: [PhenologyEvent]? = []

    @Relationship(deleteRule: .cascade, inverse: \PestDiseaseEvent.planting)
    var pestDiseaseEvents: [PestDiseaseEvent]? = []

    init() {}

    var status: PlantingStatus {
        get { PlantingStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }

    var sowingLocation: SowingLocation? {
        get { sowingLocationRaw.flatMap(SowingLocation.init(rawValue:)) }
        set { sowingLocationRaw = newValue?.rawValue }
    }

    /// How it was started, if that was recorded.
    var startedFrom: PlantingStart? {
        get { startedFromRaw.flatMap(PlantingStart.init(rawValue:)) }
        set { startedFromRaw = newValue?.rawValue }
    }

    /// "Apple, Pendragon × Egremont Russet (hand cross)", for a sowing
    /// of saved or crossed seed. Nil for anything else.
    var parentage: String? {
        guard startedFrom == .savedSeed else { return nil }
        return SeedTruth.parentage(seedParent: seedParentName, pollenParent: pollenParentName,
                                   byHand: wasHandCrossed ?? false)
    }

    var totalHarvestGrams: Double {
        (harvests ?? []).reduce(0) { $0 + $1.weightInGrams }
    }

    /// The number that tells you whether a seed packet is still worth sowing.
    var germinationRate: Double? {
        guard let sown = quantitySown, sown > 0,
              let survived = quantitySurvived else { return nil }
        return Double(survived) / Double(sown)
    }

    var daysToGermination: Int? {
        guard let sown = dateSown, let germ = dateGerminated else { return nil }
        return Calendar.current.dateComponents([.day], from: sown, to: germ).day
    }

    var bedNames: String {
        let labels = (sections ?? []).sorted { $0.displayOrder < $1.displayOrder }.map(\.fullLabel)
        return labels.joined(separator: ", ")
    }
}

// MARK: - Harvest

enum HarvestUnit: String, Codable, CaseIterable, Identifiable {
    case grams, kilograms, count, litres, bunches

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .grams:     return "g"
        case .kilograms: return "kg"
        case .count:     return "items"
        case .litres:    return "L"
        case .bunches:   return "bunches"
        }
    }
}

/// Where the crop went. The most quietly useful field in the app: it's the
/// difference between "we grew 14 kg of beans" and "we grew 14 kg and
/// composted 4 of them".
enum HarvestDestination: String, Codable, CaseIterable, Identifiable {
    case eaten, stored, frozen, preserved, givenAway, sold, seedSaved, composted, lost

    var id: String { rawValue }
}

/// One picking. Courgettes get harvested thirty times — thirty rows.
@Model
final class Harvest {

    var id: UUID = UUID()
    var date: Date = Date.now
    var quantity: Double = 0
    var unitRaw: String = HarvestUnit.grams.rawValue
    var destinationRaw: String?
    var quality: String?
    var notes: String?

    @Relationship(deleteRule: .cascade, inverse: \Photo.harvest)
    var photos: [Photo]? = []

    var planting: Planting?

    init() {}

    var unit: HarvestUnit {
        get { HarvestUnit(rawValue: unitRaw) ?? .grams }
        set { unitRaw = newValue.rawValue }
    }

    var destination: HarvestDestination? {
        get { destinationRaw.flatMap(HarvestDestination.init(rawValue:)) }
        set { destinationRaw = newValue?.rawValue }
    }

    /// Normalised so totals across mixed units still mean something.
    /// Counts, litres and bunches contribute nothing to a weight total.
    var weightInGrams: Double {
        switch unit {
        case .grams:     return quantity
        case .kilograms: return quantity * 1000
        default:         return 0
        }
    }
}

// MARK: - Phenology

/// First flowering, first fruit, leaf fall. Records what the plant did
/// and when — which, set alongside pollinator counts, shows whether what's
/// flowering matches what's flying.
enum PhenologyStage: String, Codable, CaseIterable, Identifiable {
    case firstLeaf, firstFlower, fullFlower, firstFruit, firstRipeFruit
    case leafFall, dieback, bolted

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .firstLeaf:      return "First leaf"
        case .firstFlower:    return "First flower"
        case .fullFlower:     return "Full flower"
        case .firstFruit:     return "First fruit"
        case .firstRipeFruit: return "First ripe fruit"
        case .leafFall:       return "Leaf fall"
        case .dieback:        return "Dieback"
        case .bolted:         return "Bolted"
        }
    }
}

@Model
final class PhenologyEvent {

    var id: UUID = UUID()
    var date: Date = Date.now
    var stageRaw: String = PhenologyStage.firstFlower.rawValue
    var notes: String?

    @Relationship(deleteRule: .cascade, inverse: \Photo.phenologyEvent)
    var photos: [Photo]? = []

    var planting: Planting?

    init() {}

    var stage: PhenologyStage {
        get { PhenologyStage(rawValue: stageRaw) ?? .firstFlower }
        set { stageRaw = newValue.rawValue }
    }
}

// MARK: - Pest and disease events

enum ProblemKind: String, Codable, CaseIterable, Identifiable {
    case pest, disease, disorder, damage

    var id: String { rawValue }
}

enum ProblemSeverity: String, Codable, CaseIterable, Identifiable {
    case trace, light, moderate, severe, total

    var id: String { rawValue }
}

/// What actually happened, and when — as opposed to the Plant's static
/// list of what it might get.
@Model
final class PestDiseaseEvent {

    var id: UUID = UUID()
    var date: Date = Date.now
    var kindRaw: String = ProblemKind.pest.rawValue
    var name: String = ""
    var scientificName: String?
    var severityRaw: String = ProblemSeverity.light.rawValue
    var treatment: String?
    var outcome: String?
    var resolvedDate: Date?
    var notes: String?

    @Relationship(deleteRule: .cascade, inverse: \Photo.pestDiseaseEvent)
    var photos: [Photo]? = []

    var planting: Planting?

    init() {}

    var kind: ProblemKind {
        get { ProblemKind(rawValue: kindRaw) ?? .pest }
        set { kindRaw = newValue.rawValue }
    }

    var severity: ProblemSeverity {
        get { ProblemSeverity(rawValue: severityRaw) ?? .light }
        set { severityRaw = newValue.rawValue }
    }
}

// MARK: - Seed stock and viability

@Model
final class SeedPacket {

    var id: UUID = UUID()
    var plant: Plant?

    var variety: String?
    var supplier: String?
    var packetYear: Int?
    var useByDate: Date?
    var dateAcquired: Date?
    var quantityRemaining: Int?
    var storageLocation: String?
    var isHomeSaved: Bool = false
    var notes: String?

    // Germination test
    var testDate: Date?
    var testSeedsSown: Int?
    var testSeedsGerminated: Int?

    init() {}

    /// From a deliberate test if there is one, otherwise inferred from
    /// how the actual sowings did.
    var viabilityRate: Double? {
        if let sown = testSeedsSown, sown > 0, let germ = testSeedsGerminated {
            return Double(germ) / Double(sown)
        }
        let rates = (plant?.plantings ?? [])
            .filter { $0.seedPacket?.id == self.id }
            .compactMap(\.germinationRate)
        guard !rates.isEmpty else { return nil }
        return rates.reduce(0, +) / Double(rates.count)
    }

    var isExpired: Bool {
        guard let useByDate else { return false }
        return useByDate < .now
    }

    /// Sow more thickly when viability drops. Nil when untested.
    func suggestedSowingMultiplier() -> Double? {
        guard let rate = viabilityRate, rate > 0 else { return nil }
        return min(3.0, 1.0 / rate)
    }
}
