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
//  - The title. A short heading made from the entry's own first words.
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
    /// ⚠️ CHECK: Claude's figure, chosen on 13 November 2026.
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

    // MARK: - The title

    /// Words that open a sentence without saying what it is about. They
    /// are dropped from the front of a title.
    private static let openers: [[String]] = [
        ["this", "morning"], ["this", "afternoon"], ["this", "evening"], ["last", "night"],
        ["first", "thing"], ["earlier", "today"], ["today"], ["yesterday"], ["earlier"], ["tonight"],
        ["i", "have"], ["we", "have"], ["i've"], ["we've"], ["i"], ["we"],
        ["just"], ["then"], ["also"], ["so"], ["and"], ["finally"]
    ]

    /// Small joining words a title should not end on.
    private static let trailers: Set<String> = ["and", "with", "the", "a", "an", "to", "of", "in", "on", "for", "at", "but", "then", "by", "from"]

    /// The most words a title may have.
    static let titleLength = 7

    /// A short heading made from an entry's own words.
    ///
    /// It takes the first sentence, drops openers such as "This morning
    /// I", stops at a comma if enough has been said by then, keeps at
    /// most seven words and does not end on a joining word.
    /// "This morning I mulched the raspberries with leaf mould and saw a
    /// wren." becomes "Mulched the raspberries with leaf mould".
    ///
    /// Nil when there are no words to make one from.
    static func title(for text: String) -> String? {
        // The first line that has anything on it.
        let firstLine = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        guard let firstLine else { return nil }

        // Its first sentence: up to a full stop, question mark or
        // exclamation mark that is followed by a space or the end. A
        // full stop inside a number, as in "2.5 kg", does not count.
        var sentence = firstLine
        var index = firstLine.startIndex
        while index < firstLine.endIndex {
            let next = firstLine.index(after: index)
            if ".!?".contains(firstLine[index]), next == firstLine.endIndex || firstLine[next] == " " {
                sentence = String(firstLine[..<index])
                break
            }
            index = next
        }

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
