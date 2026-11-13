//
//  JournalOffers.swift
//  Windfall
//
//  Reads something written in the journal and works out whether it
//  describes a harvest or a sowing that could be put on record.
//
//  "We harvested 50kg of Jonagold's" gives one offer: a harvest, of the
//  plant whose variety is Jonagold, 50 kilograms. The screen
//  (JournalOfferCards.swift) shows each offer as a card from Eira with
//  Add and a way to say no. Nothing is saved by this file, and nothing
//  is saved at all until Add is pressed.
//
//  How it reads:
//
//  1. It looks for a word that means harvesting ("picked", "dug",
//     "harvested") or sowing ("sowed", "planted"). Only words for
//     something done, so "need to sow carrots" and "didn't pick any"
//     offer nothing.
//  2. From that word to the next such word, or the end of the sentence,
//     it looks for the names of plants in the library.
//  3. For each plant it looks nearby for an amount ("50kg", "a kilo
//     of", "12"), and in the sentence for a bed, where a crop went
//     ("froze", "for cider") and where a sowing was made ("in the
//     greenhouse").
//
//  These are fixed rules, not the AI model, so the same words always
//  give the same offers, on any device. Rules will miss some ways of
//  putting things. A miss costs nothing: the entry is still saved, and
//  the record can be added by hand.
//
//  Nothing here draws anything or touches the records, so it can be
//  tested without a screen.
//

import Foundation

// MARK: - What it is told

/// A plant the reader can look for.
struct OfferPlant {
    /// The plant's own identifier, as text.
    let key: String
    let commonName: String
    let variety: String?
}

/// A bed the reader can look for.
struct OfferBed {
    let key: String
    let name: String
}

// MARK: - What comes back

/// One record the journal's words seem to describe.
struct RecordOffer: Identifiable, Equatable {

    enum Kind: String {
        case harvest, sowing
    }

    let id: String
    let kind: Kind
    /// The plants it might be, likeliest first. There is one unless
    /// only a common name was written ("apples") and several plants in
    /// the library share it.
    let plantKeys: [String]
    /// How much was harvested, or how many seeds were sown. Nil if the
    /// words did not say.
    let quantity: Double?
    /// For a harvest with an amount: what it was measured in.
    let unit: HarvestUnit?
    /// For a harvest: where it went, if the words said.
    let destination: HarvestDestination?
    /// The bed named in the same sentence, if one was.
    let bedKey: String?
    /// For a sowing: where it was sown, if the words said.
    let sownWhere: SowingLocation?
}

// MARK: - The reader

enum JournalOffers {

    // MARK: Word lists

    private static let harvestWords: Set<String> = [
        "harvested", "picked", "pulled", "lifted", "dug", "cut", "gathered", "collected", "cropped",
        "harvesting", "picking", "pulling", "lifting", "digging", "cutting", "gathering"
    ]

    private static let sowWords: Set<String> = ["sowed", "sown", "sowing", "seeded", "planted", "planting"]

    /// Within three words before the doing word, any of these means it
    /// has not happened: it is planned, wished for or denied.
    private static let notDone: Set<String> = [
        "to", "need", "must", "will", "should", "going", "want", "plan", "might", "could", "not", "never",
        "didn't", "didn’t", "haven't", "haven’t", "don't", "don’t", "won't", "won’t", "thinking", "considering", "next"
    ]

    /// What an amount can be measured in, by the root of the word.
    private static let units: [String: HarvestUnit] = [
        "kg": .kilograms, "kgs": .kilograms, "kilo": .kilograms, "kilogram": .kilograms, "kilogramme": .kilograms,
        "g": .grams, "gm": .grams, "gms": .grams, "gram": .grams, "gramme": .grams,
        "l": .litres, "litre": .litres, "liter": .litres,
        "bunch": .bunches
    ]

    /// Pounds and ounces are turned into kilograms and grams, since the
    /// app records in those.
    private static let imperial: [String: (unit: HarvestUnit, each: Double)] = [
        "lb": (.kilograms, 0.45359237), "lbs": (.kilograms, 0.45359237), "pound": (.kilograms, 0.45359237),
        "oz": (.grams, 28.349523), "ounce": (.grams, 28.349523)
    ]

    /// Things seed is sown by that are not a number of seeds.
    private static let containers: Set<String> = ["row", "tray", "pot", "module", "packet", "line", "drill", "pinch", "cell", "pan"]

    private static let numberWords: [String: Double] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9,
        "ten": 10, "eleven": 11, "twelve": 12, "couple": 2, "dozen": 12, "half": 0.5
    ]

    /// Variety names too ordinary to stand for a plant by themselves.
    /// "Purple" in a sentence does not mean the purple French bean.
    private static let plainVarieties: Set<String> = [
        "purple", "red", "green", "yellow", "white", "black", "blue", "orange", "pink", "golden", "early", "late",
        "giant", "dwarf", "mixed", "sweet", "wild", "common", "mini", "baby", "large", "small", "tall", "climbing", "bush"
    ]

    private static let destinations: [(HarvestDestination, Set<String>)] = [
        (.frozen, ["froze", "frozen", "freezer", "freeze", "freezing"]),
        (.stored, ["stored", "store", "storing", "storage"]),
        (.preserved, ["jam", "chutney", "pickled", "pickle", "pickling", "cider", "perry", "juice", "juiced", "pressed",
                      "pressing", "dried", "drying", "bottled", "preserved", "preserve", "fermented", "sauce", "wine"]),
        (.givenAway, ["gave", "given", "neighbour", "shared"]),
        (.sold, ["sold"]),
        (.composted, ["compost", "composted"]),
        (.eaten, ["ate", "eaten", "cooked", "lunch", "dinner", "supper"])
    ]

    private static let locations: [(SowingLocation, Set<String>)] = [
        (.undercover, ["greenhouse", "polytunnel", "tunnel", "cloche", "coldframe"]),
        (.indoors, ["indoor", "inside", "windowsill", "propagator", "kitchen"]),
        (.directSown, ["direct", "directly"]),
        (.outdoors, ["outdoor", "outside"])
    ]

    // MARK: Words

    /// One word of the entry.
    private struct ReadWord {
        /// Lower case, with nothing but letters and figures at its ends.
        let plain: String
        /// Cut down further, so that plurals match. See `JournalChat.root`.
        let root: String
        /// Which sentence it is in, counting from 0.
        let sentence: Int
    }

    /// Splits text into words, keeping track of sentences. "50kg" is
    /// split into "50" and "kg".
    private static func pieces(of text: String) -> [ReadWord] {
        var read: [ReadWord] = []
        for (number, sentence) in JournalChat.sentences(in: text).enumerated() {
            for word in sentence.split(separator: " ") {
                let plain = word.lowercased().trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                guard !plain.isEmpty else { continue }
                let figures = plain.prefix { $0.isNumber || $0 == "." }
                let rest = plain.dropFirst(figures.count)
                if !figures.isEmpty, !rest.isEmpty, rest.allSatisfy(\.isLetter), Double(figures) != nil {
                    read.append(ReadWord(plain: String(figures), root: String(figures), sentence: number))
                    read.append(ReadWord(plain: String(rest), root: JournalChat.root(of: String(rest)), sentence: number))
                } else {
                    read.append(ReadWord(plain: plain, root: JournalChat.root(of: plain), sentence: number))
                }
            }
        }
        return read
    }

    // MARK: Plant names

    /// A plant's names as lists of roots, ready to be looked for.
    private struct Names {
        let key: String
        let common: [String]
        /// Empty if there is no variety, or it is too ordinary a word.
        let variety: [String]
    }

    private static func names(of plant: OfferPlant) -> Names {
        let common = JournalChat.roots(in: plant.commonName)
        // Anything in brackets is a note, not part of the name.
        var variety = plant.variety ?? ""
        if let bracket = variety.firstIndex(of: "(") { variety = String(variety[..<bracket]) }
        var varietyRoots = JournalChat.roots(in: variety)
        if varietyRoots.count == 1, let only = varietyRoots.first, only.count < 4 || plainVarieties.contains(only) {
            varietyRoots = []
        }
        return Names(key: plant.key, common: common, variety: varietyRoots)
    }

    /// A plant named in the words: where, how many words long, and
    /// which plants it could be.
    private struct Mention {
        let start: Int
        let length: Int
        let plantKeys: [String]
    }

    /// True if `words` appear in `roots` starting at `index`.
    private static func matches(_ words: [String], in roots: [String], at index: Int) -> Bool {
        guard !words.isEmpty, index + words.count <= roots.count else { return false }
        return Array(roots[index..<(index + words.count)]) == words
    }

    /// Finds the plants named between two places in the words. The
    /// longest name wins: "Jonagold apples" is one plant, not a variety
    /// and then every apple.
    private static func mentions(in roots: [String], from start: Int, to end: Int, plants: [Names]) -> [Mention] {
        var spotted: [Mention] = []
        var index = start
        while index < end {
            var longest: Mention?
            func offer(_ length: Int, _ keys: [String]) {
                guard index + length <= end, length > (longest?.length ?? 0) else { return }
                longest = Mention(start: index, length: length, plantKeys: keys)
            }
            for plant in plants {
                if !plant.variety.isEmpty {
                    if matches(plant.common + plant.variety, in: roots, at: index) {
                        offer(plant.common.count + plant.variety.count, [plant.key])
                    }
                    if matches(plant.variety + plant.common, in: roots, at: index) {
                        offer(plant.common.count + plant.variety.count, [plant.key])
                    }
                    if matches(plant.variety, in: roots, at: index) {
                        offer(plant.variety.count, [plant.key])
                    }
                }
            }
            // A common name alone: every plant that shares it.
            for plant in plants where matches(plant.common, in: roots, at: index) && plant.common.count > (longest?.length ?? 0) {
                let sharing = plants.filter { $0.common == plant.common }.map(\.key)
                longest = Mention(start: index, length: plant.common.count, plantKeys: sharing)
            }
            if let longest {
                spotted.append(longest)
                index += longest.length
            } else {
                index += 1
            }
        }
        return spotted
    }

    // MARK: Amounts

    /// An amount found in the words.
    private struct Amount {
        var value: Double
        /// The root of the word after the number, if it was a measure
        /// or a container. Nil for a bare number.
        var measure: String?
    }

    private static func number(_ readWord: ReadWord) -> Double? {
        Double(readWord.plain) ?? numberWords[readWord.root]
    }

    private static func isMeasure(_ root: String) -> Bool {
        units[root] != nil || imperial[root] != nil || containers.contains(root) || root == "seed"
    }

    /// Looks for an amount between two places. Before a plant's name
    /// any number counts ("12 apples"). After it, only a number with a
    /// measure does ("apples, about 50kg").
    private static func amount(in pieces: [ReadWord], from start: Int, to end: Int, needsMeasure: Bool) -> Amount? {
        var amountSoFar: Amount?
        var index = start
        while index < end {
            let word = pieces[index]
            // "a kilo of", "an ounce of": one of them.
            if word.plain == "a" || word.plain == "an", index + 1 < end, isMeasure(pieces[index + 1].root),
               !(index > start && pieces[index - 1].root == "half") {
                amountSoFar = Amount(value: 1, measure: pieces[index + 1].root)
                index += 2
                continue
            }
            if var value = number(word) {
                var next = index + 1
                // "half a kilo", "half a dozen".
                if word.root == "half", next < end, pieces[next].plain == "a" || pieces[next].plain == "an" { next += 1 }
                if next < end, pieces[next].root == "dozen", word.root != "dozen" {
                    value *= 12
                    next += 1
                }
                let measure = next < end && isMeasure(pieces[next].root) ? pieces[next].root : nil
                if measure != nil || !needsMeasure {
                    amountSoFar = Amount(value: value, measure: measure)
                }
                index = next
                continue
            }
            index += 1
        }
        return amountSoFar
    }

    // MARK: Reading

    /// Works out what records the words describe.
    static func offers(in text: String, plants: [OfferPlant], beds: [OfferBed]) -> [RecordOffer] {
        let pieces = pieces(of: text)
        let roots = pieces.map(\.root)
        let plantNames = plants.map { names(of: $0) }.filter { !$0.common.isEmpty }
        let bedNames = beds.map { (key: $0.key, nameRoots: JournalChat.roots(in: $0.name)) }

        // Where each doing word is, and what kind it is.
        var doings: [(index: Int, kind: RecordOffer.Kind)] = []
        for (index, word) in pieces.enumerated() {
            var kind: RecordOffer.Kind?
            if harvestWords.contains(word.plain) { kind = .harvest }
            if sowWords.contains(word.plain) { kind = .sowing }
            guard let kind else { continue }

            // "Planted out" moves a sowing on. It is not a new one.
            if word.plain.hasPrefix("plant"), index + 1 < pieces.count, pieces[index + 1].plain == "out" { continue }

            // Planned, wished for or denied: look at the three words before.
            let before = pieces[max(0, index - 3)..<index].filter { $0.sentence == word.sentence }
            if before.contains(where: { notDone.contains($0.plain) }) { continue }
            if pieces.contains(where: { $0.sentence == word.sentence && $0.plain == "tomorrow" }) { continue }

            doings.append((index, kind))
        }

        var made: [RecordOffer] = []
        for (place, doing) in doings.enumerated() {
            let sentence = pieces[doing.index].sentence
            // The stretch this doing word covers: up to the next doing
            // word or the end of its sentence.
            var end = doing.index + 1
            while end < pieces.count, pieces[end].sentence == sentence { end += 1 }
            if place + 1 < doings.count { end = min(end, doings[place + 1].index) }

            let inSentence = Set(pieces.filter { $0.sentence == sentence }.map(\.root))
            let sentenceRoots = pieces.indices.filter { pieces[$0].sentence == sentence }
            let bedKey = bedNames.first { candidate in
                sentenceRoots.contains { matches(candidate.nameRoots, in: roots, at: $0) }
            }?.key

            let plantsNamed = mentions(in: roots, from: doing.index + 1, to: end, plants: plantNames)
            for (order, mention) in plantsNamed.enumerated() {
                // An amount belongs to the plant it comes before. Failing
                // that, to the plant it follows, if it has a measure.
                let before = order == 0 ? doing.index + 1 : plantsNamed[order - 1].start + plantsNamed[order - 1].length
                let after = order + 1 < plantsNamed.count ? plantsNamed[order + 1].start : end
                let amount = amount(in: pieces, from: before, to: mention.start, needsMeasure: false)
                    ?? amount(in: pieces, from: mention.start + mention.length, to: after, needsMeasure: true)

                var quantity: Double?
                var unit: HarvestUnit?
                if let amount {
                    if doing.kind == .harvest {
                        if let measure = amount.measure, let known = units[measure] {
                            quantity = amount.value
                            unit = known
                        } else if let measure = amount.measure, let old = imperial[measure] {
                            // Kilograms to two decimal places, grams whole.
                            let turned = amount.value * old.each
                            quantity = old.unit == .kilograms ? (turned * 100).rounded() / 100 : turned.rounded()
                            unit = old.unit
                        } else if amount.measure == nil {
                            quantity = amount.value
                            unit = .count
                        }
                    } else if amount.measure == nil || amount.measure == "seed" {
                        // Seeds are whole. "Two rows" is not a number of seeds.
                        if amount.value == amount.value.rounded() { quantity = amount.value }
                    }
                }

                let destination = doing.kind == .harvest
                    ? destinations.first { !$0.1.isDisjoint(with: inSentence) }?.0 : nil
                var sownWhere: SowingLocation?
                if doing.kind == .sowing {
                    sownWhere = locations.first { !$0.1.isDisjoint(with: inSentence) }?.0
                    if sownWhere == nil, inSentence.contains("under"), inSentence.contains("cover") { sownWhere = .undercover }
                    if sownWhere == nil, inSentence.contains("cold"), inSentence.contains("frame") { sownWhere = .undercover }
                }

                // The same plant twice for the same kind of record is one offer.
                if made.contains(where: { $0.kind == doing.kind && $0.plantKeys == mention.plantKeys }) { continue }
                made.append(RecordOffer(id: "\(doing.kind.rawValue)-\(made.count)", kind: doing.kind,
                                         plantKeys: mention.plantKeys, quantity: quantity, unit: unit,
                                         destination: destination, bedKey: bedKey, sownWhere: sownWhere))
            }
        }
        return made
    }
}
