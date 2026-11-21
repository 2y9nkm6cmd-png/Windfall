//
//  PlantNames.swift
//  Windfall
//
//  One way of writing each crop's name.
//
//  William's spreadsheet grew over years, so the same crop is written
//  more than one way: "Leek" on one sheet and "Leeks" on another,
//  "Parsnip" and "Parsnips", "French Beans", "French beans" and
//  "Dwarf/french bean". The companion planting sheet says "Radishes"
//  where the library says "Radish". Each spelling was a different
//  plant to the app, so:
//
//    - Leek 'Musselburgh' was two records, one for each garden.
//    - "Sow again" (doc 148) would have run two chains for one crop.
//    - A companion pair for "Radishes" never found the radishes.
//    - The wildlife link for "Meadow cranesbill" never found
//      "Meadow crane's-bill", so its bees were not shown on its page.
//
//  This file holds the list of spellings and the name each becomes,
//  and the one-off job that tidies a library already on a device.
//  Loading a spreadsheet file tidies every name as it comes in
//  (GardenData.swift), so the file can stay as William wrote it.
//
//  The rule chosen for the crops is the singular, as most of the
//  library already has it: Pea, Radish, Turnip, Onion, Broad bean.
//
//  A name changed by hand on a plant's page is left as it is: the
//  person chose it.
//

import Foundation
import SwiftData

/// On the main actor, like the importer it borrows `relink` from.
@MainActor
enum PlantNames {

    /// Bump this when the list below changes, so that a library on a
    /// device is tidied again with the new lines.
    static let version = 1

    /// The setting that records which version of the list a device's
    /// library has been tidied with.
    static let tidiedKey = "plantNamesTidiedVersion"

    /// Each spelling, in small letters, and the name it becomes.
    /// A name not in this list is left exactly as it was written.
    static let spellings: [String: String] = [
        // Two spellings of one crop in the plant sheets.
        "leeks": "Leek",
        "parsnips": "Parsnip",
        "french beans": "French bean",
        "dwarf/french bean": "French bean",
        "ox-eye daisy": "Oxeye Daisy",
        "overwinter mix": "Overwinter mix",
        // The plant sheets call it "Rocket salad" and the companion
        // sheet "Rocket". Rocket is what it is.
        "rocket salad": "Rocket",

        // The companion planting sheet's plurals and qualifiers.
        "broad beans": "Broad bean",
        "daffodils": "Daffodil",
        "geums": "Geum",
        "radishes": "Radish",
        "turnips": "Turnip",
        "zinnias": "Zinnia",
        "mint (garden)": "Mint",
        "savory (summer)": "Savory",

        // The wildlife links, where the plant is the same species as
        // one in the library under another name (checked by Latin name).
        "meadow cranesbill": "Meadow crane's-bill",
        "bird's-foot trefoil": "Common bird's-foot-trefoil",
        "yellow flag iris": "Yellow Iris",
    ]

    /// The tidy name for a name as written. Spaces at the ends are
    /// trimmed. Capitals do not matter when looking a name up.
    static func tidy(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return spellings[trimmed.lowercased()] ?? trimmed
    }

    // MARK: - Tidying a library already on a device

    /// What the one-off tidy did, for its message and the tests.
    struct Summary: Equatable {
        var renamed = 0
        var merged = 0
        var companionNames = 0
        var linkNames = 0
        var isEmpty: Bool { renamed + merged + companionNames + linkNames == 0 }
    }

    /// Tidies the library once for each version of the list.
    ///
    /// The starter data is only loaded into an empty library, so a
    /// device that already has William's plants never meets the tidy
    /// import. This brings it into line. It runs at start-up and does
    /// nothing after the first time.
    @discardableResult
    static func tidyLibraryIfNeeded(in context: ModelContext,
                                    defaults: UserDefaults = .standard) -> Summary? {
        guard defaults.integer(forKey: tidiedKey) < version else { return nil }
        let summary = tidyLibrary(in: context)
        defaults.set(version, forKey: tidiedKey)
        return summary
    }

    /// Renames plants to their tidy names. Where two records turn out
    /// to be one plant (Leek 'Musselburgh' and Leeks 'Musselburgh'),
    /// the two become one: everything recorded against either is kept.
    /// Companion pairs and wildlife links are tidied the same way, and
    /// the links are joined to their plants again.
    ///
    /// Safe to run more than once: a tidy library has nothing to change.
    @discardableResult
    static func tidyLibrary(in context: ModelContext) -> Summary {
        var summary = Summary()
        let plants = (try? context.fetch(FetchDescriptor<Plant>())) ?? []

        // Group the plants by the name and variety they will have once
        // tidied. A name chosen by hand is not tidied, so such a plant
        // is in a group of its own under its own name.
        var groups: [String: [Plant]] = [:]
        var order: [String] = []
        for plant in plants {
            let name = keepsItsName(plant) ? plant.commonName : tidy(plant.commonName)
            let key = PlantFacts.libraryKey(name: name, variety: plant.variety)
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(plant)
        }

        for key in order {
            guard let group = groups[key] else { continue }
            let keeper = chooseKeeper(group)
            if !keepsItsName(keeper) {
                let tidied = tidy(keeper.commonName)
                if tidied != keeper.commonName {
                    keeper.commonName = tidied
                    summary.renamed += 1
                }
            }
            for other in group where other !== keeper {
                merge(other, into: keeper, in: context)
                summary.merged += 1
            }
        }

        for pair in (try? context.fetch(FetchDescriptor<CompanionPair>())) ?? [] {
            let one = tidy(pair.plantOneName), two = tidy(pair.plantTwoName)
            if one != pair.plantOneName || two != pair.plantTwoName {
                pair.plantOneName = one
                pair.plantTwoName = two
                summary.companionNames += 1
            }
        }
        for link in (try? context.fetch(FetchDescriptor<PlantFaunaLink>())) ?? [] {
            let name = tidy(link.plantName)
            if name != link.plantName {
                link.plantName = name
                summary.linkNames += 1
            }
        }

        if !summary.isEmpty {
            try? GardenDataImporter().relink(in: context)
            try? context.save()
        }
        return summary
    }

    /// True when the plant's name was changed by hand in the app.
    private static func keepsItsName(_ plant: Plant) -> Bool {
        plant.changedByHand.contains("commonName")
    }

    /// Which record of a group stays. The one already called by the
    /// tidy name, then the one with the most recorded against it.
    private static func chooseKeeper(_ group: [Plant]) -> Plant {
        if group.count == 1 { return group[0] }
        func weight(_ plant: Plant) -> Int {
            (plant.plantings?.count ?? 0) + (plant.seedPackets?.count ?? 0)
        }
        let named = group.filter { $0.commonName == tidy($0.commonName) }
        let pool = named.isEmpty ? group : named
        return pool.max { weight($0) < weight($1) } ?? group[0]
    }

    /// Moves everything from `other` on to `keeper`, then deletes
    /// `other`. Nothing recorded is lost.
    static func merge(_ other: Plant, into keeper: Plant, in context: ModelContext) {
        // Facts: a box empty on the keeper is filled from the other.
        // A box the other had changed by hand wins over one that was
        // only loaded from the file, and stays marked as changed.
        for factField in PlantFacts.all where factField.key != "commonName" && factField.key != "variety" {
            let theirs = PlantFacts.value(of: factField, in: other)
            guard !theirs.isEmpty else { continue }
            let ours = PlantFacts.value(of: factField, in: keeper)
            let theyTyped = other.changedByHand.contains(factField.key)
            let weTyped = keeper.changedByHand.contains(factField.key)
            if ours.isEmpty || (theyTyped && !weTyped) {
                PlantFacts.setValue(theirs, for: factField, in: keeper)
                if theyTyped && !weTyped { keeper.changedByHand.append(factField.key) }
            }
        }
        for site in other.sourceSites where !keeper.sourceSites.contains(site) {
            keeper.sourceSites.append(site)
        }
        if other.status == .growing { keeper.status = .growing }
        if keeper.importedAs == nil { keeper.importedAs = other.importedAs }

        // Sowings and seed packets. The list on the other record is
        // emptied first: it deletes what it holds when the record is
        // deleted, so nothing must still be on it by then.
        let plantings = other.plantings ?? []
        let packets = other.seedPackets ?? []
        other.plantings = []
        other.seedPackets = []
        for planting in plantings { planting.plant = keeper }
        for packet in packets { packet.plant = keeper }

        // Everything else that points at a plant.
        for entry in (try? context.fetch(FetchDescriptor<DiaryEntry>())) ?? [] where entry.plant === other {
            entry.plant = keeper
        }
        for survey in (try? context.fetch(FetchDescriptor<Survey>())) ?? [] where survey.targetPlant === other {
            survey.targetPlant = keeper
            survey.targetPlantName = keeper.commonName
        }
        for sighting in (try? context.fetch(FetchDescriptor<WildlifeObservation>())) ?? [] where sighting.associatedPlant === other {
            sighting.associatedPlant = keeper
            sighting.associatedPlantName = keeper.commonName
        }
        for link in (try? context.fetch(FetchDescriptor<PlantFaunaLink>())) ?? [] where link.plant === other {
            link.plant = keeper
        }
        // Crosses and kept facts hold a plant by its id, as text or as
        // an id, not as a link.
        let oldID = other.id.uuidString, newID = keeper.id.uuidString
        for cross in (try? context.fetch(FetchDescriptor<PlantCross>())) ?? [] {
            if cross.seedParentKey == oldID { cross.seedParentKey = newID }
            if cross.pollenParentKey == oldID { cross.pollenParentKey = newID }
        }
        for fact in (try? context.fetch(FetchDescriptor<KeptFact>())) ?? [] where fact.plantID == other.id {
            fact.plantID = keeper.id
        }

        context.delete(other)
    }
}
