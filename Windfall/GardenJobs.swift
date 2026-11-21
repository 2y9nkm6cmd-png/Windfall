//
//  GardenJobs.swift
//  Windfall
//
//  Jobs of your own: the ones no season or sowing month would ever
//  suggest. "I need to build the wigwam in the allotment at the weekend."
//
//  "This week" and "This month" on the Today screen are worked out from
//  the plant library, the records and the forecast. Nothing in those
//  knows that a wigwam wants building. So a job of your own is a record
//  you add, by telling Eira or by hand, and it is listed beside the
//  worked-out ones until it is ticked.
//
//  This file holds three things:
//
//  1. `GardenJob`, the record.
//  2. The reader. It takes a sentence and decides whether it is a job to
//     do, and if so what the job is, when it is for and which garden.
//  3. The lists. Given the jobs on record and today's date, which belong
//     under "This week", which wait, and how each one's day is worded.
//
//  The reading is done by fixed rules, not by the AI model behind Eira,
//  for the same reason as the journal's offers (JournalOffers.swift):
//  the same words must give the same card every time, on any device,
//  with or without a model. Rules will miss some ways of putting things.
//  A miss costs nothing: the words go to Eira as they always did, and a
//  job can be added by hand.
//
//  Nothing is saved by the reader. It hands back what it understood, the
//  screen shows that as a card (JobViews.swift), and the record is made
//  only when Add is pressed.
//
//  Apart from the record itself, nothing here draws anything or touches
//  the records, so it can be tested without a screen.
//
//  ⚠️ CHECK: what "next weekend" and "next Friday" mean, and the months
//  of each season, are Claude's choices of 14 November 2026. They are
//  set out in `Reading when` below and the card lets any of them be
//  changed before it is added.
//

import Foundation
import SwiftData

// MARK: - The record

/// One job of your own.
///
/// `@Model` asks SwiftData to store this class in the database. Every
/// property has a starting value or is optional (the `?`), because
/// iCloud sync needs that of every record type.
@Model
final class GardenJob {

    var id: UUID = UUID()
    var createdAt: Date = Date.now

    /// What is to be done: "Build the wigwam".
    var title: String = ""

    /// The first and last day it is for, each as the start of that day.
    /// A job for one day has the same day in both. A job for "the
    /// weekend" has Saturday and Sunday. Both empty means whenever.
    var dueFrom: Date?
    var dueBy: Date?

    /// The garden it is for, as that garden's `siteKey`. Empty if none
    /// was named.
    var siteKey: String?

    /// When it was ticked. Empty while it is still to do.
    var doneAt: Date?

    /// The sentence it was read from, if it came from one. Kept so that
    /// a job the reader got wrong can be traced back to the words.
    var saidAs: String?

    /// For a "Sow again" job (SowAgain.swift): the crop it is for, by
    /// its tidy name, such as "Lettuce". Every variety of the crop
    /// shares one chain of sowings. Empty for any other job.
    /// Added 21 November 2026.
    var cropName: String?

    /// For a "Sow again" job: the sowing it follows, by that sowing's
    /// id. Kept as an id, not a link, so deleting the sowing leaves the
    /// job alone. Added 21 November 2026.
    var afterSowingID: UUID?

    init(title: String = "") {
        self.title = title
    }

    var isDone: Bool { doneAt != nil }

    /// True for a job that offers the next sowing of a crop.
    var isSowAgain: Bool { !(cropName ?? "").isEmpty }
}

// MARK: - What the reader is told and hands back

/// A garden the reader can look for in a sentence.
struct JobPlace: Equatable {
    /// The garden's `siteKey`.
    let key: String
    /// What you call it.
    let name: String
}

/// The days a job is for. Both empty means no date.
///
/// `Hashable` lets a menu use one of these as the value it has chosen.
struct JobDays: Equatable, Hashable {
    var from: Date?
    var by: Date?

    static let whenever = JobDays(from: nil, by: nil)

    /// One day.
    static func day(_ day: Date) -> JobDays { JobDays(from: day, by: day) }
}

/// What a sentence was understood to ask for.
struct JobOffer: Equatable {
    /// "Build the wigwam"
    var title: String
    var span: JobDays
    /// The garden named, as its `siteKey`.
    var siteKey: String?
}

/// What the lists need to know about one job on record.
struct JobFacts: Equatable {
    /// The job's own identifier, as text.
    let key: String
    let title: String
    let span: JobDays
    /// The name of its garden, if it has one.
    let place: String?
    let doneAt: Date?
}

// MARK: - The reader

enum GardenJobs {

    // MARK: Words

    /// One word of a sentence, as typed and as it is matched.
    private struct Word {
        /// As typed: "Wigwam,"
        let shown: String
        /// Lower case, with the marks around it taken off: "wigwam"
        let plain: String
    }

    /// Splits text into words. `plain` keeps letters, digits and the
    /// apostrophe inside a word, so "don't" stays one word and "weekend."
    /// loses its full stop.
    private static func words(in text: String) -> [Word] {
        text.replacingOccurrences(of: "\u{2019}", with: "'")
            .split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
            .map { piece in
                let lowered = piece.lowercased()
                let plain = lowered.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                return Word(shown: String(piece), plain: plain)
            }
    }

    /// Ways of saying there is something to do. Each is a run of words.
    /// Longer runs come first so that "remind me that i need to" is not
    /// read as "i need to" with "remind me that" left over.
    private static let openers: [[String]] = [
        ["remind", "me", "that", "i", "need", "to"], ["remind", "me", "that", "we", "need", "to"],
        ["remind", "me", "i", "need", "to"], ["don't", "let", "me", "forget", "to"],
        ["i", "have", "got", "to"], ["we", "have", "got", "to"],
        ["remind", "me", "to"], ["remind", "us", "to"], ["don't", "forget", "to"],
        ["i", "need", "to"], ["we", "need", "to"], ["i", "have", "to"], ["we", "have", "to"],
        ["i've", "got", "to"], ["we've", "got", "to"], ["i", "still", "need", "to"], ["we", "still", "need", "to"],
        ["remember", "to"], ["i", "must"], ["we", "must"]
    ]

    /// The same, for a list: "Add a job to net the brassicas".
    private static let listOpeners: [[String]] = [
        ["add", "a", "job", "to"], ["add", "a", "task", "to"], ["add", "a", "job", "for"], ["add", "a", "task", "for"],
        ["add", "to", "my", "jobs"], ["add", "to", "the", "jobs"], ["add", "to", "my", "list"],
        ["add", "a", "job"], ["add", "a", "task"], ["add", "job"], ["add", "task"],
        ["new", "job"], ["new", "task"]
    ]

    /// Said at the very start with nobody doing it: "Need to net the
    /// brassicas", "Must order seed potatoes".
    private static let bareOpeners: [[String]] = [["need", "to"], ["must"], ["got", "to"], ["have", "to"]]

    /// A label at the very start, which must end in a colon: "Job: fix
    /// the gate".
    private static let labels: [[String]] = [["job"], ["task"], ["to", "do"], ["todo"], ["to-do"]]

    /// Words that may come before any of the above and mean nothing:
    /// "Eira, please can you remind me to".
    private static let leadIns: Set<String> = [
        "eira", "hey", "hi", "hello", "ok", "okay", "please", "so", "right", "and", "also", "oh", "can", "could",
        "would", "will", "you"
    ]

    /// A sentence that opens with one of these is asking, not telling.
    private static let askingStarts: Set<String> = [
        "what", "what's", "when", "where", "which", "who", "why", "how", "do", "does", "did", "is", "are",
        "should", "shall", "if", "whether", "am"
    ]

    /// Straight before "I need to", any of these makes it a question or
    /// a maybe: "do I need to water", "if I need to".
    private static let doubtBefore: Set<String> = [
        "do", "did", "does", "if", "whether", "when", "why", "how", "what", "where", "unless", "don't", "didn't"
    ]

    /// Straight after "I need to", these are about finding out, which is
    /// a question for Eira: "I need to know when to prune".
    private static let findingOut: Set<String> = [
        "know", "understand", "learn", "ask", "decide", "think", "wonder", "choose", "be"
    ]
    private static let findingOutPairs: Set<String> = [
        "find out", "work out", "figure out", "look up", "look into", "check if", "check whether", "check when",
        "check how", "see if", "see whether", "see how", "see what"
    ]

    /// Tidied off the end of a title wherever they fall: "Net the
    /// brassicas please".
    private static let closers: Set<String> = ["and", "then", "sometime", "please", "thanks", "eira"]

    /// Words that lead up to a day or a garden. One of these is only
    /// left hanging if what it led up to has been lifted out: the "by"
    /// of "by tomorrow", the "for" of "for this weekend".
    private static let links: Set<String> = [
        "the", "my", "our", "at", "by", "for", "to", "before", "until", "till", "during"
    ]

    /// Words that are as often part of the job itself: "put the cables
    /// in", "dig the potatoes up", "turn the heater on". These stay.
    /// The one exception is "in the" or "on the" before a day ("in the
    /// next week"), where "the" shows the word was leading up to it.
    private static let particles: Set<String> = ["in", "on", "up", "down"]

    /// "Over" goes either way: "turn the compost over this weekend"
    /// keeps it, "mulch the beds over this weekend" does not. It is kept
    /// when the job begins with a word that takes it.
    /// ⚠️ CHECK: this list is Claude's.
    private static let overVerbs: Set<String> = [
        "turn", "fork", "dig", "rake", "hoe", "go", "look", "check", "tip", "flip", "roll", "knock"
    ]

    // MARK: Reading a sentence

    /// Reads what was said and hands back the job in it, or nil if it
    /// does not read as a job to do.
    ///
    /// - `today`: when it was said. "At the weekend" is worked out from it.
    /// - `places`: the gardens on record, to look for by name.
    ///
    ///   "I need to build the wigwam in the allotment at the weekend"
    ///       the job "Build the wigwam", Saturday and Sunday, the allotment
    ///   "Remind me to order seed potatoes"
    ///       the job "Order seed potatoes", no date
    ///   "The fence needs fixing by Friday"
    ///       the job "The fence needs fixing", from today to Friday
    ///   "Do I need to water the beans?"         not a job: it asks
    ///   "I need to know when to prune"          not a job: it asks
    ///   "I planted the garlic"                  not a job: it is done
    static func offer(in text: String, today: Date, places: [JobPlace] = [],
                      calendar: Calendar = .current) -> JobOffer? {
        // A question mark anywhere means it is asking.
        guard !text.contains("?") else { return nil }

        // One sentence at a time, and the first with a job in it wins.
        for sentence in sentences(in: words(in: text)) {
            if let found = offer(inSentence: sentence, today: today, places: places, calendar: calendar) {
                return found
            }
        }
        return nil
    }

    /// Cuts a run of words into sentences, at a full stop, an
    /// exclamation mark or a semicolon.
    private static func sentences(in all: [Word]) -> [[Word]] {
        var found: [[Word]] = []
        var current: [Word] = []
        for word in all {
            current.append(word)
            if let last = word.shown.last, ".!;".contains(last) {
                found.append(current)
                current = []
            }
        }
        if !current.isEmpty { found.append(current) }
        return found
    }

    private static func offer(inSentence sentence: [Word], today: Date, places: [JobPlace],
                              calendar: Calendar) -> JobOffer? {
        // Drop "Eira, please can you" from the front.
        var start = 0
        while start < sentence.count, leadIns.contains(sentence[start].plain) { start += 1 }
        let said = Array(sentence[start...])
        guard let opening = said.first, !askingStarts.contains(opening.plain) else { return nil }
        let plain = said.map(\.plain)

        // Where the job's own words begin and end. `body` is the part
        // that becomes the title. The day and the garden are looked for
        // in the whole sentence, so "At the weekend I need to build the
        // wigwam" works too.
        var body: Range<Int>?
        /// True if the job was opened with "must", which has a second
        /// meaning: "I must have left the gate open" is a guess.
        var openedWithMust = false

        // 1. A label: "Job: fix the gate".
        for label in labels where body == nil {
            if starts(plain, with: label, at: 0), said[label.count - 1].shown.hasSuffix(":") {
                body = label.count..<said.count
            }
        }
        // 2. "Add a job to ...", near the start.
        for opener in listOpeners where body == nil {
            if starts(plain, with: opener, at: 0) { body = opener.count..<said.count }
        }
        // 3. "Need to ..." with nobody doing it, at the very start.
        for opener in bareOpeners where body == nil {
            if starts(plain, with: opener, at: 0) {
                body = opener.count..<said.count
                openedWithMust = opener.last == "must"
            }
        }
        // 4. "I need to ...", "remind me to ...", anywhere.
        if body == nil {
            search: for index in plain.indices {
                for opener in openers where starts(plain, with: opener, at: index) {
                    if index > 0, doubtBefore.contains(plain[index - 1]) { return nil }
                    body = (index + opener.count)..<said.count
                    openedWithMust = opener.last == "must"
                    break search
                }
            }
        }
        // 5. "The fence needs fixing", "the beds need mulching", "the
        //    hedge needs to be cut". The whole sentence is the title.
        var keepsWholeSentence = false
        if body == nil, let need = plain.firstIndex(where: { $0 == "needs" || $0 == "need" }), need > 0 {
            let nobody: Set<String> = ["i", "we", "you", "they", "he", "she", "it", "don't", "doesn't", "not", "to"]
            let after = Array(plain[(need + 1)...])
            let isDoing = after.prefix(2).contains { $0.count >= 6 && $0.hasSuffix("ing") }
            let isToBe = after.prefix(2) == ["to", "be"]
            if !nobody.contains(plain[need - 1]), isDoing || isToBe {
                body = 0..<said.count
                keepsWholeSentence = true
            }
        }
        guard let body, !body.isEmpty else { return nil }

        // "I need to know when to prune" is a question for Eira.
        if !keepsWholeSentence {
            let first = plain[body.lowerBound]
            let pair = body.count >= 2 ? first + " " + plain[body.lowerBound + 1] : first
            if findingOut.contains(first) || findingOutPairs.contains(pair) { return nil }
            if openedWithMust, ["have", "say", "admit"].contains(first) { return nil }
        }

        // The day, from anywhere in the sentence.
        var leftOut = Set<Int>()
        var span = JobDays.whenever
        if let found = when(in: plain, today: today, calendar: calendar) {
            span = found.span
            leftOut.formUnion(found.range)
        }

        // The garden, from anywhere in the sentence.
        var siteKey: String?
        if let found = place(in: plain, places: places) {
            siteKey = found.key
            leftOut.formUnion(found.lifted)
        }

        // The title: the job's own words, less the day and the garden.
        // `keptAt` holds the place of each word in the sentence, not the
        // word, so that the next step can ask what came after it.
        var keptAt = body.filter { !leftOut.contains($0) }

        // Tidy the end. A small word is only taken off if what it led up
        // to has gone, so "put the cables in this month" keeps its "in"
        // and "fix the gate by tomorrow" loses its "by". `gone` is every
        // place lifted or tidied away so far.
        var gone = leftOut
        var tookArticle = false
        let verb = keptAt.first.map { plain[$0] } ?? ""
        while let last = keptAt.last {
            let word = plain[last]
            let nextIsGone = gone.contains(last + 1)
            let isHanging: Bool
            if word.isEmpty || closers.contains(word) {
                isHanging = true
            } else if links.contains(word) {
                isHanging = nextIsGone
            } else if particles.contains(word) {
                isHanging = nextIsGone && tookArticle
            } else if word == "over" {
                isHanging = nextIsGone && !overVerbs.contains(verb)
            } else {
                isHanging = false
            }
            guard isHanging else { break }
            tookArticle = word == "the"
            gone.insert(last)
            keptAt.removeLast()
        }
        var kept = keptAt.map { said[$0] }
        while let first = kept.first, first.plain.isEmpty || first.plain == "to" || first.plain == "that" { kept.removeFirst() }
        var title = kept.map(\.shown).joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " .,;:!-"))
        guard title.contains(where: \.isLetter) else { return nil }
        // A capital letter to begin with. `prefix(1)` is the first
        // character and `dropFirst()` is everything after it.
        title = title.prefix(1).uppercased() + title.dropFirst()

        return JobOffer(title: title, span: span, siteKey: siteKey)
    }

    /// True if `run` appears in `plain` beginning at `index`.
    private static func starts(_ plain: [String], with run: [String], at index: Int) -> Bool {
        guard index >= 0, index + run.count <= plain.count else { return false }
        return Array(plain[index..<(index + run.count)]) == run
    }

    // MARK: Reading where

    /// Small words that lead up to a garden's name: "in the allotment",
    /// "up at the orchard".
    private static let placeLeads: Set<String> = ["in", "at", "on", "for", "up", "down", "over", "round", "around"]
    private static let placeArticles: Set<String> = ["the", "my", "our"]

    /// Looks for a garden by name.
    ///
    /// A garden is found by its whole name ("lower orchard"), or by one
    /// word of its name or key that no other garden shares
    /// ("allotment"). `lifted` is the words to leave out of the title:
    /// the name and what led up to it. A name with nothing leading up to
    /// it stays in the title, so "Weed the allotment" keeps its sense.
    private static func place(in plain: [String], places: [JobPlace]) -> (key: String, lifted: Range<Int>)? {
        guard !places.isEmpty else { return nil }

        // Each garden's whole name, and each single word only it has.
        var names: [(run: [String], key: String)] = []
        var owners: [String: Set<String>] = [:]
        for gardenPlace in places {
            let whole = words(in: gardenPlace.name).map(\.plain).filter { !$0.isEmpty }
            if !whole.isEmpty { names.append((whole, gardenPlace.key)) }
            for word in Set(whole + [gardenPlace.key.lowercased()]) where word.count >= 4 {
                owners[word, default: []].insert(gardenPlace.key)
            }
        }
        for (word, keys) in owners where keys.count == 1 {
            if let key = keys.first { names.append(([word], key)) }
        }
        // Longest first, so a whole name beats one word of it.
        names.sort { $0.run.count > $1.run.count }

        for index in plain.indices {
            for name in names where starts(plain, with: name.run, at: index) {
                // Walk back over "the", then "in" or "up at".
                var begin = index
                if begin > 0, placeArticles.contains(plain[begin - 1]) { begin -= 1 }
                var hasLead = false
                while begin > 0, placeLeads.contains(plain[begin - 1]) {
                    begin -= 1
                    hasLead = true
                }
                let end = index + name.run.count
                return (name.key, hasLead ? begin..<end : end..<end)
            }
        }
        return nil
    }

    // MARK: Reading when

    private static let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

    private static let months: [String: Int] = [
        "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6, "july": 7, "august": 8,
        "september": 9, "october": 10, "november": 11, "december": 12,
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "jun": 6, "jul": 7, "aug": 8, "sep": 9, "sept": 9, "oct": 10,
        "nov": 11, "dec": 12
    ]

    /// The first and last month of each season. ⚠️ CHECK: these are the
    /// Met Office's seasons, which begin on the first of the month.
    private static let seasons: [String: (first: Int, last: Int)] = [
        "spring": (3, 5), "summer": (6, 8), "autumn": (9, 11), "winter": (12, 2)
    ]

    private static let numbers: [String: Int] = [
        "a": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8,
        "nine": 9, "ten": 10, "couple": 2, "few": 3
    ]

    private static let partsOfDay: Set<String> = ["morning", "afternoon", "evening", "night", "lunchtime"]

    /// Phrases that always mean the same thing. Longer ones first.
    private enum Fixed {
        case today, tomorrow, weekend, nextWeekend, beforeWeekend, thisWeek, nextWeek, thisMonth, nextMonth, fewDays, noDate
    }

    private static let fixedPhrases: [([String], Fixed)] = [
        (["before", "the", "end", "of", "the", "week"], .thisWeek), (["by", "the", "end", "of", "the", "week"], .thisWeek),
        (["before", "the", "end", "of", "the", "month"], .thisMonth), (["by", "the", "end", "of", "the", "month"], .thisMonth),
        (["when", "i", "get", "a", "chance"], .noDate), (["when", "i", "get", "the", "chance"], .noDate),
        (["in", "the", "next", "few", "days"], .fewDays), (["over", "the", "next", "few", "days"], .fewDays),
        (["some", "time", "this", "week"], .thisWeek), (["some", "time", "next", "week"], .nextWeek),
        (["this", "coming", "weekend"], .weekend),
        (["at", "the", "weekend"], .weekend), (["over", "the", "weekend"], .weekend), (["on", "the", "weekend"], .weekend),
        (["by", "the", "weekend"], .beforeWeekend), (["before", "the", "weekend"], .beforeWeekend),
        (["sometime", "this", "week"], .thisWeek), (["later", "this", "week"], .thisWeek), (["during", "the", "week"], .thisWeek),
        (["sometime", "next", "week"], .nextWeek), (["later", "this", "month"], .thisMonth),
        (["at", "some", "point"], .noDate), (["when", "i", "can"], .noDate),
        (["this", "weekend"], .weekend), (["at", "weekend"], .weekend), (["next", "weekend"], .nextWeekend),
        (["the", "weekend"], .weekend),
        (["this", "week"], .thisWeek), (["next", "week"], .nextWeek), (["this", "month"], .thisMonth), (["next", "month"], .nextMonth),
        (["later", "today"], .today), (["this", "morning"], .today), (["this", "afternoon"], .today), (["this", "evening"], .today),
        (["tomorrow", "morning"], .tomorrow), (["tomorrow", "afternoon"], .tomorrow), (["tomorrow", "evening"], .tomorrow),
        (["some", "time"], .noDate), (["one", "day"], .noDate),
        (["today"], .today), (["tonight"], .today), (["tomorrow"], .tomorrow),
        (["soon"], .noDate), (["sometime"], .noDate), (["eventually"], .noDate)
    ]

    /// Looks for the day a job is for. Hands back the days and which
    /// words said so, or nil if no day was named. The earliest in the
    /// sentence wins.
    private static func when(in plain: [String], today: Date, calendar: Calendar) -> (span: JobDays, range: Range<Int>)? {
        let start = calendar.startOfDay(for: today)
        for index in plain.indices {
            if let found = when(at: index, in: plain, start: start, calendar: calendar) {
                return (found.span, index..<(index + found.length))
            }
        }
        return nil
    }

    /// Adds days to a date. `calendar.date(byAdding:)` is used, not a
    /// sum of seconds, so that the two days a year the clocks change are
    /// still whole days.
    private static func add(_ days: Int, to date: Date, _ calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// Tries to read a day beginning at one word.
    private static func when(at index: Int, in plain: [String], start: Date,
                             calendar: Calendar) -> (span: JobDays, length: Int)? {
        // Sunday is 1 and Saturday is 7 in Apple's calendar.
        let weekday = calendar.component(.weekday, from: start)
        // Days until the coming Saturday (none on a Saturday) and until
        // the Sunday that ends this week (none on a Sunday). `%` is the
        // remainder after dividing, which wraps the count round the week.
        let toSaturday = (7 - weekday) % 7
        let toSunday = (8 - weekday) % 7

        // 1. The phrases that always mean the same thing.
        for (phrase, meaning) in fixedPhrases where starts(plain, with: phrase, at: index) {
            let span: JobDays
            switch meaning {
            case .today: span = .day(start)
            case .tomorrow: span = .day(add(1, to: start, calendar))
            case .weekend:
                // On a Sunday the weekend is what is left of it: today.
                span = weekday == 1 ? .day(start)
                    : JobDays(from: add(toSaturday, to: start, calendar), by: add(toSaturday + 1, to: start, calendar))
            case .nextWeekend:
                // ⚠️ CHECK: taken as the weekend after the coming one.
                let saturday = weekday == 1 ? 6 : toSaturday + 7
                span = JobDays(from: add(saturday, to: start, calendar), by: add(saturday + 1, to: start, calendar))
            case .beforeWeekend:
                // From today to Friday, or just today if it is Friday or later.
                let toFriday = weekday == 1 ? 0 : max(toSaturday - 1, 0)
                span = JobDays(from: start, by: add(toFriday, to: start, calendar))
            case .thisWeek: span = JobDays(from: start, by: add(toSunday, to: start, calendar))
            case .nextWeek:
                span = JobDays(from: add(toSunday + 1, to: start, calendar), by: add(toSunday + 7, to: start, calendar))
            case .thisMonth: span = JobDays(from: start, by: monthEnd(of: start, calendar))
            case .nextMonth:
                let next = calendar.date(byAdding: .month, value: 1, to: monthStart(of: start, calendar)) ?? start
                span = JobDays(from: next, by: monthEnd(of: next, calendar))
            case .fewDays: span = JobDays(from: start, by: add(3, to: start, calendar))
            case .noDate: span = .whenever
            }
            return (span, phrase.count)
        }

        // The rest may begin with a small word: "on", "by", "next".
        var at = index
        var lead: String?
        if at < plain.count, ["on", "by", "before", "until", "till", "this", "next", "in", "during", "over", "early", "late"].contains(plain[at]) {
            lead = plain[at]
            at += 1
            // "in early March", "on the 21st", "this coming Friday".
            while at < plain.count, ["the", "early", "late", "coming"].contains(plain[at]) { at += 1 }
        }
        guard at < plain.count else { return nil }
        let word = plain[at]
        let isBy = lead == "by" || lead == "before" || lead == "until" || lead == "till"

        // 2. A day of the week: "on Saturday", "by Friday", "next Monday".
        if let number = weekdays.firstIndex(of: word), lead != "in", lead != "during", lead != "over" {
            var daysOn: Int
            if lead == "next" {
                // ⚠️ CHECK: "next Friday" is taken as the Friday of the
                // week that begins next Monday. `(number + 6) % 7` counts
                // days after Monday: 0 for Monday, 6 for Sunday.
                daysOn = toSunday + 1 + (number + 6) % 7
            } else {
                // The next such day, a week on if today is that day.
                daysOn = (number + 1 - weekday + 7) % 7
                if daysOn == 0 { daysOn = 7 }
            }
            var length = at - index + 1
            if at + 1 < plain.count, partsOfDay.contains(plain[at + 1]) { length += 1 }
            let day = add(daysOn, to: start, calendar)
            return (isBy ? JobDays(from: start, by: day) : .day(day), length)
        }

        // 3. A date: "on 21 November", "the 21st of November", "on the 21st".
        if let dayNumber = dayOfMonth(word) {
            var next = at + 1
            if next < plain.count, plain[next] == "of" { next += 1 }
            if next < plain.count, let month = months[plain[next]] {
                if let day = date(day: dayNumber, month: month, notBefore: start, calendar) {
                    return (isBy ? JobDays(from: start, by: day) : .day(day), next - index + 1)
                }
            } else if lead != nil, lead != "in", word.count > String(dayNumber).count {
                // "On the 21st" with no month: this month, or next if
                // that day has gone. It must be written "21st", not "21",
                // so that "by 2 metres" is not read as a date.
                let thisMonth = calendar.component(.month, from: start)
                if let day = date(day: dayNumber, month: thisMonth, notBefore: start, calendar, orNextMonth: true) {
                    return (isBy ? JobDays(from: start, by: day) : .day(day), at - index + 1)
                }
            }
            return nil
        }

        // 4. A month: "in March", "by December", and "November 21st".
        //    A month needs a small word before it or a day after it, so
        //    that "may" in "the beans may want water" is not a date.
        if let month = months[word] {
            // "May" is also an everyday word, so it needs a firmer lead:
            // "in May", not "this may".
            if word == "may", !["in", "during", "by", "before", "until", "till"].contains(lead ?? "") { return nil }
            if at + 1 < plain.count, let dayNumber = dayOfMonth(plain[at + 1]),
               let day = date(day: dayNumber, month: month, notBefore: start, calendar) {
                return (isBy ? JobDays(from: start, by: day) : .day(day), at - index + 2)
            }
            guard lead != nil, lead != "on" else { return nil }
            let year = calendar.component(.year, from: start)
            let thisMonth = calendar.component(.month, from: start)
            var parts = DateComponents()
            parts.year = month >= thisMonth ? year : year + 1
            parts.month = month
            parts.day = 1
            guard let first = calendar.date(from: parts) else { return nil }
            let last = monthEnd(of: first, calendar)
            // This month has already begun, so it starts today.
            let from = isBy || month == thisMonth ? start : first
            return (JobDays(from: from, by: lead == "before" ? add(-1, to: first, calendar) : last), at - index + 1)
        }

        // 5. A season: "in spring", "over the winter", "this autumn".
        if let season = seasons[word], lead != nil, lead != "on" {
            let year = calendar.component(.year, from: start)
            let thisMonth = calendar.component(.month, from: start)
            let wraps = season.first > season.last
            let isNow = wraps ? (thisMonth >= season.first || thisMonth <= season.last)
                              : (season.first...season.last).contains(thisMonth)
            var begins = DateComponents()
            begins.day = 1
            begins.month = season.first
            if isNow {
                // Winter in January or February began last December.
                begins.year = wraps && thisMonth <= season.last ? year - 1 : year
            } else {
                begins.year = thisMonth < season.first ? year : year + 1
            }
            guard let first = calendar.date(from: begins),
                  let lastMonth = calendar.date(byAdding: .month, value: 2, to: first) else { return nil }
            // "Before winter" ends the day before winter begins.
            if lead == "before", !isNow {
                return (JobDays(from: start, by: add(-1, to: first, calendar)), at - index + 1)
            }
            return (JobDays(from: isNow || isBy ? start : first, by: monthEnd(of: lastMonth, calendar)), at - index + 1)
        }

        // 6. "In a fortnight", "in two weeks", "in 3 days".
        if lead == "in" {
            if word == "a", at + 1 < plain.count, plain[at + 1] == "fortnight" {
                return (.day(add(14, to: start, calendar)), at - index + 2)
            }
            var next = at + 1
            var counted = numbers[word] ?? Int(word)
            // "In a couple of weeks", "in a few days".
            if word == "a", next < plain.count, let more = numbers[plain[next]], plain[next] != "a" {
                counted = more
                next += 1
            }
            guard let count = counted, count > 0, count <= 60 else { return nil }
            if next < plain.count, plain[next] == "of" { next += 1 }
            guard next < plain.count else { return nil }
            let unit = plain[next]
            let each = ["day": 1, "days": 1, "week": 7, "weeks": 7, "fortnight": 14, "fortnights": 14][unit]
            guard let each else { return nil }
            return (.day(add(count * each, to: start, calendar)), next - index + 1)
        }
        return nil
    }

    /// "21", "21st", "3rd": the number, if it could be a day of a month.
    private static func dayOfMonth(_ word: String) -> Int? {
        var digits = word
        for ending in ["st", "nd", "rd", "th"] where digits.hasSuffix(ending) { digits.removeLast(2) }
        guard let number = Int(digits), (1...31).contains(number) else { return nil }
        return number
    }

    /// The next time a day and month come round, today counted.
    private static func date(day: Int, month: Int, notBefore start: Date, _ calendar: Calendar,
                             orNextMonth: Bool = false) -> Date? {
        var parts = DateComponents()
        parts.year = calendar.component(.year, from: start)
        parts.month = month
        parts.day = day
        guard let first = calendar.date(from: parts), calendar.component(.day, from: first) == day else { return nil }
        if first >= start { return first }
        return calendar.date(byAdding: orNextMonth ? .month : .year, value: 1, to: first)
    }

    private static func monthStart(of date: Date, _ calendar: Calendar) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? date
    }

    /// The start of the last day of a date's month.
    private static func monthEnd(of date: Date, _ calendar: Calendar) -> Date {
        guard let month = calendar.dateInterval(of: .month, for: date) else { return date }
        return add(-1, to: month.end, calendar)
    }

    // MARK: - Wording a day

    /// "21 November", with the year if it is not this one.
    private static func dayAndMonth(_ date: Date, today: Date, _ calendar: Calendar) -> String {
        let month = calendar.monthSymbols[calendar.component(.month, from: date) - 1]
        var text = "\(calendar.component(.day, from: date)) \(month)"
        let year = calendar.component(.year, from: date)
        if year != calendar.component(.year, from: today) { text += " \(year)" }
        return text
    }

    private static func weekdayName(_ date: Date, _ calendar: Calendar) -> String {
        calendar.weekdaySymbols[calendar.component(.weekday, from: date) - 1]
    }

    private static func daysBetween(_ first: Date, _ second: Date, _ calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: first), to: calendar.startOfDay(for: second)).day ?? 0
    }

    /// One day in words: "Today", "Tomorrow", "Saturday" for a day this
    /// week, "Saturday 21 November" for any other.
    private static func oneDay(_ day: Date, today: Date, _ calendar: Calendar) -> String {
        switch daysBetween(today, day, calendar) {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        case 2...6: return weekdayName(day, calendar)
        default: return "\(weekdayName(day, calendar)) \(dayAndMonth(day, today: today, calendar))"
        }
    }

    /// The days a job is for, in words, as they stand today. Nil for a
    /// job with no date.
    ///
    /// The words are worked out from the dates each time, not kept from
    /// what was said, so "Tomorrow" becomes "Today" overnight and a day
    /// changed on the card is worded the same as one that was spoken.
    static func whenLine(_ span: JobDays, today: Date, calendar: Calendar = .current) -> String? {
        guard let from = span.from ?? span.by, let by = span.by ?? span.from else { return nil }
        let start = calendar.startOfDay(for: today)
        if daysBetween(from, by, calendar) <= 0 { return oneDay(by, today: start, calendar) }

        let isPast = by < start
        let isUnderWay = from <= start && !isPast
        let isWeekend = calendar.component(.weekday, from: from) == 7 && daysBetween(from, by, calendar) == 1
        let isWholeMonth = from == monthStart(of: from, calendar) && by == monthEnd(of: from, calendar)
        let weekday = calendar.component(.weekday, from: start)
        let sunday = add((8 - weekday) % 7, to: start, calendar)

        if isWeekend {
            if !isPast, daysBetween(start, from, calendar) <= 6 { return "This weekend" }
            return "Weekend of \(dayAndMonth(from, today: start, calendar))"
        }
        if isWholeMonth {
            let name = calendar.monthSymbols[calendar.component(.month, from: from) - 1]
            let year = calendar.component(.year, from: from)
            return year == calendar.component(.year, from: start) ? name : "\(name) \(year)"
        }
        if isUnderWay {
            if by == sunday { return "This week" }
            if by == monthEnd(of: start, calendar) { return "This month" }
            // "By tomorrow", "By Friday", "By Friday 27 November".
            let day = oneDay(by, today: start, calendar)
            return "By " + (day == "Tomorrow" ? "tomorrow" : day)
        }
        if from == add(1, to: sunday, calendar), by == add(7, to: sunday, calendar) { return "Next week" }

        // Any other run of days: "21 to 27 November", "28 November to 3 December".
        if calendar.component(.month, from: from) == calendar.component(.month, from: by),
           calendar.component(.year, from: from) == calendar.component(.year, from: by) {
            return "\(calendar.component(.day, from: from)) to \(dayAndMonth(by, today: start, calendar))"
        }
        return "\(dayAndMonth(from, today: start, calendar)) to \(dayAndMonth(by, today: start, calendar))"
    }

    /// True if a job's days have all gone by.
    static func isOverdue(_ span: JobDays, today: Date, calendar: Calendar = .current) -> Bool {
        guard let by = span.by ?? span.from else { return false }
        return by < calendar.startOfDay(for: today)
    }

    /// The line under a job's title: its garden and its day. "Allotment ·
    /// This weekend". A job whose days have gone says so: "Was for
    /// Saturday 14 November". Nil if there is neither garden nor day.
    static func detail(for job: JobFacts, today: Date, calendar: Calendar = .current) -> String? {
        var pieces: [String] = []
        if let place = job.place, !place.isEmpty { pieces.append(place) }
        if var when = whenLine(job.span, today: today, calendar: calendar) {
            if isOverdue(job.span, today: today, calendar: calendar) {
                // "Was for yesterday", "Was for the weekend of 14 November".
                if when == "Yesterday" { when = "yesterday" }
                if when.hasPrefix("Weekend of") { when = "the w" + when.dropFirst() }
                when = "Was for " + when
            }
            pieces.append(when)
        }
        return pieces.isEmpty ? nil : pieces.joined(separator: " · ")
    }

    /// What Eira says once a job is added.
    static func addedLine(title: String, span: JobDays, today: Date, calendar: Calendar = .current) -> String {
        var line = "Added to your jobs: \(title)."
        if let when = whenLine(span, today: today, calendar: calendar) {
            line += " It is down for \(when.prefix(1).lowercased() + when.dropFirst())."
        } else {
            line += " It has no date, so it stays on your list until you tick it."
        }
        return line
    }

    /// What Eira says in her chat when a message reads as a job. The
    /// card sits under the message and nothing is added until Add is
    /// pressed.
    static let offerReply = "That reads like a job to do. I have put what I understood on the card above. Change anything that is wrong, then press Add. Nothing is added until you do."

    /// What Eira says in her chat when the card is turned down.
    static let notAJobReply = "Left off your jobs. If that was a question for me, ask it again with a question mark and I will answer it."

    // MARK: - Choosing a day

    /// The days offered on the card, in order: no date, today, tomorrow,
    /// this weekend, this week, next week and this month. Any that come
    /// to the same days as an earlier one are left out, so a Sunday does
    /// not offer "Today" three times over.
    static func choices(today: Date, calendar: Calendar = .current) -> [JobDays] {
        let start = calendar.startOfDay(for: today)
        var found: [JobDays] = [.whenever]
        for phrase in [["today"], ["tomorrow"], ["this", "weekend"], ["this", "week"], ["next", "week"], ["this", "month"]] {
            if let span = when(at: 0, in: phrase, start: start, calendar: calendar)?.span, !found.contains(span) {
                found.append(span)
            }
        }
        return found
    }

    // MARK: - The lists

    /// How long a ticked job stays in sight: until the end of the day it
    /// was ticked, so a slip of the finger can be put right.
    static func isInSight(_ job: JobFacts, today: Date, calendar: Calendar = .current) -> Bool {
        guard let done = job.doneAt else { return true }
        return calendar.isDate(done, inSameDayAs: today)
    }

    /// Days from today until a job's first day. None for a job that has
    /// begun or is overdue. Nil for a job with no date.
    static func daysUntil(_ job: JobFacts, today: Date, calendar: Calendar = .current) -> Int? {
        guard let from = job.span.from ?? job.span.by else { return nil }
        return max(daysBetween(today, from, calendar), 0)
    }

    /// The jobs of your own that belong under "This week": those with a
    /// day that begins within the week, and any whose day has gone by
    /// and are still not done.
    static func thisWeek(_ jobs: [JobFacts], today: Date, calendar: Calendar = .current) -> [WeekJob] {
        jobs.compactMap { job in
            guard isInSight(job, today: today, calendar: calendar),
                  let days = daysUntil(job, today: today, calendar: calendar), days <= WeekJobs.window else { return nil }
            return WeekJob(id: listID(for: job.key), kind: .own, title: job.title,
                           detail: detail(for: job, today: today, calendar: calendar) ?? "",
                           subject: job.key, daysLeft: days)
        }
    }

    /// The jobs of your own that belong under "This month" and not under
    /// "This week": those with no date, and those for later this month.
    /// Jobs with no date come first, oldest first, then the dated ones
    /// in date order.
    static func laterThisMonth(_ jobs: [JobFacts], today: Date, calendar: Calendar = .current) -> [JobFacts] {
        let endOfMonth = monthEnd(of: calendar.startOfDay(for: today), calendar)
        let kept = jobs.filter { job in
            guard isInSight(job, today: today, calendar: calendar) else { return false }
            guard let days = daysUntil(job, today: today, calendar: calendar) else { return true }
            guard days > WeekJobs.window, let from = job.span.from ?? job.span.by else { return false }
            return from <= endOfMonth
        }
        return kept.sorted { first, second in
            let firstDays = daysUntil(first, today: today, calendar: calendar)
            let secondDays = daysUntil(second, today: today, calendar: calendar)
            if (firstDays == nil) != (secondDays == nil) { return firstDays == nil }
            return (firstDays ?? 0) < (secondDays ?? 0)
        }
    }

    /// The name a job of your own goes by in the Today lists. The "own-"
    /// at the front keeps it apart from the worked-out jobs' names.
    static func listID(for key: String) -> String { "own-\(key)" }
}
