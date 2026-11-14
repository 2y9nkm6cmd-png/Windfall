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

    /// What can be sown this month, from the plant library.
    ///
    /// This one is not offered to the model. The app runs it itself,
    /// before the model answers, for any question about what to sow now
    /// (see EiraChecks.lookupFirst). That keeps the model's own list of
    /// tools short, and means the fact arrives whether or not the model
    /// would have thought to ask.
    static let sowingNow = ToolDefinition(
        name: "sowing_now",
        description: "List the plants in the gardener's plant library that can be sown this month, indoors and outdoors.",
        parameters: ["type": "object", "properties": [:]]
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
        case "sowing_now":
            return sowingNow()
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
    /// Finds the accepted scientific name for a plant or animal.
    ///
    /// Three places are tried, in order of trust:
    ///
    ///   1. Your own records. If you have the species in your plant or
    ///      wildlife lists, that is the name you use.
    ///   2. GBIF, the international register of species names. It matches
    ///      scientific names well and everyday names badly.
    ///   3. Wikipedia, to turn an everyday name such as "red mason bee"
    ///      into a scientific one, which is then checked against GBIF.
    ///
    /// Step 3 was added on 11 November 2026. Before it, an everyday name
    /// came back as "no match" and the model guessed.
    private func lookupSpecies(_ name: String) async -> ToolResult {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return ToolResult(text: "No name given.", source: "app")
        }

        var lines: [String] = []
        var sources: [String] = []

        // 1. The gardener's own records.
        let own = ownRecord(named: name)
        if let own {
            lines.append("In the gardener's own records: \(own.description)")
            sources.append("user's records")
        }

        // 2. GBIF, using the scientific name from the records if there is one.
        if let match = await gbifMatch(own?.scientificName ?? name) {
            lines.append(contentsOf: match)
            sources.append("GBIF species match API")
            return ToolResult(text: lines.joined(separator: "\n"),
                              source: sources.joined(separator: " and "))
        }

        // 3. Wikipedia, for an everyday name.
        if let article = try? await WikipediaLookup().lookUp(name) {
            let summary = String(article.extract.prefix(400))
            lines.append("Wikipedia article \"\(article.title)\": \(summary)")
            sources.append("Wikipedia, unverified general reference")

            // Check each likely scientific name against GBIF, stopping at
            // the first that GBIF recognises.
            for candidate in Self.scientificNameCandidates(title: article.title,
                                                           extract: article.extract) {
                if let match = await gbifMatch(candidate) {
                    lines.append(contentsOf: match)
                    sources.append("GBIF species match API")
                    break
                }
            }
        }

        guard !lines.isEmpty else {
            return ToolResult(
                text: "No match for \"\(name)\" in the gardener's records, GBIF or Wikipedia. "
                    + "Say that it could not be found. Do not guess.",
                source: "GBIF and Wikipedia")
        }
        return ToolResult(text: lines.joined(separator: "\n"),
                          source: sources.joined(separator: " and "))
    }

    /// A species found in the gardener's own lists.
    private struct OwnRecord {
        let description: String
        let scientificName: String?
    }

    private func ownRecord(named name: String) -> OwnRecord? {
        let needle = name.lowercased()

        let fauna = (try? context.fetch(FetchDescriptor<Fauna>())) ?? []
        if let found = fauna.first(where: {
            $0.commonName.lowercased() == needle || $0.scientificName?.lowercased() == needle
        }) {
            let latin = found.scientificName.map { " (\($0))" } ?? ""
            return OwnRecord(description: "\(found.commonName)\(latin), in the wildlife list",
                             scientificName: found.scientificName)
        }

        let plants = (try? context.fetch(FetchDescriptor<Plant>())) ?? []
        if let found = plants.first(where: {
            $0.commonName.lowercased() == needle || $0.latinName?.lowercased() == needle
        }) {
            let latin = found.latinName.map { " (\($0))" } ?? ""
            return OwnRecord(description: "\(found.displayName)\(latin), in the plant library",
                             scientificName: found.latinName)
        }
        return nil
    }

    /// Asks GBIF for a name. Returns lines describing the match, or nil
    /// when there is none or GBIF cannot be reached.
    private func gbifMatch(_ name: String) async -> [String]? {
        var components = URLComponents(string: "https://api.gbif.org/v1/species/match")!
        components.queryItems = [URLQueryItem(name: "name", value: name)]
        guard let url = components.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return Self.describeGBIFMatch(json)
    }

    /// Turns GBIF's reply into readable lines. Kept separate from the
    /// network call so it can be tested without the internet.
    static func describeGBIFMatch(_ json: [String: Any]) -> [String]? {
        guard let matchType = json["matchType"] as? String, matchType != "NONE" else { return nil }

        var lines: [String] = []
        if let scientific = json["scientificName"] as? String {
            lines.append("Accepted name: \(scientific)")
        }
        if let rank = json["rank"] as? String { lines.append("Rank: \(rank.lowercased())") }
        if let family = json["family"] as? String { lines.append("Family: \(family)") }
        if let order = json["order"] as? String { lines.append("Order: \(order)") }
        if let confidence = json["confidence"] as? Int {
            lines.append("Match confidence: \(confidence)%")
        }
        if matchType != "EXACT" {
            lines.append("Note: this was a \(matchType.lowercased()) match, not exact.")
        }
        return lines.isEmpty ? nil : lines
    }

    /// Picks likely two-word scientific names out of a Wikipedia article,
    /// best guess first.
    ///
    /// The article for a species usually gives the scientific name in
    /// brackets early on ("The European robin (Erithacus rubecula) is...")
    /// or is titled with it ("Osmia bicornis"). A scientific name is a
    /// capitalised word followed by a lower-case word. Ordinary English
    /// can have that shape too ("European robin"), which is why these are
    /// only candidates: each is checked against GBIF before it is believed.
    static func scientificNameCandidates(title: String, extract: String) -> [String] {
        let binomial = "[A-Z][a-z]+ [a-z][a-z-]+"
        var candidates: [String] = []

        // The first pair of brackets holding a name of that shape.
        let opening = String(extract.prefix(600))
        if let range = opening.range(of: "\\(\(binomial)[),;]", options: .regularExpression) {
            candidates.append(String(opening[range].dropFirst().dropLast()))
        }
        if title.range(of: "^\(binomial)$", options: .regularExpression) != nil,
           !candidates.contains(title) {
            candidates.append(title)
        }
        return candidates
    }

    // MARK: Local queries

    private func searchGarden(_ query: String) -> ToolResult {
        let plants = (try? context.fetch(FetchDescriptor<Plant>())) ?? []

        let matches = plants.filter {
            ToolRunner.plantMatches(asked: query, texts: [$0.commonName, $0.variety, $0.latinName, $0.group])
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

    /// Whether a plant answers a search of the plant database.
    ///
    /// Every word asked for must be somewhere in the plant's name,
    /// variety, Latin name or group, in any order. Until 14 November
    /// 2026 the whole phrase had to appear in one of them as written,
    /// and the variety was not looked at. So "English lavender" did not
    /// find the plant stored as "Lavender", variety "English", and the
    /// trained Qwen told William his database had no such plant.
    ///
    ///   "English lavender"   finds Lavender — English
    ///   "Spartan"            finds Apple — Spartan
    ///   "the broad beans"    finds Broad bean — Aquadulce
    ///   "lavender"           finds every lavender, as before
    ///
    /// Small words such as "the" and "my" are ignored, and a word ending
    /// in "s" also matches without it, so "beans" finds "bean".
    nonisolated static func plantMatches(asked: String, texts: [String?]) -> Bool {
        // `compactMap` drops the pieces a plant does not have.
        let haystack = texts.compactMap { $0?.lowercased() }.joined(separator: " ")
        let ignored: Set<String> = ["the", "a", "an", "my", "of", "and", "some", "any", "plant", "plants"]
        let words = asked.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !ignored.contains($0) }
        guard !words.isEmpty else { return false }
        return words.allSatisfy { word in
            haystack.contains(word)
                || (word.count > 3 && word.hasSuffix("s") && haystack.contains(String(word.dropLast())))
        }
    }

    /// Whether what a model wrote for a bed means this bed.
    ///
    /// A model asked about "Bed 3" may hand over "Bed 3", "bed 3", "3"
    /// or "bed three". All four should find the bed called "Bed 3", and
    /// none should find "Bed 30". Before 13 November 2026 only the first
    /// two did: Qwen3 8B sent "3", was told nothing was growing there
    /// and passed that on, when French beans were.
    ///
    /// Both names are put in lower case, punctuation is dropped, a
    /// leading "bed" is taken off and number words up to twelve become
    /// digits. Then they must be the same.
    nonisolated static func bedMatches(asked: String, name: String) -> Bool {
        let numberWords = ["one": "1", "two": "2", "three": "3", "four": "4", "five": "5", "six": "6",
                           "seven": "7", "eight": "8", "nine": "9", "ten": "10", "eleven": "11", "twelve": "12"]
        func plain(_ text: String) -> String {
            var words = text.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .map { numberWords[$0] ?? $0 }
            if words.count > 1, words.first == "bed" { words.removeFirst() }
            return words.joined(separator: " ")
        }
        let wanted = plain(asked)
        return !wanted.isEmpty && wanted == plain(name)
    }

    private func whatsGrowing(bed name: String?) -> ToolResult {
        let plantings = (try? context.fetch(FetchDescriptor<Planting>())) ?? []
        let active = plantings.filter { $0.status != .finished && $0.status != .failed }

        // A bed that does not exist is not the same as an empty bed. If
        // the name matches nothing, say so and list the beds there are,
        // so the model can try again and not report an empty bed.
        if let name {
            let bedNames = ((try? context.fetch(FetchDescriptor<Bed>())) ?? []).map(\.name)
            if !bedNames.isEmpty, !bedNames.contains(where: { ToolRunner.bedMatches(asked: name, name: $0) }) {
                return ToolResult(
                    text: "There is no bed called \"\(name)\". The beds are: \(bedNames.sorted().joined(separator: ", ")).",
                    source: "user's garden records")
            }
        }

        let filtered = name.map { bedName in
            active.filter {
                ($0.sections ?? []).contains {
                    ToolRunner.bedMatches(asked: bedName, name: $0.bed?.name ?? "")
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

    /// What the plant library says can be sown this month.
    private func sowingNow(today: Date = .now, calendar: Calendar = .current) -> ToolResult {
        let month = calendar.component(.month, from: today)
        let plants = (try? context.fetch(FetchDescriptor<Plant>())) ?? []
        let rows = plants.map {
            (name: $0.displayName,
             indoors: MonthParser.months(in: $0.sowIndoorsMonthsText),
             outdoors: MonthParser.months(in: $0.sowOutdoorsMonthsText))
        }
        let words = ToolRunner.sowingText(for: rows, month: month, monthName: calendar.monthSymbols[month - 1])
        return ToolResult(text: words, source: "user's plant database")
    }

    /// The words handed to the model: who can be sown this month, and where.
    ///
    /// Kept apart from the fetching above so it can be tested without a
    /// database. At most `limit` names are given for each place, with a
    /// count of the rest, so a long list cannot crowd out the question.
    nonisolated static func sowingText(for plants: [(name: String, indoors: [Int], outdoors: [Int])],
                                       month: Int, monthName: String, limit: Int = 30) -> String {
        func listed(_ names: [String]) -> String {
            let unique = Array(Set(names)).sorted()
            let shown = unique.prefix(limit).joined(separator: ", ")
            return unique.count > limit ? "\(shown) and \(unique.count - limit) more" : shown
        }
        let indoors = plants.filter { $0.indoors.contains(month) }.map(\.name)
        let outdoors = plants.filter { $0.outdoors.contains(month) }.map(\.name)

        guard !indoors.isEmpty || !outdoors.isEmpty else {
            return "Nothing in the plant library has \(monthName) among its sowing months."
        }
        var lines = ["Plants in the plant library whose sowing months include \(monthName):"]
        if !indoors.isEmpty { lines.append("Sow indoors (\(Set(indoors).count)): \(listed(indoors))") }
        if !outdoors.isEmpty { lines.append("Sow outdoors (\(Set(outdoors).count)): \(listed(outdoors))") }
        lines.append("Anything not listed is not marked for sowing in \(monthName).")
        return lines.joined(separator: "\n")
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
        accepted name. If it finds nothing, call search_wikipedia. Never \
        guess what a species is.
        6. Use search_notes before general knowledge. Use search_wikipedia \
        only when the records and notes have nothing.
        7. Say where each fact came from. If it is your own general \
        knowledge and not from a tool, say "from general knowledge, not checked".
        8. When a tool finds no records, say that nothing is recorded. Do \
        not say that it did not happen. "I have no sowings recorded for \
        last week" is right. "You did not sow anything" is wrong.

        Identification:
        9. Give the scientific name, the features you used, your confidence \
        and what it could be confused with.
        10. Say plainly when something cannot be identified with certainty.

        Never:
        11. Never identify fungi or say anything is safe to eat. Never ask \
        for a description of a fungus, and never offer to check one. Explain \
        that a mistake can be fatal and suggest a local fungus group.
        12. Never give preserving, canning or blanching times, medicinal doses \
        or pesticide rates.
        13. Never say something has been saved or changed. You can look \
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
