//
//  EiraVision.swift
//  Windfall
//
//  Identifying a plant or animal from a photograph.
//
//  How it works now (14 November 2026). Two steps.
//
//  First the photo is matched against a list of UK species by an image
//  model that runs on this device through Core AI. SpeciesEye.swift
//  runs it and SpeciesTable.swift does the matching. The model cannot
//  describe a photo or answer a question about it: it only matches.
//
//  Then Eira judges the match by fixed rules (EiraIdentify.swift): she
//  checks it against your plant list, your wildlife list, your past
//  sightings and the month, says when a species cannot be told from
//  its look-alikes, gives the genus when the species is unclear, and
//  warns when a dangerous plant is among the possibilities.
//
//  The answer is drawn by the card in IdentifyCards.swift, which Eira's
//  chat uses too.
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
    /// A photo to begin with, as its file's own bytes: one given to Eira
    /// with her "+" button or dropped on her bar. She looks at it as
    /// soon as the screen opens.
    var startingPhoto: Data? = nil
    /// How many more photos came with it. She looks at one at a time,
    /// and says so.
    var photosLeftOut = 0

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItem: PhotosPickerItem?
    @State private var isChoosingFile = false
    /// True while the camera is open, on an iPhone or iPad.
    @State private var isTakingPhoto = false
    @State private var imageData: Data?
    /// What Eira made of the photo: the image model's match, judged
    /// against your records and the month.
    @State private var identification: EiraIdentification?
    /// The photo as it came, before it was made smaller. Kept so that
    /// the original can go to the photo folder if a sighting is started.
    @State private var originalData: Data?
    /// When and where the photo was taken, read from its file before it
    /// is made smaller. Making it smaller loses the camera's notes.
    @State private var facts = PhotoFacts()
    /// True once the starting photo has been taken in, so it happens once.
    @State private var hasTakenStartingPhoto = false
    /// True while a photo is being held over the screen.
    @State private var isDropTarget = false
    @State private var isWorking = false
    @State private var error: String?
    /// The image model in use, for saying which under the photo.
    @State private var eyeName: String?

    private let heading = "Identify from a photo"
    /// What the button under an answer says.
    private var sightingTitle: String {
        identification?.isNameable == true ? "Start a sighting from this" : "Start a sighting to identify later"
    }
    private let subheading = "Eira compares it with UK plants and animals, and with your records."

    var body: some View {
        Group {
            if inSheet {
                SheetPage(heading, detail: subheading, dismissTitle: "Close") {
                    // The cards scroll. The button that acts on the
                    // answer stays at the foot of the sheet, in view
                    // however long the cards are.
                    SheetScroll { cards }
                    if identification != nil {
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
                        if identification != nil {
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

                        // The way to the page that compares the image
                        // models. Only here, where there is a stack of
                        // pages to push it on to: a sheet has none.
                        NavigationLink {
                            EyeTestView()
                        } label: {
                            Label("Test the image models", systemImage: "square.split.2x1")
                        }
                        .buttonStyle(QuietGlassButton())
                        .padding(.top, 6)
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
        // A photo taken now with the camera, on an iPhone or iPad. See
        // CameraPhoto.swift.
        .cameraPhoto(isPresented: $isTakingPhoto) { photo in
            take(photo)
        }
        // A photo dragged on to the screen is looked at straight away.
        .onDrop(of: PhotoDrop.kinds, isTargeted: $isDropTarget) { providers in
            guard PhotoDrop.mayHold(providers) else { return false }
            Task {
                guard let first = await PhotoDrop.pictures(from: providers).first else { return }
                take(first)
                await identify()
            }
            return true
        }
        .overlay {
            if isDropTarget {
                PhotoDropOutline(words: "Drop a photo to ask what it is")
            }
        }
        .task {
            eyeName = SpeciesEyeFiles.chosen()?.name
            // A photo handed over with Eira's "+" or dropped on her bar
            // is looked at as soon as the screen opens.
            if let startingPhoto, !hasTakenStartingPhoto {
                hasTakenStartingPhoto = true
                take(startingPhoto)
                if !DemoGarden.showsExampleMatch { await identify() }
            }
            // A checking aid: an example answer, so the cards can be
            // looked at where the model cannot run. See DemoGarden.
            // `-demoMatch hemlock` shows the carrot-family warning instead.
            if DemoGarden.showsExampleMatch {
                identification = EiraIdentify.example(in: context, carrotFamily: DemoGarden.showsCarrotFamilyMatch)
            }
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
            // The photo's own date, where it has one and it was not
            // taken just now.
            if facts.wasTakenEarlier(than: .now), let taken = facts.taken {
                Text("Taken \(taken.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute())). A sighting started from this is dated then.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
            if photosLeftOut > 0 {
                Text("This is the first of \(photosLeftOut + 1) photos. Eira looks at one at a time.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
            // ChipFlow lays buttons out in a row and wraps them on to a
            // second row when they do not fit, as three do not on an
            // iPhone.
            ChipFlow(spacing: 10) {
                if CameraPhoto.isAvailable {
                    Button {
                        isTakingPhoto = true
                    } label: {
                        Label(imageData == nil ? "Take a photo" : "Take another", systemImage: "camera")
                    }
                    .buttonStyle(QuietGlassButton())
                }

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
            Text("The photo stays on this device." + (eyeName.map { " Image model: \($0)." } ?? ""))
                .font(.footnote)
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

        if let identification {
            // The card is shared with Eira's chat: IdentifyCards.swift.
            SheetCard {
                IdentificationCard(identification: identification)
                Text("Nothing is saved until you start a sighting and confirm the name yourself.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
        }

        if let error {
            ProblemsCard(problems: [error])
        }

        if imageData != nil, identification == nil {
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
        // Read the date and place first, from the photo as it came:
        // making it smaller loses them. The date gives Eira the month
        // to judge a species by (PhotoFacts.month).
        facts = PhotoFacts.read(from: data)
        originalData = data
        imageData = DiaryEntryEditor.thumbnail(from: data, maxDimension: 1024) ?? data
        identification = nil
        error = nil
    }

    /// Asks the image model what the photo most resembles, and has
    /// Eira judge the answer against your records and the month.
    ///
    /// `async` because loading the model the first time takes a moment
    /// and the screen must stay usable meanwhile. `defer` runs when the
    /// function ends by any route, so the "Looking…" spinner always
    /// stops, even after an error.
    private func identify() async {
        guard let imageData else { return }
        isWorking = true
        identification = nil
        error = nil
        defer { isWorking = false }

        do {
            identification = try await EiraIdentify.identify(photo: imageData, taken: facts.month(), context: context)
            // For the Identify widgets: her last answer, with its photo.
            if let identification { WidgetShare.noteAnswer(identification, photo: imageData) }
            eyeName = SpeciesEye.shared.loaded?.name ?? eyeName
        } catch let problem {
            // The error's own words say what is missing and what can
            // still be done. See SpeciesEyeError.
            error = problem.localizedDescription
        }
    }

    /// Creates an unconfirmed sighting with the photo attached. The
    /// suggestion goes into provisionalID, never confirmedID. Shared
    /// with Eira's chat: see EiraIdentify.startSighting.
    private func createObservation() {
        // The photo's own date becomes the sighting's, and the original
        // goes to the photo folder if one has been chosen.
        EiraIdentify.startSighting(from: identification, photo: imageData,
                                   original: originalData, facts: facts, in: context)
        dismiss()
    }

    private func displayImage(_ data: Data) -> Image? {
        PhotoPicture.image(data)
    }
}
