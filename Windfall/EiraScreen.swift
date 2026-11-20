//
//  EiraScreen.swift
//  Windfall
//
//  What the gardener is looking at, so that Eira can be told.
//
//  Each screen says what it is showing, in a few words: "the plant Apple
//  (Spartan)". Eira's bar reads the newest one. It changes the hint in
//  the bar, and it is handed to Eira with the question, so that "what
//  grows well beside this?" can mean the plant that is open.
//
//  What this is not: Eira does not see the screen. She is given one short
//  phrase that the screen wrote about itself. She cannot tell which row
//  has been scrolled to, or what a photograph shows.
//
//  The part that screens use, `.eiraLooksAt(...)`, is at the bottom of
//  EiraFloatingBar.swift.
//

import Foundation
import Observation

/// One screen's description of itself.
struct EiraSight: Equatable {
    /// A few words for the hint in Eira's bar, such as "Apple, Spartan".
    /// Nil for a general screen like Today, where the usual hint reads
    /// better.
    var short: String?
    /// The phrase Eira is given, such as "the plant Apple, Spartan".
    var full: String
    /// True for the Journal page. There Eira's bar is for telling her
    /// what happened: it stays open, what is typed is taken as an
    /// entry unless it plainly asks something, and a photo given to
    /// her starts an entry. Added 14 November 2026.
    var isJournal = false
}

extension EiraSight {
    /// A name with its variety, when it has one: "Apple, Spartan".
    static func name(_ name: String, variety: String?) -> String {
        guard let variety, !variety.trimmingCharacters(in: .whitespaces).isEmpty else { return name }
        return "\(name), \(variety)"
    }
}

/// Keeps track of which screen is on top.
///
/// Screens come and go: one is opened on top of another, then closed
/// again. Each registers itself when it appears and removes itself when
/// it goes. The newest one still showing is the one being looked at.
@Observable
final class EiraScreen {

    /// The screens showing now, oldest first. Each has a label of its own
    /// (a UUID, a long random number) so that it can be found again.
    ///
    /// `place` is the tab a screen belongs to, on an iPhone. It is nil
    /// on a Mac or an iPad, where there is one bar for every place.
    private var showing: [(id: UUID, sight: EiraSight, place: String?)] = []

    /// What each tab was last showing, kept from the moment its last
    /// screen goes. See `current(in:)`.
    private var resting: [String: EiraSight] = [:]

    /// The screen on top, if any screen has described itself.
    var current: EiraSight? { showing.last?.sight }

    /// The screen on top in one place.
    ///
    /// An iPhone has a tab for each place and a bar of Eira's on each
    /// tab. Until 15 November 2026 every one of those bars read
    /// `current`, the newest screen anywhere. So when the Journal tab
    /// was chosen, the bar on the tab being left sprang open as the
    /// Journal's bar while its own page was still on screen, and on the
    /// way back the Journal's bar shut before the Journal had gone.
    /// Now each bar asks only about its own tab.
    ///
    /// A tab that is not on screen has no screen showing. Its bar is
    /// told what the tab showed last (`resting`), so the bar is already
    /// right when the tab comes back.
    ///
    /// With no place named, this is the same as `current`.
    func current(in place: String?) -> EiraSight? {
        guard let place else { return current }
        return showing.last(where: { $0.place == place })?.sight ?? resting[place]
    }

    /// A screen has appeared, or what it shows has changed.
    func show(_ sight: EiraSight, id: UUID, place: String? = nil) {
        showing.removeAll { $0.id == id }
        showing.append((id: id, sight: sight, place: place))
    }

    /// A screen has gone.
    func hide(id: UUID) {
        // If it was the last screen showing in its tab, remember it as
        // what that tab holds.
        if let leaving = showing.first(where: { $0.id == id }), let place = leaving.place,
           !showing.contains(where: { $0.place == place && $0.id != id }) {
            resting[place] = leaving.sight
        }
        showing.removeAll { $0.id == id }
    }

    // MARK: Photos on their way to Eira's bar

    /// How far down the window the strip kept clear for Eira's bar
    /// begins, in points from the top of the window. MainTabView
    /// measures it. A page can compare it with where its own foot is,
    /// to find out whether its last lines lie under the bar. Nil until
    /// it has been measured. See `JournalTimelineView.hiddenByBar`.
    var barLine: CGFloat?

    /// Photos a page has been given that belong with Eira's bar, each
    /// as its file's own bytes. The Journal page puts photos dropped on
    /// it here, and the bar picks them up and opens the journal's
    /// conversation in its panel. Until 14 November 2026 the page
    /// opened a sheet of its own for them.
    ///
    /// `private(set)` means any code can read this, and only the two
    /// functions below can change it.
    private(set) var photosForBar: [Data] = []

    /// A page hands photos over for the bar.
    func handToBar(_ photos: [Data]) {
        photosForBar = photos
    }

    /// The bar takes them. They are handed over once and then gone,
    /// so the same photos never start two entries.
    func takePhotosForBar() -> [Data] {
        let photos = photosForBar
        photosForBar = []
        return photos
    }

    /// A question a page wants put to Eira, such as "How and when
    /// should I prune medlar?" from the sheet that fills in a plant's
    /// gaps (PlantFillInViews.swift). The bar picks it up and opens
    /// her chat with it, as if it had been typed there.
    private(set) var questionForBar: String?

    /// A page hands a question over for the bar.
    func ask(_ question: String) {
        questionForBar = question
    }

    /// The bar takes it. Handed over once and then gone, so the same
    /// question is never asked twice.
    func takeQuestionForBar() -> String? {
        let question = questionForBar
        questionForBar = nil
        return question
    }

    /// The sentence that is put in front of a question for the model.
    ///
    /// It says plainly that this is background, because a small model
    /// given a plant's name tends to talk about that plant whatever the
    /// question was.
    static func line(for note: String) -> String {
        "For context, the gardener has this open in the app at the moment: \(note). "
        + "Only use this if the question refers to it, for example with \"this\", \"it\" or \"here\"."
    }
}

// MARK: - The words some pages give Eira

/// The phrases the pages added on 20 November 2026 give Eira about
/// themselves (piece 1 of project doc 119: every page tells her what is
/// open). Most pages pass a fixed phrase straight to `.eiraLooksAt(...)`.
/// The ones that are built from a record live here instead, as plain
/// functions that take words and dates and give back a phrase. Being
/// plain, the logic tests can check them without drawing a screen.
///
/// The phrase is all Eira is told about the page, so it names what the
/// gardener would name: "the sighting of Red Admiral (Vanessa atalanta),
/// seen on 3 August 2026", not the screen's title.
enum EiraPagePhrase {

    /// A date as Eira is given it: "3 August 2026".
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide).year())
    }

    /// Nil for a missing name or one that is only spaces.
    private static func named(_ words: String?) -> String? {
        guard let words else { return nil }
        let trimmed = words.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// One sighting: "the sighting of Red Admiral (Vanessa atalanta),
    /// seen on 3 August 2026". With no name yet: "an unidentified
    /// sighting, seen on ...".
    static func sighting(english: String?, latin: String?, seen: Date) -> String {
        let who: String
        switch (named(english), named(latin)) {
        case let (english?, latin?): who = "the sighting of \(english) (\(latin))"
        case let (english?, nil): who = "the sighting of \(english)"
        case let (nil, latin?): who = "the sighting of \(latin)"
        case (nil, nil): who = "an unidentified sighting"
        }
        return "\(who), seen on \(day(seen))"
    }

    /// A survey that has been kept: "the FIT Count of 3 August 2026, on
    /// Lavender".
    static func survey(scheme: String, started: Date, flower: String?) -> String {
        let base = "the \(scheme) of \(day(started))"
        guard let flower = named(flower) else { return base }
        return "\(base), on \(flower)"
    }

    /// Where a count being made has got to.
    enum CountStage { case settingUp, counting, finished }

    /// A count being made: "a FIT Count under way, on Lavender".
    static func count(scheme: String, stage: CountStage, flower: String?) -> String {
        let state: String
        switch stage {
        case .settingUp: state = "being set up"
        case .counting: state = "under way"
        case .finished: state = "just finished, with its result showing"
        }
        let base = "a \(scheme) \(state)"
        guard let flower = named(flower) else { return base }
        return "\(base), on \(flower)"
    }

    /// One cross: "the cross of Tomato (seed parent) with Gardener's
    /// Delight (pollen parent), made on 3 August 2026".
    static func cross(seedParent: String, pollenParent: String?, made: Date) -> String {
        let seed = named(seedParent) ?? "an unnamed plant"
        let pollen = named(pollenParent).map { "with \($0) (pollen parent)" } ?? "with no pollen parent named"
        return "the cross of \(seed) (seed parent) \(pollen), made on \(day(made))"
    }

    /// The sheet for one of the gardener's own jobs: "the job \"Lift the
    /// dahlias\"", or "a new job being written".
    static func job(title: String?) -> String {
        guard let title = named(title) else { return "a new job being written" }
        return "the job \u{201C}\(title)\u{201D}"
    }

    /// A plant's drawings opened large: "the life stages drawings of the
    /// plant Strawberry".
    static func plantDrawings(card: String, plant: String) -> String {
        let what = named(card).map { "the \($0.lowercased()) drawings" } ?? "the drawings"
        return "\(what) of the plant \(named(plant) ?? "with no name")"
    }
}
