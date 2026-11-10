//
//  EiraOnDeviceEngine.swift
//  Windfall
//
//  Runs a model on this device and connects it to Eira's chat.
//
//  This is the only file that talks to Apple's AI frameworks:
//
//    Foundation Models   holds the conversation, streams the reply and
//                        runs the tools. The class is LanguageModelSession.
//    Core AI             runs a converted model (.aimodel) underneath.
//    MLX                 an alternative way to run a model (see
//                        EiraMLXLoader.swift).
//
//  Everything Apple-specific is fenced with `#if canImport(...)`, which
//  means "only build this part if that framework exists". So:
//
//    - Built with Xcode 26, the fenced part vanishes and Eira reports
//      that she needs the newer system. The rest of the app still builds.
//    - Built with Xcode 27, Apple's built-in model works straight away.
//    - Add the coreai-models package and Core AI models work too.
//
//  NOT YET BUILT ON A MAC. The framework calls below were written from
//  Apple's published source and tests, dated October and November 2026,
//  but this file has never been through Xcode. Expect small corrections
//  on its first build.
//

import Foundation
import SwiftData

#if canImport(FoundationModels) && canImport(CoreAI)
import FoundationModels
#if canImport(CoreAILanguageModels)
import CoreAILanguageModels
#endif
#endif

// MARK: - Making an engine

/// The one place the app asks for an engine. It either returns one that
/// is ready to use or throws an error whose message says plainly why not.
@MainActor
enum EiraEngineFactory {

    static func make(choice: EiraModelChoice, hub: EiraToolHub) async throws -> EiraEngine {
        // The 12GB rule comes first. Below it, no model is loaded at all.
        guard DeviceCapability.canRunEira() else {
            throw EiraEngineError.deviceBelowMinimum(DeviceCapability.memoryDescription())
        }

        #if canImport(FoundationModels) && canImport(CoreAI)
        if #available(iOS 27.0, macOS 27.0, *) {
            return try await OnDeviceEngine.load(choice: choice, hub: hub)
        }
        #endif

        throw EiraEngineError.needsNewerSystem
    }
}

#if canImport(FoundationModels) && canImport(CoreAI)

// MARK: - The engine

@available(iOS 27.0, macOS 27.0, *)
@MainActor
final class OnDeviceEngine: EiraEngine {

    let displayName: String

    /// Makes a new session for a given set of instructions. Supplied by
    /// whichever loader built this engine, because only the loader knows
    /// what kind of model it has.
    private let makeSession: (_ instructions: String) -> LanguageModelSession
    private let unloadModel: () -> Void

    /// The conversation in progress. Apple's session keeps the whole
    /// exchange itself, including tool calls and their results.
    private var session: LanguageModelSession?

    init(displayName: String,
         makeSession: @escaping (_ instructions: String) -> LanguageModelSession,
         unloadModel: @escaping () -> Void) {
        self.displayName = displayName
        self.makeSession = makeSession
        self.unloadModel = unloadModel
    }

    func startConversation(instructions: String, history: [ChatMessage]) {
        // Earlier turns are written into the instructions as plain text.
        // It is the simplest reliable way to carry a conversation into a
        // fresh session, and it works the same for every kind of model.
        var full = instructions
        let earlier = EiraContext.historyText(history)
        if !earlier.isEmpty {
            full += "\n\nEarlier in this conversation:\n\(earlier)"
        }
        session = makeSession(full)
    }

    func reply(
        to prompt: String,
        onEvent: @escaping @MainActor (StreamEvent) -> Void
    ) async throws -> GenerationMetrics {

        if session == nil {
            startConversation(instructions: EiraPrompt.build(), history: [])
        }
        guard let session else { throw EiraEngineError.needsNewerSystem }

        var metrics = GenerationMetrics()
        let started = Date.now
        // Remember how long the record of the conversation was, so only
        // this turn's reasoning is read back out of it.
        let entriesBefore = Array(session.transcript).count
        var answerSoFar = ""
        var reasoningSoFar = ""

        // The reply arrives as a series of snapshots, each holding the
        // whole answer so far. The chat wants only what is new each time,
        // so the difference is worked out here.
        let stream = session.streamResponse(to: prompt)
        for try await partial in stream {
            try Task.checkCancellation()

            let reasoning = Self.reasoningText(in: session.transcript, after: entriesBefore)
            if reasoning.count > reasoningSoFar.count, reasoning.hasPrefix(reasoningSoFar) {
                onEvent(.reasoning(String(reasoning.dropFirst(reasoningSoFar.count))))
                reasoningSoFar = reasoning
            }

            let answer = partial.content
            guard answer.count > answerSoFar.count, answer.hasPrefix(answerSoFar) else { continue }
            if metrics.timeToFirstToken == nil {
                metrics.timeToFirstToken = Date.now.timeIntervalSince(started)
            }
            metrics.tokensGenerated += 1
            onEvent(.content(String(answer.dropFirst(answerSoFar.count))))
            answerSoFar = answer
        }

        // Reasoning may only be written into the record at the end.
        let reasoning = Self.reasoningText(in: session.transcript, after: entriesBefore)
        if reasoning.count > reasoningSoFar.count, reasoning.hasPrefix(reasoningSoFar) {
            onEvent(.reasoning(String(reasoning.dropFirst(reasoningSoFar.count))))
        }

        metrics.totalTime = Date.now.timeIntervalSince(started)
        onEvent(.finished)
        return metrics
    }

    func unload() {
        session = nil
        unloadModel()
    }

    /// Pulls the model's thinking out of the session's record.
    private static func reasoningText(in transcript: Transcript, after count: Int) -> String {
        Array(transcript).dropFirst(count).compactMap { entry -> String? in
            guard case .reasoning(let reasoning) = entry else { return nil }
            return reasoning.segments.compactMap { segment -> String? in
                if case .text(let text) = segment { return text.content }
                return nil
            }.joined()
        }
        .joined(separator: "\n")
    }

    // MARK: Loading a model

    static func load(choice: EiraModelChoice, hub: EiraToolHub) async throws -> OnDeviceEngine {
        let tools = EiraSessionTools.all(hub: hub)

        switch choice.kind {

        case .appleBuiltIn:
            // The model Apple ships with the system. Nothing to download.
            let model = SystemLanguageModel.default
            guard model.isAvailable else { throw EiraEngineError.builtInModelUnavailable }
            return OnDeviceEngine(
                displayName: choice.displayName,
                makeSession: { LanguageModelSession(model: model, tools: tools, instructions: $0) },
                unloadModel: {})

        case .coreAI:
            #if canImport(CoreAILanguageModels)
            guard !choice.value.isEmpty,
                  let folder = bundleFolder(in: EiraModelLibrary.folderURL(named: choice.value))
            else { throw EiraEngineError.modelNotFound(choice.value) }

            // Reads the model's description and its tokenizer. The heavy
            // part, loading the weights, happens on the first question.
            let model = try await CoreAILanguageModel(resourcesAt: folder)
            return OnDeviceEngine(
                displayName: choice.displayName,
                makeSession: { LanguageModelSession(model: model, tools: tools, instructions: $0) },
                unloadModel: { model.unload() })
            #else
            throw EiraEngineError.packageMissing("Apple's coreai-models package")
            #endif

        case .mlx:
            #if canImport(MLXFoundationModels) && canImport(MLXHuggingFace)
            guard !choice.value.isEmpty else { throw EiraEngineError.modelNotFound("no name given") }
            return EiraMLXLoader.engine(modelID: choice.value, displayName: choice.displayName, tools: tools)
            #else
            throw EiraEngineError.packageMissing("the mlx-swift-lm package")
            #endif

        case .online:
            throw EiraEngineError.notSetUpYet("An online service")
        }
    }

    /// A Core AI model folder is recognised by its metadata.json file.
    /// This looks in the folder itself and one level down, so a model
    /// copied in inside a wrapping folder is still found.
    private static func bundleFolder(in folder: URL) -> URL? {
        let fileManager = FileManager.default
        func isBundle(_ url: URL) -> Bool {
            fileManager.fileExists(atPath: url.appendingPathComponent("metadata.json").path)
        }
        if isBundle(folder) { return folder }
        let children = (try? fileManager.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil)) ?? []
        return children.first(where: isBundle)
    }
}

// MARK: - Eira's tools, in the form Apple's framework expects

// Each tool below is a thin wrapper. The real work is still done by
// ToolRunner in EiraTools.swift. These wrappers exist because Apple's
// framework wants every tool described in its own way:
//
//   name, description   what the model is told about the tool
//   Arguments           the inputs, marked @Generable so the framework
//                       can make the model fill them in correctly
//   call(arguments:)    what happens when the model uses the tool
//
// The framework runs the tool and hands the result back to the model by
// itself. That replaces the hand-written loop the old server code used.

@available(iOS 27.0, macOS 27.0, *)
enum EiraSessionTools {

    @MainActor
    static func all(hub: EiraToolHub) -> [any Tool] {
        [
            LookupSpeciesTool(description: EiraTools.lookupSpecies.description, hub: hub),
            SearchGardenTool(description: EiraTools.searchGarden.description, hub: hub),
            WhatsGrowingTool(description: EiraTools.whatsInBed.description, hub: hub),
            PlantVisitorsTool(description: EiraTools.plantVisitors.description, hub: hub),
            RecentRecordsTool(description: EiraTools.recentRecords.description, hub: hub),
            SearchNotesTool(description: EiraTools.searchNotes.description, hub: hub),
            SearchWikipediaTool(description: EiraTools.searchWikipedia.description, hub: hub),
            ReadWebPageTool(description: EiraTools.readWebPage.description, hub: hub)
        ]
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct LookupSpeciesTool: Tool {
    let name = "lookup_species"
    let description: String
    let hub: EiraToolHub

    @Generable
    struct Arguments {
        @Guide(description: "Common or scientific name to look up")
        var name: String
    }

    func call(arguments: Arguments) async throws -> String {
        await hub.run(name: name, argumentsJSON: EiraToolHub.json(["name": arguments.name]))
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SearchGardenTool: Tool {
    let name = "search_garden"
    let description: String
    let hub: EiraToolHub

    @Generable
    struct Arguments {
        @Guide(description: "Plant name or search term")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        await hub.run(name: name, argumentsJSON: EiraToolHub.json(["query": arguments.query]))
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct WhatsGrowingTool: Tool {
    let name = "whats_growing"
    let description: String
    let hub: EiraToolHub

    @Generable
    struct Arguments {
        @Guide(description: "Bed name, or an empty string for everything")
        var bed: String
    }

    func call(arguments: Arguments) async throws -> String {
        let bed = arguments.bed.trimmingCharacters(in: .whitespaces)
        return await hub.run(name: name,
                             argumentsJSON: bed.isEmpty ? "{}" : EiraToolHub.json(["bed": bed]))
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct PlantVisitorsTool: Tool {
    let name = "plant_visitors"
    let description: String
    let hub: EiraToolHub

    @Generable
    struct Arguments {
        @Guide(description: "Plant common name")
        var plant: String
    }

    func call(arguments: Arguments) async throws -> String {
        await hub.run(name: name, argumentsJSON: EiraToolHub.json(["plant": arguments.plant]))
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct RecentRecordsTool: Tool {
    let name = "recent_records"
    let description: String
    let hub: EiraToolHub

    @Generable
    struct Arguments {
        @Guide(description: "One of: harvests, sowings, surveys, sightings")
        var kind: String
        @Guide(description: "How many days back to look. Use 30 if unsure.")
        var days: Int
    }

    func call(arguments: Arguments) async throws -> String {
        // Built with JSONSerialization because one value is a number.
        let values: [String: Any] = ["kind": arguments.kind, "days": max(1, arguments.days)]
        let json = (try? JSONSerialization.data(withJSONObject: values))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return await hub.run(name: name, argumentsJSON: json)
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SearchNotesTool: Tool {
    let name = "search_notes"
    let description: String
    let hub: EiraToolHub

    @Generable
    struct Arguments {
        @Guide(description: "What to look for")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        await hub.run(name: name, argumentsJSON: EiraToolHub.json(["query": arguments.query]))
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct SearchWikipediaTool: Tool {
    let name = "search_wikipedia"
    let description: String
    let hub: EiraToolHub

    @Generable
    struct Arguments {
        @Guide(description: "The topic to look up")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        await hub.run(name: name, argumentsJSON: EiraToolHub.json(["query": arguments.query]))
    }
}

@available(iOS 27.0, macOS 27.0, *)
struct ReadWebPageTool: Tool {
    let name = "read_web_page"
    let description: String
    let hub: EiraToolHub

    @Generable
    struct Arguments {
        @Guide(description: "The full web address")
        var url: String
    }

    func call(arguments: Arguments) async throws -> String {
        await hub.run(name: name, argumentsJSON: EiraToolHub.json(["url": arguments.url]))
    }
}

#endif
