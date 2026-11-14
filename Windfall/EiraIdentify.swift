//
//  EiraIdentify.swift
//  Windfall
//
//  Eira's judgement about a photo.
//
//  The image model (SpeciesEye.swift, SpeciesTable.swift) only matches.
//  It hands back the few names on its list that the photo most
//  resembles, each with a share. It knows nothing about the month, about
//  this garden or about which species nobody can tell apart.
//
//  This file adds that judgement, by fixed rules and with no model:
//
//    1. If she cannot split two species of one genus, she says the
//       genus and stops there. "A bumblebee, species not certain" is
//       more use than a confident wrong species.
//    2. If the name is one of a group that cannot be told apart from a
//       photo, she says "one of these" and why.
//    3. She checks the month: against UK records month by month, and
//       against the flight period in your own wildlife list.
//    4. She looks the names up in your plant list, your wildlife list
//       and your past sightings, and says what she finds.
//    5. If a dangerous plant is among the possibilities she says so,
//       whichever name came first. The carrot-family warning comes
//       from DangerousLookAlikes in SpeciesTable.swift.
//
//  The answer is an `EiraIdentification`. The Identify screen and
//  Eira's chat both draw it with the same card (IdentifyCards.swift).
//
//  Nothing here needs Apple's AI frameworks or the screen, so all of it
//  is covered by the logic tests that run without a Mac.
//
//  New things here:
//
//  enum with values   `case genusOnly(String)` is a case that carries a
//                     value with it, here the genus.
//  Dictionary         A lookup table: give it a key and it hands back
//                     the value filed under that key, or nil.
//

import Foundation

// MARK: - Comparing names

/// Scientific names are written many ways: "Lavandula angustifolia",
/// "Lavandula angustifolia 'Hidcote'", "lavandula  angustifolia". To
/// compare two, each is cut down to the same plain form first.
enum SpeciesName {

    /// The genus and species in small letters, with anything after
    /// them (a variety, an author) left off. A name with only a genus
    /// gives the genus.
    nonisolated static func key(_ name: String?) -> String {
        guard let name else { return "" }
        var words: [String] = []
        for piece in name.lowercased().split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" }) {
            // A hybrid's cross is not part of the name being compared.
            if piece == "x" || piece == "×" { continue }
            // A variety in quotation marks ends the name.
            if let first = piece.first, "'‘’\"“(".contains(first) { break }
            let letters = String(piece.filter { $0.isLetter || $0 == "-" })
            if letters.isEmpty || letters == "sp" || letters == "spp" || letters == "var" || letters == "subsp" { break }
            words.append(letters)
            if words.count == 2 { break }
        }
        return words.joined(separator: " ")
    }

    /// The first word of a scientific name, as written.
    nonisolated static func genus(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}

// MARK: - What Windfall already knows

/// A plant in your plant list, cut down to what is needed here.
struct KnownPlant: Equatable {
    /// How it reads in the app, such as "Lavender, Hidcote".
    var name: String
    var latin: String
}

/// A species in your wildlife list.
struct KnownWildlife: Equatable {
    var common: String
    var scientific: String
    /// The months it is about, 1 to 12, where the list gives them.
    var flightMonths: [Int] = []
    var flightText: String?
    var favouredPlants: String?
}

/// One sighting already in your records.
struct PastSighting: Equatable {
    /// Every name the sighting carries: confirmed, looked up or guessed.
    var names: [String]
    var date: Date
    /// True when you confirmed the name yourself.
    var isConfirmed: Bool
}

/// How many UK records there are of each species in each month.
///
/// The figures are counts of agreed records on iNaturalist, fetched on
/// the Mac (project doc 28). A summer insect suggested in January is
/// worth doubting, and these say so.
struct SpeciesSeasons {

    /// Twelve counts, January first, filed under the species' name.
    let counts: [String: [Int]]
    /// Where the counts came from, for saying so.
    let source: String

    init(counts: [String: [Int]], source: String = "iNaturalist") {
        var filed: [String: [Int]] = [:]
        for (name, months) in counts where months.count == 12 {
            filed[SpeciesName.key(name)] = months
        }
        self.counts = filed
        self.source = source
    }

    /// Reads SpeciesMonths.json. Returns nil if it is not that file.
    init?(data: Data) {
        struct File: Decodable {
            var source: String?
            var months: [String: [Int]]
        }
        guard let read = try? JSONDecoder().decode(File.self, from: data) else { return nil }
        self.init(counts: read.months, source: read.source ?? "iNaturalist")
    }

    /// How usual a species is in a month.
    enum Standing: Equatable {
        case usual
        /// Under 2 in 100 of its records fall in this month.
        case scarce(inMonth: Int, inYear: Int)
        /// Under 1 in 200 do.
        case rare(inMonth: Int, inYear: Int)
    }

    /// Nil when the species is not in the file, or has too few records
    /// for a share of them to mean anything.
    ///
    /// ⚠️ CHECK: the two levels (2% and 0.5%) and the least number of
    /// records (200) are Claude's judgement, 14 November 2026.
    func standing(of scientific: String, month: Int) -> Standing? {
        guard (1...12).contains(month),
              let months = counts[SpeciesName.key(scientific)] else { return nil }
        let year = months.reduce(0, +)
        guard year >= 200 else { return nil }
        let share = Double(months[month - 1]) / Double(year)
        if share < 0.005 { return .rare(inMonth: months[month - 1], inYear: year) }
        if share < 0.02 { return .scarce(inMonth: months[month - 1], inYear: year) }
        return .usual
    }
}

/// Species that cannot reliably be told apart from a photo.
struct LookalikeGroup: Codable, Equatable {
    var names: [String]
    var why: String
}

struct Lookalikes {

    let groups: [LookalikeGroup]
    /// False until the list has been checked against a field guide.
    /// While it is false every warning from it is marked "to check".
    let isChecked: Bool

    init(groups: [LookalikeGroup], isChecked: Bool = false) {
        self.groups = groups
        self.isChecked = isChecked
    }

    /// Reads SpeciesLookalikes.json. Returns nil if it is not that file.
    init?(data: Data) {
        struct File: Decodable {
            var checked: Bool?
            var groups: [LookalikeGroup]
        }
        guard let read = try? JSONDecoder().decode(File.self, from: data) else { return nil }
        self.init(groups: read.groups, isChecked: read.checked ?? false)
    }

    /// The group a species belongs to, if it is in one.
    func group(holding scientific: String) -> LookalikeGroup? {
        let wanted = SpeciesName.key(scientific)
        return groups.first { group in group.names.contains { SpeciesName.key($0) == wanted } }
    }
}

/// Plants that can kill or badly hurt.
///
/// ⚠️ CHECK: this list was written by Claude from general knowledge on
/// 14 November 2026 and has not been checked by William against a
/// reference. It is here so that a warning is shown too often rather
/// than too seldom. It is not a list of every poisonous plant, and a
/// plant's absence from it says nothing about whether it is safe.
enum PlantDangers {

    /// What to say about each, filed under its name.
    nonisolated static let harmful: [String: String] = [
        "conium maculatum": "Hemlock is deadly poisonous in every part",
        "oenanthe crocata": "Hemlock water-dropwort is deadly poisonous in every part, the roots most of all",
        "cicuta virosa": "Cowbane is deadly poisonous",
        "aethusa cynapium": "Fool's parsley is poisonous",
        "aconitum napellus": "Monkshood is deadly poisonous, and its sap can harm through the skin",
        "atropa belladonna": "Deadly nightshade is deadly poisonous, the berries included",
        "digitalis purpurea": "Foxglove is poisonous in every part",
        "taxus baccata": "Yew is deadly poisonous in every part but the red flesh round the seed",
        "colchicum autumnale": "Meadow saffron is deadly poisonous",
        "arum maculatum": "Lords-and-ladies is poisonous, and its berries are a danger to children",
        "heracleum mantegazzianum": "Giant hogweed's sap blisters and burns the skin in sunlight",
        "laburnum anagyroides": "Laburnum is poisonous in every part, the seeds most of all",
        "ricinus communis": "The castor oil plant's seeds are deadly poisonous",
        "daphne mezereum": "Mezereon is poisonous, the berries included",
        "solanum dulcamara": "Bittersweet's berries are poisonous",
        "bryonia dioica": "White bryony is poisonous, the berries and root included",
        "datura stramonium": "Thorn-apple is deadly poisonous",
        "convallaria majalis": "Lily of the valley is poisonous in every part",
        "nerium oleander": "Oleander is deadly poisonous in every part"
    ]

    nonisolated static func danger(of scientific: String) -> String? {
        harmful[SpeciesName.key(scientific)]
    }

}

/// Everything Eira can check a photo's answer against. The screen
/// gathers it from the records (IdentifyCards.swift) and hands it over,
/// so the rules below never touch the database themselves.
struct IdentifyKnowledge {
    /// The month the photo is judged in, 1 to 12: the month it was
    /// taken where the photo says, and otherwise this month. Any other
    /// number means "not known", and then the month is not checked.
    var month: Int
    /// True when `month` was read from the photo itself.
    var monthIsFromPhoto = false
    var plants: [KnownPlant] = []
    var wildlife: [KnownWildlife] = []
    var sightings: [PastSighting] = []
    var seasons: SpeciesSeasons?
    var lookalikes: Lookalikes?

    /// "November" for 11. Fixed English names, so the wording is the
    /// same on every device.
    nonisolated static func monthName(_ month: Int) -> String {
        let names = ["January", "February", "March", "April", "May", "June", "July",
                     "August", "September", "October", "November", "December"]
        return (1...12).contains(month) ? names[month - 1] : "this month"
    }
}

// MARK: - The answer

/// What Eira makes of a photo.
struct EiraIdentification: Equatable {

    enum Verdict: Equatable {
        /// One species, named.
        case named
        /// One of a group that cannot be told apart from a photo.
        case oneOfSeveral([String])
        /// The genus is clear and the species is not.
        case genusOnly(String)
        /// Nothing is strong enough to name.
        case notSure
        /// There was nothing to compare the photo with.
        case nothing
    }

    /// Something to be careful of.
    struct Caution: Equatable, Hashable {
        enum Weight: Equatable, Hashable {
            /// It could hurt someone.
            case danger
            /// A reason to doubt the name.
            case doubt
            /// Worth knowing.
            case note
        }
        var weight: Weight
        var words: String
        /// True when the fact behind it came from Claude and has not
        /// been checked by William. The card marks these.
        var isUnchecked = false
    }

    var verdict: Verdict
    /// The line in large type: a name, or that she is not sure.
    var headline: String
    /// Under the headline: the scientific name, or the names it lies between.
    var subheading: String?
    /// The name a sighting would carry as its suggestion. Nil when
    /// nothing should be written in as a name at all.
    var provisionalName: String?
    /// How far to trust it. Nil when nothing is named.
    var confidence: IDConfidence?
    /// The image model's closest names, most likely first.
    var candidates: [SpeciesCandidate]
    /// What your own records say about the names.
    var records: [String]
    var cautions: [Caution]
    /// What the image model can and cannot do, said under every answer.
    var caveat: String
    /// Which image model answered, such as "BioCLIP 2.5 Huge".
    var modelName: String?

    /// True when there is a name to put on a sighting.
    var isNameable: Bool { provisionalName != nil }

    /// The answer in sentences, for Eira's chat and for reading aloud.
    var spoken: String {
        var parts: [String] = []
        let closest = candidates.prefix(3)
            .map { "\($0.entry.title), \($0.percent)" }
            .joined(separator: "; ")

        switch verdict {
        case .named:
            guard let top = candidates.first else { break }
            if confidence == .probable {
                parts.append("This looks like \(top.entry.title). The image model puts it at \(top.percent).")
            } else {
                parts.append("This may be \(top.entry.title). The image model puts it at \(top.percent), but there is a reason to doubt it.")
            }
        case .oneOfSeveral(let names):
            guard let top = candidates.first else { break }
            let others = names.filter { SpeciesName.key($0) != SpeciesName.key(top.entry.scientific) }
            parts.append("This looks like \(top.entry.title), or a species that cannot be told from it in a photo: \(others.joined(separator: ", ")). The image model puts its first choice at \(top.percent).")
        case .genusOnly:
            parts.append("\(headline). The closest matches are \(closest).")
        case .notSure:
            parts.append("I am not sure what this is. The closest matches are \(closest). None is strong enough to name. A closer or sharper photo may help, and it may be something the image model was never shown.")
        case .nothing:
            parts.append("There is nothing to compare the photo with.")
        }

        parts.append(contentsOf: cautions.map { $0.isUnchecked ? $0.words + " (From a list that has not been checked yet.)" : $0.words })
        parts.append(contentsOf: records)
        if verdict != .nothing {
            parts.append("Nothing has been saved. " + caveat)
        }
        return parts.joined(separator: "\n\n")
    }

    /// The note kept with a sighting started from this answer.
    var sightingNote: String {
        let closest = candidates.prefix(3)
            .map { "\($0.entry.title), \($0.percent)" }
            .joined(separator: "; ")
        let by = modelName.map { " by \($0)" } ?? ""
        switch verdict {
        case .named:
            return "Suggested by Eira from a photograph\(by) (\(closest)). Needs confirming."
        case .oneOfSeveral(let names):
            return "Suggested by Eira from a photograph\(by) (\(closest)). It cannot reliably be told from a photo which of these it is: \(names.joined(separator: ", ")). Needs confirming."
        case .genusOnly(let genus):
            return "Eira could tell the genus, \(genus), from the photograph\(by) and not the species. Closest: \(closest)."
        case .notSure:
            return "Eira was not sure from the photograph\(by). Closest: \(closest)."
        case .nothing:
            return "Photo saved without an identification."
        }
    }
}

// MARK: - The rules

enum EiraIdentify {

    /// The pooled share a genus must reach before Eira will name the
    /// genus when she cannot name the species. The same level as the
    /// image model's own "not sure" line (project doc 28).
    nonisolated static let genusFloor = 0.85

    /// How many of the image model's closest names to ask for. More
    /// than are shown, so that the shares of one genus can be pooled
    /// and a dangerous plant further down is still seen.
    nonisolated static let candidatesWanted = 5

    /// Judges the image model's answer against what Windfall knows.
    ///
    /// - `guess`: what the image model said.
    /// - `knowing`: the month and your records.
    /// - `listSize`: how many names the model could choose from.
    static func judge(_ guess: SpeciesGuess,
                      knowing knowledge: IdentifyKnowledge,
                      listSize: Int? = nil,
                      modelName: String? = nil) -> EiraIdentification {

        let caveat = EiraIdentify.caveat(listSize: listSize)
        guard let top = guess.candidates.first else {
            return EiraIdentification(verdict: .nothing, headline: "Nothing to compare the photo with",
                                      subheading: nil, provisionalName: nil, confidence: nil,
                                      candidates: [], records: [], cautions: [], caveat: caveat,
                                      modelName: modelName)
        }

        var cautions: [EiraIdentification.Caution] = []

        // Rule 5 first, because it matters most: a dangerous plant
        // anywhere among the possibilities, or one of the carrot family
        // at the top.
        cautions.append(contentsOf: dangers(in: guess.candidates))

        // Which verdict?
        var verdict: EiraIdentification.Verdict = .notSure
        var headline = "Eira is not sure"
        var subheading: String?
        var provisionalName: String?
        var confidence: IDConfidence?
        /// The names whose records are worth looking up.
        var subjects: [SpeciesEntry] = guess.candidates.prefix(3).map(\.entry)

        if guess.isSure {
            verdict = .named
            headline = top.entry.common.flatMap { $0.isEmpty ? nil : $0 } ?? top.entry.scientific
            subheading = headline == top.entry.scientific ? nil : top.entry.scientific
            provisionalName = top.entry.scientific
            confidence = .probable
            subjects = [top.entry]

            // Rule 2: one of a group nobody can split from a photo.
            // A group of one is a species whose look-alikes are not
            // on the list by name ("most hoverflies of this genus"):
            // it keeps its name and still gets the doubt.
            if let group = knowledge.lookalikes?.group(holding: top.entry.scientific) {
                if group.names.count > 1 {
                    verdict = .oneOfSeveral(group.names)
                    headline += " or a look-alike"
                    subheading = group.names.joined(separator: " / ")
                }
                confidence = .possible
                cautions.append(.init(weight: .doubt, words: group.why,
                                      isUnchecked: !(knowledge.lookalikes?.isChecked ?? false)))
            }
        } else if let pooled = pooledGenus(of: guess.candidates) {
            // Rule 1: the genus is clear and the species is not.
            verdict = .genusOnly(pooled.genus)
            if let word = pooled.everydayWord {
                headline = "\(article(for: word)) \(word) (\(pooled.genus)), species not certain"
            } else {
                headline = "One of the \(pooled.genus) species, which one is not certain"
            }
            subheading = pooled.members.map(\.scientific).joined(separator: " / ")
            provisionalName = pooled.genus
            confidence = .possible
            subjects = pooled.members
        }

        // Rule 3: the month. Only worth saying of a name she is giving.
        if guess.isSure {
            let month = IdentifyKnowledge.monthName(knowledge.month)
            // A photo taken in June and looked at in November is
            // judged for June, and the words say which month is meant.
            let when = knowledge.monthIsFromPhoto ? "\(month), when the photo was taken" : month
            switch knowledge.seasons?.standing(of: top.entry.scientific, month: knowledge.month) {
            case .rare(let inMonth, let inYear):
                cautions.append(.init(weight: .doubt, words: "It is rarely recorded in the UK in \(when): \(grouped(inMonth)) of \(grouped(inYear)) records on \(knowledge.seasons?.source ?? "iNaturalist")."))
                confidence = .possible
            case .scarce(let inMonth, let inYear):
                cautions.append(.init(weight: .note, words: "It is not often recorded in the UK in \(when): \(grouped(inMonth)) of \(grouped(inYear)) records on \(knowledge.seasons?.source ?? "iNaturalist")."))
            case .usual, .none:
                break
            }
            if (1...12).contains(knowledge.month),
               let listed = wildlife(matching: top.entry, in: knowledge.wildlife),
               !listed.flightMonths.isEmpty, !listed.flightMonths.contains(knowledge.month) {
                let period = listed.flightText.map { " as \($0)" } ?? ""
                let photoWas = knowledge.monthIsFromPhoto ? "the photo was taken in \(month)" : "this is \(month)"
                cautions.append(.init(weight: .doubt, words: "Your wildlife list gives its flight period\(period), and \(photoWas)."))
                confidence = .possible
            }
            if let source = top.entry.source, source.lowercased().contains("to check") {
                cautions.append(.init(weight: .note, words: "This name is on the image model's list from a pot label in one of your photos, and has not been checked."))
            }
        }

        // Rule 4: what the records say.
        let single = subjects.count == 1
        var records: [String] = []
        for entry in subjects {
            records.append(contentsOf: recordLines(for: entry, in: knowledge, naming: !single))
        }
        if single, records.isEmpty, let only = subjects.first {
            records.append(only.group == "Plantae"
                           ? "It is not in your plant list, and you have no earlier sighting of it."
                           : "It is not in your wildlife list, and you have no earlier sighting of it.")
        }

        return EiraIdentification(verdict: verdict, headline: headline, subheading: subheading,
                                  provisionalName: provisionalName, confidence: confidence,
                                  candidates: guess.candidates, records: records,
                                  cautions: cautions, caveat: caveat, modelName: modelName)
    }

    /// What the image model can and cannot do.
    nonisolated static func caveat(listSize: Int?) -> String {
        let list = listSize.map { "the \($0) UK species it was given" } ?? "the UK species it was given"
        return "The image model can only choose among \(list), and it never names fungi. Never eat anything, or handle a plant that may be poisonous, on the strength of a match: it can mistake a deadly plant for a harmless one. Treat a match as a suggestion to check."
    }

    // MARK: Rule 1: pooling a genus

    struct PooledGenus: Equatable {
        var genus: String
        var share: Double
        var members: [SpeciesEntry]
        /// "bumblebee" when every member's English name ends with it.
        var everydayWord: String?
    }

    /// Adds up the shares of the candidates in the same genus as the
    /// first. Returns them if there are at least two and together they
    /// reach `genusFloor`.
    static func pooledGenus(of candidates: [SpeciesCandidate]) -> PooledGenus? {
        guard let top = candidates.first else { return nil }
        let genus = SpeciesName.genus(top.entry.scientific)
        let same = candidates.filter { SpeciesName.genus($0.entry.scientific) == genus }
        let share = same.reduce(0) { $0 + $1.share }
        guard same.count >= 2, share >= genusFloor else { return nil }

        // The last word of each English name: "Buff-tailed Bumblebee"
        // and "Garden Bumblebee" both end in "bumblebee".
        let lastWords = same.map { $0.entry.common?.split(separator: " ").last.map { $0.lowercased() } ?? "" }
        let shared = Set(lastWords).count == 1 ? lastWords[0] : ""
        return PooledGenus(genus: genus, share: share, members: same.map(\.entry),
                           everydayWord: shared.isEmpty ? nil : shared)
    }

    /// "An" before a vowel sound, near enough: "an ant", "a bumblebee".
    nonisolated static func article(for word: String) -> String {
        guard let first = word.lowercased().first else { return "A" }
        return "aeiou".contains(first) ? "An" : "A"
    }

    // MARK: Rule 5: dangers

    /// A warning for each dangerous plant among the possibilities, and
    /// one for the carrot family if any of the three names shown
    /// belongs to it.
    ///
    /// Two lists are used. `PlantDangers` (above) names particular
    /// plants. A plant on it counts if it is the first name, or holds
    /// at least 2 in 100 of the model's belief. ⚠️ CHECK: that level is
    /// Claude's judgement. It is low on purpose: in the test of 14
    /// November 2026 a photo of hemlock water-dropwort was named as
    /// yellow iris at 87% (project doc 27).
    ///
    /// `DangerousLookAlikes` (SpeciesTable.swift, written by another
    /// chat the same morning) knows the carrot family, and warns
    /// however small the share: BioCLIP 2.5 Huge named a photo of
    /// hemlock as cow parsley at over 99%. Its warning is left out only
    /// when a carrot-family plant has already been warned of by name,
    /// so the same thing is not said twice.
    static func dangers(in candidates: [SpeciesCandidate]) -> [EiraIdentification.Caution] {
        var found: [EiraIdentification.Caution] = []
        var namedOneOfTheFamily = false
        for (place, candidate) in candidates.enumerated() where candidate.entry.group == "Plantae" {
            guard place == 0 || candidate.share >= 0.02,
                  let danger = PlantDangers.danger(of: candidate.entry.scientific) else { continue }
            let opening = place == 0 ? "" : "\(candidate.entry.title) is among the possibilities. "
            found.append(.init(weight: .danger,
                               words: "\(opening)\(danger). Do not eat it or handle it on the strength of a photo.",
                               isUnchecked: true))
            if DangerousLookAlikes.isCarrotFamily(candidate.entry) { namedOneOfTheFamily = true }
        }
        if !namedOneOfTheFamily,
           let warning = DangerousLookAlikes.warning(for: Array(candidates.prefix(3))) {
            found.append(.init(weight: .danger, words: warning))
        }
        return found
    }

    // MARK: Rule 4: the records

    static func wildlife(matching entry: SpeciesEntry, in list: [KnownWildlife]) -> KnownWildlife? {
        let wanted = SpeciesName.key(entry.scientific)
        return list.first { SpeciesName.key($0.scientific) == wanted }
    }

    /// The lines that say what your records hold about one species.
    /// `naming` puts its name in each line, for when several species
    /// are being looked up at once.
    static func recordLines(for entry: SpeciesEntry, in knowledge: IdentifyKnowledge, naming: Bool) -> [String] {
        let wanted = SpeciesName.key(entry.scientific)
        guard !wanted.isEmpty else { return [] }
        let who = naming ? entry.title : "it"
        var lines: [String] = []

        // The plant list. One species may be there as several varieties.
        let plants = knowledge.plants.filter { SpeciesName.key($0.latin) == wanted }
        if !plants.isEmpty {
            let shown = plants.prefix(3).map(\.name).joined(separator: "; ")
            let more = plants.count > 3 ? " and \(plants.count - 3) more" : ""
            lines.append(naming ? "\(entry.title) is in your plant list: \(shown)\(more)."
                                : "It is in your plant list: \(shown)\(more).")
        }

        // The wildlife list.
        if let listed = wildlife(matching: entry, in: knowledge.wildlife) {
            var line = naming ? "\(entry.title) is in your wildlife list." : "It is in your wildlife list as \(listed.common)."
            if let flight = listed.flightText, !flight.isEmpty { line += " Flight period: \(flight)." }
            if let favoured = listed.favouredPlants, !favoured.isEmpty { line += " Favoured plants: \(favoured)." }
            lines.append(line)
        }

        // Past sightings, by any of the names each one carries. The
        // English name counts as well, for sightings typed in by hand.
        let english = entry.common?.lowercased() ?? ""
        let seen = knowledge.sightings.filter { sighting in
            sighting.names.contains { name in
                SpeciesName.key(name) == wanted || (!english.isEmpty && name.lowercased() == english)
            }
        }
        if let last = seen.map(\.date).max() {
            let times = seen.count == 1 ? "once" : "\(seen.count) times"
            let confirmed = seen.filter(\.isConfirmed).count
            let standing = confirmed == seen.count ? "" : (confirmed == 0 ? ", none of them confirmed" : ", \(confirmed) of them confirmed")
            let on = seen.count == 1 ? "on" : "last on"
            lines.append("You have recorded \(who) \(times), \(on) \(day(last))\(standing).")
        }
        return lines
    }

    /// A whole number with commas between the thousands: "13,374".
    /// Done by hand so that it reads the same on every device,
    /// whatever its region is set to.
    nonisolated static func grouped(_ number: Int) -> String {
        let digits = String(abs(number))
        var result = ""
        for (place, digit) in digits.reversed().enumerated() {
            if place > 0, place % 3 == 0 { result.append(",") }
            result.append(digit)
        }
        return (number < 0 ? "-" : "") + String(result.reversed())
    }

    /// "12 November 2026".
    nonisolated static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Was the judgement right?

extension EiraIdentification {

    /// How an answer stands against the truth, for the test run.
    enum Mark: Equatable {
        /// She gave a name, a group or a genus and the truth is it, or in it.
        case right
        /// She gave one and the truth is something else.
        case wrong
        /// She gave nothing.
        case declined
    }

    /// Marks this answer against a photo's true scientific name.
    func mark(against truth: String) -> Mark {
        let wanted = SpeciesName.key(truth)
        switch verdict {
        case .named:
            return candidates.first.map { SpeciesName.key($0.entry.scientific) == wanted } == true ? .right : .wrong
        case .oneOfSeveral(let names):
            return names.contains { SpeciesName.key($0) == wanted } ? .right : .wrong
        case .genusOnly(let genus):
            return SpeciesName.genus(truth).lowercased() == genus.lowercased() ? .right : .wrong
        case .notSure, .nothing:
            return .declined
        }
    }
}

// MARK: - The image models that are installed

/// One image model in Windfall's Models folder: a folder holding the
/// model, the list of species and the rows of numbers made for it.
///
/// More than one can be installed, so that they can be compared on the
/// same photos (EyeTestView.swift). Eira uses one of them.
struct EyeModel: Identifiable, Equatable {
    /// The folder's name inside Models, such as "bioclip2".
    var folder: String
    /// A name to show, such as "BioCLIP 2.5 Huge".
    var name: String
    var note: String?
    /// Lower comes first. The first is Eira's unless another is chosen.
    var order: Int
    /// The model's own file name inside the folder.
    var modelFile: String

    var id: String { folder }

    /// The shape of the small file, eye.json, that names a model. All
    /// of it is optional: a folder without one is shown by its own name.
    private struct Label: Decodable {
        var name: String?
        var note: String?
        var order: Int?
    }

    /// Describes a folder from its name and its label file, if it has one.
    static func describing(folder: String, modelFile: String, label: Data?) -> EyeModel {
        let read = label.flatMap { try? JSONDecoder().decode(Label.self, from: $0) }
        return EyeModel(folder: folder,
                        name: read?.name.flatMap { $0.isEmpty ? nil : $0 } ?? folder,
                        note: read?.note,
                        order: read?.order ?? 100,
                        modelFile: modelFile)
    }

    /// Puts a list of models in order: by `order`, then by name.
    static func sorted(_ models: [EyeModel]) -> [EyeModel] {
        models.sorted { ($0.order, $0.name) < ($1.order, $1.name) }
    }

    /// The model Eira uses: the saved choice if it is still installed,
    /// and otherwise the first in order.
    static func pick(from installed: [EyeModel], saved: String?) -> EyeModel? {
        if let saved, let chosen = installed.first(where: { $0.folder == saved }) { return chosen }
        return sorted(installed).first
    }
}

// MARK: - Marking a test of the image models

/// What is really in a test photo, as you marked it.
enum EyeTruth: Equatable {
    /// This species, by its scientific name.
    case species(String)
    /// Something that is not on the model's list at all.
    case notOnList
}

/// One model's answer for one photo in a test.
struct EyeTestAnswer: Equatable {
    var guess: SpeciesGuess
    var seconds: Double
    /// Nil until you have marked the photo.
    var truth: EyeTruth?
}

/// One model's score over a set of photos.
struct EyeTestTally: Equatable {
    var tried = 0
    /// Photos you have marked.
    var marked = 0
    /// Marked photos whose species is on the model's list.
    var onList = 0
    var firstRight = 0
    var inThree = 0
    /// Marked photos the model named outright, and how many were right.
    var named = 0
    var namedRight = 0
    /// Photos of something off its list, and how many it still named.
    var offList = 0
    var offListNamed = 0
    var seconds = 0.0

    static func counting(_ answers: [EyeTestAnswer]) -> EyeTestTally {
        var tally = EyeTestTally()
        for answer in answers {
            tally.tried += 1
            tally.seconds += answer.seconds
            guard let truth = answer.truth else { continue }
            tally.marked += 1
            switch truth {
            case .species(let name):
                let wanted = SpeciesName.key(name)
                let isFirst = answer.guess.likeliest.map { SpeciesName.key($0.entry.scientific) == wanted } ?? false
                let isInThree = answer.guess.candidates.prefix(3).contains { SpeciesName.key($0.entry.scientific) == wanted }
                tally.onList += 1
                if isFirst { tally.firstRight += 1 }
                if isInThree { tally.inThree += 1 }
                if answer.guess.isSure {
                    tally.named += 1
                    if isFirst { tally.namedRight += 1 }
                }
            case .notOnList:
                tally.offList += 1
                if answer.guess.isSure {
                    tally.named += 1
                    tally.offListNamed += 1
                }
            }
        }
        return tally
    }

    /// "9 of 12 (75%)", or "none" when there is nothing to divide by.
    nonisolated static func share(_ part: Int, of whole: Int) -> String {
        guard whole > 0 else { return "none" }
        return "\(part) of \(whole) (\(Int((Double(part) / Double(whole) * 100).rounded()))%)"
    }

    /// The score in lines, for the screen and for copying out.
    var lines: [String] {
        var lines = ["Photos tried: \(tried)"]
        if tried > 0 { lines.append(String(format: "Seconds a photo: %.2f", seconds / Double(tried))) }
        guard marked > 0 else {
            lines.append("None marked yet")
            return lines
        }
        lines.append("Marked by you: \(marked)")
        if onList > 0 {
            lines.append("First answer right: \(EyeTestTally.share(firstRight, of: onList))")
            lines.append("Right answer among the three: \(EyeTestTally.share(inThree, of: onList))")
        }
        lines.append("Named outright and right: \(EyeTestTally.share(namedRight, of: named))")
        if offList > 0 {
            lines.append("Not on its list, yet named anyway: \(EyeTestTally.share(offListNamed, of: offList))")
        }
        return lines
    }
}
