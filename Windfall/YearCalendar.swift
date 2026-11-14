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
        case .harvest:
            // The allotment sheet's "Harvest" and the permaculture sheet's
            // "Fruiting/Harvest" arrive in two fields. Both count, so fruit
            // trees show here too.
            return Array(Set(MonthParser.months(in: plant.harvestMonthsText))
                .union(MonthParser.months(in: plant.fruitingMonthsText))).sorted()
        case .flowering:   return MonthParser.months(in: plant.floweringMonthsText)
        }
    }
}

/// Where one month falls in the stretch of months a job can be done in.
/// The month's own page uses it to say "Last chance" or "Starts now".
///
/// The numbers put the urgent ones first: a list sorted by them starts
/// with what cannot wait.
enum MonthPlace: Int, Equatable {
    /// The job can be done in this month and in neither neighbour.
    case onlyMonth = 0
    /// The last month of a longer stretch.
    case lastChance = 1
    /// The first month of a longer stretch.
    case opening = 2
    /// In the middle of a stretch, or the job can be done all year.
    case during = 3
}

/// One plant under one job on a month's page.
struct MonthEntry: Identifiable {
    let plant: Plant
    /// Where the month falls in this job's stretch for this plant.
    let monthPlace: MonthPlace
    /// The last month of the stretch, 1 to 12. Nil when the job can be
    /// done all year, which has no last month.
    let lastMonth: Int?

    var id: UUID { plant.id }
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

    // MARK: One month

    /// The month after, going round from December to January.
    static func monthAfter(_ month: Int) -> Int { month >= 12 ? 1 : month + 1 }

    /// The month before, going round from January to December.
    static func monthBefore(_ month: Int) -> Int { month <= 1 ? 12 : month - 1 }

    // MARK: Months as pages

    /// A month's page lays the months out side by side, like the pages
    /// of a calendar, so a finger can swipe from one to the next. To let
    /// December lead on to January the twelve are repeated: this many
    /// pages in all, which is twenty years. The page opens in the middle,
    /// ten years of swiping from either end.
    static let monthPageCount = 240

    /// The month a page shows, 1 to 12. Page 0 is January, page 11 is
    /// December and page 12 is January again. `%` is the remainder after
    /// dividing, which is what makes the months go round.
    static func month(atPage page: Int) -> Int {
        ((page % 12) + 12) % 12 + 1
    }

    /// The page to open on for a month: the one in the middle year.
    static func middlePage(for month: Int) -> Int {
        monthPageCount / 2 + min(max(month, 1), 12) - 1
    }

    /// The page showing a month that is the shortest way from the page
    /// now showing. From November, January is two pages on, not ten
    /// pages back.
    static func page(for month: Int, nearest page: Int) -> Int {
        var steps = (month - self.month(atPage: page)) % 12
        if steps > 6 { steps -= 12 }
        if steps < -5 { steps += 12 }
        var found = page + steps
        // Never off either end of the pages.
        if found < 0 { found += 12 }
        if found >= monthPageCount { found -= 12 }
        return found
    }

    /// Where a month falls in a job's months, or nil when the job cannot
    /// be done that month.
    ///
    /// It looks at the two neighbours. With February to April: February
    /// has nothing before it, so it is the opening. April has nothing
    /// after it, so it is the last chance. March has both, so it is
    /// "during". December and January count as neighbours, so October to
    /// February is one stretch.
    static func place(of month: Int, in months: [Int]) -> MonthPlace? {
        let chosen = Set(months.filter { (1...12).contains($0) })
        guard chosen.contains(month) else { return nil }
        let hasBefore = chosen.contains(monthBefore(month))
        let hasAfter = chosen.contains(monthAfter(month))
        if !hasBefore && !hasAfter { return .onlyMonth }
        if !hasAfter { return .lastChance }
        if !hasBefore { return .opening }
        return .during
    }

    /// The last month of the stretch a month is in: for March in
    /// February to April, April. Nil when the month is not one of them,
    /// or when all twelve are, which never ends.
    static func lastMonth(from month: Int, in months: [Int]) -> Int? {
        let chosen = Set(months.filter { (1...12).contains($0) })
        guard chosen.contains(month), chosen.count < 12 else { return nil }
        var end = month
        // Step forward a month at a time until the next one is missing.
        while chosen.contains(monthAfter(end)) { end = monthAfter(end) }
        return end
    }

    /// The plants a job can be done for in one month, the urgent ones
    /// first and A to Z within each kind.
    static func entries(for job: YearActivity, in month: Int, from plants: [Plant]) -> [MonthEntry] {
        var found: [MonthEntry] = []
        for plant in plants {
            let months = job.months(for: plant)
            guard let falls = place(of: month, in: months) else { continue }
            found.append(MonthEntry(plant: plant, monthPlace: falls,
                                    lastMonth: lastMonth(from: month, in: months)))
        }
        func sortName(_ entry: MonthEntry) -> String {
            (entry.plant.commonName + " " + (entry.plant.variety ?? "")).lowercased()
        }
        return found.sorted { a, b in
            if a.monthPlace != b.monthPlace { return a.monthPlace.rawValue < b.monthPlace.rawValue }
            return sortName(a) < sortName(b)
        }
    }

    /// The few words shown beside a plant on a month's page, or nil when
    /// the month is in the middle of the stretch and there is nothing
    /// pressing to say. A flower is not a job, so it has no "last
    /// chance": it is in its last month.
    static func tag(for monthPlace: MonthPlace, job: YearActivity) -> String? {
        switch monthPlace {
        case .onlyMonth: return "This month only"
        case .lastChance: return job == .flowering ? "Last month" : "Last chance"
        case .opening: return "Starts now"
        case .during: return nil
        }
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
