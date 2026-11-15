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
//  Which facts there are, and which card each belongs on, is not
//  decided here. That is the list in PlantFacts.swift, which the sheet
//  that edits a plant uses too, so the two can never disagree: whatever
//  can be typed in is shown, and whatever is shown can be changed.
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
        /// Where the value came from, if it was kept from a website or
        /// a book: "RHS, kept Nov 2026". Nil for everything else, which
        /// is most things. See KeptFacts.swift.
        var source: String? = nil

        var id: String { label }

        /// A long value is given the full width of its card. A short one
        /// sits beside others.
        var isLong: Bool { value.count > 26 }

        /// Roughly how many rows a long value takes: one for its name
        /// and one for each sixty letters or so. A page of sowing notes
        /// is many times taller than one line about pests, and the
        /// sharing-out between two columns needs to know that.
        var rows: Int { 1 + max(1, (value.count + 59) / 60) }
    }

    /// One card of the page.
    struct FactCard: Identifiable, Equatable {
        /// Which group of facts the card holds. Its name is the card's
        /// heading, and the page hands it to the editing sheet so that
        /// the sheet opens at the same card.
        let group: PlantFacts.Group
        var monthRows: [MonthRow] = []
        var facts: [Fact] = []
        /// Short labels shown as chips, such as "Pollinator plant".
        var tags: [String] = []

        var title: String { group.title }
        var id: String { title }

        var isEmpty: Bool { monthRows.isEmpty && facts.isEmpty && tags.isEmpty }

        /// Roughly how tall the card will be, in rows. Used to share the
        /// cards between two columns.
        var weight: Int {
            let longFacts = facts.filter(\.isLong)
            let shortFacts = facts.count - longFacts.count
            // Short facts sit two or three to a line. Month rows share
            // one extra line for the letters above them. A long fact
            // counts for as many rows as it has words to fill.
            return 2 + (monthRows.isEmpty ? 0 : monthRows.count + 1) + longFacts.map(\.rows).reduce(0, +)
                + (shortFacts + 1) / 2 + (tags.isEmpty ? 0 : (tags.count + 1) / 2)
        }
    }

    // MARK: - Building the page

    /// The line of facts at the very top: variety, group, whether it is
    /// an annual or a perennial, and the form it is held in. The common
    /// and Latin names are left out of it, because they are the page's
    /// title.
    static func summary(for plant: Plant) -> [Fact] {
        PlantFacts.fields(in: .naming)
            .filter { $0.key != "commonName" && $0.key != "latinName" }
            .compactMap { factField in
                let text = PlantFacts.value(of: factField, in: plant)
                guard !text.isEmpty, !PlantFacts.isPlaceholder(text) else { return nil }
                return Fact(label: factField.label, value: text)
            }
    }

    /// The cards for a plant, in the spreadsheet's order. A card with
    /// nothing on it is left out.
    ///
    /// `sources` gives, for the name of a fact ("Pruning"), where its
    /// value came from. A fact named there carries that as its source.
    static func cards(for plant: Plant, sources: [String: String] = [:]) -> [FactCard] {
        let filled = PlantFacts.Group.cards.map { card(for: $0, of: plant) }.filter { !$0.isEmpty }
        guard !sources.isEmpty else { return filled }
        return filled.map { factCard in
            var marked = factCard
            marked.facts = factCard.facts.map { fact in
                var copy = fact
                copy.source = sources[fact.label]
                return copy
            }
            return marked
        }
    }

    /// The groups with nothing to show yet, in order. These are the
    /// cards the page leaves out. It lists them at its foot, each a way
    /// in to the editing sheet, so that an empty group can be started.
    static func emptyGroups(for plant: Plant) -> [PlantFacts.Group] {
        PlantFacts.Group.cards.filter { card(for: $0, of: plant).isEmpty }
    }

    /// One card: every filled-in fact of its group, each put in the
    /// part of the card that suits what kind of fact it is.
    private static func card(for factGroup: PlantFacts.Group, of plant: Plant) -> FactCard {
        var factCard = FactCard(group: factGroup)
        for factField in PlantFacts.fields(in: factGroup) {
            let text = PlantFacts.value(of: factField, in: plant)
            // Nothing there, or only the spreadsheet's "*" or "?".
            guard !text.isEmpty, !PlantFacts.isPlaceholder(text) else { continue }

            switch factField.kind {
            case .yesNo:
                factCard.tags.append(factField.label)
            case .months(let monthKind):
                let found = MonthParser.months(in: text)
                if found.isEmpty {
                    // Words that are not months, such as "Spring to
                    // summer", are still worth showing, as plain text.
                    factCard.facts.append(Fact(label: factField.label, value: text))
                } else {
                    factCard.monthRows.append(MonthRow(label: factField.label, months: found, kind: monthKind))
                }
            case .measure(let unit):
                factCard.facts.append(Fact(label: factField.label, value: measured(text, unit: unit)))
            case .duration:
                // In its own unit: "20 weeks". Text with no figure in it
                // is shown as it is.
                factCard.facts.append(Fact(label: factField.label, value: DurationParser.describe(text) ?? text))
            case .text, .longText:
                factCard.facts.append(Fact(label: factField.label, value: text))
            }
        }
        return factCard
    }

    /// Shares cards between two columns so that they come out about the
    /// same height. Each card in turn goes to whichever column is
    /// shorter so far, so the order down each column stays the
    /// spreadsheet's order.
    ///
    /// The two head starts are the heights, in rows, of what else the
    /// page puts in each column: the sowings and plantings card at the
    /// top of the right-hand one, and the companions, pests and "Add
    /// information" cards at the foot of the left-hand one. The
    /// sharing-out counts them as already there.
    ///
    /// The two weights handed back are how tall each column came out,
    /// head start included. The page puts its "Add information" card at
    /// the foot of whichever is shorter.
    static func twoColumns(_ cards: [FactCard], leftHeadStart: Int = 0, rightHeadStart: Int = 0)
        -> (left: [FactCard], right: [FactCard], leftWeight: Int, rightWeight: Int) {
        var left: [FactCard] = []
        var right: [FactCard] = []
        var leftWeight = leftHeadStart
        var rightWeight = rightHeadStart
        for factCard in cards {
            if leftWeight <= rightWeight {
                left.append(factCard)
                leftWeight += factCard.weight
            } else {
                right.append(factCard)
                rightWeight += factCard.weight
            }
        }
        return (left, right, leftWeight, rightWeight)
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

    /// Roughly how tall the sowings and plantings card is, in rows: its
    /// title, two rows for each line and the row of buttons. With none
    /// it has one line saying so. Used as the head start in `twoColumns`.
    static func plantingsCardWeight(lines: Int) -> Int {
        4 + max(lines, 1) * 2
    }

    /// Roughly how tall the cards at the foot of the left-hand column
    /// are, in rows: the link to companions, and the pests card if the
    /// plant has any (`pests` is how many).
    static func footCardsWeight(pests: Int) -> Int {
        3 + (pests == 0 ? 0 : 2 + (pests + 1) / 2)
    }

    /// Roughly how tall the drawing cards at the top of the left-hand
    /// column are, in rows: "Life stages" is a title and a row of
    /// 96-point drawings with their labels; the Leaf and Flower cards,
    /// side by side, are a title and a drawing about as tall. `cards` is
    /// how many rows of drawing cards the page shows (0, 1 or 2).
    static func drawingCardsWeight(cards: Int) -> Int {
        max(cards, 0) * 7
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

    /// A figure with its unit. The unit is added when the value ends in
    /// a figure, so "0.15" reads "0.15 m" and a value that already has
    /// its unit, or is words, is left alone.
    private static func measured(_ text: String, unit: String) -> String {
        guard let last = text.last, last.isNumber else { return text }
        return "\(text) \(unit)"
    }
}
