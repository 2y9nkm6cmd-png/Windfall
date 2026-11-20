//
//  EiraOpenPage.swift
//  Windfall
//
//  "Show me bed 3": Eira opens a page for you (piece 4 of project doc
//  119, built 20 November 2026).
//
//  This file is the rule that reads the words. It is plain: it takes
//  the sentence typed in Eira's bar and a list of names, and says what
//  to open, or that it is not a request to open anything. No model is
//  asked, so it works the same on every device, the 8GB iPhone
//  included, and gives the same answer every time.
//
//  The opening itself (changing place, putting the page on top) is in
//  EiraOpenPageRoute.swift, because it needs the screens.
//
//  How it reads a sentence:
//    1. It must begin with a word for opening: "show me", "open", "go
//       to", "take me to", "bring up", "find me", with "please", "can
//       you", "could you" or "Eira," allowed in front.
//    2. What follows is the thing to open. "the", "my" and "our" at
//       its start, and "page", "screen" and "please" at its end, are
//       left off.
//    3. That must be, exactly, the name of a place in the app (Today,
//       the journal, the plant library), or of a bed, plant, garden or
//       species in the records. "bed", "plant", "garden" and "species"
//       may stand in front of a name: "the plant Borage".
//    4. If nothing matches, it is not a request to open anything, and
//       the words go on to Eira as before. So "show me how to prune an
//       apple" is answered by her, not opened.
//
//  It is deliberately strict. A near miss goes to Eira, who can answer
//  in words. Opening the wrong page would be worse than not opening one.
//

import Foundation

/// The places the rule knows by name. Their raw values are the same as
/// `AppSection`'s in MainTabView.swift, so the two can be matched up.
enum EiraOpenPlace: String, CaseIterable {
    case today, gardens, year, plants, wildlife, identify, journal, more

    /// The words that name each place, already in the rule's plain form
    /// (small letters, no punctuation). "garden" alone is not here: it
    /// is too likely to be the start of a garden's own name.
    var words: [String] {
        switch self {
        case .today: return ["today", "today screen", "home", "home screen"]
        case .gardens: return ["gardens", "gardens screen", "beds", "my beds", "garden plans"]
        case .year: return ["year", "the year", "year calendar", "calendar", "sowing calendar"]
        case .plants: return ["plants", "plant library", "the plant library", "library", "plant list"]
        case .wildlife: return ["wildlife", "sightings", "surveys"]
        case .identify: return ["identify", "identification", "fungus keys"]
        case .journal: return ["journal", "diary", "garden journal"]
        case .more: return ["settings", "the settings"]
        }
    }

    /// How the place is named in the line Eira's bar shows.
    var spoken: String {
        switch self {
        case .today: return "Today"
        case .gardens: return "Gardens"
        case .year: return "the Year"
        case .plants: return "the plant library"
        case .wildlife: return "Wildlife"
        case .identify: return "Identify"
        case .journal: return "the journal"
        case .more: return "Settings"
        }
    }
}

/// The kinds of record the rule can open.
enum EiraOpenKind: String {
    case bed, plant, garden, species

    /// The word that may stand in front of a name: "bed", "plant".
    var word: String { rawValue }
}

/// One record that could be opened, as the rule sees it: its kind, a
/// number that says which record it is in the caller's own list, and
/// every name it may be called by.
struct EiraOpenCandidate: Equatable {
    var kind: EiraOpenKind
    var index: Int
    var names: [String]
}

/// What the rule found.
enum EiraOpenResult: Equatable {
    /// Open this place.
    case place(EiraOpenPlace)
    /// Open this one record.
    case record(EiraOpenKind, Int)
    /// More than one record has this name, all of one kind: "show me
    /// Apple" when there are three apples. The caller opens the list
    /// they live in.
    case several(EiraOpenKind, [Int])
}

enum EiraOpenRule {

    /// The words that start a request to open something, in plain form.
    /// Longest first, so "show me" is tried before "show".
    static let openingWords: [String] = [
        "take me to the", "take me to", "navigate to", "bring up", "pull up", "jump to",
        "show me", "find me", "open up", "go to", "show", "open",
    ].sorted { $0.count > $1.count }

    /// Polite words that may come before the opening words.
    static let politeStarts = ["eira", "please", "can you", "could you", "would you", "will you"]

    /// Small words left off the front of the thing named.
    static let leadingFiller = ["the", "my", "our", "a"]

    /// Words left off the end.
    static let trailingFiller = ["page", "screen", "please", "for me", "now"]

    /// A sentence in the rule's plain form: small letters, "&" as
    /// "and", every other mark (commas, question marks, dashes,
    /// brackets) a space, and single spaces between words.
    static func plain(_ text: String) -> String {
        let lowered = text.lowercased().replacingOccurrences(of: "&", with: " and ")
        // Straight and curly apostrophes are dropped, so "William's"
        // and "Williams" are the same.
        let noApostrophes = lowered.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\u{2019}", with: "")
        let spaced = noApostrophes.map { $0.isLetter || $0.isNumber ? String($0) : " " }.joined()
        return spaced.split(separator: " ").joined(separator: " ")
    }

    /// The thing a sentence asks to have opened, in plain form, or nil
    /// when it does not begin with words for opening. "Could you show
    /// me the bed called Bed 3, please?" gives "bed called bed 3".
    static func asked(in text: String) -> String? {
        var rest = plain(text)
        // Polite words first, any number of them, in any order.
        var changed = true
        while changed {
            changed = false
            for word in politeStarts where rest.hasPrefix(word + " ") {
                rest = String(rest.dropFirst(word.count + 1))
                changed = true
            }
        }
        guard let opening = openingWords.first(where: { rest.hasPrefix($0 + " ") }) else { return nil }
        rest = String(rest.dropFirst(opening.count + 1))
        changed = true
        while changed {
            changed = false
            for word in trailingFiller where rest.hasSuffix(" " + word) {
                rest = String(rest.dropLast(word.count + 1))
                changed = true
            }
            for word in leadingFiller where rest.hasPrefix(word + " ") {
                rest = String(rest.dropFirst(word.count + 1))
                changed = true
            }
        }
        return rest.isEmpty ? nil : rest
    }

    /// Reads one sentence. Nil means it is not a request to open
    /// anything this rule knows, and the words should go on as before.
    static func read(_ text: String, candidates: [EiraOpenCandidate]) -> EiraOpenResult? {
        guard let wanted = asked(in: text) else { return nil }

        // A place, by any of its names.
        if let place = EiraOpenPlace.allCases.first(where: { $0.words.contains(wanted) }) {
            return .place(place)
        }

        // A record whose name is exactly what was asked, with or without
        // its kind's word in front ("bed 3", "plant borage", "the bed
        // called bed 3").
        let matches = candidates.filter { candidate in
            let names = candidate.names.map(plain).filter { !$0.isEmpty }
            let word = candidate.kind.word
            return names.contains { name in
                wanted == name || wanted == "\(word) \(name)" || wanted == "\(word) called \(name)"
                    || wanted == "\(word) named \(name)"
            }
        }
        guard let first = matches.first else { return nil }
        if matches.count == 1 { return .record(first.kind, first.index) }
        // Several, all of one kind: open the list. Of different kinds
        // (a bed and a plant both called "Rhubarb"): not sure which, so
        // it goes to Eira.
        guard matches.allSatisfy({ $0.kind == first.kind }) else { return nil }
        return .several(first.kind, matches.map(\.index))
    }

    /// The names a plant may be called by: "Apple", "Apple Spartan",
    /// "Spartan Apple", "Apple (Spartan)". Plain forms are made later.
    static func plantNames(common: String, variety: String?) -> [String] {
        guard let variety, !variety.trimmingCharacters(in: .whitespaces).isEmpty else { return [common] }
        return [common, "\(common) \(variety)", "\(variety) \(common)", "\(common) (\(variety))"]
    }
}

extension EiraOpenCandidate {
    /// A plant, by its common name and variety. See `plantNames`.
    static func forPlant(index: Int, common: String, variety: String?) -> EiraOpenCandidate {
        let called = EiraOpenRule.plantNames(common: common, variety: variety)
        return EiraOpenCandidate(kind: .plant, index: index, names: called)
    }
}
