//
//  WildlifeModels.swift
//  Windfall
//
//  Generalised beyond pollinators. A Survey is any structured, repeatable
//  count following a published protocol — FIT Counts, earthworm pits,
//  whatever comes next. An Observation is a single sighting of anything:
//  insect, bird, mammal, amphibian, fungus.
//
//  CloudKit rules throughout: every property optional or defaulted,
//  no unique constraints, relationships optional with declared inverses.
//

import Foundation
import SwiftData

// MARK: - Taxonomy

/// Broad taxonomic bucket. Deliberately coarse — this is for filtering and
/// UI, not identification.
enum TaxonGroup: String, Codable, CaseIterable, Identifiable {
    case insect, arachnid, mollusc, annelid, otherInvertebrate
    case bird, mammal, amphibian, reptile, fish
    case plant, fungus, lichen, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .insect:            return "Insects"
        case .arachnid:          return "Spiders & harvestmen"
        case .mollusc:           return "Slugs & snails"
        case .annelid:           return "Worms"
        case .otherInvertebrate: return "Other invertebrates"
        case .bird:              return "Birds"
        case .mammal:            return "Mammals"
        case .amphibian:         return "Amphibians"
        case .reptile:           return "Reptiles"
        case .fish:              return "Fish"
        case .plant:             return "Plants"
        case .fungus:            return "Fungi"
        case .lichen:            return "Lichens"
        case .other:             return "Other"
        }
    }
}

/// A recording scheme's own group vocabulary. Each scheme defines its own
/// buckets, so these are stored as strings rather than forced into one enum.
enum RecordingScheme: String, Codable, CaseIterable, Identifiable {
    case fitCount           // UK Pollinator Monitoring Scheme
    case earthwormCount     // #60minworms / Earthworm Society
    case casual             // no protocol
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fitCount:       return "FIT Count"
        case .earthwormCount: return "Earthworm count"
        case .casual:         return "Casual record"
        case .other:          return "Other survey"
        }
    }

    /// The groups this scheme asks you to sort individuals into.
    var groups: [String] {
        switch self {
        case .fitCount:
            return ["Bumblebees", "Honeybees", "Solitary bees", "Wasps",
                    "Hoverflies", "Other flies", "Butterflies & moths",
                    "Beetles", "Small insects", "Other insects"]
        case .earthwormCount:
            // The three ecological groups the protocol is built around.
            return ["Epigeic", "Anecic", "Endogeic", "Juvenile"]
        case .casual, .other:
            return []
        }
    }

    /// Default duration of the counting period, in seconds.
    var defaultDurationSeconds: Int? {
        switch self {
        case .fitCount:       return 600   // ten minutes watching
        case .earthwormCount: return 300   // five minutes hand-sorting
        default:              return nil
        }
    }
}

// MARK: - Supporting enums

enum SkyCondition: String, Codable, CaseIterable, Identifiable {
    case sunny, partlyCloudy, cloudy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sunny:        return "Sunny"
        case .partlyCloudy: return "Partly cloudy"
        case .cloudy:       return "Cloudy"
        }
    }

    /// PoMS minimum temperature for this sky condition.
    var minimumTemperatureC: Double { self == .sunny ? 13 : 15 }
}

enum IDConfidence: String, Codable, CaseIterable, Identifiable {
    case certain, probable, possible, unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .certain:  return "Certain"
        case .probable: return "Probable"
        case .possible: return "Possible"
        case .unknown:  return "Not identified"
        }
    }
}

/// Where an identification came from. Explicit, so a machine guess is never
/// silently promoted to a confirmed record.
enum IDSource: String, Codable, CaseIterable, Identifiable {
    case onDeviceModel, desktopModel, iNaturalistCV, speciesLookup, human

    var id: String { rawValue }
}

// MARK: - Survey

/// A structured count following a protocol.
///
/// FIT Count: one target flower, 50 x 50 cm patch, ten minutes, insects
/// tallied to broad group. 1 April–30 September, dry, 13°C in sun or 15°C
/// in cloud.
///
/// Earthworm count: a 20 x 20 x 20 cm pit, soil hand-sorted for five
/// minutes, worms sorted into three ecological groups. Repeated across
/// several pits — hence `pitNumber`.
///
/// A count of zero is a valid, meaningful result. Absence is data.
@Model
final class Survey {

    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var startedAt: Date = Date.now

    var schemeRaw: String = RecordingScheme.casual.rawValue
    /// Actual duration, stored rather than assumed, so an interrupted
    /// count is honest about itself.
    var durationSeconds: Int?

    // Where
    var bed: Bed?
    var section: BedSection?
    var siteRaw: String?
    var latitude: Double?
    var longitude: Double?
    /// iRecord needs an OS grid reference, not coordinates.
    var gridReference: String?
    var locationName: String?

    // FIT Count specifics
    var targetPlant: Plant?
    var targetPlantName: String?
    var isSchemeTargetFlower: Bool = false
    var floralUnitCount: Int?
    var patchSizeCM: Int?

    // Earthworm count specifics
    var pitNumber: Int?
    var pitDepthCM: Int?
    var soilConditionNotes: String?

    // Conditions
    var temperatureC: Double?
    var skyConditionRaw: String?
    var isDry: Bool = true
    var isWindy: Bool = false

    // Admin
    var recorderName: String?
    var notes: String?
    var submitted: Bool = false
    var submittedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \SurveyTally.survey)
    var tallies: [SurveyTally]? = []

    @Relationship(deleteRule: .nullify, inverse: \WildlifeObservation.survey)
    var observations: [WildlifeObservation]? = []

    init(scheme: RecordingScheme = .casual) {
        self.schemeRaw = scheme.rawValue
        self.durationSeconds = scheme.defaultDurationSeconds
    }

    // MARK: Convenience

    var scheme: RecordingScheme {
        get { RecordingScheme(rawValue: schemeRaw) ?? .casual }
        set {
            schemeRaw = newValue.rawValue
            if durationSeconds == nil { durationSeconds = newValue.defaultDurationSeconds }
        }
    }

    var skyCondition: SkyCondition? {
        get { skyConditionRaw.flatMap(SkyCondition.init(rawValue:)) }
        set { skyConditionRaw = newValue?.rawValue }
    }

    var site: GardenSite? {
        get { siteRaw.flatMap(GardenSite.init(rawValue:)) }
        set { siteRaw = newValue?.rawValue }
    }

    var totalCount: Int {
        (tallies ?? []).reduce(0) { $0 + $1.quantity }
    }

    func total(forGroup group: String) -> Int {
        (tallies ?? []).filter { $0.groupName == group }.reduce(0) { $0 + $1.quantity }
    }

    /// Whether conditions met the scheme's thresholds. Counts that fail are
    /// kept — they're just excluded from submission.
    var meetsProtocolConditions: Bool {
        switch scheme {
        case .fitCount:
            guard isDry, !isWindy,
                  let temp = temperatureC,
                  let sky = skyCondition else { return false }
            return temp >= sky.minimumTemperatureC
        case .earthwormCount:
            return true   // no weather thresholds; timing is seasonal
        case .casual, .other:
            return true
        }
    }

    var isInSeason: Bool {
        let month = Calendar.current.component(.month, from: startedAt)
        switch scheme {
        case .fitCount:       return (4...9).contains(month)
        // Worms are near the surface in spring and autumn; dig in high
        // summer or hard frost and you'll undercount badly.
        case .earthwormCount: return [3, 4, 5, 9, 10, 11].contains(month)
        case .casual, .other: return true
        }
    }

    /// Checked before export, because a single invalid row causes iRecord
    /// to reject the entire file.
    var validationProblems: [String] {
        var problems: [String] = []
        if gridReference?.isEmpty ?? true { problems.append("No grid reference") }
        if recorderName?.isEmpty ?? true  { problems.append("No recorder name") }
        if scheme == .fitCount {
            if targetPlantName?.isEmpty ?? true { problems.append("No target flower recorded") }
            if floralUnitCount == nil           { problems.append("Floral units not counted") }
        }
        if !isInSeason              { problems.append("Outside the recording season") }
        if !meetsProtocolConditions { problems.append("Conditions outside protocol") }
        return problems
    }

    var isReadyForSubmission: Bool { validationProblems.isEmpty }
}

// MARK: - Tally

/// One group's count within a survey. Rows rather than columns, so adding
/// a group later doesn't migrate the schema.
@Model
final class SurveyTally {

    var id: UUID = UUID()
    /// The scheme's own group name — "Hoverflies", "Anecic".
    var groupName: String = ""
    var quantity: Int = 0
    var notes: String?

    var survey: Survey?

    init(groupName: String = "", quantity: Int = 0) {
        self.groupName = groupName
        self.quantity = quantity
    }
}

// MARK: - Wildlife observation

/// A single sighting of anything. Stands alone, or hangs off a survey —
/// PoMS encourages photographing examples of the groups seen during a count.
///
/// Named WildlifeObservation rather than Observation because Apple has a
/// framework called Observation, and sharing the name confuses the compiler.
@Model
final class WildlifeObservation {

    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var observedAt: Date = Date.now

    // Subject
    var commonName: String?
    var scientificName: String?
    /// The accepted name from the species lookup. Kept separate from the
    /// first guess, so the original is never lost.
    var acceptedScientificName: String?
    var family: String?
    var order: String?
    var taxonGroupRaw: String?
    /// The scheme group this rolls up into, derived from family.
    var schemeGroupName: String?

    var quantity: Int?
    var lifeStage: String?
    var sex: String?
    var behaviour: String?

    // Identification provenance
    var provisionalID: String?
    var provisionalConfidenceRaw: String?
    var provisionalSourceRaw: String?
    var confirmedID: String?
    var confirmedAt: Date?

    // Association
    var associatedPlant: Plant?
    /// The plant's name kept as plain text as well as the link above, so a
    /// sighting still reads correctly if the plant later leaves the library.
    /// Same pattern as Survey's targetPlant and targetPlantName.
    var associatedPlantName: String?
    var associatedPlanting: Planting?
    /// What it was doing on the plant — visiting flowers, feeding on
    /// foliage, resting. The interaction, not just co-presence.
    var interaction: String?

    // Place
    var bed: Bed?
    var section: BedSection?
    var latitude: Double?
    var longitude: Double?
    var gridReference: String?
    /// Precision in metres (10, 100, 1000). Coarser precision publishes a
    /// garden record without pinpointing the house.
    var gridPrecisionMetres: Int = 100
    var locationName: String?

    // Media. Each Photo points back here through its `observation` link.
    @Relationship(deleteRule: .cascade, inverse: \Photo.observation)
    var photos: [Photo]? = []

    // Admin
    var recorderName: String?
    var notes: String?
    var submittedToIRecord: Bool = false
    var submittedAt: Date?

    var survey: Survey?

    init() {}

    // MARK: Convenience

    var taxonGroup: TaxonGroup? {
        get { taxonGroupRaw.flatMap(TaxonGroup.init(rawValue:)) }
        set { taxonGroupRaw = newValue?.rawValue }
    }

    var provisionalConfidence: IDConfidence? {
        get { provisionalConfidenceRaw.flatMap(IDConfidence.init(rawValue:)) }
        set { provisionalConfidenceRaw = newValue?.rawValue }
    }

    var provisionalSource: IDSource? {
        get { provisionalSourceRaw.flatMap(IDSource.init(rawValue:)) }
        set { provisionalSourceRaw = newValue?.rawValue }
    }

    /// A machine guess is never a record. Only human confirmation counts.
    var isConfirmed: Bool { !(confirmedID?.isEmpty ?? true) }

    var bestAvailableName: String? {
        confirmedID ?? acceptedScientificName ?? scientificName ?? commonName
    }

    /// iRecord needs species name, grid reference, date, recorder and stage.
    var validationProblems: [String] {
        var problems: [String] = []
        if !isConfirmed                   { problems.append("Identification not confirmed") }
        if gridReference?.isEmpty ?? true { problems.append("No grid reference") }
        if recorderName?.isEmpty ?? true  { problems.append("No recorder name") }
        if lifeStage?.isEmpty ?? true     { problems.append("No life stage (use \"not recorded\")") }
        return problems
    }

    var isReadyForSubmission: Bool { validationProblems.isEmpty }
}

// MARK: - Family to scheme group

/// Turns an identification into a scheme group: you identify Eristalis
/// tenax, GBIF returns Syrphidae, and the app knows that's "Hoverflies".
/// FIT Count tallies stay at group level regardless — species detail rides
/// on the observations attached to the count.
enum TaxonMapper {

    static let familyToFITGroup: [String: String] = [
        "Apidae":         "Bumblebees",       // refined by genus below
        "Andrenidae":     "Solitary bees",
        "Halictidae":     "Solitary bees",
        "Megachilidae":   "Solitary bees",
        "Colletidae":     "Solitary bees",
        "Melittidae":     "Solitary bees",
        "Syrphidae":      "Hoverflies",
        "Vespidae":       "Wasps",
        "Crabronidae":    "Wasps",
        "Sphecidae":      "Wasps",
        "Ichneumonidae":  "Wasps",
        "Formicidae":     "Small insects",
        "Coccinellidae":  "Beetles",
        "Carabidae":      "Beetles",
        "Cantharidae":    "Beetles",
        "Curculionidae":  "Beetles",
        "Chrysomelidae":  "Beetles",
        "Nymphalidae":    "Butterflies & moths",
        "Pieridae":       "Butterflies & moths",
        "Lycaenidae":     "Butterflies & moths",
        "Hesperiidae":    "Butterflies & moths",
        "Papilionidae":   "Butterflies & moths",
        "Noctuidae":      "Butterflies & moths",
        "Geometridae":    "Butterflies & moths",
        "Sphingidae":     "Butterflies & moths",
        "Zygaenidae":     "Butterflies & moths",
        "Calliphoridae":  "Other flies",
        "Muscidae":       "Other flies",
        "Tachinidae":     "Other flies",
        "Bombyliidae":    "Other flies",
        "Empididae":      "Other flies"
    ]

    static let earthwormGenusToGroup: [String: String] = [
        "Lumbricus":     "Anecic",
        "Aporrectodea":  "Endogeic",
        "Allolobophora": "Endogeic",
        "Octolasion":    "Endogeic",
        "Dendrobaena":   "Epigeic",
        "Eisenia":       "Epigeic",
        "Satchellius":   "Epigeic"
    ]

    /// Apidae covers honeybees, bumblebees and some solitary bees, so it
    /// needs the genus to disambiguate.
    static func fitGroup(family: String?, genus: String? = nil) -> String? {
        if let genus {
            switch genus {
            case "Apis":   return "Honeybees"
            case "Bombus": return "Bumblebees"
            case "Nomada", "Anthophora", "Ceratina", "Xylocopa":
                return "Solitary bees"
            default: break
            }
        }
        guard let family else { return nil }
        return familyToFITGroup[family]
    }

    static func earthwormGroup(scientificName: String?) -> String? {
        guard let genus = scientificName?.split(separator: " ").first else { return nil }
        return earthwormGenusToGroup[String(genus)]
    }

    static func taxonGroup(forFamily family: String?, order: String?) -> TaxonGroup? {
        guard let order else { return nil }
        switch order {
        case "Hymenoptera", "Diptera", "Coleoptera", "Lepidoptera",
             "Hemiptera", "Odonata", "Orthoptera", "Dermaptera":
            return .insect
        case "Araneae", "Opiliones":            return .arachnid
        case "Stylommatophora", "Pulmonata":    return .mollusc
        case "Crassiclitellata", "Haplotaxida": return .annelid
        case "Passeriformes", "Columbiformes", "Piciformes",
             "Accipitriformes", "Strigiformes": return .bird
        case "Rodentia", "Eulipotyphla", "Carnivora", "Chiroptera":
            return .mammal
        case "Anura", "Caudata":                return .amphibian
        case "Squamata":                        return .reptile
        default:                                return nil
        }
    }
}
