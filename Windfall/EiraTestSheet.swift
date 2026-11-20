//
//  EiraTestSheet.swift
//  Windfall
//
//  Reads the questions file that Eira's test run puts to her
//  (EiraTestRun.swift). Kept apart from the run itself, which needs
//  the app, so that how a line is read can be tested without one
//  (Tools/checks/LogicTests.swift).
//
//  Moved out of EiraTestRun.swift on 20 November 2026, when three new
//  kinds of line were added: `page:`, `add` and `page: none`.
//

import Foundation

/// One line of the questions file, once understood.
enum EiraTestStep: Equatable {
    /// Ask this in a new conversation. The label is how it is headed in
    /// the answers file, such as "A1".
    case ask(label: String, question: String)
    /// Tell Eira her last reply was wrong, and what is right.
    case correct(String)
    /// Say this next, in the conversation already going. Used to put
    /// Eira right the way it would be typed.
    case followUp(label: String, question: String)
    /// Press "Keep it" on the card that offers to keep a correction.
    case keep
    /// Press "Keep it" on the card that offers to keep what Eira read
    /// online, leaving the card as it came up.
    case keepFind
    /// Have this page open for the next question. Added 20 November 2026.
    case page(EiraTestPage)
    /// Press Add on the card that is waiting, as it came up. Added 20
    /// November 2026.
    case add
}

/// A page to have open while a question is asked, as written after
/// `page:` in the questions file.
enum EiraTestPage: Equatable {
    /// No page: the question is asked as from Eira's own chat.
    case none
    /// One of the app's places, by its name in `AppSection`: today,
    /// gardens, year, plants, wildlife, identify, journal or more.
    case place(String)
    /// A plant's page. The variety may be left off when only one plant
    /// in the library has that name.
    case plant(name: String, variety: String?)
    /// A bed's page, by the bed's name: "Bed 3", "Herb bed".
    case bed(String)
    /// A species' page in the wildlife lists, by its common name.
    case species(String)
    /// A seed packet's page, by the name of the plant it is for.
    case seedPacket(String)
    /// A sowing's page, by the name of the plant sown.
    case sowing(String)
    /// Words that name none of the above. The run says so and asks the
    /// question with no page open.
    case unknown(String)
}

enum EiraTestSheet {

    /// The places a `page:` line can name on their own.
    nonisolated static let places = ["today", "gardens", "year", "plants", "wildlife", "identify", "journal", "more"]

    /// Turns the text of a questions file into steps.
    ///
    /// `nonisolated` means this may run on any thread. It only reads the
    /// text it is given and touches nothing shared, so that is safe.
    nonisolated static func steps(from text: String) -> [EiraTestStep] {
        var steps: [EiraTestStep] = []
        var asked = 0

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let lower = line.lowercased()

            if lower.hasPrefix("correct:") {
                let words = line.dropFirst("correct:".count).trimmingCharacters(in: .whitespaces)
                if !words.isEmpty { steps.append(.correct(words)) }
                continue
            }
            if lower.hasPrefix("page:") {
                let words = line.dropFirst("page:".count).trimmingCharacters(in: .whitespaces)
                steps.append(.page(page(from: words)))
                continue
            }
            if lower == "keep" {
                steps.append(.keep)
                continue
            }
            if lower == "keep find" {
                steps.append(.keepFind)
                continue
            }
            if lower == "add" {
                steps.append(.add)
                continue
            }

            // "then:" in front means the same conversation carries on.
            var rest = line
            let carriesOn = lower.hasPrefix("then:")
            if carriesOn {
                rest = line.dropFirst("then:".count).trimmingCharacters(in: .whitespaces)
                if rest.isEmpty { continue }
            }

            asked += 1
            // "A1 | question" carries its own label. A bare question is
            // numbered Q1, Q2 and so on.
            var label = "Q\(asked)"
            var question = rest
            if let bar = rest.range(of: " | ") {
                let given = rest[..<bar.lowerBound].trimmingCharacters(in: .whitespaces)
                question = rest[bar.upperBound...].trimmingCharacters(in: .whitespaces)
                if question.isEmpty { asked -= 1; continue }
                if !given.isEmpty { label = given }
            }
            steps.append(carriesOn ? .followUp(label: label, question: question)
                                   : .ask(label: label, question: question))
        }
        return steps
    }

    /// Reads the words after `page:`.
    ///
    ///     page: journal                    one of the app's places
    ///     page: plant Rhubarb, Victoria    a plant, with its variety
    ///     page: plant Medlar               a plant, without one
    ///     page: bed Bed 3                  a bed, by its whole name
    ///     page: species Tree bumblebee     a species
    ///     page: seed packet Broad bean     a seed packet, by its plant
    ///     page: sowing Broad bean          a sowing, by its plant
    ///     page: none                       nothing open
    ///
    /// The kind of page is read without regard to capitals. The name
    /// after it is kept as written.
    nonisolated static func page(from words: String) -> EiraTestPage {
        let trimmed = words.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()
        if lower.isEmpty || lower == "none" { return .none }
        if places.contains(lower) { return .place(lower) }

        /// The name after a kind's word, or nil if the words do not
        /// start with that kind followed by a space and something more.
        func name(after kind: String) -> String? {
            guard lower.hasPrefix(kind + " ") else { return nil }
            let rest = trimmed.dropFirst(kind.count + 1).trimmingCharacters(in: .whitespaces)
            return rest.isEmpty ? nil : rest
        }

        // "seed packet" before anything shorter, so its two words are
        // read together.
        if let plant = name(after: "seed packet") { return .seedPacket(plant) }
        if let plant = name(after: "sowing") { return .sowing(plant) }
        if let bed = name(after: "bed") { return .bed(bed) }
        if let species = name(after: "species") { return .species(species) }
        if let plant = name(after: "plant") {
            // "Rhubarb, Victoria": the variety follows the first comma.
            if let comma = plant.range(of: ",") {
                let common = plant[..<comma.lowerBound].trimmingCharacters(in: .whitespaces)
                let variety = plant[comma.upperBound...].trimmingCharacters(in: .whitespaces)
                return .plant(name: common, variety: variety.isEmpty ? nil : variety)
            }
            return .plant(name: plant, variety: nil)
        }
        return .unknown(trimmed)
    }

    /// A long piece of text cut to its first `limit` characters, on one
    /// line, for the answers file.
    nonisolated static func shortened(_ text: String, limit: Int) -> String {
        let oneLine = text.replacingOccurrences(of: "\n", with: " ")
        return oneLine.count > limit ? String(oneLine.prefix(limit)) + "…" : oneLine
    }
}
