//
//  EiraConversation.swift
//  Windfall
//
//  One conversation with Eira, as the chat screen sees it.
//
//  This is the conductor. It does not run a model and it does not draw
//  anything. It takes what you typed, hands it to the engine, gathers the
//  reply as it streams in, records every lookup, saves each message and
//  keeps the conversation small enough for a small model to follow.
//

import Foundation
import Observation

// MARK: - Keeping a conversation within the model's memory

/// A model can only keep a limited amount of text in mind at once. On a
/// small on-device model that limit is a few pages. Past it, the model
/// forgets its instructions or fails outright.
///
/// So when a conversation grows too long it is condensed: recent turns
/// are kept word for word, older ones are shortened, and old lookups are
/// dropped because their answers have already been used.
enum EiraContext {

    /// Roughly four characters make one token in English.
    static func estimatedTokens(_ text: String) -> Int {
        max(1, text.count / 4)
    }

    static func estimatedTokens(_ messages: [ChatMessage]) -> Int {
        messages.reduce(0) { $0 + estimatedTokens($1.content) }
    }

    /// Room allowed for the conversation itself. The standing
    /// instructions, the tool descriptions and the reply need the rest.
    static let conversationBudgetTokens = 2000

    static func needsCondensing(
        _ messages: [ChatMessage], budget: Int = conversationBudgetTokens
    ) -> Bool {
        estimatedTokens(messages) > budget
    }

    /// A shorter version of a conversation that keeps its thread.
    /// - The last `keepRecent` things said by either side stay in full.
    /// - Older ones are cut to their first `olderLimit` characters.
    /// - Lookups and instructions are left out.
    static func condensed(
        _ messages: [ChatMessage], keepRecent: Int = 4, olderLimit: Int = 240
    ) -> [ChatMessage] {
        let spoken = messages.filter { $0.role == .user || $0.role == .assistant }
        let splitAt = max(0, spoken.count - keepRecent)

        return spoken.enumerated().map { index, message in
            var copy = message
            copy.reasoning = nil
            if index < splitAt, copy.content.count > olderLimit {
                copy.content = String(copy.content.prefix(olderLimit)) + "…"
            }
            return copy
        }
    }

    /// Earlier turns written out as plain text, for handing to a model
    /// that is starting afresh.
    static func historyText(_ messages: [ChatMessage]) -> String {
        messages.compactMap { message -> String? in
            switch message.role {
            case .user:      return "Gardener: \(message.content)"
            case .assistant: return "Eira: \(message.content)"
            case .system, .tool: return nil
            }
        }
        .joined(separator: "\n")
    }
}

// MARK: - The conversation

@Observable
@MainActor
final class EiraConversation {

    /// Everything said so far, including lookups, in order.
    private(set) var messages: [ChatMessage] = []
    private(set) var isGenerating = false
    private(set) var lastMetrics: GenerationMetrics?
    var lastError: String?

    /// The reply as it arrives, before it is finished.
    private(set) var streamingContent = ""
    private(set) var streamingReasoning = ""

    /// The model in use, or nil if Eira is not ready.
    private(set) var modelName: String?
    /// Why Eira cannot run, in plain words, when she cannot.
    private(set) var setupProblem: String?

    /// What the gardener had open when they asked, such as "the plant
    /// Apple, Spartan". Nil when the chat was not opened from a screen
    /// that describes itself, and then nothing changes. See EiraScreen.
    var screenNote: String?

    /// Photos given to Eira in this conversation, each filed under the
    /// id of the message it came with. They are kept only while the
    /// chat is open: a photo is saved when you start a sighting from
    /// it, and not before.
    private(set) var photos: [UUID: Data] = [:]
    /// What she made of each photo, filed under the id of her reply.
    /// The chat screen draws a reply that has one as a card.
    private(set) var identifications: [UUID: EiraIdentification] = [:]
    /// Which photo each of those replies was about: the reply's id,
    /// then the id of the message the photo came with.
    private(set) var photoBehind: [UUID: UUID] = [:]
    /// True from a photo being given until her answer to it.
    private(set) var isLooking = false

    /// What your message says when you give her a photo.
    static let photoQuestion = "What is this? (A photo.)"
    /// The label kept with her answer to a photo, so a saved
    /// conversation shows where that answer came from.
    static let photoAnswerLabel = "identify_photo"

    private var engine: EiraEngine?
    private var hub: EiraToolHub?
    private var store: EiraChatStore?
    private var chat: EiraChat?
    private var replyTask: Task<Void, Never>?
    /// Set when the engine must begin again with fresh instructions.
    private var needsRestart = true

    // MARK: Setting up

    /// Gives the conversation an engine to talk to and somewhere to save.
    func configure(engine: EiraEngine, hub: EiraToolHub, store: EiraChatStore) {
        self.engine?.unload()
        self.engine = engine
        self.hub = hub
        self.store = store
        self.modelName = engine.displayName
        self.setupProblem = nil
        self.needsRestart = true

        hub.onToolUse = { [weak self] name, result in
            self?.record(ChatMessage(role: .tool, content: result, toolName: name))
        }
        if chat == nil { chat = store.newChat(modelName: engine.displayName) }
    }

    /// Records that Eira cannot run here, and why.
    func setUnavailable(_ reason: String) {
        engine?.unload()
        engine = nil
        modelName = nil
        setupProblem = reason
    }

    // MARK: Talking

    /// Sends a message. `forcedTool` runs a lookup first whether or not
    /// the model would have thought to, because small models are
    /// unreliable at deciding when to look something up.
    ///
    /// `subject` is what that lookup is given to look for, when it is
    /// not the whole message. "Tell me about Buff-tailed Bumblebee
    /// (Bombus terrestris)." is the message, and "Bombus terrestris" is
    /// what to look up. Added 14 November 2026, for asking about a
    /// species Eira has just named from a photo.
    func send(_ text: String, forcedTool: ToolDefinition? = nil, about subject: String? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard engine != nil, !trimmed.isEmpty, !isGenerating, !isLooking else { return }

        // The reply before this message, if there is one. Read now,
        // before the message itself joins the list.
        let replyBefore = messages.last { $0.role == .assistant }
        let sent = ChatMessage(role: .user, content: trimmed)
        record(sent)
        // An offer from an earlier message that was never answered goes.
        offeredCorrection = nil

        // Some questions are answered by fixed wording and never reach the
        // model. See EiraSafety for why. Nothing said on one of these
        // subjects is offered for keeping as a correction.
        if let safety = EiraSafety.safetyReply(to: trimmed) {
            answerWithFixedWording(safety)
            return
        }

        // If this message puts her last reply right, offer to keep it.
        // The chat screen shows the offer as a card under the message.
        // The message is still sent, so she answers it as well. See
        // EiraChecks.correctionWords.
        if let replyBefore, let fact = EiraChecks.correctionWords(in: trimmed, answering: replyBefore.content) {
            offeredCorrection = OfferedCorrection(messageID: sent.id, replyID: replyBefore.id, words: fact)
        }

        // Asked to save something. The chat cannot change your records,
        // but a correction it can keep, once you press the button.
        if EiraSafety.asksToSaveARecord(trimmed) {
            answerWithFixedWording(offeredCorrection == nil ? EiraSafety.savingReply : EiraChecks.correctionNotKeptYet)
            return
        }

        isGenerating = true
        streamingContent = ""
        streamingReasoning = ""
        lastError = nil

        // A lookup chosen by hand comes first. Otherwise a fixed rule
        // may choose one: see EiraChecks.lookupFirst.
        let lookup = forcedTool ?? EiraChecks.lookupFirst(for: trimmed)

        replyTask = Task { [weak self] in
            await self?.generate(for: trimmed, forcedTool: lookup, about: subject)
        }
    }

    // MARK: Photos

    /// Takes a photo into the conversation as a message of yours.
    ///
    /// Returns that message's id, which is handed back with the answer
    /// so the two stay together. Returns nil, and does nothing, if she
    /// is busy with a reply or with another photo.
    ///
    /// Naming a photo does not need Eira's text model. The image model
    /// does the matching and fixed rules do the judging (EiraIdentify),
    /// so this works even when no text model can run on the device.
    /// The screen runs the image model between this call and the next,
    /// because that part needs Apple's frameworks and this file is
    /// tested without them.
    @discardableResult
    func givePhoto(_ data: Data) -> UUID? {
        guard !isGenerating, !isLooking else { return nil }
        let words = EiraConversation.photoQuestion
        let photoMessage = ChatMessage(role: .user, content: words)
        record(photoMessage)
        offeredCorrection = nil
        photos[photoMessage.id] = data
        isLooking = true
        lastError = nil
        return photoMessage.id
    }

    /// Her answer to a photo. It joins the conversation in words, so
    /// the text model has it in front of it when you ask a follow-up,
    /// and the screen draws it as a card.
    func answerPhoto(_ photoID: UUID, with identification: EiraIdentification) {
        let label = EiraConversation.photoAnswerLabel
        let photoReply = ChatMessage(role: .assistant, content: identification.spoken, toolName: label)
        identifications[photoReply.id] = identification
        photoBehind[photoReply.id] = photoID
        record(photoReply)
        isLooking = false
        lastMetrics = nil
        // The model did not see this exchange, so it is handed the
        // conversation afresh before its next reply.
        needsRestart = true
    }

    /// Says why a photo could not be looked at.
    func photoFailed(_ words: String) {
        record(ChatMessage(role: .assistant, content: words))
        isLooking = false
        lastMetrics = nil
        needsRestart = true
    }

    /// A checking aid: puts an example photo exchange on screen, so a
    /// still picture can be taken of the card where the image model
    /// cannot run. There is no photo behind it. See DemoGarden.opens.
    func showExamplePhoto(answeredBy identification: EiraIdentification) {
        guard let photoID = givePhoto(Data()) else { return }
        answerPhoto(photoID, with: identification)
    }

    /// Forgets the photos, at the start of another conversation.
    private func forgetPhotos() {
        photos = [:]
        identifications = [:]
        photoBehind = [:]
        isLooking = false
    }

    /// Replies with wording fixed in the app. The model is not asked.
    private func answerWithFixedWording(_ wording: String) {
        record(ChatMessage(role: .assistant, content: wording))
        lastMetrics = nil
        // The model did not see this exchange, so it is handed the
        // conversation afresh before its next reply.
        needsRestart = true
    }

    /// Stops the reply in progress. What has arrived so far is kept.
    func stop() {
        replyTask?.cancel()
    }

    private func generate(for text: String, forcedTool: ToolDefinition?, about subject: String? = nil) async {
        guard let engine else { isGenerating = false; return }
        defer {
            isGenerating = false
            replyTask = nil
        }

        prepareEngineIfNeeded(engine)

        var prompt = text
        if let forcedTool, let hub {
            // What to look for: the subject if one was given, and
            // otherwise the whole message.
            let wanted = subject ?? text
            let arguments = EiraToolHub.json(["name": wanted, "query": wanted, "plant": wanted, "url": wanted])
            let result = await hub.run(name: forcedTool.name, argumentsJSON: arguments)
            prompt = """
            The app has already looked this up for you with \(forcedTool.name):
            \(result)

            Using that, answer: \(text)
            """
        }

        // Tell the model what is open on screen, if anything. Only the
        // model sees this line. The conversation on screen, and what is
        // saved, keep the question exactly as it was typed.
        if let screenNote, !screenNote.isEmpty {
            prompt = EiraScreen.line(for: screenNote) + "\n\n" + prompt
        }

        do {
            let metrics = try await engine.reply(to: prompt) { [weak self] event in
                guard let self else { return }
                switch event {
                case .reasoning(let piece):
                    self.streamingReasoning += piece
                case .content(let piece):
                    self.streamingContent += piece
                case .toolResult(let name, let result):
                    self.record(ChatMessage(role: .tool, content: result, toolName: name))
                case .finished:
                    break
                }
            }
            lastMetrics = metrics
            commitReply(stopped: false)
        } catch is CancellationError {
            commitReply(stopped: true)
        } catch {
            // A stop can also surface as some other error from the model.
            if Task.isCancelled {
                commitReply(stopped: true)
            } else {
                commitReply(stopped: false)
                lastError = error.localizedDescription
                // The engine's own memory may now disagree with ours.
                needsRestart = true
            }
        }
    }

    /// Starts the engine's conversation afresh when instructions have
    /// changed or the conversation has outgrown the model's memory.
    private func prepareEngineIfNeeded(_ engine: EiraEngine) {
        // The message just sent is the last one. Everything before it is history.
        let earlier = Array(messages.dropLast())
        let tooLong = EiraContext.needsCondensing(earlier)
        guard needsRestart || tooLong else { return }

        let corrections = store?.recentCorrectionLines() ?? []
        let instructions = EiraPrompt.build(corrections: corrections)
        engine.startConversation(instructions: instructions,
                                 history: EiraContext.condensed(earlier))
        needsRestart = false
    }

    /// Turns the streamed pieces into a finished message.
    private func commitReply(stopped: Bool) {
        var content = streamingContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let reasoning = streamingReasoning.trimmingCharacters(in: .whitespacesAndNewlines)
        streamingContent = ""
        streamingReasoning = ""
        guard !content.isEmpty || !reasoning.isEmpty else { return }

        // Read the finished reply by rule before it is shown or saved.
        // A reply you stopped yourself is left exactly as it was.
        // See EiraChecks.
        if !stopped {
            let asked = messages.lastIndex { $0.role == .user }
            let question = asked.map { messages[$0].content } ?? ""
            let lookups = asked.map { index in
                messages[(index + 1)...].filter { $0.role == .tool }.map(\.content)
            } ?? []
            let known = [EiraGardenNotes.load(), screenNote ?? ""] + (store?.recentCorrectionLines() ?? [])
            // Was the question a correction, and has it been kept yet?
            var standing = EiraChecks.CorrectionStanding.notACorrection
            if let offer = offeredCorrection {
                standing = offer.isKept ? .kept : .waiting
            }
            content = EiraChecks.checked(reply: content, question: question, lookups: lookups, known: known,
                                         correction: standing)
        }

        record(ChatMessage(
            role: .assistant,
            content: stopped && !content.isEmpty ? content + " (stopped)" : content,
            reasoning: reasoning.isEmpty ? nil : reasoning))
    }

    /// Adds a message to the screen and saves it.
    private func record(_ message: ChatMessage) {
        messages.append(message)
        guard let store, let chat else { return }
        // If saving fails, say so on screen. A conversation that quietly
        // is not being kept is worse than an error message.
        if let problem = store.append(message, to: chat) {
            lastError = "This conversation could not be saved: \(problem)"
        }
    }

    // MARK: Starting over and going back

    /// Begins a new, empty conversation.
    func clear() {
        stop()
        messages = []
        streamingContent = ""
        streamingReasoning = ""
        lastMetrics = nil
        lastError = nil
        offeredCorrection = nil
        forgetPhotos()
        chat = store?.newChat(modelName: modelName)
        needsRestart = true
    }

    /// Reopens a saved conversation so it can be continued.
    func open(_ saved: EiraChat) {
        stop()
        chat = saved
        messages = saved.orderedMessages.map(\.asChatMessage)
        streamingContent = ""
        streamingReasoning = ""
        lastMetrics = nil
        lastError = nil
        offeredCorrection = nil
        forgetPhotos()
        needsRestart = true
    }

    // MARK: Being put right

    /// A correction typed as an ordinary message, waiting for the
    /// gardener to say whether to keep it.
    struct OfferedCorrection {
        /// Your message. The card sits under it.
        let messageID: ChatMessage.ID
        /// The reply of Eira's that it puts right.
        let replyID: ChatMessage.ID
        /// The fact as it was read from your message.
        let words: String
        /// What it was saved as, once "Keep it" has been pressed.
        var keptAs: EiraCorrection?

        var isKept: Bool { keptAs != nil }
    }

    /// Set by `send` when a message reads as a correction. Nothing is
    /// kept until `keepOfferedCorrection`.
    private(set) var offeredCorrection: OfferedCorrection?

    /// Keeps the offered correction, exactly as "Correct this" would.
    /// `words` is the fact as it stands on the card, which you may have
    /// reworded there.
    func keepOfferedCorrection(as words: String) {
        guard let offer = offeredCorrection, !offer.isKept,
              let reply = messages.first(where: { $0.id == offer.replyID }) else { return }
        offeredCorrection?.keptAs = correct(reply, with: words)
    }

    /// Takes back a correction kept from the card, and offers it again.
    func undoKeptCorrection() {
        guard let saved = offeredCorrection?.keptAs else { return }
        store?.remove(saved)
        offeredCorrection?.keptAs = nil
        needsRestart = true
    }

    /// Takes the card away without keeping anything.
    func dismissOfferedCorrection() {
        offeredCorrection = nil
    }

    /// Records that one of Eira's replies was wrong, and what is right.
    /// The correction is read at the start of every later conversation.
    /// Returns what was saved, or nil if nothing was.
    @discardableResult
    func correct(_ message: ChatMessage, with correction: String) -> EiraCorrection? {
        guard let store else { return nil }
        let question = messages
            .prefix { $0.id != message.id }
            .last { $0.role == .user }?.content ?? ""
        let saved = store.addCorrection(topic: question, mistake: message.content, correction: correction)
        // So the correction applies from the very next message.
        needsRestart = true
        return saved
    }

    /// A checking aid: fills the conversation with an example exchange
    /// in which Eira is put right, so a still picture can be taken of the
    /// card that offers to keep the correction. No model is asked. With
    /// `kept`, the correction is kept too, and an older one beside it,
    /// for a picture of the list. Only ever called for the example
    /// garden, whose records live in memory. See DemoGarden.opens.
    func showExample(in store: EiraChatStore, kept: Bool) {
        if self.store == nil { self.store = store }
        let exampleQuestion = ChatMessage(role: .user, content: "Which apple is the tree by the shed?")
        let exampleReply = ChatMessage(role: .assistant, content: "The apple by the shed is a Spartan, an eating apple that is picked in October.")
        let puttingRight = ChatMessage(role: .user, content: "No, that's wrong. It's a Bramley, a cooking apple.")
        let standing = kept ? EiraChecks.correctionKept : EiraChecks.correctionNotKeptYet
        let exampleAnswer = ChatMessage(role: .assistant, content: "Thank you. A Bramley is a cooking apple and keeps well into the new year.\n\n" + standing)
        messages = [exampleQuestion, exampleReply, puttingRight, exampleAnswer]
        let fact = EiraChecks.correctionWords(in: puttingRight.content) ?? puttingRight.content
        offeredCorrection = OfferedCorrection(messageID: puttingRight.id, replyID: exampleReply.id, words: fact)
        if kept {
            store.addCorrection(topic: "When should I prune the lavender?",
                                mistake: nil, correction: "My lavender is English lavender, not Dutch.")
            keepOfferedCorrection(as: offeredCorrection?.words ?? "")
        }
    }

    /// Every correction kept so far, newest first. For the list in the
    /// chat's Options menu.
    func corrections() -> [EiraCorrection] {
        store?.corrections() ?? []
    }

    /// Removes a correction for good, from the list of them.
    func remove(_ correction: EiraCorrection) {
        store?.remove(correction)
        // If it was the one just kept from a card, the card goes too.
        if offeredCorrection?.keptAs === correction { offeredCorrection = nil }
        // Her instructions held it, so they are written afresh.
        needsRestart = true
    }
}
