//
//  FungusKey.swift
//  Windfall
//
//  Windfall's own key to the commoner groups of larger fungi.
//
//  A key is a chain of questions. Each answer you choose leads to the
//  next question, until you arrive at a group. This file is the rules:
//  how the key is read from FungusKey.json and how a walk through it is
//  remembered. What you see is in FungusKeyView.swift.
//
//  THREE THINGS THIS KEY NEVER DOES
//    1. It never says whether a fungus can be eaten. Its answers are
//       groups for a wildlife record. `faults()` fails the checks if
//       the word "edible" ever appears in the file.
//    2. It never saves anything by itself. A sighting is made only when
//       "Add a sighting" is pressed, and the name goes in as a
//       suggestion, never as confirmed.
//    3. It is not Eira. She still refuses to name a fungus or to say
//       one is safe (EiraSafety.fungiReply). The key is fixed words
//       that William checks, with no model anywhere in it.
//
//  The words were written by Claude from memory on 14 November 2026,
//  not taken from any book or website (project doc 58). The file says
//  "checked": false until William has read it against a field guide,
//  and the screen says "to check" for as long as it does.
//

import Foundation

/// The whole key, as read from FungusKey.json.
///
/// `Decodable` lets Swift fill these in from the file by matching
/// names: "question" in the file goes into `question` here. That is why
/// the names are spelled the same in both places.
struct FungusKey: Decodable {

    /// False until William has checked the words. Missing counts as false.
    let checked: Bool?
    /// The first step's id.
    let start: String
    /// The answer that "None of these fit" leads to, from any step.
    let noneOfThese: String
    /// One line shown under every answer.
    let footer: String
    let steps: [Step]
    let results: [Answer]

    /// One question, with the choices that answer it.
    struct Step: Decodable, Identifiable, Hashable {
        let id: String
        /// A few words for the top of the step: "White spores".
        let title: String
        let question: String
        /// How to look or what a word means. A `?` after a type means
        /// "may be missing", so a step with no help is fine.
        let help: String?
        let choices: [Choice]
    }

    /// One choice at a step.
    struct Choice: Decodable, Hashable {
        let text: String
        /// The id of the step or answer this choice leads to.
        let to: String
        /// A smaller second line.
        let detail: String?
        /// The diagram's name. Its picture is "Icons/fungus-<picture>".
        let picture: String?
    }

    /// Where a walk ends: a group, a genus or sometimes one species.
    struct Answer: Decodable, Identifiable, Hashable {
        let id: String
        /// The everyday name: "Honey fungus".
        let name: String
        /// The scientific name or names. May be empty.
        let latin: String
        /// What kind of answer it is: "Genus", "Group", "Species",
        /// "How to", "No answer" and so on.
        let rank: String
        /// The features to check before believing the answer.
        let confirm: [String]
        let examples: [String]?
        let notes: String?
        /// Deadly or poisonous members and look-alikes that matter.
        let danger: String?
        /// What it means for a grower.
        let garden: String?
    }

    /// Reads a key from the bytes of a file. Gives nothing back, and
    /// does not crash, if they are not a key.
    init?(data: Data) {
        guard let key = try? JSONDecoder().decode(FungusKey.self, from: data) else { return nil }
        self = key
    }

    /// The key that travels inside the app, read the first time it is
    /// asked for and then kept. `Bundle.main` is the app's own package
    /// of files.
    static let shared: FungusKey? = {
        guard let url = Bundle.main.url(forResource: "FungusKey", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return FungusKey(data: data)
    }()

    var isChecked: Bool { checked ?? false }

    /// The step with this id, if it is a step.
    func step(_ id: String) -> Step? { steps.first { $0.id == id } }

    /// The answer with this id, if it is an answer.
    func answer(_ id: String) -> Answer? { results.first { $0.id == id } }

    /// Every diagram the key names.
    var pictures: Set<String> {
        Set(steps.flatMap { $0.choices.compactMap(\.picture) })
    }

    // MARK: What a sighting made from an answer holds

    /// The name to suggest in a sighting, or nothing where the answer
    /// is not something seen, such as "Take a spore print first".
    func sightingName(for answer: Answer) -> String? {
        if answer.rank == "How to" { return nil }
        if answer.id == noneOfThese { return "Fungus, not identified" }
        return answer.name
    }

    /// The group a sighting from this answer belongs to. Slime moulds
    /// are in the key because they turn up on mulch, but are not fungi.
    func taxonGroup(for answer: Answer) -> TaxonGroup {
        answer.rank == "Not a fungus" ? .other : .fungus
    }

    // MARK: Checking the file itself

    /// Everything wrong with the key, in words. Empty when it is sound.
    /// The logic tests run this on the real file, so a slip made while
    /// correcting the words is caught before it reaches a device.
    func faults() -> [String] {
        var found: [String] = []
        let stepIDs = steps.map(\.id), answerIDs = results.map(\.id)
        let all = stepIDs + answerIDs
        // `Set` drops repeats, so a shorter set means an id used twice.
        if Set(all).count != all.count { found.append("an id is used twice") }
        if step(start) == nil { found.append("the start, \(start), is not a step") }
        if answer(noneOfThese) == nil { found.append("\(noneOfThese) is not an answer") }

        var reached: Set<String> = [start, noneOfThese]
        for step in steps {
            if step.choices.count < 2 { found.append("\(step.id) has fewer than two choices") }
            for choice in step.choices {
                if !all.contains(choice.to) { found.append("\(step.id) leads to \(choice.to), which does not exist") }
                reached.insert(choice.to)
            }
        }
        for id in all where !reached.contains(id) { found.append("nothing leads to \(id)") }
        for answer in results where answer.confirm.isEmpty { found.append("\(answer.id) has nothing to check") }

        // The key is for recording. It must never say what can be eaten.
        // Gathered a piece at a time: one long expression here took the
        // compiler too long to work out the types of.
        var pieces: [String] = []
        for step in steps {
            pieces.append(step.question)
            pieces.append(step.help ?? "")
            for choice in step.choices {
                pieces.append(choice.text)
                pieces.append(choice.detail ?? "")
            }
        }
        for answer in results {
            pieces.append(answer.name)
            pieces.append(answer.notes ?? "")
            pieces.append(answer.danger ?? "")
            pieces.append(answer.garden ?? "")
            pieces.append(contentsOf: answer.confirm)
            pieces.append(contentsOf: answer.examples ?? [])
        }
        let words = pieces.joined(separator: " ").lowercased()
        if words.contains("edible") { found.append("the word \"edible\" is in the key") }
        return found
    }
}

// MARK: - A walk through the key

/// The choices taken so far and where they have led.
///
/// It holds no screen code on purpose, so the logic tests can take a
/// walk and step back without building a screen.
struct FungusWalk: Equatable {

    /// One choice that was taken: at which step, and its words.
    struct Taken: Hashable {
        let step: String
        let choice: String
    }

    /// The trail. `private(set)` means other code may read it and only
    /// this struct may change it, so it cannot be muddled from outside.
    private(set) var taken: [Taken] = []
    /// The id of the step or answer now showing.
    private(set) var here: String
    private let start: String

    init(start: String) {
        self.start = start
        here = start
    }

    /// Take a choice: remember it and move on. `mutating` marks a
    /// function that changes the struct it belongs to.
    mutating func choose(_ choice: FungusKey.Choice, at step: String) {
        taken.append(Taken(step: step, choice: choice.text))
        here = choice.to
    }

    /// "None of these fit", from any step.
    mutating func noneFit(at step: String, in key: FungusKey) {
        taken.append(Taken(step: step, choice: "None of these fit"))
        here = key.noneOfThese
    }

    /// Go back to an earlier step and forget what came after it.
    /// `index...` reads "from index onwards".
    mutating func back(to index: Int) {
        guard taken.indices.contains(index) else { return }
        here = taken[index].step
        taken.removeSubrange(index...)
    }

    /// One step back. Does nothing at the start.
    mutating func back() { back(to: taken.count - 1) }

    mutating func startAgain() {
        taken = []
        here = start
    }

    var isAtStart: Bool { taken.isEmpty }

    /// The walk in words, for a sighting's notes, so the record shows
    /// how the name was reached.
    func note(reaching answer: FungusKey.Answer) -> String {
        var lines = ["Windfall's fungus key led to: \(answer.name)" + (answer.latin.isEmpty ? "." : " (\(answer.latin)).")]
        if !taken.isEmpty {
            lines.append("Steps: " + taken.map(\.choice).joined(separator: " › "))
        }
        lines.append("A key gives a group, not a certain name. Not checked by anyone who knows fungi.")
        return lines.joined(separator: "\n")
    }
}
