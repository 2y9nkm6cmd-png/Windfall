//
//  Crosses.swift
//  Windfall
//
//  A record of a cross: one plant's flowers pollinated with another's
//  pollen, on purpose or by whatever was flying.
//
//  WHY IT IS A RECORD OF ITS OWN
//  The cross is made in spring, when the flowers are open. The seed is
//  gathered in autumn and sown the year after. By then nobody remembers
//  which tree gave the pollen. So the cross is written down on the day,
//  and next year's sowing picks it from a list and takes its parents
//  from it. (William, 13 November 2026: "if we crossed things the
//  previous year, we need to be able to record what we grow and forced
//  crossed with.")
//
//  HOW THE PARENTS ARE KEPT
//  Each parent is kept twice: as a key (the plant's own identifier, as
//  text) and as its name in words. The name is what is shown, and it
//  still reads correctly if the plant is later removed from the library
//  or was never in it, such as a neighbour's tree. The key lets the app
//  find the plant again when it can.
//
//  The record and the sums are here. The screens are in CrossViews.swift.
//

import Foundation
import SwiftData

// `@Model` makes this a kind of record that SwiftData keeps in the
// app's database. Every property has a starting value or may be empty,
// which is what iCloud sync will need later.
@Model
final class PlantCross {

    var id: UUID = UUID()
    var createdAt: Date = Date.now

    /// The day the flowers were pollinated.
    var date: Date = Date.now

    /// The plant that carried the fruit and the seed.
    var seedParentKey: String?
    var seedParentName: String = ""

    /// The plant the pollen came from. Both empty if it is not known,
    /// which is the usual case when the bees did the work.
    var pollenParentKey: String?
    var pollenParentName: String?

    /// True if the pollen was put on by hand.
    var wasByHand: Bool = true
    /// True if the flowers were bagged, so nothing else could reach them.
    var wasBagged: Bool = false
    var flowersPollinated: Int?

    // Filled in later, when the fruit is ripe.
    var seedsCollected: Int?
    var seedCollectedOn: Date?

    var notes: String?

    init() {}

    /// "Apple, Pendragon × Egremont Russet", or with "not known" for
    /// the pollen parent.
    var title: String {
        CrossBook.title(seedParent: seedParentName, pollenParent: pollenParentName)
    }
}

/// The sums for crosses. Nothing here touches the database or the
/// screen, so it can be tested alone.
enum CrossBook {

    /// What the sums need to know about one recorded cross.
    struct Line: Equatable {
        let id: UUID
        let seedParentKey: String?
        let seedParentName: String
        let date: Date
    }

    /// "Pendragon × Egremont Russet". An empty seed parent reads
    /// "Not yet chosen".
    static func title(seedParent: String, pollenParent: String?) -> String {
        let seed = seedParent.trimmingCharacters(in: .whitespaces)
        let pollen = (pollenParent ?? "").trimmingCharacters(in: .whitespaces)
        return "\(seed.isEmpty ? "Not yet chosen" : seed) × \(pollen.isEmpty ? "not known" : pollen)"
    }

    /// The kind of plant a name belongs to, without its variety:
    /// "Apple — Pendragon", "Apple (Cider)" and "Apple, Katy" are all
    /// "apple". Used to offer the crosses and parents most likely meant.
    static func kind(of name: String) -> String {
        let cut = name.split(whereSeparator: { $0 == "(" || $0 == "—" || $0 == "," || $0 == "×" }).first
        return (cut.map(String.init) ?? name).trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// The crosses to offer when seed of a plant is being sown, best
    /// guess first: crosses made on that very plant, then crosses made
    /// on another plant of the same kind. Newest first within each.
    /// Crosses on other kinds of plant are left out.
    static func offered(forPlantKey plantKey: String, named name: String, from lines: [Line]) -> [UUID] {
        let wanted = kind(of: name)
        let newest = lines.sorted { $0.date > $1.date }
        let exact = newest.filter { $0.seedParentKey == plantKey }
        let alike = newest.filter { $0.seedParentKey != plantKey && !wanted.isEmpty && kind(of: $0.seedParentName) == wanted }
        return (exact + alike).map(\.id)
    }

    /// A line of facts for a cross's card: "By hand · bagged · 6 flowers
    /// · 14 seeds".
    static func facts(byHand: Bool, bagged: Bool, flowers: Int?, seeds: Int?) -> String {
        var parts = [byHand ? "By hand" : "Open pollinated"]
        if bagged { parts.append("bagged") }
        if let flowers, flowers > 0 { parts.append("\(flowers) \(flowers == 1 ? "flower" : "flowers")") }
        if let seeds, seeds > 0 { parts.append("\(seeds) \(seeds == 1 ? "seed" : "seeds")") }
        return parts.joined(separator: " · ")
    }
}
