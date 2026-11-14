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
    private var showing: [(id: UUID, sight: EiraSight)] = []

    /// The screen on top, if any screen has described itself.
    var current: EiraSight? { showing.last?.sight }

    /// A screen has appeared, or what it shows has changed.
    func show(_ sight: EiraSight, id: UUID) {
        showing.removeAll { $0.id == id }
        showing.append((id: id, sight: sight))
    }

    /// A screen has gone.
    func hide(id: UUID) {
        showing.removeAll { $0.id == id }
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
