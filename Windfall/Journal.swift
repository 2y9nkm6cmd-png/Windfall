//
//  Journal.swift
//  Windfall
//
//  Diary entries, photos, and the timeline that unifies every dated record.
//
//  The timeline is deliberately not a diary view. Phenology, harvests,
//  pest events, plantings and surveys are all dated, photographed things
//  that happened in the garden. Showing only diary entries would split the
//  history in two.
//

import Foundation
import SwiftData

// MARK: - Photo

/// One image, shared by every record type.
///
/// `.externalStorage` tells SwiftData to write the image data as a file
/// alongside the database rather than inside it — the store stays small and
/// fast, and CloudKit still syncs the file. The alternative, storing a
/// Photos-library identifier, is cheaper but the picture disappears if the
/// camera roll is tidied, and it doesn't sync.
@Model
final class Photo {

    var id: UUID = UUID()
    var capturedAt: Date = Date.now
    var addedAt: Date = Date.now

    @Attribute(.externalStorage)
    var imageData: Data?

    /// Small version for scrolling. Loading full images into a timeline
    /// is the fastest way to make a list stutter.
    @Attribute(.externalStorage)
    var thumbnailData: Data?

    var caption: String?

    // Read from EXIF where present — the same fields the records need.
    var latitude: Double?
    var longitude: Double?

    /// Kept so a photo can be traced back to the original in Photos,
    /// even though the data is stored independently.
    var sourceLocalIdentifier: String?

    // Optional owners. A photo belongs to at most one of these.
    var diaryEntry: DiaryEntry?
    var phenologyEvent: PhenologyEvent?
    var pestDiseaseEvent: PestDiseaseEvent?
    var observation: WildlifeObservation?
    var harvest: Harvest?

    init() {}
}

// MARK: - Diary entry

enum DiaryScope: String, Codable, CaseIterable, Identifiable {
    case garden          // the whole place
    case bed             // one bed or section
    case planting        // one sowing
    case plant           // a species generally

    var id: String { rawValue }
}

enum Weather: String, Codable, CaseIterable, Identifiable {
    case sunny, cloudy, overcast, rain, heavyRain, frost, snow, windy, mild

    var id: String { rawValue }

    /// The word as it is shown: "Heavy rain", not "Heavyrain".
    var displayName: String {
        switch self {
        case .sunny:     return "Sunny"
        case .cloudy:    return "Cloudy"
        case .overcast:  return "Overcast"
        case .rain:      return "Rain"
        case .heavyRain: return "Heavy rain"
        case .frost:     return "Frost"
        case .snow:      return "Snow"
        case .windy:     return "Windy"
        case .mild:      return "Mild"
        }
    }

    var symbolName: String {
        switch self {
        case .sunny:     return "sun.max"
        case .cloudy:    return "cloud.sun"
        case .overcast:  return "cloud"
        case .rain:      return "cloud.rain"
        case .heavyRain: return "cloud.heavyrain"
        case .frost:     return "snowflake"
        case .snow:      return "cloud.snow"
        case .windy:     return "wind"
        case .mild:      return "thermometer.medium"
        }
    }
}

/// A written note about the garden, or about one thing in it.
@Model
final class DiaryEntry {

    var id: UUID = UUID()
    var date: Date = Date.now
    var createdAt: Date = Date.now
    var modifiedAt: Date = Date.now

    /// Optional. When blank the timeline falls back to `generatedSummary`,
    /// then to the first line of the body.
    var title: String?
    var body: String = ""

    /// Written by Eira from the body, and marked as machine-written so it
    /// is never mistaken for something you wrote.
    var generatedSummary: String?
    var summaryGeneratedAt: Date?

    var scopeRaw: String = DiaryScope.garden.rawValue
    var weatherRaw: String?
    var temperatureC: Double?

    // What it's about. All optional — a general entry links to nothing.
    var bed: Bed?
    var section: BedSection?
    var planting: Planting?
    var plant: Plant?

    var tags: [String] = []
    var isPinned: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Photo.diaryEntry)
    var photos: [Photo]? = []

    init(body: String = "") {
        self.body = body
    }

    var scope: DiaryScope {
        get { DiaryScope(rawValue: scopeRaw) ?? .garden }
        set { scopeRaw = newValue.rawValue }
    }

    var weather: Weather? {
        get { weatherRaw.flatMap(Weather.init(rawValue:)) }
        set { weatherRaw = newValue?.rawValue }
    }

    /// First non-empty line, trimmed — the last fallback for a heading.
    private var firstLine: String {
        body.split(separator: "\n", omittingEmptySubsequences: true)
            .first.map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? "Untitled entry"
    }

    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        if let generatedSummary, !generatedSummary.isEmpty { return generatedSummary }
        return String(firstLine.prefix(60))
    }

    /// True when the heading came from the model rather than from you.
    var titleIsGenerated: Bool {
        (title?.isEmpty ?? true) && !(generatedSummary?.isEmpty ?? true)
    }
}

// MARK: - Timeline

enum TimelineKind: String, CaseIterable, Identifiable {
    case diary, planting, phenology, harvest, problem, survey, sighting

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .diary:     return "Diary"
        case .planting:  return "Sowings"
        case .phenology: return "Flowering & fruiting"
        case .harvest:   return "Harvests"
        case .problem:   return "Pests & diseases"
        case .survey:    return "Surveys"
        case .sighting:  return "Sightings"
        }
    }

    var symbolName: String {
        switch self {
        case .diary:     return "book.closed"
        case .planting:  return "leaf"
        case .phenology: return "camera.macro"
        case .harvest:   return "basket"
        case .problem:   return "exclamationmark.triangle"
        case .survey:    return "list.clipboard"
        case .sighting:  return "ant"
        }
    }
}

/// Anything that can appear on the timeline.
///
/// SwiftData can't query across a protocol, so the timeline fetches each
/// type and merges in memory. Fine at garden scale — a few thousand rows
/// over many years — and much simpler than one giant table with a type
/// column and mostly-empty fields.
protocol TimelineEntry {
    var timelineDate: Date { get }
    var timelineKind: TimelineKind { get }
    var timelineTitle: String { get }
    var timelineDetail: String? { get }
    var timelinePhotos: [Photo] { get }
}

extension DiaryEntry: TimelineEntry {
    var timelineDate: Date { date }
    var timelineKind: TimelineKind { .diary }
    var timelineTitle: String { displayTitle }
    var timelineDetail: String? { body.isEmpty ? nil : body }
    var timelinePhotos: [Photo] { photos ?? [] }
}

extension Planting: TimelineEntry {
    var timelineDate: Date { dateSown ?? createdAt }
    var timelineKind: TimelineKind { .planting }
    var timelineTitle: String {
        let name = plant?.displayName ?? "Unknown plant"
        // With no sowing date it was not sown that day. It was put on
        // record, as happens when a harvest is added for a tree that was
        // here before the app.
        if dateSown == nil { return "\(name) put on record" }
        // A tree, a tuber or a clove is planted, not sown. And seed that
        // will not come true is seed *of* its parent, not the parent.
        if startedFrom == .plant { return "Planted \(name)" }
        if startedFrom == .savedSeed { return "Sowed seed of \(name)" }
        if let round = successionRound { return "Sowed \(name) — round \(round)" }
        return "Sowed \(name)"
    }
    var timelineDetail: String? {
        var bits: [String] = []
        if !bedNames.isEmpty { bits.append(bedNames) }
        if let n = quantitySown { bits.append(startedFrom == .plant ? "\(n) planted" : "\(n) sown") }
        if let parentage { bits.append(parentage) }
        return bits.isEmpty ? nil : bits.joined(separator: " · ")
    }
    var timelinePhotos: [Photo] { [] }
}

extension PhenologyEvent: TimelineEntry {
    var timelineDate: Date { date }
    var timelineKind: TimelineKind { .phenology }
    var timelineTitle: String {
        let name = planting?.plant?.displayName ?? "Plant"
        return "\(name) — \(stage.displayName.lowercased())"
    }
    var timelineDetail: String? { notes }
    var timelinePhotos: [Photo] { photos ?? [] }
}

extension Harvest: TimelineEntry {
    var timelineDate: Date { date }
    var timelineKind: TimelineKind { .harvest }
    var timelineTitle: String {
        let name = planting?.plant?.displayName ?? "Harvest"
        return "\(name) — \(quantity.formatted()) \(unit.displayName)"
    }
    var timelineDetail: String? {
        [destination?.rawValue, notes].compactMap { $0 }.joined(separator: " · ")
            .isEmpty ? nil : [destination?.rawValue, notes].compactMap { $0 }.joined(separator: " · ")
    }
    var timelinePhotos: [Photo] { photos ?? [] }
}

extension PestDiseaseEvent: TimelineEntry {
    var timelineDate: Date { date }
    var timelineKind: TimelineKind { .problem }
    var timelineTitle: String {
        let host = planting?.plant?.displayName
        return host.map { "\(name) on \($0)" } ?? name
    }
    var timelineDetail: String? {
        [severity.rawValue, treatment].compactMap { $0 }.joined(separator: " · ")
    }
    var timelinePhotos: [Photo] { photos ?? [] }
}

extension Survey: TimelineEntry {
    var timelineDate: Date { startedAt }
    var timelineKind: TimelineKind { .survey }
    var timelineTitle: String {
        switch scheme {
        case .fitCount:
            return "FIT Count on \(targetPlantName ?? "unnamed plant") — \(totalCount) insects"
        case .earthwormCount:
            return "Earthworm count\(pitNumber.map { ", pit \($0)" } ?? "") — \(totalCount) worms"
        default:
            return "\(scheme.displayName) — \(totalCount) recorded"
        }
    }
    var timelineDetail: String? { notes }
    var timelinePhotos: [Photo] { [] }
}

extension WildlifeObservation: TimelineEntry {
    var timelineDate: Date { observedAt }
    var timelineKind: TimelineKind { .sighting }
    var timelineTitle: String { bestAvailableName ?? "Unidentified sighting" }
    var timelineDetail: String? {
        [associatedPlantName.map { "on \($0)" }, interaction, notes]
            .compactMap { $0 }.joined(separator: " · ")
    }
    var timelinePhotos: [Photo] { photos ?? [] }
}

// MARK: - Assembling the timeline

/// A type-erased wrapper, so a mixed list can be held in one array
/// and used in a SwiftUI `ForEach`.
struct TimelineItem: Identifiable {
    let id: UUID
    let date: Date
    let kind: TimelineKind
    let title: String
    let detail: String?
    let photos: [Photo]

    init(_ entry: TimelineEntry, id: UUID) {
        self.id = id
        self.date = entry.timelineDate
        self.kind = entry.timelineKind
        self.title = entry.timelineTitle
        self.detail = entry.timelineDetail
        self.photos = entry.timelinePhotos
    }
}

enum TimelineBuilder {

    /// Merges every source into one list, newest first.
    /// Fetching is left to the view via `@Query`, so this stays testable
    /// and has no opinion about where the data came from.
    static func build(
        diary: [DiaryEntry] = [],
        plantings: [Planting] = [],
        phenology: [PhenologyEvent] = [],
        harvests: [Harvest] = [],
        problems: [PestDiseaseEvent] = [],
        surveys: [Survey] = [],
        sightings: [WildlifeObservation] = [],
        kinds: Set<TimelineKind> = Set(TimelineKind.allCases)
    ) -> [TimelineItem] {

        var items: [TimelineItem] = []

        if kinds.contains(.diary)     { items += diary.map     { TimelineItem($0, id: $0.id) } }
        if kinds.contains(.planting)  { items += plantings.map { TimelineItem($0, id: $0.id) } }
        if kinds.contains(.phenology) { items += phenology.map { TimelineItem($0, id: $0.id) } }
        if kinds.contains(.harvest)   { items += harvests.map  { TimelineItem($0, id: $0.id) } }
        if kinds.contains(.problem)   { items += problems.map  { TimelineItem($0, id: $0.id) } }
        if kinds.contains(.survey)    { items += surveys.map   { TimelineItem($0, id: $0.id) } }
        if kinds.contains(.sighting)  { items += sightings.map { TimelineItem($0, id: $0.id) } }

        return items.sorted { $0.date > $1.date }
    }

    /// Grouped by month, for section headers down the timeline.
    static func groupedByMonth(_ items: [TimelineItem]) -> [(month: Date, items: [TimelineItem])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: items) { item in
            calendar.date(from: calendar.dateComponents([.year, .month], from: item.date)) ?? item.date
        }
        return groups
            .map { (month: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.month > $1.month }
    }
}
