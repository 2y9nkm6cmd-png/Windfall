//
//  EiraEngine.swift
//  Windfall
//
//  The parts of Eira that do not depend on any one AI model.
//
//  Eira runs entirely on the device in your hand. There is no server and
//  nothing to connect to. This file holds:
//
//    - the shapes of a chat message and of the pieces a reply arrives in
//    - EiraEngine, the one interface the chat screen talks to
//    - the 12GB rule that decides whether a device can run Eira
//    - the choice of model, and where downloaded models are kept
//
//  The engine that actually runs a model is in EiraOnDeviceEngine.swift.
//  Keeping this file free of Apple's AI frameworks means everything here
//  can be checked and tested anywhere.
//

import Foundation

// MARK: - Messages

enum ChatRole: String, Codable {
    case system, user, assistant, tool
}

struct ChatMessage: Identifiable, Codable {
    var id = UUID()
    var role: ChatRole
    var content: String
    /// The model's thinking, kept separate from its answer.
    var reasoning: String?
    /// For tool rows: which lookup produced this text.
    var toolName: String?
}

/// What comes back, piece by piece, while Eira is replying.
enum StreamEvent {
    /// More of the model's thinking.
    case reasoning(String)
    /// More of the answer.
    case content(String)
    /// Eira looked something up. `text` is what came back, with its source.
    case toolResult(name: String, text: String)
    case finished
}

// MARK: - Metrics

/// The numbers that decide which models earn their space on a device.
struct GenerationMetrics {
    var timeToFirstToken: TimeInterval?
    /// Approximate. Counted in pieces of text received, not true tokens.
    var tokensGenerated: Int = 0
    var totalTime: TimeInterval = 0

    var tokensPerSecond: Double {
        guard totalTime > 0 else { return 0 }
        return Double(tokensGenerated) / totalTime
    }

    var summary: String {
        var parts: [String] = []
        if let ttft = timeToFirstToken {
            parts.append("\(Int(ttft * 1000))ms to first word")
        }
        if tokensPerSecond > 0 {
            parts.append(String(format: "about %.0f pieces/s", tokensPerSecond))
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - The engine interface

/// Anything that can hold a conversation with a model.
///
/// The chat screen only ever talks to this. Which model sits behind it,
/// and which of Apple's frameworks runs that model, is hidden here, so a
/// new kind of model can be added without touching the screen.
///
/// The engine remembers the conversation itself. The screen sends one
/// message at a time and listens for the pieces of the reply.
@MainActor
protocol EiraEngine: AnyObject {

    /// A short name for the model, shown in the chat.
    var displayName: String { get }

    /// Begins a fresh conversation.
    /// - `instructions` are Eira's standing rules, built by EiraPrompt.
    /// - `history` is any earlier messages to carry in, used when a saved
    ///   conversation is reopened or a long one has been condensed.
    func startConversation(instructions: String, history: [ChatMessage])

    /// Sends one message and streams the reply back through `onEvent`.
    func reply(
        to prompt: String,
        onEvent: @escaping @MainActor (StreamEvent) -> Void
    ) async throws -> GenerationMetrics

    /// Frees the memory the model is using.
    func unload()
}

enum EiraEngineError: LocalizedError, Equatable {
    case deviceBelowMinimum(String)
    case needsNewerSystem
    case builtInModelUnavailable
    case modelNotFound(String)
    case packageMissing(String)
    case notSetUpYet(String)

    var errorDescription: String? {
        switch self {
        case .deviceBelowMinimum(let memory):
            return "Eira needs a device with at least \(DeviceCapability.minimumMemoryGB)GB of memory. This one has \(memory). The rest of Windfall works as normal."
        case .needsNewerSystem:
            return "Eira's on-device models need iOS 27, iPadOS 27 or macOS 27, and the app built with Xcode 27."
        case .builtInModelUnavailable:
            return "Apple's built-in model is not available on this device. Check that Apple Intelligence is switched on in Settings, or choose a downloaded model."
        case .modelNotFound(let name):
            return "The model \"\(name)\" could not be found on this device."
        case .notSetUpYet(let what):
            return "\(what) is not set up yet."
        case .packageMissing(let package):
            return "This build of Windfall does not include \(package), which that kind of model needs."
        }
    }
}

// MARK: - The 12GB rule

/// Eira's models only run on devices with at least 12GB of memory.
/// Smaller devices run the rest of Windfall without her.
enum DeviceCapability {

    static let minimumMemoryGB = 12

    /// A device sold as "12GB" reports a little less than 12 to apps,
    /// because the system keeps some back. An 8GB device reports under 8.
    /// 10.5 sits safely between the two.
    static let minimumReportedBytes: UInt64 = 10_500 * 1024 * 1024

    static func canRunEira(
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) -> Bool {
        physicalMemory >= minimumReportedBytes
    }

    /// The device's memory rounded to the size it is sold as.
    static func memoryDescription(
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) -> String {
        let gigabytes = Double(physicalMemory) / (1024 * 1024 * 1024)
        return "\(Int(gigabytes.rounded()))GB"
    }
}

// MARK: - Which model

/// The model Eira is set to use. Saved in the app's settings.
struct EiraModelChoice: Codable, Equatable, Hashable {

    enum Kind: String, Codable, CaseIterable, Identifiable {
        /// The model Apple ships with the system. Nothing to download.
        case appleBuiltIn
        /// A converted .aimodel folder, run by Core AI.
        case coreAI
        /// A model downloaded by name from Hugging Face, run by MLX.
        case mlx
        /// A model on someone else's servers. Not set up yet, and never
        /// used unless chosen. The slot is here so a service can be added
        /// later without changing anything else.
        case online

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .appleBuiltIn: return "Apple built-in"
            case .coreAI:       return "Core AI model"
            case .mlx:          return "MLX model"
            case .online:       return "Online service"
            }
        }

        /// Whether questions stay on this device.
        var isPrivate: Bool { self != .online }
    }

    var kind: Kind
    /// For Core AI, the folder name inside the models folder.
    /// For MLX, the Hugging Face name, such as "mlx-community/Qwen3-4B-4bit".
    /// Unused for the built-in model.
    var value: String

    static let appleBuiltIn = EiraModelChoice(kind: .appleBuiltIn, value: "")

    var displayName: String {
        switch kind {
        case .appleBuiltIn, .online: return kind.displayName
        case .coreAI, .mlx: return value.isEmpty ? kind.displayName : value
        }
    }

    // Saving and loading. Two plain strings, so the settings stay readable.

    private static let kindKey = "eiraModelKind"
    private static let valueKey = "eiraModelValue"

    static func load(from defaults: UserDefaults = .standard) -> EiraModelChoice {
        guard let raw = defaults.string(forKey: kindKey),
              let kind = Kind(rawValue: raw) else { return .appleBuiltIn }
        return EiraModelChoice(kind: kind, value: defaults.string(forKey: valueKey) ?? "")
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(kind.rawValue, forKey: Self.kindKey)
        defaults.set(value, forKey: Self.valueKey)
    }
}

// MARK: - Where models live

/// Core AI models are folders of files. They are kept in one place so the
/// app can list them, and so they can be copied in with the Files app.
enum EiraModelLibrary {

    /// The app's "Models" folder, created on first use.
    static func modelsFolder(fileManager: FileManager = .default) -> URL {
        let folder = modelsFolderPath(fileManager: fileManager)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Where the Models folder is, without making it.
    ///
    /// On an iPhone or iPad it is in the app's Documents, which the
    /// Files app can see, so a model can be copied in by hand.
    ///
    /// On a Mac it is in Application Support, the place for an app's own
    /// working files: "Windfall", then "Models". Documents would be the
    /// wrong place there. A Mac's Documents folder is often kept in
    /// iCloud, and a model of several gigabytes would start uploading.
    /// (Changed on 13 November 2026, before any model had been put in.)
    nonisolated static func modelsFolderPath(fileManager: FileManager = .default) -> URL {
        #if os(macOS)
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("Windfall", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
        #else
        let base = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("Models", isDirectory: true)
        #endif
    }

    static func folderURL(named name: String, fileManager: FileManager = .default) -> URL {
        modelsFolder(fileManager: fileManager).appendingPathComponent(name, isDirectory: true)
    }

    /// Names of the folders inside "Models" that hold a Core AI model
    /// Eira can talk with.
    /// A folder counts if it contains something ending in .aimodel or
    /// .aimodelc, at the top level or one level down.
    ///
    /// An image model's folder is left out. It also holds an .aimodel,
    /// so until 14 November 2026 "bioclip2" was offered as a model to
    /// chat with, which it cannot do. Its list of species is what
    /// tells it apart (SpeciesEye.swift).
    static func coreAIModelNames(fileManager: FileManager = .default) -> [String] {
        let root = modelsFolder(fileManager: fileManager)
        let folders = (try? fileManager.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey])) ?? []

        return folders
            .filter { containsModel($0, depth: 2, fileManager: fileManager) }
            .filter { !fileManager.fileExists(atPath: $0.appendingPathComponent("uk_species.json").path) }
            .map(\.lastPathComponent)
            .sorted()
    }

    /// Copies a converted model's folder into Windfall's Models folder
    /// and returns the name it was given.
    ///
    /// Why a copy: on a Mac, Windfall runs in a "sandbox", a fenced-off
    /// part of the disk that only it may use. It cannot read a model
    /// lying elsewhere, and nothing else may put one inside. So the
    /// model is chosen in a file window, which gives Windfall leave to
    /// read that one folder, and Windfall copies it in itself.
    ///
    /// On the same disk the copy is a "clone": it appears at once and
    /// takes no more room until one of the two is changed.
    ///
    /// `nonisolated` lets this run away from the main thread, so the
    /// screen does not freeze while a large copy is made.
    nonisolated static func importModel(from source: URL) throws -> String {
        let fileManager = FileManager.default
        // Leave to read a folder chosen in a file window lasts only
        // between these two calls.
        let hasLeave = source.startAccessingSecurityScopedResource()
        defer { if hasLeave { source.stopAccessingSecurityScopedResource() } }

        guard fileManager.fileExists(atPath: source.appendingPathComponent("metadata.json").path) else {
            throw EiraEngineError.modelNotFound("\(source.lastPathComponent) (it has no metadata.json, so it is not a converted model's folder)")
        }

        let models = modelsFolderPath(fileManager: fileManager)
        try fileManager.createDirectory(at: models, withIntermediateDirectories: true)

        let name = source.lastPathComponent
        let target = models.appendingPathComponent(name, isDirectory: true)
        // A model of the same name is replaced, so the same folder can
        // be brought in again after it has been converted afresh.
        if fileManager.fileExists(atPath: target.path) {
            try fileManager.removeItem(at: target)
        }
        try fileManager.copyItem(at: source, to: target)
        return name
    }

    private static func containsModel(_ folder: URL, depth: Int, fileManager: FileManager) -> Bool {
        guard depth > 0 else { return false }
        let items = (try? fileManager.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil)) ?? []
        for item in items {
            let ext = item.pathExtension.lowercased()
            if ext == "aimodel" || ext == "aimodelc" { return true }
            if containsModel(item, depth: depth - 1, fileManager: fileManager) { return true }
        }
        return false
    }
}
