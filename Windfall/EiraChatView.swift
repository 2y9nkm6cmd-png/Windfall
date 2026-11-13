//
//  EiraChatView.swift
//  Windfall
//
//  Talking to Eira.
//
//  This file is only what you see. The thinking happens elsewhere:
//    EiraConversation.swift     runs one conversation
//    EiraOnDeviceEngine.swift   runs the model
//    EiraTools.swift            the lookups and Eira's standing instructions
//
//  Three things are always visible, on purpose:
//    - her reasoning, in a box that opens when tapped
//    - every lookup she makes, with what came back and from where
//    - which model answered and how fast
//
//  The buttons above the text box force a lookup, because small models
//  are unreliable at deciding when to look something up. Pressing and
//  holding one of her replies lets you correct it, and she keeps that.
//

import SwiftUI
import SwiftData

// MARK: - Chat screen

struct EiraChatView: View {

    /// A question to send as soon as Eira is ready. Used when the chat is
    /// opened from her bar with something already typed.
    var openingQuestion: String? = nil
    @State private var hasSentOpeningQuestion = false

    /// What was on screen when the chat was opened from Eira's bar, such
    /// as "the plant Apple, Spartan". Eira is told this with each
    /// question. Nil when there is nothing to tell her.
    var lookingAt: String? = nil
    @State private var hasPassedOnScreen = false

    @Environment(\.modelContext) private var context

    @State private var conversation = EiraConversation()
    @State private var input = ""
    @State private var isLoadingModel = false
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var messageToCorrect: ChatMessage?
    @State private var voice = VoiceInput()
    @AppStorage("eiraSpeaksReplies") private var speaksReplies = false

    var body: some View {
        VStack(spacing: 0) {
            if let problem = conversation.setupProblem {
                unavailableBanner(problem)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if conversation.messages.isEmpty {
                            welcome
                        }

                        ForEach(conversation.messages) { message in
                            MessageView(message: message) {
                                messageToCorrect = message
                            }
                            .id(message.id)
                        }

                        if conversation.isGenerating {
                            StreamingView(conversation: conversation)
                                .id("streaming")
                        }

                        if let metrics = conversation.lastMetrics,
                           !conversation.isGenerating,
                           !metrics.summary.isEmpty {
                            Text([conversation.modelName, metrics.summary]
                                .compactMap { $0 }.joined(separator: " · "))
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
                .onChange(of: conversation.messages.count) { _, _ in
                    if let last = conversation.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            // Say plainly what Eira has been told about the screen, and
            // offer a way to take it back.
            if let note = conversation.screenNote {
                HStack(spacing: 8) {
                    Text("Eira knows you were looking at \(note).")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                    Spacer(minLength: 0)
                    Button("Don't use this") {
                        conversation.screenNote = nil
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.leaf)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }

            inputBar
        }
        .navigationTitle("Eira")
        .paperScreen()
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
                        showingHistory = true
                    } label: {
                        Label("Past conversations", systemImage: "clock.arrow.circlepath")
                    }
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Model and garden notes", systemImage: "gear")
                    }
                } label: {
                    Label("Options", systemImage: "ellipsis.circle")
                }
            }
        }
        // When the settings close, load whichever model is now chosen.
        .sheet(isPresented: $showingSettings, onDismiss: {
            Task { await loadEngine() }
        }) {
            EiraSettingsView()
                .macSheetSize(width: 520, height: 600)
        }
        .sheet(isPresented: $showingHistory) {
            EiraHistoryView { chat in
                conversation.open(chat)
                showingHistory = false
            }
            .macSheetSize()
        }
        .sheet(item: $messageToCorrect) { message in
            EiraCorrectionView(message: message) { correction in
                conversation.correct(message, with: correction)
            }
            .macSheetSize(width: 480, height: 420)
        }
        .task {
            // Before anything is sent, pass on what was open on screen.
            // Once only, so "Don't use this" is never quietly undone.
            if !hasPassedOnScreen {
                hasPassedOnScreen = true
                conversation.screenNote = lookingAt
            }
            await loadEngine()
            // Only look at what is already allowed. Opening Eira should
            // never put a permission box in front of you.
            voice.checkExistingPermission()
            // Send the question typed into Eira's bar, once. If she is not
            // available it is left in the text box so it is not lost.
            if let openingQuestion, !hasSentOpeningQuestion {
                hasSentOpeningQuestion = true
                if conversation.modelName != nil {
                    conversation.send(openingQuestion)
                } else {
                    input = openingQuestion
                }
            }
        }
        .onChange(of: conversation.isGenerating) { wasGenerating, isGenerating in
            // Read the reply aloud once it has finished, if asked to.
            guard wasGenerating, !isGenerating, speaksReplies,
                  let last = conversation.messages.last,
                  last.role == .assistant, !last.content.isEmpty else { return }
            voice.speak(last.content)
        }
    }

    // MARK: Loading the model

    /// Asks for an engine for the chosen model. If one cannot be made,
    /// the reason is shown in plain words at the top of the chat.
    private func loadEngine() async {
        isLoadingModel = true
        defer { isLoadingModel = false }

        let hub = EiraToolHub(context: context)
        do {
            let engine = try await EiraEngineFactory.make(choice: EiraModelChoice.load(), hub: hub)
            conversation.configure(engine: engine, hub: hub,
                                   store: EiraChatStore(context: context))
        } catch {
            conversation.setUnavailable(error.localizedDescription)
        }
    }

    // MARK: Pieces

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask about your garden")
                .font(.headline)

            if isLoadingModel {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Getting Eira ready…").font(.caption).foregroundStyle(.secondary)
                }
            }

            ForEach([
                "What's growing in Bed 3?",
                "What visits marjoram?",
                "What did I harvest this month?",
                "What should I sow this month?"
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

    private func unavailableBanner(_ problem: String) -> some View {
        HStack(alignment: .top) {
            Image(systemName: "exclamationmark.circle")
            Text(problem)
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
            // Manual override. Forces a lookup whether or not the model
            // would have decided to make one.
            if !input.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        forceButton("Look up species", tool: EiraTools.lookupSpecies)
                        forceButton("Search my plants", tool: EiraTools.searchGarden)
                        forceButton("What visits it", tool: EiraTools.plantVisitors)
                        forceButton("Search my notes", tool: EiraTools.searchNotes)
                        forceButton("Wikipedia", tool: EiraTools.searchWikipedia)
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Ask Eira…", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    // Return sends. Shift-Return or Option-Return starts a new
                    // line. `.ignored` hands the key back to the text box.
                    .onKeyPress(.return, phases: .down) { press in
                        if press.modifiers.contains(.shift) || press.modifiers.contains(.option) {
                            return .ignored
                        }
                        sendTypedMessage()
                        return .handled
                    }
                    // The same for keyboards that report "submit" instead.
                    .onSubmit { sendTypedMessage() }

                if voice.isAuthorised {
                    PushToTalkButton(voice: voice) { spoken in
                        conversation.send(spoken)
                    }
                    .scaleEffect(0.62)
                    .frame(width: 44, height: 44)
                } else {
                    // Voice stays off until you ask for it. Tapping this is
                    // what shows Apple's microphone and speech permission boxes.
                    Button {
                        Task { await voice.requestPermission() }
                    } label: {
                        Image(systemName: "mic.slash")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    .help("Turn on voice input")
                    .accessibilityLabel("Turn on voice input")
                }

                if conversation.isGenerating {
                    // While she is replying, the send button becomes stop.
                    Button {
                        conversation.stop()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                    }
                } else {
                    Button {
                        sendTypedMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(input.isEmpty || conversation.modelName == nil)
                }
            }
        }
        .padding(8)
    }

    /// Sends whatever is in the text box. Shared by the send button and
    /// the Return key, so both always behave the same way.
    private func sendTypedMessage() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, conversation.modelName != nil, !conversation.isGenerating else { return }
        input = ""
        conversation.send(text)
    }

    private func forceButton(_ title: String, tool: ToolDefinition) -> some View {
        Button {
            let text = input
            input = ""
            conversation.send(text, forcedTool: tool)
        } label: {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(conversation.isGenerating || conversation.modelName == nil)
    }
}

// MARK: - One message

private struct MessageView: View {

    let message: ChatMessage
    /// Called when "Correct this" is chosen on one of Eira's replies.
    let onCorrect: () -> Void
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
            .contextMenu {
                Button {
                    onCorrect()
                } label: {
                    Label("Correct this", systemImage: "pencil.and.outline")
                }
            }

        case .system:
            EmptyView()
        }
    }
}

// MARK: - Reasoning box

/// Collapsed by default. On a small model the thinking is routinely longer
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

// MARK: - Sheet size on the Mac

extension View {
    /// Gives a pop-up sheet a sensible size on the Mac.
    ///
    /// On iPhone and iPad a sheet fills the space it is given. On the Mac
    /// it shrinks to fit its contents, and a list has no natural size, so
    /// without this a sheet holding a list opens as a sliver.
    @ViewBuilder
    func macSheetSize(width: CGFloat = 480, height: CGFloat = 520) -> some View {
        #if os(macOS)
        // The paper goes behind the whole sheet, so that any strip the
        // sheet's own content does not reach is paper too, not grey.
        // Smallest, usual and largest sizes: it opens at the size given
        // and its edges can be dragged out to twice that.
        self.frame(minWidth: width, idealWidth: width, maxWidth: width * 2,
                   minHeight: height, idealHeight: height, maxHeight: height * 2)
            .presentationSizing(.fitted)
            .presentationBackground { PaperBackground() }
        #else
        self
        #endif
    }
}

// MARK: - Settings

/// Which model Eira uses, and what she is told about the garden.
struct EiraSettingsView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var kind: EiraModelChoice.Kind = .appleBuiltIn
    @State private var coreAIName = ""
    @State private var mlxName = ""
    @State private var gardenNotes = ""
    @State private var coreAIModels: [String] = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("This device", value: DeviceCapability.memoryDescription())
                    if !DeviceCapability.canRunEira() {
                        Label("Eira needs at least \(DeviceCapability.minimumMemoryGB)GB. The rest of Windfall works as normal.",
                              systemImage: "exclamationmark.circle")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Memory")
                }

                Section {
                    Picker("Kind", selection: $kind) {
                        ForEach(EiraModelChoice.Kind.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }

                    switch kind {
                    case .appleBuiltIn:
                        Text("The model Apple includes with the system. Nothing to download.")
                            .font(.callout).foregroundStyle(.secondary)

                    case .coreAI:
                        if coreAIModels.isEmpty {
                            Text("No Core AI models found yet.")
                                .font(.callout).foregroundStyle(.secondary)
                        } else {
                            Picker("Model", selection: $coreAIName) {
                                ForEach(coreAIModels, id: \.self) { name in
                                    Text(name).tag(name)
                                }
                            }
                        }

                    case .mlx:
                        TextField("mlx-community/…", text: $mlxName)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif

                    case .online:
                        Text("Not set up yet. Everything Eira does stays on this device.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Model")
                } footer: {
                    switch kind {
                    case .coreAI:
                        Text("Copy a converted model's folder into Windfall's Models folder using the Files app, then come back here.")
                    case .mlx:
                        Text("The model's name on Hugging Face. It is downloaded the first time it is used, so that first reply needs a connection.")
                    case .appleBuiltIn, .online:
                        EmptyView()
                    }
                }

                Section {
                    TextEditor(text: $gardenNotes)
                        .frame(minHeight: 140)
                } header: {
                    Text("What Eira knows about your garden")
                } footer: {
                    Text("Eira reads this before every conversation. Keep it short and factual: your sites, soil, methods and anything she should always bear in mind. Check the starting text is right.")
                }
            }
            .navigationTitle("Eira")
            .paperScreen()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        save()
                        dismiss()
                    }
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        let choice = EiraModelChoice.load()
        kind = choice.kind
        coreAIModels = EiraModelLibrary.coreAIModelNames()
        coreAIName = choice.kind == .coreAI ? choice.value : (coreAIModels.first ?? "")
        mlxName = choice.kind == .mlx ? choice.value : ""
        gardenNotes = EiraGardenNotes.load()
    }

    private func save() {
        let value: String
        switch kind {
        case .coreAI: value = coreAIName
        case .mlx:    value = mlxName.trimmingCharacters(in: .whitespaces)
        case .appleBuiltIn, .online: value = ""
        }
        EiraModelChoice(kind: kind, value: value).save()
        EiraGardenNotes.save(gardenNotes)
    }
}

// MARK: - Past conversations

struct EiraHistoryView: View {

    /// Called with the conversation that was tapped.
    let onOpen: (EiraChat) -> Void

    @Query(sort: [SortDescriptor(\EiraChat.updatedAt, order: .reverse)])
    private var chats: [EiraChat]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if chats.isEmpty {
                    ContentUnavailableView("No saved conversations",
                                           systemImage: "bubble.left.and.bubble.right")
                }
                ForEach(chats) { chat in
                    Button {
                        onOpen(chat)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(chat.title.isEmpty ? "Conversation" : chat.title)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Text(chat.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(chats[index]) }
                }
            }
            .navigationTitle("Past conversations")
            .paperScreen()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Putting Eira right

/// Records what was wrong with a reply. Eira reads her recent corrections
/// before every conversation, so the same mistake is not made twice.
struct EiraCorrectionView: View {

    let message: ChatMessage
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var correction = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Eira said") {
                    Text(message.content)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(8)
                }
                Section {
                    TextEditor(text: $correction)
                        .frame(minHeight: 100)
                } header: {
                    Text("What is right")
                } footer: {
                    Text("Write it as a plain fact, such as \"My lavender is English lavender, not Dutch.\" Eira will be told this from now on.")
                }
            }
            .navigationTitle("Correct this")
            .paperScreen()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(correction)
                        dismiss()
                    }
                    .disabled(correction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
