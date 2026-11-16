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
    /// What its OTHER drawings show, for an animal with more than one, in
    /// the order they are shown: "flight", "female", "caterpillar". Each
    /// is a key from `viewNames`. About seventy animals have these.
    let otherViews: [String]?
    /// What its FIRST drawing shows ("male", "perched", "adult"), so that
    /// it can be told from the others. Only set when there are others.
    let mainShows: String?

    // The file uses one-letter names to stay small. `CodingKeys` tells
    // Swift which letter fills which property.
    enum CodingKeys: String, CodingKey {
        case scientificName = "s", commonName = "c", kindSlug = "k", family = "f", order = "o"
        case ukRecords = "n", monthCounts = "m", introduced = "i", ownPicture = "p"
        case otherViews = "v", mainShows = "w"
    }

    /// One drawing of an animal, with the words that say what it shows.
    struct Picture: Identifiable, Hashable {
        /// The short key: "flight", "female", "caterpillar".
        let key: String
        /// The words shown under it: "In flight", "Female", "Caterpillar".
        let caption: String
        /// Its name in the app's store of pictures.
        let pictureName: String
        var id: String { key }
    }

    /// The words shown for each key. The same list is in
    /// Tools/design/wildlife.py (`VIEW_NAMES`), and a logic test checks
    /// that every key used in the list of animals has words here.
    static let viewNames: [String: String] = [
        "adult": "Adult", "male": "Male", "female": "Female", "juvenile": "Young bird",
        "summer": "In summer", "winter": "In winter", "perched": "Perched", "flight": "In flight",
        "upperside": "Wings open", "underside": "Wings closed", "eggs": "Eggs", "spawn": "Spawn",
        "tadpole": "Tadpole", "caterpillar": "Caterpillar", "chrysalis": "Chrysalis",
        "cocoon": "Cocoon", "larva": "Larva", "pupa": "Pupa", "nymph": "Nymph",
    ]

    /// The words for a key. A key with no words of its own is shown with
    /// a capital letter, so a new one is never blank.
    static func viewName(_ key: String) -> String {
        viewNames[key] ?? key.capitalized
    }

    /// Every drawing of this animal, the first one first. Most animals
    /// have one, and then its caption is empty because nothing needs
    /// telling apart.
    var pictures: [Picture] {
        guard let own = ownPicture, let others = otherViews, !others.isEmpty else {
            return [Picture(key: "only", caption: "", pictureName: pictureName)]
        }
        let firstKey = mainShows ?? "adult"
        var list = [Picture(key: firstKey, caption: WildlifeAnimal.viewName(firstKey), pictureName: pictureName)]
        // `where` skips a key that repeats the first, so no two share an id.
        for key in others where key != firstKey {
            list.append(Picture(key: key, caption: WildlifeAnimal.viewName(key), pictureName: "Wildlife/wild-sp-\(own)--\(key)"))
        }
        return list
    }

    /// True when there is more than one drawing to choose between.
    var hasOtherPictures: Bool { pictures.count > 1 }

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
    /// For a few genera, the scientific name of the animal whose drawing
    /// stands for every member, keyed by the genus in small letters:
    /// "myrmica" to "Myrmica rubra", because any Myrmica is a red ant.
    /// Used for a species of William's that the list does not hold.
    let genusStandIns: [String: String]

    /// From a kind's slug to the places of its animals in `animals`, from
    /// a scientific name in small letters to its place, and from a genus
    /// to the places of its members, so that none is a search through
    /// four thousand rows.
    private let placesByKind: [String: [Int]]
    private let placeByName: [String: Int]
    private let placesByGenus: [String: [Int]]

    init(source: String = "", fetched: String = "", kinds: [WildlifeKind], animals: [WildlifeAnimal], genusStandIns: [String: String] = [:]) {
        self.source = source
        self.fetched = fetched
        self.kinds = kinds
        self.animals = animals
        self.genusStandIns = genusStandIns
        var byKind: [String: [Int]] = [:]
        var byName: [String: Int] = [:]
        var byGenus: [String: [Int]] = [:]
        for (place, creature) in animals.enumerated() {
            byKind[creature.kindSlug, default: []].append(place)
            byName[WildlifeReference.plain(creature.scientificName)] = place
            byGenus[WildlifeReference.genus(of: creature.scientificName), default: []].append(place)
        }
        placesByKind = byKind
        placeByName = byName
        placesByGenus = byGenus
    }

    /// The genus of a scientific name, in small letters: its first word.
    /// "Andrena spp." and "Andrena fulva" both give "andrena".
    static func genus(of scientificName: String) -> String {
        plain(scientificName).split(separator: " ").first.map(String.init) ?? ""
    }

    /// The shape of WildlifeReference.json.
    private struct File: Decodable {
        let source: String?
        let fetched: String?
        let kinds: [WildlifeKind]
        let animals: [WildlifeAnimal]
        let genera: [String: String]?
    }

    /// Reads the list from the file's contents.
    static func decode(_ data: Data) throws -> WildlifeReference {
        let listFile = try JSONDecoder().decode(File.self, from: data)
        return WildlifeReference(source: listFile.source ?? "", fetched: listFile.fetched ?? "", kinds: listFile.kinds, animals: listFile.animals, genusStandIns: listFile.genera ?? [:])
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

    // MARK: A drawing for any name

    /// A drawing to show for a scientific name, and a line to put under it
    /// when the drawing is not of that very animal.
    struct Drawing: Equatable {
        /// Its name in the app's store of pictures.
        let pictureName: String
        /// Nil when the drawing is of the animal itself.
        let note: String?
    }

    /// The drawing for a scientific name, which need not be in the list.
    /// William's own species list holds "Andrena spp." (a whole genus) and
    /// Myrmica sabuleti (too scarce for the list), and both had no drawing
    /// (his message of 15 November 2026). It tries, in order:
    ///   1. the animal itself: its own drawing, or its kind's;
    ///   2. the animal that stands for its genus (`genusStandIns`);
    ///   3. the kind of its most recorded relative in the same genus.
    /// Nil when the genus is not in the list at all.
    func drawing(forScientificName scientificName: String?) -> Drawing? {
        guard let scientificName else { return nil }
        if let exact = animal(scientificName: scientificName) {
            return Drawing(pictureName: exact.pictureName, note: exact.hasOwnPicture ? nil : "The drawing is of its kind, not of this species.")
        }
        let genus = WildlifeReference.genus(of: scientificName)
        guard !genus.isEmpty else { return nil }
        if let standIn = animal(scientificName: genusStandIns[genus]), standIn.hasOwnPicture {
            return Drawing(pictureName: standIn.pictureName, note: "The drawing is of a close relative, \(standIn.title) (\(standIn.scientificName)).")
        }
        // `max(by:)` finds the largest by the rule given, here the most records.
        let relatives = (placesByGenus[genus] ?? []).map { animals[$0] }
        guard let commonest = relatives.max(by: { $0.ukRecords < $1.ukRecords }) else { return nil }
        return Drawing(pictureName: "Wildlife/wild-\(commonest.kindSlug)", note: "The drawing is of its kind, not of this species.")
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

// MARK: - A sighting's English and Latin names, both shown

/// The two names a sighting is shown by: its English name as the title,
/// and its Latin name beside or under it. William, 16 November 2026:
/// "Include Latin name and common name." Until then a sighting showed
/// whichever one name came first, often only the Latin.
struct ShownNames: Equatable {
    /// "Honey bee". Nil when no English name is known.
    var english: String?
    /// "Apis mellifera", without its author. Nil when none is known.
    var latin: String?

    /// What to put in large type: the English name, or the Latin when
    /// that is all there is.
    var title: String { english ?? latin ?? "Unidentified sighting" }

    /// What to put under or after the title: the Latin, but only when
    /// the title is the English name, so the Latin is never said twice.
    var latinBeside: String? { english == nil ? nil : latin }

    /// Both on one line, for places with room for one: "Honey bee
    /// (Apis mellifera)".
    var oneLine: String {
        guard let latinBeside else { return title }
        return "\(title) (\(latinBeside))"
    }
}

extension SpeciesName {

    /// A scientific name as it should be shown: the genus and the words
    /// after it, without an author or year. "Bombus terrestris
    /// (Linnaeus, 1758)" gives "Bombus terrestris". Nil for nothing.
    ///
    /// It stops at the first word, after the genus, that starts with a
    /// capital letter, a bracket or a figure, because those begin the
    /// author's name or the year.
    nonisolated static func shown(_ name: String?) -> String? {
        guard let name else { return nil }
        var kept: [Substring] = []
        for word in name.split(separator: " ") {
            if let first = word.first, !kept.isEmpty,
               first.isUppercase || first == "(" || first.isNumber {
                break
            }
            kept.append(word)
        }
        let shown = kept.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return shown.isEmpty ? nil : shown
    }

    /// True when a name is written as a scientific one: a capital first
    /// word and a small second word ("Apis mellifera"). "Small
    /// tortoiseshell" is not, nor is "Honey Bee".
    nonisolated static func looksLatin(_ name: String) -> Bool {
        let words = name.split(separator: " ")
        guard words.count >= 2, let first = words[0].first, let second = words[1].first else { return false }
        return first.isUppercase && second.isLowercase
            && !englishFirstWords.contains(words[0].lowercased())
    }

    /// First words that make a two-word name English, not Latin, even
    /// though the second word is small: "Small tortoiseshell", "Red
    /// admiral". Only used by `looksLatin`.
    private static let englishFirstWords: Set<String> = [
        "small", "large", "common", "red", "white", "green", "great", "lesser", "garden",
        "tree", "honey", "buff-tailed", "brown", "black", "blue", "yellow", "orange", "grey",
        "harlequin", "seven-spot", "two-spot", "peacock", "comma", "painted", "holly", "speckled"
    ]
}

extension WildlifeObservation {

    /// The English and Latin names to show for this sighting.
    ///
    /// - The Latin is its accepted name, or the scientific name typed or
    ///   suggested, or the confirmed name when that is a Latin one.
    /// - The English is the name typed in its Common name box. Failing
    ///   that, it is looked up by the Latin name: first among William's
    ///   own species, then in the UK guide.
    ///
    /// `yourSpecies` and `ukGuide` are passed in rather than fetched here,
    /// so this can be tested without the app's records.
    func shownNames(yourSpecies: [Fauna] = [], ukGuide: WildlifeReference? = nil) -> ShownNames {
        var latinSource = acceptedScientificName ?? scientificName
        var englishSource = commonName?.isEmpty == false ? commonName : nil
        if let confirmed = confirmedID, !confirmed.isEmpty {
            if SpeciesName.looksLatin(confirmed) {
                // A confirmed Latin name that differs from the one typed
                // replaces it, and the English typed for the old one no
                // longer fits.
                if SpeciesName.key(confirmed) != SpeciesName.key(latinSource) {
                    latinSource = confirmed
                    englishSource = nil
                }
            } else if englishSource == nil {
                englishSource = confirmed
            }
        }
        let latin = SpeciesName.shown(latinSource)
        var english = englishSource
        if english == nil, let latin {
            let key = SpeciesName.key(latin)
            english = yourSpecies.first(where: { SpeciesName.key($0.scientificName) == key && !$0.commonName.isEmpty })?.commonName
                ?? ukGuide?.animal(scientificName: latin)?.commonName
        }
        // An "English" name that is only the Latin again is no English name.
        if let found = english, SpeciesName.key(found) == SpeciesName.key(latin), latin != nil {
            english = nil
        }
        return ShownNames(english: english, latin: latin)
    }
}
