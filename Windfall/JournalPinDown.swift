//
//  JournalPinDown.swift
//  Windfall
//
//  Eira's follow-up in the journal when an entry tells of something seen
//  but not named: "I noticed an insect in my garden tonight".
//
//  She asks once, as a card under the entry, while it is fresh in the
//  memory:
//
//      Want to pin it down?
//      [Add a photo]  [Describe it]  [Leave it unidentified]
//
//  - Add a photo     the image model and Eira's fixed rules look at it,
//                    as on the Identify screen (EiraIdentify.identify).
//                    If the entry was sent with a photo, that one is
//                    offered instead.
//  - Describe it     a few questions with answers as buttons: size in
//                    centimetres, colours, wings, what it was doing and
//                    where. Each is something field guides identify by.
//  - Leave it        the card goes. The entry is already saved.
//
//  Whatever is added becomes an unconfirmed sighting on the Wildlife
//  page, dated with the entry. A name from a photo stays a suggestion
//  until confirmed there.
//
//  Which entries get the card, the questions and the rule for asking
//  less often are fixed rules in JournalChat.swift, so they can be
//  tested without a screen. This file only draws the card and saves.
//

import SwiftUI
import SwiftData
import PhotosUI

/// One find to offer to pin down, and what the journal knows about it.
struct PinDownRequest: Identifiable {
    let id = UUID()
    let find: JournalChat.Find
    /// When the entry was stamped. The sighting takes this date.
    let date: Date
    /// The bed the entry was about, if one was chosen.
    let bed: Bed?
    /// The first photo sent with the entry, if there was one.
    let photo: Data?
}

struct PinDownCard: View {

    let request: PinDownRequest
    /// Called the first time Photo or Describe is used, so the journal
    /// knows the offer was wanted (see `shouldOfferPinDown`).
    let onUsed: () -> Void
    /// Called when Leave it is pressed.
    let onSkip: () -> Void
    /// Called when the card is finished with, with a line for Eira to
    /// say, if there is one.
    let onFinish: (String?) -> Void

    @Environment(\.modelContext) private var context

    /// The steps the card goes through.
    private enum Stage {
        case offer
        case describing
        case looking
        case answered(EiraIdentification)
        case failed(String)
    }

    @State private var stage: Stage = .offer
    /// The description so far: question id → chosen answers.
    @State private var answers: [String: [String]] = [:]
    /// The photo being looked at.
    @State private var photo: Data?
    @State private var pickerItem: PhotosPickerItem?
    /// True once a sighting has been saved from a photo's answer.
    @State private var isAdded = false

    private var word: String { request.find.word }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            EiraSymbol(size: 28)
            VStack(alignment: .leading, spacing: 10) {
                switch stage {
                case .offer: offer
                case .describing: describing
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
        // A photo chosen with the picker arrives a moment later.
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await look(at: data)
                }
                pickerItem = nil
            }
        }
    }

    // MARK: The offer

    private var offer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Want to pin it down?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("A photo or a few details now will make the \(word) easier to name later.")
                .font(.subheadline)
                .foregroundStyle(Theme.ink)

            // Wraps on to a second row if the card is narrow.
            ChipFlow(spacing: 8) {
                if let sent = request.photo {
                    Button {
                        Task { await look(at: sent) }
                    } label: {
                        Label("Use the photo you sent", systemImage: "photo")
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.leaf)
                    .foregroundStyle(Theme.onLeaf)
                } else {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Add a photo", systemImage: "photo.badge.plus")
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.leaf)
                    .foregroundStyle(Theme.onLeaf)
                }
                Button {
                    onUsed()
                    stage = .describing
                } label: {
                    Label("Describe it", systemImage: "text.badge.plus")
                }
                .buttonStyle(QuietGlassButton())
                Button("Leave it unidentified") { onSkip() }
                    .buttonStyle(QuietGlassButton())
            }
        }
    }

    // MARK: Describing

    private var describing: some View {
        // Worked out again each time an answer changes, so "Wings held
        // at rest" appears once there are wings.
        let questions = JournalChat.describeQuestions(for: request.find, answers: answers)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Tell me what you can. Skip anything you didn't see.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)

            ForEach(questions) { question in
                VStack(alignment: .leading, spacing: 6) {
                    Text(question.title + (question.allowsMany ? " (choose any)" : ""))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                    ChipFlow(spacing: 6) {
                        ForEach(question.options, id: \.self) { option in
                            answerChip(option, isOn: answers[question.id]?.contains(option) == true) {
                                choose(option, for: question)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Button("Save as a sighting") { saveDescription() }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.leaf)
                    .foregroundStyle(Theme.onLeaf)
                    .disabled(JournalChat.description(of: request.find, answers: answers) == nil)
                Button("Not now") { onFinish(nil) }
                    .buttonStyle(QuietGlassButton())
            }
        }
    }

    /// One answer as a small chip, filled in when chosen.
    private func answerChip(_ words: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(words)
                .font(.caption)
                .fontWeight(isOn ? .semibold : .regular)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint((isOn ? Theme.leafFill : Theme.card).opacity(isOn ? 0.9 : 0.5)), in: .capsule)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// Pressing an answer. Where only one may be chosen it replaces the
    /// last; pressing a chosen answer again clears it.
    private func choose(_ option: String, for question: JournalChat.DescribeQuestion) {
        var chosen = answers[question.id] ?? []
        if chosen.contains(option) {
            chosen.removeAll { $0 == option }
        } else if question.allowsMany {
            chosen.append(option)
        } else {
            chosen = [option]
        }
        answers[question.id] = chosen
    }

    private func saveDescription() {
        guard let description = JournalChat.description(of: request.find, answers: answers) else { return }
        let observation = newSighting()
        observation.notes = description
        observation.behaviour = answers["doing"]?.first
        context.insert(observation)
        onFinish("Saved as a sighting to identify later, with your description. It is on the Wildlife page.")
    }

    // MARK: A photo

    private var looking: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Looking at the photo…")
                .font(.subheadline)
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
            Button(isAdded ? "Done" : "Not now") { onFinish(nil) }
                .buttonStyle(QuietGlassButton())
        }
    }

    private func failed(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("I couldn't look at that photo. \(reason)")
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
            HStack(spacing: 8) {
                Button("Save the photo to identify later") { saveSighting(from: nil) }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.leaf)
                    .foregroundStyle(Theme.onLeaf)
                Button("Not now") { onFinish(nil) }
                    .buttonStyle(QuietGlassButton())
            }
        }
    }

    /// Hands a photo to the image model, as Eira's chat does: the month
    /// it was taken is read first, since shrinking loses it, then it is
    /// kept at no more than 1024 pixels on its longest side.
    private func look(at data: Data) async {
        onUsed()
        stage = .looking
        let taken = SpeciesEye.monthTaken(of: data)
        let shrunk = DiaryEntryEditor.thumbnail(from: data, maxDimension: 1024) ?? data
        photo = shrunk
        do {
            stage = .answered(try await EiraIdentify.identify(photo: shrunk, taken: taken, context: context))
        } catch let problem {
            stage = .failed(problem.localizedDescription)
        }
    }

    /// Saves the photo as an unconfirmed sighting, with Eira's
    /// suggestion if there is one (EiraIdentify.startSighting), then
    /// gives it the entry's date, bed and group.
    private func saveSighting(from identification: EiraIdentification?) {
        let observation = EiraIdentify.startSighting(from: identification, photo: photo, in: context)
        observation.observedAt = request.date
        observation.bed = request.bed
        if observation.taxonGroup == nil { observation.taxonGroup = request.find.group }
        if request.find.isYoung, observation.lifeStage == nil { observation.lifeStage = "larva" }
        isAdded = true
        if identification == nil || identification?.verdict == .nothing {
            onFinish("Saved the photo as a sighting to identify later. It is on the Wildlife page.")
        }
    }

    /// A sighting started from the entry, not yet saved.
    private func newSighting() -> WildlifeObservation {
        let observation = WildlifeObservation()
        observation.recorderName = UserDefaults.standard.string(forKey: "recorderName")
        let precision = UserDefaults.standard.integer(forKey: "gridPrecision")
        observation.gridPrecisionMetres = precision == 0 ? 100 : precision
        observation.observedAt = request.date
        observation.bed = request.bed
        observation.taxonGroup = request.find.group
        if request.find.isYoung { observation.lifeStage = "larva" }
        return observation
    }
}
