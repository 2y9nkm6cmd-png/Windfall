//
//  EiraChatLayout.swift
//  Windfall
//
//  How Eira's conversation is laid out on the chat screen.
//
//  The conversation is kept as a flat list: your message, then each
//  lookup she made, then her reply. Until 14 November 2026 the screen
//  drew that list as it stood, so one question could put four grey
//  lookup rows between your words and her answer.
//
//  This file folds the list into "turns". A turn is one message
//  together with the lookups that led to it. The screen draws a turn's
//  lookups as a single closed bubble above the reply, which opens when
//  tapped (EiraChatCards.swift).
//
//  It also works out which plants from your library a turn's lookups
//  found, so the screen can put a card for each under the reply.
//
//  Nothing here draws anything or needs Apple's screen frameworks, so
//  all of it is covered by the logic tests.
//

import Foundation

enum EiraChatLayout {

    // MARK: - Turns

    /// One message and the lookups made on the way to it.
    ///
    /// `Identifiable` lets a SwiftUI `ForEach` tell the turns apart. The
    /// id is the message's own, so anything filed under a message's id
    /// (a photo, a correction card) still finds its turn.
    struct Turn: Identifiable {
        let id: UUID
        /// The lookups Eira made before this message, oldest first.
        /// Empty for your own messages.
        let lookups: [ChatMessage]
        /// The message. Nil when lookups have been made and her reply
        /// has not come: she is still working, or was stopped.
        let message: ChatMessage?
    }

    /// Folds the flat list of messages into turns.
    ///
    ///   you, lookup, lookup, Eira     two turns: yours, and hers with
    ///                                 two lookups
    ///   you, lookup                   two turns: yours, and one with
    ///                                 no message yet
    ///
    /// Instructions to the model (the `.system` role) are never drawn,
    /// so they are left out.
    static func turns(from messages: [ChatMessage]) -> [Turn] {
        var turns: [Turn] = []
        // Lookups seen since the last message, waiting for the reply
        // they belong to.
        var waiting: [ChatMessage] = []

        for message in messages {
            switch message.role {
            case .system:
                continue
            case .tool:
                waiting.append(message)
            case .assistant:
                turns.append(Turn(id: message.id, lookups: waiting, message: message))
                waiting = []
            case .user:
                // Lookups with no reply after them: the reply was
                // stopped or failed. They keep a turn of their own.
                if let first = waiting.first {
                    turns.append(Turn(id: first.id, lookups: waiting, message: nil))
                    waiting = []
                }
                turns.append(Turn(id: message.id, lookups: [], message: message))
            }
        }
        if let first = waiting.first {
            turns.append(Turn(id: first.id, lookups: waiting, message: nil))
        }
        return turns
    }

    // MARK: - The words on the bubble

    /// A lookup in plain words. The model knows each lookup by a short
    /// code name such as `search_garden`, which means little to read.
    static func title(forLookup codeName: String?) -> String {
        switch codeName {
        case "search_garden":    return "Searched your plants"
        case "lookup_species":   return "Looked up the species name"
        case "plant_visitors":   return "Checked what visits it"
        case "search_notes":     return "Searched your notes"
        case "whats_growing":    return "Checked what is growing"
        case "recent_records":   return "Checked your recent records"
        case "sowing_now":       return "Checked what can be sown now"
        case "search_wikipedia": return "Searched Wikipedia"
        case "read_web_page":    return "Read a web page"
        default:                 return "Looked something up"
        }
    }

    /// What the closed bubble says once the reply is finished.
    ///
    ///   3 lookups, no reasoning   "Looked in 3 places"
    ///   1 lookup, reasoning       "Thought it through and looked in 1 place"
    ///   no lookups, reasoning     "Thought it through"
    static func summary(lookups count: Int, hasReasoning: Bool) -> String {
        let places = count == 1 ? "1 place" : "\(count) places"
        if count == 0 { return "Thought it through" }
        return hasReasoning ? "Thought it through and looked in \(places)" : "Looked in \(places)"
    }

    /// What a lookup brought back, split from the line saying where it
    /// came from. Every result ends with a line like
    /// `[source: user's plant database]` (ToolResult.formatted).
    ///
    /// `found` is the result without that line. `source` is nil when
    /// there is no such line.
    static func parts(ofResult text: String) -> (found: String, source: String?) {
        let marker = "[source: "
        // `.backwards` looks from the end, because the source line is
        // always last and a web page's own text might hold the marker.
        guard let start = text.range(of: marker, options: .backwards),
              text.hasSuffix("]") else {
            return (text.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }
        let found = text[..<start.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        let source = String(text[start.upperBound...].dropLast())
        return (found, source.isEmpty ? nil : source)
    }

    // MARK: - Plants the lookups found

    /// The lines of a turn's lookups that each speak of one plant in
    /// your plant library.
    ///
    /// Two lookups name plants from the library:
    ///
    ///   search_garden    one line for each plant, starting with its
    ///                    name: "Lavender — Hidcote; (Lavandula
    ///                    angustifolia); position: Full sun"
    ///   lookup_species   one line when the species is in the library:
    ///                    "In the gardener's own records: Lavender —
    ///                    Hidcote (Lavandula angustifolia), in the
    ///                    plant library"
    ///
    /// For the second, the words around the name are taken off.
    static func plantLines(in lookups: [ChatMessage]) -> [String] {
        let ownRecordStart = "In the gardener's own records: "
        let ownRecordEnd = ", in the plant library"
        var lines: [String] = []

        for lookup in lookups {
            let found = parts(ofResult: lookup.content).found
            let each = found.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }

            switch lookup.toolName {
            case "search_garden":
                // "Nothing matching ..." is what a search that found
                // nothing says, and "(shortened)" marks a cut result.
                lines += each.filter { !$0.isEmpty && !$0.hasPrefix("Nothing matching") && $0 != "(shortened)" }
            case "lookup_species":
                for line in each where line.hasPrefix(ownRecordStart) && line.hasSuffix(ownRecordEnd) {
                    lines.append(String(line.dropFirst(ownRecordStart.count).dropLast(ownRecordEnd.count)))
                }
            default:
                break
            }
        }
        return lines
    }

    /// Which of the plants in your library a turn's lookups found, by
    /// name, in the order the lookups gave them and each once only.
    ///
    /// `libraryNames` is every plant's full name as the library shows
    /// it, variety included ("Apple — Spartan").
    ///
    /// A line belongs to a plant when it is that plant's name, or the
    /// name followed by ";" or " (". Where more than one name fits, the
    /// longest wins: the line "Apple (Cider) — Fiona (Malus domestica)"
    /// starts with "Apple (", but it is the cider apple and not the
    /// plant called plain "Apple".
    static func plantNames(foundBy lookups: [ChatMessage], among libraryNames: [String]) -> [String] {
        var matched: [String] = []
        for line in plantLines(in: lookups) {
            let fitting = libraryNames.filter { each in
                !each.isEmpty && (line == each || line.hasPrefix(each + ";") || line.hasPrefix(each + " ("))
            }
            // `max(by:)` with "shorter comes first" returns the longest.
            if let best = fitting.max(by: { $0.count < $1.count }), !matched.contains(best) {
                matched.append(best)
            }
        }
        return matched
    }
}
