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
import UniformTypeIdentifiers

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

/// Choose a photo, ask what it is, and start a sighting from the answer.
///
/// Drawn from the same cards as the other sheets (SheetParts.swift), so
/// it looks like the screen it was opened from. Until 13 November 2026
/// it was a standard form.
struct IdentifyView: View {

    /// True when it is shown as a sheet, from Today. False when it is a
    /// page pushed on from the Wildlife page, which has its own way back.
    var inSheet = false

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItem: PhotosPickerItem?
    @State private var isChoosingFile = false
    @State private var imageData: Data?
    /// What the model made of the photo.
    @State private var guess: SpeciesGuess?
    @State private var isWorking = false
    @State private var error: String?

    private let heading = "Identify from a photo"
    /// What the button under an answer says.
    private var sightingTitle: String {
        guess?.isSure == true ? "Start a sighting from this" : "Start a sighting to identify later"
    }
    private let subheading = "Eira compares it with UK plants and animals."

    var body: some View {
        Group {
            if inSheet {
                SheetPage(heading, detail: subheading, dismissTitle: "Close") {
                    // The cards scroll. The button that acts on the
                    // answer stays at the foot of the sheet, in view
                    // however long the cards are.
                    SheetScroll { cards }
                    if guess != nil {
                        SheetMainButton(sightingTitle) { createObservation() }
                    }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ScreenHeader(title: heading, detail: subheading)
                        cards
                        // On a page there is no foot to stand on, so
                        // the button follows the cards.
                        if guess != nil {
                            Button {
                                createObservation()
                            } label: {
                                Text(sightingTitle)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.glassProminent)
                            .controlSize(.large)
                            .tint(Theme.leaf)
                            .foregroundStyle(Theme.onLeaf)
                        }
                    }
                    // Reads best in a column, not across a wide window.
                    .frame(maxWidth: 640, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle("Identify")
                .paperScreen()
            }
        }
        // A photo from the Photos library.
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { take(data) }
            }
        }
        // A photo that is a file, which on a Mac is often where they are.
        .fileImporter(isPresented: $isChoosingFile, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            // Leave to read a file chosen in a file window lasts only
            // between these two calls.
            let hasLeave = url.startAccessingSecurityScopedResource()
            defer { if hasLeave { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) { take(data) }
        }
        .task {
            // A checking aid: an example answer, so the cards can be
            // looked at where the model cannot run. See DemoGarden.
            if DemoGarden.showsExampleMatch { guess = IdentifyView.exampleMatch }
        }
    }

    // MARK: The cards

    @ViewBuilder
    private var cards: some View {
        SheetCard("Photo") {
            if let imageData, let image = displayImage(imageData) {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            HStack(spacing: 10) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label(imageData == nil ? "From Photos" : "Another from Photos", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(QuietGlassButton())

                Button {
                    isChoosingFile = true
                } label: {
                    Label("From a file", systemImage: "folder")
                }
                .buttonStyle(QuietGlassButton())
            }
            Text("The photo stays on this device.")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        }

        if imageData != nil {
            Button {
                Task { await identify() }
            } label: {
                HStack(spacing: 8) {
                    if isWorking { ProgressView().controlSize(.small) }
                    Text(isWorking ? "Looking…" : "What is this?")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(Theme.leaf)
            .foregroundStyle(Theme.onLeaf)
            .disabled(isWorking)
        }

        if let guess {
            SheetCard(guess.isSure ? "Eira's match" : "Eira is not sure") {
                if !guess.isSure {
                    Text("None of these is strong enough to name. A closer or sharper photo may help. It may also be something she was never shown.")
                        .font(.callout)
                        .foregroundStyle(Theme.inkSoft)
                }
                ForEach(Array(guess.candidates.enumerated()), id: \.offset) { place, possible in
                    CandidateRow(possible: possible, isNamed: guess.isSure && place == 0)
                }
                Text((SpeciesEye.shared.table?.caveat ?? "Never eat anything on the strength of a match. Treat it as a suggestion to check.")
                     + " Nothing is saved until you start a sighting and confirm the name yourself.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
        }

        if let error {
            ProblemsCard(problems: [error])
        }

        if imageData != nil, guess == nil {
            Button {
                createObservation()
            } label: {
                Label("Save as a sighting to identify later", systemImage: "plus.circle")
            }
            .buttonStyle(QuietGlassButton())
        }
    }

    // MARK: Doing things

    /// Takes a newly chosen photo and clears the last answer.
    ///
    /// The photo is kept at no more than 1024 pixels on its longest
    /// side. That is plenty to identify from and to keep with a
    /// sighting, and a fraction of the size of the original.
    private func take(_ data: Data) {
        imageData = DiaryEntryEditor.thumbnail(from: data, maxDimension: 1024) ?? data
        guess = nil
        error = nil
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
        guess = nil
        error = nil
        defer { isWorking = false }

        do {
            guess = try await SpeciesEye.shared.guess(forPhoto: imageData)
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

    /// A made-up answer for looking at the cards. Never shown unless
    /// the app was started with the example garden and asked for it.
    static let exampleMatch = SpeciesGuess(
        candidates: [
            SpeciesCandidate(entry: SpeciesEntry(scientific: "Bombus terrestris", common: "Buff-tailed Bumblebee", group: "Insecta", taught: true), share: 0.93),
            SpeciesCandidate(entry: SpeciesEntry(scientific: "Bombus lucorum", common: "White-tailed Bumblebee", group: "Insecta", taught: true), share: 0.05),
            SpeciesCandidate(entry: SpeciesEntry(scientific: "Bombus hortorum", common: "Garden Bumblebee", group: "Insecta", taught: true), share: 0.01)
        ],
        isSure: true)
}

/// One possible species: its names, its share as a bar and as a figure.
private struct CandidateRow: View {

    let possible: SpeciesCandidate
    /// True for the one species that is being named outright.
    let isNamed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(possible.entry.common ?? possible.entry.scientific)
                        .font(isNamed ? .title3.weight(.semibold) : .body)
                        .foregroundStyle(Theme.ink)
                    if possible.entry.common != nil {
                        Text(possible.entry.scientific)
                            .font(.callout)
                            .italic()
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                Spacer(minLength: 8)
                Text(possible.percent)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(isNamed ? Theme.leaf : Theme.inkSoft)
            }
            // The share as a bar: a full-width track with a filled part.
            // GeometryReader tells the bar how wide its space is, so the
            // filled part can be that width times the share.
            GeometryReader { space in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.hairline)
                    Capsule()
                        .fill(isNamed ? Theme.leaf : Theme.inkSoft.opacity(0.55))
                        .frame(width: max(3, space.size.width * possible.share))
                }
            }
            .frame(height: 5)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(possible.entry.title), \(possible.percent)")
    }
}
