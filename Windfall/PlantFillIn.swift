//
//  PlantFillIn.swift
//  Windfall
//
//  Filling in what a plant's record does not yet say.
//
//  Why this exists. William, 14 November 2026: "when you add a new plant
//  to the app or tell Eira you've planted a new plant, it will run a
//  search and fill in as much information about the plant as it can
//  find and you just have to approve each thing. I'd also like a smart
//  way to fill in the gaps."
//
//  The library he loaded has 437 plants and most of their boxes are
//  empty: 19 have a hardiness, 24 have pruning advice and 14 have pests.
//  So the same machinery serves both halves of what he asked: a plant
//  added today, and a plant that has been in the library all along.
//
//  How it works, in four steps:
//
//  1. PlantGaps works out which boxes are empty and which of those
//     matter to this plant. An apple tree is not asked when to sow it.
//  2. Suggestions are gathered from three places, best first:
//       a. Your own library. If the other rhubarbs all say "Hardy
//          perennial", a new rhubarb very likely is one too. No
//          internet is needed for this.
//       b. The RHS. Its growing guide is found from the plant's name
//          (EiraSources.swift). The guide gives the months to sow,
//          plant and harvest, and links to the RHS's own page for the
//          plant, which holds height, spread, hardiness, soil and more.
//          Fixed rules read the facts out of those pages (PageFacts).
//       c. Worked out by rule from the plant's family: every member of
//          the carrot family is an umbellifer.
//  3. Each suggestion says where it came from and shows the words it
//     was read from, so a wrong one is plain to see.
//  4. Nothing is written until Keep is pressed on that one suggestion.
//     A kept suggestion goes into its box with a KeptFact beside it
//     (KeptFacts.swift), so the plant's page shows "RHS, kept Nov 2026"
//     and it is offered for checking again after two years.
//
//  The facts are read by fixed rules and not by the AI model. A rule
//  reads the same page the same way every time and cannot invent a
//  figure that is not on the page. What rules cannot do is read loose
//  prose, so some boxes stay empty. For those the screen offers to ask
//  Eira, to read a web address you paste, or to type the fact in.
//
//  Nothing here draws anything. The screens are in
//  PlantFillInViews.swift. So all of this is covered by the logic tests.
//

import Foundation
import SwiftData

// MARK: - One suggestion

/// One fact offered for one empty box of a plant's record.
///
/// A `struct` is a simple bundle of values. `Identifiable` lets SwiftUI
/// tell one from another in a list, and `Equatable` lets two be compared
/// with `==`, which the logic tests use.
struct FillSuggestion: Identifiable, Equatable {
    /// The box, by its key in PlantFacts.swift: "hardiness".
    let key: String
    /// What the box would hold, written as the record writes it.
    var value: String
    /// "RHS", "Your other rhubarbs" or "Worked out".
    let sourceName: String
    /// The page it was read from, if it came from one.
    let address: String?
    let trust: SourceTrust
    /// The words it was read from, or the reason for it. Shown under
    /// the suggestion so it can be judged before it is kept.
    let evidence: String
    /// Set when another source says something different for the same
    /// box: "Your other rhubarbs say H6."
    var otherView: String?

    var id: String { key }

    /// The box's name as a plant's page shows it: "Hardiness".
    var label: String { PlantFacts.named(key)?.label ?? key }

    /// True for a yes-or-no box, which is shown as a tick and not as
    /// words to change.
    var isYesNo: Bool { PlantFacts.named(key)?.kind == .yesNo }
}

// MARK: - Which boxes are empty, and which matter

enum PlantGaps {

    /// One empty box worth filling.
    struct Gap: Identifiable, Equatable {
        let key: String
        let label: String
        /// 3 for a box the app works from, 2 for one that is good to
        /// have, 1 for the rest.
        let weight: Int
        /// What the app does with the box, where it does something.
        let why: String?

        var id: String { key }
    }

    /// The boxes worth filling, most useful first, with what the app
    /// does with each. A box not listed here is never counted as a gap:
    /// a variety name, a rootstock and a pollination group only apply
    /// to some plants, and Notes and History are for you to write.
    ///
    /// The reasons name only what the app does today. Where a box is
    /// simply shown on the plant's page there is no reason given.
    private static let wanted: [(key: String, weight: Int, why: String?)] = [
        ("latinName", 3, "Look-ups go by the Latin name"),
        ("group", 3, "Crop rotation and the Plants filters use it"),
        ("sowIndoorsMonthsText", 3, "The Year page and the sowing reminders read it"),
        ("sowOutdoorsMonthsText", 3, "The Year page and the sowing reminders read it"),
        ("plantOutMonthsText", 3, "The Year page reads it"),
        ("harvestMonthsText", 3, "The Year page reads it"),
        ("floweringMonthsText", 3, "The Year page reads it"),
        ("spacingM", 3, nil),
        ("sunShade", 3, nil),
        ("hardiness", 2, nil),
        ("classification", 2, nil),
        ("maxHeightM", 2, nil),
        ("spreadM", 2, nil),
        ("knownPests", 2, "The pests card and companion planting read it"),
        ("knownDiseases", 2, nil),
        ("pruning", 2, "Eira answers pruning questions from it"),
        ("propagation", 2, "Eira answers dividing questions from it"),
        ("sowingDepthMM", 2, nil),
        ("sowToCropText", 2, nil),
        ("germinationDaysText", 2, nil),
        ("preferredSoilConditions", 2, "Eira answers soil questions from it"),
        ("soilPH", 2, nil),
        ("toxicityCautions", 2, nil),
        ("foliagePattern", 1, nil),
        ("timeToUltimateHeight", 1, nil),
        ("habits", 1, nil)
    ]

    /// The boxes that are about raising a plant from seed.
    private static let seedKeys: Set<String> = ["sowIndoorsMonthsText", "sowOutdoorsMonthsText", "plantOutMonthsText",
                                                "sowingDepthMM", "sowToCropText", "germinationDaysText"]

    /// Whether a box applies to a plant at all.
    ///
    /// An apple tree has no sowing months, and a lettuce is not pruned.
    /// Counting those as gaps would make every tree look half empty, and
    /// the list of gaps would nag about things that can never be filled.
    static func applies(_ key: String, to plant: Plant) -> Bool {
        let kind = PlantKind.of(group: plant.group)
        // Everything the record says about what sort of plant it is, in
        // small letters, to look for words in.
        let sort = [plant.typeLabel, plant.plantType, plant.layer, plant.classification]
            .compactMap { $0 }.joined(separator: " ").lowercased()
        let isWoody = ["tree", "shrub", "bush", "cane", "vine", "climber"].contains { sort.contains($0) }

        if seedKeys.contains(key) {
            // Something already filled in about sowing says it is sown.
            let hasSowingFacts = seedKeys.contains { seedKey in
                guard let box = PlantFacts.named(seedKey) else { return false }
                return !PlantFacts.value(of: box, in: plant).isEmpty
            }
            let isSown = sort.contains("seed") || sort.contains("annual") || sort.contains("biennial")
            return hasSowingFacts || isSown || kind == .vegetables || kind == .greenManure
                || !(plant.seedPackets ?? []).isEmpty
        }
        switch key {
        case "harvestMonthsText":
            return kind == .fruit || kind == .vegetables || kind == .herbs
        case "pruning":
            return isWoody || kind == .fruit
        default:
            return true
        }
    }

    /// True when a box holds nothing, or only the spreadsheet's "*" or
    /// "?" that stand for nothing.
    static func isEmpty(_ key: String, in plant: Plant) -> Bool {
        guard let box = PlantFacts.named(key) else { return false }
        let held = PlantFacts.value(of: box, in: plant)
        return held.isEmpty || PlantFacts.isPlaceholder(held)
    }

    /// The plant's gaps: the boxes worth filling that apply to it and
    /// are empty. Heaviest first, and in the list's order within that.
    static func gaps(in plant: Plant) -> [Gap] {
        let found = wanted.compactMap { entry -> Gap? in
            guard let box = PlantFacts.named(entry.key), applies(entry.key, to: plant),
                  isEmpty(entry.key, in: plant) else { return nil }
            return Gap(key: entry.key, label: box.label, weight: entry.weight, why: entry.why)
        }
        // `sorted` here is stable for equal weights only by luck, so the
        // list's own order is used as the tie-break.
        let order = Dictionary(uniqueKeysWithValues: wanted.enumerated().map { ($1.key, $0) })
        return found.sorted {
            $0.weight != $1.weight ? $0.weight > $1.weight : (order[$0.key] ?? 0) < (order[$1.key] ?? 0)
        }
    }

    /// How full a plant's record is: of the boxes that apply to it, how
    /// many are filled. For "14 of 22 filled in".
    static func fullness(of plant: Plant) -> (filled: Int, wanted: Int) {
        let applying = wanted.filter { applies($0.key, to: plant) }
        let empty = applying.filter { isEmpty($0.key, in: plant) }
        return (applying.count - empty.count, applying.count)
    }

    /// A number for how much a plant would gain from being filled in:
    /// the weights of its gaps, added up.
    static func toGain(for plant: Plant) -> Int {
        gaps(in: plant).reduce(0) { $0 + $1.weight }
    }

    /// The plants with most to gain, most first: for a list of where to
    /// start. Plants you are growing come before ones on the wish list,
    /// because their sowing and harvest months are wanted this year.
    /// A plant with no heavy gap is left out.
    static func mostToGain(among plants: [Plant], limit: Int = 30) -> [Plant] {
        let withHeavyGap = plants.filter { plant in gaps(in: plant).contains { $0.weight == 3 } }
        let ordered = withHeavyGap.sorted { first, second in
            let firstGrowing = first.status == .growing, secondGrowing = second.status == .growing
            if firstGrowing != secondGrowing { return firstGrowing }
            let firstGain = toGain(for: first), secondGain = toGain(for: second)
            return firstGain != secondGain ? firstGain > secondGain : first.displayName < second.displayName
        }
        return Array(ordered.prefix(limit))
    }

    /// A question to put to Eira for a gap that rules cannot read off a
    /// page, or nil if the gap is not one she has a lookup for.
    ///
    /// Each question is worded so that her care rules (CareTopic in
    /// KeptFacts.swift) send it to the right lookup, and the answer
    /// comes back with a card that offers to keep it in this same box.
    static func questionForEira(about key: String, plant: String) -> String? {
        let name = KeptFacts.withoutBrackets(plant).lowercased()
        switch key {
        case "pruning": return "How and when should I prune \(name)?"
        case "propagation": return "How do I divide or propagate \(name)?"
        case "knownPests": return "Which pests trouble \(name)?"
        case "knownDiseases": return "Which diseases does \(name) get?"
        case "sowOutdoorsMonthsText": return "When do I sow \(name) outdoors?"
        case "sowIndoorsMonthsText": return "When do I sow \(name) indoors?"
        case "plantOutMonthsText": return "When do I plant out \(name)?"
        case "harvestMonthsText": return "When do I harvest \(name)?"
        case "sunShade": return "Does \(name) want sun or shade?"
        case "preferredSoilConditions": return "What soil does \(name) like?"
        default: return nil
        }
    }
}

// MARK: - From your own library

enum LibraryFill {

    /// The boxes that hold the same for every variety of a plant. One
    /// other variety saying so is enough to suggest it.
    ///
    /// Left out: anything that differs between an early and a late
    /// variety or a tall and a dwarf one, such as the months, heights
    /// and spacing. Those are only suggested when at least two other
    /// varieties have the box filled and every one of them agrees.
    static let sameForEveryVariety: Set<String> = [
        "latinName", "group", "classification", "plantType", "foliagePattern", "layer",
        "isPollinator", "isRepeller", "isUmbelliferous", "isNitrogenFixer", "isDynamicAccumulator",
        "sunShade", "hardiness", "soilPH", "preferredSoilConditions", "knownPests", "knownDiseases",
        "propagation", "toxicityCautions", "partnerPlants", "antagonisticPlants", "pollinators",
        "sowingDepthMM", "germinationDaysText", "sowingTemperatureC", "sowingPreference"
    ]

    /// The boxes never copied from another variety: they are what makes
    /// one variety different from the next, or they are yours to write.
    static let neverCopied: Set<String> = ["commonName", "variety", "typeLabel", "rootstock", "pollinationGroup",
                                           "ploidy", "appearance", "history", "notes", "medicinalUses",
                                           "isGroundCover", "needsPropagator"]

    /// The other records of the same plant: the same common name, with
    /// anything in brackets ignored so that "Apple (Cider)" counts as an
    /// apple, or the same Latin name.
    static func siblings(of plant: Plant, among plants: [Plant]) -> [Plant] {
        let name = KeptFacts.withoutBrackets(plant.commonName).lowercased()
        let latin = (plant.latinName ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        return plants.filter { other in
            guard other.id != plant.id else { return false }
            if !name.isEmpty, KeptFacts.withoutBrackets(other.commonName).lowercased() == name { return true }
            let otherLatin = (other.latinName ?? "").trimmingCharacters(in: .whitespaces).lowercased()
            return !latin.isEmpty && otherLatin == latin
        }
    }

    /// What the plant's siblings can tell it: one suggestion for each
    /// empty box that they fill and agree on.
    static func suggestions(for plant: Plant, among plants: [Plant]) -> [FillSuggestion] {
        let others = siblings(of: plant, among: plants)
        guard !others.isEmpty else { return [] }
        let family = KeptFacts.withoutBrackets(plant.commonName).lowercased()
        let sourceName = "Your other \(family) records"

        var made: [FillSuggestion] = []
        for box in PlantFacts.all where !neverCopied.contains(box.key) {
            guard PlantGaps.isEmpty(box.key, in: plant) else { continue }
            // What each sibling holds in this box, leaving out the
            // empty ones and the "*" and "?" markers.
            let held = others.map { PlantFacts.value(of: box, in: $0) }
                .filter { !$0.isEmpty && !PlantFacts.isPlaceholder($0) }
            guard !held.isEmpty else { continue }

            // Count how many say each thing, ignoring capitals.
            var counts: [String: Int] = [:]
            var spelling: [String: String] = [:]
            for text in held {
                counts[text.lowercased(), default: 0] += 1
                if spelling[text.lowercased()] == nil { spelling[text.lowercased()] = text }
            }
            // The commonest, and for a tie the one that sorts first, so
            // that the answer is the same every time.
            guard let top = counts.sorted(by: { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }).first,
                  let value = spelling[top.key] else { continue }

            if box.kind == .yesNo {
                // A yes only if most of the others say yes.
                guard top.value * 2 > others.count else { continue }
            } else if !sameForEveryVariety.contains(box.key) {
                // A box that can differ by variety: two or more must
                // have it, and all must agree.
                guard held.count >= 2, counts.count == 1 else { continue }
            }
            let evidence = others.count == 1
                ? "\(others[0].displayName) says this."
                : "\(top.value) of your \(others.count) other \(family) records say this."
            var suggestion = FillSuggestion(key: box.key, value: value, sourceName: sourceName, address: nil,
                                            trust: .ownRecords, evidence: evidence)
            if counts.count > 1 {
                let rest = counts.keys.filter { $0 != top.key }.sorted().compactMap { spelling[$0] }
                suggestion.otherView = "Others say: " + rest.joined(separator: "; ")
            }
            made.append(suggestion)
        }
        return made
    }
}

// MARK: - Small helpers for reading text by pattern

/// A "regular expression" is a pattern for finding text: `\d+` means
/// one or more digits, `(cm|mm)` means either of those, and anything in
/// round brackets is handed back as a "group". These two helpers wrap
/// Apple's own pattern reader so the rules below stay short.
enum Pattern {

    /// The first place a pattern fits in a text: the whole match and
    /// then each group. Nil if it fits nowhere. A group that took no
    /// part in the match comes back as empty text.
    static func first(_ pattern: String, in text: String, ignoringCase: Bool = true) -> [String]? {
        all(pattern, in: text, ignoringCase: ignoringCase).first
    }

    /// Every place a pattern fits, in order.
    static func all(_ pattern: String, in text: String, ignoringCase: Bool = true) -> [[String]] {
        let options: NSRegularExpression.Options = ignoringCase ? [.caseInsensitive] : []
        guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let whole = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: whole).map { fitted in
            (0..<fitted.numberOfRanges).map { index in
                guard let range = Range(fitted.range(at: index), in: text) else { return "" }
                return String(text[range])
            }
        }
    }
}

// MARK: - The parts of an RHS page that plain text loses

/// Reads three things from an RHS page as the site sent it, tags and
/// all: the month-by-month calendar, the links to plant pages and the
/// table of seasons. In plain text the calendar is twelve letters with
/// nothing to say which are coloured in.
enum RHSPage {

    private static let monthNames = ["january", "february", "march", "april", "may", "june", "july", "august",
                                     "september", "october", "november", "december"]

    /// The calendar on a growing guide: for "sow", "plant" and
    /// "harvest", the months coloured in, 1 for January.
    ///
    /// On the page each row is a block marked `calendar-section` with
    /// its name in a heading, and each coloured month is marked
    /// `calendar-month--active` and carries the month's name as its
    /// title. Seen on the RHS's pages on 14 November 2026. If the RHS
    /// changes its page this finds nothing, which is safe: no months
    /// are suggested, and nothing wrong is.
    static func calendar(inHTML html: String) -> [String: [Int]] {
        var found: [String: [Int]] = [:]
        // Cut the page at each row's opening, so each piece holds one row.
        let pieces = html.components(separatedBy: "class=\"calendar-section\"").dropFirst()
        for piece in pieces {
            guard let title = Pattern.first("calendar-section__title\"[^>]*>\\s*([A-Za-z ]+?)\\s*<", in: piece)?[1] else { continue }
            let active = Pattern.all("calendar-month calendar-month--active\"\\s+title=\"([A-Za-z]+)\"", in: piece)
            let months = active.compactMap { match in monthNames.firstIndex(of: match[1].lowercased()).map { $0 + 1 } }
            if !months.isEmpty { found[title.lowercased()] = months.sorted() }
        }
        return found
    }

    /// The links on a page to the RHS's own pages for single plants,
    /// which all have the shape /plants/<number>/<name>/details. Each
    /// once, in the page's order.
    static func plantLinks(inHTML html: String) -> [String] {
        var found: [String] = []
        for match in Pattern.all("href=\"(/plants/\\d+/[^\"/]+/details)\"", in: html) where !found.contains(match[1]) {
            found.append(match[1])
        }
        return found
    }

    /// A name as it appears in one of those links: small letters, with
    /// hyphens for spaces. "Rheum × hybridum" becomes "rheum-x-hybridum".
    static func slug(_ name: String) -> String {
        let plain = name.lowercased().replacingOccurrences(of: "\u{00D7}", with: "x")
        return EiraSafety.tidied(plain).trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "-")
    }

    /// The name part of a link, tidied. The RHS wraps a Latin name in
    /// "i-" and "-i" (its mark for italics) and writes the cross of a
    /// hybrid as "times;", so "i-lavandula-i-times;-i-intermedia-i"
    /// becomes "lavandula-x-intermedia".
    static func linkName(_ link: String) -> String {
        let parts = link.split(separator: "/").map(String.init)
        guard parts.count >= 3 else { return "" }
        let words = parts[2].replacingOccurrences(of: "times;", with: "x").split(separator: "-").map(String.init)
        return words.filter { $0 != "i" && !$0.isEmpty }.joined(separator: "-")
    }

    /// Which of a guide's links is the page for the plant's species, and
    /// which, if any, is the page for its variety.
    ///
    ///   latin "Rheum × hybridum"   /plants/113552/rheum-x-hybridum/details
    ///   variety "Victoria"         /plants/70672/victoria/details
    ///
    /// The species link must be the Latin name and nothing else. The
    /// variety link must be the variety's name, with or without "agm"
    /// after it (AGM is the RHS's award, tacked on to the name), or the
    /// plant's genus and then the variety's name, as in
    /// "rheum-hybridum-timperley-early". A variety called "Early" does
    /// not find "timperley-early".
    static func links(forLatin latin: String?, variety: String?, among links: [String]) -> (species: String?, variety: String?) {
        var species: String?
        var ofVariety: String?
        let latinSlug = latin.map(slug) ?? ""
        let varietySlug = variety.map(slug) ?? ""
        for link in links {
            let name = linkName(link)
            if species == nil, !latinSlug.isEmpty, name == latinSlug { species = link }
            if ofVariety == nil, varietySlug.count >= 3 {
                let bare = name.hasSuffix("-agm") ? String(name.dropLast(4)) : name
                let genus = latinSlug.split(separator: "-").first.map(String.init) ?? ""
                let afterGenus = !genus.isEmpty && bare.hasPrefix(genus + "-") && bare.hasSuffix("-" + varietySlug)
                if bare == varietySlug || afterGenus { ofVariety = link }
            }
        }
        return (species, ofVariety)
    }

    /// The table of seasons on a plant's own page: for "flower" and
    /// "fruit", the months of the seasons that are marked.
    ///
    /// The table has a row for each season and a column for stem,
    /// flower, foliage and fruit. A cell with a colour in it holds a
    /// small drawing (an `svg`), and an empty cell holds nothing. A
    /// season is three months, so this is coarser than a calendar:
    /// "summer" comes back as June, July and August.
    static func seasons(inHTML html: String) -> [String: [Int]] {
        let seasonMonths = ["spring": [3, 4, 5], "summer": [6, 7, 8], "autumn": [9, 10, 11], "winter": [12, 1, 2]]
        var marked: [String: Set<Int>] = [:]
        let rows = Pattern.all("<th scope=\"row\"[^>]*>\\s*(Spring|Summer|Autumn|Winter)\\s*</th>([\\s\\S]*?)</tr>", in: html)
        for row in rows {
            guard let months = seasonMonths[row[1].lowercased()] else { continue }
            for column in ["Flower", "Fruit"] {
                guard let cell = Pattern.first("<td data-label=\"\(column)\"[^>]*>([\\s\\S]*?)</td>", in: row[2])?[1],
                      cell.contains("<svg") else { continue }
                marked[column.lowercased(), default: []].formUnion(months)
            }
        }
        return marked.mapValues { $0.sorted() }
    }
}

// MARK: - Reading facts off a page by rule

enum PageFacts {

    /// One fact a rule read from a page.
    struct Found: Equatable {
        /// The box it belongs in, by its key in PlantFacts.swift. One
        /// key is not a box: "family", the plant's botanical family,
        /// which the record has no box for. It is used to work other
        /// things out (FamilyRules).
        let key: String
        let value: String
        /// The words on the page the rule read it from.
        let evidence: String
    }

    static let familyKey = "family"

    /// Every fact the rules can read from a page.
    ///
    /// - `text`: the page as plain text, a line for each paragraph.
    /// - `html`: the page as the site sent it, for the calendar and the
    ///   table of seasons. Empty text simply finds neither.
    /// - `plantName`: the plant's common name, which some rules look
    ///   for so that they read the right sentence.
    ///
    /// Each rule gives at most one fact for a box. A rule that is not
    /// sure gives nothing: an empty box is better than a wrong one.
    static func facts(in text: String, html: String = "", plantName: String) -> [Found] {
        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var found: [Found] = []
        func add(_ key: String, _ value: String?, _ evidence: String) {
            guard let value, !value.isEmpty, !found.contains(where: { $0.key == key }) else { return }
            found.append(Found(key: key, value: value, evidence: shortened(evidence, to: 220)))
        }

        // 1. The facts an RHS plant page sets out under headings of
        //    their own. These come first: a labelled fact beats one
        //    picked out of a sentence.
        labelled(lines, add: add)

        // 2. The calendar and the seasons.
        calendarFacts(text: text, html: html, add: add)

        // 3. Facts picked out of sentences.
        let sentences = lines.flatMap(sentencesOf)
        if let latin = latinName(in: sentences, plantName: plantName) { add("latinName", latin.name, latin.sentence) }
        if let depth = sowingDepth(in: sentences) { add("sowingDepthMM", depth.value, depth.sentence) }
        if let spacing = spacing(in: sentences) { add("spacingM", spacing.value, spacing.sentence) }
        if let crop = sowToCrop(in: sentences) { add("sowToCropText", crop.value, crop.sentence) }
        if let sunFact = sunOrShade(in: sentences) { add("sunShade", sunFact.value, sunFact.sentence) }
        if let lifeCycle = classification(in: sentences, plantName: plantName) {
            add("classification", lifeCycle.value, lifeCycle.sentence)
        }
        if let foliage = foliage(in: sentences) { add("foliagePattern", foliage.value, foliage.sentence) }

        // 4. The list of common problems at the foot of a growing guide.
        let problems = commonProblems(in: lines)
        if !problems.pests.isEmpty {
            add("knownPests", problems.pests.joined(separator: "; "), "Listed under Common Problems: " + problems.pests.joined(separator: ", "))
        }
        if !problems.diseases.isEmpty {
            add("knownDiseases", problems.diseases.joined(separator: "; "), "Listed under Common Problems: " + problems.diseases.joined(separator: ", "))
        }
        return found
    }

    // MARK: Labelled facts

    /// The headings an RHS plant page puts its facts under. A value
    /// stops where the next of these begins.
    private static let labels = ["position", "soil types", "max height", "max spread", "time to maturity", "size",
                                 "growing conditions", "moisture", "ph", "aspect", "exposure", "hardiness",
                                 "colour & scent", "botanical details", "family", "foliage", "habit", "genus",
                                 "potentially harmful", "name status", "how to grow", "cultivation", "propagation",
                                 "suggested planting locations and garden types", "pruning", "pests", "diseases"]

    /// What follows a heading: the rest of its own line ("Foliage
    /// Deciduous"), or else the next line ("Max Height", then "1-1.5
    /// metres"). Nil if the heading is not on the page, or if what
    /// follows is another heading.
    private static func value(after label: String, in lines: [String]) -> String? {
        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()
            if lower == label {
                guard index + 1 < lines.count else { return nil }
                let next = lines[index + 1]
                // Another heading straight after means this one is empty.
                if labels.contains(next.lowercased()) { continue }
                return next
            }
            if lower.hasPrefix(label + " ") {
                return String(line.dropFirst(label.count + 1)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private static func labelled(_ lines: [String], add: (String, String?, String) -> Void) {
        // These headings only mean what they say on a plant's own page,
        // which always has a "Botanical Details" section. On any other
        // page a line that happens to read "Position" proves nothing.
        guard lines.contains(where: { $0.lowercased() == "botanical details" }) else { return }

        // Sun or shade: one or more of three phrases after "Position".
        if let index = lines.firstIndex(where: { $0.lowercased() == "position" }) {
            var said: [String] = []
            for line in lines[(index + 1)...].prefix(3) {
                let phrases = ["full sun", "partial shade", "full shade"].filter { line.lowercased().contains($0) }
                if phrases.isEmpty { break }
                for phrase in phrases where !said.contains(phrase) { said.append(phrase) }
            }
            if !said.isEmpty {
                let joined = said.joined(separator: " or ")
                add("sunShade", joined.prefix(1).uppercased() + joined.dropFirst(), "Position: " + said.joined(separator: ", "))
            }
        }
        if let height = value(after: "max height", in: lines) { add("maxHeightM", metres(from: height), "Max height: \(height)") }
        if let spread = value(after: "max spread", in: lines) { add("spreadM", metres(from: spread), "Max spread: \(spread)") }
        if let time = value(after: "time to maturity", in: lines), time.contains(where: \.isNumber) {
            add("timeToUltimateHeight", plainDashes(time), "Time to maturity: \(time)")
        }

        // Soil: the types and how wet, joined, as the library writes it.
        var soilWords: [String] = []
        if let types = value(after: "soil types", in: lines) { soilWords.append(types) }
        if let moisture = value(after: "moisture", in: lines) { soilWords.append(plainDashes(moisture).lowercased()) }
        if !soilWords.isEmpty { add("preferredSoilConditions", soilWords.joined(separator: "; "), "Soil: " + soilWords.joined(separator: ". Moisture: ")) }

        // "Acid or Alkaline or Neutral" is written "Acid, Alkaline,
        // Neutral", which is how the library already writes it.
        if let acidity = value(after: "ph", in: lines) {
            add("soilPH", acidity.replacingOccurrences(of: " or ", with: ", "), "pH: \(acidity)")
        }

        // Hardiness. The page prints the whole scale as a key, each
        // line ending in a colon ("H5:"), and then the plant's own
        // rating on a line by itself ("H5").
        if let index = lines.firstIndex(where: { $0.lowercased() == "hardiness" }) {
            let rating = lines[(index + 1)...].prefix(40).first { Pattern.first("^H[1-7][abc]?$", in: $0) != nil }
            if let rating {
                add("hardiness", "H" + rating.dropFirst().lowercased(), "Hardiness: \(rating), on the RHS's scale of H1 to H7")
            }
        }

        if let family = value(after: "family", in: lines), Pattern.first("^[A-Z][a-z]+aceae$", in: family, ignoringCase: false) != nil {
            add(familyKey, family, "Family: \(family)")
        }
        if let foliage = value(after: "foliage", in: lines), ["deciduous", "evergreen", "semi evergreen"].contains(foliage.lowercased()) {
            add("foliagePattern", foliage, "Foliage: \(foliage)")
        }
        if let habit = value(after: "habit", in: lines), habit.count < 40 { add("habits", habit, "Habit: \(habit)") }
        if let harm = value(after: "potentially harmful", in: lines) { add("toxicityCautions", shortened(harm, to: 240), harm) }

        // The RHS's "Plants for Pollinators" mark. It is a line of its
        // own on the page of a plant that carries it, and is absent
        // from the page of one that does not.
        //
        // The page also explains every mark in a pop-up key, under
        // "For Biodiversity". The plant's own mark sits under "For
        // Bio-Diversity", with a hyphen, and only that one counts. (As
        // seen on 14 November 2026. If the RHS changes the wording the
        // rule finds nothing, and nothing wrong is suggested.)
        let hasMark = lines.indices.dropFirst().contains { index in
            lines[index].lowercased() == "plants for pollinators" && lines[index - 1].lowercased() == "for bio-diversity"
        }
        if hasMark {
            add("isPollinator", PlantFacts.yes, "The page carries the RHS's Plants for Pollinators mark.")
        }
        // "pruning group 10; deadhead after flowering" names the RHS's
        // pruning group, which has a box of its own.
        if let words = value(after: "pruning", in: lines), let group = Pattern.first("pruning group (\\d+[a-z]?)", in: words)?[1] {
            add("pruningGroup", group, words)
        }

        // The four paragraphs under "How to Grow". Each is the RHS's
        // own wording, cut to a sentence or two, for you to shorten.
        for (label, key) in [("propagation", "propagation"), ("pruning", "pruning")] {
            if let words = value(after: label, in: lines), words.count > 15 { add(key, shortened(words, to: 260), words) }
        }
        for (label, key) in [("pests", "knownPests"), ("diseases", "knownDiseases")] {
            guard let words = value(after: label, in: lines), words.count > 5 else { continue }
            // "May be susceptible to slugs" is kept as "slugs".
            var list = words
            for opening in ["may be susceptible to ", "can be susceptible to ", "may be affected by ", "may be attacked by "]
            where list.lowercased().hasPrefix(opening) {
                list = String(list.dropFirst(opening.count))
            }
            add(key, shortened(list, to: 200), words)
        }
    }

    /// A height or spread in metres, as the record writes it.
    ///
    ///   "1-1.5 metres"           1-1.5
    ///   "0.1–0.5 metres"         0.1-0.5
    ///   "Up to 10 cm"            up to 0.1
    ///   "Higher than 12 metres"  over 12
    static func metres(from text: String) -> String? {
        let lower = text.lowercased()
        let figures = Pattern.all("\\d+(?:\\.\\d+)?", in: lower).compactMap { Double($0[0]) }
        guard !figures.isEmpty else { return nil }
        // Centimetres only when the page says so and does not say metres.
        let isCentimetres = lower.contains("cm") || (lower.contains("centimetre") && !lower.contains(" metre"))
        let inMetres = figures.prefix(2).map { number(isCentimetres ? $0 / 100 : $0) }
        let joined = inMetres.joined(separator: "-")
        if lower.contains("higher than") || lower.contains("wider than") || lower.contains("more than") { return "over " + joined }
        if lower.contains("up to") { return "up to " + joined }
        return joined
    }

    /// A number without a needless ".0": 0.9, 1.5, 12.
    static func number(_ value: Double) -> String {
        let rounded = (value * 1000).rounded() / 1000
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }

    /// Long dashes turned into the plain hyphen the record uses.
    static func plainDashes(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{2013}", with: "-").replacingOccurrences(of: "\u{2014}", with: "-")
    }

    // MARK: The calendar and the seasons

    private static func calendarFacts(text: String, html: String, add: (String, String?, String) -> Void) {
        let calendar = RHSPage.calendar(inHTML: html)
        func say(_ row: String, _ months: [Int]) -> String {
            "The RHS's month-by-month calendar, \(row): \(MonthParser.describe(months))"
        }
        if let months = calendar["sow"] {
            // The calendar has one row for sowing and does not say
            // where. The page's own words decide.
            let key = sowsIndoors(text) ? "sowIndoorsMonthsText" : "sowOutdoorsMonthsText"
            add(key, PlantFacts.monthText(months),
                say("Sow", months) + ". The calendar does not say indoors or outdoors: the page's wording decided, so check it.")
        }
        if let months = calendar["plant"] { add("plantOutMonthsText", PlantFacts.monthText(months), say("Plant", months)) }
        if let months = calendar["harvest"] { add("harvestMonthsText", PlantFacts.monthText(months), say("Harvest", months)) }
        if let months = calendar["flower"] ?? calendar["flowering"] {
            add("floweringMonthsText", PlantFacts.monthText(months), say("Flower", months))
        }

        let seasons = RHSPage.seasons(inHTML: html)
        if let months = seasons["flower"] {
            add("floweringMonthsText", PlantFacts.monthText(months),
                "The RHS marks flowers in these seasons, not months, so this is to the nearest three months: \(MonthParser.describe(months))")
        }
        if let months = seasons["fruit"] {
            add("fruitingMonthsText", PlantFacts.monthText(months),
                "The RHS marks fruit in these seasons, not months, so this is to the nearest three months: \(MonthParser.describe(months))")
        }
    }

    /// Whether a growing guide speaks of sowing indoors more than of
    /// sowing outdoors. Each phrase is counted once for each time it
    /// appears, and indoors must be clearly ahead: a tie, or nothing
    /// either way, is taken as outdoors.
    static func sowsIndoors(_ text: String) -> Bool {
        let lower = text.lowercased()
        func count(_ phrases: [String]) -> Int {
            phrases.reduce(0) { $0 + lower.components(separatedBy: $1).count - 1 }
        }
        let indoors = count(["sow indoors", "sown indoors", "sowing indoors", "sow under cover", "sown under cover",
                             "sow in a greenhouse", "on a windowsill", "in a propagator", "sow into modules",
                             "sow in modules", "sow in pots", "sow seeds indoors"])
        let outdoors = count(["sow outdoors", "sown outdoors", "sowing outdoors", "sown directly", "sow directly",
                              "sow direct", "direct sow", "sow outside", "sown outside", "shallow drill"])
        return indoors > outdoors
    }

    // MARK: Facts in sentences

    /// A paragraph cut into its sentences, at a full stop, question
    /// mark or exclamation mark that is followed by a space and a
    /// capital letter. "2.5cm" and "e.g." are not cut.
    static func sentencesOf(_ paragraph: String) -> [String] {
        let marked = paragraph.replacingOccurrences(of: "([.!?])\\s+(?=[A-Z\u{2018}'\"])", with: "$1\n", options: .regularExpression)
        return marked.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// The Latin name, where a sentence opens with the plant's name and
    /// gives the Latin straight after it in brackets:
    ///
    ///   "Carrots (Daucus carota) like sun and light, well-drained soil"
    ///   "Rhubarb (Rheum × hybridum) is a hardy perennial"
    ///
    /// The plant's name must open the sentence. "French lavender
    /// (Lavandula stoechas)" is about one kind of lavender, and is not
    /// taken as the Latin name for lavender.
    static func latinName(in sentences: [String], plantName: String) -> (name: String, sentence: String)? {
        let plain = EiraSafety.tidied(KeptFacts.withoutBrackets(plantName)).trimmingCharacters(in: .whitespaces)
        guard !plain.isEmpty else { return nil }
        // A genus with a capital, an optional cross, then the species.
        let latin = "\\(([A-Z][a-z]{2,}(?: [\u{00D7}x])? [a-z]{3,}(?:-[a-z]+)?)\\)"
        for sentence in sentences {
            for spelling in KeptFacts.spellings(of: plain) {
                let opening = "^" + NSRegularExpression.escapedPattern(for: spelling) + " " + latin
                // The name may be in any case. The Latin must keep its
                // capital, so the two are matched in two steps.
                guard Pattern.first(opening, in: sentence) != nil,
                      let name = Pattern.first(latin, in: sentence, ignoringCase: false)?[1] else { continue }
                return (name, sentence)
            }
        }
        return nil
    }

    /// A length such as "2.5cm" or "10mm" at one place in a sentence.
    private static let length = "(\\d+(?:\\.\\d+)?)(?:\\s*[\u{2013}-]\\s*(\\d+(?:\\.\\d+)?))?\\s*(cm|mm|m)\\b"
    /// The imperial figure the RHS gives in brackets after a metric
    /// one, "(1in)", which the rules step over.
    private static let imperial = "(?:\\s*\\([^)]*\\))?"

    /// How deep to sow, in millimetres: "Sow seed 2.5cm (1in) deep".
    /// The sentence must be about sowing, so that a mulch "7cm deep" or
    /// a pot "50cm deep" is never taken for it.
    static func sowingDepth(in sentences: [String]) -> (value: String, sentence: String)? {
        for sentence in sentences {
            let lower = sentence.lowercased()
            guard lower.contains("sow") || lower.contains("seed") || lower.contains("drill") else { continue }
            guard !lower.contains("mulch"), !lower.contains("container"), !lower.contains(" pot ") else { continue }
            guard let match = Pattern.first(length + imperial + "\\s*deep", in: sentence), let figure = Double(match[1]) else { continue }
            let millimetres = match[3].lowercased() == "mm" ? figure : match[3].lowercased() == "cm" ? figure * 10 : figure * 1000
            return (number(millimetres), sentence)
        }
        return nil
    }

    /// How far apart the plants stand, in metres.
    ///
    /// A page may give several distances: between rows, between
    /// seedlings after thinning, and between full-grown plants. The
    /// rule takes them in this order of preference:
    ///
    ///   1. a sentence that says to space the plants ("Space plants up
    ///      to 90cm apart")
    ///   2. a sentence about thinning ("Thin seedlings to 5cm apart")
    ///   3. any other, so long as it is not about rows
    ///
    /// A range is kept as a range: "75–90cm" is "0.75-0.9".
    static func spacing(in sentences: [String]) -> (value: String, sentence: String)? {
        var best: (rank: Int, value: String, sentence: String)?
        for sentence in sentences {
            guard let match = Pattern.first(length + imperial + "\\s*apart", in: sentence), let low = Double(match[1]) else { continue }
            let lower = sentence.lowercased()
            let rank: Int
            if lower.contains("space plants") || lower.contains("space them") || lower.contains("plant them")
                || lower.contains("plants should be") { rank = 1 }
            else if lower.contains("thin") { rank = 2 }
            else if lower.contains(" row") { continue }
            else { rank = 3 }
            guard best == nil || rank < best!.rank else { continue }

            let unit = match[3].lowercased()
            func inMetres(_ figure: Double) -> Double { unit == "cm" ? figure / 100 : unit == "mm" ? figure / 1000 : figure }
            var value = number(inMetres(low))
            if let high = Double(match[2]) { value += "-" + number(inMetres(high)) }
            best = (rank, value, sentence)
        }
        return best.map { ($0.value, $0.sentence) }
    }

    /// How long from sowing to harvest: "ready to harvest about 12–16
    /// weeks after sowing" gives "12-16 weeks".
    static func sowToCrop(in sentences: [String]) -> (value: String, sentence: String)? {
        let span = "(\\d+(?:\\s*[\u{2013}-]\\s*\\d+)?)\\s*(days|weeks|months)"
        for sentence in sentences {
            let match = Pattern.first(span + "\\s+(?:after|from)\\s+sowing", in: sentence)
                ?? Pattern.first("ready (?:to harvest |for harvesting |to pick |to pull )?in (?:about |around |as little as )?" + span, in: sentence)
            guard let match else { continue }
            let figures = plainDashes(match[1]).replacingOccurrences(of: " ", with: "")
            return ("\(figures) \(match[2].lowercased())", sentence)
        }
        return nil
    }

    /// Sun or shade, from what a page says the plant likes.
    ///
    /// The page must say it likes sun for "Full sun", and must also say
    /// it copes with some shade for "Full sun or partial shade". A page
    /// that only speaks of shade as something to avoid ("will not
    /// survive long in shady conditions") names none of the shade
    /// phrases below, so it is read as full sun.
    static func sunOrShade(in sentences: [String]) -> (value: String, sentence: String)? {
        let sunPhrases = ["full sun", "sunny site", "sunny spot", "sunny position", "sunny, ", "like sun", "likes sun",
                          "lots of sun", "plenty of sun", "in sun"]
        let shadePhrases = ["light shade", "partial shade", "part shade", "dappled shade", "some shade", "semi-shade"]
        let sunny = sentences.first { sentence in sunPhrases.contains { sentence.lowercased().contains($0) } }
        let shady = sentences.first { sentence in
            let lower = sentence.lowercased()
            return shadePhrases.contains { lower.contains($0) } && !lower.contains("avoid") && !lower.contains("not ")
        }
        switch (sunny, shady) {
        case (let sunny?, let shady?):
            return ("Full sun or partial shade", sunny == shady ? sunny : sunny + " " + shady)
        case (let sunny?, nil):
            return ("Full sun", sunny)
        case (nil, let shady?):
            return ("Partial shade", shady)
        case (nil, nil):
            return nil
        }
    }

    /// "Hardy perennial", "Half-hardy annual" and so on, from a
    /// sentence that says the plant is one: "Rhubarb is a hardy
    /// perennial that lives for many years".
    static func classification(in sentences: [String], plantName: String) -> (value: String, sentence: String)? {
        let plain = EiraSafety.tidied(KeptFacts.withoutBrackets(plantName)).trimmingCharacters(in: .whitespaces)
        let stem = RHSFinder.stem(plain.split(separator: " ").last.map(String.init) ?? plain)
        guard !stem.isEmpty else { return nil }
        // "is a", then perhaps one other word such as "herbaceous" or
        // "short-lived", then the words wanted. `(?!hardy|half|tender)`
        // stops that one other word from swallowing "hardy".
        let cycle = "\\b(?:is|are) (?:an? )?(?:(?!hardy|half|tender)[a-z-]+ )?((?:hardy |half-hardy |half hardy |tender )?(?:perennial|annual|biennial))s?\\b"
        for sentence in sentences where sentence.lowercased().contains(stem) {
            guard let match = Pattern.first(cycle, in: sentence) else { continue }
            let words = match[1].lowercased().replacingOccurrences(of: "half hardy", with: "half-hardy")
            return (words.prefix(1).uppercased() + words.dropFirst(), sentence)
        }
        return nil
    }

    /// Deciduous or evergreen, but only where the page uses one of the
    /// two words and never the other. A guide that covers both kinds
    /// says nothing certain about this plant.
    static func foliage(in sentences: [String]) -> (value: String, sentence: String)? {
        let evergreen = sentences.first { $0.lowercased().contains("evergreen") }
        let deciduous = sentences.first { $0.lowercased().contains("deciduous") }
        if let evergreen, deciduous == nil { return ("Evergreen", evergreen) }
        if let deciduous, evergreen == nil { return ("Deciduous", deciduous) }
        return nil
    }

    // MARK: Common problems

    private static let diseaseWords = ["virus", "blight", "mildew", "rust", "canker", "scab", "leaf spot", "mould",
                                       "wilt", "club root", "clubroot", "honey fungus", "leaf curl", "botrytis",
                                       " rot", "rots", "silver leaf", "blackleg", "smut"]
    private static let pestWords = ["slug", "snail", "aphid", " fly", "flies", "mice", "vole", "wireworm", "caterpillar",
                                    "beetle", "moth", "weevil", "bird", "pigeon", "sawfly", "mite", "thrip", "eelworm",
                                    "whitefly", "blackfly", "greenfly", "leaf miner", "rabbit", "deer", "squirrel",
                                    "earwig", "capsid", "midge", "leafhopper", "wasp", "woodlice", "leatherjacket"]

    /// The pests and diseases a growing guide lists under "Common
    /// Problems", by name, in small letters as the library writes them.
    ///
    /// The list is a run of entries, each a name, a line or two about
    /// it and then "Read more". So a name is the line two above a "Read
    /// more". Each is sorted into pest or disease by the words in it. A
    /// name that is neither, such as "Root vegetables: splitting", is a
    /// growing problem and is left out.
    static func commonProblems(in lines: [String]) -> (pests: [String], diseases: [String]) {
        guard let start = lines.firstIndex(where: { $0.lowercased() == "common problems" }) else { return ([], []) }
        var pests: [String] = []
        var diseases: [String] = []
        let section = Array(lines[(start + 1)...])
        for (index, line) in section.enumerated() where line.lowercased() == "read more" && index >= 2 {
            let name = section[index - 2]
            guard name.count <= 50, !name.contains(".") else { continue }
            let lower = " " + name.lowercased()
            if diseaseWords.contains(where: { lower.contains($0) }) {
                if !diseases.contains(name.lowercased()) { diseases.append(name.lowercased()) }
            } else if pestWords.contains(where: { lower.contains($0) }) {
                if !pests.contains(name.lowercased()) { pests.append(name.lowercased()) }
            }
        }
        return (pests, diseases)
    }

    // MARK: Shortening

    /// Text cut to whole sentences that fit a length. If even the first
    /// sentence is too long it is cut at a word, with three dots.
    static func shortened(_ text: String, to limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        var kept = ""
        for sentence in sentencesOf(trimmed) {
            if kept.count + sentence.count + 1 > limit { break }
            kept += (kept.isEmpty ? "" : " ") + sentence
        }
        return kept.isEmpty ? WebText.truncate(trimmed, to: limit) : kept
    }
}

// MARK: - Worked out from the plant's family

enum FamilyRules {

    /// What a plant's botanical family settles about it.
    ///
    /// - `isVegetable`: true when the RHS files the plant under its
    ///   vegetables. Only then is a crop rotation group suggested: a
    ///   wallflower is in the cabbage family and is no brassica crop.
    ///
    /// Each of these is worked out and not read, and says so.
    static func suggestions(family: String, latinName: String?, isVegetable: Bool) -> [FillSuggestion] {
        let name = family.trimmingCharacters(in: .whitespaces)
        let genus = (latinName ?? "").split(separator: " ").first.map(String.init) ?? ""
        var made: [FillSuggestion] = []
        func add(_ key: String, _ value: String, _ reason: String) {
            made.append(FillSuggestion(key: key, value: value, sourceName: "Worked out", address: nil,
                                       trust: .workedOut, evidence: reason))
        }
        switch name.lowercased() {
        case "apiaceae":
            add("isUmbelliferous", PlantFacts.yes, "Its family is Apiaceae, the carrot family, whose flowers are umbels.")
        case "fabaceae":
            add("isNitrogenFixer", PlantFacts.yes,
                "Its family is Fabaceae, the pea family. Most of the family fix nitrogen with bacteria on their roots, but not every member does, so check.")
            if isVegetable { add("group", "Beans", "The RHS lists it as a vegetable and its family is Fabaceae, the pea and bean family.") }
        case "brassicaceae":
            if isVegetable { add("group", "Brassicas", "The RHS lists it as a vegetable and its family is Brassicaceae, the cabbage family.") }
        case "cucurbitaceae":
            if isVegetable { add("group", "Gourd", "The RHS lists it as a vegetable and its family is Cucurbitaceae, the gourd family.") }
        case "solanaceae":
            if isVegetable { add("group", "Nightshades", "The RHS lists it as a vegetable and its family is Solanaceae, the nightshade family.") }
        case "amaryllidaceae":
            if isVegetable, genus.lowercased() == "allium" {
                add("group", "Alliums", "The RHS lists it as a vegetable and its genus is Allium, the onions.")
            }
        default:
            break
        }
        return made
    }

    /// The family and genus from GBIF's reply to a name. GBIF is the
    /// international register of species names, which Eira already
    /// uses (EiraTools.swift). Kept apart from the request itself so it
    /// can be tested without the internet.
    ///
    /// Only a sure match counts: GBIF's own confidence must be 90 or
    /// more out of 100.
    static func family(fromGBIF json: [String: Any]) -> String? {
        guard let matchType = json["matchType"] as? String, matchType != "NONE",
              let confidence = json["confidence"] as? Int, confidence >= 90,
              (json["kingdom"] as? String) == "Plantae" else { return nil }
        return json["family"] as? String
    }
}

// MARK: - Gathering, and choosing between sources

/// What one page gave.
struct PageReading: Equatable {
    let sourceName: String
    let trust: SourceTrust
    let address: String
    let title: String?
    let pageFacts: [PageFacts.Found]
}

/// What a look online brought back.
struct OnlineReading {
    var pages: [PageReading] = []
    /// The plant's botanical family, if a page or GBIF gave it.
    var family: String?
    /// True if the RHS files the plant under its vegetables.
    var isVegetable = false
    /// Plain words for anything that did not work, to show on screen.
    var problems: [String] = []
}

/// The few things about a plant that a look online needs. A plain
/// copy, so that the waiting can happen away from the database: a
/// record must only be touched on the app's main thread.
struct PlantAsked: Equatable {
    let name: String
    let variety: String?
    let latinName: String?
    let kind: PlantKind

    init(name: String, variety: String?, latinName: String?, kind: PlantKind) {
        self.name = name
        self.variety = variety
        self.latinName = latinName
        self.kind = kind
    }

    init(_ plant: Plant) {
        name = plant.commonName
        variety = plant.variety
        latinName = plant.latinName
        kind = PlantKind.of(group: plant.group)
    }
}

enum PlantFillIn {

    /// How many pages one plant may cost a site: the growing guide, the
    /// species page and the variety's page.
    static let pagesForOnePlant = 3

    /// Turns a page into a reading, using the rules above. The source
    /// and how far it is trusted come from the page's own address
    /// (WebSources in EiraSources.swift).
    static func reading(of page: WebPageReader.Page, plantName: String) -> PageReading {
        let site = WebSources.source(forAddress: page.address)
        return PageReading(sourceName: site.name, trust: site.trust, address: page.address, title: page.title,
                           pageFacts: PageFacts.facts(in: page.text, html: page.html, plantName: plantName))
    }

    /// Looks a plant up online: at most three pages of the RHS's, and
    /// one question to GBIF if the family is still not known.
    ///
    /// `async` marks a function that waits, here for the internet. The
    /// app carries on meanwhile, and the result arrives when it is ready.
    ///
    /// Manners, as for Eira's own reading (EiraSources.swift): one
    /// plant, when you ask, a handful of pages, each request saying it
    /// is Windfall. A plant the RHS has no guide for is remembered and
    /// not asked about again for a month.
    static func lookUp(_ whichPlant: PlantAsked, reader: WebPageReader = WebPageReader()) async -> OnlineReading {
        var result = OnlineReading()
        guard let guide = await RHSFinder.page(for: whichPlant.name, kind: whichPlant.kind, reader: reader) else {
            result.problems.append("The RHS's growing guide for \(whichPlant.name) could not be found or reached.")
            return result
        }
        result.isVegetable = guide.address.contains("/vegetables/")
        let guideReading = reading(of: guide, plantName: whichPlant.name)
        result.pages.append(guideReading)

        // The guide links to the RHS's own page for the species, and
        // often for the variety. The Latin name picks out the species:
        // the record's, or the one just read from the guide.
        let latin = whichPlant.latinName ?? guideReading.pageFacts.first { $0.key == "latinName" }?.value
        let links = RHSPage.links(forLatin: latin, variety: whichPlant.variety, among: RHSPage.plantLinks(inHTML: guide.html))
        // The variety's page first: where both say something, the
        // variety's own figure is the better one.
        for link in [links.variety, links.species].compactMap({ $0 }) where result.pages.count < pagesForOnePlant {
            if let page = try? await reader.fetch("https://www.rhs.org.uk" + link) {
                result.pages.insert(reading(of: page, plantName: whichPlant.name), at: result.pages.count - 1)
            }
        }
        result.family = result.pages.flatMap(\.pageFacts).first { $0.key == PageFacts.familyKey }?.value
        if result.family == nil, let latin {
            result.family = await gbifFamily(of: latin, reader: reader)
        }
        return result
    }

    /// Reads one page you have given the address of, from any site.
    /// Nil if it could not be read.
    static func readPage(at address: String, plantName: String, reader: WebPageReader = WebPageReader()) async -> PageReading? {
        guard let page = try? await reader.fetch(address) else { return nil }
        return reading(of: page, plantName: plantName)
    }

    /// Asks GBIF which family a Latin name belongs to.
    private static func gbifFamily(of latin: String, reader: WebPageReader) async -> String? {
        var components = URLComponents(string: "https://api.gbif.org/v1/species/match")
        components?.queryItems = [URLQueryItem(name: "name", value: latin)]
        guard let url = components?.url,
              let (data, _) = try? await reader.session.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return FamilyRules.family(fromGBIF: json)
    }

    /// The suggestions for a plant, one for each empty box, chosen from
    /// everything that was gathered.
    ///
    /// Where more than one source fills a box the order is:
    ///
    ///   1. your own library, because those are words you have already
    ///      checked and the library stays consistent
    ///   2. the pages, in the order given (the variety's own page
    ///      first, then the species, then the growing guide)
    ///   3. what was worked out from the family
    ///
    /// If a later source says something different, the suggestion
    /// carries a note of it, so the difference is seen and not hidden.
    /// A box that is already filled is never offered a suggestion.
    ///
    /// A fact that was found is offered even for a box PlantGaps would
    /// not count as a gap. A plant added a minute ago has no group yet,
    /// so the app cannot tell whether it is harvested or sown, and the
    /// page that gave the months is the better judge. It costs one
    /// press of Skip if it is not wanted.
    static func suggestions(for plant: Plant, fromLibrary own: [FillSuggestion], online: OnlineReading) -> [FillSuggestion] {
        var candidates = own
        for pageReading in online.pages {
            for fact in pageReading.pageFacts where fact.key != PageFacts.familyKey {
                candidates.append(FillSuggestion(key: fact.key, value: fact.value, sourceName: pageReading.sourceName,
                                                 address: pageReading.address, trust: pageReading.trust, evidence: fact.evidence))
            }
        }
        if let family = online.family {
            let latin = plant.latinName ?? candidates.first { $0.key == "latinName" }?.value
            candidates += FamilyRules.suggestions(family: family, latinName: latin, isVegetable: online.isVegetable)
        }

        var chosen: [FillSuggestion] = []
        for candidate in candidates {
            guard PlantFacts.named(candidate.key) != nil, PlantGaps.isEmpty(candidate.key, in: plant) else { continue }
            if let index = chosen.firstIndex(where: { $0.key == candidate.key }) {
                // A later source for the same box. Note it if it differs.
                let first = chosen[index]
                if first.otherView == nil, candidate.value.lowercased() != first.value.lowercased() {
                    // Two pages of one site can differ too: the RHS's
                    // plant page gives rhubarb full sun, and its growing
                    // guide adds that it copes with light shade.
                    let who = candidate.sourceName == first.sourceName
                        ? "Another \(candidate.sourceName) page" : candidate.sourceName
                    chosen[index].otherView = "\(who) says: \(candidate.value)"
                }
            } else {
                chosen.append(candidate)
            }
        }
        // In the order a plant's page shows its facts.
        let order = Dictionary(uniqueKeysWithValues: PlantFacts.all.enumerated().map { ($1.key, $0) })
        return chosen.sorted { (order[$0.key] ?? 0) < (order[$1.key] ?? 0) }
    }
}

// MARK: - Keeping a suggestion

extension KeptFactStore {

    /// Writes one suggestion into its box and remembers where it came
    /// from. Returns the record made, or nil if the box is not one the
    /// app knows or the value is blank.
    ///
    /// The value is passed separately because it may have been changed
    /// on the card before Keep was pressed.
    ///
    /// The writing goes through PlantFacts.write, which also notes the
    /// box as changed by hand, so loading the spreadsheet file again
    /// leaves it alone.
    @discardableResult
    func keep(_ suggestion: FillSuggestion, as value: String, in plant: Plant, on date: Date = .now) -> KeptFact? {
        guard let box = PlantFacts.named(suggestion.key) else { return nil }
        var tidy = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // A box of months takes months in the record's own style.
        if case .months = box.kind {
            let months = MonthParser.months(in: tidy)
            guard !months.isEmpty else { return nil }
            tidy = PlantFacts.monthText(months)
        }
        guard !tidy.isEmpty else { return nil }

        let before = PlantFacts.value(of: box, in: plant)
        PlantFacts.write(tidy, forKey: box.key, to: plant)

        let fact = KeptFact()
        fact.keptAt = date
        fact.plantID = plant.id
        fact.plantName = plant.displayName
        fact.factKey = box.key
        fact.words = tidy
        fact.valueBefore = before.isEmpty ? nil : before
        fact.valueAfter = PlantFacts.value(of: box, in: plant)
        fact.sourceName = suggestion.sourceName
        fact.sourceAddress = suggestion.address
        fact.trustRaw = suggestion.trust.rawValue
        context.insert(fact)
        try? context.save()
        return fact
    }
}

// MARK: - Hearing that a new plant has been planted

enum NewPlantMention {

    /// The name of a plant someone says they have planted, sown or
    /// bought, when it is not a plant the library already has. Nil for
    /// anything else.
    ///
    ///   "I planted a medlar by the pond today"        Medlar
    ///   "We've just bought two sea buckthorn"         Sea buckthorn
    ///   "I planted the rhubarb" (in the library)      nil
    ///   "I need to plant a medlar"                    nil
    ///   "Should I plant garlic now?"                  nil
    ///
    /// These are fixed rules and will miss some ways of putting it. A
    /// miss costs nothing: the plant can still be added by hand.
    ///
    /// - `known`: the common names in the library.
    static func name(in text: String, known: [String]) -> String? {
        guard !text.contains("?") else { return nil }
        let tidied = EiraSafety.tidied(text)
        // Something done, not something meant or put off.
        let notDone = [" need to ", " going to ", " want to ", " should ", " might ", " will ", " would ", " could ",
                       " didnt ", " havent ", " not ", " never ", " plan to ", " hoping to ", " if "]
        guard !notDone.contains(where: { tidied.contains($0) }) else { return nil }

        let doing = "(?:planted|sowed|sown|bought|added|put in|got)"
        let howMany = "(?:a couple of|a pair of|a few|a|an|some|one|two|three|four|five|six|\\d+|the|my|our)"
        // Words that end a name: where, when and what next. `$` is the
        // end of the text.
        let stop = "(?:in|on|at|by|next|near|along|under|beside|behind|from|for|today|yesterday|this|last|and|into|to|with|which|that|as) |$"
        // After the doing word and the "a" or "two": one to four words,
        // as few as will do (`{1,4}?`), up to a word that ends a name.
        // `(?=...)` looks ahead for that word without taking it.
        let pattern = " \(doing) \(howMany) ((?:[a-z]+ ){1,4}?)(?=\(stop))"
        guard let match = Pattern.first(pattern, in: tidied) else { return nil }

        var words = match[1].split(separator: " ").map(String.init)
        // "new" and the like are not part of a name, and nor is what
        // was planted of it: "three bare root medlar trees".
        let notNames: Set<String> = ["new", "more", "little", "young", "bare", "root", "rooted", "potted", "small", "large",
                                     "tree", "trees", "plant", "plants", "bush", "bushes", "seeds", "seed", "seedlings",
                                     "bulbs", "plugs", "cuttings", "canes", "crowns", "sets", "of"]
        words.removeAll { notNames.contains($0) }
        guard !words.isEmpty else { return nil }
        let name = words.joined(separator: " ")
        // Things that are planted or bought and are not plants.
        let notPlants: Set<String> = ["it", "them", "these", "those", "everything", "something", "lot", "few", "compost",
                                      "pot", "pots", "trowel", "spade", "fork", "shed", "greenhouse", "book", "tools"]
        guard name.count >= 3, !notPlants.contains(name) else { return nil }
        // Already in the library, under one name or several: then the
        // journal's own offer of a sowing is the right one.
        guard KeptFacts.plantNamed(in: " \(name) ", among: known) == nil else { return nil }
        return name.prefix(1).uppercased() + name.dropFirst()
    }
}
