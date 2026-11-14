//
//  EiraChatStore.swift
//  Windfall
//
//  Saved conversations with Eira.
//
//  Until now a conversation lived only in memory and vanished when the
//  app closed. Saving them does three jobs: you can go back to one, they
//  can sync between devices once iCloud is on, and Handoff has something
//  to hand to the Mac.
//
//  Both record types follow the iCloud rules used everywhere else in the
//  app: every property is optional or has a starting value, and nothing
//  is marked unique.
//

import Foundation
import SwiftData

/// One conversation.
@Model
final class EiraChat {

    var id: UUID = UUID()
    /// Taken from the first thing you asked, so the list is readable.
    var title: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    /// Which model answered, for comparing models later.
    var modelName: String?

    @Relationship(deleteRule: .cascade, inverse: \EiraChatMessage.chat)
    var messages: [EiraChatMessage]? = []

    init() {}

    /// Messages in the order they were said.
    var orderedMessages: [EiraChatMessage] {
        (messages ?? []).sorted { $0.order < $1.order }
    }
}

/// One message within a conversation.
@Model
final class EiraChatMessage {

    var id: UUID = UUID()
    /// Position in the conversation. SwiftData does not promise to keep a
    /// list in order, so the order is stored.
    var order: Int = 0
    var createdAt: Date = Date.now
    var roleRaw: String = ChatRole.user.rawValue
    var content: String = ""
    var reasoning: String?
    var toolName: String?

    var chat: EiraChat?

    init() {}

    var role: ChatRole {
        get { ChatRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    /// The same message in the shape the chat screen uses.
    var asChatMessage: ChatMessage {
        ChatMessage(id: id, role: role, content: content,
                    reasoning: reasoning, toolName: toolName)
    }
}

/// Something Eira got wrong, and what is right.
///
/// Every correction is kept. Eira reads the recent ones before each
/// conversation, so the same mistake is not made twice, and in time they
/// become the examples she is fine-tuned on. This is the one thing a
/// general assistant cannot do: remember being put right.
@Model
final class EiraCorrection {

    var id: UUID = UUID()
    var createdAt: Date = Date.now
    /// What was being discussed, usually the question.
    var topic: String = ""
    /// What Eira said.
    var mistake: String?
    /// What is actually right, in the gardener's words.
    var correction: String = ""

    init() {}

    /// One line for Eira's standing instructions.
    ///
    /// All of the correction is used, with its lines run together. Until
    /// 14 November 2026 only its first line was, so a correction written
    /// over two lines lost its second.
    var promptLine: String {
        let subject = topic.isEmpty ? "" : "On \"\(EiraChatStore.title(from: topic, limit: 80))\": "
        return subject + EiraChatStore.oneLine(correction, limit: EiraChecks.correctionLimit)
    }
}

/// Reads and writes saved conversations and corrections.
@MainActor
struct EiraChatStore {

    let context: ModelContext

    /// Starts a new saved conversation. Nothing is stored until the first
    /// message is added, so opening the chat does not litter the list.
    func newChat(modelName: String?) -> EiraChat {
        let chat = EiraChat()
        chat.modelName = modelName
        return chat
    }

    /// Adds a message to a conversation and saves it.
    ///
    /// Returns nil when the save worked, or a description of what went
    /// wrong. `@discardableResult` lets a caller ignore the answer.
    @discardableResult
    func append(_ message: ChatMessage, to chat: EiraChat) -> String? {
        // The first message is what puts a conversation into the store.
        if (chat.messages ?? []).isEmpty { context.insert(chat) }

        let stored = EiraChatMessage()
        stored.id = message.id
        stored.order = (chat.messages ?? []).count
        stored.role = message.role
        stored.content = message.content
        stored.reasoning = message.reasoning
        stored.toolName = message.toolName
        stored.chat = chat
        chat.messages?.append(stored)

        if chat.title.isEmpty, message.role == .user {
            chat.title = Self.title(from: message.content)
        }
        chat.updatedAt = .now
        do {
            try context.save()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Saved conversations, most recent first.
    func recentChats(limit: Int = 50) -> [EiraChat] {
        let all = (try? context.fetch(FetchDescriptor<EiraChat>())) ?? []
        return Array(all.sorted { $0.updatedAt > $1.updatedAt }.prefix(limit))
    }

    func delete(_ chat: EiraChat) {
        context.delete(chat)
        try? context.save()
    }

    // MARK: Corrections

    /// How many corrections are read to Eira before each conversation:
    /// the newest ten. All of them are kept, however many there are.
    nonisolated static let correctionsRead = 10

    /// Keeps a correction. Returns what was saved, or nil if there was
    /// nothing to save. `@discardableResult` lets a caller ignore that.
    @discardableResult
    func addCorrection(topic: String, mistake: String?, correction: String) -> EiraCorrection? {
        let trimmed = correction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let record = EiraCorrection()
        record.topic = topic
        record.mistake = mistake
        record.correction = trimmed
        context.insert(record)
        try? context.save()
        return record
    }

    /// Every correction, newest first.
    func corrections() -> [EiraCorrection] {
        let all = (try? context.fetch(FetchDescriptor<EiraCorrection>())) ?? []
        return all.sorted { $0.createdAt > $1.createdAt }
    }

    /// Takes a correction away for good.
    func remove(_ correction: EiraCorrection) {
        context.delete(correction)
        try? context.save()
    }

    /// The most recent corrections, newest first, as lines for the prompt.
    /// Limited, because a small model can only hold so much.
    func recentCorrectionLines(limit: Int = EiraChatStore.correctionsRead) -> [String] {
        corrections().prefix(limit).map(\.promptLine)
    }

    /// Text as a single line: its lines run together with a space
    /// between, and cut short with an ellipsis if longer than `limit`.
    nonisolated static func oneLine(_ text: String, limit: Int) -> String {
        let joined = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard joined.count > limit else { return joined }
        return String(joined.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// A short title from the first line of a message.
    nonisolated static func title(from text: String, limit: Int = 60) -> String {
        let firstLine = text
            .split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
