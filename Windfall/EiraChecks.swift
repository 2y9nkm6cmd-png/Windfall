//
//  EiraChecks.swift
//  Windfall
//
//  Fixed rules that work around the model, on both sides of it.
//
//  A small model on a phone or a Mac is good at reading and rewording
//  and poor at remembering. So the app does two things for it, by rules
//  a person can read, with no model involved:
//
//    BEFORE it answers   Where a question plainly needs a fact from
//                        your records, the app looks the fact up and
//                        hands it over with the question. The model
//                        does not have to think to look, or guess.
//
//    AFTER it answers    The reply is read by rule before you see it.
//                        A claim to have saved something is taken out,
//                        because Eira cannot save from the chat. A
//                        scientific name that no lookup supplied is
//                        flagged as unchecked. An empty reply is said
//                        to be empty.
//
//  Each rule here exists because a model got exactly that wrong on the
//  test sheet on 13 November 2026 (knowledge base, doc 27). The rules
//  help whichever model Eira is using, Apple's included.
//
//  Nothing here needs a model or Apple's AI frameworks, so all of it is
//  covered by the logic tests.
//

import Foundation

enum EiraChecks {

    // MARK: - Before: a lookup the app runs first

    /// The lookup to run before the model sees this question, if any.
    ///
    /// One rule so far. A question about what to sow now is answered
    /// from the sowing months in your own plant library. Left to
    /// itself, Apple's model suggested parsnips in November and Qwen
    /// thought for four minutes and said nothing.
    ///
    ///   "What should I be sowing now?"            looked up first
    ///   "Is it too late to sow broad beans now?"  looked up first
    ///   "What have I sown this month?"            not: that asks for records
    ///   "I am sowing carrots today"               not: that is not a question
    static func lookupFirst(for question: String,
                            today: Date = .now,
                            calendar: Calendar = .current) -> ToolDefinition? {
        let text = EiraSafety.tidied(question)

        let questionStarts = [" what ", " which ", " when ", " can ", " should ", " is ", " are ", " do ",
                              " does ", " could ", " any ", " anything ", " whats "]
        let isQuestion = question.contains("?") || questionStarts.contains { text.hasPrefix($0) }
        guard isQuestion else { return nil }

        let month = calendar.component(.month, from: today)
        let monthName = calendar.monthSymbols[month - 1].lowercased()
        let nowWords = [" now ", " this month ", " this week ", " today ", " at the moment ",
                        " currently ", " in \(monthName) ", " this \(monthName) "]
        let asksAboutSowing = text.contains(" sow ") || text.contains(" sowing ")

        if asksAboutSowing && nowWords.contains(where: { text.contains($0) }) {
            return EiraTools.sowingNow
        }
        return nil
    }

    // MARK: - After: reading the reply by rule

    /// Said in place of any claim to have saved something.
    static let nothingSaved = "Nothing has been saved. I cannot change your records from this chat. To record it, tell the journal what you did and press Add on the card it offers."

    /// Said when the model thought and then wrote nothing.
    static let noAnswer = "I thought about that and did not reach an answer. Please ask again, perhaps more simply."

    /// The reply as you will see it.
    ///
    /// - `lookups`: what the lookups returned for this question.
    /// - `known`: other text the model was properly given, such as your
    ///   garden notes and corrections. A name found in the question, a
    ///   lookup or these counts as supplied, not remembered.
    static func checked(reply: String, question: String,
                        lookups: [String], known: [String] = []) -> String {
        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return noAnswer }

        var result = withoutSaveClaims(trimmed)

        let names = uncheckedNames(in: result, against: [question] + lookups + known)
        if !names.isEmpty {
            let listed = names.count == 1
                ? "the name \(names[0]) came"
                : "the names \(names.dropLast().joined(separator: ", ")) and \(names[names.count - 1]) came"
            result += "\n\nNot checked: \(listed) from the model's memory, not from a lookup."
        }
        return result
    }

    /// True when a sentence says Eira has saved, or will save, something.
    ///
    ///   "Your sowing is now recorded in the system."   a claim
    ///   "I've saved that for you."                     a claim
    ///   "You recorded a harvest on 9 November."        not: that is about you
    ///   "I have not saved anything."                   not: it says the opposite
    static func claimsToHaveSaved(_ sentence: String) -> Bool {
        let text = EiraSafety.tidied(sentence)
        let done = ["recorded", "saved", "logged", "added", "stored", "updated", "noted"]
        let will = ["save", "record", "log", "add", "store", "update", "note"]

        for word in done {
            // "is now recorded", "has now been saved"
            if text.contains(" now \(word) ") || text.contains(" now been \(word) ") { return true }
            // "I have saved", "I've now added", "I saved". Tidying has
            // already turned "I've" into "ive".
            for start in [" i have ", " ive ", " i have now ", " ive now ", " i ", " i just ", " ive just "] {
                if text.contains(start + word + " ") { return true }
            }
            // "has been saved to your records", "successfully added"
            if text.contains(" successfully \(word) ") { return true }
            if text.contains(" been \(word) ") {
                let places = [" to your ", " in your ", " in the system ", " for you ", " successfully "]
                if places.contains(where: { text.contains($0) }) { return true }
            }
        }
        for word in will {
            if text.contains(" i will \(word) ") || text.contains(" ill \(word) ")
                || text.contains(" i will now \(word) ") || text.contains(" ill now \(word) ") { return true }
        }
        return false
    }

    /// The reply with every such sentence taken out, and the plain truth
    /// added once at the end if any was.
    static func withoutSaveClaims(_ reply: String) -> String {
        var removedAny = false
        var keptLines: [String] = []

        // Line by line, so paragraphs and lists keep their shape.
        for line in reply.components(separatedBy: "\n") {
            let kept = sentences(in: line).filter { sentence in
                let isClaim = claimsToHaveSaved(sentence)
                if isClaim { removedAny = true }
                return !isClaim
            }
            // A line that was only a claim disappears. A blank line
            // that was already blank stays, to keep paragraphs apart.
            if kept.isEmpty && !line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            keptLines.append(kept.joined(separator: " "))
        }
        guard removedAny else { return reply }

        let rest = keptLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return rest.isEmpty ? nothingSaved : rest + "\n\n" + nothingSaved
    }

    /// Splits a line into sentences at a full stop, question mark or
    /// exclamation mark that is followed by a space.
    static func sentences(in line: String) -> [String] {
        var found: [String] = []
        var current = ""
        let characters = Array(line)
        for (index, character) in characters.enumerated() {
            current.append(character)
            let endsSentence = character == "." || character == "?" || character == "!"
            let spaceFollows = index + 1 < characters.count && characters[index + 1] == " "
            if endsSentence && spaceFollows {
                found.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            }
        }
        let last = current.trimmingCharacters(in: .whitespaces)
        if !last.isEmpty { found.append(last) }
        return found
    }

    // MARK: Scientific names nobody looked up

    /// Scientific names in the reply that appear in none of the sources.
    ///
    /// A scientific name is two words, the first with a capital and the
    /// second without: "Osmia bicornis". Models nearly always write
    /// them in italics or in brackets, so only those places are read:
    ///
    ///   *Osmia bicornis*        italics, written with asterisks
    ///   (Origanum majoricum)    brackets
    ///
    /// In italics, any such pair counts. In brackets the pair must also
    /// look Latin, because brackets hold plenty of ordinary English:
    /// "(Sweet pea)" and "(Large blue)" are not names.
    ///
    /// This is a flag and not a correction. A name from memory may be
    /// right. The point is that nobody checked it.
    static func uncheckedNames(in reply: String, against sources: [String]) -> [String] {
        let haystack = sources.joined(separator: "\n").lowercased()
        var found: [String] = []

        func consider(_ piece: String, mustLookLatin: Bool) {
            guard let name = scientificName(in: piece, mustLookLatin: mustLookLatin) else { return }
            if haystack.contains(name.lowercased()) { return }
            if !found.contains(name) { found.append(name) }
        }

        // Italics and bold: every second piece between asterisks, or
        // between underscores, is inside the marks.
        for marker in ["*", "_"] {
            let pieces = reply.replacingOccurrences(of: marker + marker, with: marker)
                .components(separatedBy: marker)
            for (index, piece) in pieces.enumerated() where index % 2 == 1 {
                consider(piece, mustLookLatin: false)
            }
        }

        // Brackets.
        var depthStart: String.Index?
        for index in reply.indices {
            if reply[index] == "(" {
                depthStart = reply.index(after: index)
            } else if reply[index] == ")", let start = depthStart {
                let inside = String(reply[start..<index])
                let wasEmphasised = inside.contains("*") || inside.contains("_")
                consider(inside, mustLookLatin: !wasEmphasised)
                depthStart = nil
            }
        }
        return found
    }

    /// Reads a piece of text as a scientific name, or returns nil.
    static func scientificName(in piece: String, mustLookLatin: Bool) -> String? {
        let cleaned = piece.trimmingCharacters(in: CharacterSet(charactersIn: "*_ \t"))
        var words = cleaned.components(separatedBy: " ").filter { !$0.isEmpty }
        // A hybrid is written with a cross between its two words.
        if words.count == 3, words[1] == "x" || words[1] == "×" { words.remove(at: 1) }
        guard words.count == 2 else { return nil }
        let genus = words[0], epithet = words[1]

        let genusLetters = Array(genus)
        guard let first = genusLetters.first, first.isUppercase,
              genusLetters.dropFirst().allSatisfy({ $0.isLetter && $0.isLowercase }),
              epithet.allSatisfy({ ($0.isLetter && $0.isLowercase) || $0 == "-" }),
              genus.count >= 3, epithet.count >= 2 else { return nil }

        // Ordinary words that turn up in italics or brackets.
        let notAGenus: Set<String> = ["Note", "Please", "Not", "The", "This", "That", "See", "Source", "Important",
                                      "Warning", "Tip", "Bed", "Use", "From", "For", "Your", "You", "Nothing",
                                      "None", "Yes", "Common", "Also", "Only", "Both", "Some", "Most"]
        let notAnEpithet: Set<String> = ["this", "that", "note", "here", "there", "more", "some", "the", "and",
                                         "are", "is", "one", "none", "also", "please", "use", "care", "sure",
                                         "true", "false", "these", "those", "once", "twice", "time", "date",
                                         "name", "type", "like", "safe", "save", "done", "made", "have", "above",
                                         "advice", "source", "sources", "family", "order", "genus", "species",
                                         "group", "class", "checked", "sense", "bees", "flies", "plants"]
        if notAGenus.contains(genus) || notAnEpithet.contains(epithet) { return nil }

        if mustLookLatin {
            let genusEndings = ["us", "um", "is", "ia", "ula", "ella", "ium", "ax", "yx", "on", "es"]
            let endsAsGenus = genusEndings.contains { genus.hasSuffix($0) } || (genus.hasSuffix("a") && genus.count >= 5)
            let epithetEndings = ["a", "e", "i", "is", "us", "um", "ae", "ii", "ens", "ans", "or", "es", "on",
                                  "ys", "ax", "ex", "ix", "ox", "io"]
            let endsAsEpithet = epithetEndings.contains { epithet.hasSuffix($0) }
            guard genus.count >= 4, epithet.count >= 3, endsAsGenus, endsAsEpithet else { return nil }
        }
        return "\(genus) \(epithet)"
    }
}
