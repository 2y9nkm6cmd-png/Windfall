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

    static let all: [ToolDefinition] = [
        lookupSpecies, searchGarden, whatsInBed, plantVisitors, recentRecords, searchNotes
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

// MARK: - System prompt

enum EiraPrompt {

    static func build(location: String = "Gloucestershire, UK") -> String {
        """
        You are Eira, a horticulture and natural-history assistant for a \
        permaculture garden and allotment in \(location).

        How to answer:
        - Be brief and practical. Two or three sentences unless asked for more.
        - Advice must suit the UK climate, organic and permaculture methods.
        - Use British spelling.

        Using tools:
        - When any species is mentioned, call lookup_species FIRST to get the \
        accepted name. Do not describe a species before resolving its name.
        - For anything about this specific garden — what is growing, what was \
        harvested, what visits a plant — use the garden tools rather than \
        general knowledge. The user's own records are authoritative.
        - Always say where an answer came from. If you are drawing on general \
        knowledge rather than a tool, say so plainly.

        Identification:
        - Give the scientific name, the diagnostic features you are using, \
        your confidence, and the species it could be confused with.
        - Say plainly when a photograph cannot settle an identification. Many \
        UK invertebrates cannot be identified to species from an image by \
        anyone.
        - Never identify fungi. Refuse and explain that misidentification can \
        be fatal and that a local expert or foray group should be consulted.

        Be honest about uncertainty. A hedged correct answer is more useful \
        than a confident wrong one.
        """
    }
}
