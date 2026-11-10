//
//  EiraBackend.swift
//  Windfall
//
//  Where Eira's thinking actually happens.
//
//  Built around a protocol with two implementations from the start:
//
//    RemoteBackend   an OpenAI-compatible endpoint. Points at Ollama on
//                    the Mac over Tailscale, so gpt-oss:20b is available
//                    at home.
//    LocalBackend    MLX on the device, added later. Same interface, so
//                    nothing above this file has to change.
//
//  Doing it this way round means the app degrades sensibly: the big model
//  when the Mac is reachable, a small one in a hedge with no signal.
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
    /// Reasoning tokens, kept separate from the answer.
    var reasoning: String?
    var toolName: String?
    var toolCallID: String?
}

/// What comes back as the model generates.
enum StreamEvent {
    case reasoning(String)
    case content(String)
    case toolCall(name: String, arguments: String, id: String)
    case finished
}

// MARK: - Reasoning delimiters

/// Different model families mark their thinking differently, so this is
/// configuration rather than a hardcoded assumption. Get it wrong and raw
/// tags leak into the chat the first time you load a different model.
struct ReasoningFormat {
    let open: String
    let close: String

    static let qwenStyle = ReasoningFormat(open: "<think>", close: "</think>")
    static let deepseek  = ReasoningFormat(open: "<think>", close: "</think>")
    static let none      = ReasoningFormat(open: "", close: "")

    static func forModel(_ name: String) -> ReasoningFormat {
        let lower = name.lowercased()
        if lower.contains("qwen") || lower.contains("deepseek") || lower.contains("r1") {
            return .qwenStyle
        }
        // gpt-oss uses channel markers, which Ollama already strips into
        // a separate field, so nothing to parse here.
        return .none
    }
}

/// Splits a token stream into reasoning and answer.
/// A small state machine — about forty lines, as promised.
struct ReasoningParser {

    private let format: ReasoningFormat
    private var buffer = ""
    private var insideReasoning = false

    init(format: ReasoningFormat) {
        self.format = format
    }

    mutating func consume(_ chunk: String) -> [StreamEvent] {
        guard !format.open.isEmpty else { return [.content(chunk)] }

        buffer += chunk
        var events: [StreamEvent] = []

        while true {
            if insideReasoning {
                guard let range = buffer.range(of: format.close) else {
                    // Hold back anything that might be a partial close tag.
                    let safe = safeFlushLength(for: format.close)
                    if safe > 0 {
                        let text = String(buffer.prefix(safe))
                        buffer.removeFirst(safe)
                        events.append(.reasoning(text))
                    }
                    break
                }
                let text = String(buffer[buffer.startIndex..<range.lowerBound])
                if !text.isEmpty { events.append(.reasoning(text)) }
                buffer.removeSubrange(buffer.startIndex..<range.upperBound)
                insideReasoning = false

            } else {
                guard let range = buffer.range(of: format.open) else {
                    let safe = safeFlushLength(for: format.open)
                    if safe > 0 {
                        let text = String(buffer.prefix(safe))
                        buffer.removeFirst(safe)
                        events.append(.content(text))
                    }
                    break
                }
                let text = String(buffer[buffer.startIndex..<range.lowerBound])
                if !text.isEmpty { events.append(.content(text)) }
                buffer.removeSubrange(buffer.startIndex..<range.upperBound)
                insideReasoning = true
            }
        }
        return events
    }

    /// How much of the buffer is definitely not the start of a tag.
    private func safeFlushLength(for tag: String) -> Int {
        max(0, buffer.count - tag.count + 1)
    }

    mutating func flush() -> [StreamEvent] {
        guard !buffer.isEmpty else { return [] }
        let text = buffer
        buffer = ""
        return [insideReasoning ? .reasoning(text) : .content(text)]
    }
}

// MARK: - Metrics

/// The numbers you'll actually use when deciding which models earn their
/// space on a device.
struct GenerationMetrics {
    var timeToFirstToken: TimeInterval?
    var tokensGenerated: Int = 0
    var totalTime: TimeInterval = 0

    var tokensPerSecond: Double {
        guard totalTime > 0 else { return 0 }
        return Double(tokensGenerated) / totalTime
    }

    var summary: String {
        var parts: [String] = []
        if let ttft = timeToFirstToken {
            parts.append("\(Int(ttft * 1000))ms to first token")
        }
        if tokensPerSecond > 0 {
            parts.append(String(format: "%.1f tok/s", tokensPerSecond))
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Backend protocol

protocol EiraBackend: AnyObject {
    var name: String { get }
    var isAvailable: Bool { get async }

    func send(
        messages: [ChatMessage],
        tools: [ToolDefinition],
        onEvent: @escaping @MainActor (StreamEvent) -> Void
    ) async throws -> GenerationMetrics
}

enum BackendError: LocalizedError {
    case notReachable(String)
    case badResponse(Int)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .notReachable(let host):
            return "Can't reach \(host). Is Ollama running, and is Tailscale connected?"
        case .badResponse(let code):
            return "The model server returned an error (\(code))."
        case .decoding(let detail):
            return "Couldn't read the response: \(detail)"
        }
    }
}

// MARK: - Remote backend

/// Talks to any OpenAI-compatible endpoint. Ollama exposes one at
/// /v1/chat/completions, which is how Jan talks to it too — so the same
/// setup serves both.
final class RemoteBackend: EiraBackend {

    let name: String
    private let baseURL: URL
    private let model: String
    private let format: ReasoningFormat

    init(baseURL: URL, model: String) {
        self.baseURL = baseURL
        self.model = model
        self.name = model
        self.format = ReasoningFormat.forModel(model)
    }

    var isAvailable: Bool {
        get async {
            var request = URLRequest(url: baseURL.appendingPathComponent("v1/models"))
            request.timeoutInterval = 3
            guard let (_, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse else { return false }
            return http.statusCode == 200
        }
    }

    func send(
        messages: [ChatMessage],
        tools: [ToolDefinition],
        onEvent: @escaping @MainActor (StreamEvent) -> Void
    ) async throws -> GenerationMetrics {

        var request = URLRequest(url: baseURL.appendingPathComponent("v1/chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        var body: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": messages.map { message in
                var dictionary: [String: Any] = [
                    "role": message.role.rawValue,
                    "content": message.content
                ]
                if let toolCallID = message.toolCallID {
                    dictionary["tool_call_id"] = toolCallID
                }
                return dictionary
            }
        ]

        if !tools.isEmpty {
            body["tools"] = tools.map(\.asJSON)
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var metrics = GenerationMetrics()
        let started = Date.now
        var parser = ReasoningParser(format: format)

        let (stream, response) = try await URLSession.shared.bytes(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw BackendError.notReachable(baseURL.host ?? "the server")
        }
        guard http.statusCode == 200 else {
            throw BackendError.badResponse(http.statusCode)
        }

        // Server-sent events: each line is "data: {json}".
        for try await line in stream.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            guard payload != "[DONE]" else { break }

            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any]
            else { continue }

            if metrics.timeToFirstToken == nil {
                metrics.timeToFirstToken = Date.now.timeIntervalSince(started)
            }

            // Some servers give reasoning in its own field; use it directly.
            if let reasoning = delta["reasoning"] as? String ?? delta["reasoning_content"] as? String,
               !reasoning.isEmpty {
                await MainActor.run { onEvent(.reasoning(reasoning)) }
            }

            if let content = delta["content"] as? String, !content.isEmpty {
                metrics.tokensGenerated += 1
                for event in parser.consume(content) {
                    await MainActor.run { onEvent(event) }
                }
            }

            if let calls = delta["tool_calls"] as? [[String: Any]] {
                for call in calls {
                    guard let function = call["function"] as? [String: Any],
                          let name = function["name"] as? String else { continue }
                    let arguments = function["arguments"] as? String ?? "{}"
                    let id = call["id"] as? String ?? UUID().uuidString
                    await MainActor.run {
                        onEvent(.toolCall(name: name, arguments: arguments, id: id))
                    }
                }
            }
        }

        for event in parser.flush() {
            await MainActor.run { onEvent(event) }
        }

        metrics.totalTime = Date.now.timeIntervalSince(started)
        await MainActor.run { onEvent(.finished) }

        return metrics
    }
}
