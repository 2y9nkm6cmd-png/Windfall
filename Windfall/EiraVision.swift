//
//  EiraVision.swift
//  Windfall
//
//  Identifying a plant or animal from a photograph.
//
//  How it works now (13 November 2026). The photo is matched against a
//  list of UK species by BioCLIP 2, a model that runs on this device
//  through Core AI. SpeciesEye.swift runs it and SpeciesTable.swift does
//  the matching. It names a species only when the match is strong, and
//  otherwise says it is not sure and shows the closest few. It cannot
//  describe a photo or answer a question about it: it only matches.
//
//  If the model's files are not on the device, the screen says so and
//  the photo can still be saved as a sighting to identify yourself.
//
//  The prompt below is not used yet. It is kept for a later model that
//  can look at a photo and talk about it. It is written to make such a
//  model behave like a careful naturalist rather than a confident one:
//  give the features it is actually using, name the confusion species,
//  and say plainly when a photograph cannot settle the question. Many UK
//  invertebrates cannot be identified to species from an image by anyone.
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
    /// What the model made of the photo, kept so that a sighting can be
    /// started from the name and not from the whole sentence.
    @State private var guess: SpeciesGuess?
    @State private var isWorking = false
    @State private var error: String?

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
                    Section {
                        Button {
                            Task { await identify() }
                        } label: {
                            if isWorking {
                                HStack { ProgressView(); Text("Looking…") }
                            } else {
                                Label("What is this?", systemImage: "sparkles")
                            }
                        }
                        .disabled(isWorking)
                    } footer: {
                        Text("Eira compares the photo with a list of UK plants and animals. She never names fungi.")
                    }
                }

                if let answer {
                    Section {
                        Text(answer)
                            .textSelection(.enabled)
                    } header: {
                        Text("Eira says")
                    } footer: {
                        Text((SpeciesEye.shared.table?.caveat ?? "Treat a match as a suggestion to check.")
                             + " Nothing is saved until you create a sighting and confirm the identification yourself.")
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
            .paperScreen()
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
                        guess = nil
                        error = nil
                    }
                }
            }
        }
    }

    /// Asks the on-device model what the photo most resembles.
    ///
    /// `async` because loading the model the first time takes a moment
    /// and the screen must stay usable meanwhile. `defer` runs when the
    /// function ends by any route, so the "Looking…" spinner always
    /// stops, even after an error.
    private func identify() async {
        guard let imageData else { return }
        isWorking = true
        answer = nil
        guess = nil
        error = nil
        defer { isWorking = false }

        do {
            let found = try await SpeciesEye.shared.guess(forPhoto: imageData)
            guess = found
            answer = found.summary
        } catch let problem {
            // The error's own words say what is missing and what can
            // still be done. See SpeciesEyeError.
            error = problem.localizedDescription
        }
    }

    /// Creates an unconfirmed sighting with the photo attached. The
    /// suggestion goes into provisionalID, never confirmedID.
    private func createObservation() {
        let observation = WildlifeObservation()
        observation.recorderName = UserDefaults.standard.string(forKey: "recorderName")
        if let guess, let top = guess.likeliest {
            let closest = guess.candidates
                .map { "\($0.entry.title), \($0.percent)" }
                .joined(separator: "; ")
            if guess.isSure {
                // A strong match becomes the provisional name. It is
                // still only a suggestion until you confirm it.
                observation.provisionalID = top.entry.scientific
                observation.provisionalSource = .onDeviceModel
                observation.provisionalConfidence = .probable
                observation.notes = "Suggested by Eira from a photograph (\(closest)). Needs confirming."
            } else {
                // A weak match is not written in as a name at all.
                observation.notes = "Eira was not sure from the photograph. Closest: \(closest)."
            }
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
