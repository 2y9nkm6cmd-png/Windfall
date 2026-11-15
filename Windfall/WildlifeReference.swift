import Foundation

// The UK wildlife reference: every animal you could meet, sorted into kinds.
//
// Asked for by William on 15 November 2026: "It would be good if you could
// create a sheet with all wildlife that you could encounter in the uk in
// it. With drawings." He chose three things the same afternoon:
//   - it lives in the app, not in a spreadsheet;
//   - it holds the animals Eira's image model can name: every animal with
//     20 or more confirmed UK records on iNaturalist;
//   - one drawing for each KIND of animal (bumblebee, hoverfly, tit, newt),
//     shared by every animal of that kind, as with the plant drawings.
// An hour later he asked for more: "more specific drawings per species",
// "for creatures I'm likely to see". So about two hundred of the most often
// seen animals now have a drawing of their own (`ownPicture`), and every
// other animal still shows the drawing of its kind.
//
// WHERE IT COMES FROM
// The list ships inside the app as WildlifeReference.json, made by
// Tools/data/build_wildlife_reference.py from what iNaturalist returned.
// The drawings are in the app's store of pictures under "Wildlife/", made
// by Tools/design/wildlife.py.
//
// WHAT IT IS NOT
// It is not William's own species list. That is the `Fauna` records, from
// his Fauna sheet, with his notes on tongue length and favoured plants.
// This list is kept apart from it and is never written into the database:
// it is read from the file each time the app opens, like the list of
// plant drawings. So it costs iCloud nothing and cannot be muddled with
// his records.
//
// ⚠️ Nothing in the file has been checked by William. The common names
// are iNaturalist's, the kinds and their rules are Claude's.
//
// Nothing here draws. This file only reads the list and answers questions
// about it, so that it can be tested without a Mac.

/// One kind of animal: "Bumblebees", under the heading "Bees, wasps and ants".
struct WildlifeKind: Decodable, Identifiable, Hashable {
    /// The short name used in file names: "bumblebee".
    let slug: String
    /// The name shown: "Bumblebees".
    let name: String
    /// The heading it sits under on the page: "Bees, wasps and ants".
    let group: String
    /// The scientific name of the animal this kind's drawing shows, where
    /// it is a drawing of one typical member: "Bombus terrestris".
    let typical: String?

    // The file calls the last of these "is". `CodingKeys` tells Swift
    // which name in the file fills which property.
    enum CodingKeys: String, CodingKey {
        case slug, name, group, typical = "is"
    }

    var id: String { slug }

    /// The name of this kind's drawing in the app's store of pictures.
    var pictureName: String { "Wildlife/wild-\(slug)" }
}

/// One animal in the reference.
struct WildlifeAnimal: Decodable, Identifiable, Hashable {
    let scientificName: String
    /// iNaturalist's common name. About one animal in five has none.
    let commonName: String?
    /// The slug of its kind.
    let kindSlug: String
    let family: String?
    let order: String?
    /// How many confirmed UK records iNaturalist held when the list was made.
    let ukRecords: Int
    /// Those records month by month, January first. Missing for an animal
    /// whose months were not fetched.
    let monthCounts: [Int]?
    /// True when iNaturalist marks it as brought to the UK by people.
    let introduced: Bool?
    /// The name of its own drawing, for an animal that has one. About two
    /// hundred of the most often seen do. The rest show their kind's.
    let ownPicture: String?

    // The file uses one-letter names to stay small. `CodingKeys` tells
    // Swift which letter fills which property.
    enum CodingKeys: String, CodingKey {
        case scientificName = "s", commonName = "c", kindSlug = "k", family = "f", order = "o"
        case ukRecords = "n", monthCounts = "m", introduced = "i", ownPicture = "p"
    }

    /// True when the drawing shown is of this animal and not of its kind.
    var hasOwnPicture: Bool { ownPicture != nil }

    /// The name of the drawing to show, in the app's store of pictures:
    /// its own if it has one, otherwise its kind's.
    var pictureName: String {
        ownPicture.map { "Wildlife/wild-sp-\($0)" } ?? "Wildlife/wild-\(kindSlug)"
    }

    var id: String { scientificName }

    /// The name to show first: the common one, or the scientific one
    /// when it has no common name.
    var title: String { commonName ?? scientificName }

    /// The share of this animal's UK records that fall in a month
    /// (1 is January), from 0 to 1. Nil when its months are not known.
    func share(ofMonth month: Int) -> Double? {
        guard let counts = monthCounts, counts.count == 12, (1...12).contains(month) else { return nil }
        let total = counts.reduce(0, +)
        guard total > 0 else { return nil }
        return Double(counts[month - 1]) / Double(total)
    }

    /// Whether the animal is about in a month: at least 2 in every 100 of
    /// its records fall in it. Nil when its months are not known.
    ///
    /// ⚠️ The level is Claude's. It is the one Eira's photo rules already
    /// use for "not often recorded in this month" (EiraIdentify.swift).
    func isAbout(inMonth month: Int) -> Bool? {
        share(ofMonth: month).map { $0 >= WildlifeReference.aboutLevel }
    }

    /// The months it is about in, 1 to 12. Empty when not known.
    var monthsAbout: [Int] {
        (1...12).filter { isAbout(inMonth: $0) == true }
    }

    /// The months it is about in, in words: "April to September",
    /// "All year", "November to February". Nil when not known.
    var seasonWords: String? {
        guard monthCounts != nil, share(ofMonth: 1) != nil else { return nil }
        return WildlifeReference.words(forMonths: monthsAbout)
    }
}

struct WildlifeReference {

    /// A month counts when it holds at least this share of the records.
    static let aboutLevel = 0.02

    /// A heading and the kinds under it.
    struct Group: Identifiable, Equatable {
        let name: String
        let kinds: [WildlifeKind]
        var id: String { name }
    }

    /// Where the list came from, and the day it was fetched ("2026-11-15").
    let source: String
    let fetched: String
    let kinds: [WildlifeKind]
    let animals: [WildlifeAnimal]

    /// From a kind's slug to the places of its animals in `animals`, and
    /// from a scientific name in small letters to its place, so that
    /// neither is a search through four thousand rows.
    private let placesByKind: [String: [Int]]
    private let placeByName: [String: Int]

    init(source: String = "", fetched: String = "", kinds: [WildlifeKind], animals: [WildlifeAnimal]) {
        self.source = source
        self.fetched = fetched
        self.kinds = kinds
        self.animals = animals
        var byKind: [String: [Int]] = [:]
        var byName: [String: Int] = [:]
        for (place, creature) in animals.enumerated() {
            byKind[creature.kindSlug, default: []].append(place)
            byName[WildlifeReference.plain(creature.scientificName)] = place
        }
        placesByKind = byKind
        placeByName = byName
    }

    /// The shape of WildlifeReference.json.
    private struct File: Decodable {
        let source: String?
        let fetched: String?
        let kinds: [WildlifeKind]
        let animals: [WildlifeAnimal]
    }

    /// Reads the list from the file's contents.
    static func decode(_ data: Data) throws -> WildlifeReference {
        let listFile = try JSONDecoder().decode(File.self, from: data)
        return WildlifeReference(source: listFile.source ?? "", fetched: listFile.fetched ?? "", kinds: listFile.kinds, animals: listFile.animals)
    }

    /// The list that ships inside the app, read once, the first time it is
    /// asked for. If the file is missing the list is empty and the pages
    /// that use it say so.
    static let shared: WildlifeReference = {
        guard let url = Bundle.main.url(forResource: "WildlifeReference", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? decode(data) else { return WildlifeReference(kinds: [], animals: []) }
        return list
    }()

    /// A name as it is compared: small letters, no spaces at the ends.
    static func plain(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: Kinds

    /// The headings in the order the file gives them, each with its kinds.
    /// A kind with no animals is left out.
    var groups: [Group] {
        var names: [String] = []
        var held: [String: [WildlifeKind]] = [:]
        for kind in kinds where count(ofKind: kind.slug) > 0 {
            if held[kind.group] == nil { names.append(kind.group) }
            held[kind.group, default: []].append(kind)
        }
        return names.map { Group(name: $0, kinds: held[$0] ?? []) }
    }

    func kind(slug: String) -> WildlifeKind? {
        kinds.first { $0.slug == slug }
    }

    /// How many animals a kind holds.
    func count(ofKind slug: String) -> Int {
        placesByKind[slug]?.count ?? 0
    }

    /// A kind's animals, most recorded first (the order of the file).
    /// With a month, only those about in that month. An animal whose
    /// months are not known is kept, because leaving it out would say
    /// something the list does not know.
    func animals(ofKind slug: String, aboutInMonth month: Int? = nil) -> [WildlifeAnimal] {
        let all = (placesByKind[slug] ?? []).map { animals[$0] }
        guard let month else { return all }
        return all.filter { $0.isAbout(inMonth: month) != false }
    }

    /// A kind's animals that have a drawing of their own, most recorded first.
    func pictured(ofKind slug: String) -> [WildlifeAnimal] {
        animals(ofKind: slug).filter(\.hasOwnPicture)
    }

    // MARK: One animal

    /// The animal with this scientific name, whatever its capitals.
    func animal(scientificName: String?) -> WildlifeAnimal? {
        guard let scientificName else { return nil }
        return placeByName[WildlifeReference.plain(scientificName)].map { animals[$0] }
    }

    /// The kind an animal with this scientific name belongs to. This is
    /// how one of William's own species finds its drawing.
    func kind(ofScientificName scientificName: String?) -> WildlifeKind? {
        animal(scientificName: scientificName).flatMap { kind(slug: $0.kindSlug) }
    }

    // MARK: Search

    /// Animals whose common name, scientific name or family holds the
    /// words typed, most recorded first, and no more than `limit` of them.
    func search(_ text: String, limit: Int = 60) -> [WildlifeAnimal] {
        let needle = WildlifeReference.plain(text)
        guard !needle.isEmpty else { return [] }
        let found = animals.filter { creature in
            creature.scientificName.lowercased().contains(needle)
                || (creature.commonName?.lowercased().contains(needle) ?? false)
                || (creature.family?.lowercased().contains(needle) ?? false)
        }
        return Array(found.sorted { $0.ukRecords > $1.ukRecords }.prefix(limit))
    }

    // MARK: Months in words

    static let monthNames = ["January", "February", "March", "April", "May", "June",
                             "July", "August", "September", "October", "November", "December"]

    /// Turns a set of months into words. A run that goes round the end of
    /// the year is said as one run: [11, 12, 1, 2] is "November to February".
    static func words(forMonths months: [Int]) -> String {
        let wanted = Set(months.filter { (1...12).contains($0) })
        if wanted.isEmpty { return "Not known" }
        if wanted.count == 12 { return "All year" }
        // Start from a month that is in the set and follows one that is not,
        // so a run that wraps round December is not cut in two.
        guard let start = (1...12).first(where: { wanted.contains($0) && !wanted.contains($0 == 1 ? 12 : $0 - 1) }) else { return "All year" }
        var spans: [(first: Int, last: Int)] = []
        var step = 0
        while step < 12 {
            let month = (start - 1 + step) % 12 + 1
            if wanted.contains(month) {
                var last = month
                var reach = step
                while reach + 1 < 12, wanted.contains((start - 1 + reach + 1) % 12 + 1) {
                    reach += 1
                    last = (start - 1 + reach) % 12 + 1
                }
                spans.append((month, last))
                step = reach + 1
            } else {
                step += 1
            }
        }
        let said = spans.map { span in
            span.first == span.last ? monthNames[span.first - 1] : "\(monthNames[span.first - 1]) to \(monthNames[span.last - 1])"
        }
        return said.joined(separator: ", ")
    }
}
