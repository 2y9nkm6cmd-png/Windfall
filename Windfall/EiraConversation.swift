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
    func send(_ text: String, forcedTool: ToolDefinition? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard engine != nil, !trimmed.isEmpty, !isGenerating else { return }

        record(ChatMessage(role: .user, content: trimmed))
        isGenerating = true
        streamingContent = ""
        streamingReasoning = ""
        lastError = nil

        replyTask = Task { [weak self] in
            await self?.generate(for: trimmed, forcedTool: forcedTool)
        }
    }

    /// Stops the reply in progress. What has arrived so far is kept.
    func stop() {
        replyTask?.cancel()
    }

    private func generate(for text: String, forcedTool: ToolDefinition?) async {
        guard let engine else { isGenerating = false; return }
        defer {
            isGenerating = false
            replyTask = nil
        }

        prepareEngineIfNeeded(engine)

        var prompt = text
        if let forcedTool, let hub {
            let arguments = EiraToolHub.json(["name": text, "query": text, "plant": text, "url": text])
            let result = await hub.run(name: forcedTool.name, argumentsJSON: arguments)
            prompt = """
            The app has already looked this up for you with \(forcedTool.name):
            \(result)

            Using that, answer: \(text)
            """
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
        let content = streamingContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let reasoning = streamingReasoning.trimmingCharacters(in: .whitespacesAndNewlines)
        streamingContent = ""
        streamingReasoning = ""
        guard !content.isEmpty || !reasoning.isEmpty else { return }

        record(ChatMessage(
            role: .assistant,
            content: stopped && !content.isEmpty ? content + " (stopped)" : content,
            reasoning: reasoning.isEmpty ? nil : reasoning))
    }

    /// Adds a message to the screen and saves it.
    private func record(_ message: ChatMessage) {
        messages.append(message)
        if let store, let chat { store.append(message, to: chat) }
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
        needsRestart = true
    }

    // MARK: Being put right

    /// Records that one of Eira's replies was wrong, and what is right.
    /// The correction is read at the start of every later conversation.
    func correct(_ message: ChatMessage, with correction: String) {
        guard let store else { return }
        let question = messages
            .prefix { $0.id != message.id }
            .last { $0.role == .user }?.content ?? ""
        store.addCorrection(topic: question, mistake: message.content, correction: correction)
        // So the correction applies from the very next message.
        needsRestart = true
    }
}
