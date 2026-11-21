//
//  SowAgain.swift
//  Windfall
//
//  Sow again: ticking a sowing offers the next one, for a crop that
//  keeps coming (knowledge base doc 148).
//
//  William, 21 November 2026: "when you've sown a crop and tap the check
//  box, this sets it so that it reappears when it's time to sow again,
//  so that you get a continuous crop, or presents you with the option."
//  His four choices:
//
//    1. Ask each time. After a sowing, a card offers the next one:
//       Yes, Change date, Not this time.
//    2. One chain per crop. "Sow lettuce again", then pick the variety.
//    3. Fixed weeks after sowing, a gap for each crop, which he can
//       change on the plant's page.
//    4. The tick records the sowing, dated today. Where and how many
//       are optional.
//
//  This file holds the rules. The sheet that asks is SowAgainViews.swift,
//  and the job it saves is an ordinary `GardenJob` (GardenJobs.swift)
//  with its `cropName` filled in, so "This week", overdue and ticking
//  all work as for any job of your own.
//
//  Nothing here draws anything, so it can be tested without a screen.
//
//  ⚠️ CHECK (cards f-sow-again-gaps-148 and d-sow-again-details-148):
//  the starting gaps below, the order varieties are offered in, and that
//  a sow-again job is due from its day for a week.
//

import Foundation

/// On the main actor, as PlantNames is, whose tidy names it keys on.
@MainActor
enum SowAgain {

    // MARK: - The crop

    /// The crop a plant belongs to, as a key: its tidy name in small
    /// letters. Every variety of lettuce has the key "lettuce". The
    /// names were tidied on 21 November 2026 (PlantNames.swift), so a
    /// crop has one name, and a name typed by hand is tidied here too.
    static func cropKey(of plant: Plant) -> String {
        cropKey(PlantNames.tidy(plant.commonName))
    }

    static func cropKey(_ name: String) -> String {
        PlantNames.tidy(name).trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// The crop's name for a sentence: "Lettuce sown", "Sow lettuce again".
    static func cropName(of plant: Plant) -> String {
        PlantNames.tidy(plant.commonName)
    }

    /// Every variety of a crop in the library, apart from plants no
    /// longer grown.
    static func varieties(ofCrop key: String, in plants: [Plant]) -> [Plant] {
        plants.filter { $0.status != .previouslyOwned && cropKey(of: $0) == key }
    }

    /// True when a plant's sowing months, indoors or out, include `month`.
    static func canSow(_ plant: Plant, inMonth month: Int) -> Bool {
        MonthParser.months(in: plant.sowIndoorsMonthsText).contains(month)
            || MonthParser.months(in: plant.sowOutdoorsMonthsText).contains(month)
    }

    // MARK: - Which variety

    /// The varieties to offer when sowing a crop, in this order:
    ///
    ///  1. the variety sown last time,
    ///  2. varieties with seed in stock (a packet with seed left and not
    ///     past its sow-by date),
    ///  3. other varieties.
    ///
    /// Only varieties that can be sown in `month` are offered: that is
    /// what hands a summer lettuce over to a winter one in autumn. If
    /// none can, every variety is offered, so a sowing out of season can
    /// still be recorded.
    static func offeredVarieties(ofCrop key: String, plants: [Plant], packets: [SeedPacket],
                                 lastSown: Plant?, month: Int, today: Date = .now) -> [Plant] {
        let all = varieties(ofCrop: key, in: plants)
        let open = all.filter { canSow($0, inMonth: month) }
        let pool = open.isEmpty ? all : open
        let stocked = Set(packets.filter { packet in
            SeedStock.hasSeed(packet) && !(packet.useByDate.map { $0 < today } ?? false)
        }.compactMap { $0.plant?.id })

        func rank(_ plant: Plant) -> Int {
            if let lastSown, plant.id == lastSown.id { return 0 }
            return stocked.contains(plant.id) ? 1 : 2
        }
        return pool.sorted { a, b in
            let ra = rank(a), rb = rank(b)
            if ra != rb { return ra < rb }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
    }

    // MARK: - The gap

    /// Where a crop's gap came from.
    enum GapSource: Equatable {
        /// Typed on the plant's page.
        case typed
        /// The spreadsheet's "Next sowing days" column.
        case spreadsheet
        /// A line the seed packet reader found on the packet.
        case packet
        /// Claude's starting figure. ⚠️ CHECK
        case starting
    }

    /// A crop's gap in days, and where it came from.
    struct Gap: Equatable {
        let days: Int
        let gapSource: GapSource
    }

    /// Claude's starting gaps, in days, from general knowledge and not
    /// looked up (doc 148). One number each, the lower of the range.
    /// ⚠️ CHECK every one.
    static let startingDays: [String: Int] = [
        "radish": 14,
        "lettuce": 14, "rocket": 14, "spinach": 14, "leaf salad": 14, "salad leaves": 14,
        "spring onion": 21, "carrot": 21, "carrots": 21, "beetroot": 21,
        "pea": 21, "french bean": 21
    ]

    /// The gap in days before a crop is sown again, and where it came
    /// from. Nil for a crop with no gap: parsnips, squash, leeks and
    /// the like, which are sown once.
    ///
    /// In this order: what was typed on the plant's page (the variety
    /// being sown first, then any other variety of the crop); the
    /// spreadsheet's own figure; a "sow every 3 weeks" line the packet
    /// reader kept in a packet's note; Claude's starting figure.
    static func gap(for chosen: Plant?, crop key: String, plants: [Plant],
                    packets: [SeedPacket]) -> Gap? {
        var family = varieties(ofCrop: key, in: plants)
        if let chosen {
            family.removeAll { $0.id == chosen.id }
            family.insert(chosen, at: 0)
        }
        for plant in family where plant.changedByHand.contains("sowAgainEvery") {
            if let days = days(in: plant.sowAgainEvery) { return Gap(days: days, gapSource: .typed) }
        }
        for plant in family {
            if let days = days(in: plant.sowAgainEvery) { return Gap(days: days, gapSource: .spreadsheet) }
        }
        let ids = Set(family.map(\.id))
        for packet in packets where packet.plant.map({ ids.contains($0.id) }) ?? false {
            if let days = everyLine(in: packet.notes) { return Gap(days: days, gapSource: .packet) }
        }
        if let days = startingDays[key] { return Gap(days: days, gapSource: .starting) }
        return nil
    }

    /// Days in "21 days", "3 weeks" or a bare "21" (the sheet's column
    /// is in days). A range gives its lower end, so the next sowing is
    /// offered early rather than late.
    static func days(in text: String?) -> Int? {
        guard let raw = text?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        if let whole = Int(raw), whole > 0 { return whole }
        guard let found = DurationParser.days(in: raw), found.lower > 0 else { return nil }
        return Int(found.lower.rounded())
    }

    /// The gap in a packet's words: "sow every 3 weeks", "sow again
    /// every 10 days", "successional sowings every 2-3 weeks".
    static func everyLine(in note: String?) -> Int? {
        guard let note = note?.lowercased() else { return nil }
        let pattern = "every ([0-9]+)(?:\\s*(?:-|to)\\s*[0-9]+)?\\s*(day|week)"
        guard let range = note.range(of: pattern, options: .regularExpression) else { return nil }
        let words = String(note[range])
        guard let numberRange = words.range(of: "[0-9]+", options: .regularExpression),
              let number = Int(words[numberRange]), number > 0 else { return nil }
        return words.contains("week") ? number * 7 : number
    }

    /// A gap in words: "3 weeks", "10 days", "1 week".
    static func words(forDays days: Int) -> String {
        if days % 7 == 0 { return days == 7 ? "1 week" : "\(days / 7) weeks" }
        return days == 1 ? "1 day" : "\(days) days"
    }

    // MARK: - The offer

    /// What the card after a sowing says.
    struct Offer: Equatable {
        /// "Lettuce"
        let crop: String
        /// The day the next sowing is offered for. Nil when the chain
        /// ends or the crop has no gap.
        let next: Date?
        let gapDays: Int?
        let gapSource: GapSource?
        /// True when no variety of the crop can be sown on the next day:
        /// "That was the last sowing for this year."
        let isLast: Bool

        /// The question on the card.
        var question: String? {
            guard let next else { return nil }
            return "\(crop) sown. Sow again around \(next.formatted(.dateTime.weekday(.wide).day().month(.wide)))?"
        }
    }

    /// The offer after sowing `chosen` on `sown`.
    static func offer(after chosen: Plant, sown: Date, plants: [Plant], packets: [SeedPacket],
                      calendar: Calendar = .current) -> Offer {
        let key = cropKey(of: chosen)
        let name = cropName(of: chosen)
        guard let gap = gap(for: chosen, crop: key, plants: plants, packets: packets),
              let next = calendar.date(byAdding: .day, value: gap.days, to: calendar.startOfDay(for: sown)) else {
            return Offer(crop: name, next: nil, gapDays: nil, gapSource: nil, isLast: false)
        }
        let month = calendar.component(.month, from: next)
        let open = varieties(ofCrop: key, in: plants).contains { canSow($0, inMonth: month) }
        if !open {
            return Offer(crop: name, next: nil, gapDays: gap.days, gapSource: gap.gapSource, isLast: true)
        }
        return Offer(crop: name, next: next, gapDays: gap.days, gapSource: gap.gapSource, isLast: false)
    }

    /// The round the next sowing of a crop will be this year: one more
    /// than the sowings of every variety of it so far this year.
    static func nextRound(ofCrop key: String, plants: [Plant], plantings: [Planting],
                          on day: Date, calendar: Calendar = .current) -> Int {
        let year = calendar.component(.year, from: day)
        let ids = Set(varieties(ofCrop: key, in: plants).map(\.id))
        let sown = plantings.filter { planting in
            guard planting.startedFrom != .plant, let date = planting.dateSown,
                  let plant = planting.plant, ids.contains(plant.id) else { return false }
            return calendar.component(.year, from: date) == year
        }
        return sown.count + 1
    }

    /// The job's title: "Sow lettuce again · round 3".
    static func jobTitle(crop: String, round: Int) -> String {
        "Sow \(crop.lowercased()) again · round \(round)"
    }

    /// The days a sow-again job is for: from its day for a week. After
    /// that it shows as overdue, as any job of your own does.
    static func span(from day: Date, calendar: Calendar = .current) -> JobDays {
        let first = calendar.startOfDay(for: day)
        return JobDays(from: first, by: calendar.date(byAdding: .day, value: 6, to: first) ?? first)
    }

    // MARK: - Today's lists

    /// The crops that have a sow-again job waiting (not ticked).
    static func waitingCrops(_ jobs: [GardenJob]) -> Set<String> {
        Set(jobs.filter { !$0.isDone }.compactMap(\.cropName).filter { !$0.isEmpty }.map(cropKey))
    }

    /// True when a worked-out "Sow …" line for this plant should be
    /// hidden, because a sow-again job for its crop is waiting. Without
    /// this, a crop would be asked for twice.
    static func hidesWorkedOutLine(for plant: Plant, waiting: Set<String>) -> Bool {
        waiting.contains(cropKey(of: plant))
    }

    /// The plant a worked-out sowing line is about, from its id: lines
    /// begin "sow-" and then the plant's id.
    static func plantKey(inJobID id: String) -> String? {
        id.hasPrefix("sow-") ? String(id.dropFirst(4)) : nil
    }
}
