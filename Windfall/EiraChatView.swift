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
//  A photo can be given to her with the camera button beside the text
//  box (14 November 2026). Her answer to it is a card, drawn by
//  IdentifyCards.swift from the rules in EiraIdentify.swift. Naming a
//  photo does not use her text model, so it works even where no text
//  model can run. Asking her about the species afterwards does.
//

import SwiftUI
import UniformTypeIdentifiers
import SwiftData
import PhotosUI

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
    @State private var showingCorrections = false
    @State private var voice = VoiceInput()
    @AppStorage("eiraSpeaksReplies") private var speaksReplies = false

    // Giving her a photo.
    /// True while the Photos library is open to choose one.
    @State private var isChoosingPhoto = false
    /// True while a file window is open to choose one.
    @State private var isChoosingPhotoFile = false
    /// The photo chosen in the Photos library, until it has been read.
    @State private var pickedPhoto: PhotosPickerItem?
    /// The answers a sighting has been started from, by the id of her
    /// reply, so each shows "Added" in place of its button.
    @State private var sightingsAdded: Set<UUID> = []

    /// The name of the marker at the bottom of the conversation.
    private let endOfChat = "end of chat"

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
                            if let identification = conversation.identifications[message.id] {
                                // Her answer to a photo is drawn as a
                                // card, with what can be done with it.
                                ChatIdentification(
                                    identification: identification,
                                    isAdded: sightingsAdded.contains(message.id),
                                    canAsk: conversation.modelName != nil && !conversation.isGenerating,
                                    onAdd: { addSighting(for: message.id, from: identification) },
                                    onAsk: { question, name in
                                        conversation.send(question, forcedTool: EiraTools.lookupSpecies, about: name)
                                    })
                                    .id(message.id)
                            } else {
                                // A photo of yours sits above the
                                // message it came with.
                                if let photo = conversation.photos[message.id] {
                                    PhotoBubble(data: photo)
                                }
                                MessageView(message: message) {
                                    messageToCorrect = message
                                }
                                .id(message.id)
                            }

                            // A message of yours that put Eira right is
                            // followed by a card offering to keep it.
                            if let offer = conversation.offeredCorrection, offer.messageID == message.id {
                                CorrectionOfferCard(
                                    offer: offer,
                                    onKeep: { words in conversation.keepOfferedCorrection(as: words) },
                                    onUndo: { conversation.undoKeptCorrection() },
                                    onDismiss: { conversation.dismissOfferedCorrection() },
                                    onShowAll: { showingCorrections = true })
                            }
                        }

                        if conversation.isGenerating {
                            StreamingView(conversation: conversation)
                                .id("streaming")
                        }

                        if conversation.isLooking {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Looking at the photo…")
                                    .font(.callout)
                                    .foregroundStyle(Theme.inkSoft)
                            }
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

                        // Nothing to see: a marker at the very end, for
                        // the list to scroll to.
                        Color.clear
                            .frame(height: 1)
                            .id(endOfChat)
                    }
                    .padding()
                }
                // Keep the newest thing in view: a message, the reply as
                // it arrives, or a card offering to keep a correction.
                // Each `onChange` runs its closure when the value it
                // names changes. `proxy` is what can move the list.
                .onChange(of: conversation.streamingContent) { _, _ in
                    withAnimation { proxy.scrollTo(endOfChat, anchor: .bottom) }
                }
                .onChange(of: conversation.messages.count) { _, _ in
                    withAnimation { proxy.scrollTo(endOfChat, anchor: .bottom) }
                }
                .onChange(of: conversation.offeredCorrection?.messageID) { _, _ in
                    withAnimation { proxy.scrollTo(endOfChat, anchor: .bottom) }
                }
                .onChange(of: conversation.isLooking) { _, _ in
                    withAnimation { proxy.scrollTo(endOfChat, anchor: .bottom) }
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
                        showingCorrections = true
                    } label: {
                        Label("Corrections", systemImage: "pencil.and.outline")
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
        }
        .sheet(isPresented: $showingCorrections) {
            EiraCorrectionsView { correction in
                conversation.remove(correction)
            }
        }
        // A photo for her from the Photos library. Choosing one sets
        // `pickedPhoto`, and the `onChange` below reads it.
        .photosPicker(isPresented: $isChoosingPhoto, selection: $pickedPhoto, matching: .images)
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            pickedPhoto = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { await look(at: data) }
            }
        }
        // Or one that is a file, which on a Mac is often where they are.
        .fileImporter(isPresented: $isChoosingPhotoFile, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            // Leave to read a file chosen in a file window lasts only
            // between these two calls.
            let hasLeave = url.startAccessingSecurityScopedResource()
            defer { if hasLeave { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) {
                Task { await look(at: data) }
            }
        }
        .task {
            // Before anything is sent, pass on what was open on screen.
            // Once only, so "Don't use this" is never quietly undone.
            if !hasPassedOnScreen {
                hasPassedOnScreen = true
                conversation.screenNote = lookingAt
            }
            await loadEngine()
            // A checking aid: an example exchange, so a still picture can
            // be taken of the chat. See DemoGarden.opens.
            // `eira-photo` shows her answer to a photo instead.
            if DemoGarden.opens == "eira-photo" {
                conversation.showExamplePhoto(answeredBy: EiraIdentify.example(in: context))
            }
            if DemoGarden.opens == "eira" || DemoGarden.opens == "corrections" {
                let listed = DemoGarden.opens == "corrections"
                conversation.showExample(in: EiraChatStore(context: context), kept: listed)
                showingCorrections = listed
            }
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
                // Give her a photo to name. A Menu is a button that
                // opens a short list of choices.
                Menu {
                    Button {
                        isChoosingPhoto = true
                    } label: {
                        Label("From Photos", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        isChoosingPhotoFile = true
                    } label: {
                        Label("From a file", systemImage: "folder")
                    }
                } label: {
                    Image(systemName: "camera")
                        .frame(width: 32, height: 32)
                }
                .menuStyle(.button)
                .buttonStyle(.borderless)
                .menuIndicator(.hidden)
                .fixedSize()
                .disabled(conversation.isGenerating || conversation.isLooking)
                .help("Ask what is in a photo")
                .accessibilityLabel("Ask what is in a photo")

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

    // MARK: Photos

    /// Gives Eira a photo and puts her answer into the conversation.
    ///
    /// Three steps. The photo joins the conversation as your message.
    /// The image model and the fixed rules work out an answer
    /// (EiraIdentify.identify). The answer joins the conversation, or
    /// the reason there is none does.
    ///
    /// The photo is kept at no more than 1024 pixels on its longest
    /// side, as on the Identify screen: plenty to name from and to keep
    /// with a sighting.
    private func look(at data: Data) async {
        // The month it was taken is read first: shrinking loses it.
        let taken = SpeciesEye.monthTaken(of: data)
        let photo = DiaryEntryEditor.thumbnail(from: data, maxDimension: 1024) ?? data
        guard let photoID = conversation.givePhoto(photo) else { return }
        do {
            let identification = try await EiraIdentify.identify(photo: photo, taken: taken, context: context)
            conversation.answerPhoto(photoID, with: identification)
        } catch let problem {
            conversation.photoFailed(problem.localizedDescription)
        }
    }

    /// Starts an unconfirmed sighting from one of her answers, with the
    /// photo it was about. This is the only thing here that saves to
    /// your records, and only when you press its button.
    private func addSighting(for replyID: UUID, from identification: EiraIdentification) {
        let photo = conversation.photoBehind[replyID].flatMap { conversation.photos[$0] }
        EiraIdentify.startSighting(from: identification, photo: photo, in: context)
        sightingsAdded.insert(replyID)
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

                // In plain sight under every reply. Until 14 November
                // 2026 it was only in the menu that a press and hold (or
                // a right-click) brings up, where nobody would find it.
                if !message.content.isEmpty {
                    Button {
                        onCorrect()
                    } label: {
                        Label("Correct this", systemImage: "pencil.and.outline")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.inkSoft)
                    .help("Tell Eira what was wrong. She is told it at the start of every conversation.")
                }
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
    // Bringing a model in from a folder.
    @State private var isChoosingFolder = false
    @State private var isCopying = false
    @State private var importProblem: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("This device", value: DeviceCapability.memoryDescription())
                    if !DeviceCapability.canRunDownloadedModels() {
                        Label(EiraEngineFactory.builtInModelIsAvailable
                              ? "A downloaded model needs at least \(DeviceCapability.minimumMemoryGB)GB. On this device Eira uses Apple's built-in model."
                              : "A downloaded model needs at least \(DeviceCapability.minimumMemoryGB)GB, and Apple's built-in model is not available on this device. The rest of Windfall works as normal.",
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
                        // Opens a file window to choose a converted
                        // model's folder. Windfall then copies it in.
                        Button {
                            isChoosingFolder = true
                        } label: {
                            HStack(spacing: 8) {
                                Text("Add a model from a folder…")
                                if isCopying { ProgressView().controlSize(.small) }
                            }
                        }
                        .disabled(isCopying)
                        if let importProblem {
                            Label(importProblem, systemImage: "exclamationmark.triangle")
                                .font(.callout)
                                .foregroundStyle(.orange)
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
                        Text("Choose the folder a model was converted into: the one holding metadata.json. Windfall keeps its own copy, which on the same disk takes no extra room.")
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
            // `.folder` limits the file window to folders.
            .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
                switch result {
                case .success(let folder): bringIn(folder)
                case .failure(let error): importProblem = error.localizedDescription
                }
            }
        }
    }

    /// Copies the chosen folder in, away from the main thread, then
    /// chooses the new model.
    private func bringIn(_ folder: URL) {
        isCopying = true
        importProblem = nil
        Task {
            do {
                let name = try await Task.detached(priority: .userInitiated) {
                    try EiraModelLibrary.importModel(from: folder)
                }.value
                coreAIModels = EiraModelLibrary.coreAIModelNames()
                coreAIName = name
            } catch {
                importProblem = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isCopying = false
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
///
/// Built from the pieces in SheetParts.swift, like the app's other
/// sheets. It was a standard Form until 14 November 2026.
struct EiraCorrectionView: View {

    let message: ChatMessage
    let onSave: (String) -> Void

    /// How to close the sheet, handed down by SwiftUI.
    @Environment(\.dismiss) private var dismiss
    @State private var correction = ""

    /// What was typed, without the spaces and blank lines around it.
    private var trimmed: String {
        correction.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        SheetPage("Correct this",
                  detail: "Eira is told her \(EiraChatStore.correctionsRead) newest corrections at the start of every conversation.",
                  confirmTitle: "Keep",
                  canConfirm: !trimmed.isEmpty,
                  onConfirm: {
                      onSave(trimmed)
                      dismiss()
                  }) {
            SheetScroll {
                SheetCard("Eira said") {
                    Text(message.content)
                        .font(.callout)
                        .foregroundStyle(Theme.inkSoft)
                        // No more than eight lines of a long reply.
                        .lineLimit(8)
                }

                SheetCard("What is right") {
                    FieldBox {
                        // `axis: .vertical` lets the box grow downwards as
                        // you type, from three lines up to eight.
                        TextField("My lavender is English lavender, not Dutch.",
                                  text: $correction, axis: .vertical)
                            .lineLimit(3...8)
                    }
                    Text("Write it as a plain fact. It is a note she is handed, not training: the model itself does not change.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                    if trimmed.count > EiraChecks.correctionLimit {
                        Text("Only the first \(EiraChecks.correctionLimit) characters are read to her. This is \(trimmed.count).")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }
}

// MARK: - Offering to keep a correction

/// "Keep this as a correction?" Shown under a message of yours that
/// reads as putting Eira right. EiraChecks.correctionWords decides
/// which messages those are.
///
/// Nothing is kept until "Keep it" is pressed, and the words can be
/// changed first. Once kept, the card shrinks to a line that says so
/// and offers to take it back.
private struct CorrectionOfferCard: View {

    private let offer: EiraConversation.OfferedCorrection
    private let onKeep: (String) -> Void
    private let onUndo: () -> Void
    private let onDismiss: () -> Void
    private let onShowAll: () -> Void

    /// The fact as it stands on the card.
    @State private var words: String

    init(offer: EiraConversation.OfferedCorrection,
         onKeep: @escaping (String) -> Void,
         onUndo: @escaping () -> Void,
         onDismiss: @escaping () -> Void,
         onShowAll: @escaping () -> Void) {
        self.offer = offer
        self.onKeep = onKeep
        self.onUndo = onUndo
        self.onDismiss = onDismiss
        self.onShowAll = onShowAll
        // `_words` is the storage behind `@State var words`. This is how
        // a starting value is handed to it.
        _words = State(initialValue: offer.words)
    }

    private var trimmed: String {
        words.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        if offer.isKept {
            keptLine
        } else {
            OfferFrame("Keep this as a correction?",
                       addTitle: "Keep it",
                       refuseTitle: "No thanks",
                       canAdd: !trimmed.isEmpty,
                       onAdd: { onKeep(trimmed) },
                       onRefuse: onDismiss) {
                FieldBox {
                    TextField("What is right", text: $words, axis: .vertical)
                        .lineLimit(1...5)
                }
                Text("Eira would be told this at the start of every conversation. Nothing is kept unless you press Keep it.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    /// What the card becomes once the correction is kept.
    private var keptLine: some View {
        HStack(spacing: 10) {
            Label("Kept as a correction", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Theme.leaf)
            Button("Undo") { onUndo() }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.inkSoft)
                .underline()
            Button("See all") { onShowAll() }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.inkSoft)
                .underline()
        }
        .font(.caption)
    }
}

// MARK: - What Eira has been told

/// Every correction kept so far, newest first, each with a button to
/// remove it. Opened from the chat's Options menu.
///
/// A correction is handed to the model as right "even if you believe
/// otherwise". So there must be somewhere to read them and to take a
/// wrong one back, and until 14 November 2026 there was not.
struct EiraCorrectionsView: View {

    /// Called with a correction to remove.
    let onRemove: (EiraCorrection) -> Void

    // `@Query` reads these from the database and keeps the list up to
    // date: when one is removed, its card goes without being told to.
    @Query(sort: [SortDescriptor(\EiraCorrection.createdAt, order: .reverse)])
    private var corrections: [EiraCorrection]

    private var detail: String {
        let read = EiraChatStore.correctionsRead
        if corrections.count > read {
            return "All \(corrections.count) are kept. Eira is told the newest \(read) at the start of every conversation, and any other when a question touches on it."
        }
        return "Eira is told these at the start of every conversation, and again with any question that touches on one."
    }

    var body: some View {
        SheetPage("Corrections", detail: detail, dismissTitle: "Done") {
            SheetScroll {
                if corrections.isEmpty {
                    SheetCard {
                        Text("Nothing yet. When Eira gets something wrong, press \"Correct this\" under her reply, or simply tell her: \"No, that's wrong. It's a Bramley.\"")
                            .font(.callout)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }

                // `enumerated()` pairs each correction with its place in
                // the list, counting from 0, so the eleventh onward can
                // be marked as not being read to her.
                ForEach(Array(corrections.enumerated()), id: \.element.id) { place, correction in
                    SheetCard {
                        Text(correction.correction)
                            .foregroundStyle(Theme.ink)
                            .textSelection(.enabled)

                        if !correction.topic.isEmpty {
                            Text("You had asked: \(EiraChatStore.title(from: correction.topic, limit: 80))")
                                .font(.footnote)
                                .foregroundStyle(Theme.inkSoft)
                        }

                        HStack {
                            Text(correction.createdAt.formatted(date: .abbreviated, time: .shortened)
                                 + (place >= EiraChatStore.correctionsRead ? " · only when a question touches on it" : ""))
                                .font(.caption)
                                .foregroundStyle(Theme.inkSoft)
                            Spacer()
                            Button("Remove") { onRemove(correction) }
                                .buttonStyle(QuietGlassButton())
                        }
                    }
                }
            }
        }
    }
}
