//
//  PhotoOffer.swift
//  Windfall
//
//  What Eira does when she is given a photo.
//
//  A photo can reach Eira from her bar on any page: chosen with the "+"
//  beside her snowdrop, or dragged on to the bar. On the Journal page it
//  plainly belongs in the journal, and goes straight there. Anywhere
//  else it could be for one of three things, so she asks:
//
//  - What is this?    She looks at it and names what it most resembles
//                     (the Identify screen, EiraVision.swift).
//  - Journal entry    The journal's conversation opens with the photo in
//                     its box (JournalChatView.swift).
//  - Sighting         A new sighting is started with the photo attached
//                     and dated when the photo was taken.
//
//  Nothing is saved by choosing. Each of the three has its own button
//  that saves, and its own way of backing out.
//
//  The card and the three things it leads to are all shown in the one
//  sheet. Choosing swaps what is in the sheet, so the sheet does not
//  have to close and another open.
//

import SwiftUI
import SwiftData

struct PhotoOfferSheet: View {

    /// The photos, each as its file's own bytes.
    let photos: [Data]

    @Environment(\.modelContext) private var context

    /// What the sheet is showing.
    private enum Stage {
        case offer
        case identify
        case journal
        case sighting(WildlifeObservation)
    }

    @State private var stage = Stage.offer
    /// Small copies of the photos to show on the card. Made once, when
    /// the card appears, because making them takes a moment.
    @State private var smallCopies: [Data] = []
    /// When and where each photo was taken.
    @State private var facts: [PhotoFacts] = []

    private var heading: String {
        photos.count == 1 ? "A photo for Eira" : "\(photos.count) photos for Eira"
    }

    /// The earliest time any of the photos was taken, if that was more
    /// than an hour ago. It is what a sighting would be dated.
    private var taken: Date? {
        facts.filter { $0.wasTakenEarlier(than: .now) }.compactMap(\.taken).min()
    }

    /// "Taken Wednesday 11 November at 14:02", for the line under the
    /// title. Nil for a photo taken just now or one that does not say.
    private var takenWords: String? {
        taken.map { "Taken \($0.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()))" }
    }

    var body: some View {
        // `switch` shows one of four things in the same sheet.
        Group {
            switch stage {
            case .offer:
                offer
            case .identify:
                IdentifyView(inSheet: true, startingPhoto: photos.first, photosLeftOut: photos.count - 1)
            case .journal:
                JournalChatView(photos: photos)
            case .sighting(let observation):
                ObservationEditor(observation: observation, isNew: true)
            }
        }
        .task {
            guard facts.isEmpty else { return }
            facts = photos.map { PhotoFacts.read(from: $0) }
            smallCopies = photos.compactMap { DiaryEntryEditor.thumbnail(from: $0, maxDimension: 600) }
        }
    }

    // MARK: The card

    private var offer: some View {
        SheetPage(heading, detail: takenWords) {
            SheetScroll {
                SheetCard {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(smallCopies.enumerated()), id: \.offset) { _, copy in
                                if let picture = PhotoThumbnail.image(from: copy) {
                                    picture
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 170)
                                        .clipShape(.rect(cornerRadius: 12))
                                }
                            }
                        }
                    }
                    .frame(height: 170)
                }

                SheetCard("What shall I do with \(photos.count == 1 ? "it" : "them")?") {
                    choice(.search, "What is this?",
                           photos.count == 1
                           ? "I compare it with UK plants and animals and say what it most resembles."
                           : "I compare the first one with UK plants and animals and say what it most resembles.") {
                        stage = .identify
                    }
                    choice(.journalEntry, "Journal entry",
                           taken == nil
                           ? "Write about it. I note the time and the weather."
                           : "Write about it. I offer to file it under the day it was taken.") {
                        stage = .journal
                    }
                    choice(.sighting, "Sighting",
                           taken == nil
                           ? "Record something you saw, to name now or later."
                           : "Record something you saw, dated when the photo was taken.") {
                        startSighting()
                    }
                }
            }
        }
    }

    /// One of the three choices: an icon, a name and a line saying what
    /// it does, the whole row being the button.
    private func choice(_ icon: WIcon, _ title: String, _ detail: String,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                WIconView(icon, size: 24)
                    .foregroundStyle(Theme.leaf)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                WIconView(.chevronRight, size: 14)
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card.opacity(0.85), in: .rect(cornerRadius: 12))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    // MARK: Starting a sighting

    /// Makes a new sighting with the photos attached and opens its form.
    /// The form's Cancel button throws the unfinished sighting away, so
    /// nothing is kept unless Save is pressed there.
    private func startSighting() {
        let observation = WildlifeObservation()
        observation.recorderName = UserDefaults.standard.string(forKey: "recorderName")
        let precision = UserDefaults.standard.integer(forKey: "gridPrecision")
        observation.gridPrecisionMetres = precision == 0 ? 100 : precision
        // It was seen when the photo was taken, not when the photo was
        // brought in here.
        if let taken { observation.observedAt = taken }

        var attached: [Photo] = []
        for (place, data) in photos.enumerated() {
            let photo = Photo.record(of: data, facts: place < facts.count ? facts[place] : nil,
                                     otherwiseAt: observation.observedAt)
            photo.observation = observation
            attached.append(photo)
        }
        observation.photos = attached

        context.insert(observation)
        stage = .sighting(observation)
    }
}
