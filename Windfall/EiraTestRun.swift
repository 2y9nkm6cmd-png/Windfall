//
//  EiraTestRun.swift
//  Windfall
//
//  A checking aid. It puts a list of questions to Eira with nobody at
//  the keyboard and writes her answers to a file.
//
//  Why it exists. Choosing Eira's model by feel does not work: one model
//  sounds better and then invents a Latin name. The test sheet
//  (docs/eira-test-questions.md) fixes the questions. This asks them the
//  same way of every model, through the very code the chat screen uses:
//  the fixed safety replies, the lookups and the corrections.
//
//  It only runs when the app is started from Terminal with all three of:
//
//    -demoGarden YES        the example garden, held in memory, so your
//                           real records are never read or changed
//    -eiraTest <file>       the questions, one to a line
//    -eiraTestOut <file>    where to write the answers
//
//  Write "-demoGarden YES", not "-demoGarden" alone. On a Mac every
//  dashed word here must be followed by a value. Otherwise the file path
//  after it is left unpaired, the Mac takes it for a document to open,
//  and the app starts without its window, so nothing runs. (Found the
//  hard way on 13 November 2026.)
//
//  The model is whichever one Eira is set to use. To try another without
//  changing that setting, add for example:
//
//    -eiraModelKind coreAI -eiraModelValue qwen3_8b_4bit_dynamic
//
//  A word after a dash on the command line is read as a setting for that
//  one run only. Nothing is saved.
//
//  The questions file:
//
//    A1 | How long do I water-bath my beans?    a label, a bar, a question
//    What visits marjoram?                       or a question on its own
//    correct: My lavender is English lavender.   puts the last reply right
//    # a line starting with a hash is ignored
//
//  Each question starts a new conversation, as the test sheet asks.
//

import Foundation
import SwiftData
#if os(macOS)
import AppKit
#endif

// MARK: - Reading the questions file

/// One line of the questions file, once understood.
enum EiraTestStep: Equatable {
    /// Ask this in a new conversation. The label is how it is headed in
    /// the answers file, such as "A1".
    case ask(label: String, question: String)
    /// Tell Eira her last reply was wrong, and what is right.
    case correct(String)
}

enum EiraTestSheet {

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

            if line.lowercased().hasPrefix("correct:") {
                let words = line.dropFirst("correct:".count).trimmingCharacters(in: .whitespaces)
                if !words.isEmpty { steps.append(.correct(words)) }
                continue
            }

            asked += 1
            // "A1 | question" carries its own label. A bare question is
            // numbered Q1, Q2 and so on.
            if let bar = line.range(of: " | ") {
                let label = line[..<bar.lowerBound].trimmingCharacters(in: .whitespaces)
                let question = line[bar.upperBound...].trimmingCharacters(in: .whitespaces)
                if question.isEmpty { asked -= 1; continue }
                steps.append(.ask(label: label.isEmpty ? "Q\(asked)" : label, question: question))
            } else {
                steps.append(.ask(label: "Q\(asked)", question: line))
            }
        }
        return steps
    }

    /// A long piece of text cut to its first `limit` characters, on one
    /// line, for the answers file.
    nonisolated static func shortened(_ text: String, limit: Int) -> String {
        let oneLine = text.replacingOccurrences(of: "\n", with: " ")
        return oneLine.count > limit ? String(oneLine.prefix(limit)) + "…" : oneLine
    }
}

// MARK: - Running them

@MainActor
enum EiraTestRun {

    /// How long one answer may take before it is stopped, in seconds.
    static let patience: TimeInterval = 240

    /// The word that follows `flag` on the command line, if there is one.
    private static func word(after flag: String) -> String? {
        let all = ProcessInfo.processInfo.arguments
        guard let index = all.firstIndex(of: flag), index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    /// Runs the questions file if the app was started with one, then
    /// closes the app. Does nothing at all otherwise.
    static func runIfAsked(context: ModelContext) async {
        guard DemoGarden.isRequested,
              let questionsFile = word(after: "-eiraTest"),
              let answersFile = word(after: "-eiraTestOut") else { return }

        let choice = EiraModelChoice.load()
        var lines: [String] = []
        // Written out after every step, so the file can be watched as it
        // grows and still holds what was done if the app is stopped.
        func note(_ line: String) {
            lines.append(line)
            try? lines.joined(separator: "\n").write(toFile: answersFile, atomically: true, encoding: .utf8)
        }

        note("# Eira test run\n")
        note("- Model: \(choice.displayName) (\(choice.kind.displayName))")
        note("- Began: \(Date.now.formatted(date: .abbreviated, time: .standard))")

        guard let text = try? String(contentsOfFile: questionsFile, encoding: .utf8) else {
            note("\nSTOPPED: the questions file could not be read at \(questionsFile)")
            close()
            return
        }
        let steps = EiraTestSheet.steps(from: text)

        // The same three parts the chat screen puts together.
        let hub = EiraToolHub(context: context)
        let conversation = EiraConversation()
        let began = Date.now
        do {
            let engine = try await EiraEngineFactory.make(choice: choice, hub: hub)
            conversation.configure(engine: engine, hub: hub, store: EiraChatStore(context: context))
        } catch {
            note("\nSTOPPED: Eira could not start. \(error.localizedDescription)")
            close()
            return
        }
        note(String(format: "- Engine made in %.1f seconds (the model itself loads on the first question)",
                    Date.now.timeIntervalSince(began)))

        for step in steps {
            switch step {

            case .correct(let words):
                if let last = conversation.messages.last(where: { $0.role == .assistant }) {
                    conversation.correct(last, with: words)
                    note("\n**Put right with:** \(words)")
                }

            case .ask(let label, let question):
                conversation.clear()
                note("\n## \(label)\n")
                note("**Asked:** \(question)\n")

                let isFixed = EiraSafety.fixedReply(to: question) != nil
                let askedAt = Date.now
                conversation.send(question)

                // Wait for the reply, looking ten times a second.
                var wasStopped = false
                while conversation.isGenerating {
                    let waited = Date.now.timeIntervalSince(askedAt)
                    if waited > patience, !wasStopped {
                        conversation.stop()
                        wasStopped = true
                    }
                    // A stop that is not obeyed must not hang the run.
                    if waited > patience + 30 { break }
                    try? await Task.sleep(for: .milliseconds(100))
                }
                let took = Date.now.timeIntervalSince(askedAt)

                for message in conversation.messages where message.role == .tool {
                    note("**Looked up** with \(message.toolName ?? "a tool"): "
                         + EiraTestSheet.shortened(message.content, limit: 300) + "\n")
                }
                let reply = conversation.messages.last(where: { $0.role == .assistant })
                if let thinking = reply?.reasoning, !thinking.isEmpty {
                    note("**Thought first** (\(thinking.count) characters): "
                         + EiraTestSheet.shortened(thinking, limit: 300) + "\n")
                }
                note("**Answer**" + (isFixed ? " (fixed wording, the model was not asked)" : "") + ":\n")
                note((reply?.content.isEmpty == false ? reply!.content : "(nothing came back)") + "\n")

                var timing = String(format: "**Took:** %.1f seconds", took)
                if let figures = conversation.lastMetrics?.summary, !figures.isEmpty {
                    timing += " · " + figures
                }
                if wasStopped { timing += " · STOPPED after \(Int(patience)) seconds" }
                note(timing)
                if let problem = conversation.lastError {
                    note("\n**Error:** \(problem)")
                }
            }
        }

        note("\n- Finished: \(Date.now.formatted(date: .abbreviated, time: .standard))")
        note("\nDONE")
        close()
    }

    /// Closes the app, so whatever started the run knows it is over.
    private static func close() {
        #if os(macOS)
        NSApplication.shared.terminate(nil)
        #endif
    }
}
