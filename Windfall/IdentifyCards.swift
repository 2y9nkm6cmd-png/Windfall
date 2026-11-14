//
//  IdentifyCards.swift
//  Windfall
//
//  Eira's answer to a photo, drawn.
//
//  EiraIdentify.swift holds the rules and has no screen in it. This
//  file is the other half: it gathers what the rules need from your
//  records, runs the whole job from photo to answer, draws the answer
//  as a card and starts a sighting from it.
//
//  The same card is used in two places, so an answer reads the same
//  wherever it is asked for:
//
//    - the Identify screen (EiraVision.swift)
//    - Eira's chat (EiraChatView.swift), where a photo can be given to
//      her like any other message
//
//  New things here:
//
//  extension          Adds to a type that is declared in another file.
//                     `extension IdentifyKnowledge` puts the function
//                     that reads the database here, beside the screen
//                     code, and keeps the rules' own file free of it.
//  FetchDescriptor    SwiftData's way of asking for records: "every
//                     Plant", "every sighting".
//  Bundle.main        The app's own package of files. The two small
//                     reference files this uses travel inside it.
//

import SwiftUI
import SwiftData

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - The two reference files

/// The reference files that travel inside the app, read once and kept.
///
///   SpeciesMonths.json      UK records of each species month by month
///   SpeciesLookalikes.json  species that cannot be split from a photo
///
/// Both were made on the Mac on 13 November 2026 (project doc 28). The
/// look-alikes were written by Claude from memory and are marked "to
/// check" on screen until the file itself says they have been checked.
enum SpeciesNotes {

    static let seasons: SpeciesSeasons? = read("SpeciesMonths").flatMap { SpeciesSeasons(data: $0) }
    static let lookalikes: Lookalikes? = read("SpeciesLookalikes").flatMap { Lookalikes(data: $0) }

    private static func read(_ name: String) -> Data? {
        Bundle.main.url(forResource: name, withExtension: "json").flatMap { try? Data(contentsOf: $0) }
    }
}

// MARK: - Gathering what Windfall knows

extension IdentifyKnowledge {

    /// Reads your plant list, wildlife list and past sightings, and
    /// adds the two reference files and the month.
    ///
    /// Only the few facts the rules use are copied out of each record,
    /// so the rules never hold a live database record.
    static func gathered(from context: ModelContext, on date: Date = .now) -> IdentifyKnowledge {
        var knowledge = IdentifyKnowledge(month: Calendar.current.component(.month, from: date))

        let plants = (try? context.fetch(FetchDescriptor<Plant>())) ?? []
        knowledge.plants = plants.compactMap { plant in
            guard let latin = plant.latinName, !latin.isEmpty else { return nil }
            // "Lavender, Hidcote": the name, then the variety if it has one.
            var name = plant.commonName
            if let variety = plant.variety, !variety.isEmpty { name += ", \(variety)" }
            return KnownPlant(name: name, latin: latin)
        }

        let species = (try? context.fetch(FetchDescriptor<Fauna>())) ?? []
        knowledge.wildlife = species.compactMap { animal in
            guard let scientific = animal.acceptedName ?? animal.scientificName, !scientific.isEmpty else { return nil }
            return KnownWildlife(common: animal.commonName, scientific: scientific,
                                 flightMonths: animal.flightMonths,
                                 flightText: animal.flightPeriodText,
                                 favouredPlants: animal.favouredPlants)
        }

        let sightings = (try? context.fetch(FetchDescriptor<WildlifeObservation>())) ?? []
        knowledge.sightings = sightings.map { sighting in
            let names = [sighting.confirmedID, sighting.acceptedScientificName, sighting.scientificName,
                         sighting.provisionalID, sighting.commonName]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
            return PastSighting(names: names, date: sighting.observedAt, isConfirmed: sighting.isConfirmed)
        }

        knowledge.seasons = SpeciesNotes.seasons
        knowledge.lookalikes = SpeciesNotes.lookalikes
        return knowledge
    }
}

// MARK: - The whole job, and starting a sighting

extension EiraIdentify {

    /// Photo in, judged answer out.
    ///
    /// Two steps. The image model says which names the photo most
    /// resembles (`eye.guess`). Then the fixed rules judge that against
    /// your records and the month (`judge`). `async throws` because the
    /// first step waits for the model and can fail: the model may be
    /// missing, or the photo unreadable.
    static func identify(photo data: Data,
                         context: ModelContext,
                         eye: SpeciesEye = .shared) async throws -> EiraIdentification {
        let guess = try await eye.guess(forPhoto: data)
        return judge(guess,
                     knowing: .gathered(from: context),
                     listSize: eye.table?.species.count,
                     modelName: eye.loaded?.name)
    }

    /// Starts an unconfirmed sighting, with the photo attached.
    ///
    /// The suggestion goes into `provisionalID`, never `confirmedID`: a
    /// machine's guess is not a record until you confirm it yourself.
    /// When Eira was not sure, no name is written in at all.
    ///
    /// `@discardableResult` lets a caller ignore what is handed back.
    @discardableResult
    static func startSighting(from identification: EiraIdentification?,
                              photo: Data?,
                              in context: ModelContext) -> WildlifeObservation {
        let observation = WildlifeObservation()
        observation.recorderName = UserDefaults.standard.string(forKey: "recorderName")

        if let identification {
            observation.notes = identification.sightingNote
            if let name = identification.provisionalName {
                observation.provisionalID = name
                observation.provisionalSource = .onDeviceModel
                observation.provisionalConfidence = identification.confidence ?? .possible
            }
        } else {
            observation.notes = "Photo saved without an identification."
        }

        if let photo, !photo.isEmpty {
            let attached = Photo()
            attached.imageData = photo
            attached.thumbnailData = DiaryEntryEditor.thumbnail(from: photo)
            attached.observation = observation
            observation.photos = [attached]
        }

        context.insert(observation)
        return observation
    }

    /// A made-up answer for looking at the cards where the image model
    /// cannot run, such as the iOS Simulator. It is judged against the
    /// real records like any other, so the lines about your lists are
    /// true. Never shown unless the app was started with the example
    /// garden and asked for it (DemoGarden.showsExampleMatch).
    static func example(in context: ModelContext) -> EiraIdentification {
        let guess = SpeciesGuess(
            candidates: [
                SpeciesCandidate(entry: SpeciesEntry(scientific: "Bombus terrestris", common: "Buff-tailed Bumblebee", group: "Insecta", taught: true), share: 0.93),
                SpeciesCandidate(entry: SpeciesEntry(scientific: "Bombus lucorum", common: "White-tailed Bumblebee", group: "Insecta", taught: true), share: 0.05),
                SpeciesCandidate(entry: SpeciesEntry(scientific: "Bombus hortorum", common: "Garden Bumblebee", group: "Insecta", taught: true), share: 0.01)
            ],
            isSure: true)
        return judge(guess, knowing: .gathered(from: context), listSize: 776, modelName: "an example, not a model")
    }
}

// MARK: - Showing a photo

/// Turns a photo's bytes into something SwiftUI can draw. An iPhone and
/// a Mac each have their own kind of picture, so this is the one place
/// that knows which is which.
enum PhotoPicture {
    static func image(_ data: Data) -> Image? {
        #if os(iOS)
        guard let picture = UIImage(data: data) else { return nil }
        return Image(uiImage: picture)
        #elseif os(macOS)
        guard let picture = NSImage(data: data) else { return nil }
        return Image(nsImage: picture)
        #endif
    }
}

// MARK: - The card

/// Eira's answer to a photo: the name or that she is not sure, the
/// warnings, the image model's closest names as bars, and what your
/// records say.
///
/// It draws no background of its own. On the Identify screen it sits
/// inside a `SheetCard`, and in the chat inside a glass card.
struct IdentificationCard: View {

    let identification: EiraIdentification

    /// The small line above the name, saying how far to trust it.
    private var standing: String {
        switch identification.verdict {
        case .named:
            return identification.confidence == .probable ? "Eira's match" : "Eira's match, with a doubt"
        case .oneOfSeveral:
            return "One of several that look alike"
        case .genusOnly:
            return "As far as Eira can tell"
        case .notSure:
            return "No match strong enough to name"
        case .nothing:
            return "No answer"
        }
    }

    /// Dangers go above the bars, where they cannot be missed. Doubts
    /// and notes go below, with the reasons.
    private var dangers: [EiraIdentification.Caution] {
        identification.cautions.filter { $0.weight == .danger }
    }
    private var otherCautions: [EiraIdentification.Caution] {
        identification.cautions.filter { $0.weight != .danger }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(standing)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
                Text(identification.headline)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                if let names = identification.subheading {
                    Text(names)
                        .font(.callout)
                        .italic()
                        .foregroundStyle(Theme.inkSoft)
                }
            }

            ForEach(dangers, id: \.self) { CautionRow(caution: $0) }

            // The image model's own answer: its closest three, as bars.
            if !identification.candidates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(identification.candidates.prefix(3).enumerated()), id: \.offset) { place, possible in
                        CandidateRow(possible: possible, isNamed: place == 0 && namesTheFirst)
                    }
                }
            }

            ForEach(otherCautions, id: \.self) { CautionRow(caution: $0) }

            if !identification.records.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("In your records")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                    ForEach(identification.records, id: \.self) { line in
                        Text(line)
                            .font(.callout)
                            .foregroundStyle(Theme.ink)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(identification.caveat)
                if let model = identification.modelName {
                    Text("Image model: \(model).")
                }
            }
            .font(.caption)
            .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// True when the first bar is a name Eira is giving, not just the
    /// closest of several she will not choose between.
    private var namesTheFirst: Bool {
        switch identification.verdict {
        case .named, .oneOfSeveral: return true
        case .genusOnly, .notSure, .nothing: return false
        }
    }
}

/// One warning: a symbol whose colour says how serious it is, and the words.
private struct CautionRow: View {

    let caution: EiraIdentification.Caution

    private var symbol: String {
        switch caution.weight {
        case .danger: return "exclamationmark.octagon.fill"
        case .doubt:  return "questionmark.circle"
        case .note:   return "info.circle"
        }
    }

    private var colour: Color {
        switch caution.weight {
        case .danger: return .red
        case .doubt:  return Theme.amber
        case .note:   return Theme.inkSoft
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(colour)
            VStack(alignment: .leading, spacing: 2) {
                Text(caution.words)
                    .font(.callout)
                    .foregroundStyle(Theme.ink)
                // Anything Claude supplied that you have not checked
                // says so, as everywhere else in the project.
                if caution.isUnchecked {
                    Text("⚠️ To check: this comes from a list Claude wrote that you have not checked yet.")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// One possible species: its names, its share as a bar and as a figure.
struct CandidateRow: View {

    let possible: SpeciesCandidate
    /// True for the one species that is being named outright.
    let isNamed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(possible.entry.common ?? possible.entry.scientific)
                        .font(isNamed ? .body.weight(.semibold) : .body)
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

// MARK: - In Eira's chat

/// A photo you gave Eira, shown on your side of the conversation.
struct PhotoBubble: View {

    let data: Data

    var body: some View {
        if let picture = PhotoPicture.image(data) {
            HStack {
                Spacer(minLength: 40)
                picture
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260, maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("The photo you gave Eira")
            }
        }
    }
}

/// Eira's answer to a photo, in the chat: the card, and under it the
/// two things that can be done with the answer.
///
/// The buttons are handed in as closures (`onAdd`, `onAsk`): pieces of
/// code the chat screen supplies, so this view need not know how a
/// sighting is saved or a question sent.
struct ChatIdentification: View {

    let identification: EiraIdentification
    /// True once a sighting has been started from this answer.
    let isAdded: Bool
    /// False when Eira's text model cannot run, so there is nobody to ask.
    let canAsk: Bool
    let onAdd: () -> Void
    /// Called with the question to put to her and the name to look up.
    let onAsk: (_ question: String, _ name: String) -> Void

    private var addTitle: String {
        identification.isNameable ? "Add a sighting" : "Add a sighting to identify later"
    }

    /// The name to ask about: the first candidate when a species is
    /// named, and nothing when only the genus is known or she is unsure.
    private var askable: SpeciesEntry? {
        switch identification.verdict {
        case .named, .oneOfSeveral: return identification.candidates.first?.entry
        case .genusOnly, .notSure, .nothing: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            IdentificationCard(identification: identification)

            if isAdded {
                Label("Added to Sightings, unconfirmed. Confirm or correct the name there.", systemImage: "checkmark.circle")
                    .font(.callout)
                    .foregroundStyle(Theme.leaf)
            } else if identification.verdict != .nothing {
                HStack(spacing: 10) {
                    Button(action: onAdd) {
                        Label(addTitle, systemImage: "plus.circle")
                    }
                    .buttonStyle(QuietGlassButton())

                    if canAsk, let entry = askable {
                        Button {
                            onAsk("Tell me about \(entry.title).", entry.scientific)
                        } label: {
                            Label("Ask Eira about it", systemImage: "text.bubble")
                        }
                        .buttonStyle(QuietGlassButton())
                    }
                }
                Text("Nothing is saved until you press Add, and the name stays a suggestion until you confirm it.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .glassCard()
    }
}
