//
//  RecordWarnings.swift
//  Windfall
//
//  Odd-record warnings before an iRecord export (doc 120, use 13; doc
//  140). Rules and plain sums, no model.
//
//  A record that iRecord would refuse is already held back by
//  `WildlifeObservation.validationProblems` (no name confirmed, no grid
//  reference, no recorder, no life stage). These are the other kind: a
//  record iRecord would take, but that a county recorder would query.
//  A butterfly in January, a name not on the UK list, a date that has
//  not happened yet, a grid reference of the wrong shape. Each is shown
//  before the file is made, and William decides whether to send it.
//
//  Kept apart from the screen so that the logic tests can check every
//  rule with a made-up list and a made-up clock.
//

import Foundation

/// One thing that looks odd about a record.
struct RecordWarning: Equatable, Identifiable {

    enum Kind: String, Equatable {
        /// Seldom recorded in the UK in that month.
        case outOfSeason
        /// Not among the animals with 20 or more confirmed UK records,
        /// nor in a genus that is.
        case outOfRange
        /// Dated later than now.
        case futureDate
        /// No grid reference at all. iRecord refuses these, so the record
        /// is held back from the file whatever is chosen.
        case noGridReference
        /// A grid reference that is not of the shape OS grid references
        /// take.
        case oddGridReference
    }

    let kind: Kind
    /// One plain sentence, shown under the record's name.
    let words: String
    var id: String { kind.rawValue }

    /// True for a warning that keeps the record out of the file
    /// regardless (iRecord would refuse the whole file otherwise).
    var holdsBack: Bool { kind == .noGridReference }
}

enum RecordWarnings {

    /// An animal is only said to be out of season when its list holds at
    /// least this many records, so a month with none means something.
    /// ⚠️ CHECK: Claude's number.
    static let fewestForSeason = 50

    /// What looks odd about one record.
    ///
    /// - `scientificName`: the accepted or given scientific name, if any.
    ///   Without one, season and range are not checked: there is nothing
    ///   to look up by.
    /// - `book`: the UK wildlife list (WildlifeReference.json).
    static func warnings(scientificName: String?, observedAt: Date,
                         gridReference: String?, book: WildlifeReference,
                         now: Date = .now, calendar: Calendar = .current) -> [RecordWarning] {
        var found: [RecordWarning] = []

        // A date in the future. An hour's grace for a clock that differs.
        if observedAt > now.addingTimeInterval(3600) {
            found.append(RecordWarning(kind: .futureDate,
                                       words: "Dated \(dayWords(observedAt, calendar: calendar)), which has not come yet."))
        }

        // The grid reference: missing, or not of the right shape.
        let grid = (gridReference ?? "").trimmingCharacters(in: .whitespaces)
        if grid.isEmpty {
            found.append(RecordWarning(kind: .noGridReference,
                                       words: "No grid reference. iRecord needs one, so this record stays out of the file."))
        } else if !looksLikeGridReference(grid) {
            found.append(RecordWarning(kind: .oddGridReference,
                                       words: "\"\(grid)\" is not the shape of an OS grid reference (two letters and an even number of figures, such as ST 6541 7720)."))
        }

        // Season and range, from the UK list.
        if let name = scientificName?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
            if let animal = book.animal(scientificName: name) {
                let month = calendar.component(.month, from: observedAt)
                let total = animal.monthCounts?.reduce(0, +) ?? 0
                if total >= fewestForSeason, animal.isAbout(inMonth: month) == false {
                    let usual = animal.seasonWords.map { " Usually \($0)." } ?? ""
                    found.append(RecordWarning(kind: .outOfSeason,
                                               words: "Seldom recorded in \(monthName(month)): fewer than 2 in 100 of its UK records.\(usual)"))
                }
            } else if !book.knowsGenus(of: name) {
                found.append(RecordWarning(kind: .outOfRange,
                                           words: "\(name) is not on the UK list (animals with 20 or more confirmed UK records), nor is its genus. Worth checking the name."))
            }
        }
        return found
    }

    /// Whether some text has the shape of an OS grid reference: for Great
    /// Britain two letters, the first H, J, N, O, S or T, the second any
    /// but I; for Ireland one letter but I. Then an even number of
    /// figures, 2 to 10, spaces allowed. The shape only: a square in the
    /// sea passes.
    static func looksLikeGridReference(_ text: String) -> Bool {
        let plain = text.uppercased().filter { !$0.isWhitespace }
        let letters = plain.prefix { $0.isLetter }
        let figures = plain.dropFirst(letters.count)
        guard figures.allSatisfy({ $0.isASCII && $0.isNumber }),
              figures.count >= 2, figures.count <= 10, figures.count % 2 == 0 else { return false }
        let all = Array(letters)
        switch all.count {
        case 2:
            return "HJNOST".contains(all[0]) && all[1] != "I" && all[1].isASCII
        case 1:
            return all[0] != "I" && all[0].isASCII
        default:
            return false
        }
    }

    // MARK: Words

    static func monthName(_ month: Int) -> String {
        let names = ["January", "February", "March", "April", "May", "June", "July",
                     "August", "September", "October", "November", "December"]
        return (1...12).contains(month) ? names[month - 1] : "that month"
    }

    /// "3 August 2027".
    static func dayWords(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.day ?? 0) \(monthName(parts.month ?? 0)) \(parts.year ?? 0)"
    }
}
