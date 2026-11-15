//
//  EiraSecondLook.swift
//  Windfall
//
//  Eira's second look at a sighting's photo: which plant the animal is
//  on, and what it is doing. Asked for by William on 15 November 2026:
//  "Eira should do a second pass of the photo for the plant and what
//  it's doing."
//
//  Why a second look is needed. The image model (BioCLIP) gives one
//  ranked list of names for the whole photo, and an animal on a flower
//  comes out as the animal. It cannot say what anything is doing.
//
//  So the second look has two parts:
//
//    1. The image model again, on the same photo, but with every row
//       that is not a plant set aside (SpeciesTable.guess(fromShares:
//       keeping:among:)). The flower the bee is on is usually the
//       likeliest plant left. This gives up to five plant names.
//    2. Apple's own model, which on iOS 27 and macOS 27 can be shown a
//       photo (EiraSecondLookRunner.swift). It is given the photo, the
//       animal's name, those five plant names and the list of ready-
//       made answers under "What was it doing?", and asked three
//       things: is the animal on a plant, which of the five is it if
//       any, and which of the answers fits.
//
//  This file holds the part with no Apple frameworks in it: the ready-
//  made answers, and the rules that turn the two parts' answers into
//  the suggestions shown on the sighting. Everything here is covered by
//  the logic tests that run without a Mac.
//
//  Nothing here fills a box by itself. The sighting's form shows each
//  suggestion with a "Use" button, because both parts can be wrong.
//

import Foundation

// MARK: - The ready-made answers

enum SightingDoing {

    /// The ready-made answers under "What was it doing?" on a sighting,
    /// and the only answers Apple's model may choose from.
    ///
    /// ⚠️ CHECK: Claude's list (15 November 2026), not William's.
    /// Card `f-doing-list-113` on the checklist asks him.
    static let choices = [
        "Feeding at a flower", "Collecting pollen", "Resting", "Basking",
        "Feeding on leaves", "Laying eggs", "Nesting", "Hunting", "Mating", "Flying past"
    ]

    /// The choice that matches what a model wrote, ignoring capitals and
    /// spaces at the ends. Nil when it wrote anything else, such as
    /// "cannot tell" or an answer of its own: a model is never allowed
    /// to put words into the record that are not on the list.
    static func choice(matching written: String?) -> String? {
        guard let written else { return nil }
        let wanted = written.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return choices.first { $0.lowercased() == wanted }
    }
}

// MARK: - What Apple's model said

/// Apple's model's answer about the photo, as plain values. The runner
/// (EiraSecondLookRunner.swift) copies the model's reply into one of
/// these, so the rules below never touch Apple's types.
struct SeenInPhoto: Equatable {
    /// Whether the animal is on, at or touching a plant.
    var isOnPlant: Bool
    /// One of the plant names it was offered, or anything else when
    /// none fitted.
    var plantChoice: String?
    /// A few words about the plant it saw, such as "a yellow daisy-like
    /// flower head". Kept as a note, never as a name.
    var plantWords: String?
    /// One of `SightingDoing.choices`, or anything else when it could
    /// not tell.
    var doing: String?
}

// MARK: - The suggestions

/// What the second look suggests for one sighting.
struct SecondLookSuggestion: Equatable {
    /// The plant to suggest under "Which plant": one of William's own
    /// plants when the name matches one ("Sunflower, Velvet Queen"),
    /// otherwise the image model's name for it ("Common Sunflower").
    var plantName: String?
    /// Its scientific name, kept so the form can find the plant in the
    /// library again.
    var plantLatin: String?
    /// True when `plantName` is one of William's own plants.
    var plantIsYours = false
    /// One of `SightingDoing.choices`.
    var doing: String?
    /// One line saying what was seen, for the note under the
    /// suggestions. Says when the suggestion came from the image model
    /// alone.
    var note: String?

    var isEmpty: Bool { plantName == nil && doing == nil }
}

enum EiraSecondLook {

    /// How many plant names the image model hands on.
    static let plantNamesWanted = 5

    /// The share a plant must have, among plants alone, before it is
    /// suggested on the image model's word alone, with no look from
    /// Apple's model to agree. ⚠️ CHECK: Claude's choice. It has not been
    /// measured, and setting the animals aside makes every plant's share
    /// larger than it would be on the whole list.
    static let plantShareOnItsOwn = 0.5

    /// Turns the two parts' answers into the suggestions.
    ///
    /// - `plants`: the image model's plant names, likeliest first, with
    ///   their shares among plants alone.
    /// - `seen`: what Apple's model said, or nil if it could not look
    ///   (no Apple Intelligence, an older system, or it failed).
    /// - `yourPlants`: William's own plants with a scientific name.
    ///
    /// The rules:
    /// 1. If Apple's model says the animal is not on a plant, no plant
    ///    is suggested.
    /// 2. If it chose one of the names it was offered, that is the
    ///    plant. A name it made up is never used.
    /// 3. If it could not look at all, the image model's first plant is
    ///    used only when its share is at least `plantShareOnItsOwn`.
    /// 4. The plant is then looked for among William's own: the same
    ///    species first, then the same genus. His name for it is used
    ///    when one matches.
    /// 5. What it was doing comes only from Apple's model, and only when
    ///    it chose one of the ready-made answers.
    static func suggestion(plants: [SpeciesCandidate],
                           seen: SeenInPhoto?,
                           yourPlants: [KnownPlant]) -> SecondLookSuggestion {
        var result = SecondLookSuggestion()

        // Which plant, before matching it to William's.
        var chosen: SpeciesEntry?
        if let seen {
            if seen.isOnPlant, let picked = seen.plantChoice {
                chosen = plants.first { matches(picked, $0.entry) }?.entry
            }
        } else if let top = plants.first, top.share >= plantShareOnItsOwn {
            chosen = top.entry
        }

        if let chosen {
            result.plantLatin = chosen.scientific
            if let yours = yourPlant(for: chosen.scientific, among: yourPlants) {
                result.plantName = yours.name
                result.plantIsYours = true
            } else {
                result.plantName = chosen.title
            }
        }

        result.doing = SightingDoing.choice(matching: seen?.doing)

        // The note: what was seen, in a line.
        var parts: [String] = []
        if let seen {
            if !seen.isOnPlant {
                parts.append("Eira saw it was not on a plant.")
            } else if let words = seen.plantWords?.trimmingCharacters(in: .whitespacesAndNewlines), !words.isEmpty {
                parts.append("Eira saw it on \(words.hasSuffix(".") ? String(words.dropLast()) : words).")
            }
        } else if chosen != nil {
            parts.append("From the image model alone: Apple's model could not look at the photo here.")
        }
        result.note = parts.isEmpty ? nil : parts.joined(separator: " ")
        return result
    }

    /// True when a name a model wrote is this entry: its title, its
    /// English name or its scientific name, ignoring capitals.
    static func matches(_ written: String, _ entry: SpeciesEntry) -> Bool {
        let wanted = written.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !wanted.isEmpty else { return false }
        if entry.title.lowercased() == wanted { return true }
        if let common = entry.common, common.lowercased() == wanted { return true }
        return SpeciesName.key(entry.scientific) == SpeciesName.key(written)
    }

    /// One of William's plants with this species, or failing that this
    /// genus. The first in his list wins, so the answer never wavers.
    static func yourPlant(for scientific: String, among yours: [KnownPlant]) -> KnownPlant? {
        let species = SpeciesName.key(scientific)
        if let same = yours.first(where: { SpeciesName.key($0.latin) == species }) { return same }
        let genus = species.split(separator: " ").first.map(String.init) ?? species
        guard !genus.isEmpty else { return nil }
        return yours.first { SpeciesName.key($0.latin).split(separator: " ").first.map(String.init) == genus }
    }

    /// The words Apple's model is given with the photo.
    static func question(animal: String, plantNames: [String]) -> String {
        let offered = plantNames.isEmpty ? "(none)" : plantNames.joined(separator: "; ")
        return """
        This photo was recorded as a sighting of \(animal).
        1. Is the \(animal) on, at or touching a plant or flower? Answer true or false.
        2. If it is, which of these plants is it on? Answer with one name exactly as written, or "none of these": \(offered).
        3. In a few plain words, describe the plant or flower it is on, such as "a yellow daisy-like flower head". Leave it empty if it is not on a plant.
        4. What is the \(animal) doing? Answer with one of these exactly as written, or "cannot tell": \(SightingDoing.choices.joined(separator: "; ")).
        Only say what can be seen in the photo. If you are not sure, say "none of these" or "cannot tell".
        """
    }
}

// MARK: - Keeping the suggestions on the sighting

extension WildlifeObservation {

    /// Writes a second look's suggestions on to the sighting, and the
    /// time it was made, so the look is not repeated each time the form
    /// opens.
    func keep(_ suggestion: SecondLookSuggestion, at time: Date = .now) {
        eiraPlantSuggestion = suggestion.plantName
        eiraPlantSuggestionLatin = suggestion.plantLatin
        eiraDoingSuggestion = suggestion.doing
        eiraSecondLookNote = suggestion.note
        eiraSecondLookAt = time
    }

    /// True when a second look is worth making: the sighting has a photo,
    /// none has been made yet, and the sighting is not of a plant itself.
    var wantsSecondLook: Bool {
        eiraSecondLookAt == nil && !(photos ?? []).isEmpty && taxonGroup != .plant
    }
}
