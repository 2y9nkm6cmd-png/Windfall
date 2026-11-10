//
//  EiraVision.swift
//  Windfall
//
//  Identifying a plant or animal from a photograph.
//
//  STATUS: the screen is here, the identification is not yet. The first
//  version sent the photo to a model server on the Mac. That has been
//  removed, because Eira now runs only on the device in your hand. The
//  replacement is a small vision model run by Core AI, which is the next
//  piece of work after the chat. Until then this screen can still attach
//  a photo to a new sighting for you to identify yourself.
//
//  The prompt is written to make the model behave like a careful
//  naturalist rather than a confident one: give the features it is
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

// MARK: - Instructions for the vision model

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
                    Text("The photo stays on this device.")
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
                        .disabled(isWorking)
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

                if imageData != nil, answer == nil {
                    Section {
                        Button {
                            createObservation()
                        } label: {
                            Label("Save as a sighting to identify later", systemImage: "plus.circle")
                        }
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

    /// On-device photo identification is not built yet, so this explains
    /// that and leaves the photo ready to save as a sighting.
    private func identify() async {
        guard imageData != nil else { return }
        answer = nil
        error = "Photo identification on this device is not built yet. You can still save the photo as a sighting and identify it yourself."
    }

    /// Creates an unconfirmed sighting with the photo attached. The
    /// suggestion goes into provisionalID, never confirmedID.
    private func createObservation() {
        let observation = WildlifeObservation()
        observation.recorderName = UserDefaults.standard.string(forKey: "recorderName")
        if let answer {
            observation.provisionalID = answer
            observation.provisionalSource = .onDeviceModel
            observation.provisionalConfidence = .possible
            observation.notes = "Suggested by Eira from a photograph. Needs confirming."
        } else {
            observation.notes = "Photo saved without an identification."
        }

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
