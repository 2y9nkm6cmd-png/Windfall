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
    ///
    /// Until 15 November 2026 this looked for one dash or one " to " in
    /// the whole text, and gave up on the range if there were two. So a
    /// seed packet's "March to May and August to September" lost April.
    /// Now the text is read a piece at a time (see `spans`), and each
    /// range is filled in by itself.
    private static func read(_ text: String) -> [Int] {
        let found = spans(in: text)
        // One range alone keeps its own order, so that "Oct-Feb" still
        // reads October, November, December, January, February.
        if found.count == 1 { return found[0].months }
        return Set(found.flatMap(\.months)).sorted()
    }

    /// One month, or one range of months, found in a text, and where.
    ///
    /// "Sow March to May and August to September" holds two: March,
    /// April, May at letter 4 and August, September at letter 21. The
    /// seed packet reader (PacketReading.swift) uses the place to tell
    /// which months go with "sow" and which with "flowers".
    struct Span: Equatable {
        /// The months, in the order written: a range over the new year
        /// runs October, November, December, January.
        let months: [Int]
        /// How many letters into the text it starts.
        let at: Int
    }

    /// Finds every month name, as a whole word, in any case. Built once
    /// and kept, because building a pattern is slow.
    ///
    /// `(?<![a-z])` and `(?![a-z])` mean "no letter just before" and
    /// "no letter just after", so "mar" is not found inside "marrow",
    /// nor "may" inside "maybe". The long names come first so that
    /// "march" is not read as "mar" with "ch" left over.
    private static let namePattern: NSRegularExpression? = {
        let longestFirst = names.map(\.0).sorted { $0.count > $1.count }
        let pattern = "(?<![a-z])(" + longestFirst.joined(separator: "|") + ")(?![a-z])"
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    /// The words that join two months into a range.
    private static let rangeWords: Set<String> = ["-", "\u{2013}", "\u{2014}", "to", "until", "till", "through"]
    /// Words that may sit inside a range without breaking it, as in
    /// "March to late May".
    private static let fillerWords: Set<String> = ["early", "mid", "late", "the", "end", "of", "start", "beginning"]

    /// Every month and range of months in a text, in the order written.
    ///
    ///   "mar apr may"                          three, one month each
    ///   "Mar-May"                              one: March, April, May
    ///   "March to May and August to September" two ranges
    ///   "Oct-Mar"                              one, over the new year
    ///   "Seedlings may take 21 days"           none: this "may" is not the month
    static func spans(in text: String) -> [Span] {
        guard let namePattern else { return [] }
        let whole = NSRange(text.startIndex..., in: text)

        // 1. Each month name: which month, and where it starts and ends.
        var found: [(month: Int, start: Int, end: Int)] = []
        for fitted in namePattern.matches(in: text, range: whole) {
            guard let range = Range(fitted.range, in: text) else { continue }
            let word = String(text[range])
            guard let month = names.first(where: { $0.0 == word.lowercased() })?.1 else { continue }
            found.append((month, fitted.range.location, fitted.range.location + fitted.range.length))
        }

        // What lies between two places in the text, in small letters.
        func between(_ from: Int, _ to: Int) -> String {
            guard to >= from, let range = Range(NSRange(location: from, length: to - from), in: text) else { return "" }
            return text[range].lowercased()
        }
        // True when what lies between two months joins them as a range:
        // a dash or "to", with nothing else but words like "late".
        func isRange(_ gap: String) -> Bool {
            let spaced = gap.replacingOccurrences(of: "([-\u{2013}\u{2014}])", with: " $1 ", options: .regularExpression)
            let words = spaced.split(whereSeparator: { $0 == " " || $0 == "." }).map(String.init)
                .filter { !fillerWords.contains($0) }
            // "to mid-May" leaves a dash behind once "mid" is gone, so
            // up to two joining words are allowed.
            return !words.isEmpty && words.count <= 2 && words.allSatisfy { rangeWords.contains($0) }
        }

        // 2. "may" is also an everyday word. A packet's "Seedlings may
        //    take 21 days" is not about May. It is the month when it
        //    has a capital, or stands next to another month, or when
        //    the text has no capitals at all (the spreadsheet's "mar
        //    apr may"). "May be sown..." and the like are never it.
        let hasCapitals = text.contains { $0.isUppercase }
        found = found.enumerated().filter { index, name in
            guard name.month == 5 else { return true }
            let after = between(name.end, min(name.end + 9, whole.length))
            if [" be ", " take ", " need ", " require ", " also ", " not ", " benefit ", " have ", " cause "].contains(where: { (after + " ").hasPrefix($0) }) { return false }
            let firstLetter = Range(NSRange(location: name.start, length: 1), in: text).map { String(text[$0]) } ?? ""
            if firstLetter != firstLetter.lowercased() || !hasCapitals { return true }
            let nearBefore = index > 0 && name.start - found[index - 1].end <= 8
            let nearAfter = index + 1 < found.count && found[index + 1].start - name.end <= 8
            return nearBefore || nearAfter
        }.map(\.element)

        // 3. Join neighbours into ranges. Two joined months are a range.
        //    Three or more in a chain ("Mar-Apr-May") are a list written
        //    with dashes, and are left as the months named.
        var result: [Span] = []
        var index = 0
        while index < found.count {
            var last = index
            while last + 1 < found.count, isRange(between(found[last].end, found[last + 1].start)) { last += 1 }
            if last == index + 1 {
                let from = found[index].month, to = found[last].month
                // After December comes January: "Oct-Mar" wraps round.
                let months = from <= to ? Array(from...to) : Array(from...12) + Array(1...to)
                result.append(Span(months: months, at: found[index].start))
            } else {
                for name in found[index...last] { result.append(Span(months: [name.month], at: name.start)) }
            }
            index = last + 1
        }
        return result
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

// MARK: - Lengths of time

/// Reads a length of time with its unit: "12-16 weeks", "9-12 months".
///
/// `RangeParser` above only finds the numbers. Until 14 November 2026
/// "Sow to crop" was read with it and the numbers were taken as days,
/// so garlic's "20 weeks" was shown as "20 days" and Today thought a
/// crop was ready to pick after 20 days. Every sow-to-crop figure in
/// the spreadsheet is in weeks or months.
enum DurationParser {

    /// The units a length of time may be written in.
    enum TimeUnit: String, CaseIterable {
        case days, weeks, months, years

        /// How many days one of them is. A month is a twelfth of a year.
        var inDays: Double {
            switch self {
            case .days: return 1
            case .weeks: return 7
            case .months: return 365.25 / 12
            case .years: return 365.25
            }
        }

        /// The ways it is written, shortest forms included.
        fileprivate var spellings: [String] {
            switch self {
            case .days: return ["day"]
            case .weeks: return ["week", "wk"]
            case .months: return ["month", "mth"]
            case .years: return ["year", "yr"]
            }
        }

        /// "week" for one and "weeks" for more.
        func word(for howMany: Double) -> String {
            howMany == 1 ? String(rawValue.dropLast()) : rawValue
        }
    }

    /// The numbers and the unit, as written: "12-16 weeks" is 12 to 16
    /// and weeks. Nil if there is no number.
    ///
    /// The unit is the first one named. Only the numbers before it are
    /// used, so "12 weeks (84 days)" is 12 weeks and not 12 to 84. With
    /// no unit named the figure is taken as days, which is what the
    /// germination column is in.
    static func read(_ text: String?) -> (span: NumericRange, timeUnit: TimeUnit)? {
        guard let text, !text.isEmpty else { return nil }
        let lower = text.lowercased()

        // Where each unit is first named, if it is. The earliest wins.
        var firstNamed: (timeUnit: TimeUnit, at: String.Index)?
        for timeUnit in TimeUnit.allCases {
            for spelling in timeUnit.spellings {
                if let place = lower.range(of: spelling)?.lowerBound, place < (firstNamed?.at ?? lower.endIndex) {
                    firstNamed = (timeUnit, place)
                }
            }
        }

        guard let earliest = firstNamed else {
            return RangeParser.range(in: lower).map { ($0, .days) }
        }
        // The figures before the unit, or failing that all of them, as
        // in "weeks: 12-16".
        let before = String(lower[..<earliest.at])
        guard let span = RangeParser.range(in: before) ?? RangeParser.range(in: lower) else { return nil }
        return (span, earliest.timeUnit)
    }

    /// The length of time in days: "12-16 weeks" is 84 to 112.
    static func days(in text: String?) -> NumericRange? {
        guard let length = read(text) else { return nil }
        return NumericRange(lower: length.span.lower * length.timeUnit.inDays,
                            upper: length.span.upper * length.timeUnit.inDays)
    }

    /// As it should be shown, in its own unit: "20 weeks", "9–12 months".
    static func describe(_ text: String?) -> String? {
        guard let length = read(text) else { return nil }
        return "\(length.span.description) \(length.timeUnit.word(for: length.span.upper))"
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
