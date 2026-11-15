//
//  JournalNaming.swift
//  Windfall
//
//  What the journal's conversation does when a photo is sent with words
//  that ask what it is: "What is this?", "What tree is that?".
//
//  That is a question about the photo, not something that happened in
//  the garden. So nothing is written in the journal and nobody is asked
//  when it was. Eira looks at the photo and answers under it:
//
//      (your words and the photo, on the right)
//      Looking at the photo…
//      Eira's match: Japanese Maple            (the same card her chat shows)
//      [Add a sighting]  [Write a journal entry with it]  [Not now]
//
//  - Add a sighting      an unconfirmed sighting with the photo attached,
//                        dated when the photo was taken
//                        (EiraIdentify.startSighting).
//  - Write a journal     the photo goes back in the box to write in, to
//    entry with it       be sent as an ordinary entry.
//  - Not now             the card goes. Nothing has been saved.
//
//  Which words count as asking for a name is a fixed rule,
//  JournalChat.asksForAName in JournalChat.swift, so it can be tested
//  without a screen. This file only draws the card and saves.
//
//  (William, 15 November 2026: "Weird that I can't say what is this
//  without selecting the time it was sent?" Until then the journal took
//  the words for an entry, asked when the photo was about before it
//  would send, and never looked at the photo.)
//

import SwiftUI
import SwiftData

/// A photo, or several of the same thing, sent with words that ask
/// what it is.
///
/// `Identifiable` gives each request a label of its own (`id`), so
/// SwiftUI starts a new card for a new question and does not reuse the
/// last one.
struct NamingRequest: Identifiable {
    let id = UUID()
    /// What was typed: "What is this?"
    let words: String
    /// Each photo as it came, with everything its camera wrote in it.
    let originals: [Data]
    /// When and where each was taken, in the same order.
    let facts: [PhotoFacts]
    /// The small copy of each that was drawn in the box, in the same
    /// order. Nil where none could be made.
    let tiles: [Data?]
    /// The bed chosen on the "about" chip, if one was.
    let bed: Bed?
}

struct NamingCard: View {

    let request: NamingRequest
    /// Called once Eira's answer is showing, so the journal can bring
    /// the top of it into view.
    let onAnswered: () -> Void
    /// Called by "Write a journal entry with it": the journal puts the
    /// photos back in its box.
    let onJournal: () -> Void
    /// Called when the card is finished with.
    let onFinish: () -> Void

    @Environment(\.modelContext) private var context

    /// The steps the card goes through.
    private enum Stage {
        case looking
        case answered(EiraIdentification)
        case failed(String)
    }

    @State private var stage: Stage = .looking
    /// The photos as the image model was given them, each with its
    /// original and its date. A sighting is started from these.
    @State private var photos: [IdentifyPhoto] = []
    /// True once the looking has begun, so it is not begun twice.
    @State private var hasStarted = false
    /// True once a sighting has been saved from the answer.
    @State private var isAdded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            question
            HStack(alignment: .top, spacing: 8) {
                EiraSymbol(size: 28)
                VStack(alignment: .leading, spacing: 10) {
                    switch stage {
                    case .looking: looking
                    case .answered(let identification): answered(identification)
                    case .failed(let reason): failed(reason)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card.opacity(0.85), in: .rect(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Theme.leaf.opacity(0.6))
                }
            }
        }
        // `.task` runs its work when the card first appears, and lets
        // it wait (`await`) without holding up the screen.
        .task { await look() }
    }

    // MARK: What was asked

    /// Your words and the photos, as a green bubble on the right, like
    /// an entry. It has no stamp under it, because it is not one.
    private var question: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(request.words)
                .font(.body)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(request.tiles.enumerated()), id: \.offset) { _, tile in
                        if let tile, let picture = PhotoThumbnail.image(from: tile) {
                            picture
                                .resizable()
                                .scaledToFill()
                                .frame(width: 84, height: 84)
                                .clipShape(.rect(cornerRadius: 10))
                                .accessibilityLabel("Photo")
                        } else {
                            // No small copy could be made of it.
                            Image(systemName: "photo")
                                .foregroundStyle(Theme.inkSoft)
                                .frame(width: 84, height: 84)
                                .background(Theme.card, in: .rect(cornerRadius: 10))
                                .accessibilityLabel("Photo")
                        }
                    }
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(12)
        .background(Theme.leafFill, in: .rect(cornerRadius: 18))
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 36)
    }

    // MARK: Her answer

    private var looking: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(request.originals.count == 1 ? "Looking at the photo…" : "Looking at the photos…")
                .font(.body)
                .foregroundStyle(Theme.ink)
        }
    }

    private func answered(_ identification: EiraIdentification) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // The same card Eira's chat shows. There is no "Ask Eira"
            // here, because the journal has no conversation with her.
            ChatIdentification(identification: identification, isAdded: isAdded, canAsk: false,
                               onAdd: { saveSighting(from: identification) },
                               onAsk: { _, _ in })
            // With no answer at all, the card has no button, so the
            // photo can still be kept.
            if identification.verdict == .nothing, !isAdded {
                Button("Save the photo to identify later") { saveSighting(from: nil) }
                    .buttonStyle(QuietGlassButton())
            }
            closingButtons
        }
    }

    private func failed(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("I couldn't look at \(request.originals.count == 1 ? "that photo" : "those photos"). \(reason)")
                .font(.body)
                .foregroundStyle(Theme.ink)
            if !isAdded {
                Button("Save the photo to identify later") { saveSighting(from: nil) }
                    .buttonStyle(QuietGlassButton())
            } else {
                Label("Added to Sightings, to identify later.", systemImage: "checkmark.circle")
                    .font(.body)
                    .foregroundStyle(Theme.leaf)
            }
            closingButtons
        }
    }

    /// The two ways on from the answer. They wrap on to a second row
    /// if the card is narrow.
    private var closingButtons: some View {
        ChipFlow(spacing: 8) {
            Button {
                onJournal()
            } label: {
                Label("Write a journal entry with it", systemImage: "book")
            }
            .buttonStyle(QuietGlassButton())
            Button(isAdded ? "Done" : "Not now") { onFinish() }
                .buttonStyle(QuietGlassButton())
        }
    }

    // MARK: Looking and saving

    /// Hands the photos to the image model and Eira's fixed rules, as
    /// the Identify screen does (EiraIdentify.identify).
    ///
    /// Each photo is first made smaller, in the background: no more
    /// than 2048 pixels on its longest side, which is plenty to name
    /// from. Its date was read earlier, from the photo as it came,
    /// because making it smaller loses that.
    ///
    /// Several photos are taken to be of the same plant or animal and
    /// weighed together, and no more than six are looked at, both as on
    /// the Identify screen.
    private func look() async {
        guard !hasStarted else { return }
        hasStarted = true

        var made: [IdentifyPhoto] = []
        for (place, original) in request.originals.prefix(IdentifyView.mostPhotos).enumerated() {
            let small = await PhotoWorkshop.shared.jpeg(from: original, longestSide: PhotoShrink.lookSide)
            // `??` means "or, if there is none": a photo that cannot be
            // made smaller is handed over as it came.
            made.append(IdentifyPhoto(shown: small ?? original, original: original,
                                      facts: place < request.facts.count ? request.facts[place] : nil))
        }
        photos = made

        // A checking aid: an example answer, so the card can be looked
        // at where the image model cannot run, such as the simulator.
        // See DemoGarden.showsExampleMatch.
        if DemoGarden.showsExampleMatch {
            var example = EiraIdentify.example(in: context, carrotFamily: DemoGarden.showsCarrotFamilyMatch)
            example.photoCount = max(1, made.count)
            stage = .answered(example)
            onAnswered()
            return
        }

        do {
            // `try await` because the image model takes a moment and
            // can fail: it may be missing, or the photo unreadable.
            let identification = try await EiraIdentify.identify(photos: made.map(\.shown),
                                                                 taken: request.facts.first?.month(),
                                                                 context: context)
            // For the Identify widgets: her last answer, with its photo.
            WidgetShare.noteAnswer(identification, photo: made.first?.shown)
            stage = .answered(identification)
            onAnswered()
        } catch let problem {
            stage = .failed(problem.localizedDescription)
        }
    }

    /// Starts an unconfirmed sighting with every photo attached and
    /// Eira's suggestion, if she made one. The sighting is dated when
    /// the first photo was taken. This is the only thing here that
    /// saves to your records, and only when its button is pressed.
    private func saveSighting(from identification: EiraIdentification?) {
        let observation = EiraIdentify.startSighting(from: identification, photos: photos, in: context)
        observation.bed = request.bed
        isAdded = true
    }
}
