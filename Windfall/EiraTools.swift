//
//  EiraTools.swift
//  Windfall
//
//  What Eira can look things up in.
//
//  Two kinds, deliberately separate:
//
//  1. Local queries against your own data — what's in the beds, what you
//     harvested, what your reference sheets say. These are exact and
//     always available.
//  2. GBIF for taxonomy, which resolves a name to an accepted one. Free,
//     no key, and far more authoritative on species than a web search.
//
//  Every answer carries a source, including an explicit note when
//  something is unsourced model knowledge. Traceability matters more than
//  fluency for a naturalist assistant.
//

import Foundation
import SwiftData

// MARK: - Definitions

struct ToolDefinition {
    let name: String
    let description: String
    /// JSON Schema for the arguments.
    let parameters: [String: Any]

    var asJSON: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": parameters
            ]
        ]
    }
}

enum EiraTools {

    static let lookupSpecies = ToolDefinition(
        name: "lookup_species",
        description: "Resolve a plant or animal name to its accepted scientific name, family and order using GBIF. Use this whenever a species is mentioned, before saying anything else about it.",
        parameters: [
            "type": "object",
            "properties": [
                "name": [
                    "type": "string",
                    "description": "Common or scientific name to look up"
                ]
            ],
            "required": ["name"]
        ]
    )

    static let searchGarden = ToolDefinition(
        name: "search_garden",
        description: "Search the user's own plant database for plants matching a name, group or property. Returns what they actually grow, with sowing times and conditions.",
        parameters: [
            "type": "object",
            "properties": [
                "query": ["type": "string", "description": "Plant name or search term"]
            ],
            "required": ["query"]
        ]
    )

    static let whatsInBed = ToolDefinition(
        name: "whats_growing",
        description: "List what is currently growing, optionally in a named bed. Use for questions about the current state of the garden.",
        parameters: [
            "type": "object",
            "properties": [
                "bed": ["type": "string", "description": "Bed name, or omit for everything"]
            ]
        ]
    )

    static let plantVisitors = ToolDefinition(
        name: "plant_visitors",
        description: "Look up which insects use a given plant, and how — nectar, pollen, larval host or nectar-robbing. Uses the user's own Plant-Fauna reference data.",
        parameters: [
            "type": "object",
            "properties": [
                "plant": ["type": "string", "description": "Plant common name"]
            ],
            "required": ["plant"]
        ]
    )

    static let recentRecords = ToolDefinition(
        name: "recent_records",
        description: "Summarise recent harvests, sowings, surveys or sightings. Use for questions about what has happened lately.",
        parameters: [
            "type": "object",
            "properties": [
                "kind": [
                    "type": "string",
                    "enum": ["harvests", "sowings", "surveys", "sightings"]
                ],
                "days": ["type": "integer", "description": "How far back to look, default 30"]
            ],
            "required": ["kind"]
        ]
    )

    /// Every tool Eira may use. Kept short on purpose: a small model
    /// chooses more reliably from a few clearly different tools.
    static let all: [ToolDefinition] = [
        lookupSpecies, searchGarden, whatsInBed, plantVisitors, recentRecords, searchNotes,
        searchWikipedia, readWebPage
    ]
}

// MARK: - Results

struct ToolResult {
    let text: String
    let source: String

    var formatted: String {
        "\(text)\n\n[source: \(source)]"
    }

    static func unsourced(_ text: String) -> ToolResult {
        ToolResult(text: text, source: "unsourced — model knowledge, not verified")
    }
}

// MARK: - Runner

@MainActor
struct ToolRunner {

    let context: ModelContext

    func run(name: String, arguments: String) async -> ToolResult {
        let json = (try? JSONSerialization.jsonObject(with: Data(arguments.utf8)))
            as? [String: Any] ?? [:]

        switch name {
        case "lookup_species":
            return await lookupSpecies(json["name"] as? String ?? "")
        case "search_garden":
            return searchGarden(json["query"] as? String ?? "")
        case "whats_growing":
            return whatsGrowing(bed: json["bed"] as? String)
        case "plant_visitors":
            return plantVisitors(json["plant"] as? String ?? "")
        case "search_notes":
            return searchNotes(json["query"] as? String ?? "", service: KnowledgeService())
        case "recent_records":
            return recentRecords(kind: json["kind"] as? String ?? "harvests",
                                 days: json["days"] as? Int ?? 30)
        case "search_wikipedia":
            return await searchWikipedia(json["query"] as? String ?? "")
        case "read_web_page":
            return await readWebPage(json["url"] as? String ?? "")
        default:
            return ToolResult(text: "No such tool: \(name)", source: "app")
        }
    }

    // MARK: GBIF

    /// Taxonomy first — resolve the name before saying anything about it.
    private func lookupSpecies(_ name: String) async -> ToolResult {
        guard !name.isEmpty else {
            return ToolResult(text: "No name given.", source: "app")
        }

        var components = URLComponents(string: "https://api.gbif.org/v1/species/match")!
        components.queryItems = [URLQueryItem(name: "name", value: name)]

        guard let url = components.url else {
            return ToolResult(text: "Couldn't build the lookup.", source: "app")
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let matchType = json["matchType"] as? String, matchType != "NONE" else {
                return ToolResult(text: "GBIF has no match for \"\(name)\".",
                                  source: "GBIF species match API")
            }

            var lines: [String] = []
            if let scientific = json["scientificName"] as? String {
                lines.append("Accepted name: \(scientific)")
            }
            if let rank = json["rank"] as? String { lines.append("Rank: \(rank)") }
            if let family = json["family"] as? String { lines.append("Family: \(family)") }
            if let order = json["order"] as? String { lines.append("Order: \(order)") }
            if let confidence = json["confidence"] as? Int {
                lines.append("Match confidence: \(confidence)%")
            }
            if matchType != "EXACT" {
                lines.append("Note: this was a \(matchType.lowercased()) match, not exact.")
            }

            return ToolResult(text: lines.joined(separator: "\n"),
                              source: "GBIF species match API")

        } catch {
            return ToolResult(text: "Couldn't reach GBIF: \(error.localizedDescription)",
                              source: "app")
        }
    }

    // MARK: Local queries

    private func searchGarden(_ query: String) -> ToolResult {
        let plants = (try? context.fetch(FetchDescriptor<Plant>())) ?? []
        let needle = query.lowercased()

        let matches = plants.filter {
            $0.commonName.lowercased().contains(needle)
                || ($0.latinName?.lowercased().contains(needle) ?? false)
                || ($0.group?.lowercased().contains(needle) ?? false)
        }.prefix(6)

        guard !matches.isEmpty else {
            return ToolResult(text: "Nothing matching \"\(query)\" in the plant database.",
                              source: "user's plant database")
        }

        let described = matches.map { plant -> String in
            var parts = [plant.displayName]
            if let latin = plant.latinName { parts.append("(\(latin))") }
            if let sow = plant.sowOutdoorsMonthsText { parts.append("sow outdoors: \(sow)") }
            if let harvest = plant.harvestMonthsText { parts.append("harvest: \(harvest)") }
            if let sun = plant.sunShade { parts.append("position: \(sun)") }
            if plant.isPollinator { parts.append("pollinator plant") }
            return parts.joined(separator: "; ")
        }

        return ToolResult(text: described.joined(separator: "\n"),
                          source: "user's plant database")
    }

    private func whatsGrowing(bed name: String?) -> ToolResult {
        let plantings = (try? context.fetch(FetchDescriptor<Planting>())) ?? []
        let active = plantings.filter { $0.status != .finished && $0.status != .failed }

        let filtered = name.map { bedName in
            active.filter {
                ($0.sections ?? []).contains {
                    $0.bed?.name.lowercased() == bedName.lowercased()
                }
            }
        } ?? active

        guard !filtered.isEmpty else {
            return ToolResult(text: name.map { "Nothing growing in \($0) at the moment." }
                              ?? "Nothing currently growing.",
                              source: "user's planting records")
        }

        let described = filtered.map { planting -> String in
            var parts = [planting.plant?.displayName ?? "unknown"]
            if !planting.bedNames.isEmpty { parts.append("in \(planting.bedNames)") }
            if let sown = planting.dateSown {
                parts.append("sown \(sown.formatted(date: .abbreviated, time: .omitted))")
            }
            parts.append("status: \(planting.status.rawValue)")
            return parts.joined(separator: ", ")
        }

        return ToolResult(text: described.joined(separator: "\n"),
                          source: "user's planting records")
    }

    private func plantVisitors(_ plant: String) -> ToolResult {
        let links = (try? context.fetch(FetchDescriptor<PlantFaunaLink>())) ?? []
        let matches = links.filter { $0.plantName.lowercased().contains(plant.lowercased()) }

        guard !matches.isEmpty else {
            return ToolResult(text: "No recorded visitors for \"\(plant)\" in the reference data.",
                              source: "user's Plant-Fauna Links sheet")
        }

        let described = matches.map { link -> String in
            var parts = ["\(link.faunaName): \(link.relationship.displayName)"]
            if let shape = link.flowerShape { parts.append("flower shape \(shape)") }
            if let notes = link.notes, !notes.isEmpty { parts.append(notes) }
            return parts.joined(separator: " — ")
        }

        return ToolResult(text: described.joined(separator: "\n"),
                          source: "user's Plant-Fauna Links sheet")
    }

    private func recentRecords(kind: String, days: Int) -> ToolResult {
        let cutoff = Date.now.addingTimeInterval(-Double(days) * 86_400)

        switch kind {
        case "harvests":
            let harvests = ((try? context.fetch(FetchDescriptor<Harvest>())) ?? [])
                .filter { $0.date >= cutoff }
            guard !harvests.isEmpty else {
                return ToolResult(text: "No harvests in the last \(days) days.",
                                  source: "user's harvest records")
            }
            let total = harvests.reduce(0.0) { $0 + $1.weightInGrams } / 1000
            let lines = harvests.prefix(10).map {
                "\($0.date.formatted(date: .abbreviated, time: .omitted)): \($0.planting?.plant?.commonName ?? "unknown") \($0.quantity.formatted()) \($0.unit.displayName)"
            }
            return ToolResult(
                text: "\(harvests.count) pickings totalling \(total.formatted(.number.precision(.fractionLength(0...1)))) kg.\n"
                    + lines.joined(separator: "\n"),
                source: "user's harvest records")

        case "surveys":
            let surveys = ((try? context.fetch(FetchDescriptor<Survey>())) ?? [])
                .filter { $0.startedAt >= cutoff }
            guard !surveys.isEmpty else {
                return ToolResult(text: "No surveys in the last \(days) days.",
                                  source: "user's survey records")
            }
            let lines = surveys.map {
                "\($0.startedAt.formatted(date: .abbreviated, time: .omitted)): \($0.scheme.displayName) on \($0.targetPlantName ?? "—"), \($0.totalCount) recorded"
            }
            return ToolResult(text: lines.joined(separator: "\n"),
                              source: "user's survey records")

        case "sightings":
            let sightings = ((try? context.fetch(FetchDescriptor<WildlifeObservation>())) ?? [])
                .filter { $0.observedAt >= cutoff }
            guard !sightings.isEmpty else {
                return ToolResult(text: "No sightings in the last \(days) days.",
                                  source: "user's sighting records")
            }
            let lines = sightings.prefix(15).map {
                "\($0.observedAt.formatted(date: .abbreviated, time: .omitted)): \($0.bestAvailableName ?? "unidentified")"
                + ($0.associatedPlantName.map { plant in " on \(plant)" } ?? "")
            }
            return ToolResult(text: lines.joined(separator: "\n"),
                              source: "user's sighting records")

        default:
            let plantings = ((try? context.fetch(FetchDescriptor<Planting>())) ?? [])
                .filter { ($0.dateSown ?? .distantPast) >= cutoff }
            guard !plantings.isEmpty else {
                return ToolResult(text: "No sowings in the last \(days) days.",
                                  source: "user's planting records")
            }
            let lines = plantings.map {
                "\($0.dateSown?.formatted(date: .abbreviated, time: .omitted) ?? "—"): \($0.plant?.commonName ?? "unknown") in \($0.bedNames)"
            }
            return ToolResult(text: lines.joined(separator: "\n"),
                              source: "user's planting records")
        }
    }
}

// MARK: - The hub that runs tools for the engine

/// Sits between the model and the tools.
///
/// The on-device engine runs tools itself, in the middle of a reply. It
/// asks this hub, and the hub does three things: runs the tool against
/// your data, trims the result so it cannot crowd out the conversation,
/// and tells the chat screen, so every lookup is visible to you.
@MainActor
final class EiraToolHub {

    private let runner: ToolRunner
    /// Longest result handed back to the model, in characters.
    var resultLimit = 1500
    /// Called each time a tool has run, so the chat can show it.
    var onToolUse: ((_ name: String, _ result: String) -> Void)?

    init(context: ModelContext) {
        self.runner = ToolRunner(context: context)
    }

    /// Runs one tool. `argumentsJSON` is the tool's inputs written as JSON.
    func run(name: String, argumentsJSON: String) async -> String {
        let result = await runner.run(name: name, arguments: argumentsJSON)
        let text = EiraToolHub.trimmed(result, limit: resultLimit)
        onToolUse?(name, text)
        return text
    }

    /// Cuts the body of a long result but always keeps the source line,
    /// because an answer without its source is not allowed.
    static func trimmed(_ result: ToolResult, limit: Int) -> String {
        guard result.text.count > limit else { return result.formatted }
        let cut = String(result.text.prefix(limit))
        let body = cut.lastIndex(of: "\n").map { String(cut[..<$0]) } ?? cut
        return "\(body)\n(shortened)\n\n[source: \(result.source)]"
    }

    /// Writes simple text inputs as JSON, safely.
    nonisolated static func json(_ values: [String: String]) -> String {
        (try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
}

// MARK: - What Eira knows about the garden

/// Standing facts Eira is given at the start of every conversation.
///
/// This is the cheapest way to make her answers fit this garden: she is
/// simply told, every time, what would otherwise have to be repeated.
/// It is plain text, edited in Eira's settings.
enum EiraGardenNotes {

    private static let key = "eiraGardenNotes"

    /// Used until the notes are edited. Check these are right.
    static let starter = """
    Two sites in Gloucestershire, UK: a permaculture forest garden and an allotment.
    The garden is on a clay slope, improved over time with organic matter.
    Methods are organic and permaculture-led. No synthetic pesticides.
    Wildlife recording matters: pollinators, earthworms and what visits which plant.
    """

    static func load(from defaults: UserDefaults = .standard) -> String {
        let saved = defaults.string(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return saved.isEmpty ? starter : saved
    }

    static func save(_ text: String, to defaults: UserDefaults = .standard) {
        defaults.set(text, forKey: key)
    }
}

// MARK: - Standing instructions

/// Builds the instructions Eira is given before every conversation.
///
/// Written for a small model, which follows short, plainly ordered rules
/// far better than long prose. Three things are filled in fresh each time
/// so she never has to guess them: today's date, the season and the
/// garden notes.
enum EiraPrompt {

    static func build(
        date: Date = .now,
        gardenNotes: String = EiraGardenNotes.load(),
        corrections: [String] = [],
        calendar: Calendar = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "EEEE d MMMM yyyy"
        let today = formatter.string(from: date)
        let season = season(for: date, calendar: calendar)

        // Things the gardener has put right before. Listed last in the
        // garden section so they are fresh in the model's mind, and
        // described as overriding everything else.
        let correctionLines = corrections.isEmpty ? "" : "\n\nCorrections the gardener has given you. "
            + "These are right even if you believe otherwise:\n"
            + corrections.map { "- \($0)" }.joined(separator: "\n")

        return """
        You are Eira, a gardening and natural history assistant for one \
        gardener in the UK. You work inside their garden app, Windfall.

        Today is \(today). The season is \(season).

        About this garden:
        \(gardenNotes)\(correctionLines)

        How to answer:
        1. Be brief and practical. Two or three sentences unless asked for more.
        2. Use British spelling and UK growing conditions.
        3. If the question is unclear, ask one short question before answering.

        Using tools:
        4. For anything about this garden, such as what is growing, what was \
        harvested or what visits a plant, use a garden tool first. The \
        gardener's own records are the authority.
        5. When a species is named, call lookup_species first to get its \
        accepted name.
        6. Use search_notes before general knowledge. Use search_wikipedia \
        only when the records and notes have nothing.
        7. Say where each fact came from. If it is your own general \
        knowledge and not from a tool, say "from general knowledge, not checked".

        Identification:
        8. Give the scientific name, the features you used, your confidence \
        and what it could be confused with.
        9. Say plainly when something cannot be identified with certainty.

        Never:
        10. Never identify fungi or say anything is safe to eat. Explain that \
        a mistake can be fatal and suggest a local expert or foray group.
        11. Never give preserving, canning or blanching times, medicinal doses \
        or pesticide rates.
        12. Never say something has been saved or changed. You can look \
        things up but cannot yet change records.

        A hedged correct answer is better than a confident wrong one.
        """
    }

    /// The season by the meteorological calendar used in the UK.
    static func season(for date: Date, calendar: Calendar = .current) -> String {
        switch calendar.component(.month, from: date) {
        case 3...5:  return "spring"
        case 6...8:  return "summer"
        case 9...11: return "autumn"
        default:     return "winter"
        }
    }
}
