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
//  MORE THAN ONE KEY (15 November 2026, project doc 77)
//    The same code can step through any file of this shape. `FungusKeys`
//    at the foot of this file lists the ones in the app: Windfall's own,
//    then John Wright's if his file is there, or else a sample.
//
//    His key would be WrightFungusKey.json in Windfall/PrivateKeys. That
//    folder is in .gitignore, so his words never reach the public copy
//    on GitHub. Nothing of his is in the app until he has said yes and
//    his file has been put there by hand on the Mac.
//
//    A key that is someone else's carries a `credit`. Only such a key
//    may hold a `verdict`, the author's own word on eating, and only if
//    the credit says he allowed it. Windfall's own key never may. The
//    rules are in `faults()`.
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
    /// The key's name on screen. Missing means Windfall's own.
    let title: String?
    /// Whose key it is, when it is not Windfall's own.
    let credit: Credit?
    /// True for a stand-in, written by Claude to try the screens with,
    /// which must never be mistaken for anyone's real key.
    let sample: Bool?
    /// The first step's id.
    let start: String
    /// The answer that "None of these fit" leads to, from any step.
    let noneOfThese: String
    /// One line shown under every answer.
    let footer: String
    let steps: [Step]
    let results: [Answer]

    /// Whose key it is, and what he agreed to.
    struct Credit: Decodable, Hashable {
        /// "John Wright".
        let author: String
        /// Where the key comes from: a book or a website.
        let work: String
        /// A web address for the original.
        let link: String?
        /// What the author agreed to, in a line, with the date.
        let terms: String?
        /// True only once the author has said his verdicts on eating may
        /// be shown. Missing counts as false.
        let verdictsAllowed: Bool?
    }

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
        /// The author's own verdict on eating, in his words. Only in a
        /// key that is someone else's, and shown only when he has
        /// allowed it and William has switched it on.
        let verdict: String?
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
    static let shared: FungusKey? = FungusKeys.load(FungusKeys.ownFile)

    var isChecked: Bool { checked ?? false }

    /// True for a sample written by Claude to try the screens.
    var isSample: Bool { sample ?? false }

    /// True for Windfall's own key, which credits nobody.
    var isOwn: Bool { credit == nil }

    /// The key's name: "Windfall's fungus key" unless the file gives one.
    var displayTitle: String { title ?? FungusKeys.ownTitle }

    /// True when this key's verdicts may be shown at all. The switch on
    /// the Identify page decides whether they are.
    var mayShowVerdicts: Bool { !isOwn && (credit?.verdictsAllowed ?? false) }

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
        // The verdicts are not among the pieces, so this holds for
        // every key: outside a verdict the word never appears.
        if words.contains("edible") { found.append("the word \"edible\" is in the key") }

        // Verdicts belong only to someone else's key, and only with his
        // leave. A verdict in Windfall's own key, or one he has not
        // allowed, is a fault, so a slip cannot reach a screen.
        let withVerdicts = results.filter { $0.verdict != nil }.map(\.id)
        if !withVerdicts.isEmpty {
            if isOwn {
                found.append("Windfall's own key gives a verdict at \(withVerdicts.joined(separator: ", "))")
            } else if !mayShowVerdicts {
                found.append("verdicts are in the file but the author has not allowed them")
            }
        }
        // A sample must say so, and must not borrow a real author's name.
        if isSample && credit?.author != FungusKeys.sampleAuthor {
            found.append("a sample must be credited to \"\(FungusKeys.sampleAuthor)\"")
        }
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

    /// A walk that opens part-way in, with no trail behind it. Only the
    /// checking aid `-demoFungus` uses this, to show one step or answer.
    init(start: String, openingAt place: String) {
        self.start = start
        here = place
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
    /// how the name was reached and through which key.
    func note(reaching answer: FungusKey.Answer, keyName: String = FungusKeys.ownTitle) -> String {
        var lines = ["\(keyName) led to: \(answer.name)" + (answer.latin.isEmpty ? "." : " (\(answer.latin)).")]
        if !taken.isEmpty {
            lines.append("Steps: " + taken.map(\.choice).joined(separator: " › "))
        }
        lines.append("A key gives a group, not a certain name. Not checked by anyone who knows fungi.")
        return lines.joined(separator: "\n")
    }
}

// MARK: - The keys in the app

/// Which keys the app offers, and where their files are.
///
/// An `enum` with no cases is a name to hang shared things on. Nothing
/// can be made from it, only its `static` values and functions used.
enum FungusKeys {

    /// Windfall's own key, which travels with the code.
    static let ownFile = "FungusKey"
    /// John Wright's key, if he says yes. Kept in Windfall/PrivateKeys,
    /// which git leaves out, so it is only ever in the app on the Mac
    /// and William's own devices.
    static let wrightFile = "WrightFungusKey"
    /// A stand-in in the shape of a key that goes to species, written by
    /// Claude, shown only while there is no file of Wright's.
    static let sampleFile = "SampleFungusKey"

    static let ownTitle = "Windfall's fungus key"
    /// What a sample's credit must say, so it is never taken for a real key.
    static let sampleAuthor = "Sample written by Claude"

    /// One key on the shelf. `id` is its file name, which is all a
    /// screen needs to tell two apart.
    struct Shelved: Identifiable {
        let id: String
        let key: FungusKey
    }

    /// The keys to offer, in order: Windfall's own, then Wright's if his
    /// file is in the app, otherwise the sample. `loading` reads a file
    /// by name. The app passes one that reads from its own package; the
    /// tests pass one that reads from a list, so they need no files.
    static func shelf(loading: (String) -> FungusKey?) -> [Shelved] {
        var keys: [Shelved] = []
        if let own = loading(ownFile) { keys.append(Shelved(id: ownFile, key: own)) }
        if let wright = loading(wrightFile) {
            keys.append(Shelved(id: wrightFile, key: wright))
        } else if let sample = loading(sampleFile), sample.isSample {
            keys.append(Shelved(id: sampleFile, key: sample))
        }
        return keys
    }

    /// Reads a key that travels inside the app, by its file name.
    static func load(_ name: String) -> FungusKey? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return FungusKey(data: data)
    }

    /// The keys in this copy of the app, read once and then kept.
    ///
    /// The files are read here first and only then handed to `shelf`.
    /// Passing `load` itself would hand a main-thread function to code
    /// that does not promise to stay on the main thread, which Swift
    /// warns about.
    static let inApp: [Shelved] = {
        var files: [String: FungusKey] = [:]
        for name in [ownFile, wrightFile, sampleFile] { files[name] = load(name) }
        return shelf(loading: { files[$0] })
    }()

    /// The key with this file name, if the app has it.
    static func key(named name: String) -> FungusKey? {
        inApp.first { $0.id == name }?.key
    }
}
