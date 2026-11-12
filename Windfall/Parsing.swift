//
//  Parsing.swift
//  Windfall
//
//  Your spreadsheet holds sowing times as free text — "mar apr may",
//  "July, August", "oct nov dec feb mar" — and durations as ranges like
//  "10-14 days" or "7 to 21". People are good at reading that; code is not.
//
//  These parsers turn it into something the calendar can use, and they
//  live here rather than in the spreadsheet so there is one implementation
//  rather than two that can disagree.
//
//  Deliberately forgiving. A parser that rejects "Sept" because it wanted
//  "Sep" is worse than useless — it makes you go and edit 265 rows.
//

import Foundation

// MARK: - Months

enum MonthParser {

    /// Every spelling seen in the sheet, plus the obvious variants.
    private static let names: [(String, Int)] = [
        ("january", 1), ("jan", 1),
        ("february", 2), ("febuary", 2), ("feb", 2),
        ("march", 3), ("mar", 3),
        ("april", 4), ("apr", 4),
        ("may", 5),
        ("june", 6), ("jun", 6),
        ("july", 7), ("jul", 7),
        ("august", 8), ("aug", 8),
        ("september", 9), ("sept", 9), ("sep", 9),
        ("october", 10), ("oct", 10),
        ("november", 11), ("nov", 11),
        ("december", 12), ("dec", 12)
    ]

    /// Pulls every month mentioned out of a string.
    ///
    /// Handles lists ("mar apr may", "July, August"), ranges written with
    /// a dash ("Mar-May"), and wrapped years ("oct nov dec feb mar").
    /// Returns them in calendar order, deduplicated.
    ///
    /// The answer for each piece of text is remembered. The Year page
    /// alone asks about 1,700 times each time it redraws, nearly always
    /// about text it has asked about before, and reading the text afresh
    /// each time took about a tenth of a second in all (measured on 12
    /// November 2026). Looking up a remembered answer takes almost none.
    static func months(in text: String?) -> [Int] {
        guard let text, !text.isEmpty else { return [] }
        if let known = remembered[text] { return known }
        let answer = read(text)
        remembered[text] = answer
        return answer
    }

    /// Answers already worked out, by the text they were worked out from.
    /// The library holds a few hundred different pieces of month text, so
    /// this stays small.
    private static var remembered: [String: [Int]] = [:]

    /// Does the reading. Only called for text not seen before.
    private static func read(_ text: String) -> [Int] {
        let lower = text.lowercased()

        // A dash between two month names means everything in between.
        if let range = dashRange(in: lower) {
            return range
        }

        // Every name is tried. A short name inside a long one ("sep" in
        // "september") finds the same month, so the order does not matter.
        var found = Set<Int>()
        for (name, number) in names where lower.contains(name) {
            found.insert(number)
        }
        return found.sorted()
    }

    /// "Mar-May" or "March to June" — expand to the months between.
    private static func dashRange(in lower: String) -> [Int]? {
        let separators = ["-", "–", "—", " to "]
        for separator in separators {
            let parts = lower.components(separatedBy: separator)
            guard parts.count == 2 else { continue }

            let left = singleMonth(in: parts[0])
            let right = singleMonth(in: parts[1])

            if let start = left, let end = right {
                if start <= end {
                    return Array(start...end)
                } else {
                    // Wraps the new year: Oct–Mar
                    return Array(start...12) + Array(1...end)
                }
            }
        }
        return nil
    }

    private static func singleMonth(in fragment: String) -> Int? {
        let trimmed = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
        for (name, number) in names.sorted(by: { $0.0.count > $1.0.count }) {
            if trimmed.contains(name) { return number }
        }
        return nil
    }

    /// "March, April and May" — for showing back to the user.
    static func describe(_ months: [Int]) -> String {
        guard !months.isEmpty else { return "—" }
        // The calendar already knows the months' names. (A DateFormatter
        // was made here on every call just to ask for them, and those are
        // slow to make.)
        let symbols = Calendar.current.monthSymbols
        let names = months.compactMap { month -> String? in
            guard month >= 1, month <= 12 else { return nil }
            return symbols[month - 1]
        }
        guard names.count > 1 else { return names.first ?? "—" }
        return names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
    }

    /// Whether a month falls inside a set — for "what can I sow now?"
    static func includes(_ month: Int, in text: String?) -> Bool {
        months(in: text).contains(month)
    }
}

// MARK: - Numeric ranges

/// A duration read from text: "10-14 days" becomes 10...14.
struct NumericRange: Equatable {
    var lower: Double
    var upper: Double

    var midpoint: Double { (lower + upper) / 2 }
    var isSingleValue: Bool { lower == upper }

    var description: String {
        isSingleValue
            ? lower.formatted(.number.precision(.fractionLength(0...1)))
            : "\(lower.formatted(.number.precision(.fractionLength(0...1))))–\(upper.formatted(.number.precision(.fractionLength(0...1))))"
    }
}

enum RangeParser {

    /// Pulls a range out of free text.
    ///
    /// "10-14 days" → 10...14
    /// "7 to 21"    → 7...21
    /// "around 12"  → 12...12
    /// "1.5m+"      → 1.5...1.5
    /// "" or "n/a"  → nil
    /// Finds every number in a string, decimals included. Built once and
    /// kept, because building a pattern is slow and this is asked for
    /// every sowing on Today.
    private static let numberPattern = try? NSRegularExpression(pattern: #"\d+(?:\.\d+)?"#)

    static func range(in text: String?) -> NumericRange? {
        guard let text, !text.isEmpty else { return nil }

        let lower = text.lowercased()
        if lower.contains("n/a") || lower.contains("unknown") { return nil }

        guard let regex = numberPattern else { return nil }

        let range = NSRange(lower.startIndex..., in: lower)
        let matches = regex.matches(in: lower, range: range)

        let numbers: [Double] = matches.compactMap { match in
            guard let r = Range(match.range, in: lower) else { return nil }
            return Double(lower[r])
        }

        guard let first = numbers.first else { return nil }

        if numbers.count >= 2, let second = numbers.dropFirst().first {
            return NumericRange(lower: Swift.min(first, second),
                                upper: Swift.max(first, second))
        }
        return NumericRange(lower: first, upper: first)
    }

    /// Just the middle of the range — for sorting and rough sums.
    static func midpoint(in text: String?) -> Double? {
        range(in: text)?.midpoint
    }

    /// The cautious end — for "will it be ready before the frosts?"
    static func upperBound(in text: String?) -> Double? {
        range(in: text)?.upper
    }
}

// MARK: - Booleans

enum BoolParser {

    /// Spreadsheet truthiness: "Yes", "Y", "TRUE", "1", "x" all mean yes.
    static func value(_ text: String?) -> Bool {
        guard let text else { return false }
        let lower = text.trimmingCharacters(in: .whitespaces).lowercased()
        return ["yes", "y", "true", "1", "x", "✓", "✔"].contains(lower)
    }
}
