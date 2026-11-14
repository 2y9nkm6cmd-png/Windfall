//
//  SpeciesTable.swift
//  Windfall
//
//  Naming what is in a photo: the arithmetic.
//
//  How photo identification works here, in three steps:
//
//    1. The photo is cut to its middle square, shrunk to 224 by 224
//       pixels, and its colours turned into the numbers the model
//       expects. (PhotoArithmetic, below, and SpeciesEye.swift.)
//    2. BioCLIP, a model trained only on living things, turns those
//       into a list of numbers that describe what the photo looks like:
//       768 of them from BioCLIP 2, or 1,024 from BioCLIP 2.5 Huge,
//       which took its place on the Mac on 14 November 2026.
//       (SpeciesEye.swift. This is the only step that needs Core AI.)
//    3. Those numbers are compared with one row of as many numbers for
//       each species. The closest rows are the likeliest species. The
//       table says how many numbers its rows hold, so either model
//       works as long as the table beside it was made for it.
//       (SpeciesTable, below.)
//
//  The rows are made on the Mac from the names of UK species, nudged by
//  real UK photographs. They arrive as two files:
//
//    uk_species.json            who each row is, and two settings
//    uk_species_rows_f16.bin    the rows themselves
//
//  Nothing in this file needs Apple's AI frameworks, so all of it is
//  covered by the logic tests that run without a Mac.
//

import Foundation

// MARK: - A species and a guess

/// One species a photo can be matched to: one row of the table.
struct SpeciesEntry: Codable, Equatable {
    /// The scientific name, such as "Bombus terrestris".
    var scientific: String
    /// The English name, where there is one.
    var common: String?
    /// The broad group it was listed under, such as "Insecta" or "Plantae".
    var group: String
    /// True when its row was nudged by real photographs. False when
    /// there were too few, so its row comes from its name alone.
    var taught: Bool

    /// "Buff-tailed Bumblebee (Bombus terrestris)", or the scientific
    /// name alone where there is no English one.
    var title: String {
        guard let common, !common.isEmpty else { return scientific }
        return "\(common) (\(scientific))"
    }

    /// Fungi are never named from a photo. A mistake can be fatal.
    var isFungus: Bool { group.lowercased().hasPrefix("fung") }
}

/// One species the photo might be, and how strongly.
struct SpeciesCandidate: Equatable {
    var entry: SpeciesEntry
    /// Its share of the model's belief, from 0 to 1. The shares of all
    /// the species in the table add up to 1.
    var share: Double

    /// The share as words: "97%", "under 1%", "over 99%".
    var percent: String {
        if share > 0.995 { return "over 99%" }
        let whole = Int((share * 100).rounded())
        return whole < 1 ? "under 1%" : "\(whole)%"
    }
}

/// What came back for one photo.
struct SpeciesGuess: Equatable {
    /// The closest species, most likely first.
    var candidates: [SpeciesCandidate]
    /// True only when the top one is strong enough to name. Otherwise
    /// the candidates are possibilities and nothing more.
    var isSure: Bool

    var likeliest: SpeciesCandidate? { candidates.first }

    /// A warning to show above the candidates when a wrong name among
    /// them could kill, or nil. See DangerousLookAlikes.
    var lookAlikeWarning: String? { DangerousLookAlikes.warning(for: candidates) }

    /// The guess in sentences, for the screen.
    var summary: String {
        guard let first = candidates.first else {
            return "There is nothing to compare the photo with."
        }
        let others = candidates.dropFirst()
            .map { "\($0.entry.title), \($0.percent)" }
            .joined(separator: "; ")

        if isSure {
            var text = "This looks like \(first.entry.title). The model puts it at \(first.percent)."
            if !others.isEmpty { text += "\n\nNext closest: \(others)." }
            return text
        }
        var text = "Not sure. The closest matches are \(first.entry.title), \(first.percent)"
        text += others.isEmpty ? "." : "; \(others)."
        text += "\n\nNone is strong enough to name. A closer or sharper photo may help. It may also be something the model was never shown."
        return text
    }
}

// MARK: - Dangerous look-alikes

/// Plants where a wrong name could kill.
///
/// Why this exists. On 14 November 2026 the same 300 UK photos were run
/// through the app with two image models. The older one named a photo
/// of hemlock water-dropwort as yellow iris, at 87%. The newer one
/// (BioCLIP 2.5 Huge) named a photo of hemlock as cow parsley at over
/// 99%, where the older had said "not sure". Both plants are deadly,
/// both are in the carrot family, and in both cases a carrot-family
/// plant was among the three candidates shown.
///
/// So when any of the three is a carrot-family plant, the screen says
/// so in plain sight, above the names, however sure the model is. The
/// line under every answer ("never eat anything on the strength of a
/// match") still stands for everything else.
///
/// Only the carrot family is here. Other dangerous pairs (wild garlic
/// and lords-and-ladies, comfrey and foxglove) each need a checked list
/// before they are added.
enum DangerousLookAlikes {

    /// The genus (the first word of a scientific name) of each
    /// carrot-family plant likely to be met in a UK garden or hedge.
    /// The family's botanical name is Apiaceae. Its flowers are held in
    /// flat-topped clusters shaped like an umbrella.
    ///
    /// A `Set` is a list with no order and no repeats, which makes
    /// "is this name in it?" quick to answer.
    static let carrotFamilyGenera: Set<String> = [
        "Aegopodium",    // ground elder
        "Aethusa",       // fool's parsley
        "Ammi",          // bishop's flower
        "Anethum",       // dill
        "Angelica",      // angelica
        "Anthriscus",    // cow parsley, chervil
        "Apium",         // celery, celeriac, wild celery
        "Berula",        // lesser water-parsnip
        "Carum",         // caraway
        "Chaerophyllum", // rough chervil
        "Cicuta",        // cowbane
        "Conium",        // hemlock
        "Conopodium",    // pignut
        "Coriandrum",    // coriander
        "Crithmum",      // rock samphire
        "Daucus",        // carrot, wild carrot
        "Foeniculum",    // fennel
        "Helosciadium",  // fool's watercress
        "Heracleum",     // hogweed, giant hogweed
        "Levisticum",    // lovage
        "Myrrhis",       // sweet cicely
        "Oenanthe",      // the water-dropworts
        "Pastinaca",     // parsnip
        "Petroselinum",  // parsley
        "Pimpinella",    // burnet-saxifrage, anise
        "Scandix",       // shepherd's needle
        "Silaum",        // pepper-saxifrage
        "Sison",         // stone parsley
        "Sium",          // greater water-parsnip, skirret
        "Smyrnium",      // alexanders
        "Torilis"        // the hedge parsleys
    ]

    /// What the screen says when a carrot-family plant is among the
    /// candidates.
    static let carrotFamilyWarning = "Take care: this may be one of the carrot family. That family holds deadly plants, hemlock and hemlock water-dropwort among them, that look much like cow parsley, wild carrot, wild celery and parsley. A photo cannot tell them apart safely. If you did not sow it yourself, do not eat any part of it on the strength of this, and wear gloves to handle it: giant hogweed, of the same family, burns the skin."

    /// "Conium" from "Conium maculatum".
    static func genus(of scientific: String) -> String {
        scientific.split(separator: " ").first.map(String.init) ?? ""
    }

    /// True for a plant whose genus is in the list.
    ///
    /// The group is checked as well as the name, because an animal can
    /// share a plant's genus name: Oenanthe is the water-dropworts and
    /// also the wheatears, which are birds.
    static func isCarrotFamily(_ entry: SpeciesEntry) -> Bool {
        entry.group.lowercased().hasPrefix("plant") && carrotFamilyGenera.contains(genus(of: entry.scientific))
    }

    /// The warning for a set of candidates, or nil if none calls for one.
    static func warning(for candidates: [SpeciesCandidate]) -> String? {
        candidates.contains { isCarrotFamily($0.entry) } ? carrotFamilyWarning : nil
    }
}

// MARK: - The table

/// The rows a photo is compared with, and the two settings that go
/// with them.
struct SpeciesTable {

    let species: [SpeciesEntry]
    /// How many numbers are in each row. 768 for BioCLIP 2, 1,024 for
    /// BioCLIP 2.5 Huge.
    let width: Int
    /// How sharply the model separates a good match from a poor one.
    /// It comes from BioCLIP 2 itself and is not ours to choose.
    let scale: Float
    /// The share the top answer must reach before it is named. It was
    /// set on the Mac so that a named answer is right 19 times in 20
    /// on photos the model had not seen. Nil means no level did that,
    /// and then nothing is ever named outright.
    let notSureFloor: Double?
    /// The day the table was made, for showing in Settings.
    let made: String?

    /// Every row end to end: species.count times width numbers.
    private let numbers: [Float]

    enum Problem: LocalizedError, Equatable {
        case unreadable
        case wrongSize(expected: Int, found: Int)

        var errorDescription: String? {
            switch self {
            case .unreadable:
                return "The species list could not be read."
            case .wrongSize(let expected, let found):
                return "The species rows do not match the species list: \(expected) bytes were expected and \(found) were found."
            }
        }
    }

    /// The shape of uk_species.json. `CodingKeys` maps the file's
    /// names, written with underscores, onto Swift's.
    private struct Listing: Decodable {
        var rows: Int
        var width: Int
        var scale: Double
        var notSureFloor: Double?
        var made: String?
        var species: [SpeciesEntry]

        enum CodingKeys: String, CodingKey {
            case rows, width, scale, made, species
            case notSureFloor = "not_sure_floor"
        }
    }

    /// Reads the two files.
    ///
    /// The rows file holds "half-precision" numbers: two bytes each
    /// where an ordinary Float takes four. That halves the file, and the
    /// model's own numbers are no more exact than that.
    init(listing: Data, rowBytes: Data) throws {
        guard let read = try? JSONDecoder().decode(Listing.self, from: listing),
              read.width > 0, read.species.count == read.rows else {
            throw Problem.unreadable
        }
        let expected = read.rows * read.width * 2
        guard rowBytes.count == expected else {
            throw Problem.wrongSize(expected: expected, found: rowBytes.count)
        }

        var all = [Float](repeating: 0, count: read.rows * read.width)
        rowBytes.withUnsafeBytes { raw in
            for index in 0..<all.count {
                // Two bytes, low one first, make one half-size number.
                let bits = UInt16(raw[index * 2]) | (UInt16(raw[index * 2 + 1]) << 8)
                all[index] = SpeciesTable.float(fromHalf: bits)
            }
        }

        self.init(species: read.species, width: read.width, scale: Float(read.scale),
                  notSureFloor: read.notSureFloor, made: read.made, numbers: all)
    }

    /// Builds a table from values already in hand. Any fungi are left
    /// out here, so a list that included them still could not name one.
    init(species: [SpeciesEntry], width: Int, scale: Float,
         notSureFloor: Double?, made: String? = nil, numbers: [Float]) {
        var kept: [SpeciesEntry] = []
        var keptNumbers: [Float] = []
        for (index, entry) in species.enumerated() where !entry.isFungus {
            let begin = index * width
            guard begin + width <= numbers.count else { break }
            kept.append(entry)
            keptNumbers.append(contentsOf: numbers[begin..<(begin + width)])
        }
        self.species = kept
        self.width = width
        self.scale = scale
        self.notSureFloor = notSureFloor
        self.made = made
        self.numbers = keptNumbers
    }

    /// Turns the 16 bits of a half-size number into an ordinary Float.
    ///
    /// The bits are: 1 for the sign, 5 for the power of two and 10 for
    /// the fraction. Worked out by hand here, and not with Swift's
    /// Float16, because Float16 does not exist on older Intel Macs.
    nonisolated static func float(fromHalf bits: UInt16) -> Float {
        let isNegative = (bits >> 15) == 1
        let power = Int((bits >> 10) & 0x1F)
        let fraction = Float(bits & 0x3FF)
        let sign: FloatingPointSign = isNegative ? .minus : .plus

        switch power {
        case 0:
            // Zero, or a number too small for the usual form.
            return Float(sign: sign, exponent: -24, significand: fraction)
        case 31:
            return fraction == 0 ? (isNegative ? -Float.infinity : Float.infinity) : Float.nan
        default:
            return Float(sign: sign, exponent: power - 15, significand: 1 + fraction / 1024)
        }
    }

    /// Compares a photo's numbers with every row and returns the
    /// closest few.
    ///
    /// For each species the photo's numbers and the row's are
    /// multiplied pair by pair and added up. Both are scaled to length
    /// 1 first, so that sum is how closely they point the same way: 1
    /// for identical, 0 for unrelated. The sums are then turned into
    /// shares that add up to 1 (the "softmax" step), which is what the
    /// "not sure" level was measured against.
    func guess(for photo: [Float], keeping count: Int = 3) -> SpeciesGuess {
        guard photo.count == width, !species.isEmpty else {
            return SpeciesGuess(candidates: [], isSure: false)
        }

        // Scale the photo's numbers to length 1.
        let length = photo.reduce(Float(0)) { $0 + $1 * $1 }.squareRoot()
        let pointing = length > 0 ? photo.map { $0 / length } : photo

        var scores = [Float](repeating: 0, count: species.count)
        numbers.withUnsafeBufferPointer { all in
            pointing.withUnsafeBufferPointer { mine in
                for row in 0..<species.count {
                    var sum: Float = 0
                    let begin = row * width
                    for column in 0..<width { sum += all[begin + column] * mine[column] }
                    scores[row] = sum * scale
                }
            }
        }

        // Shares. The highest score is taken off every score first.
        // That changes none of the shares and stops the numbers
        // growing too large to hold.
        let highest = scores.max() ?? 0
        let weights = scores.map { Foundation.exp(Double($0 - highest)) }
        let total = weights.reduce(0, +)

        let order = scores.indices.sorted { scores[$0] > scores[$1] }.prefix(max(1, count))
        let candidates = order.map {
            SpeciesCandidate(entry: species[$0], share: total > 0 ? weights[$0] / total : 0)
        }

        let topShare = candidates.first?.share ?? 0
        let isSure = notSureFloor.map { topShare >= $0 } ?? false
        return SpeciesGuess(candidates: candidates, isSure: isSure)
    }

    /// What the model can and cannot do, said once under any answer.
    ///
    /// The second sentence was added on 14 November 2026. Of 300 UK
    /// photos run through the app, one of hemlock water-dropwort, which
    /// is deadly, was named as yellow iris at 87%, and hemlock itself
    /// was read as cow parsley or chervil. A match must never be the
    /// reason to eat a plant. For the carrot family there is a louder
    /// warning as well: see DangerousLookAlikes.
    var caveat: String {
        "It can only choose among the \(species.count) UK species it was given, and it never names fungi. Never eat anything, or handle a plant that may be poisonous, on the strength of a match: it can mistake a deadly plant for a harmless one. Treat a match as a suggestion to check."
    }
}

// MARK: - Preparing a photo

/// The sums that turn a photo into what BioCLIP 2 expects. The values
/// are BioCLIP 2's own, read from the settings file that came with it.
enum PhotoArithmetic {

    /// The model looks at a square this many pixels on a side.
    nonisolated static let side = 224

    /// For red, green and blue: the average the model was trained to
    /// expect, and how far colours usually spread around it. Each
    /// colour value has the average taken off and is divided by the
    /// spread, so that typical photos give numbers centred on zero.
    nonisolated static let averages: [Float] = [0.48145466, 0.4578275, 0.40821073]
    nonisolated static let spreads: [Float] = [0.26862954, 0.26130258, 0.27577711]

    /// The part of a photo that is kept: the largest square in its
    /// middle. A wide photo loses its two ends and a tall one its top
    /// and bottom.
    nonisolated static func middleSquare(width: Int, height: Int) -> (x: Int, y: Int, side: Int) {
        let side = max(0, min(width, height))
        return (x: (width - side) / 2, y: (height - side) / 2, side: side)
    }

    /// One colour value, 0 to 255, as the model wants it.
    /// `colour` is 0 for red, 1 for green and 2 for blue.
    nonisolated static func adjusted(_ value: UInt8, colour: Int) -> Float {
        (Float(value) / 255 - averages[colour]) / spreads[colour]
    }

    /// Rearranges a square picture for the model.
    ///
    /// A picture in memory is pixel after pixel, each as four bytes:
    /// red, green, blue and a spare. The model wants all the reds
    /// first, then all the greens, then all the blues, each adjusted
    /// as above. Returns nil if the bytes are not a whole square.
    nonisolated static func planar(fromRGBA bytes: [UInt8], side: Int) -> [Float]? {
        let pixels = side * side
        guard side > 0, bytes.count == pixels * 4 else { return nil }
        var result = [Float](repeating: 0, count: pixels * 3)
        for pixel in 0..<pixels {
            for colour in 0..<3 {
                result[colour * pixels + pixel] = adjusted(bytes[pixel * 4 + colour], colour: colour)
            }
        }
        return result
    }
}
