//
//  EiraVision.swift
//  Windfall
//
//  Sending a photograph to Eira for identification.
//
//  This is the middle tier of the three we agreed: the Mac's larger
//  vision model, reached over Tailscale. The phone's on-device model
//  handles coarse grouping; iNaturalist's classifier handles species.
//
//  The prompt is written to make the model behave like a careful
//  naturalist rather than a confident one — give the features it is
//  actually using, name the confusion species, and say plainly when a
//  photograph cannot settle the question. Many UK invertebrates cannot
//  be identified to species from an image by anyone.
//

import Foundation
import SwiftUI
import SwiftData
import PhotosUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Vision request

extension RemoteBackend {

    /// Sends an image with a question. Uses the OpenAI vision message
    /// shape, which Ollama accepts for multimodal models.
    func identify(imageData: Data, question: String, model visionModel: String)
        async throws -> String {

        let base64 = imageData.base64EncodedString()

        var request = URLRequest(url: visionEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180

        let body: [String: Any] = [
            "model": visionModel,
            "stream": false,
            "messages": [
                ["role": "system", "content": EiraVisionPrompt.system],
                ["role": "user", "content": [
                    ["type": "text", "text": question],
                    ["type": "image_url",
                     "image_url": ["url": "data:image/jpeg;base64,\(base64)"]]
                ]]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw BackendError.badResponse((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw BackendError.decoding("unexpected response shape")
        }

        return content
    }

    private var visionEndpoint: URL {
        // Same base as chat; the property is private on the class, so
        // rebuild from the stored name is not possible — instead this
        // relies on the caller having configured a working backend.
        URL(string: UserDefaults.standard.string(forKey: "eiraHost") ?? "http://localhost:11434")!
            .appendingPathComponent("v1/chat/completions")
    }
}

enum EiraVisionPrompt {
    static let system = """
    You are identifying a plant or animal from a photograph, for a \
    naturalist recording in the UK.

    Always answer in this order:
    1. What you can see — the features you are actually using.
    2. The most likely identification, with the scientific name.
    3. Your confidence: certain, probable, possible, or not identifiable.
    4. Species it could be confused with.
    5. What would settle it — a photograph of a different feature, or \
    examination under a lens.

    Rules:
    - Prefer a coarse identification you are sure of over a species-level \
    one you are not. "A hoverfly, probably Eristalis" is more useful than \
    a confident wrong species.
    - Many UK invertebrates cannot be identified to species from a \
    photograph by anyone. Say so when that is the case.
    - Never identify fungi. Explain that misidentification can be fatal \
    and that a local expert or foray group should be consulted.
    - Use British spelling. Be brief.
    """
}

// MARK: - Identification screen

struct IdentifyView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage("eiraHost") private var host = ""
    @AppStorage("eiraVisionModel") private var visionModel = "qwen2.5vl:7b"

    @State private var pickerItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var answer: String?
    @State private var isWorking = false
    @State private var error: String?
    @State private var question = "What is this?"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let imageData, let image = displayImage(imageData) {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label(imageData == nil ? "Choose a photo" : "Choose a different photo",
                              systemImage: "camera")
                    }
                } header: {
                    Text("Photo")
                } footer: {
                    Text("Sent to your Mac over Tailscale. Nothing leaves your own network.")
                }

                if imageData != nil {
                    Section("Question") {
                        TextField("What would you like to know?", text: $question, axis: .vertical)

                        Button {
                            Task { await identify() }
                        } label: {
                            if isWorking {
                                HStack { ProgressView(); Text("Looking…") }
                            } else {
                                Label("Ask Eira", systemImage: "sparkles")
                            }
                        }
                        .disabled(isWorking || host.isEmpty)
                    }
                }

                if let answer {
                    Section {
                        Text(answer)
                            .textSelection(.enabled)
                    } header: {
                        Text("Eira says")
                    } footer: {
                        Text("This is a suggestion, not a record. Nothing is saved until you create a sighting and confirm the identification yourself.")
                    }

                    Section {
                        Button {
                            createObservation()
                        } label: {
                            Label("Start a sighting from this", systemImage: "plus.circle")
                        }
                    }
                }

                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }

                if host.isEmpty {
                    Section {
                        Label("Set the model server address in the Eira tab first.",
                              systemImage: "info.circle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Identify")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    // Downscale before sending — a 12 MP photo is slow to
                    // upload and no more identifiable than a 1024 px one.
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        imageData = DiaryEntryEditor.thumbnail(from: data, maxDimension: 1024) ?? data
                        answer = nil
                    }
                }
            }
        }
    }

    private func identify() async {
        guard let imageData, let url = URL(string: host) else { return }
        isWorking = true
        error = nil
        defer { isWorking = false }

        let backend = RemoteBackend(baseURL: url, model: visionModel)
        do {
            answer = try await backend.identify(imageData: imageData,
                                                question: question,
                                                model: visionModel)
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Creates an unconfirmed sighting with the photo attached. The
    /// suggestion goes into provisionalID, never confirmedID.
    private func createObservation() {
        let observation = WildlifeObservation()
        observation.provisionalID = answer
        observation.provisionalSource = .desktopModel
        observation.provisionalConfidence = .possible
        observation.recorderName = UserDefaults.standard.string(forKey: "recorderName")
        observation.notes = "Suggested by Eira from a photograph. Needs confirming."

        if let imageData {
            let photo = Photo()
            photo.imageData = imageData
            photo.thumbnailData = DiaryEntryEditor.thumbnail(from: imageData)
            photo.observation = observation
            observation.photos = [photo]
        }

        context.insert(observation)
        dismiss()
    }

    private func displayImage(_ data: Data) -> Image? {
        #if os(iOS)
        guard let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
        #elseif os(macOS)
        guard let ns = NSImage(data: data) else { return nil }
        return Image(nsImage: ns)
        #endif
    }
}
