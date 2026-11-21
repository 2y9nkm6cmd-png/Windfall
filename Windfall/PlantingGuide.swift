//
//  PlantingGuide.swift
//  Windfall
//
//  The planting guide at the very top of a plant's page.
//
//  Why it exists: William's partner wants the notes for planting a plant
//  "front and centre" (William, 21 November 2026). The notes are mostly
//  the sowing text from a seed packet, several hundred words long, and
//  open from the Notes button. This card puts the few lines that matter
//  when sowing at the top of the page. (Project doc 150.)
//
//  Where its lines come from:
//
//  1. The plant's own record first: sowing months, depth, spacing,
//     germination, planting out, sow to crop, harvest. These are facts
//     from the spreadsheet or typed in the app.
//  2. Eira reads the notes (Apple's model on the device, in
//     PlantingGuideMaker.swift) and picks out how to sow, how to plant
//     out, and up to three tips, plus depth, spacing and germination
//     where the record has none. Every line she supplies is marked as
//     hers on the card.
//
//  The guard against a model making things up is here, in plain code,
//  not left to the model: a line from Eira is thrown away if it holds a
//  figure that is not in the notes, or a month the notes never name.
//
//  This file draws nothing, so the logic tests can try it without a Mac.
//  The card is PlantingGuideCard.swift.
//

import Foundation

enum PlantingGuide {

    /// Raised when what Eira is asked changes, so that every guide is
    /// read again. Part of the fingerprint in `notesKey`.
    static let readingVersion = 1

    // MARK: - What the card shows

    /// One line of the guide: "Sowing depth", "1.5 cm".
    struct Line: Identifiable, Equatable {
        let label: String
        let text: String
        /// True when Eira read it from the notes; false when it is a
        /// fact from the plant's record.
        let fromNotes: Bool

        var id: String { label }
    }

    /// What Eira read out of the notes. Each is empty when the notes
    /// do not say. Kept on the plant as JSON (`Plant.plantingGuideReading`).
    struct GuideFromNotes: Codable, Equatable {
        var howToSow: String = ""
        var depth: String = ""
        var spacing: String = ""
        var germination: String = ""
        var plantingOut: String = ""
        var tips: [String] = []

        var isEmpty: Bool {
            [howToSow, depth, spacing, germination, plantingOut].allSatisfy { $0.isEmpty } && tips.isEmpty
        }
    }

    /// The whole guide for a plant.
    struct Guide: Equatable {
        var lines: [Line] = []
        var tips: [String] = []

        var isEmpty: Bool { lines.isEmpty && tips.isEmpty }
        /// True if anything on it is Eira's.
        var hasEiraLines: Bool { !tips.isEmpty || lines.contains(where: \.fromNotes) }
    }

    // MARK: - Building it

    /// The guide, from the plant's record and Eira's reading of its
    /// notes, if she has read them. `reading` should already have been
    /// through `checked`, which `stored` does.
    static func guide(for plant: Plant, reading notesGuide: GuideFromNotes?) -> Guide {
        let facts = factLines(for: plant)
        var lines: [Line] = []

        func eira(_ label: String, _ text: String?) {
            guard let text, !text.isEmpty else { return }
            lines.append(Line(label: label, text: text, fromNotes: true))
        }

        // In the order a gardener goes through them.
        lines += facts.filter { ["Sow indoors", "Sow outdoors"].contains($0.label) }
        eira("How to sow", notesGuide?.howToSow)
        for (label, theirs) in [("Sowing depth", notesGuide?.depth),
                                ("Germination", notesGuide?.germination),
                                ("Spacing", notesGuide?.spacing)] {
            // The record's fact wins; Eira's only fills a gap.
            if let fact = facts.first(where: { $0.label == label }) {
                lines.append(fact)
            } else {
                eira(label, theirs)
            }
        }
        lines += facts.filter { $0.label == "Temperature" }
        lines += facts.filter { $0.label == "Plant out" }
        eira("Planting out", notesGuide?.plantingOut)
        lines += facts.filter { ["Sow to crop", "Harvest"].contains($0.label) }

        return Guide(lines: lines, tips: notesGuide?.tips ?? [])
    }

    /// The lines that come straight from the plant's record.
    static func factLines(for plant: Plant) -> [Line] {
        var lines: [Line] = []
        func fact(_ label: String, _ text: String?) {
            let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !PlantFacts.isPlaceholder(trimmed) else { return }
            lines.append(Line(label: label, text: trimmed, fromNotes: false))
        }
        fact("Sow indoors", monthWords(plant.sowIndoorsMonthsText))
        fact("Sow outdoors", monthWords(plant.sowOutdoorsMonthsText))
        fact("Sowing depth", measured(plant.sowingDepthMM, unit: "mm"))
        fact("Germination", DurationParser.describe(plant.germinationDaysText) ?? plant.germinationDaysText)
        fact("Spacing", measured(plant.spacingM, unit: "m"))
        fact("Temperature", measured(plant.sowingTemperatureC, unit: "°C"))
        fact("Plant out", monthWords(plant.plantOutMonthsText))
        fact("Sow to crop", DurationParser.describe(plant.sowToCropText) ?? plant.sowToCropText)
        fact("Harvest", monthWords(plant.harvestMonthsText))
        return lines
    }

    // MARK: - The guard on Eira's lines

    /// Eira's reading with anything she could not have got from the
    /// notes taken out: a line whose figures are not all in the notes,
    /// or which names a month the notes never name. Spaces are tidied,
    /// lines over 240 letters cut at a word, and at most three tips kept.
    static func checked(_ notesGuide: GuideFromNotes, notes: String) -> GuideFromNotes {
        let noteFigures = Set(figures(in: notes))
        let noteMonths = Set(MonthParser.months(in: notes))

        func keep(_ text: String) -> String {
            let tidy = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            guard !tidy.isEmpty, !PlantFacts.isPlaceholder(tidy) else { return "" }
            // Words a model uses when it has nothing to say.
            let lower = tidy.lowercased()
            if ["not mentioned", "not stated", "not specified", "none", "n/a", "unknown", "not given"].contains(where: { lower.hasPrefix($0) }) {
                return ""
            }
            guard figures(in: tidy).allSatisfy(noteFigures.contains) else { return "" }
            guard Set(MonthParser.months(in: tidy)).isSubset(of: noteMonths) else { return "" }
            return shortened(tidy, to: 240)
        }

        var guideKept = GuideFromNotes()
        guideKept.howToSow = keep(notesGuide.howToSow)
        guideKept.depth = keep(notesGuide.depth)
        guideKept.spacing = keep(notesGuide.spacing)
        guideKept.germination = keep(notesGuide.germination)
        guideKept.plantingOut = keep(notesGuide.plantingOut)
        var seen = Set<String>()
        guideKept.tips = notesGuide.tips.map(keep).filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }.prefix(3).map { $0 }
        return guideKept
    }

    /// Every figure in a piece of text, as written: "1.5", "30", "12".
    /// "1/2" gives "1" and "2"; "15-20" gives "15" and "20".
    static func figures(in text: String) -> [String] {
        var found: [String] = []
        var current = ""
        let characters = Array(text)
        for (index, character) in characters.enumerated() {
            if character.isASCII, character.isNumber {
                current.append(character)
            } else if (character == "." || character == ","), !current.isEmpty,
                      index + 1 < characters.count, characters[index + 1].isASCII, characters[index + 1].isNumber {
                // A decimal point (or the European comma) between figures.
                current.append(".")
            } else if !current.isEmpty {
                found.append(current)
                current = ""
            }
        }
        if !current.isEmpty { found.append(current) }
        return found
    }

    // MARK: - Keeping a reading on the plant

    /// A short fingerprint of the notes and of `readingVersion`, so a
    /// change to either asks Eira to read them again. Spaces at the ends
    /// do not count. Swift's own `hashValue` changes each time the app
    /// starts, so this is worked out by hand (FNV-1a, a well-known
    /// simple recipe), and is the same on every device.
    static func notesKey(_ notes: String?) -> String {
        let text = (notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return "v\(readingVersion)-" + String(hash, radix: 16)
    }

    /// True when the plant has notes and Eira has not yet read these
    /// notes (or read them under an older `readingVersion`).
    static func needsReading(_ plant: Plant) -> Bool {
        let notes = (plant.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !notes.isEmpty, !PlantFacts.isPlaceholder(notes) else { return false }
        return plant.plantingGuideNotesKey != notesKey(plant.notes) || plant.plantingGuideReading == nil
    }

    /// Eira's reading kept on the plant, if it was made from the notes
    /// as they are now. Nil when there is none, or the notes have
    /// changed since.
    static func stored(on plant: Plant) -> GuideFromNotes? {
        guard let json = plant.plantingGuideReading,
              plant.plantingGuideNotesKey == notesKey(plant.notes),
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(GuideFromNotes.self, from: data)
    }

    /// Keeps a reading on the plant, checked against its notes first,
    /// with the fingerprint of the notes it came from.
    static func keep(_ notesGuide: GuideFromNotes, on plant: Plant) {
        let safe = checked(notesGuide, notes: plant.notes ?? "")
        guard let data = try? JSONEncoder().encode(safe) else { return }
        plant.plantingGuideReading = String(data: data, encoding: .utf8)
        plant.plantingGuideNotesKey = notesKey(plant.notes)
    }

    /// The notes as they are handed to the model: a straight double
    /// quote becomes ″, the sign for inches. Packets write inches as
    /// 2", and the model writes its answer as JSON, where " ends a piece
    /// of text: tried on the Mac (21 November 2026), Achillea's 5cm (2")
    /// cut its answer off and broke it. The figures are unchanged, so
    /// the check against the notes still matches.
    static func forModel(_ notes: String) -> String {
        notes.replacingOccurrences(of: "\"", with: "\u{2033}")
    }

    // MARK: - Pieces

    /// "feb mar apr sep" as "Feb to Apr, Sep". Empty when no month is
    /// found, so words such as "Spring" are left out of the guide (the
    /// Sowing from Seed card still shows them).
    static func monthWords(_ text: String?) -> String {
        let months = MonthParser.months(in: text)
        guard !months.isEmpty else { return "" }
        let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        // Runs of months next to each other: [2, 3, 4], [9].
        var monthRuns: [[Int]] = []
        for month in months {
            if let last = monthRuns.last?.last, month == last + 1 {
                monthRuns[monthRuns.count - 1].append(month)
            } else {
                monthRuns.append([month])
            }
        }
        // A run that ends in December and one that starts in January are
        // one run over the turn of the year: "Nov to Jan".
        if monthRuns.count > 1, monthRuns.first?.first == 1, monthRuns.last?.last == 12 {
            let first = monthRuns.removeFirst()
            monthRuns[monthRuns.count - 1] += first
        }
        return monthRuns.map { run in
            run.count == 1 ? names[run[0] - 1] : "\(names[run[0] - 1]) to \(names[run[run.count - 1] - 1])"
        }.joined(separator: ", ")
    }

    /// A figure with its unit, when the text ends in a figure.
    private static func measured(_ text: String?, unit: String) -> String {
        let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last, last.isNumber else { return trimmed }
        return "\(trimmed) \(unit)"
    }

    /// Cut at the last space before `limit` letters, with "…" after.
    private static func shortened(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }
        let cut = text.prefix(limit)
        let end = cut.lastIndex(of: " ") ?? cut.endIndex
        return String(cut[..<end]) + "…"
    }
}
