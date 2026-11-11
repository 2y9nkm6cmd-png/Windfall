//
//  VoiceInput.swift
//  Windfall
//
//  Push-to-talk, for using Eira with muddy hands.
//
//  A note on the API choice. iOS 26 introduced SpeechAnalyzer, which is
//  Apple's newer and better transcription framework. This uses the older
//  SFSpeechRecognizer instead, for one reason: with
//  requiresOnDeviceRecognition set, it is equally offline and private,
//  it is stable and thoroughly documented, and it works back to much
//  older systems. Worth migrating to SpeechAnalyzer once you have run
//  this and know the surrounding code works — but not both changes at once.
//
//  Design decisions:
//  - Push and hold, not a wake word. iOS won't let a third-party app
//    listen for arbitrary wake words in the background anyway, and
//    keeping the mic live all afternoon flattens the battery.
//  - Partial results shown live, so it feels responsive.
//  - Spoken replies are optional and off by default. Reading is faster.
//

import Foundation
import Speech
import AVFoundation
import SwiftUI

@Observable
@MainActor
final class VoiceInput: NSObject {

    private(set) var transcript = ""
    private(set) var isListening = false
    private(set) var isAuthorised = false
    private(set) var lastError: String?
    /// Rough input level, for the waveform.
    private(set) var level: Float = 0

    private let recogniser = SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private let synthesiser = AVSpeechSynthesizer()

    // MARK: Permission

    /// Looks at what has already been allowed, without asking for anything.
    /// Safe to call whenever a screen opens, because it never puts a
    /// permission box in front of you.
    func checkExistingPermission() {
        let speech = SFSpeechRecognizer.authorizationStatus() == .authorized
        #if os(iOS)
        let mic = AVAudioApplication.shared.recordPermission == .granted
        #else
        let mic = true
        #endif
        isAuthorised = speech && mic
    }

    /// Asks for permission. This is the call that shows Apple's permission
    /// boxes, so it should only run when you have tapped something to say
    /// you want voice input.
    func requestPermission() async {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        #if os(iOS)
        let mic = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        #else
        let mic = true
        #endif

        isAuthorised = speech && mic
        if !isAuthorised {
            lastError = "Windfall needs microphone and speech permission to listen."
        }
    }

    // MARK: Listening

    func startListening() {
        guard isAuthorised, !isListening else { return }
        guard let recogniser, recogniser.isAvailable else {
            lastError = "Speech recognition isn't available right now."
            return
        }

        // Stop any speaking first, or the synthesiser talks over the mic.
        if synthesiser.isSpeaking {
            synthesiser.stopSpeaking(at: .immediate)
        }

        transcript = ""
        lastError = nil

        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            #endif

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            // Everything stays on the device. Slightly less accurate than
            // the server model, and worth it for working in a field.
            request.requiresOnDeviceRecognition = true
            self.request = request

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)

            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                request.append(buffer)
                self?.updateLevel(from: buffer)
            }

            engine.prepare()
            try engine.start()
            isListening = true

            task = recogniser.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                    }
                    if error != nil || (result?.isFinal ?? false) {
                        self.stopListening()
                    }
                }
            }

        } catch {
            lastError = error.localizedDescription
            stopListening()
        }
    }

    func stopListening() {
        guard isListening || engine.isRunning else { return }

        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()

        request = nil
        task = nil
        isListening = false
        level = 0

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private nonisolated func updateLevel(from buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frames { sum += abs(channel[i]) }
        let average = frames > 0 ? sum / Float(frames) : 0

        Task { @MainActor in
            // Smoothed, so the waveform doesn't jitter.
            self.level = self.level * 0.7 + min(average * 12, 1) * 0.3
        }
    }

    // MARK: Speaking

    func speak(_ text: String) {
        guard !text.isEmpty else { return }

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        synthesiser.speak(utterance)
    }

    func stopSpeaking() {
        synthesiser.stopSpeaking(at: .immediate)
    }

    var isSpeaking: Bool { synthesiser.isSpeaking }
}

// MARK: - Push-to-talk button

/// Hold to speak, release to send. Deliberately large — this gets used
/// one-handed, outdoors, without looking closely.
struct PushToTalkButton: View {

    @Bindable var voice: VoiceInput
    var onFinish: (String) -> Void

    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 8) {
            if voice.isListening {
                VStack(spacing: 6) {
                    WaveformView(level: voice.level)
                        .frame(height: 28)

                    Text(voice.transcript.isEmpty ? "Listening…" : voice.transcript)
                        .font(.callout)
                        .foregroundStyle(voice.transcript.isEmpty ? .secondary : .primary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .animation(.default, value: voice.transcript)
                }
                .padding(.horizontal)
                .transition(.opacity)
            }

            Image(systemName: voice.isListening ? "mic.fill" : "mic")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(
                    Circle().fill(voice.isListening ? Color.red : Color.accentColor)
                )
                .scaleEffect(isPressed ? 1.12 : 1)
                .animation(.spring(duration: 0.2), value: isPressed)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard !isPressed else { return }
                            isPressed = true
                            voice.startListening()
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            #endif
                        }
                        .onEnded { _ in
                            isPressed = false
                            let text = voice.transcript
                            voice.stopListening()
                            if !text.isEmpty { onFinish(text) }
                        }
                )

            if !voice.isListening {
                Text("Hold to speak")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.default, value: voice.isListening)
    }
}

// MARK: - Waveform

private struct WaveformView: View {

    let level: Float
    @State private var phase = 0.0

    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { context, size in
                let bars = 24
                let width = size.width / CGFloat(bars * 2)

                for i in 0..<bars {
                    let offset = Double(i) / Double(bars)
                    let wave = sin(offset * .pi * 3 + phase) * 0.5 + 0.5
                    let height = max(3, size.height * CGFloat(wave) * CGFloat(level))

                    let rect = CGRect(
                        x: CGFloat(i) * width * 2,
                        y: (size.height - height) / 2,
                        width: width,
                        height: height
                    )
                    context.fill(Path(roundedRect: rect, cornerRadius: width / 2),
                                 with: .color(.accentColor))
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Voice settings

struct VoiceSettingsView: View {

    @AppStorage("eiraSpeaksReplies") private var speaksReplies = false
    @State private var voice = VoiceInput()

    var body: some View {
        Form {
            Section {
                if voice.isAuthorised {
                    Label("Microphone and speech ready", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                } else {
                    Button("Allow microphone and speech") {
                        Task { await voice.requestPermission() }
                    }
                }
            } header: {
                Text("Permission")
            } footer: {
                Text("Transcription runs entirely on the device. Nothing is sent to Apple or anyone else.")
            }

            Section {
                Toggle("Read replies aloud", isOn: $speaksReplies)
            } footer: {
                Text("Off by default — reading is usually quicker. Useful when your hands are full.")
            }

            if let error = voice.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("Voice")
    }
}
