//
//  EiraChatView.swift
//  Windfall
//
//  Talking to Eira.
//
//  The reasoning box is the PocketPal-style collapsible panel: the stream
//  is split into two buffers and shown separately, collapsed by default
//  because on a small model the thinking is often longer than the answer.
//  Metrics sit underneath, because tokens/sec is the number that decides
//  which models earn their space.
//
//  Tool calls are shown explicitly. When Eira looks something up you can
//  see what it asked and what came back — and there is a manual override,
//  because small models are unreliable about deciding when to use a tool.
//

import SwiftUI
import SwiftData

// MARK: - Conversation

@Observable
@MainActor
final class EiraConversation {

    var messages: [ChatMessage] = []
    var isGenerating = false
    var lastMetrics: GenerationMetrics?
    var lastError: String?

    /// Live buffers while a reply is streaming.
    var streamingContent = ""
    var streamingReasoning = ""

    private var backend: EiraBackend?
    private var runner: ToolRunner?

    func configure(backend: EiraBackend, context: ModelContext) {
        self.backend = backend
        self.runner = ToolRunner(context: context)

        if messages.isEmpty {
            messages.append(ChatMessage(role: .system, content: EiraPrompt.build()))
        }
    }

    func send(_ text: String, forcedTool: ToolDefinition? = nil) async {
        guard let backend, !text.isEmpty else { return }

        messages.append(ChatMessage(role: .user, content: text))
        isGenerating = true
        streamingContent = ""
        streamingReasoning = ""
        lastError = nil

        // A forced tool call runs before the model gets a turn, so a
        // lookup happens whether or not the model thought to ask for one.
        if let forcedTool, let runner {
            let result = await runner.run(name: forcedTool.name,
                                          arguments: "{\"name\":\"\(text)\",\"query\":\"\(text)\",\"plant\":\"\(text)\"}")
            messages.append(ChatMessage(role: .tool,
                                        content: result.formatted,
                                        toolName: forcedTool.name))
        }

        await generate()
    }

    private func generate(depth: Int = 0) async {
        guard let backend, depth < 4 else {
            isGenerating = false
            return
        }

        var pendingToolCalls: [(name: String, arguments: String, id: String)] = []

        do {
            let metrics = try await backend.send(
                messages: messages,
                tools: EiraTools.all
            ) { [weak self] event in
                guard let self else { return }
                switch event {
                case .reasoning(let text):
                    self.streamingReasoning += text
                case .content(let text):
                    self.streamingContent += text
                case .toolCall(let name, let arguments, let id):
                    pendingToolCalls.append((name, arguments, id))
                case .finished:
                    break
                }
            }

            lastMetrics = metrics

            // Commit whatever was produced.
            if !streamingContent.isEmpty || !streamingReasoning.isEmpty {
                messages.append(ChatMessage(
                    role: .assistant,
                    content: streamingContent,
                    reasoning: streamingReasoning.isEmpty ? nil : streamingReasoning
                ))
            }
            streamingContent = ""
            streamingReasoning = ""

            // Run any tools, then let the model see the results.
            if !pendingToolCalls.isEmpty, let runner {
                for call in pendingToolCalls {
                    let result = await runner.run(name: call.name, arguments: call.arguments)
                    messages.append(ChatMessage(
                        role: .tool,
                        content: result.formatted,
                        toolName: call.name,
                        toolCallID: call.id
                    ))
                }
                await generate(depth: depth + 1)
                return
            }

        } catch {
            lastError = error.localizedDescription
        }

        isGenerating = false
    }

    func clear() {
        messages = [ChatMessage(role: .system, content: EiraPrompt.build())]
        streamingContent = ""
        streamingReasoning = ""
        lastMetrics = nil
        lastError = nil
    }
}

// MARK: - View

struct EiraChatView: View {

    @Environment(\.modelContext) private var context

    @AppStorage("eiraHost") private var host = ""
    @AppStorage("eiraModel") private var model = "gpt-oss:20b"

    @State private var conversation = EiraConversation()
    @State private var input = ""
    @State private var backendReachable: Bool?
    @State private var showingSettings = false
    @State private var voice = VoiceInput()
    @AppStorage("eiraSpeaksReplies") private var speaksReplies = false

    private var visibleMessages: [ChatMessage] {
        conversation.messages.filter { $0.role != .system }
    }

    var body: some View {
        VStack(spacing: 0) {
            if backendReachable == false {
                unreachableBanner
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if visibleMessages.isEmpty {
                            welcome
                        }

                        ForEach(visibleMessages) { message in
                            MessageView(message: message)
                                .id(message.id)
                        }

                        if conversation.isGenerating {
                            StreamingView(conversation: conversation)
                                .id("streaming")
                        }

                        if let metrics = conversation.lastMetrics,
                           !conversation.isGenerating,
                           !metrics.summary.isEmpty {
                            Text(metrics.summary)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }

                        if let error = conversation.lastError {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .font(.callout)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding()
                }
                .onChange(of: conversation.streamingContent) { _, _ in
                    withAnimation { proxy.scrollTo("streaming", anchor: .bottom) }
                }
                .onChange(of: visibleMessages.count) { _, _ in
                    if let last = visibleMessages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()
            inputBar
        }
        .navigationTitle("Eira")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        conversation.clear()
                    } label: {
                        Label("New conversation", systemImage: "square.and.pencil")
                    }
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Model settings", systemImage: "gear")
                    }
                } label: {
                    Label("Options", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            EiraSettingsView(host: $host, model: $model)
        }
        .task {
            await configure()
            await voice.requestPermission()
        }
        .onChange(of: conversation.isGenerating) { wasGenerating, isGenerating in
            // Read the reply aloud once it has finished, if asked to.
            guard wasGenerating, !isGenerating, speaksReplies,
                  let last = conversation.messages.last,
                  last.role == .assistant, !last.content.isEmpty else { return }
            voice.speak(last.content)
        }
    }

    // MARK: Pieces

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask about your garden")
                .font(.headline)

            ForEach([
                "What's growing in Bed 3?",
                "What visits marjoram?",
                "What did I harvest this month?",
                "Is it warm enough for a FIT count?"
            ], id: \.self) { suggestion in
                Button {
                    input = suggestion
                } label: {
                    Text(suggestion)
                        .font(.callout)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical)
    }

    private var unreachableBanner: some View {
        HStack {
            Image(systemName: "wifi.exclamationmark")
            Text("Can't reach the model server")
                .font(.caption)
            Spacer()
            Button("Settings") { showingSettings = true }
                .font(.caption)
        }
        .padding(8)
        .background(.orange.opacity(0.15))
    }

    private var inputBar: some View {
        VStack(spacing: 6) {
            // Manual override — forces a lookup regardless of whether the
            // model decided to call one. Small models are unreliable here.
            if !input.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        forceButton("Look up species", tool: EiraTools.lookupSpecies)
                        forceButton("Search my plants", tool: EiraTools.searchGarden)
                        forceButton("What visits it", tool: EiraTools.plantVisitors)
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Ask Eira…", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)

                if voice.isAuthorised {
                    PushToTalkButton(voice: voice) { spoken in
                        Task { await conversation.send(spoken) }
                    }
                    .scaleEffect(0.62)
                    .frame(width: 44, height: 44)
                }

                Button {
                    let text = input
                    input = ""
                    Task { await conversation.send(text) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(input.isEmpty || conversation.isGenerating)
            }
        }
        .padding(8)
    }

    private func forceButton(_ title: String, tool: ToolDefinition) -> some View {
        Button {
            let text = input
            input = ""
            Task { await conversation.send(text, forcedTool: tool) }
        } label: {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func configure() async {
        guard !host.isEmpty, let url = URL(string: host) else {
            backendReachable = false
            return
        }
        let backend = RemoteBackend(baseURL: url, model: model)
        conversation.configure(backend: backend, context: context)
        backendReachable = await backend.isAvailable
    }
}

// MARK: - One message

private struct MessageView: View {

    let message: ChatMessage
    @State private var reasoningExpanded = false

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 40)
                Text(message.content)
                    .padding(10)
                    .background(Color.accentColor.opacity(0.18),
                                in: RoundedRectangle(cornerRadius: 12))
            }

        case .tool:
            DisclosureGroup {
                Text(message.content)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } label: {
                Label(message.toolName ?? "Lookup", systemImage: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        case .assistant:
            VStack(alignment: .leading, spacing: 8) {
                if let reasoning = message.reasoning, !reasoning.isEmpty {
                    ReasoningBox(text: reasoning, expanded: $reasoningExpanded)
                }
                Text(message.content)
                    .textSelection(.enabled)
            }

        case .system:
            EmptyView()
        }
    }
}

// MARK: - Reasoning box

/// Collapsed by default. On a 4B model the thinking is routinely longer
/// than the answer, and you'd be scrolling past a wall of it every turn.
struct ReasoningBox: View {

    let text: String
    @Binding var expanded: Bool
    var isLive = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation { expanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: isLive ? "ellipsis.bubble" : "brain")
                    Text(isLive ? "Thinking…" : "Reasoning")
                        .font(.caption.weight(.medium))
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            if expanded {
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(10)
        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.blue.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Streaming

private struct StreamingView: View {

    let conversation: EiraConversation
    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !conversation.streamingReasoning.isEmpty {
                ReasoningBox(text: conversation.streamingReasoning,
                             expanded: $expanded, isLive: true)
            }

            if conversation.streamingContent.isEmpty && conversation.streamingReasoning.isEmpty {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Thinking…").font(.caption).foregroundStyle(.secondary)
                }
            } else if !conversation.streamingContent.isEmpty {
                Text(conversation.streamingContent)
            }
        }
    }
}

// MARK: - Settings

struct EiraSettingsView: View {

    @Binding var host: String
    @Binding var model: String

    @Environment(\.dismiss) private var dismiss
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://100.x.y.z:11434", text: $host)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        #endif

                    TextField("Model", text: $model)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                } header: {
                    Text("Model server")
                } footer: {
                    Text("Your Mac's Tailscale address with port 11434. Ollama must be running, and started with OLLAMA_HOST=0.0.0.0 so it accepts connections from other machines.")
                }

                Section {
                    Button {
                        Task { await test() }
                    } label: {
                        if isTesting {
                            HStack { ProgressView(); Text("Testing…") }
                        } else {
                            Label("Test connection", systemImage: "network")
                        }
                    }
                    .disabled(host.isEmpty || isTesting)

                    if let testResult {
                        Text(testResult)
                            .font(.callout)
                            .foregroundStyle(testResult.hasPrefix("Connected") ? .green : .orange)
                    }
                }
            }
            .navigationTitle("Eira")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func test() async {
        isTesting = true
        defer { isTesting = false }

        guard let url = URL(string: host) else {
            testResult = "That doesn't look like a valid address."
            return
        }
        let backend = RemoteBackend(baseURL: url, model: model)
        testResult = await backend.isAvailable
            ? "Connected. \(model) should be available."
            : "No response. Check Ollama is running and Tailscale is connected."
    }
}
