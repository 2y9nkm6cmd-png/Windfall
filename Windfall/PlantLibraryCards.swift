//
//  PlantLibraryCards.swift
//  Windfall
//
//  The cards on the Plants page.
//
//  Until 13 November 2026 the Plants page was Apple's plain list, which
//  did not match Today, Gardens or Wildlife. William asked for a better
//  version. Each plant is now a glass card, the cards sit in a grid under
//  a letter, and a card says what the plant is doing this month.
//
//  The top half of this file is sums with no screen code, so it can be
//  tested anywhere. The bottom half draws the card.
//

import SwiftUI

// MARK: - Sums

/// Turns a set of months into a few short words, such as "Mar to May".
enum MonthSpan {

    /// - `months`: 1 for January to 12 for December.
    /// - `names`: twelve short month names. Left out, the device's own.
    ///
    /// Months next to each other are joined into a run. A run may go
    /// round the end of the year, so November to February reads
    /// "Nov to Feb" and not "Jan, Feb, Nov, Dec".
    static func text(_ months: Set<Int>, names: [String] = Calendar.current.shortMonthSymbols) -> String? {
        let valid = months.filter { (1...12).contains($0) }
        guard !valid.isEmpty, names.count == 12 else { return nil }
        if valid.count == 12 { return "all year" }

        // A run starts at any month whose month before is not in the set.
        func before(_ month: Int) -> Int { month == 1 ? 12 : month - 1 }
        func after(_ month: Int) -> Int { month == 12 ? 1 : month + 1 }
        let starts = valid.filter { !valid.contains(before($0)) }.sorted()

        let runs = starts.map { start -> String in
            var end = start
            var length = 1
            while valid.contains(after(end)) {
                end = after(end)
                length += 1
            }
            switch length {
            case 1:  return names[start - 1]
            case 2:  return "\(names[start - 1]), \(names[end - 1])"
            default: return "\(names[start - 1]) to \(names[end - 1])"
            }
        }
        return runs.joined(separator: ", ")
    }
}

/// What a card on the Plants page says about its plant.
enum PlantCards {

    /// A small coloured label on a card.
    struct Chip: Identifiable, Equatable {
        enum Tone { case sow, flower, pick, pollinator, soil, cover, repel, buy }
        let text: String
        let tone: Tone
        var id: String { text }
    }

    /// The small line above the name: "Fruit · Trees".
    static func kindLine(_ plant: Plant) -> String? {
        var parts: [String] = []
        let kind = PlantKind.of(group: plant.group)
        if kind != .unsorted { parts.append(kind.rawValue) }
        if let layer = plant.layer?.trimmingCharacters(in: .whitespaces), !layer.isEmpty,
           !parts.contains(layer) {
            parts.append(layer)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The line of months: "Sow Mar to May · Pick Jul to Oct".
    /// Nil when the plant's record gives no months at all.
    static func seasonLine(_ plant: Plant) -> String? {
        var parts: [String] = []
        if let sow = MonthSpan.text(PlantSeason.sowing.months(for: plant)) { parts.append("Sow \(sow)") }
        if let flower = MonthSpan.text(PlantSeason.flowering.months(for: plant)) { parts.append("Flowers \(flower)") }
        if let pick = MonthSpan.text(PlantSeason.cropping.months(for: plant)) { parts.append("Pick \(pick)") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The labels on a card. What can be done this month comes first,
    /// then the plant's jobs in the garden.
    static func chips(_ plant: Plant, month: Int) -> [Chip] {
        var chips: [Chip] = []
        if PlantSeason.sowing.months(for: plant).contains(month) { chips.append(Chip(text: "Sow now", tone: .sow)) }
        if PlantSeason.cropping.months(for: plant).contains(month) { chips.append(Chip(text: "Pick now", tone: .pick)) }
        if PlantSeason.flowering.months(for: plant).contains(month) { chips.append(Chip(text: "In flower", tone: .flower)) }
        if plant.status == .wanted { chips.append(Chip(text: "To buy", tone: .buy)) }
        if plant.isPollinator { chips.append(Chip(text: "Pollinator", tone: .pollinator)) }
        if plant.isNitrogenFixer { chips.append(Chip(text: "N-fixer", tone: .soil)) }
        if plant.isDynamicAccumulator { chips.append(Chip(text: "Accumulator", tone: .soil)) }
        if plant.isGroundCover { chips.append(Chip(text: "Ground cover", tone: .cover)) }
        if plant.isRepeller { chips.append(Chip(text: "Pest repeller", tone: .repel)) }
        return chips
    }

    /// The plants under one letter.
    struct LetterGroup: Identifiable {
        let letter: String
        let plants: [Plant]
        var id: String { letter }
    }

    /// Splits a list that is already in A to Z order into its letters.
    /// A name that does not start with a letter goes under "#".
    static func byLetter(_ plants: [Plant]) -> [LetterGroup] {
        var groups: [LetterGroup] = []
        var letter = ""
        var current: [Plant] = []
        for plant in plants {
            let first = plant.commonName.trimmingCharacters(in: .whitespaces).first
            let own = first.map { $0.isLetter ? String($0).uppercased() : "#" } ?? "#"
            if own != letter {
                if !current.isEmpty { groups.append(LetterGroup(letter: letter, plants: current)) }
                letter = own
                current = []
            }
            current.append(plant)
        }
        if !current.isEmpty { groups.append(LetterGroup(letter: letter, plants: current)) }
        return groups
    }
}

// MARK: - The card

/// One plant on the Plants page.
struct PlantCardView: View {

    let plant: Plant
    /// This month, 1 to 12.
    let month: Int

    var body: some View {
        let chips = PlantCards.chips(plant, month: month)

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    if let kind = PlantCards.kindLine(plant) {
                        Text(kind)
                            .font(.caption2)
                            .textCase(.uppercase)
                            .tracking(0.6)
                            .foregroundStyle(Theme.leaf)
                    }
                    Text(plant.commonName)
                        .font(.headline.weight(.medium))
                        .foregroundStyle(Theme.ink)
                    if let variety = plant.variety, !variety.isEmpty {
                        Text(variety)
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink)
                    }
                    if let latin = plant.latinName, !latin.isEmpty {
                        Text(latin)
                            .font(.caption)
                            .italic()
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                Spacer(minLength: 0)
                // Says the card opens something.
                WIconView(.chevronRight, size: 12)
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 4)
            }

            if let season = PlantCards.seasonLine(plant) {
                Text(season)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !chips.isEmpty {
                ChipFlow(spacing: 5) {
                    ForEach(chips) { chip in
                        Text(chip.text)
                            .font(.caption2)
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(chip.tone.colour.opacity(0.38), in: .capsule)
                            .overlay { Capsule().strokeBorder(chip.tone.colour.opacity(0.7), lineWidth: 0.8) }
                    }
                }
            }
        }
        // Fills its place in the grid, so cards in a row are one height.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassCard(padding: 14)
        .contentShape(.rect(cornerRadius: Theme.cardRadius))
        // VoiceOver reads the card as one thing.
        .accessibilityElement(children: .combine)
    }
}

private extension PlantCards.Chip.Tone {
    /// The same colours as the Year page uses for the same things.
    var colour: Color {
        switch self {
        case .sow:        return Theme.sowOutdoors
        case .flower:     return Theme.flowering
        case .pick:       return Theme.harvest
        case .pollinator: return Theme.amber
        case .soil:       return Theme.leafFill
        case .cover:      return Theme.leafFill
        case .repel:      return Theme.petal
        case .buy:        return Theme.water
        }
    }
}

// MARK: - Labels that wrap

/// Lays small labels out in a row and starts a new row when they run out
/// of room. SwiftUI's own HStack would squash them instead.
struct ChipFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: rows.width, height: rows.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(width: bounds.width, subviews: subviews)
        for (index, point) in rows.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                                  proposal: .unspecified)
        }
    }

    /// Where each label goes, and the room they take in all.
    private func arrange(width: CGFloat, subviews: Subviews) -> (points: [CGPoint], width: CGFloat, height: CGFloat) {
        var points: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (points, widest, y + rowHeight)
    }
}
