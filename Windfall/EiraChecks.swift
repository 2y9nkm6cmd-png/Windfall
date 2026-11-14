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
//    WHEN YOU PUT HER RIGHT   A message such as "No, that's wrong. It's
//                        a Bramley." is spotted by rule, and a card
//                        offers to keep the fact as a correction. Eira
//                        is told her corrections at the start of every
//                        conversation. (14 November 2026.)
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

    // MARK: - A correction typed as an ordinary message

    /// What to keep from a message that puts Eira right, or nil if the
    /// message is not a correction.
    ///
    /// Until 14 November 2026 a correction was kept only if it was made
    /// with "Correct this" on one of her replies. Typing "No, that's
    /// wrong, it's a Bramley" was answered and then forgotten. Now such
    /// a message brings up a card offering to keep it, and this decides
    /// whether a message is one.
    ///
    /// A correction opens by disagreeing and then states a fact:
    ///
    ///   "No, that's wrong. It's a Bramley."   keeps "It's a Bramley."
    ///   "Actually it flowers in June"         keeps the whole message
    ///   "That's not a Spartan, it's a Bramley"  keeps the whole message
    ///   "No, that's wrong"                    nothing: no fact in it
    ///   "No slugs on the hostas this year"    nothing: "no" is the subject
    ///   "No, tell me about the other one"     nothing: a request, not a fact
    ///   "That's wrong, isn't it?"             nothing: it is a question
    ///   "Actually that's really helpful"      nothing: praise, not a fact
    ///   "No, I'll do it tomorrow"             nothing, if she had just
    ///                                         asked "Shall I list them?"
    ///
    /// The opening is taken off only where you set it apart with a comma
    /// or a full stop. "That is wrong for clay soil" would otherwise be
    /// kept as "for clay soil", which says nothing.
    ///
    /// Where the rule is unsure it offers nothing. "Correct this" is
    /// under every reply for whatever it misses.
    ///
    /// - `eirasReply`: what she said just before, if anything. A plain
    ///   "No" after a question of hers is an answer to it.
    static func correctionWords(in whatWasTyped: String, answering eirasReply: String = "") -> String? {
        // A question is asking, not telling.
        if whatWasTyped.contains("?") { return nil }
        // Several lines become one, because a correction is read to the
        // model as a single line.
        let typed = whatWasTyped.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let text = EiraSafety.tidied(typed)

        // "No" that is manners, or the start of the subject.
        let notDisagreeing = [" no thanks", " no thank you", " no problem", " no worries", " no idea ",
                              " no need", " no rush", " no dig", " no till", " no mow"]
        if notDisagreeing.contains(where: { text.hasPrefix($0) }) { return nil }

        // Praise, or a grumble about the question or the app, is not a
        // fact about the garden.
        let notAFact = [" helpful", " thanks", " thank you", " perfect", " brilliant", " great ", " lovely",
                        " makes sense", " good idea", " good point", " interesting",
                        " what i asked", " what i meant", " what i said", " my question",
                        " not working", " isnt working", " doesnt work"]
        if notAFact.contains(where: { text.contains($0) }) { return nil }

        // Openings that say she was wrong. Longest first, so that all of
        // "no that is not right" is found and not only its "no".
        let disagreeing = [
            "no that is not right", "no thats not right", "no that isnt right", "no that is wrong",
            "no thats wrong", "no thats incorrect", "no you are wrong", "no youre wrong",
            "that is not right", "thats not right", "that isnt right", "that is not correct",
            "thats not correct", "that isnt correct", "that is incorrect", "thats incorrect",
            "that is wrong", "thats wrong", "that was wrong", "you are wrong", "youre wrong",
            "you got that wrong", "you have that wrong", "youve got that wrong",
            "not quite", "incorrect", "correction", "actually", "wrong", "nope", "no"
        ]
        // Openings that are part of the fact and are never taken off.
        let statingTheMistake = [
            "you said", "you told me", "that is not", "thats not", "that isnt", "that was not",
            "that wasnt", "it is not", "its not", "it isnt", "they are not", "theyre not", "they arent"
        ]

        var kept = typed
        if let opening = disagreeing.first(where: { text.hasPrefix(" " + $0 + " ") }) {
            // Find where the opening ends in the message as it was typed,
            // by counting its letters and digits. Spaces and punctuation
            // do not count, so "No, that's wrong." matches "no thats wrong".
            var toSkip = opening.filter { $0.isLetter || $0.isNumber }.count
            var rest = Substring(typed)
            while toSkip > 0, let first = rest.first {
                if first.isLetter || first.isNumber { toSkip -= 1 }
                rest = rest.dropFirst()
            }
            // What stands between the opening and the next word.
            let gap = rest.prefix { !($0.isLetter || $0.isNumber) }
            let setApart = gap.contains { ",.;:!\u{2013}\u{2014}".contains($0) } || gap.contains(" - ")
            let after = EiraSafety.tidied(String(rest))

            // A bare "no" or "wrong" is too common a word to trust alone.
            // It counts when set apart ("No, ...") or when it runs on into
            // a statement ("No it's a Bramley"), but not in "No slugs on
            // the hostas".
            // And "No" after a question of hers answers the question.
            let sheAsked = eirasReply.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?")
            if ["no", "nope"].contains(opening) && sheAsked { return nil }
            if ["no", "nope", "wrong"].contains(opening) && !setApart {
                let statementStarts = ["it", "its", "that", "thats", "the", "my", "i", "im", "ive", "you",
                                       "youre", "they", "theyre", "this", "these", "those", "there", "we"]
                guard let next = after.split(separator: " ").first,
                      statementStarts.contains(String(next)) else { return nil }
            }

            // "No, tell me about the other one" asks for something else.
            let requests = [" tell me", " show me", " give me", " list ", " can you", " could you", " would you",
                            " will you", " please", " i want", " i would like", " id like", " i meant", " i mean ",
                            " lets ", " let us ", " never mind", " nevermind", " forget ", " ignore ", " stop ",
                            " try again", " what ", " how ", " why ", " when ", " where ", " which ", " who "]
            if requests.contains(where: { after.hasPrefix($0) }) { return nil }

            // The fact must be more than a word or two.
            guard after.split(separator: " ").count >= 3 else { return nil }

            if setApart {
                kept = String(rest.dropFirst(gap.count))
                kept = kept.prefix(1).uppercased() + kept.dropFirst()
            }
        } else if let opening = statingTheMistake.first(where: { text.hasPrefix(" " + $0 + " ") }) {
            // "It's not working" is not about a fact. Four words at least.
            guard text.split(separator: " ").count >= 4 else { return nil }
            // "You said to prune in winter, tell me more" repeats her and
            // moves on. It is a correction only if it goes on to disagree.
            if opening.hasPrefix("you") {
                let disagrees = [" but ", " not ", " wrong ", " actually ", " isnt ", " wasnt ", " arent ", " doesnt "]
                guard disagrees.contains(where: { text.contains($0) }) else { return nil }
            }
        } else {
            return nil
        }

        // Longer than this and the line read to the model would be cut
        // off part way. "Correct this" is the place for a longer one.
        guard kept.count <= correctionLimit else { return nil }
        return kept
    }

    /// The most characters of a correction that are read to the model.
    nonisolated static let correctionLimit = 240

    /// Where a typed correction stands when Eira's reply to it is read.
    enum CorrectionStanding {
        /// The message was not a correction.
        case notACorrection
        /// The card to keep it is showing and has not been answered.
        case waiting
        /// "Keep it" has been pressed.
        case kept
    }

    /// Said in place of a claim to have saved, while the card to keep a
    /// correction is waiting for an answer.
    static let correctionNotKeptYet = "I have not kept that yet. Press \"Keep it\" on the card above and I will be told it at the start of every conversation."

    /// Said in place of a claim to have saved, once a correction is kept.
    static let correctionKept = "Your correction is kept, and I will be told it at the start of every conversation. Your records themselves are unchanged."

    // MARK: - Before: handing over the corrections that bear on a question

    /// Words too common to say what a question is about.
    private static let commonWords: Set<String> = [
        "what", "which", "when", "where", "does", "have", "that", "this", "with", "from", "your", "about",
        "tell", "there", "also", "kind", "sort", "should", "would", "could", "will", "they", "them", "their",
        "then", "than", "into", "much", "many", "some", "grow", "growing", "grown", "garden", "plant",
        "planted", "planting", "year", "month", "week", "today", "best", "good", "need", "want", "like",
        "make", "know", "please", "thanks", "wrong", "right", "really", "still", "very", "just", "more",
        "most", "been", "were", "here", "mine", "said", "told"
    ]

    /// The words of a piece of text that say what it is about: four
    /// letters or more, not a common word, and without a final "s", so
    /// that "apples" and "apple" count as the same word.
    static func wordsThatMatter(in text: String) -> Set<String> {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.count > 4 && $0.hasSuffix("s") ? String($0.dropLast()) : $0 }
            .filter { $0.count >= 4 && !commonWords.contains($0) }
        return Set(words)
    }

    /// The kept corrections that bear on a question, newest first.
    ///
    /// Why this exists. The ten newest corrections are in Eira's
    /// standing instructions, and Apple's model uses them. On 14 November
    /// 2026 the trained Qwen did not: told there was a Bramley apple by
    /// the shed, it was asked in a new conversation whether there was
    /// one, ran a lookup, found nothing and said no. A model weighs what
    /// arrives with the question more than what stood in its
    /// instructions. So a correction that shares a word with the question
    /// is now handed over with the question, as a lookup's result is.
    ///
    /// It also brings an old correction back when it is needed. Only the
    /// ten newest fit in the instructions, but every one is searched
    /// here.
    ///
    /// A correction bears on a question when the two share a word that
    /// matters. The question the correction was first given on counts
    /// too: "It's a Bramley", given on "Which apple is by the shed?",
    /// comes back for "Tell me about the apple tree".
    ///
    /// `[EiraCorrection]` is a list of the saved records. `limit` keeps
    /// the hand-over short: a small model reads every word.
    static func corrections(bearingOn question: String, among all: [EiraCorrection], limit: Int = 3) -> [EiraCorrection] {
        let asked = wordsThatMatter(in: question)
        guard !asked.isEmpty else { return [] }
        let bearing = all.filter { each in
            // `isDisjoint` is true when two sets share nothing.
            !asked.isDisjoint(with: wordsThatMatter(in: each.topic + " " + each.correction))
        }
        return Array(bearing.prefix(limit))
    }

    /// The lines put in front of a question when corrections bear on it.
    /// Only the model sees them.
    static func handOver(_ corrections: [EiraCorrection]) -> String {
        let lines = corrections.map { "- " + $0.promptLine }.joined(separator: "\n")
        return """
        The gardener has put you right on this before. What they told you is right, even where a lookup finds nothing or disagrees. When you use it, say it is what the gardener told you, not what the records show:
        \(lines)
        """
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
    /// - `correction`: where a typed correction stands, if the question
    ///   was one. A claim to have saved is then answered with the truth
    ///   about the correction, not with the line about the journal.
    static func checked(reply: String, question: String,
                        lookups: [String], known: [String] = [],
                        correction: CorrectionStanding = .notACorrection) -> String {
        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return noAnswer }

        let truth: String
        switch correction {
        case .notACorrection: truth = nothingSaved
        case .waiting: truth = correctionNotKeptYet
        case .kept: truth = correctionKept
        }
        var result = withoutSaveClaims(trimmed, saying: truth)

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
    ///   "Nothing has been recorded in your records."   not: the opposite again
    ///
    /// The sentence is read a clause at a time, split at commas and at
    /// "but" and "and". That way "I cannot save changes, but your sowing
    /// is now recorded" is still caught by its second half.
    static func claimsToHaveSaved(_ sentence: String) -> Bool {
        var clauses = sentence.components(separatedBy: CharacterSet(charactersIn: ",;:"))
        for joiner in [" but ", " and "] {
            clauses = clauses.flatMap { $0.components(separatedBy: joiner) }
        }
        return clauses.contains { clauseClaimsToHaveSaved($0) }
    }

    /// The same question of one clause.
    private static func clauseClaimsToHaveSaved(_ clause: String) -> Bool {
        let text = EiraSafety.tidied(clause)
        let done = ["recorded", "saved", "logged", "added", "stored", "updated", "noted"]
        let will = ["save", "record", "log", "add", "store", "update", "note"]

        // A clause that denies it says the opposite of a claim: "nothing
        // has been recorded", "no harvests have been logged in your
        // records", "it has not been saved". Until 14 November 2026
        // these were taken for claims. The trained Qwen said, rightly,
        // that nothing had been recorded, and the app took the sentence
        // out and wrote "Nothing has been saved" under its answer.
        //
        // The denial has to come before the saving word. Tidying has
        // turned "hasn't" into "hasnt". Each such word is listed whole:
        // looking for any word ending in "nt" would also find "plant".
        let denials = [" nothing ", " none ", " no ", " not ", " never ", " cannot ",
                       " cant ", " couldnt ", " dont ", " doesnt ", " didnt ", " hasnt ", " havent ",
                       " hadnt ", " isnt ", " arent ", " wasnt ", " werent ", " wont ", " wouldnt "]
        for word in done + will {
            guard let found = text.range(of: " \(word) ") else { continue }
            let before = text[..<found.lowerBound] + " "
            if denials.contains(where: { before.contains($0) }) { return false }
        }

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
    static func withoutSaveClaims(_ reply: String, saying truth: String = nothingSaved) -> String {
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
        return rest.isEmpty ? truth : rest + "\n\n" + truth
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
