//
//  YearCalendar.swift
//  Windfall
//
//  The workings behind the Year page: which jobs it can show, and how a
//  plant's months are joined into runs.
//
//  A "run" is a stretch of months in a row. March, April and May are one
//  run. February on its own is a run one month long. The Year page draws
//  a run of one month as a dot and a longer run as a bar with round ends,
//  so the eye sees a season at a glance.
//
//  Nothing in this file draws anything. That keeps it small enough to be
//  tested without a screen. The drawing is in YearView.swift.
//

import Foundation

/// The jobs the Year page can show.
enum YearActivity: String, CaseIterable, Identifiable {
    case sowIndoors = "Sow indoors"
    case sowOutdoors = "Sow outdoors"
    case plantOut = "Plant out"
    case harvest = "Harvest"
    case flowering = "Flowering"

    var id: String { rawValue }

    /// The months, 1 for January to 12 for December, in which this job
    /// can be done for a plant. Read from the words in the plant's record.
    func months(for plant: Plant) -> [Int] {
        switch self {
        case .sowIndoors:  return MonthParser.months(in: plant.sowIndoorsMonthsText)
        case .sowOutdoors: return MonthParser.months(in: plant.sowOutdoorsMonthsText)
        case .plantOut:    return MonthParser.months(in: plant.plantOutMonthsText)
        case .harvest:     return MonthParser.months(in: plant.harvestMonthsText)
        case .flowering:   return MonthParser.months(in: plant.floweringMonthsText)
        }
    }
}

/// A stretch of months in a row.
struct MonthRun: Equatable {
    /// The first and last month of the run, 1 to 12.
    var first: Int
    var last: Int
    /// True when the window really began before January: it runs on from
    /// December. October to February is drawn as two runs, and this is
    /// how the January one knows it is the tail of the autumn one.
    var continuesBefore = false
    /// True when the window carries on past December into January.
    var continuesAfter = false

    /// How many months long the run is.
    var length: Int { last - first + 1 }

    func contains(_ month: Int) -> Bool { month >= first && month <= last }
}

enum YearCalendar {

    /// Joins months into runs. 2, 3, 4 and 9 become February to April,
    /// and September.
    static func runs(in months: [Int]) -> [MonthRun] {
        // Tidy the list first: only real months, each once, in order.
        let tidy = Array(Set(months.filter { (1...12).contains($0) })).sorted()
        var found: [MonthRun] = []
        for month in tidy {
            if let last = found.last, last.last == month - 1 {
                // Next door to the run before: make that run longer.
                found[found.count - 1].last = month
            } else {
                found.append(MonthRun(first: month, last: month))
            }
        }
        // A window that includes both December and January, but not the
        // whole year, wraps round the end of the year.
        if tidy.count < 12, tidy.first == 1, tidy.last == 12, found.count >= 2 {
            found[0].continuesBefore = true
            found[found.count - 1].continuesAfter = true
        }
        return found
    }

    /// The month a window opens: the first month whose month before is
    /// not part of it. October to February opens in October. Used to put
    /// plants in the order their seasons begin.
    static func opens(_ months: [Int]) -> Int {
        let chosen = Set(months)
        for month in 1...12 where chosen.contains(month) {
            let before = month == 1 ? 12 : month - 1
            if !chosen.contains(before) { return month }
        }
        // Empty, or all twelve months.
        return chosen.isEmpty ? 13 : 1
    }

    /// A key for putting plants of one family together.
    ///
    /// The records sometimes spell a family two ways, "Allium" and
    /// "Alliums". Lower case with any final "s" removed is the same for
    /// both, so they land in one group.
    static func familyKey(_ name: String) -> String {
        var key = name.trimmingCharacters(in: .whitespaces).lowercased()
        if key.count > 3, key.hasSuffix("s") { key.removeLast() }
        return key
    }

    /// The name to show for a family when it has been spelt several ways:
    /// the spelling most plants use, and the longer one if that is a tie.
    static func familyTitle(from spellings: [String]) -> String {
        var counts: [String: Int] = [:]
        for spelling in spellings { counts[spelling, default: 0] += 1 }
        let best = counts.max { a, b in
            if a.value != b.value { return a.value < b.value }
            if a.key.count != b.key.count { return a.key.count < b.key.count }
            return a.key > b.key
        }
        return best?.key ?? ""
    }

    /// The runs in words, for VoiceOver: "February to April and October
    /// to November". A window that wraps the year is read as one stretch.
    static func words(for runs: [MonthRun]) -> String {
        guard !runs.isEmpty else { return "no months" }
        let names = Calendar.current.monthSymbols
        func name(_ month: Int) -> String { names[month - 1] }
        func phrase(_ first: Int, _ last: Int) -> String {
            first == last ? name(first) : "\(name(first)) to \(name(last))"
        }
        if runs.count == 1, runs[0].first == 1, runs[0].last == 12 { return "all year" }

        var parts = runs.map { phrase($0.first, $0.last) }
        // Stitch the two halves of a wrapped window back together.
        if runs.count >= 2, runs[0].continuesBefore, runs[runs.count - 1].continuesAfter {
            parts.removeFirst()
            parts[parts.count - 1] = phrase(runs[runs.count - 1].first, runs[0].last)
        }
        if parts.count == 1 { return parts[0] }
        return parts.dropLast().joined(separator: ", ") + " and " + parts[parts.count - 1]
    }
}
