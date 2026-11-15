//
//  JournalChat.swift
//  Windfall
//
//  The thinking behind the journal's conversation, kept apart from the
//  screen (JournalChatView.swift) so that it can be tested without one.
//
//  Four jobs:
//
//  - The weather stamp. Each thing written in the journal is stamped
//    with the conditions at the time. This turns the weather service's
//    figures into the journal's own short word for the weather.
//
//  - The title. A short heading made from the entry's own words. It
//    reads the whole entry to find the sentence that says most about
//    what the entry keeps coming back to, and is not just its opening.
//
//  - The time check. Written late, or with "this morning" in it, an
//    entry is probably about earlier in the day. This decides when to
//    ask, and which times to offer, before the entry is stamped.
//
//  - The photos' own day. Photos say when they were taken. If that was
//    not just now, this decides whether to ask which day the entry is
//    about. Added 14 November 2026.
//
//  A fifth job, added 14 November 2026: noticing when an entry tells
//  of something seen but not named ("an insect", "a strange weed"),
//  and the questions that help pin it down. See "Pinning down
//  something seen" at the end.
//
//  A sixth, added 14 November 2026: what becomes of an entry's heading
//  when the entry is changed later (JournalEntryEditor.swift). See
//  "The heading after a change", below the title.
//
//  All of them are fixed rules. None of them uses the AI model, so they
//  give the same answer every time and work on any device.
//

import Foundation

enum JournalChat {

    // MARK: - The weather stamp

    /// Rain falling this fast is called heavy, in millimetres an hour.
    /// This is the Met Office's own line: 4 mm an hour or more is
    /// "termed heavy" (its guide to the rainfall map for government
    /// users, read 13 November 2026). The journal does not try to tell
    /// showers from rain.
    static let heavyRainMM = 4.0

    /// The journal's word for some conditions. Rain comes first, then
    /// frost, then wind, and only then how much cloud there is, because
    /// that is the order in which they matter to a gardener.
    static func weatherWord(for conditions: CurrentConditions) -> Weather {
        if !conditions.isDry {
            return conditions.precipitationMM >= heavyRainMM ? .heavyRain : .rain
        }
        if conditions.temperatureC <= 0 { return .frost }
        if conditions.isWindy { return .windy }
        switch conditions.skyCondition {
        case .sunny: return .sunny
        case .partlyCloudy: return .cloudy
        case .cloudy: return .overcast
        }
    }

    /// The stamp in words: "9°C, overcast". Nil when nothing is known.
    static func stampWords(weather: Weather?, temperatureC: Double?) -> String? {
        let degrees = temperatureC.map { "\(Int($0.rounded()))°C" }
        let word = weather?.displayName.lowercased()
        switch (degrees, word) {
        case (let degrees?, let word?): return "\(degrees), \(word)"
        case (let degrees?, nil): return degrees
        case (nil, let word?): return word.prefix(1).uppercased() + word.dropFirst()
        case (nil, nil): return nil
        }
    }

    // MARK: - Reading words

    /// The sentences in a piece of writing. One ends at a new line, or
    /// at a full stop, question mark or exclamation mark that is followed
    /// by a space or the end. A full stop inside a number, as in
    /// "2.5 kg", does not end one.
    static func sentences(in text: String) -> [String] {
        var split: [String] = []
        for line in text.split(whereSeparator: \.isNewline) {
            var current = ""
            var index = line.startIndex
            while index < line.endIndex {
                let letter = line[index]
                let next = line.index(after: index)
                if ".!?".contains(letter), next == line.endIndex || line[next] == " " {
                    split.append(current)
                    current = ""
                } else {
                    current.append(letter)
                }
                index = next
            }
            split.append(current)
        }
        return split.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// A word cut down so that "Raspberries", "raspberry" and
    /// "raspberry's" all read the same: lower case, nothing but letters
    /// and figures at its ends, no "'s" and no plural ending.
    ///
    /// It is rough. "Leaves" becomes "leave", not "leaf". That does not
    /// matter, because both sides of every comparison are cut the same way.
    static func root(of word: String) -> String {
        var cut = word.lowercased().trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        for ending in ["'s", "’s"] where cut.hasSuffix(ending) {
            cut.removeLast(2)
        }
        if cut.count > 4, cut.hasSuffix("ies") {
            cut.removeLast(3)
            cut += "y"                                    // raspberries, raspberry
        } else if cut.count > 4, ["oes", "shes", "ches", "xes", "sses"].contains(where: { cut.hasSuffix($0) }) {
            cut.removeLast(2)                             // tomatoes, radishes, peaches
        } else if cut.count > 3, cut.hasSuffix("s"), !cut.hasSuffix("ss") {
            cut.removeLast()                              // carrots, peas
        }
        return cut
    }

    /// The roots of every word in some text, in order.
    static func roots(in text: String) -> [String] {
        text.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "—" || $0.isNewline })
            .map { root(of: String($0)) }
            .filter { !$0.isEmpty }
    }

    /// Words too common to say what an entry is about.
    private static let commonWords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "of", "to", "in", "on", "at", "by", "for", "with", "from", "into",
        "over", "under", "up", "down", "out", "off", "i", "we", "it", "they", "them", "you", "my", "our", "your",
        "their", "its", "this", "that", "these", "those", "is", "are", "was", "were", "be", "been", "am", "have",
        "has", "had", "do", "did", "done", "got", "get", "went", "go", "then", "so", "also", "just", "very",
        "quite", "really", "some", "all", "any", "more", "most", "much", "many", "few", "lot", "bit", "as",
        "than", "too", "not", "no", "there", "here", "when", "while", "after", "before", "today", "yesterday",
        "morning", "afternoon", "evening", "night", "day", "week", "time", "now", "still", "again", "back",
        "new", "old", "first", "last", "one", "two", "three", "look", "looking", "garden"
    ]

    // MARK: - The title

    /// Words that open a sentence without saying what it is about. They
    /// are dropped from the front of a title.
    private static let openers: [[String]] = [
        ["spent", "the", "morning"], ["spent", "the", "afternoon"], ["spent", "the", "evening"],
        ["spent", "the", "day"], ["spent", "all", "day"], ["managed", "to"],
        ["this", "morning"], ["this", "afternoon"], ["this", "evening"], ["last", "night"],
        ["first", "thing"], ["earlier", "today"], ["today"], ["yesterday"], ["earlier"], ["tonight"],
        ["i", "have"], ["we", "have"], ["i've"], ["we've"], ["i"], ["we"],
        ["just"], ["then"], ["also"], ["so"], ["and"], ["finally"]
    ]

    /// Small joining words a title should not end on.
    private static let trailers: Set<String> = ["and", "with", "the", "a", "an", "to", "of", "in", "on", "for", "at", "but", "then", "by", "from"]

    /// The most words a title may have.
    static let titleLength = 7

    /// A short heading for an entry, made from its own words.
    ///
    /// The whole entry is read first. Every word that says something
    /// (not "the", "today" and the like) is counted, and each sentence
    /// is scored by the words in it that the entry uses more than once.
    /// The sentence with the highest score is the one the entry keeps
    /// coming back to, so the title is made from that one. An entry that
    /// opens "Cold start today" and then spends three sentences on the
    /// raspberries is titled for the raspberries.
    ///
    /// - `known`: the roots of names from the garden, such as its plants
    ///   and beds. A sentence that uses one scores higher, since those
    ///   are what the journal is about.
    ///
    /// If nothing is repeated and no known name appears, there is
    /// nothing to choose between the sentences and the first is used.
    ///
    /// Nil when there are no words to make a title from.
    static func title(for text: String, known: Set<String> = []) -> String? {
        let all = sentences(in: text)
        guard let first = all.first else { return nil }

        // How often each telling word is used across the whole entry.
        let telling = all.map { sentence in
            Set(roots(in: sentence).filter { $0.count > 2 && !commonWords.contains($0) })
        }
        var uses: [String: Int] = [:]
        for group in telling {
            for word in group { uses[word, default: 0] += 1 }
        }

        // A sentence scores the number of sentences each of its repeated
        // words appears in, with a known name counting double and
        // counting even if it is used only once.
        var best = first
        var bestScore = 0
        for (sentence, group) in zip(all, telling) {
            var score = 0
            for word in group {
                let count = uses[word] ?? 0
                if known.contains(word) {
                    score += count * 2
                } else if count > 1 {
                    score += count
                }
            }
            // "Greater than", so that of two equal sentences the earlier wins.
            if score > bestScore {
                best = sentence
                bestScore = score
            }
        }
        return heading(from: best)
    }

    // MARK: - The heading after a change

    /// An entry's two headings, as they should stand once the entry has
    /// been changed.
    ///
    /// An entry can have a heading of your own (`own`), one written for
    /// you from its words (`written`), both or neither. Where both are
    /// there, your own is the one shown.
    struct Heading: Equatable {
        /// The heading you typed. Nil if you have not typed one.
        var own: String?
        /// The heading made from the entry's words. Nil if there is none.
        var written: String?
        /// True if `written` has just been made afresh, so that the
        /// record's note of when it was written should move on too.
        var writtenIsNew = false
    }

    /// Works out an entry's headings after it has been changed in the
    /// editor.
    ///
    /// The editor has one box for the heading. It opens holding
    /// whichever heading the entry shows. So there are three things you
    /// can have done with the box:
    ///
    /// - Left it alone. A heading of your own stays. One that was
    ///   written for you is written again if the entry's words have
    ///   changed, since it may no longer say what the entry is about.
    /// - Emptied it. Any heading of your own goes, and one is written
    ///   from the words.
    /// - Typed something else. That becomes your own heading.
    ///
    /// - `own`, `written`: the entry's headings before the change.
    /// - `typed`: what is in the heading box now.
    /// - `oldWords`, `newWords`: the entry's words before and after.
    /// - `known`: the roots of names from the garden, as for `title`.
    static func heading(own: String?, written: String?, typed: String,
                        oldWords: String, newWords: String, known: Set<String> = []) -> Heading {
        func tidy(_ text: String?) -> String {
            (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let before = Heading(own: tidy(own).isEmpty ? nil : own, written: written)
        // What the box held when the editor opened.
        let shown = tidy(own).isEmpty ? tidy(written) : tidy(own)
        let now = tidy(typed)
        let words = tidy(newWords)

        /// A heading made from the new words. Left off where it would
        /// only repeat the entry, as when the entry is first written.
        func fresh() -> Heading {
            let made = title(for: words, known: known)
            return Heading(own: nil, written: made == words ? nil : made, writtenIsNew: true)
        }

        if now != shown {
            return now.isEmpty ? fresh() : Heading(own: now, written: written)
        }
        // The box was left alone.
        if before.own != nil || words == tidy(oldWords) { return before }
        return fresh()
    }

    /// Cuts one sentence down to a heading: drops openers such as "This
    /// morning I", stops at a comma if enough has been said by then,
    /// keeps at most seven words and does not end on a joining word.
    /// "This morning I mulched the raspberries with leaf mould and saw a
    /// wren" becomes "Mulched the raspberries with leaf mould".
    static func heading(from sentence: String) -> String? {
        var pieces = sentence.split(separator: " ").map(String.init)
        guard !pieces.isEmpty else { return nil }
        let whole = pieces

        // Drop openers from the front, one after another, for as long as
        // at least two words would be left.
        var droppedOne = true
        while droppedOne {
            droppedOne = false
            for opener in openers where pieces.count >= opener.count + 2 {
                let front = pieces.prefix(opener.count).map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
                if front == opener {
                    pieces.removeFirst(opener.count)
                    droppedOne = true
                    break
                }
            }
        }

        // Stop at the first comma that comes after at least three words.
        if let comma = pieces.indices.first(where: { $0 >= 2 && pieces[$0].hasSuffix(",") }) {
            pieces = Array(pieces.prefix(comma + 1))
        }

        pieces = Array(pieces.prefix(titleLength))
        while pieces.count > 1, let last = pieces.last,
              trailers.contains(last.lowercased().trimmingCharacters(in: .punctuationCharacters)) {
            pieces.removeLast()
        }
        if pieces.isEmpty { pieces = Array(whole.prefix(titleLength)) }

        let joined = pieces.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: ",;: "))
        guard !joined.isEmpty else { return nil }
        return joined.prefix(1).uppercased() + joined.dropFirst()
    }

    // MARK: - The time check

    /// A time an entry might be about.
    enum Moment: String, CaseIterable, Identifiable {
        case morning, afternoon, yesterday, now

        var id: String { rawValue }
    }

    /// A question to put before an entry is stamped, with the times to
    /// offer. "Now" is always the last of them.
    struct TimeCheck: Equatable {
        let question: String
        let moments: [Moment]
    }

    /// What a moment is called on its button.
    static func name(of moment: Moment) -> String {
        switch moment {
        case .morning: return "This morning"
        case .afternoon: return "This afternoon"
        case .yesterday: return "Yesterday"
        case .now: return "Now"
        }
    }

    /// The time a moment stands for: ten in the morning, three in the
    /// afternoon, three yesterday afternoon, or this instant.
    static func date(for moment: Moment, now: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        switch moment {
        case .morning: return calendar.date(byAdding: .hour, value: 10, to: today) ?? now
        case .afternoon: return calendar.date(byAdding: .hour, value: 15, to: today) ?? now
        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            return calendar.date(byAdding: .hour, value: 15, to: yesterday) ?? now
        case .now: return now
        }
    }

    /// Decides whether to ask when an entry was about.
    ///
    /// - `isDark`: whether the sun is down where the garden is. Nil if
    ///   the garden's place is not known, in which case eight in the
    ///   evening to five in the morning counts as dark.
    ///
    /// It asks when the words name an earlier time ("this morning" said
    /// after midday, "this afternoon" said in the evening, "yesterday",
    /// "earlier"), or when it is dark, since few things are done in a
    /// garden in the dark. Nil means there is nothing to ask.
    static func timeCheck(for text: String, at now: Date, isDark: Bool?, calendar: Calendar = .current) -> TimeCheck? {
        let words = text.lowercased()
        guard words.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 else { return nil }

        let hour = calendar.component(.hour, from: now)
        func says(_ phrases: [String]) -> Bool { phrases.contains { words.contains($0) } }

        if says(["yesterday", "last night"]) {
            return TimeCheck(question: "You wrote about yesterday. Stamp it with yesterday's weather?",
                             moments: [.yesterday, .now])
        }
        if hour >= 12, says(["this morning", "first thing", "before work", "before school", "at dawn", "at breakfast"]) {
            return TimeCheck(question: "You wrote about this morning. Stamp it with the morning's weather?",
                             moments: [.morning, .now])
        }
        if hour >= 17, says(["this afternoon", "after lunch", "lunchtime", "after school", "after work"]) {
            return TimeCheck(question: "You wrote about this afternoon. Stamp it with the afternoon's weather?",
                             moments: [.afternoon, .now])
        }

        // The earlier parts of today that are far enough behind to be
        // worth offering.
        var earlier: [Moment] = []
        if hour >= 12 { earlier.append(.morning) }
        if hour >= 17 { earlier.append(.afternoon) }

        if says(["earlier"]), !earlier.isEmpty {
            return TimeCheck(question: "You wrote about earlier. When was it?", moments: earlier + [.now])
        }

        // Words that put it at the time of writing. "Tonight" said after
        // dark is about now, so there is nothing to ask. (Added 14
        // November 2026: "I noticed an insect in my garden tonight" was
        // asked whether it was about the morning.)
        if says(["tonight", "this evening", "just now", "right now", "at the moment"]) { return nil }

        if isDark ?? (hour >= 20 || hour < 5) {
            let minute = calendar.component(.minute, from: now)
            let clock = String(format: "%d:%02d", hour, minute)
            if hour < 5 {
                return TimeCheck(question: "It is \(clock). Was this about yesterday?", moments: [.yesterday, .now])
            }
            if !earlier.isEmpty {
                return TimeCheck(question: "It is \(clock) and dark out. Was this about earlier today?",
                                 moments: earlier + [.now])
            }
        }
        return nil
    }
}

// MARK: - The photos' own day

extension JournalChat {

    /// A time the photos point to, with the words for its button:
    /// "Wednesday 11 November at 15:02".
    struct PhotoMoment: Equatable, Identifiable {
        let date: Date
        let name: String

        var id: Date { date }
    }

    /// A question to put before an entry with photos is stamped, with
    /// the times to offer. The card adds "Now" after them.
    struct PhotoCheck: Equatable {
        let question: String
        let moments: [PhotoMoment]
    }

    /// Decides whether to ask when an entry was about, going by when its
    /// photos were taken, and which times to offer.
    ///
    /// - `taken`: the time each photo says it was taken. Photos that do
    ///   not say are simply left out of the list.
    ///
    /// The rule:
    /// - A photo dated in the future is ignored. Its camera's clock is
    ///   wrong.
    /// - Photos taken today within the last hour ask nothing. "Now" is
    ///   near enough.
    /// - Otherwise each day with photos is offered, newest first, at
    ///   the time of that day's last photo. No more than four days.
    static func photoCheck(taken: [Date], at now: Date, calendar: Calendar = .current) -> PhotoCheck? {
        let past = taken.filter { $0 <= now.addingTimeInterval(300) }
        guard !past.isEmpty else { return nil }

        // The last photo of each day stands for that day. The key is
        // the day's midnight, the value the latest time seen that day.
        var lastOfDay: [Date: Date] = [:]
        for date in past {
            let day = calendar.startOfDay(for: date)
            lastOfDay[day] = max(lastOfDay[day] ?? date, date)
        }

        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        // Days worth asking about, newest first.
        let days = lastOfDay.keys.sorted(by: >).filter { day in
            guard day == today, let last = lastOfDay[day] else { return true }
            return now.timeIntervalSince(last) >= 3600
        }
        guard let newest = days.first, let newestTime = lastOfDay[newest] else { return nil }

        func clock(_ date: Date) -> String {
            String(format: "%d:%02d", calendar.component(.hour, from: date), calendar.component(.minute, from: date))
        }
        /// "Wednesday 11 November", or "11 November 2025" in another year.
        func dayWords(_ date: Date) -> String {
            let month = calendar.monthSymbols[calendar.component(.month, from: date) - 1]
            let number = calendar.component(.day, from: date)
            let year = calendar.component(.year, from: date)
            if year != calendar.component(.year, from: now) { return "\(number) \(month) \(year)" }
            let weekday = calendar.weekdaySymbols[calendar.component(.weekday, from: date) - 1]
            return "\(weekday) \(number) \(month)"
        }
        func name(_ date: Date) -> String {
            let day = calendar.startOfDay(for: date)
            if day == today { return "Today at \(clock(date))" }
            if day == yesterday { return "Yesterday at \(clock(date))" }
            return "\(dayWords(date)) at \(clock(date))"
        }

        let moments = days.prefix(4).compactMap { day in
            lastOfDay[day].map { PhotoMoment(date: $0, name: name($0)) }
        }

        // "The photo was", "The photos were", or "Some of the photos
        // were" when others among them were taken just now.
        let subject: String
        if lastOfDay.count > days.count {
            subject = "Some of the photos were"
        } else {
            subject = past.count == 1 ? "The photo was" : "The photos were"
        }

        let question: String
        if days.count > 1 {
            question = "The photos were taken on different days. Which day is this about?"
        } else if newest == today {
            question = "\(subject) taken at \(clock(newestTime)) today. Is this about then?"
        } else if newest == yesterday {
            question = "\(subject) taken yesterday at \(clock(newestTime)). Is this about then?"
        } else {
            question = "\(subject) taken on \(dayWords(newestTime)). Is this about that day?"
        }
        return PhotoCheck(question: question, moments: moments)
    }
}

// MARK: - Telling or asking

extension JournalChat {

    /// Words that begin a question or a request to Eira.
    private static let askingStarts: Set<String> = [
        "what", "what's", "whats", "when", "when's", "where", "where's", "which", "who", "who's",
        "whose", "why", "how", "how's", "is", "are", "am", "was", "were", "do", "does", "did",
        "can", "could", "should", "would", "will", "shall", "may", "might", "have", "has",
        "show", "open", "find", "search", "list", "tell", "give", "add", "record", "log", "make",
        "create", "set", "remind", "help", "explain", "describe", "compare", "identify", "please",
        "eira", "hey", "hi", "hello"]

    /// Words that turn a sentence into a question or a wish wherever
    /// they stand: "I wonder how deep to plant garlic".
    private static let askingWords: Set<String> = [
        "how", "what", "why", "whether", "should", "need", "want", "wonder", "can", "could", "please"]

    /// "I", "we" and the like: someone giving an account of themselves.
    private static let ownWords: Set<String> = [
        "i", "i've", "i'd", "we", "we've", "we'd", "my", "our"]

    /// Words that place it in a day.
    private static let dayWords: Set<String> = [
        "today", "yesterday", "tonight", "morning", "afternoon", "evening", "earlier", "lunchtime"]

    /// Things done in a garden, said as done. Any one of these is enough
    /// by itself: "Planted the garlic in bed 2".
    private static let gardenDone: Set<String> = [
        "sowed", "sown", "planted", "harvested", "picked", "pruned", "watered", "weeded", "mulched",
        "dug", "saw", "spotted", "noticed", "transplanted", "potted", "thinned", "netted", "staked",
        "mowed", "mown", "composted", "hoed", "raked", "deadheaded", "chitted", "lifted"]

    /// Other ways of saying something was done. These count only beside
    /// "I", "we" or a day, because they are common in questions too.
    private static let plainDone: Set<String> = [
        "found", "pulled", "cut", "fed", "tied", "went", "did", "made", "put", "took", "got",
        "built", "bought", "heard", "spent", "left", "gave", "brought", "kept", "ate", "began"]

    /// True if what was typed into Eira's bar reads as something for the
    /// journal ("Today I planted beans") and not as a question or a
    /// request ("when do I plant beans").
    ///
    /// It is cautious on purpose. When in doubt it says no, and the words
    /// go to Eira as they always did.
    ///
    /// The rule: no question mark, no asking word, at least three words,
    /// and either a garden job said as done, or "I", "we" or a day
    /// together with something done (a word from the lists, or one
    /// ending in "ed").
    static func readsAsTelling(_ text: String) -> Bool {
        guard !text.contains("?") else { return false }
        let said = text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .split(whereSeparator: { !($0.isLetter || $0 == "'") })
            .map(String.init)
        guard said.count >= 3, let opening = said.first, !askingStarts.contains(opening) else { return false }
        guard !said.contains(where: askingWords.contains) else { return false }

        if said.contains(where: gardenDone.contains) { return true }
        let isOwn = said.contains { ownWords.contains($0) || dayWords.contains($0) }
        let isDone = said.contains { plainDone.contains($0) || ($0.count >= 5 && $0.hasSuffix("ed")) }
        return isOwn && isDone
    }

    /// True if what was typed reads as a question or a request to Eira.
    ///
    /// This is the test for the Journal page, where Eira's bar says
    /// "Tell Eira what happened in the garden". There the doubt runs the
    /// other way: whatever is typed is taken as something for the
    /// journal unless it plainly asks for something. "Frosty and still"
    /// is an entry there, though it names nothing that was done.
    ///
    /// The rule: a question mark, an opening word that asks ("when",
    /// "show", "find"), an asking word anywhere ("wonder", "should"),
    /// or a single word alone, which is something to look up.
    static func readsAsAsking(_ text: String) -> Bool {
        if text.contains("?") { return true }
        let said = text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .split(whereSeparator: { !($0.isLetter || $0 == "'") })
            .map(String.init)
        guard said.count >= 2, let opening = said.first else { return true }
        return askingStarts.contains(opening) || said.contains(where: askingWords.contains)
    }

    /// True if the words ask what something is: "What is this?",
    /// "What tree is that?", "Can you identify it?".
    ///
    /// This is the test the journal's conversation puts to words sent
    /// with a photo. Such words are a question about the photo, not an
    /// account of the day, so nothing is written in the journal and
    /// nobody is asked when it happened: Eira looks at the photo and
    /// says what it most resembles (JournalNaming.swift). (William, 15
    /// November 2026: "Weird that I can't say what is this without
    /// selecting the time it was sent?")
    ///
    /// The rule, on the words in small letters with "what's" read as
    /// "what is":
    /// - no more than twelve words. A longer piece is an account of the
    ///   day that happens to wonder about something, and belongs in the
    ///   journal;
    /// - "identify", "identification" or "ID" anywhere;
    /// - or "name" followed by a pointing word: "name this";
    /// - or "what" or "which", and after it a pointing word next to
    ///   "is" or "are", either way round: "what IS THIS", "what bird
    ///   IS THAT", "do you know what THESE ARE". "What a" is left out,
    ///   because "What a beauty this is" is not a question.
    ///
    /// It asks for a name only. "What should I do with this?" and "Is
    /// this ready to pick?" are questions too, but the image model can
    /// only match a photo to a name, so they are not caught here.
    static func asksForAName(_ text: String) -> Bool {
        // The words, in small letters, with punctuation dropped.
        // `flatMap` lets one word become two: "what's" is "what is".
        let said = text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .split(whereSeparator: { !($0.isLetter || $0 == "'") })
            .map(String.init)
            .flatMap { word -> [String] in
                switch word {
                case "what's", "whats": return ["what", "is"]
                case "that's", "thats": return ["that", "is"]
                case "it's": return ["it", "is"]
                default: return [word]
                }
            }
        guard !said.isEmpty, said.count <= 12 else { return false }

        if said.contains(where: { $0 == "id" || $0.hasPrefix("identif") }) { return true }

        // `zip(said, said.dropFirst())` walks the words two at a time:
        // each word with the one after it.
        if zip(said, said.dropFirst()).contains(where: { $0 == "name" && pointingWords.contains($1) }) { return true }

        // The first "what" or "which" that is not "what a" or "what an".
        guard let asked = said.indices.first(where: { place in
            guard said[place] == "what" || said[place] == "which" else { return false }
            let next = place + 1 < said.count ? said[place + 1] : ""
            return next != "a" && next != "an"
        }) else { return false }
        let after = said[(asked + 1)...]
        return zip(after, after.dropFirst()).contains { first, second in
            (beingWords.contains(first) && pointingWords.contains(second))
                || (pointingWords.contains(first) && beingWords.contains(second))
        }
    }

    /// Words that point at the thing in the photo.
    private static let pointingWords: Set<String> = ["this", "that", "it", "these", "those", "they"]
    private static let beingWords: Set<String> = ["is", "are", "was", "were"]
}

// MARK: - Pinning down something seen

extension JournalChat {

    /// The broad sort of thing an entry saw. It decides which questions
    /// are worth asking: wings matter for an insect, not for a weed.
    enum FindKind: String, Equatable {
        case smallCreature, bird, growing
    }

    /// Something seen but not named: "an insect", "a strange weed".
    struct Find: Equatable {
        /// The word as cut down by `root(of:)`: "insect", "moth".
        let word: String
        let kind: FindKind
        /// The group a sighting of it goes in, where the word says.
        /// "Creature" says nothing, so it is nil.
        let group: TaxonGroup?
        /// True for a caterpillar, grub, larva or maggot.
        let isYoung: Bool
    }

    /// Words for something seen without a name, by the root
    /// `root(of:)` makes of them. "Bee" and "moth" are here because a
    /// bee or a moth could be one of hundreds of kinds; "robin" is not,
    /// because a robin is already named.
    private static let unnamedWords: [String: (FindKind, TaxonGroup?)] = [
        "insect": (.smallCreature, .insect), "bug": (.smallCreature, .insect),
        "beetle": (.smallCreature, .insect), "moth": (.smallCreature, .insect),
        "butterfly": (.smallCreature, .insect), "bee": (.smallCreature, .insect),
        "wasp": (.smallCreature, .insect), "fly": (.smallCreature, .insect),
        "hoverfly": (.smallCreature, .insect), "caterpillar": (.smallCreature, .insect),
        "grub": (.smallCreature, .insect), "larva": (.smallCreature, .insect),
        "larvae": (.smallCreature, .insect), "maggot": (.smallCreature, .insect),
        "spider": (.smallCreature, .arachnid),
        "slug": (.smallCreature, .mollusc), "snail": (.smallCreature, .mollusc),
        "worm": (.smallCreature, .annelid),
        "centipede": (.smallCreature, .otherInvertebrate), "millipede": (.smallCreature, .otherInvertebrate),
        "creature": (.smallCreature, nil), "beastie": (.smallCreature, nil),
        "bird": (.bird, .bird),
        "weed": (.growing, .plant), "wildflower": (.growing, .plant), "plant": (.growing, .plant),
        "mushroom": (.growing, .fungus), "toadstool": (.growing, .fungus),
        "fungus": (.growing, .fungus), "fungi": (.growing, .fungus)
    ]

    /// The young stages, written on a sighting as its life stage.
    private static let youngWords: Set<String> = ["caterpillar", "grub", "larva", "larvae", "maggot"]

    /// Words that say it was seen. One must be in the entry, so that
    /// "planted some plants" is not taken for a sighting.
    private static let seeingWords: Set<String> = [
        "saw", "seen", "see", "spotted", "noticed", "found", "watched", "heard", "caught",
        "disturbed", "there", "there's", "came", "visiting", "visited"]

    /// Words that describe without naming: "a small brown beetle". Any
    /// number of these may stand before the word.
    private static let describingWords: Set<String> = [
        "odd", "strange", "weird", "funny", "unusual", "unknown", "mystery", "new", "different",
        "little", "small", "tiny", "big", "large", "huge", "fat", "long", "thin",
        "black", "brown", "grey", "gray", "white", "cream", "yellow", "orange", "red", "pink",
        "purple", "blue", "green", "dark", "pale", "bright", "shiny", "metallic", "hairy",
        "furry", "fluffy", "spotty", "stripy", "striped", "pretty", "lovely", "beautiful", "flying"]

    /// Words that can stand before those: "an", "some", "lots of", or
    /// the seeing word itself, as in "noticed insects". Anything else
    /// there is taken as part of a name: "red admiral butterfly",
    /// "cabbage white butterflies", "carrot plants".
    private static let leadingWords: Set<String> = [
        "a", "an", "some", "this", "that", "these", "those", "few", "several", "lot", "lots",
        "of", "loads", "two", "three", "four", "many", "another", "more", "couple", "was", "were",
        "is", "are"]

    /// The first thing an entry saw without naming, if there is one.
    ///
    /// The rule: a word is seen ("saw", "noticed", "there was"), and a
    /// word from the list above stands with nothing before it but
    /// describing words, and before those an "a", "some" or the like.
    /// So "I noticed an insect in my garden tonight" is a find, and
    /// "Saw a red admiral butterfly" and "Saw a robin" are not.
    static func unnamedFind(in text: String) -> Find? {
        // The words as written, for the small words around the find, and
        // cut down by `root(of:)`, so that "moths" and "moth" match.
        // ("This" is kept as written: cut down it would lose its "s".)
        let said = text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .split(whereSeparator: { !($0.isLetter || $0 == "'" || $0 == "-") })
            .map(String.init)
        let roots = said.map { root(of: $0) }
        guard said.contains(where: seeingWords.contains) else { return nil }

        for (index, word) in roots.enumerated() {
            guard let (kind, group) = unnamedWords[word] else { continue }
            // Step back over describing words.
            var before = index - 1
            while before >= 0, describingWords.contains(said[before]) { before -= 1 }
            if before < 0 || leadingWords.contains(said[before]) || seeingWords.contains(said[before]) {
                return Find(word: word, kind: kind, group: group, isYoung: youngWords.contains(word))
            }
        }
        return nil
    }

    // MARK: Asking without nagging

    /// Skips in a row after which Eira asks less often.
    static let skipsBeforeAskingLess = 3

    /// Whether to offer to pin something down, given how many times in
    /// a row the offer has been turned down. Under three, always. After
    /// that, one time in three, so the offer never goes for good.
    static func shouldOfferPinDown(skipsInARow: Int) -> Bool {
        skipsInARow < skipsBeforeAskingLess || (skipsInARow - skipsBeforeAskingLess) % 3 == 2
    }

    // MARK: The questions

    /// One question about what was seen, with its answers as buttons.
    struct DescribeQuestion: Equatable, Identifiable {
        let id: String
        let title: String
        let options: [String]
        /// True when more than one answer can be chosen, as for colours.
        let allowsMany: Bool
    }

    /// The questions worth asking about a find, given the answers so
    /// far. Each matches something field guides identify by.
    ///
    /// Sizes are in centimetres. For a small creature it is body
    /// length, for a bird beak to tail, as in bird books, and for
    /// something growing its height.
    static func describeQuestions(for find: Find, answers: [String: [String]]) -> [DescribeQuestion] {
        var asked: [DescribeQuestion] = []
        switch find.kind {
        case .smallCreature:
            asked.append(DescribeQuestion(id: "size", title: "Size, head to tail",
                                          options: ["Under 0.5 cm", "0.5 to 1 cm", "1 to 2 cm", "2 to 4 cm", "Over 4 cm"],
                                          allowsMany: false))
        case .bird:
            asked.append(DescribeQuestion(id: "size", title: "Size, beak to tail",
                                          options: ["Under 12 cm", "12 to 20 cm", "20 to 35 cm", "Over 35 cm"],
                                          allowsMany: false))
        case .growing:
            asked.append(DescribeQuestion(id: "size", title: "Height",
                                          options: ["Under 5 cm", "5 to 20 cm", "20 to 50 cm", "Over 50 cm"],
                                          allowsMany: false))
        }

        var colours = ["Black", "Brown", "Grey", "White", "Cream", "Yellow", "Orange", "Red", "Pink", "Purple", "Blue", "Green"]
        if find.kind == .smallCreature { colours.append("Metallic") }
        asked.append(DescribeQuestion(id: "colours", title: "Main colours", options: colours, allowsMany: true))

        // Wings only for an insect that is not a caterpillar or grub.
        if find.group == .insect, !find.isYoung {
            asked.append(DescribeQuestion(id: "wings", title: "Wings",
                                          options: ["No wings", "Two wings", "Four wings", "Hard wing cases", "Couldn't see"],
                                          allowsMany: false))
            let wings = answers["wings"]?.first
            if wings == "Two wings" || wings == "Four wings" {
                asked.append(DescribeQuestion(id: "held", title: "Wings held at rest",
                                              options: ["Spread flat", "Folded like a roof", "Closed upright", "Folded along the back"],
                                              allowsMany: false))
            }
        }

        switch find.kind {
        case .smallCreature:
            asked.append(DescribeQuestion(id: "doing", title: "What it was doing",
                                          options: ["Resting", "Flying to a light", "Feeding on a flower", "Eating leaves", "Crawling", "Flying about"],
                                          allowsMany: false))
            asked.append(DescribeQuestion(id: "where", title: "Where it was",
                                          options: ["On a plant", "On a wall or fence", "On the ground or lawn", "On a window or door", "In the air"],
                                          allowsMany: false))
        case .bird:
            asked.append(DescribeQuestion(id: "doing", title: "What it was doing",
                                          options: ["Feeding on the ground", "Feeding in a tree or shrub", "At a feeder", "Singing", "Bathing or drinking", "Flying over"],
                                          allowsMany: false))
        case .growing:
            if find.group == .plant {
                asked.append(DescribeQuestion(id: "doing", title: "How it was",
                                              options: ["In flower", "Leaves only", "Going to seed"],
                                              allowsMany: false))
            }
            asked.append(DescribeQuestion(id: "where", title: "Where it was",
                                          options: ["In a bed", "In the lawn", "In a path or paving", "On wood or a stump", "Under a hedge or tree"],
                                          allowsMany: false))
        }
        return asked
    }

    /// The answers as a line for the sighting's notes, in the order the
    /// questions were asked. Answers to questions no longer asked (wings
    /// held, once "No wings" is chosen) are left out. Nil when nothing
    /// was answered.
    ///
    /// "Described in the journal: 1 to 2 cm; brown and orange; four
    /// wings, folded like a roof; flying to a light; on a window or door."
    static func description(of find: Find, answers: [String: [String]]) -> String? {
        var parts: [String] = []
        for question in describeQuestions(for: find, answers: answers) {
            guard let chosen = answers[question.id], !chosen.isEmpty else { continue }
            let said = listed(chosen.map { $0.lowercased() })
            if question.id == "held", !parts.isEmpty {
                // "four wings, folded like a roof" reads as one thing.
                parts[parts.count - 1] += ", " + said
            } else {
                parts.append(said)
            }
        }
        guard !parts.isEmpty else { return nil }
        return "Described in the journal: " + parts.joined(separator: "; ") + "."
    }

    /// "brown", "brown and orange", "black, brown and orange". No comma
    /// before the "and".
    static func listed(_ words: [String]) -> String {
        switch words.count {
        case 0: return ""
        case 1: return words[0]
        default: return words.dropLast().joined(separator: ", ") + " and " + words[words.count - 1]
        }
    }
}
