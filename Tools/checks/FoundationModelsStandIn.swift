#if !canImport(SwiftUI)
// A small imitation of the parts of Apple's Foundation Models framework
// that EiraOnDeviceEngine.swift uses. It exists only so that file's own
// logic can be type-checked without a Mac.
//
// It proves the engine's code is consistent with THIS description of the
// framework. It cannot prove this description matches the real framework.
// The shapes were copied from Apple's published source and tests
// (foundation-models-utilities, coreai-models, mlx-swift-lm) in
// November 2026. Only a build in Xcode 27 settles it.

import Foundation

public protocol Tool: Sendable {
    associatedtype Arguments
    associatedtype Output
    var name: String { get }
    var description: String { get }
    func call(arguments: Arguments) async throws -> Output
}

public struct Transcript: Sequence {
    public struct TextSegment { public var content: String }
    public enum Segment { case text(TextSegment), structure }
    public struct Prompt { public var segments: [Segment] }
    public struct Response { public var segments: [Segment] }
    public struct Reasoning { public var segments: [Segment] }
    public enum Entry {
        case instructions
        case prompt(Prompt)
        case response(Response)
        case reasoning(Reasoning)
        case toolCalls
        case toolOutput
    }
    var entries: [Entry] = []
    public func makeIterator() -> IndexingIterator<[Entry]> { entries.makeIterator() }
}

public struct SystemLanguageModel: Sendable {
    public static let `default` = SystemLanguageModel()
    public var isAvailable: Bool { true }
}

public final class LanguageModelSession: @unchecked Sendable {
    public struct Snapshot { public var content: String }
    public struct ResponseStream: AsyncSequence {
        public typealias Element = Snapshot
        public struct AsyncIterator: AsyncIteratorProtocol {
            public mutating func next() async throws -> Snapshot? { nil }
        }
        public func makeAsyncIterator() -> AsyncIterator { AsyncIterator() }
    }
    public var transcript = Transcript()
    public init(model: SystemLanguageModel, tools: [any Tool] = [], instructions: String? = nil) {}
    public func streamResponse(to prompt: String) -> ResponseStream { ResponseStream() }
}
#endif
