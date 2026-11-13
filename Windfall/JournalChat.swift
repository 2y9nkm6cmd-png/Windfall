//
//  JournalChat.swift
//  Windfall
//
//  The thinking behind the journal's conversation, kept apart from the
//  screen (JournalChatView.swift) so that it can be tested without one.
//
//  Three jobs:
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
//  All three are fixed rules. None of them uses the AI model, so they
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
}
