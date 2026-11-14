//
//  PlantPage.swift
//  Windfall
//
//  What a plant's page shows, worked out from the plant's record.
//
//  The page is a set of cards, one for each group of columns in the
//  spreadsheet the plant library came from: Growth Patterns, Growth
//  Habits, Permaculture Category, Sowing from Seed, Growth Constraints,
//  Human Management, Ecological Interactions and Description.
//
//  This file decides what goes on each card and leaves out anything
//  that is empty, down to whole cards. Most plants do not have every
//  column filled in, and a heading with nothing under it is noise.
//
//  Nothing here draws anything, so it can be tested without a screen.
//  The drawing is in PlantLibraryView.swift (PlantDetailView).
//

import Foundation

enum PlantPage {

    // MARK: - What a card is made of

    /// What a row of months is about. The screen gives each its colour.
    enum MonthKind: String {
        case flowering, growth, fruiting, sowIndoors, sowOutdoors, plantOut, harvest
    }

    /// A row of twelve months, some of them filled in: "Flowering" in
    /// July and August.
    struct MonthRow: Identifiable, Equatable {
        let label: String
        /// Month numbers, 1 for January.
        let months: [Int]
        let kind: MonthKind

        var id: String { label }
    }

    /// One thing known about the plant: "Spacing", "0.15 m".
    struct Fact: Identifiable, Equatable {
        let label: String
        let value: String

        var id: String { label }

        /// A long value is given the full width of its card. A short one
        /// sits beside others.
        var isLong: Bool { value.count > 26 }
    }

    /// One card of the page.
    struct FactCard: Identifiable, Equatable {
        let title: String
        var monthRows: [MonthRow] = []
        var facts: [Fact] = []
        /// Short labels shown as chips, such as "Pollinator plant".
        var tags: [String] = []

        var id: String { title }

        var isEmpty: Bool { monthRows.isEmpty && facts.isEmpty && tags.isEmpty }

        /// Roughly how tall the card will be, in rows. Used to share the
        /// cards between two columns.
        var weight: Int {
            let longFacts = facts.filter(\.isLong).count
            let shortFacts = facts.count - longFacts
            // Short facts sit two or three to a line. Month rows share
            // one extra line for the letters above them.
            return 2 + (monthRows.isEmpty ? 0 : monthRows.count + 1) + longFacts * 2 + (shortFacts + 1) / 2
                + (tags.isEmpty ? 0 : (tags.count + 1) / 2)
        }
    }

    // MARK: - Building the page

    /// The line of facts at the very top: variety, group and whether it
    /// is an annual, a perennial and so on.
    static func summary(for plant: Plant) -> [Fact] {
        [fact("Variety", plant.variety),
         fact("Group", plant.group),
         fact("Classification", plant.classification)].compactMap { $0 }
    }

    /// The cards for a plant, in the spreadsheet's order. A card with
    /// nothing on it is left out.
    static func cards(for plant: Plant) -> [FactCard] {
        var permaculture: [String] = []
        if plant.isPollinator { permaculture.append("Pollinator plant") }
        if plant.isRepeller { permaculture.append("Pest repeller") }
        if plant.isUmbelliferous { permaculture.append("Umbelliferous") }
        if plant.isNitrogenFixer { permaculture.append("Nitrogen fixer") }
        if plant.isDynamicAccumulator { permaculture.append("Dynamic accumulator") }
        if plant.isGroundCover { permaculture.append("Ground cover") }

        let all = [
            FactCard(title: "Growth Patterns",
                     monthRows: [months("Flowering", plant.floweringMonthsText, .flowering),
                                 months("Stem growth", plant.stemGrowthMonthsText, .growth),
                                 months("Foliage", plant.foliageMonthsText, .growth),
                                 months("Fruiting", plant.fruitingMonthsText, .fruiting)].compactMap { $0 },
                     facts: [fact("Plant type", plant.plantType),
                             fact("Habits", plant.habits)].compactMap { $0 }),
            FactCard(title: "Growth Habits",
                     facts: [fact("Max height", plant.maxHeightM, unit: "m"),
                             fact("Spread", plant.spreadM, unit: "m"),
                             fact("Root depth", plant.rootDepthM, unit: "m"),
                             fact("Spacing", plant.spacingM, unit: "m"),
                             fact("Flower form", plant.flowerForm),
                             fact("Layer", plant.layer)].compactMap { $0 }),
            FactCard(title: "Permaculture Category", tags: permaculture),
            FactCard(title: "Sowing from Seed",
                     monthRows: [months("Sow indoors", plant.sowIndoorsMonthsText, .sowIndoors),
                                 months("Sow outdoors", plant.sowOutdoorsMonthsText, .sowOutdoors),
                                 months("Plant out", plant.plantOutMonthsText, .plantOut),
                                 months("Harvest", plant.harvestMonthsText, .harvest)].compactMap { $0 },
                     facts: [days("Germination", plant.germinationDaysText),
                             days("Sow to crop", plant.sowToCropText),
                             fact("Sowing depth", plant.sowingDepthMM, unit: "mm"),
                             fact("Propagation", plant.propagation)].compactMap { $0 }),
            FactCard(title: "Growth Constraints",
                     facts: [fact("Sun / shade", plant.sunShade),
                             fact("Position", plant.position),
                             fact("Hardiness", plant.hardiness),
                             fact("Soil pH", plant.soilPH),
                             fact("Soil conditions", plant.preferredSoilConditions),
                             fact("Pests", plant.knownPests),
                             fact("Diseases", plant.knownDiseases)].compactMap { $0 }),
            FactCard(title: "Human Management",
                     facts: [fact("Pruning", plant.pruning),
                             fact("Pruning group", plant.pruningGroup),
                             fact("Culinary uses", plant.culinaryUses),
                             fact("Medicinal uses", plant.medicinalUses),
                             fact("Toxicity", plant.toxicityCautions)].compactMap { $0 }),
            FactCard(title: "Ecological Interactions",
                     facts: [fact("Partner plants", plant.partnerPlants),
                             fact("Antagonistic plants", plant.antagonisticPlants),
                             fact("Pollinators", plant.pollinators)].compactMap { $0 }),
            FactCard(title: "Description",
                     facts: [fact("Appearance", plant.appearance),
                             fact("History", plant.history),
                             fact("Notes", plant.notes)].compactMap { $0 })
        ]
        return all.filter { !$0.isEmpty }
    }

    /// Shares cards between two columns so that they come out about the
    /// same height. Each card in turn goes to whichever column is
    /// shorter so far, so the order down each column stays the
    /// spreadsheet's order.
    static func twoColumns(_ cards: [FactCard]) -> (left: [FactCard], right: [FactCard]) {
        var left: [FactCard] = []
        var right: [FactCard] = []
        var leftWeight = 0
        var rightWeight = 0
        for factCard in cards {
            if leftWeight <= rightWeight {
                left.append(factCard)
                leftWeight += factCard.weight
            } else {
                right.append(factCard)
                rightWeight += factCard.weight
            }
        }
        return (left, right)
    }

    // MARK: - The plant in the garden

    /// One sowing or planting of the plant, as its page words it.
    struct PlantingLine: Identifiable, Equatable {
        let id: UUID
        /// "Planted", "Sown" or "On record".
        let verb: String
        /// The day it was sown or planted. Nil when it was only put on
        /// record, as happens for a tree that was here before the app.
        let date: Date?
        /// Where and how many: "Bed 3 · A · 6 plants". "Not placed" if
        /// it has no bed.
        let detail: String
        /// "Growing", "Sown", "Finished" and so on.
        let status: String
    }

    /// The plant's sowings and plantings, newest first.
    ///
    /// The words follow the journal's: a plant, a tree or a tuber is
    /// "planted", seed is "sown". See `Planting.timelineTitle`.
    static func plantingLines(for plant: Plant) -> [PlantingLine] {
        (plant.plantings ?? [])
            // One with no date goes by the day it was put on record.
            .sorted { ($0.dateSown ?? $0.createdAt) > ($1.dateSown ?? $1.createdAt) }
            .map { planting in
                let isPlanted = planting.startedFrom == .plant
                var verb = isPlanted ? "Planted" : "Sown"
                if planting.dateSown == nil { verb = "On record" }

                var bits: [String] = [planting.bedNames.isEmpty ? "Not placed" : planting.bedNames]
                if let count = planting.quantitySown, count > 0 {
                    let thing = isPlanted ? "plant" : "seed"
                    bits.append("\(count) \(thing)\(count == 1 ? "" : "s")")
                }
                if let round = planting.successionRound { bits.append("round \(round)") }

                return PlantingLine(id: planting.id, verb: verb, date: planting.dateSown,
                                    detail: bits.joined(separator: " · "),
                                    status: statusWords(planting.status))
            }
    }

    /// A planting's stage in a word or two.
    static func statusWords(_ status: PlantingStatus) -> String {
        switch status {
        case .planned: return "Planned"
        case .sown: return "Sown"
        case .germinated: return "Up"
        case .plantedOut: return "Planted out"
        case .growing: return "Growing"
        case .harvesting: return "Harvesting"
        case .finished: return "Finished"
        case .failed: return "Failed"
        }
    }

    // MARK: - Pieces

    /// A fact, or nil if there is nothing to say. A unit is added when
    /// the value ends in a figure, so "0.15" reads "0.15 m" and a value
    /// that already has its unit is left alone.
    private static func fact(_ label: String, _ value: String?, unit: String? = nil) -> Fact? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        if let unit, let last = trimmed.last, last.isNumber {
            return Fact(label: label, value: "\(trimmed) \(unit)")
        }
        return Fact(label: label, value: trimmed)
    }

    /// A number of days, or a range of them: "14 days", "7 to 21 days".
    private static func days(_ label: String, _ text: String?) -> Fact? {
        RangeParser.range(in: text).map { Fact(label: label, value: "\($0.description) days") }
    }

    private static func months(_ label: String, _ text: String?, _ kind: MonthKind) -> MonthRow? {
        let found = MonthParser.months(in: text)
        return found.isEmpty ? nil : MonthRow(label: label, months: found, kind: kind)
    }
}
