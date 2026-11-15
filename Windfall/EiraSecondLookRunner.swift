//
//  EiraSecondLookRunner.swift
//  Windfall
//
//  Runs Eira's second look at a sighting's photo: the image model for
//  the plant, then Apple's own model, shown the photo, for which plant
//  and what the animal is doing. The rules that turn their answers into
//  suggestions are in EiraSecondLook.swift, where they can be tested
//  without a Mac. This file is the part that needs Apple's frameworks.
//

import Foundation
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
enum EiraSecondLookRunner {

    /// Looks at the sighting's photos and keeps the suggestions on it.
    ///
    /// Each part may fail on its own: no image model on this device, no
    /// Apple Intelligence, an older system. Whatever is found is kept,
    /// and the time is written even when nothing is, so the form does
    /// not ask again each time it opens ("Look again" asks on purpose).
    ///
    /// - `yourPlants`: William's own plants, for matching a name to one
    ///   of his.
    static func look(at observation: WildlifeObservation, yourPlants: [Plant]) async {
        // Up to three photos, the kept copy where there is one. `prefix`
        // takes the first few of a list.
        let photos = (observation.photos ?? [])
            .compactMap { $0.imageData ?? $0.thumbnailData }
            .prefix(3)
        guard !photos.isEmpty else {
            // The photo is not kept in the app (only in the photo
            // folder), so there is nothing to look at here. Saying so
            // stops the form waiting for ever.
            observation.keep(SecondLookSuggestion(note: "Eira could not open the photo to look at it."))
            return
        }

        // 1. The image model, plants only.
        let plantGuess = try? await SpeciesEye.shared.plantGuess(forPhotos: Array(photos))
        let plants = plantGuess?.candidates ?? []

        // 2. Apple's model, shown the first photo.
        let animal = observation.commonName ?? observation.scientificName ?? observation.provisionalID ?? "an animal"
        let appleSaw = await askAppleModel(photo: photos[photos.startIndex],
                                       animal: animal,
                                       plantNames: plants.map(\.entry.title))

        // 3. The rules (EiraSecondLook.swift).
        let known: [KnownPlant] = yourPlants.compactMap { plant in
            guard let latin = plant.latinName, !latin.isEmpty else { return nil }
            return KnownPlant(name: plant.displayName, latin: latin)
        }
        observation.keep(EiraSecondLook.suggestion(plants: plants, seen: appleSaw, yourPlants: known))
    }

    /// One of William's plants for the suggested name, if there is one:
    /// the display name first, then the scientific name.
    static func plant(named name: String?, latin: String?, in plants: [Plant]) -> Plant? {
        if let name, let same = plants.first(where: { $0.displayName == name }) { return same }
        guard let latin else { return nil }
        let key = SpeciesName.key(latin)
        return plants.first { SpeciesName.key($0.latinName) == key }
    }

    /// Asks Apple's model about the photo. Nil when it cannot look: no
    /// Apple Intelligence, a system before 27, a model that cannot take
    /// pictures, or any failure.
    private static func askAppleModel(photo: Data, animal: String, plantNames: [String]) async -> SeenInPhoto? {
        #if canImport(FoundationModels) && canImport(CoreAI)
        if #available(iOS 27.0, macOS 27.0, *) {
            let model = SystemLanguageModel.default
            // "vision" is Apple's word for being able to take a picture.
            guard model.isAvailable, model.capabilities.contains(.vision),
                  let picture = SpeciesEye.picture(from: photo, longestSide: 1024) else { return nil }
            let lookSession = LanguageModelSession(
                model: model,
                instructions: "You look at a gardener's wildlife photo and answer only from what can be seen. Never guess a name that is not offered.")
            do {
                // `generating:` makes the model fill in the fields of
                // `SecondLookReply` below, so there is nothing to pick out
                // of free text. `Attachment` puts the photo in the
                // question beside the words.
                let reply = try await lookSession.respond(generating: SecondLookReply.self) {
                    EiraSecondLook.question(animal: animal, plantNames: plantNames)
                    Attachment(picture)
                }
                let content = reply.content
                return SeenInPhoto(isOnPlant: content.isOnPlant,
                                   plantChoice: content.plantChoice,
                                   plantWords: content.plantWords,
                                   doing: content.doing)
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels) && canImport(CoreAI)
/// The shape of Apple's model's answer. `@Generable` lets the framework
/// make the model fill these in, and `@Guide` tells it what each is.
@available(iOS 27.0, macOS 27.0, *)
@Generable
struct SecondLookReply {
    @Guide(description: "true if the animal is on, at or touching a plant or flower")
    var isOnPlant: Bool
    @Guide(description: "One of the offered plant names exactly as written, or \"none of these\"")
    var plantChoice: String
    @Guide(description: "A few plain words describing the plant or flower it is on, or empty")
    var plantWords: String
    @Guide(description: "One of the offered answers for what it is doing exactly as written, or \"cannot tell\"")
    var doing: String
}
#endif
