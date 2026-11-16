//
//  PacketReading.swift
//  Windfall
//
//  Working out what a seed packet says, from the words read off it.
//
//  Reading a packet is two jobs. The first is turning a photo into
//  words, which Apple's Vision does (SeedPacketScanner.swift). The
//  second is deciding what the words mean: which is the plant's name,
//  which months are for sowing and which for flowering, how far apart
//  to thin. That second job is this file.
//
//  Until 15 November 2026 the second job was done inside the scanner,
//  one line of the photo at a time. William scanned his first real
//  packet that evening, Linaria 'Fairy Bouquet Mixed' from Country
//  Value, and it filled 4 of about 16 things, 3 of them wrongly. The
//  reasons are in Design/Reference/seed-packets, and each has an answer
//  here:
//
//  1. Vision gives a line at a time, and a packet's sentences run over
//     two lines ("Seedlings appear" / "14-21 days."). So the lines are
//     first joined back into sentences.
//  2. "sow" was found inside "sowings". Words are now matched whole.
//  3. "March to May and August to September" lost April. Each range is
//     now read by itself (MonthParser.spans, in Parsing.swift).
//  4. The name was guessed from the first short line. It is now the
//     line that names a plant you have, or failing that the tallest.
//  5. The little headings beside each block (SOW, CARE, FLOWERS) say
//     what the block is about, and are now used.
//
//  This file has no `import SwiftUI` and no `import Vision`. It is
//  handed plain lines of text, so it can be tested without a Mac: the
//  Linaria packet's lines are a test that must keep giving the right
//  answers (Tools/checks/LogicTests.swift).
//
//  New things here:
//
//  struct            A small bundle of values that travel together. A
//                    `PacketLine` is a line's words bundled with how
//                    sure Vision was and where on the photo it sat.
//
//  [PacketLine]      Square brackets mean "a list of". The reader is
//                    handed a list of lines and hands back a list of
//                    findings.
//
//  Pattern.first     A helper from PlantFillIn.swift that looks for a
//                    "regular expression", a pattern for finding text.
//                    `\d+` is one or more digits, `(cm|mm)` is either
//                    of those, `\b` is the edge of a word, and what is
//                    in round brackets is handed back as a "group".
//

import Foundation

// MARK: - What the reader is given

/// Which face of the packet a photo shows.
enum PacketSide: String, CaseIterable, Identifiable {
    case front, back

    var id: String { rawValue }

    /// As a heading: "Front", "Back".
    var title: String { self == .front ? "Front" : "Back" }
    /// Inside a sentence: "the front", "the back".
    var words: String { self == .front ? "the front" : "the back" }
}

/// One line of words read from a photo of a packet.
struct PacketLine: Equatable {
    var text: String
    /// How sure the reader was of the letters, from 0 to 1.
    var confidence: Double = 1
    /// Where the line sat on the photo, each as a share of the photo's
    /// size from 0 to 1: its left and right edges across, its top edge
    /// down from the top, and its height. All zero when not known, as
    /// in a test typed out by hand.
    var left: Double = 0
    var right: Double = 0
    var top: Double = 0
    var height: Double = 0
    var side: PacketSide = .back

    /// True when the line's place on the photo is known.
    var hasPlace: Bool { height > 0 }
    /// How far down the photo the middle of the line is.
    var middle: Double { top + height / 2 }
}

// MARK: - What the reader hands back

/// The things a packet can tell us, in the order they are shown.
enum PacketField: String, CaseIterable, Identifiable {
    case plantName, variety, latinName, lifeCycle, sun, soil
    case sowIndoors, sowOutdoors, sowingTime, plantOut, flowering, harvest
    case germination, sowingDepth, spacing, rowSpacing, height, successions
    case useBy, seedCount, supplier, barcode

    var id: String { rawValue }

    /// What the scan sheet calls it.
    var label: String {
        switch self {
        case .plantName: return "Plant"
        case .variety: return "Variety"
        case .latinName: return "Latin name"
        case .lifeCycle: return "Life cycle"
        case .sun: return "Sun or shade"
        case .soil: return "Soil"
        case .sowIndoors: return "Sow indoors"
        case .sowOutdoors: return "Sow outdoors"
        case .sowingTime: return "Sowing time"
        case .plantOut: return "Plant out"
        case .flowering: return "Flowering"
        case .harvest: return "Harvest"
        case .germination: return "Germination"
        case .sowingDepth: return "Sowing depth"
        case .spacing: return "Spacing between plants"
        case .rowSpacing: return "Spacing between rows"
        case .height: return "Height"
        case .successions: return "Sowing again"
        case .useBy: return "Sow by"
        case .seedCount: return "Approx. seed count"
        case .supplier: return "Supplier"
        case .barcode: return "Barcode"
        }
    }

    /// The box of the plant's record it fills, by its key in
    /// PlantFacts.swift. Nil for what belongs to the packet and not to
    /// the plant (the supplier, the sow-by date), and for what the
    /// record has no box for (the rows, the barcode), which go into the
    /// packet's notes.
    var plantKey: String? {
        switch self {
        case .variety: return "variety"
        case .latinName: return "latinName"
        case .lifeCycle: return "classification"
        case .sun: return "sunShade"
        case .soil: return "preferredSoilConditions"
        case .sowIndoors: return "sowIndoorsMonthsText"
        case .sowOutdoors, .sowingTime: return "sowOutdoorsMonthsText"
        case .plantOut: return "plantOutMonthsText"
        case .flowering: return "floweringMonthsText"
        case .harvest: return "harvestMonthsText"
        case .germination: return "germinationDaysText"
        case .sowingDepth: return "sowingDepthMM"
        case .spacing: return "spacingM"
        case .height: return "maxHeightM"
        case .plantName, .rowSpacing, .successions, .useBy, .seedCount, .supplier, .barcode: return nil
        }
    }

    /// True for the things that are a set of months.
    var isMonths: Bool {
        [.sowIndoors, .sowOutdoors, .sowingTime, .plantOut, .flowering, .harvest].contains(self)
    }

    /// True for what goes into the packet's notes, there being no box.
    var goesInNotes: Bool { [.rowSpacing, .successions, .barcode].contains(self) }
}

/// One thing read from a packet.
struct PacketFinding: Equatable {
    let field: PacketField
    /// As it is shown: "March, April and May", "15 cm", "Hardy annual".
    var value: String
    /// How far to trust it, from 0 to 1: how sure the letters were,
    /// times how tight the rule that found it is.
    let confidence: Double
    /// The words on the packet it was read from.
    let sourceText: String
    let side: PacketSide
}

// MARK: - The reader

enum PacketReading {

    // MARK: Headings

    /// The little headings a packet prints above or beside each block
    /// of its instructions.
    enum Heading: Equatable {
        case sow, sowIndoors, sowOutdoors, plantOut, care, flowers, harvest, tip
        /// A heading that divides the packet but says nothing of what
        /// follows: "GROWING INSTRUCTIONS".
        case other

        /// What a bare "June to October." means under this heading.
        var monthField: PacketField? {
            switch self {
            case .sow: return .sowingTime
            case .sowIndoors: return .sowIndoors
            case .sowOutdoors: return .sowOutdoors
            case .plantOut: return .plantOut
            case .flowers: return .flowering
            case .harvest: return .harvest
            case .care, .tip, .other: return nil
            }
        }

        /// Words a sentence under this heading is likely to hold. Used
        /// only to work out which block a heading belongs to (see
        /// `giveHeadings`).
        var tellTales: [String] {
            switch self {
            case .sow, .sowIndoors, .sowOutdoors: return ["sow", "seed", "germinat", "cover", "drill"]
            case .plantOut: return ["plant", "harden", "frost"]
            case .care: return ["thin", "water", "keep", "feed", "weed", "support", "pinch", "stake", "mulch"]
            case .flowers: return ["flower", "bloom"]
            case .harvest: return ["harvest", "pick", "crop", "lift", "ripe", "store"]
            case .tip, .other: return []
            }
        }
    }

    private static let headingWords: [String: Heading] = [
        "sow": .sow, "sowing": .sow, "when to sow": .sow, "how to sow": .sow, "sowing time": .sow,
        "sow indoors": .sowIndoors, "sow inside": .sowIndoors, "sow under glass": .sowIndoors, "indoors": .sowIndoors,
        "sow outdoors": .sowOutdoors, "sow outside": .sowOutdoors, "sow direct": .sowOutdoors, "outdoors": .sowOutdoors,
        "plant out": .plantOut, "planting out": .plantOut, "transplant": .plantOut, "plant": .plantOut,
        "care": .care, "aftercare": .care, "grow": .care, "growing": .care, "growing on": .care,
        "flowers": .flowers, "flower": .flowers, "flowering": .flowers, "flowering time": .flowers, "in flower": .flowers,
        "harvest": .harvest, "harvesting": .harvest, "crop": .harvest, "cropping": .harvest, "pick": .harvest,
        "tip": .tip, "tips": .tip, "top tip": .tip, "handy tip": .tip,
        "growing instructions": .other, "instructions": .other, "how to grow": .other, "cultivation": .other,
        "description": .other, "sowing instructions": .other, "growing guide": .other, "sowing guide": .other
    ]

    /// The heading a line is, if it is one. A heading is a few words in
    /// capitals, or ending in a colon, that are in the list above:
    /// "SOW", "FLOWERS", "Harvest:". The sentence "Sow thinly in rows"
    /// is not one.
    static func heading(of text: String) -> Heading? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let endsInColon = trimmed.hasSuffix(":")
        let letters = trimmed.filter(\.isLetter)
        let isCapitals = !letters.isEmpty && letters == letters.uppercased()
        guard isCapitals || endsInColon else { return nil }
        let words = EiraSafety.tidied(trimmed).trimmingCharacters(in: .whitespaces)
        return headingWords[words]
    }

    // MARK: Sentences

    /// A sentence put back together from the lines it was printed
    /// across, with the heading of the block it is in.
    struct Sentence: Equatable {
        var text: String
        /// The least sure of the lines it came from.
        var confidence: Double
        /// Which of the lines handed in it begins on, counting from 0.
        var firstLine: Int
        var side: PacketSide
        var blockHeading: Heading?
    }

    /// Words a line may end on only if the sentence carries on below:
    /// "Sow by" / "DEC 2028".
    private static let hangingWords: Set<String> = ["a", "an", "the", "and", "or", "to", "of", "in", "at", "by", "for",
                                                    "with", "from", "until", "on", "into", "when", "then", "is", "are",
                                                    "be", "as", "about", "approx", "every", "appear", "before", "after"]

    /// True for a line that is only digits: half of a barcode's number.
    private static func isOnlyDigits(_ text: String) -> Bool {
        let bare = text.filter { !$0.isWhitespace }
        return !bare.isEmpty && bare.allSatisfy(\.isNumber)
    }

    /// True when `next` carries on the sentence `previous` left open.
    private static func carriesOn(_ previous: String, _ next: String) -> Bool {
        guard let lastLetter = previous.last, !".!?:".contains(lastLetter) else { return false }
        guard let firstLetter = next.first else { return false }
        if lastLetter == "," || lastLetter == "-" { return true }
        if firstLetter.isLowercase || firstLetter.isNumber { return true }
        let lastWord = previous.split(separator: " ").last.map { $0.lowercased() } ?? ""
        return hangingWords.contains(lastWord)
    }

    /// The lines of one side joined back into sentences.
    ///
    /// A heading ends whatever came before it. So does a line of bare
    /// digits. Otherwise a line is joined to the one before when that
    /// one stopped in the middle of a sentence, and then the whole is
    /// cut at its full stops.
    static func sentences(from printed: [PacketLine]) -> [Sentence] {
        // A heading with its words on the same line, "Harvest: July to
        // October", is first made two lines: the heading and the rest.
        var lines: [PacketLine] = []
        for packetLine in printed {
            if let match = Pattern.first("^([A-Za-z ]{3,24}:)\\s+(\\S.*)$", in: packetLine.text.trimmingCharacters(in: .whitespaces)),
               heading(of: match[1]) != nil {
                var label = packetLine, rest = packetLine
                label.text = match[1]
                rest.text = match[2]
                lines += [label, rest]
            } else {
                lines.append(packetLine)
            }
        }
        var result: [Sentence] = []
        // The run of joined lines being built: its words so far, where
        // each line began in them, and the least confidence.
        var joined = ""
        var starts: [(at: Int, line: Int)] = []
        var least = 1.0
        var runSide = PacketSide.back

        func finishRun() {
            guard !joined.isEmpty else { return }
            // Cut the joined into sentences, and find which line each
            // sentence begins on by counting letters.
            var position = 0
            for piece in PageFacts.sentencesOf(joined) {
                let found = joined.range(of: piece, range: joined.index(joined.startIndex, offsetBy: min(position, joined.count))..<joined.endIndex)
                let at = found.map { joined.distance(from: joined.startIndex, to: $0.lowerBound) } ?? position
                let line = starts.last(where: { $0.at <= at })?.line ?? starts.first?.line ?? 0
                result.append(Sentence(text: piece, confidence: least, firstLine: line, side: runSide, blockHeading: nil))
                position = at + piece.count
            }
            joined = ""; starts = []; least = 1.0
        }

        for (index, packetLine) in lines.enumerated() {
            let words = packetLine.text.trimmingCharacters(in: .whitespaces)
            guard !words.isEmpty else { continue }
            if heading(of: words) != nil || isOnlyDigits(words) {
                finishRun()
                continue
            }
            if !joined.isEmpty, packetLine.side == runSide, carriesOn(joined, words) {
                joined += " "
            } else {
                finishRun()
            }
            starts.append((joined.count, index))
            joined += words
            least = min(least, packetLine.confidence)
            runSide = packetLine.side
        }
        finishRun()
        return giveHeadings(to: result, lines: lines)
    }

    /// Works out which heading each sentence sits under.
    ///
    /// This is harder than it sounds, because packets differ. Some
    /// print the heading above its block. Country Value prints it to
    /// the left, under a little picture, and Vision then reads it
    /// *after* the first lines of the block it belongs to.
    ///
    /// So both ways are tried: "each sentence belongs to the heading
    /// before it" and "to the heading after it". The way that puts more
    /// sentences under a heading that suits them wins: more sentences
    /// about sowing under SOW, more about thinning under CARE. Where
    /// the lines' places on the photo are known and the headings stand
    /// to the left of the words, the places settle it instead.
    private static func giveHeadings(to sentences: [Sentence], lines: [PacketLine]) -> [Sentence] {
        // Each heading, with the line it is.
        let headings: [(line: Int, kind: Heading)] = lines.enumerated().compactMap { index, packetLine in
            heading(of: packetLine.text).map { (index, $0) }
        }
        guard !headings.isEmpty else { return sentences }

        func suits(_ ofPacket: Sentence, _ headingTried: Heading?) -> Bool {
            guard let headingTried else { return false }
            let lower = ofPacket.text.lowercased()
            return headingTried.tellTales.contains { lower.contains($0) }
        }
        // The heading before a sentence, on its own side.
        func before(_ ofPacket: Sentence) -> Heading? {
            headings.last { $0.line < ofPacket.firstLine && lines[$0.line].side == ofPacket.side }?.kind
        }
        // The heading after it. A dividing heading in the way means the
        // sentence belongs to neither: "Great for mixed planters" sits
        // above GROWING INSTRUCTIONS, not under SOW.
        func after(_ ofPacket: Sentence) -> Heading? {
            guard let next = headings.first(where: { $0.line > ofPacket.firstLine && lines[$0.line].side == ofPacket.side }),
                  next.kind != .other else { return nil }
            return next.kind
        }
        // By place: the first heading to the left whose middle is level
        // with the sentence's first line or below it.
        func beside(_ ofPacket: Sentence) -> Heading? {
            let first = lines[ofPacket.firstLine]
            let lineHeight = max(first.height, 0.001)
            let below = headings
                .filter { lines[$0.line].side == ofPacket.side && lines[$0.line].middle >= first.middle - lineHeight * 1.5 }
                .min { lines[$0.line].middle < lines[$1.line].middle }
            guard let below, below.kind != .other,
                  lines[below.line].middle - first.middle <= lineHeight * 8 else { return nil }
            return below.kind
        }

        // Do the headings stand to the left of the words? Only asked
        // when every line's place is known.
        let allPlaced = lines.allSatisfy(\.hasPlace)
        let bodyLefts = sentences.map { lines[$0.firstLine].left }.sorted()
        let middleLeft = bodyLefts.isEmpty ? 0 : bodyLefts[bodyLefts.count / 2]
        let telling = headings.filter { $0.kind != .other }
        let standBeside = allPlaced && !telling.isEmpty
            && telling.filter { lines[$0.line].right <= middleLeft + 0.01 }.count * 2 > telling.count

        let choose: (Sentence) -> Heading?
        if standBeside {
            choose = beside
        } else {
            let scoreBefore = sentences.filter { suits($0, before($0)) }.count
            let scoreAfter = sentences.filter { suits($0, after($0)) }.count
            choose = scoreAfter > scoreBefore ? after : before
        }
        return sentences.map { sentence in
            var withHeading = sentence
            withHeading.blockHeading = choose(sentence)
            return withHeading
        }
    }

    // MARK: Reading everything

    /// Everything the rules can read from a packet's lines.
    ///
    /// - `lines`: the lines of one side or of both, in the order read.
    /// - `knownPlants`: the common names in your plant library. A line
    ///   that names one of them is taken as the packet's name.
    /// - `barcodes`: any barcode Vision read as a barcode, which is
    ///   surer than reading its printed digits.
    ///
    /// At most one finding comes back for each thing, the surest, in
    /// the order of `PacketField`. A rule that is not sure gives
    /// nothing: an empty row is better than a wrong one.
    static func read(_ lines: [PacketLine], knownPlants: [String] = [], barcodes: [String] = []) -> [PacketFinding] {
        let kept = lines.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        var found: [PacketFinding] = []

        for side in PacketSide.allCases {
            let sideLines = kept.filter { $0.side == side }
            guard !sideLines.isEmpty else { continue }
            let sideSentences = sentences(from: sideLines)
            // The whole side as one run of words, for things printed
            // over two lines with no sentence about them: "HARDY" /
            // "ANNUAL", "COUNTRY" / "VALUE".
            let flat = sideLines.map { $0.text.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
            let sureness = sideLines.map(\.confidence).min() ?? 1

            found += months(in: sideSentences)
            for sentence in sideSentences {
                found += measures(in: sentence)
            }
            found += lifeCycle(in: flat, side: side, sureness: sureness)
            found += sunAndSoil(in: sideSentences)
            found += sowBy(in: sideSentences, flat: flat, lines: sideLines)
            found += supplier(in: flat, side: side, sureness: sureness)
            found += latinName(in: sideLines)
            found += printedBarcode(in: sideLines)
        }
        found += nameAndVariety(in: kept, knownPlants: knownPlants)
        if let scanned = barcodes.first(where: { $0.count >= 8 && $0.allSatisfy(\.isNumber) }) {
            found.append(PacketFinding(field: .barcode, value: scanned, confidence: 0.98,
                                       sourceText: "the barcode itself", side: .back))
        }

        // The surest finding for each thing, in the list's order.
        var best: [PacketField: PacketFinding] = [:]
        for finding in found where !finding.value.isEmpty {
            if let held = best[finding.field], held.confidence >= finding.confidence { continue }
            best[finding.field] = finding
        }
        return PacketField.allCases.compactMap { best[$0] }
    }

    // MARK: Months

    /// What a packet's months can be for.
    private enum MonthUse { case sow, plantOut, flowering, harvest }

    /// A word in a sentence that says what its months are for. It is
    /// one of two sorts. A doing word (sow, plant out, flowers,
    /// harvest) comes before its months. A place word (indoors,
    /// outdoors) says where the sowing is done, and may come before the
    /// months or after them: "Sow outdoors in March", "Sow in March
    /// outdoors".
    private enum MonthCue {
        case doing(MonthUse)
        case place(PacketField)
    }

    /// The cues, each as a pattern. They are tried in this order and a
    /// place in the sentence goes to the first that fits it, so "plant
    /// outdoors" is planting out and not also "outdoors", and
    /// "flowering position" is a place and not also "flowering".
    private static let monthCues: [(pattern: String, cue: MonthCue)] = [
        ("\\b(?:plant(?:ing)? out(?:side|doors)?|plant outdoors|plant outside|transplant(?:ing)?)\\b", .doing(.plantOut)),
        ("\\b(?:indoors?|inside|under glass|under cover|greenhouse|propagator|windowsill|in trays|in pots|in modules|cold frame)\\b", .place(.sowIndoors)),
        ("\\b(?:outdoors?|outside|direct(?:ly)?|in situ|where they are to (?:flower|grow|crop)|flowering position|in the open|seed bed|in drills)\\b", .place(.sowOutdoors)),
        ("\\b(?:flowers?|flowering|blooms?|blooming)\\b", .doing(.flowering)),
        ("\\b(?:harvest(?:ing|s)?|pick(?:ing)?|crops?|cropping|lift(?:ing)?)\\b", .doing(.harvest)),
        // "sow" and "sown" as whole words: `\b` is the edge of a word,
        // so "sowings" does not count. "sowing" counts only as a label
        // ("Sowing time"), not as a thing ("from a spring sowing").
        ("\\b(?:sow|sown)\\b|\\bsowing(?=\\s*(?::|time|period|months?))", .doing(.sow))
    ]

    /// Where each cue stands in a sentence, the doing words and the
    /// place words apart, each in the order written.
    private static func cues(in sentence: String) -> (doing: [(at: Int, use: MonthUse)], places: [(at: Int, field: PacketField)]) {
        var doing: [(at: Int, use: MonthUse)] = []
        var places: [(at: Int, field: PacketField)] = []
        var taken: [NSRange] = []
        let whole = NSRange(sentence.startIndex..., in: sentence)
        for entry in monthCues {
            guard let expression = try? NSRegularExpression(pattern: entry.pattern, options: [.caseInsensitive]) else { continue }
            for fitted in expression.matches(in: sentence, range: whole) {
                // A place already claimed by an earlier cue is left to it.
                if taken.contains(where: { NSIntersectionRange($0, fitted.range).length > 0 }) { continue }
                taken.append(fitted.range)
                switch entry.cue {
                case .doing(let use): doing.append((fitted.range.location, use))
                case .place(let field): places.append((fitted.range.location, field))
                }
            }
        }
        return (doing.sorted { $0.at < $1.at }, places.sorted { $0.at < $1.at })
    }

    /// The months in each sentence, and what they are for.
    ///
    /// For each month or range of months, two questions:
    ///
    /// 1. What is being done? The doing word before it in the sentence:
    ///    in "Sow March to May for flowers June to September" the first
    ///    range follows "sow" and the second follows "flowers". With no
    ///    doing word before it, the heading of its block decides: a
    ///    bare "June to October." under FLOWERS is the flowering time.
    /// 2. If it is sowing, where? The place word that goes with it. A
    ///    packet puts the place either before its months all through a
    ///    sentence or after them all through, so the first place word
    ///    shows which: "Sow indoors February to April or outdoors April
    ///    to June", "Sow October to November under glass or March to
    ///    April outdoors". With no place word it is a plain "Sowing
    ///    time".
    private static func months(in sentences: [Sentence]) -> [PacketFinding] {
        var gathered: [PacketField: (months: [Int], confidence: Double, source: String, side: PacketSide)] = [:]

        for sentence in sentences {
            // "Sow by DEC 2028" is the packet's date, not a month to
            // sow in. `sowBy` below reads that.
            guard Pattern.first(dateCue, in: sentence.text) == nil else { continue }
            let spans = MonthParser.spans(in: sentence.text)
            guard let firstSpan = spans.first else { continue }
            let found = cues(in: sentence.text)
            let placeComesFirst = (found.places.first?.at ?? Int.max) < firstSpan.at
            let headingField = sentence.blockHeading?.monthField

            for span in spans {
                var sureness = 0.9
                var use = found.doing.last(where: { $0.at < span.at })?.use
                var field: PacketField?
                if use == nil, let headingField, ![.sowingTime, .sowIndoors, .sowOutdoors].contains(headingField) {
                    // No doing word before it, under FLOWERS or HARVEST.
                    field = headingField
                    sureness = 0.8
                } else if use == nil, !found.places.isEmpty || found.doing.contains(where: { $0.use == .sow }) {
                    // "March to May: sow outdoors", "Indoors: February".
                    use = .sow
                } else if use == nil {
                    use = found.doing.first?.use
                }

                switch use {
                case .sow:
                    let before = found.places.last(where: { $0.at < span.at })?.field
                    let after = found.places.first(where: { $0.at > span.at })?.field
                    let place = placeComesFirst ? (before ?? after) : (after ?? before)
                    // A block headed SOW INDOORS has said where already.
                    let headed = headingField == .sowIndoors || headingField == .sowOutdoors ? headingField : nil
                    field = place ?? headed ?? .sowingTime
                case .plantOut: field = .plantOut
                case .flowering: field = .flowering
                case .harvest: field = .harvest
                case nil:
                    if field == nil {
                        field = headingField
                        sureness = 0.8
                    }
                }
                guard let field else { continue }
                var entry = gathered[field] ?? (months: [], confidence: sentence.confidence * sureness, source: sentence.text, side: sentence.side)
                entry.months += span.months
                gathered[field] = entry
            }
        }
        return gathered.map { field, entry in
            let inOrder = Set(entry.months).sorted()
            return PacketFinding(field: field, value: MonthParser.describe(inOrder), confidence: entry.confidence,
                                 sourceText: entry.source, side: entry.side)
        }
    }

    // MARK: Measures and counts

    /// A length at one place in a sentence: "20cm", "2.5 cm", "10-15mm".
    /// Group 1 is the figure, group 2 a second figure if it is a range,
    /// group 3 the unit.
    private static let length = "(\\d+(?:\\.\\d+)?)(?:\\s*(?:[\u{2013}-]|to)\\s*(\\d+(?:\\.\\d+)?))?\\s*(cm|mm|m)\\b"
    /// The imperial figure often given in brackets after: "(6in)".
    private static let imperial = "(?:\\s*\\([^)]*\\))?"

    /// A length as it is shown: "15 cm", "10-15 mm". From the groups of
    /// a match of `length`, starting at group `first`.
    private static func shown(_ match: [String], from first: Int = 1) -> String {
        let figures = match[first + 1].isEmpty ? match[first] : "\(match[first])-\(match[first + 1])"
        return "\(figures) \(match[first + 2].lowercased())"
    }

    /// The things one sentence says in figures: germination, depth,
    /// spacing, height, seed count and sowing again.
    private static func measures(in ofPacket: Sentence) -> [PacketFinding] {
        let text = ofPacket.text
        let lower = text.lowercased()
        var found: [PacketFinding] = []
        func add(_ field: PacketField, _ value: String, _ sureness: Double) {
            found.append(PacketFinding(field: field, value: value, confidence: ofPacket.confidence * sureness,
                                       sourceText: text, side: ofPacket.side))
        }

        // Germination: "Seedlings appear 14-21 days", "Germination
        // takes 2-3 weeks".
        if Pattern.first("germinat|seedlings? (?:should |will |usually |normally )?(?:appear|emerge)|emergence|to emerge", in: lower) != nil,
           let match = Pattern.first("(\\d+)(?:\\s*(?:[\u{2013}-]|to)\\s*(\\d+))?\\s*(days?|weeks?)", in: lower) {
            let figures = match[2].isEmpty ? match[1] : "\(match[1])-\(match[2])"
            let unit = match[3].hasPrefix("week") ? "weeks" : "days"
            add(.germination, "\(figures) \(unit)", 0.85)
        }

        // Depth: a figure, or failing that the packet's own words.
        if let match = Pattern.first(length + imperial + "\\s*deep", in: lower) {
            add(.sowingDepth, shown(match), 0.85)
        } else if let match = Pattern.first("depth of (?:about |approx\\.? |approximately )?" + length, in: lower) {
            add(.sowingDepth, shown(match), 0.85)
        } else if let match = Pattern.first("\\b(cover lightly|lightly cover|barely cover|just cover|do not cover|surface sow|sow on the surface|press (?:gently )?(?:in|on)to the surface)\\b", in: lower) {
            add(.sowingDepth, match[1].prefix(1).uppercased() + match[1].dropFirst(), 0.6)
        }

        // Rows: "in rows 20cm apart", "30cm between rows".
        if let match = Pattern.first("\\b(?:rows?|drills?)\\s+(?:spaced\\s+|set\\s+)?" + length + imperial + "\\s*apart", in: lower)
            ?? Pattern.first(length + imperial + "\\s+between\\s+(?:the\\s+)?rows", in: lower) {
            add(.rowSpacing, shown(match), 0.85)
        }

        // Plant to plant: "thin to 15cm apart" is the surest. Otherwise
        // any "apart" that is not about rows.
        if let match = Pattern.first("\\bthin(?:ning)?(?: out)?(?: the)?(?: seedlings)?(?: out)? to (?:about |approx\\.? |leave )?" + length, in: lower) {
            add(.spacing, shown(match), 0.85)
        } else if Pattern.first("\\b(?:rows?|drills?)\\b", in: lower) == nil,
                  let match = Pattern.first(length + imperial + "\\s*apart", in: lower) {
            add(.spacing, shown(match), 0.65)
        }

        // Height: "Height 30cm", "grows to 60cm", "45cm tall".
        if let match = Pattern.first("\\b(?:height|grows to|reaches|reaching)\\b:?\\s*(?:of |up to |about |approx\\.? )?" + length, in: lower)
            ?? Pattern.first(length + imperial + "\\s*(?:tall|high)\\b", in: lower) {
            add(.height, shown(match), 0.8)
        }

        // How many seeds: "approx. 200 seeds", "Average contents 500
        // seeds". Not "sow 2 seeds per pot".
        if let match = Pattern.first("(approx(?:imately|\\.)?|average(?: contents)?:?|contents:?|contains)?\\s*(\\d[\\d,]{0,6})\\s*seeds?\\b", in: lower),
           let count = Int(match[2].replacingOccurrences(of: ",", with: "")), count >= 5, count <= 50000,
           Pattern.first("\\b(?:sow|plant|place|put)\\b[^.]{0,12}" + match[2], in: lower) == nil {
            add(.seedCount, String(count), match[1].isEmpty ? 0.65 : 0.85)
        }

        // Sowing again: "Make 2-3 sowings", "sow every 2 weeks".
        if Pattern.first("\\b(?:\\d+\\s*(?:[\u{2013}-]|to)\\s*\\d+|\\d+|several|repeat|successional|successive|regular)\\b[^.]{0,30}\\bsowings?\\b", in: lower) != nil
            || Pattern.first("\\bsow (?:again )?(?:every|at) [^.]{0,20}(?:days|weeks|intervals)", in: lower) != nil {
            add(.successions, text, 0.7)
        }
        return found
    }

    // MARK: Hardy annual, sun and soil

    /// "Hardy annual", "Half-hardy perennial" and the like, wherever on
    /// the side they are printed, even across two lines.
    private static func lifeCycle(in flat: String, side: PacketSide, sureness: Double) -> [PacketFinding] {
        if let match = Pattern.first("\\b(half[- ]hardy|hardy|tender)\\s+(annual|biennial|perennial)s?\\b", in: flat) {
            let hardy = match[1].lowercased().replacingOccurrences(of: "half hardy", with: "half-hardy")
            let words = "\(hardy) \(match[2].lowercased())"
            return [PacketFinding(field: .lifeCycle, value: words.prefix(1).uppercased() + words.dropFirst(),
                                  confidence: sureness * 0.9, sourceText: match[0], side: side)]
        }
        // The one word alone only counts in capitals, as a label:
        // "ANNUAL". In a sentence it may be about something else.
        if let match = Pattern.first("\\b(ANNUAL|BIENNIAL|PERENNIAL)\\b", in: flat, ignoringCase: false) {
            let word = match[1].lowercased()
            return [PacketFinding(field: .lifeCycle, value: word.prefix(1).uppercased() + word.dropFirst(),
                                  confidence: sureness * 0.7, sourceText: match[0], side: side)]
        }
        return []
    }

    /// The words for soil that a packet puts before "soil".
    private static let soilWords = ["well drained", "well-drained", "free draining", "free-draining", "moisture retentive",
                                    "moisture-retentive", "humus rich", "humus-rich", "moist", "fertile", "rich", "light",
                                    "heavy", "sandy", "poor", "ordinary", "dry", "damp", "chalky", "acid", "alkaline", "neutral"]

    /// Sun or shade, and what soil it likes.
    private static func sunAndSoil(in sentences: [Sentence]) -> [PacketFinding] {
        var found: [PacketFinding] = []

        // Sun: the same rule that reads a web page, so the words agree
        // with the rest of the library ("Full sun", "Full sun or
        // partial shade", "Partial shade").
        if let sunFact = PageFacts.sunOrShade(in: sentences.map(\.text)) {
            let from = sentences.first { sunFact.sentence.hasPrefix($0.text) }
            found.append(PacketFinding(field: .sun, value: sunFact.value, confidence: (from?.confidence ?? 1) * 0.8,
                                       sourceText: sunFact.sentence, side: from?.side ?? .back))
        }

        // Soil: from the first soil word to the word "soil", so that
        // "moist but well-drained soil" keeps its "but". A sentence
        // about covering the seed with fine soil is not about this.
        for sentence in sentences {
            let lower = sentence.text.lowercased()
            guard let soilAt = lower.range(of: " soil"), !lower.contains("cover"), !lower.contains("compost"),
                  !lower.contains("sieve") else { continue }
            let leadIn = String(lower[..<soilAt.lowerBound].suffix(45))
            let firstWordAt = soilWords.compactMap { leadIn.range(of: $0)?.lowerBound }.min()
            guard let firstWordAt else { continue }
            let phrase = String(leadIn[firstWordAt...]).trimmingCharacters(in: .whitespaces)
            found.append(PacketFinding(field: .soil, value: phrase.prefix(1).uppercased() + phrase.dropFirst(),
                                       confidence: sentence.confidence * 0.8, sourceText: sentence.text, side: sentence.side))
            break
        }
        return found
    }

    // MARK: Sow by

    /// The words that come before a packet's date.
    private static let dateCue = "\\b(?:sow|use|best)\\s*(?:by|before)\\b"
    private static let monthNames = "jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?"

    /// The sow-by date as it is shown, "December 2028" or "2028", from
    /// a month's name (or nothing) and a year. Nil for a year that
    /// cannot be right, which is how a misread stamp shows itself.
    private static func sowByText(month: String, year: String) -> String? {
        guard let yearNumber = Int(year), (2015...2050).contains(yearNumber) else { return nil }
        guard let monthNumber = MonthParser.months(in: month.isEmpty ? nil : month.lowercased()).first else { return year }
        return "\(Calendar.current.monthSymbols[monthNumber - 1]) \(year)"
    }

    /// "Sow by DEC 2028", "Use by end 2027", "Best before 12/2028".
    ///
    /// The date is often stamped on, not printed, and Vision may read
    /// the stamp as a line of its own, some way from the words "Sow
    /// by". So if the words are found with no date after them, the
    /// first line on that side that is a month and a year is taken,
    /// and trusted a little less.
    private static func sowBy(in sentences: [Sentence], flat: String, lines: [PacketLine]) -> [PacketFinding] {
        let cue = dateCue + "[\\s:]*(?:the\\s+)?(?:end(?:\\s+of)?\\s+)?"
        let side = lines.first?.side ?? .back
        let sureness = lines.map(\.confidence).min() ?? 1

        if let match = Pattern.first(cue + "(?:(" + monthNames + ")\\.?\\s+)?(20\\d\\d)\\b", in: flat),
           let words = sowByText(month: match[1], year: match[2]) {
            return [PacketFinding(field: .useBy, value: words, confidence: sureness * 0.9, sourceText: match[0], side: side)]
        }
        // "12/2028" or "12.28".
        if let match = Pattern.first(cue + "(\\d{1,2})[/.](20\\d\\d|\\d\\d)\\b", in: flat),
           let monthNumber = Int(match[1]), (1...12).contains(monthNumber) {
            let year = match[2].count == 2 ? "20" + match[2] : match[2]
            if let words = sowByText(month: Calendar.current.monthSymbols[monthNumber - 1], year: year) {
                return [PacketFinding(field: .useBy, value: words, confidence: sureness * 0.85, sourceText: match[0], side: side)]
            }
        }
        // The words, with the stamp read somewhere else on the side.
        if Pattern.first(cue, in: flat) != nil {
            for stamp in lines {
                guard let match = Pattern.first("^\\W*(" + monthNames + ")\\.?\\s+(20\\d\\d)\\b", in: stamp.text),
                      let words = sowByText(month: match[1], year: match[2]) else { continue }
                return [PacketFinding(field: .useBy, value: words, confidence: stamp.confidence * 0.7,
                                      sourceText: "Sow by … " + stamp.text, side: side)]
            }
        }
        return []
    }

    /// The year and month of a sow-by date as shown: "December 2028" is
    /// 2028 and 12, and "2028" alone is 2028 and 12 too, the year's end.
    static func sowByYearAndMonth(_ shown: String) -> (year: Int, month: Int)? {
        guard let match = Pattern.first("(20\\d\\d)", in: shown), let year = Int(match[1]) else { return nil }
        let month = MonthParser.months(in: shown.replacingOccurrences(of: match[1], with: "")).first ?? 12
        return (year, month)
    }

    /// The last day of a month: a packet marked "Sow by DEC 2028" is
    /// good until 31 December 2028. Found as the first of the month,
    /// plus a month, less a day, so the calendar deals with the months'
    /// different lengths and with leap years.
    static func lastDay(ofMonth month: Int, year: Int, calendar: Calendar = .current) -> Date? {
        var first = DateComponents()
        first.year = year
        first.month = month
        first.day = 1
        guard let firstDay = calendar.date(from: first),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstDay) else { return nil }
        return calendar.date(byAdding: .day, value: -1, to: nextMonth)
    }

    // MARK: Supplier

    /// UK seed suppliers, each as it should be written and the ways a
    /// packet may print it (in small letters, without marks).
    ///
    /// ⚠️ This list is Claude's, from general knowledge, for William to
    /// check and add to. A packet from a supplier not listed simply has
    /// no supplier filled in.
    static let suppliers: [(name: String, printed: [String])] = [
        ("Country Value", ["country value"]),
        ("Mr Fothergill's", ["mr fothergills", "mr fothergill", "fothergills"]),
        ("Johnsons", ["johnsons seeds", "johnsons"]),
        ("Suttons", ["suttons seeds", "suttons"]),
        ("Thompson & Morgan", ["thompson morgan", "thompson and morgan"]),
        ("Unwins", ["unwins"]),
        ("Kings Seeds", ["kings seeds"]),
        ("Marshalls", ["marshalls seeds", "marshalls"]),
        ("D.T. Brown", ["d t brown", "dt brown"]),
        ("Dobies", ["dobies"]),
        ("Chiltern Seeds", ["chiltern seeds"]),
        ("Real Seeds", ["real seed catalogue", "real seeds"]),
        ("Franchi", ["franchi", "seeds of italy"]),
        ("Sarah Raven", ["sarah raven"]),
        ("Premier Seeds Direct", ["premier seeds direct"]),
        ("Seed Co-operative", ["seed co operative", "seed cooperative"]),
        ("Tamar Organics", ["tamar organics"]),
        ("Vital Seeds", ["vital seeds"]),
        ("Higgledy Garden", ["higgledy garden"]),
        ("Moles Seeds", ["moles seeds"]),
        ("Nicky's Nursery", ["nickys nursery"]),
        ("Pennard Plants", ["pennard plants"]),
        ("Heritage Seed Library", ["heritage seed library"]),
        ("Jekka's", ["jekkas"]),
        ("Emorsgate Seeds", ["emorsgate"]),
        ("Naturescape", ["naturescape"]),
        ("Wilko", ["wilko"]),
        ("Verve", ["verve"])
    ]

    private static func supplier(in flat: String, side: PacketSide, sureness: Double) -> [PacketFinding] {
        // `tidied` gives small letters with a space at each end and
        // between words, so " country value " is found as whole words.
        let tidied = EiraSafety.tidied(flat)
        for entry in suppliers {
            if let printed = entry.printed.first(where: { tidied.contains(" \($0) ") }) {
                return [PacketFinding(field: .supplier, value: entry.name, confidence: sureness * 0.85,
                                      sourceText: printed.uppercased(), side: side)]
            }
        }
        return []
    }

    // MARK: Latin name

    /// English words that open a sentence with a capital and are
    /// followed by a small word, as a Latin name is: "Great for".
    private static let notGenera: Set<String> = ["Sow", "Plant", "Keep", "Great", "Use", "Make", "Thin", "Cover", "Water",
                                                 "Harvest", "Packed", "Best", "Prefers", "Ideal", "Easy", "Height", "Full",
                                                 "Half", "Hardy", "Firm", "When", "Late", "Early", "Grow", "Feed", "Pick",
                                                 "Store", "Seeds", "Seedlings", "Performance", "Paper", "Product", "Produce",
                                                 "Average", "Contents", "Approx", "Flowers", "Spacing", "Germination"]

    /// The Latin name, where the packet prints one: in brackets, or as
    /// a line of its own. A capital word and a small word in the middle
    /// of a sentence is not taken for one, which is how "Great for"
    /// came to be this packet's Latin name before.
    private static func latinName(in lines: [PacketLine]) -> [PacketFinding] {
        let binomial = "[A-Z][a-z]{2,}(?: [\u{00D7}x])? [a-z]{4,}(?:-[a-z]+)?"
        for packetLine in lines {
            let words = packetLine.text.trimmingCharacters(in: .whitespaces)
            var name: String?
            var sureness = 0.8
            if let match = Pattern.first("\\((" + binomial + ")\\)", in: words, ignoringCase: false) {
                name = match[1]
            } else if let match = Pattern.first("^(" + binomial + ")$", in: words, ignoringCase: false) {
                name = match[1]
                sureness = 0.65
            }
            guard let name, let genus = name.split(separator: " ").first, !notGenera.contains(String(genus)) else { continue }
            return [PacketFinding(field: .latinName, value: name, confidence: packetLine.confidence * sureness,
                                  sourceText: words, side: packetLine.side)]
        }
        return []
    }

    // MARK: Barcode

    /// True when the last digit of a barcode's number is the one its
    /// other digits call for. Every barcode carries this check, so a
    /// misread digit nearly always shows.
    static func barcodeChecks(_ digits: String) -> Bool {
        let numbers = digits.compactMap(\.wholeNumberValue)
        guard numbers.count == digits.count, [8, 12, 13].contains(numbers.count), let last = numbers.last else { return false }
        // Counting from the right, the digits before the last are
        // multiplied by 3 and 1 in turn.
        var total = 0
        for (index, digit) in numbers.dropLast().reversed().enumerated() {
            total += digit * (index % 2 == 0 ? 3 : 1)
        }
        return (10 - total % 10) % 10 == last
    }

    /// The barcode's number from its printed digits, which Vision often
    /// reads as two lines: "5" and "010931 212569".
    private static func printedBarcode(in lines: [PacketLine]) -> [PacketFinding] {
        var digits = ""
        var least = 1.0
        var barcodeFound: PacketFinding?
        func finish(side: PacketSide) {
            if [8, 12, 13].contains(digits.count), barcodeChecks(digits), barcodeFound == nil {
                barcodeFound = PacketFinding(field: .barcode, value: digits, confidence: least * 0.9,
                                     sourceText: digits, side: side)
            }
            digits = ""; least = 1.0
        }
        for packetLine in lines {
            if isOnlyDigits(packetLine.text) {
                digits += packetLine.text.filter(\.isNumber)
                least = min(least, packetLine.confidence)
            } else {
                finish(side: packetLine.side)
            }
        }
        finish(side: lines.last?.side ?? .back)
        return barcodeFound.map { [$0] } ?? []
    }

    // MARK: The name and the variety

    /// Words that are never the plant's name, though they may be
    /// printed large and alone.
    private static let notNames: Set<String> = ["price", "seeds", "seed", "new", "organic", "fsc", "mix", "paper", "sow by",
                                                "use by", "best before", "packed in uk", "packed in the uk", "rhs",
                                                "award of garden merit", "hardy", "half hardy", "tender", "annual",
                                                "biennial", "perennial", "hardy annual", "hardy perennial", "hardy biennial",
                                                "half hardy annual", "half hardy perennial", "easy to grow", "value",
                                                "flowers", "vegetables", "herbs", "wildflowers", "recycle", "great value"]

    /// True for a line that could be the packet's title: a few words,
    /// beginning with a capital, not a sentence, not a heading, not an
    /// address and not one of the words above.
    private static func couldBeTitle(_ packetLine: PacketLine) -> Bool {
        let words = packetLine.text.trimmingCharacters(in: .whitespaces)
        let tidied = EiraSafety.tidied(words).trimmingCharacters(in: .whitespaces)
        guard let firstLetter = words.first, firstLetter.isUppercase, words.count >= 3 else { return false }
        guard words.split(separator: " ").count <= 6, !words.hasSuffix("."), !words.contains(". "),
              !words.contains(",") else { return false }
        guard heading(of: words) == nil, !notNames.contains(tidied) else { return false }
        // A date stamp, a code or a price: too many digits.
        guard words.filter(\.isNumber).count <= 2 else { return false }
        // A supplier's name, or half of one ("COUNTRY", "VALUE").
        let padded = " \(tidied) "
        guard !suppliers.contains(where: { entry in entry.printed.contains { " \($0) ".contains(padded) } }) else { return false }
        return true
    }

    /// The plant's name and the variety.
    ///
    /// The surest sign is a line that names a plant already in your
    /// library: "Carrot Nantes 2" where you grow carrots. The name is
    /// then the library's and the rest of the line is the variety.
    ///
    /// Failing that, the name is the largest writing on the packet,
    /// when the lines' sizes are known, and the front of the packet is
    /// preferred to the back. The first word is taken as the name and
    /// the rest as the variety, which is right for "Linaria Fairy
    /// Bouquet Mixed" and wrong for "Sweet William Auricula Eyed". It
    /// is shown with low confidence for that reason.
    private static func nameAndVariety(in lines: [PacketLine], knownPlants: [String]) -> [PacketFinding] {
        // Sizes are compared within one photo: a line's height against
        // the middle height on its own side.
        var middleHeight: [PacketSide: Double] = [:]
        for side in PacketSide.allCases {
            let heights = lines.filter { $0.side == side && $0.hasPlace }.map(\.height).sorted()
            if !heights.isEmpty { middleHeight[side] = heights[heights.count / 2] }
        }

        var best: (index: Int, score: Double, known: String?, size: Double)?
        for (index, packetLine) in lines.enumerated() where couldBeTitle(packetLine) {
            let known = KeptFacts.plantNamed(in: packetLine.text, among: knownPlants)
            let size = middleHeight[packetLine.side].map { packetLine.height / max($0, 0.0001) } ?? 0
            // Small writing that names no plant of yours must at least
            // look like a title, each word with a capital: "Cornflower
            // Blue Ball", and not "Great for pollinators".
            let everyWordCapital = packetLine.text.split(separator: " ").allSatisfy { $0.first?.isLowercase != true }
            guard known != nil || size >= 1.4 || everyWordCapital else { continue }
            var score: Double = known == nil ? 0 : 3
            score += min(size, 4)
            if packetLine.side == .front { score += 0.5 }
            // A title in ordinary capitals and small letters, such as
            // "Linaria Fairy Bouquet Mixed", is likelier than a label
            // all in capitals.
            if packetLine.text != packetLine.text.uppercased() { score += 0.5 }
            // Nearer the top is a little likelier, all else equal.
            score -= Double(index) * 0.001
            if best == nil || score > best!.score { best = (index, score, known, size) }
        }
        guard let best else { return [] }

        let title = lines[best.index]
        let words = title.text.trimmingCharacters(in: .whitespaces).split(separator: " ").map(String.init)
        var name = words[0]
        var rest = Array(words.dropFirst())
        var sureness = best.size >= 1.4 ? 0.75 : 0.55

        if let known = best.known {
            // Take the library's name out of the line, however many
            // words it is, and call the rest the variety.
            let plain = EiraSafety.tidied(KeptFacts.withoutBrackets(known)).trimmingCharacters(in: .whitespaces)
            let spellings = Set(KeptFacts.spellings(of: plain).flatMap { $0.split(separator: " ").map(String.init) })
            name = known
            rest = words.filter { !spellings.contains(EiraSafety.tidied($0).trimmingCharacters(in: .whitespaces)) }
            sureness = 0.9
        } else if let lastCapital = words.lastIndex(where: { $0.count > 1 && $0 == $0.uppercased() && $0.contains(where: \.isLetter) }),
                  lastCapital < words.count - 1, words[...lastCapital].allSatisfy({ $0 == $0.uppercased() }) {
            // "SWEET PEA Spencer Mixed": the capitals are the name.
            name = words[...lastCapital].joined(separator: " ")
            rest = Array(words[(lastCapital + 1)...])
        }
        // A name all in capitals is shown as an ordinary word.
        if name == name.uppercased() { name = name.prefix(1) + name.dropFirst().lowercased() }

        var found = [PacketFinding(field: .plantName, value: name, confidence: title.confidence * sureness,
                                   sourceText: title.text, side: title.side)]

        // The variety: the rest of the title's line, or, when the name
        // stands alone, the next line on the same side that could be a
        // title too ("LINARIA" above "Fairy Bouquet Mixed").
        var variety = rest.joined(separator: " ")
        var varietySource = title.text
        if variety.isEmpty, best.index + 1 < lines.count {
            let next = lines[best.index + 1]
            let isNear = !title.hasPlace || !next.hasPlace || next.top - (title.top + title.height) <= title.height * 2.5
            if next.side == title.side, couldBeTitle(next), isNear,
               KeptFacts.plantNamed(in: next.text, among: knownPlants) == nil {
                variety = next.text.trimmingCharacters(in: .whitespaces)
                varietySource = next.text
                if variety == variety.uppercased() { variety = variety.capitalized }
            }
        }
        variety = variety.trimmingCharacters(in: CharacterSet(charactersIn: "'\"\u{2018}\u{2019}\u{201C}\u{201D} "))
        if !variety.isEmpty {
            found.append(PacketFinding(field: .variety, value: variety, confidence: title.confidence * sureness * 0.9,
                                       sourceText: varietySource, side: title.side))
        }
        return found
    }

    // MARK: - From a finding to the records

    /// A finding's value as the plant's record writes it, or nil if it
    /// has nothing to write.
    ///
    /// The scan sheet shows values the way a person reads them, and the
    /// library keeps some of them another way:
    ///
    ///   months    "March, April and May"   mar apr may
    ///   spacing   "15 cm"                  0.15   (metres)
    ///   height    "30-45 cm"               0.3-0.45
    ///   depth     "13 mm" or "1.5 cm"      13, 15 (millimetres)
    ///   depth     "Cover lightly"          Cover lightly
    ///
    /// The value is read afresh here, so a value corrected by hand on
    /// the sheet is converted the same way.
    static func recordText(for field: PacketField, shown: String) -> String? {
        let trimmed = shown.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, field.plantKey != nil else { return nil }
        if field.isMonths {
            let months = MonthParser.months(in: trimmed)
            return months.isEmpty ? nil : PlantFacts.monthText(months)
        }
        switch field {
        case .spacing, .height:
            return converted(trimmed, to: "m") ?? trimmed
        case .sowingDepth:
            return converted(trimmed, to: "mm") ?? trimmed
        default:
            return trimmed
        }
    }

    /// A length in another unit, as bare figures: "15 cm" to "m" is
    /// "0.15". Nil when the text is not a length.
    private static func converted(_ text: String, to unit: String) -> String? {
        guard let match = Pattern.first("^" + length + "$", in: text.lowercased()), let low = Double(match[1]) else { return nil }
        let inMetres: [String: Double] = ["mm": 0.001, "cm": 0.01, "m": 1]
        guard let from = inMetres[match[3]], let to = inMetres[unit] else { return nil }
        var figures = PageFacts.number(low * from / to)
        if let high = Double(match[2]) { figures += "-" + PageFacts.number(high * from / to) }
        return figures
    }

    /// The note kept with the packet: that it was read from a photo and
    /// when, and then what the record has no box for.
    ///
    ///   "Read from a packet photo on 15 Nov 2026. Values need
    ///    checking. Spacing between rows: 20 cm. Sowing again: Make 2-3
    ///    sowings for successive flowering. Barcode: 5010931212569."
    static func note(for findings: [PacketFinding], on day: String) -> String {
        var parts = ["Read from a packet photo on \(day). Values need checking."]
        for finding in findings where finding.field.goesInNotes {
            let value = finding.value.trimmingCharacters(in: CharacterSet(charactersIn: " ."))
            parts.append("\(finding.field.label): \(value).")
        }
        return parts.joined(separator: " ")
    }

    /// The names in the library that a packet's name could mean, the
    /// likeliest first. "Carrot" finds "Carrots". "Linaria" finds
    /// nothing, and the scan sheet then offers to add it.
    static func libraryNames(matching name: String, among known: [String]) -> [String] {
        let wanted = EiraSafety.tidied(name).trimmingCharacters(in: .whitespaces)
        guard wanted.count >= 2 else { return [] }
        var found: [String] = []
        if let exact = KeptFacts.plantNamed(in: name, among: known) { found.append(exact) }
        // Then any other name that holds the words typed, shortest
        // first: "bean" also finds "Broad bean" and "Runner bean".
        let others = Set(known).filter { $0.lowercased().contains(wanted) && !found.contains($0) }
            .sorted { $0.count != $1.count ? $0.count < $1.count : $0 < $1 }
        return found + others
    }
}
