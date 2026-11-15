//
//  FITTargets.swift
//  Windfall
//
//  Naming the flower a FIT Count watches.
//
//  William, 15 November 2026: "FIT count shortcut to be more
//  streamlined. When typing in a plant name, the plants you're growing
//  should appear."
//
//  Until then the name was typed out in full, the count was never
//  joined to the plant's own record, and "On the PoMS target list" was
//  ticked from memory.
//
//  FITTargetFlower   one of the flowers the scheme asks counters to use
//  FITSuggestion     one line offered under the name box
//  FITTargets        the list of target flowers, the test for whether a
//                    name is one of them, and the suggestions for what
//                    has been typed
//
//  Nothing here draws anything, so all of it can be tested without a
//  screen (Tools/checks/LogicTests.swift). The lines themselves are
//  drawn in SurveyViews.swift.
//
//  ⚠️ CHECK: the fourteen flowers are from the scheme's own "FIT Count
//  target flower guide", version 3, read by Claude on 15 November 2026
//  (ceh.ac.uk/sites/default/files/FIT%20Count%20flower%20guide%20v3.pdf).
//  How a name is matched to each of them is Claude's own choice. William
//  has not checked either.
//

import Foundation

// MARK: - A target flower

/// One of the flowers the Pollinator Monitoring Scheme asks counters to
/// use where they can.
struct FITTargetFlower: Identifiable {

    /// The name as the scheme gives it. Also what is written into the
    /// count when this is chosen from the suggestions.
    let name: String
    /// How a Latin name for it begins, in lower case. "crataegus" takes
    /// in every hawthorn. "centaurea nigra" takes in one knapweed only.
    let latin: [String]
    /// Pieces of an everyday name that mean this flower. They are
    /// compared with the name squashed (see `FITTargets.squash`), so
    /// "whitedeadnettle" finds "White Dead-nettle" and "white deadnettle".
    var pieces: [String] = []
    /// Whole everyday names that mean this flower, squashed. For a name
    /// too short to look for inside others: "ivy" is in "ground ivy",
    /// which is a different plant.
    var wholeNames: [String] = []
    /// Pieces that rule a name out: a giant hogweed is not the target.
    var unless: [String] = []

    /// `Identifiable` asks for something that tells one from another.
    var id: String { name }
}

// MARK: - A suggestion

/// One line offered under the name box.
struct FITSuggestion: Identifiable {

    let id: String
    /// What goes in the box when this is chosen.
    let title: String
    /// The smaller line underneath: the Latin name, and whether it is a
    /// target flower.
    let detail: String?
    /// The plant's own record, when this is one of the gardener's
    /// plants. Nil for a target flower offered by name alone.
    let plant: Plant?
    /// True when the scheme lists this flower as a target.
    let isTarget: Bool
    /// True when the plant's record says it flowers this month.
    let isInFlower: Bool
}

// MARK: - The list and the matching

enum FITTargets {

    /// The fourteen target flowers, in the guide's order: by the month
    /// each usually starts to flower.
    static let flowers: [FITTargetFlower] = [
        FITTargetFlower(name: "Dandelion", latin: ["taraxacum"], pieces: ["dandelion"]),
        // The guide says "Ranunculus species". Held to the three common
        // buttercups by Latin name, so a lesser celandine or a
        // water-crowfoot (both once Ranunculus) is not ticked. A
        // buttercup squash is a vegetable.
        FITTargetFlower(name: "Buttercup",
                        latin: ["ranunculus acris", "ranunculus repens", "ranunculus bulbosus"],
                        pieces: ["buttercup"], unless: ["squash"]),
        FITTargetFlower(name: "White Dead-nettle", latin: ["lamium album"], pieces: ["whitedeadnettle"]),
        // Water hawthorn is a pond plant and no relation.
        FITTargetFlower(name: "Hawthorn", latin: ["crataegus"], pieces: ["hawthorn"], unless: ["water"]),
        FITTargetFlower(name: "Bramble", latin: ["rubus fruticosus"], pieces: ["bramble", "blackberry"]),
        // English lavender only. "Lavender" by itself is not matched,
        // because Dutch and French lavenders are different plants.
        FITTargetFlower(name: "Lavender (English)", latin: ["lavandula angustifolia"],
                        pieces: ["englishlavender", "lavenderenglish"]),
        FITTargetFlower(name: "Hogweed", latin: ["heracleum sphondylium"], pieces: ["hogweed"], unless: ["giant"]),
        FITTargetFlower(name: "Knapweed", latin: ["centaurea nigra", "centaurea scabiosa"], pieces: ["knapweed"]),
        FITTargetFlower(name: "White Clover", latin: ["trifolium repens"], pieces: ["whiteclover"]),
        // Common ragwort has two Latin names in use, the old and the new.
        FITTargetFlower(name: "Ragwort", latin: ["senecio jacobaea", "jacobaea vulgaris"], pieces: ["ragwort"]),
        FITTargetFlower(name: "Heather", latin: ["calluna"], pieces: ["heather"]),
        // Cirsium and Carduus only. The words after `unless` keep out
        // plants called thistles that are neither.
        FITTargetFlower(name: "Thistle", latin: ["cirsium", "carduus"], pieces: ["thistle"],
                        unless: ["globe", "sow", "milk", "carline", "cotton", "star", "blessed"]),
        FITTargetFlower(name: "Buddleja", latin: ["buddleja davidii", "buddleia davidii"],
                        pieces: ["buddleja", "buddleia", "butterflybush"]),
        FITTargetFlower(name: "Ivy", latin: ["hedera helix"], wholeNames: ["ivy", "commonivy", "englishivy"])
    ]

    /// A name with everything but its letters and numbers taken out, in
    /// lower case and without accents: "White Dead-nettle" becomes
    /// "whitedeadnettle". Two spellings of one name then compare as equal.
    static func squash(_ name: String) -> String {
        String(PlantLetters.key(name).filter { $0.isLetter || $0.isNumber })
    }

    /// The target flower a plant is, or nil if it is none of them.
    ///
    /// The Latin name is tried first, because it cannot be mistaken.
    /// Then the everyday name.
    static func target(name: String, latin: String? = nil) -> FITTargetFlower? {
        let latinKey = PlantLetters.key(latin ?? "")
        if !latinKey.isEmpty,
           let byLatin = flowers.first(where: { flower in flower.latin.contains { latinKey.hasPrefix($0) } }) {
            return byLatin
        }
        let squashed = squash(name)
        guard !squashed.isEmpty else { return nil }
        return flowers.first { flower in
            // `contains(where:)` asks "is any of these true?".
            if flower.unless.contains(where: { squashed.contains($0) }) { return false }
            return flower.wholeNames.contains(squashed) || flower.pieces.contains { squashed.contains($0) }
        }
    }

    /// True when the scheme lists this flower as a target.
    static func isTarget(name: String, latin: String? = nil) -> Bool {
        target(name: name, latin: latin) != nil
    }

    // MARK: Suggestions

    /// How well some words answer what was typed. Smaller is better.
    /// Nil when they do not answer it at all.
    ///
    ///   0  the words begin with what was typed
    ///   1  a later word begins with it
    ///   2  it is somewhere inside a word
    static func closeness(of words: String, to typed: String) -> Int? {
        let key = PlantLetters.key(words)
        guard !typed.isEmpty, !key.isEmpty else { return nil }
        if key.hasPrefix(typed) { return 0 }
        // Splits at anything that is not a letter or number, so the
        // "nettle" of "Dead-nettle" counts as a word.
        let parts = key.split(whereSeparator: { !($0.isLetter || $0.isNumber) })
        if parts.contains(where: { $0.hasPrefix(typed) }) { return 1 }
        return key.contains(typed) ? 2 : nil
    }

    /// What to offer under the name box for what has been typed.
    ///
    /// The plants being grown come first: those whose name, variety or
    /// Latin name has a word that begins with what was typed, with the
    /// ones in flower this month ahead of the rest. A target flower that
    /// none of those plants already is comes after them, so "dan" still
    /// offers Dandelion in a garden that has not planted any.
    ///
    /// - Parameters:
    ///   - typed: what is in the box.
    ///   - plants: the whole plant library. Only plants marked as
    ///     growing are offered.
    ///   - month: 1 for January to 12 for December.
    ///   - limit: the most lines to offer.
    static func suggestions(for typed: String, among plants: [Plant], month: Int, limit: Int = 6) -> [FITSuggestion] {
        let needle = PlantLetters.key(typed)
        guard !needle.isEmpty else { return [] }

        // 1. The gardener's own plants that answer what was typed.
        //    Each is paired with what the sorting needs, worked out once.
        var found: [(plant: Plant, closeness: Int, field: Int, inFlower: Bool, target: FITTargetFlower?)] = []
        for plant in plants where plant.status == .growing {
            // The name, the variety and the Latin name are each tried.
            // `field` remembers which answered best: 0, 1 or 2.
            var best: (closeness: Int, field: Int)?
            for (field, words) in [plant.commonName, plant.variety ?? "", plant.latinName ?? ""].enumerated() {
                guard let closeness = closeness(of: words, to: needle) else { continue }
                if best == nil || closeness < best!.closeness { best = (closeness, field) }
            }
            guard let best else { continue }
            let inFlower = MonthParser.months(in: plant.floweringMonthsText).contains(month)
            found.append((plant, best.closeness, best.field, inFlower,
                          target(name: plant.commonName, latin: plant.latinName)))
        }
        // `sort` is handed a small function that says whether one entry
        // belongs before another. Each `if` settles it where the two
        // differ, and otherwise passes on to the next.
        found.sort { first, second in
            // A word that begins with what was typed, before one that
            // only has it inside.
            let firstBegins = first.closeness < 2, secondBegins = second.closeness < 2
            if firstBegins != secondBegins { return firstBegins }
            // In flower this month, before not.
            if first.inFlower != second.inFlower { return first.inFlower }
            // The start of the name, before a later word.
            if first.closeness != second.closeness { return first.closeness < second.closeness }
            // The name itself, before the variety, before the Latin name.
            if first.field != second.field { return first.field < second.field }
            return PlantLetters.key(first.plant.displayName) < PlantLetters.key(second.plant.displayName)
        }

        // 2. Target flowers that none of those plants already is, and
        //    that have a word beginning with what was typed. One that
        //    only has it inside is left out: "th" should offer Thistle,
        //    not Hawthorn and Heather as well.
        let covered = Set(found.compactMap { $0.target?.name })
        let targets = flowers
            .filter { !covered.contains($0.name) }
            .compactMap { flower -> (flower: FITTargetFlower, closeness: Int)? in
                guard let closeness = closeness(of: flower.name, to: needle), closeness < 2 else { return nil }
                return (flower, closeness)
            }
            .sorted { $0.closeness < $1.closeness }

        // 3. Up to two places are kept back for target flowers, so a
        //    long list of plants cannot push them all off the end.
        let targetPlaces = min(targets.count, 2)
        let plantLines = found.prefix(max(0, limit - targetPlaces)).map { entry in
            FITSuggestion(id: entry.plant.id.uuidString,
                          title: entry.plant.displayName,
                          detail: detail(latin: entry.plant.latinName, isTarget: entry.target != nil),
                          plant: entry.plant,
                          isTarget: entry.target != nil,
                          isInFlower: entry.inFlower)
        }
        let targetLines = targets.prefix(max(0, limit - plantLines.count)).map { entry in
            FITSuggestion(id: "target-\(entry.flower.name)",
                          title: entry.flower.name,
                          detail: "PoMS target flower",
                          plant: nil,
                          isTarget: true,
                          isInFlower: false)
        }
        return plantLines + targetLines
    }

    /// The smaller line under a plant's name: its Latin name, and a
    /// note if it is a target flower.
    private static func detail(latin: String?, isTarget: Bool) -> String? {
        let latinName = (latin ?? "").trimmingCharacters(in: .whitespaces)
        switch (latinName.isEmpty, isTarget) {
        case (true, false): return nil
        case (true, true): return "PoMS target flower"
        case (false, false): return latinName
        case (false, true): return "\(latinName) · PoMS target flower"
        }
    }
}
