//
//  PlantingGuideMaker.swift
//  Windfall
//
//  Asks Apple's model on the device to read a plant's notes for the
//  planting guide. The rules that check its answer and build the guide
//  are in PlantingGuide.swift, where they can be tested without a Mac.
//  This file is the part that needs Apple's frameworks.
//
//  Apple's model is used, not whichever model Eira's chat is set to,
//  because this is one short, fixed question asked once for each plant,
//  and Apple's model answers it in a few seconds without loading
//  anything. (⚠️ CHECK: Claude's choice, project doc 150.)
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
enum PlantingGuideMaker {

    /// True when this device can read notes: Apple Intelligence is here
    /// and switched on.
    static var canRead: Bool { EiraEngineFactory.builtInModelIsAvailable }

    /// Reads the plant's notes and keeps what was found on the plant.
    /// Does nothing if there are no notes, they have already been read,
    /// or this device cannot read them. A failure keeps nothing, so the
    /// page tries again the next time it opens.
    static func readNotes(of plant: Plant) async {
        guard PlantingGuide.needsReading(plant), canRead else { return }
        let notes = plant.notes ?? ""
        // The notes as they were when asked. If they are changed while
        // Eira reads, her answer is for the old notes and is not kept.
        let asked = PlantingGuide.notesKey(notes)
        // One reading at a time for each plant's notes, so opening the
        // page again while she reads does not ask twice.
        let job = "\(plant.id.uuidString)|\(asked)"
        guard !underWay.contains(job) else { return }
        underWay.insert(job)
        let name = plant.displayName
        // Asked in a task of its own, not the page's. SwiftUI cancels the
        // page's `.task` as soon as the page closes, and a reading that
        // is slow (Apple's model shares the Mac's graphics chip with any
        // training) would then never finish. This one carries on, and
        // the answer is kept on the plant for next time.
        let found = await Task { await ask(notes: notes, plantName: name) }.value
        underWay.remove(job)
        guard let found, PlantingGuide.notesKey(plant.notes) == asked else { return }
        PlantingGuide.keep(found, on: plant)
    }

    /// The readings under way: each plant's identifier and the
    /// fingerprint of the notes being read.
    private static var underWay: Set<String> = []

    /// Apple's model's answer, or nil when it cannot be asked.
    private static func ask(notes: String, plantName: String) async -> PlantingGuide.GuideFromNotes? {
        #if canImport(FoundationModels) && canImport(CoreAI)
        if #available(iOS 27.0, macOS 27.0, *) {
            let model = SystemLanguageModel.default
            guard model.isAvailable else { return nil }
            let guideSession = LanguageModelSession(
                model: model,
                instructions: """
                You read a gardener's notes about one plant, mostly copied from seed packets, \
                and pick out what they say about sowing and planting it. Use only the notes. \
                Copy figures, units and months exactly as the notes write them. Keep each answer \
                short: at most 25 words, in your own plain words but with the figures exactly as \
                written. Leave an answer empty when the notes do not \
                say. Never add anything from your own knowledge.
                """)
            do {
                // `generating:` makes the model fill in the fields of
                // `PlantingGuideReply` below, so there is nothing to
                // pick out of free text.
                //
                // `maximumResponseTokens` stops an answer that runs on.
                // Tried on the Mac (21 November 2026): with no limit, one
                // reading of Achillea's notes wrote for four minutes until
                // it filled the model's whole memory and failed.
                let reply = try await guideSession.respond(
                    generating: PlantingGuideReply.self,
                    options: GenerationOptions(maximumResponseTokens: 600)) {
                    "The plant: \(plantName)"
                    "Its notes:\n\(PlantingGuide.forModel(notes))"
                }
                let content = reply.content
                return PlantingGuide.GuideFromNotes(howToSow: content.howToSow,
                                                  depth: content.depth,
                                                  spacing: content.spacing,
                                                  germination: content.germination,
                                                  plantingOut: content.plantingOut,
                                                  tips: content.tips)
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
struct PlantingGuideReply {
    @Guide(description: "How and where to sow: indoors or outdoors, in trays, pots or drills, how thinly, what to cover with. Empty if the notes do not say.")
    var howToSow: String
    @Guide(description: "How deep to sow, exactly as written in the notes, such as 1.5cm. Empty if not given.")
    var depth: String
    @Guide(description: "How far apart to sow or plant, and between rows, exactly as written. Empty if not given.")
    var spacing: String
    @Guide(description: "How long seeds take to come up, and at what temperature, exactly as written. Empty if not given.")
    var germination: String
    @Guide(description: "When and how to transplant, harden off or plant out. Empty if the notes do not say.")
    var plantingOut: String
    @Guide(description: "Up to three short tips from the notes about growing it well, such as watering, protecting or thinning. Empty if none.", .maximumCount(3))
    var tips: [String]
}
#endif
