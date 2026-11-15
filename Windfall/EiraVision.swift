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
//  More than one photo (15 November 2026). A further photo no longer
//  takes the place of the last one. It joins it, as another view of the
//  same plant or animal: the whole of it, a leaf, the flower close up.
//  Eira weighs all of them together and every one goes on the sighting.
//  "Start again" clears them, for something different.
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
    /// Every photo of this identification, in the order they were
    /// given. Each holds its smaller copy for showing and for the image
    /// model, the photo as it came (so the original can go to the photo
    /// folder if a sighting is started) and when and where it was taken
    /// (read before it is made smaller, which loses the camera's notes).
    /// See IdentifyPhoto in IdentifyCards.swift.
    ///
    /// Until 15 November 2026 this was one photo, and choosing another
    /// replaced it.
    @State private var photos: [IdentifyPhoto] = []
    /// What Eira made of the photos: the image model's match, judged
    /// against your records and the month.
    @State private var identification: EiraIdentification?
    /// Counts each time Eira is asked to look, and each time the photos
    /// change. An answer that comes back after the count has moved on
    /// belongs to an earlier set of photos and is dropped. See `identify`.
    @State private var lookNumber = 0
    /// True once the starting photo has been taken in, so it happens once.
    @State private var hasTakenStartingPhoto = false
    /// True while a photo is being held over the screen.
    @State private var isDropTarget = false
    @State private var isWorking = false
    /// True while a newly chosen photo is being made smaller, before it
    /// can be shown.
    @State private var isReadingPhoto = false
    @State private var error: String?
    /// The image model in use, for saying which under the photo.
    @State private var eyeName: String?

    private let heading = "Identify from a photo"
    /// What the button under an answer says.
    private var sightingTitle: String {
        identification?.isNameable == true ? "Start a sighting from this" : "Start a sighting to identify later"
    }
    private let subheading = "Eira compares it with UK plants and animals, and with your records."

    /// The most photos one identification holds. Each is kept in
    /// memory as it came until a sighting is started, and the image
    /// model looks at every one each time, so there has to be a limit.
    static let mostPhotos = 6

    /// When and where the first photo was taken. It gives Eira the
    /// month to judge by, and a sighting its date.
    private var facts: PhotoFacts { photos.first?.facts ?? PhotoFacts() }
    private var isFull: Bool { photos.count >= IdentifyView.mostPhotos }

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
            // Shown as busy from here, because fetching the photo can
            // take a while if iCloud holds the original.
            isReadingPhoto = true
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await add(data)
                } else {
                    isReadingPhoto = false
                }
                // Let go of the choice, so that choosing the very same
                // photo again would still be noticed.
                pickerItem = nil
            }
        }
        // A photo that is a file, which on a Mac is often where they are.
        .fileImporter(isPresented: $isChoosingFile, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            // Leave to read a file chosen in a file window lasts only
            // between these two calls.
            let hasLeave = url.startAccessingSecurityScopedResource()
            defer { if hasLeave { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) {
                Task { await add(data) }
            }
        }
        // A photo taken now with the camera, on an iPhone or iPad. See
        // CameraPhoto.swift.
        .cameraPhoto(isPresented: $isTakingPhoto) { photo in
            // `add` waits while the photo is made smaller, away from the
            // screen's own work, so it is started as a Task, as the other
            // ways in above are.
            Task { await add(photo) }
        }
        // A photo dragged on to the screen is looked at straight away.
        .onDrop(of: PhotoDrop.kinds, isTargeted: $isDropTarget) { providers in
            guard PhotoDrop.mayHold(providers) else { return false }
            Task {
                guard let first = await PhotoDrop.pictures(from: providers).first else { return }
                await add(first, lookNow: true)
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
                await add(startingPhoto, lookNow: !DemoGarden.showsExampleMatch)
                // A checking aid: `-demoPhotoCopies 3` brings the same
                // photo in three times over, so the row of several
                // photos can be looked at in a still picture.
                for _ in 1..<max(1, DemoGarden.photoCopies) {
                    await add(startingPhoto)
                }
            }
            // A checking aid: an example answer, so the cards can be
            // looked at where the model cannot run. See DemoGarden.
            // `-demoMatch hemlock` shows the carrot-family warning instead.
            if DemoGarden.showsExampleMatch {
                var example = EiraIdentify.example(in: context, carrotFamily: DemoGarden.showsCarrotFamilyMatch)
                example.photoCount = max(1, photos.count)
                identification = example
            }
        }
    }

    // MARK: The cards

    @ViewBuilder
    private var cards: some View {
        SheetCard(photos.count > 1 ? "Photos" : "Photo") {
            if photos.count == 1, let only = photos.first, let image = displayImage(only.shown) {
                // One photo is shown large, as it always was.
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else if photos.count > 1 {
                // Several sit side by side in a row that slides, the
                // first on the left. `enumerated` hands out each photo
                // with its place in the list, for the words a screen
                // reader says ("Photo 2 of 3").
                //
                // The newest photo is added at the right-hand end, which
                // may be out of view. ScrollViewReader hands over a
                // `proxy` that can slide the row to any photo by its id,
                // so the row is slid to the newest whenever the number
                // of photos changes, and when the row first appears.
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(Array(photos.enumerated()), id: \.element.id) { place, given in
                                IdentifyPhotoTile(data: given.shown, number: place + 1, of: photos.count) {
                                    remove(given.id)
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .onAppear {
                        if let newest = photos.last { proxy.scrollTo(newest.id, anchor: .trailing) }
                    }
                    .onChange(of: photos.count) { _, _ in
                        guard let newest = photos.last else { return }
                        withAnimation { proxy.scrollTo(newest.id, anchor: .trailing) }
                    }
                }
            }
            if isReadingPhoto {
                // The photo has been chosen and is being fetched or made
                // smaller. Saying so at once is what stops the screen
                // seeming to have ignored the choice. The photos already
                // here stay in view above it.
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Fetching the photo…")
                        .font(.body)
                        .foregroundStyle(Theme.inkSoft)
                }
                .frame(maxWidth: .infinity, minHeight: photos.isEmpty ? 120 : 32)
            }
            if photos.count > 1 {
                Text("\(photos.count) photos of the same plant or animal. Eira weighs them together, and all \(photos.count) are kept with a sighting.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
            // The photo's own date, where it has one and it was not
            // taken just now. With several, the first photo's.
            if facts.wasTakenEarlier(than: .now), let taken = facts.taken {
                let when = taken.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute())
                Text(photos.count > 1
                     ? "The first was taken \(when). A sighting started from these is dated then."
                     : "Taken \(when). A sighting started from this is dated then.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
            if photosLeftOut > 0 {
                Text("This is the first of the \(photosLeftOut + 1) photos you gave. Only this one was brought in.")
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
                        Label(photos.isEmpty ? "Take a photo" : "Take another", systemImage: "camera")
                    }
                    .buttonStyle(QuietGlassButton())
                    .disabled(isFull)
                }

                // `.current` asks for the photo as it is stored, without
                // the chooser converting it to another format first.
                PhotosPicker(selection: $pickerItem, matching: .images, preferredItemEncoding: .current) {
                    Label(photos.isEmpty ? "From Photos" : "Another from Photos", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(QuietGlassButton())
                .disabled(isFull)

                Button {
                    isChoosingFile = true
                } label: {
                    Label(photos.isEmpty ? "From a file" : "Another file", systemImage: "folder")
                }
                .buttonStyle(QuietGlassButton())
                .disabled(isFull)

                // The way back to an empty screen, for a different
                // plant or animal. Before 15 November 2026 choosing
                // another photo did this by itself.
                if !photos.isEmpty {
                    Button {
                        startAgain()
                    } label: {
                        Label("Start again", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(QuietGlassButton())
                }
            }
            if isFull {
                Text("\(IdentifyView.mostPhotos) photos is the most for one identification. Remove one to add another.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            } else if !photos.isEmpty {
                Text("Another photo is added to this identification, as a second view of the same plant or animal. For something different, press Start again.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
            Text((photos.count > 1 ? "The photos stay on this device." : "The photo stays on this device.") + (eyeName.map { " Image model: \($0)." } ?? ""))
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }

        if !photos.isEmpty, !isReadingPhoto {
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

        if !photos.isEmpty, identification == nil {
            Button {
                createObservation()
            } label: {
                Label("Save as a sighting to identify later", systemImage: "plus.circle")
            }
            .buttonStyle(QuietGlassButton())
        }
    }

    // MARK: Doing things

    /// Adds a newly chosen photo to the identification.
    ///
    /// Until 15 November 2026 this replaced the photo before it. Now
    /// the earlier photos stay, and the new one joins them.
    ///
    /// The photo is kept at no more than 2048 pixels on its longest
    /// side. That is plenty to identify from and to keep with a
    /// sighting, and a fraction of the size of the original.
    ///
    /// The last answer is cleared, because it was an answer to fewer
    /// photos. If Eira had already answered, or was part-way through
    /// looking, she looks again at once with the new photo included:
    /// that is what a second photo is for. `lookNow` asks for that even
    /// on a first photo, as a photo dropped on the screen does.
    ///
    /// `async` because the smaller copy is made in the background
    /// (PhotoShrink.swift) and this waits for it, with the screen free
    /// to show "Fetching the photo…" meanwhile.
    private func add(_ data: Data, lookNow: Bool = false) async {
        guard !isFull else {
            // The Photos chooser shows "Fetching…" before it calls
            // this, so that has to be taken down again.
            isReadingPhoto = false
            return
        }
        let wasAnswered = identification != nil || isWorking
        isReadingPhoto = true
        setAnswerAside()
        // Read the date and place first, from the photo as it came:
        // making it smaller loses them. The first photo's date gives
        // Eira the month to judge a species by (PhotoFacts.month).
        let read = PhotoFacts.read(from: data)
        let shown = await PhotoWorkshop.shared.jpeg(from: data, longestSide: PhotoShrink.lookSide) ?? data
        // Checked again: two photos chosen close together could both
        // have passed the check at the top while the other was being
        // made smaller.
        if !isFull {
            photos.append(IdentifyPhoto(shown: shown, original: data, facts: read))
        }
        isReadingPhoto = false
        if lookNow || wasAnswered { await identify() }
    }

    /// Takes one photo out of the identification. If Eira had answered
    /// and photos remain, she looks again at the ones that are left.
    private func remove(_ id: UUID) {
        let wasAnswered = identification != nil || isWorking
        setAnswerAside()
        photos.removeAll { $0.id == id }
        if wasAnswered, !photos.isEmpty {
            Task { await identify() }
        }
    }

    /// Clears every photo and the answer, for a different plant or
    /// animal. Nothing was saved, so nothing is lost but the photos'
    /// place on this screen.
    private func startAgain() {
        setAnswerAside()
        photos = []
    }

    /// Clears the answer on screen and disowns any look that is still
    /// under way: moving `lookNumber` on is what makes `identify` drop
    /// its answer when it comes back.
    private func setAnswerAside() {
        lookNumber += 1
        identification = nil
        error = nil
        isWorking = false
    }

    /// Asks the image model what the photos most resemble, and has
    /// Eira judge the answer against your records and the month.
    ///
    /// `async` because loading the model the first time takes a moment
    /// and the screen must stay usable meanwhile.
    ///
    /// The photos can change while this waits: one added, one removed,
    /// or Start again pressed. `mine` is this look's number. Anything
    /// that changes the photos moves `lookNumber` on, so if the two
    /// differ when the answer arrives, the answer is to photos no
    /// longer on screen and is dropped without a word.
    private func identify() async {
        guard !photos.isEmpty else { return }
        lookNumber += 1
        let mine = lookNumber
        isWorking = true
        identification = nil
        error = nil

        do {
            let answer = try await EiraIdentify.identify(photos: photos.map(\.shown), taken: facts.month(), context: context)
            guard mine == lookNumber else { return }
            identification = answer
            // For the Identify widgets: her last answer, with its
            // first photo.
            WidgetShare.noteAnswer(answer, photo: photos.first?.shown)
            eyeName = SpeciesEye.shared.loaded?.name ?? eyeName
        } catch let problem {
            guard mine == lookNumber else { return }
            // The error's own words say what is missing and what can
            // still be done. See SpeciesEyeError.
            error = problem.localizedDescription
        }
        isWorking = false
    }

    /// Creates an unconfirmed sighting with every photo attached. The
    /// suggestion goes into provisionalID, never confirmedID. Shared
    /// with Eira's chat: see EiraIdentify.startSighting.
    private func createObservation() {
        // The first photo's own date becomes the sighting's, and each
        // original goes to the photo folder if one has been chosen.
        EiraIdentify.startSighting(from: identification, photos: photos, in: context)
        dismiss()
    }

    private func displayImage(_ data: Data) -> Image? {
        PhotoPicture.image(data)
    }
}

// MARK: - One photo in the row

/// One photo of an identification, in the row of several: the picture
/// with a small button in its corner that takes it out.
///
/// `onRemove` is a closure: a piece of code handed in by the screen,
/// run when the button is pressed. The tile need not know how a photo
/// is removed, only that it should say when it was asked to.
private struct IdentifyPhotoTile: View {

    let data: Data
    /// Its place in the row, from 1, and how many there are. Only for
    /// the words a screen reader says.
    let number: Int
    let of: Int
    let onRemove: () -> Void

    var body: some View {
        if let image = PhotoPicture.image(data) {
            image
                .resizable()
                .scaledToFit()
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Photo \(number) of \(of)")
                // `overlay` draws on top of the picture, here in its
                // top right corner (`topTrailing`: trailing is the
                // right-hand side in a language read left to right).
                .overlay(alignment: .topTrailing) {
                    Button(action: onRemove) {
                        // A white cross on a dark disc, so it shows
                        // against a pale photo and a dark one alike.
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.55))
                            .padding(6)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove photo \(number)")
                }
        }
    }
}
