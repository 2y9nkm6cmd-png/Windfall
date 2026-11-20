//
//  WindfallIntents.swift
//  Windfall
//
//  Siri, Shortcuts, Spotlight and the Action Button (knowledge base doc
//  120, use 5; built 20 November 2026, doc 138).
//
//  Apple's AppIntents framework lets an app offer actions the rest of
//  the system can run. Each action is an "intent": a small type with a
//  title, its inputs (each a `@Parameter`) and a `perform()` that does
//  the work. An `AppShortcutsProvider` lists the ones Siri should know
//  by spoken phrases, with no setting up: "Add a job in Windfall".
//
//  All three here do the same thing in the end: open Windfall and hand
//  the words to Eira's bar, as if typed there (EiraHandoff, below). The
//  bar's own rules then decide, in the same order as ever: a page to
//  open, a job (its card saves nothing until Add is pressed), news for
//  the journal, or a question for Eira. So nothing reaches the records
//  without the same card and the same Add as by hand.
//
//  The Action Button (iPhone 15 Pro and later, and some iPads) runs a
//  shortcut chosen in the device's Settings, Action Button, Shortcut:
//  any of these three can be chosen there.
//
//  New things here:
//
//  @Parameter          An input to an intent. If it is not given, Siri
//                      asks for it with `requestValueDialog`.
//  openAppWhenRun      Brings Windfall to the front before `perform()`.
//  \(.applicationName) In a phrase, the app's name, which Apple requires
//                      in every spoken phrase so Siri knows which app.
//

import AppIntents
import Foundation
import Observation

/// Words handed from Siri or Shortcuts to Eira's bar, held until the bar
/// takes them. The same pattern as `WidgetRoute` (WidgetShare.swift).
@Observable
final class EiraHandoff {
    static let shared = EiraHandoff()

    /// The words waiting, or nil.
    private(set) var pending: String?

    func hand(_ words: String) {
        let trimmed = words.trimmingCharacters(in: .whitespacesAndNewlines)
        pending = trimmed.isEmpty ? nil : trimmed
    }

    /// The bar takes them. Handed over once and then gone, so two
    /// windows on a Mac never both act on the same words.
    func take() -> String? {
        let waiting = pending
        pending = nil
        return waiting
    }
}

/// "Open a page in Windfall": "Bed 3", "the journal", "Apple Spartan".
struct OpenInWindfallIntent: AppIntent {
    static let title: LocalizedStringResource = "Open a page in Windfall"
    static let description = IntentDescription("Opens a bed, plant, garden, animal or place in Windfall by its name, as \"show me…\" does in Eira's bar.")
    static let openAppWhenRun = true

    @Parameter(title: "Page", requestValueDialog: "Which page? For example, Bed 3 or the journal.")
    var page: String

    @MainActor
    func perform() async throws -> some IntentResult {
        EiraHandoff.shared.hand(SpokenToEira.forOpening(page))
        return .result()
    }
}

/// "Add a job in Windfall": "lift the dahlias on Saturday".
struct AddJobIntent: AppIntent {
    static let title: LocalizedStringResource = "Add a garden job"
    static let description = IntentDescription("Offers a job card in Windfall, filled in from what you say. Nothing is added until you press Add.")
    static let openAppWhenRun = true

    @Parameter(title: "Job", requestValueDialog: "What is the job?")
    var job: String

    @MainActor
    func perform() async throws -> some IntentResult {
        EiraHandoff.shared.hand(SpokenToEira.forJob(job))
        return .result()
    }
}

/// "Tell Eira in Windfall": anything, handled as if typed in her bar.
struct TellEiraIntent: AppIntent {
    static let title: LocalizedStringResource = "Tell Eira"
    static let description = IntentDescription("Hands your words to Eira's bar in Windfall, as if typed there: a page to open, a job to add, news for the journal or a question for her.")
    static let openAppWhenRun = true

    @Parameter(title: "Words", requestValueDialog: "What shall I tell Eira?")
    var words: String

    @MainActor
    func perform() async throws -> some IntentResult {
        EiraHandoff.shared.hand(words)
        return .result()
    }
}

/// The phrases Siri knows with no setting up. Each must name the app.
struct WindfallShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AddJobIntent(),
                    phrases: ["Add a job in \(.applicationName)",
                              "Add a garden job in \(.applicationName)"],
                    shortTitle: "Add a job",
                    systemImageName: "checklist")
        AppShortcut(intent: OpenInWindfallIntent(),
                    phrases: ["Open a page in \(.applicationName)",
                              "Show me something in \(.applicationName)"],
                    shortTitle: "Open a page",
                    systemImageName: "arrow.up.forward.app")
        AppShortcut(intent: TellEiraIntent(),
                    phrases: ["Tell Eira in \(.applicationName)",
                              "Ask Eira in \(.applicationName)"],
                    shortTitle: "Tell Eira",
                    systemImageName: "leaf")
    }
}
