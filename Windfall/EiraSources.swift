//
//  EiraSources.swift
//  Windfall
//
//  The websites Eira knows by name, how far each is trusted and how she
//  finds the right page on one.
//
//  Reading a page was always possible: give her an address and she
//  fetches it (EiraWebLookup.swift). What she could not do was FIND a
//  page. Wikipedia offers a search made for programs to use. The RHS
//  and most gardening sites offer only a search box made for people. So
//  until 14 November 2026 Wikipedia was the only place she could look
//  on her own.
//
//  This file gives her a way in to the RHS that needs no search at all:
//  its growing guides sit at addresses made from the plant's name.
//
//      rhs.org.uk/vegetables/rhubarb/grow-your-own
//      rhs.org.uk/fruit/apples/grow-your-own
//      rhs.org.uk/herbs/mint/grow-your-own
//      rhs.org.uk/plants/lavender/growing-guide
//
//  There are several such shapes (William, 14 November: "RHS for
//  example has a few different structure"), so she tries a short list
//  in a sensible order, checks that the page she lands on really is
//  about the plant, and remembers the address that worked so she never
//  has to guess for that plant again.
//
//  Manners: one page is read when you ask a question that needs it. The
//  site is never copied or crawled, a miss is remembered so it is not
//  tried again for a month, and every request says it is Windfall.
//
//  Nothing here draws anything or needs Apple's AI frameworks, and the
//  parts that do not touch the network are covered by the logic tests.
//

import Foundation

// MARK: - How far a source is trusted

/// How far a source is trusted. William, 13 November 2026: Eira "can go
/// online, but should state her sources... and inform if it's not
/// reliable". This is how she knows which is which.
enum SourceTrust: String, CaseIterable, Identifiable {
    /// A body whose advice is checked: the RHS, Kew, a recording scheme.
    case checked
    /// A good general guide, written by gardeners, not reviewed.
    case guide
    /// Wikipedia: useful background that anyone can edit.
    case general
    /// A site that is not on the list.
    case unknown
    /// Something you read yourself and typed in: a book, a seed
    /// packet, a neighbour's advice.
    case ownReading

    var id: String { rawValue }

    /// What Eira is told the source is, so that she says so.
    var said: String {
        switch self {
        case .checked: return "a checked source"
        case .guide: return "a general gardening guide, not a checked source"
        case .general: return "a general reference, not a checked source"
        case .unknown: return "a web page that has not been checked"
        case .ownReading: return "typed in by the gardener from their own reading"
        }
    }

    /// The short label on a card.
    var label: String {
        switch self {
        case .checked: return "Checked source"
        case .guide: return "General guide"
        case .general: return "General reference"
        case .unknown: return "Not a known source"
        case .ownReading: return "Your own reading"
        }
    }
}

/// A website Eira knows by name.
struct WebSource: Equatable {
    let name: String
    /// The ends of the site's addresses: "rhs.org.uk" also covers
    /// "www.rhs.org.uk".
    let hosts: [String]
    let trust: SourceTrust
}

enum WebSources {

    /// The list. Claude's first version of 14 November 2026, drawn from
    /// the project's notes on data sources, for William to change.
    static let all: [WebSource] = [
        WebSource(name: "RHS", hosts: ["rhs.org.uk"], trust: .checked),
        WebSource(name: "Garden Organic", hosts: ["gardenorganic.org.uk"], trust: .checked),
        WebSource(name: "Kew", hosts: ["kew.org"], trust: .checked),
        WebSource(name: "GBIF", hosts: ["gbif.org"], trust: .checked),
        WebSource(name: "NBN Atlas", hosts: ["nbnatlas.org"], trust: .checked),
        WebSource(name: "BWARS", hosts: ["bwars.com"], trust: .checked),
        WebSource(name: "Butterfly Conservation", hosts: ["butterfly-conservation.org"], trust: .checked),
        WebSource(name: "Hoverfly Recording Scheme", hosts: ["hoverfly.uk"], trust: .checked),
        WebSource(name: "UK Pollinator Monitoring Scheme", hosts: ["ukpoms.org.uk"], trust: .checked),
        WebSource(name: "Gardeners' World", hosts: ["gardenersworld.com"], trust: .guide),
        WebSource(name: "Charles Dowding", hosts: ["charlesdowding.co.uk"], trust: .guide),
        WebSource(name: "Plants For A Future", hosts: ["pfaf.org"], trust: .guide),
        WebSource(name: "Real Seeds", hosts: ["realseeds.co.uk"], trust: .guide),
        WebSource(name: "Kings Seeds", hosts: ["kingsseeds.com"], trust: .guide),
        WebSource(name: "Chiltern Seeds", hosts: ["chilternseeds.co.uk"], trust: .guide),
        WebSource(name: "Tamar Organics", hosts: ["tamarorganics.co.uk"], trust: .guide),
        WebSource(name: "Thompson & Morgan", hosts: ["thompson-morgan.com"], trust: .guide),
        WebSource(name: "Wikipedia", hosts: ["wikipedia.org"], trust: .general)
    ]

    /// The source a web address belongs to. A site not on the list is
    /// named by its address and marked as not known.
    static func source(forAddress address: String) -> WebSource {
        let host = (WebPageReader.webURL(from: address)?.host ?? address).lowercased()
        let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        if let known = all.first(where: { source in
            source.hosts.contains { bare == $0 || bare.hasSuffix("." + $0) }
        }) {
            return known
        }
        return WebSource(name: bare, hosts: [bare], trust: .unknown)
    }
}

// MARK: - Something found online, on its way to the Keep card

/// One thing a lookup found online. The chat turns the last of these
/// into the card that offers to keep it.
struct OnlineFind: Equatable {
    var sourceName: String
    var trust: SourceTrust
    var address: String
    /// The page's own title, shown on the card so a wrong match is
    /// plain to see. (A search for "Ivy" once came back with the Ivy
    /// League.)
    var title: String?
    /// The plant in the library it is about, if one was named.
    var plantName: String?
    /// The box of the plant's record the rules would put it in.
    var field: PlantField = .notes
}

// MARK: - Finding the RHS's page for a plant

enum RHSFinder {

    /// The parts of an address a plant's name can take. "Broad bean"
    /// gives "broad-bean" and "broad-beans". The RHS uses both ways:
    /// /fruit/apples/ but /vegetables/rhubarb/.
    static func slugs(for name: String) -> [String] {
        let plain = EiraSafety.tidied(KeptFacts.withoutBrackets(name)).trimmingCharacters(in: .whitespaces)
        guard !plain.isEmpty else { return [] }
        var found: [String] = []
        for spelling in KeptFacts.spellings(of: plain) {
            let slug = spelling.replacingOccurrences(of: " ", with: "-")
            if !found.contains(slug) { found.append(slug) }
        }
        return found
    }

    /// The addresses to try for a plant, most likely first.
    ///
    /// The kind of plant sets the order. Rhubarb is in William's library
    /// as fruit and the RHS files it under vegetables too, so every
    /// section is tried, with the plant's own kind first. A flower goes
    /// to the growing guides first.
    ///
    /// At most eight, so that a plant the RHS has no page for costs a
    /// handful of requests once and then is left alone (see PageMemory).
    static func candidates(for name: String, kind: PlantKind) -> [String] {
        let names = slugs(for: name)
        let edible: [String]
        switch kind {
        case .fruit: edible = ["fruit", "vegetables", "herbs"]
        case .herbs: edible = ["herbs", "vegetables", "fruit"]
        default: edible = ["vegetables", "herbs", "fruit"]
        }
        var growYourOwn: [String] = []
        for section in edible {
            for slug in names { growYourOwn.append("https://www.rhs.org.uk/\(section)/\(slug)/grow-your-own") }
        }
        let guides = names.map { "https://www.rhs.org.uk/plants/\($0)/growing-guide" }

        let ordered = (kind == .flowers || kind == .unsorted || kind == .greenManure)
            ? guides + growYourOwn
            : Array(growYourOwn.prefix(names.count * 2)) + guides + Array(growYourOwn.dropFirst(names.count * 2))
        return Array(ordered.prefix(8))
    }

    /// Whether a page that came back is really about the plant.
    ///
    /// A site may answer a wrong address with its home page, or with a
    /// "not found" page that still says all is well. So the page's
    /// title must hold the plant's name: "How to Grow Rhubarb" for
    /// rhubarb. Each word of the name is looked for without its ending,
    /// so "apples" is found for "Apple" and "raspberries" for
    /// "Raspberry".
    static func isAbout(_ name: String, title: String?) -> Bool {
        guard let title = title?.lowercased(), !title.isEmpty else { return false }
        let notFound = ["not found", "404", "page can't be found", "page cannot be found", "error"]
        if notFound.contains(where: { title.contains($0) }) { return false }
        let words = EiraSafety.tidied(KeptFacts.withoutBrackets(name)).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return false }
        return words.allSatisfy { title.contains(stem($0)) }
    }

    /// A word without its plural ending.
    static func stem(_ word: String) -> String {
        if word.count > 4, word.hasSuffix("ies") { return String(word.dropLast(3)) }
        if word.count > 4, word.hasSuffix("es") { return String(word.dropLast(2)) }
        if word.count > 3, word.hasSuffix("s") { return String(word.dropLast()) }
        if word.count > 3, word.hasSuffix("y") { return String(word.dropLast()) }
        return word
    }
}

// MARK: - Remembering which address worked

/// Remembers the page found for a plant on a site, and the misses.
///
/// Kept in the app's settings (UserDefaults), not the database: it is a
/// convenience that can be thrown away and found again, not a record.
struct PageMemory {

    enum Remembered: Equatable {
        /// The address that worked.
        case found(String)
        /// Nothing was found when last tried, on this day.
        case missed(Date)
    }

    var defaults: UserDefaults = .standard
    private let key = "eiraPagesFound"
    /// How long a miss stands before the site is tried again.
    static let daysBeforeRetry = 30

    private func name(_ source: String, _ plant: String) -> String {
        "\(source.lowercased())|\(KeptFacts.withoutBrackets(plant).lowercased())"
    }

    func remembered(source: String, plant: String) -> Remembered? {
        let all = defaults.dictionary(forKey: key) as? [String: String] ?? [:]
        guard let held = all[name(source, plant)] else { return nil }
        if held.hasPrefix("none@") {
            let seconds = Double(held.dropFirst(5)) ?? 0
            return .missed(Date(timeIntervalSince1970: seconds))
        }
        return .found(held)
    }

    func remember(_ address: String?, source: String, plant: String, on date: Date = .now) {
        var all = defaults.dictionary(forKey: key) as? [String: String] ?? [:]
        all[name(source, plant)] = address ?? "none@\(Int(date.timeIntervalSince1970))"
        defaults.set(all, forKey: key)
    }

    /// True when a site should be tried for a plant: never tried, or
    /// missed more than a month ago.
    func shouldTry(source: String, plant: String, asOf: Date = .now) -> Bool {
        switch remembered(source: source, plant: plant) {
        case .none: return true
        case .found: return true
        case .missed(let when):
            return asOf.timeIntervalSince(when) > Double(PageMemory.daysBeforeRetry) * 86_400
        }
    }
}

// MARK: - Picking the right part of a long page

extension WebText {

    /// The paragraphs of a page that bear on a question.
    ///
    /// A growing guide runs to thousands of words and a small model can
    /// take in a few hundred. So the page is cut into its lines and
    /// each line is marked:
    ///
    ///   - two marks for every word of `strong` it holds, and two more
    ///     if the heading above it holds one. `strong` is what the
    ///     question is about: for pruning, "cut back", "prun" and so on.
    ///   - one mark for every word of `weak`: the question's own words,
    ///     which tell one pruning paragraph from another.
    ///
    /// A line needs a strong word, or a heading with one, to count at
    /// all. (Where no strong words are given, one weak word will do.)
    /// The best are kept until `limit` characters are used, and come
    /// back in the page's own order, each under its heading. A photo's
    /// caption, which carries a copyright sign, is never kept.
    ///
    /// Returns "" when no line of the page counts.
    static func passages(in text: String, strong: [String], weak: [String] = [], limit: Int = 1100) -> String {
        // A line with no letter in it is left out: the RHS numbers its
        // quick facts "1", "2", "3", each on a line of its own.
        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in line.contains { $0.isLetter } }
        let strongWords = strong.map { $0.lowercased() }.filter { !$0.isEmpty }
        let weakWords = weak.map { $0.lowercased() }.filter { !$0.isEmpty }

        // A heading is a short line with no full stop in it. A short
        // line with a dash in the middle is a fact, not a heading: the
        // RHS's "Timing - November to early March".
        func isHeading(_ line: String) -> Bool {
            line.count <= 60 && !line.contains(".") && !line.contains(" - ") && !line.contains(" \u{2013} ")
        }

        // Read no further than where the page turns to other pages:
        // "You may also like", then a row of teasers for them. One of
        // those, about plums, was handed to Eira as advice on apples.
        let pageEnds = ["you may also like", "rhs guides, you may also like", "see also", "related articles",
                        "related advice", "more from ", "get involved", "join the rhs"]
        let end = lines.firstIndex { line in
            let lower = line.lowercased()
            return pageEnds.contains { lower.hasPrefix($0) }
        } ?? lines.count

        // First, every line's two kinds of mark.
        var read: [(index: Int, strong: Int, weak: Int)] = []
        // True while the lines being read sit under a heading that
        // holds one of the strong words: everything under "Pruning and
        // Training" is about pruning, whether or not it says the word.
        var underRightHeading = false
        for (index, line) in lines.enumerated() where index < end {
            let lower = line.lowercased()
            if isHeading(line) {
                underRightHeading = strongWords.contains { lower.contains($0) }
                continue
            }
            if line.contains("\u{00A9}") { continue }   // a photo's caption
            let strongMarks = strongWords.filter { lower.contains($0) }.count * 2 + (underRightHeading ? 2 : 0)
            let weakMarks = weakWords.filter { lower.contains($0) }.count
            read.append((index, strongMarks, weakMarks))
        }

        // A page that is about the subject from top to bottom ("Apples:
        // winter pruning", asked about pruning) has a strong word on
        // nearly every line, so the strong words pick nothing out. On
        // such a page the question's own words decide.
        let withStrong = read.filter { $0.strong > 0 }.count
        let isAllAboutIt = !strongWords.isEmpty && !weakWords.isEmpty
            && read.count >= 6 && withStrong * 10 >= read.count * 4
        var marked: [(index: Int, marks: Int)] = []
        for line in read {
            if isAllAboutIt {
                if line.weak > 0 { marked.append((line.index, line.weak * 2 + (line.strong > 0 ? 1 : 0))) }
            } else if strongWords.isEmpty ? line.weak > 0 : line.strong > 0 {
                marked.append((line.index, line.strong + line.weak))
            }
        }
        guard !marked.isEmpty else { return "" }

        // Best first, and for equal marks the one nearer the top.
        marked.sort { $0.marks != $1.marks ? $0.marks > $1.marks : $0.index < $1.index }
        var chosen: [Int] = []
        var used = 0
        for each in marked {
            let length = lines[each.index].count
            if used + length > limit, !chosen.isEmpty { continue }
            chosen.append(each.index)
            used += length
            if used >= limit { break }
        }

        var pieces: [String] = []
        var lastHeading: Int?
        for index in chosen.sorted() {
            // The nearest heading above, within a few lines.
            let heading = stride(from: index - 1, through: max(0, index - 6), by: -1).first { isHeading(lines[$0]) }
            if let heading, heading != lastHeading {
                pieces.append("[\(lines[heading])]")
                lastHeading = heading
            }
            pieces.append(truncate(lines[index], to: limit))
        }
        return pieces.joined(separator: "\n")
    }
}
