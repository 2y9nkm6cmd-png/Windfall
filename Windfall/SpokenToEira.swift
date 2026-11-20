//
//  SpokenToEira.swift
//  Windfall
//
//  The words Siri, Shortcuts or the Action Button hand to Eira's bar,
//  made ready so the bar's own rules read them as meant. Built
//  20 November 2026 (knowledge base docs 120, use 5, and 138).
//
//  Every way in (WindfallIntents.swift) puts words in Eira's bar exactly
//  as if they had been typed there. So "show me bed 3" opens the page
//  (EiraOpenPage.swift), "I need to lift the dahlias" offers a job card
//  that saves nothing until Add is pressed (GardenJobs.swift), and
//  anything else is asked of Eira. Nothing in this file saves or opens
//  anything: it only tidies the words.
//
//  It is kept apart from the intents, which need Apple's AppIntents
//  framework, so the logic tests can check it.
//

import Foundation

enum SpokenToEira {

    /// "Bed 3" said to "Open a page" becomes "show me Bed 3", which the
    /// open-page rule reads. Words that already start with a word for
    /// opening ("open the journal") are left as they are.
    static func forOpening(_ page: String) -> String {
        let said = page.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !said.isEmpty else { return "" }
        if EiraOpenRule.asked(in: said) != nil { return said }
        return "show me " + said
    }

    /// "Lift the dahlias" said to "Add a job" becomes "I need to lift
    /// the dahlias", which the job rule reads as something to do. Words
    /// the job rule already reads as a job are left as they are, so
    /// "Sow the broad beans on Saturday" keeps its own shape.
    static func forJob(_ job: String, today: Date = .now) -> String {
        var said = job.trimmingCharacters(in: .whitespacesAndNewlines)
        // A question mark would make the job rule read it as a question.
        while said.hasSuffix("?") || said.hasSuffix(".") { said.removeLast() }
        guard !said.isEmpty else { return "" }
        if GardenJobs.offer(in: said, today: today) != nil { return said }
        let first = said.prefix(1).lowercased() + said.dropFirst()
        return "I need to " + first
    }
}
