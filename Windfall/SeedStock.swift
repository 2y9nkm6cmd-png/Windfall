//
//  SeedStock.swift
//  Windfall
//
//  How much seed is left in each packet, the Seeds to buy list, and
//  how the Seed page sorts its packets.
//
//  William, 21 November 2026: "there should be some sort of way to
//  quickly log (maybe when you've tapped the sown check box) that it
//  asks you, do you need to get more stock of this." He chose three
//  answers: Plenty left, Running low, Used it up. The last two put the
//  packet on a Seeds to buy list (knowledge base docs 152 and 153).
//
//  The same three answers are asked after a sowing (SowAgainViews.swift)
//  and can be changed on a packet's page (SeedViews.swift).
//
//  Nothing here draws anything, so it can be tested without a screen.
//
//  ⚠️ CHECK (Claude's choices, card f-seed-stock-154):
//  - "Use soon" means past its sow-by date, within six months of it, or
//    germinating under half.
//  - Which words in the spreadsheet's From column mean seed you saved.
//

import Foundation

// MARK: - Seed left

/// How much seed is left in a packet, in the three words William chose.
enum SeedLeft: String, CaseIterable, Identifiable {
    case plenty, runningLow, usedUp

    var id: String { rawValue }

    /// The words on the buttons.
    var words: String {
        switch self {
        case .plenty: return "Plenty left"
        case .runningLow: return "Running low"
        case .usedUp: return "Used it up"
        }
    }

    /// What a packet's record says now.
    ///
    /// No seed counted as left (`quantityRemaining` of 0) is used up.
    /// On the buy list with some left is running low. Anything else is
    /// plenty, including a packet whose seeds were never counted.
    static func of(_ packet: SeedPacket) -> SeedLeft {
        if packet.quantityRemaining == 0 { return .usedUp }
        if packet.toBuy { return .runningLow }
        return .plenty
    }

    /// Writes this answer on to a packet.
    ///
    /// - Used it up: no seed left, and on the buy list.
    /// - Running low: on the buy list. A count of 0 is cleared, because
    ///   there is some left after all.
    /// - Plenty: off the buy list, and a count of 0 cleared too.
    func apply(to packet: SeedPacket) {
        switch self {
        case .usedUp:
            packet.quantityRemaining = 0
            packet.toBuy = true
        case .runningLow:
            if packet.quantityRemaining == 0 { packet.quantityRemaining = nil }
            packet.toBuy = true
        case .plenty:
            if packet.quantityRemaining == 0 { packet.quantityRemaining = nil }
            packet.toBuy = false
        }
    }
}

// MARK: - The Seed page's lists

enum SeedStock {

    /// How close to its sow-by date a packet is called "Use soon".
    /// ⚠️ CHECK: six months is Claude's choice.
    static let useSoonMonths = 6

    /// True when there is seed in the packet: not used up.
    static func hasSeed(_ packet: SeedPacket) -> Bool {
        packet.quantityRemaining != 0
    }

    /// Packets on the Seeds to buy list, A to Z by plant.
    static func toBuy(_ packets: [SeedPacket]) -> [SeedPacket] {
        packets.filter(\.toBuy).sorted(by: byName)
    }

    /// The months a packet's plant can be sown, indoors or out.
    static func sowingMonths(of packet: SeedPacket) -> Set<Int> {
        guard let plant = packet.plant else { return [] }
        return Set(MonthParser.months(in: plant.sowIndoorsMonthsText))
            .union(MonthParser.months(in: plant.sowOutdoorsMonthsText))
    }

    /// Packets with seed in them whose plant can be sown in `month`
    /// (1 for January), A to Z. The pick list for this month.
    static func sowThisMonth(_ packets: [SeedPacket], month: Int) -> [SeedPacket] {
        packets.filter { hasSeed($0) && sowingMonths(of: $0).contains(month) }.sorted(by: byName)
    }

    /// Why a packet should be used soon, in a few words. Nil if it need not be.
    ///
    /// Past its sow-by date, within six months of it, or germinating
    /// under half, from a test or from how its sowings came up. A packet
    /// with no seed left is not listed: it is on the buy list instead.
    static func useSoonReason(_ packet: SeedPacket, today: Date = .now,
                              calendar: Calendar = .current) -> String? {
        guard hasSeed(packet) else { return nil }
        if let useBy = packet.useByDate {
            if useBy < today { return "Past its sow-by date" }
            if let soon = calendar.date(byAdding: .month, value: useSoonMonths, to: today), useBy <= soon {
                return "Sow by \(useBy.formatted(.dateTime.month(.wide).year()))"
            }
        }
        if let rate = packet.viabilityRate, rate < 0.5 {
            return "Germinating poorly (\(Int(rate * 100))%)"
        }
        return nil
    }

    /// Packets to use soon, soonest sow-by date first.
    static func useSoon(_ packets: [SeedPacket], today: Date = .now) -> [SeedPacket] {
        packets.filter { useSoonReason($0, today: today) != nil }
            .sorted { ($0.useByDate ?? .distantFuture) < ($1.useByDate ?? .distantFuture) }
    }

    /// The two ways of grouping every packet.
    enum Grouping: String, CaseIterable, Identifiable {
        case family, place
        var id: String { rawValue }
        var words: String { self == .family ? "By family" : "By where it's kept" }
    }

    /// Every packet in groups, each group A to Z inside and the groups
    /// A to Z by title, with "Not sorted" or "Not given a place" last.
    ///
    /// By family uses the plant's group, as the Year page does. By where
    /// it's kept uses the packet's own words for its place for now;
    /// doc 147's box codes will replace them.
    static func grouped(_ packets: [SeedPacket], by grouping: Grouping) -> [(title: String, packets: [SeedPacket])] {
        let missing = grouping == .family ? "Not sorted" : "Not given a place"
        let groups = Dictionary(grouping: packets) { packet -> String in
            let words: String?
            switch grouping {
            case .family: words = packet.plant?.group
            case .place: words = packet.storageLocation
            }
            let trimmed = (words ?? "").trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? missing : trimmed
        }
        return groups.keys
            .sorted { a, b in
                if a == missing { return false }
                if b == missing { return true }
                return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
            }
            .map { ($0, groups[$0]!.sorted(by: byName)) }
    }

    /// A to Z by plant, then variety, then supplier.
    static func byName(_ a: SeedPacket, _ b: SeedPacket) -> Bool {
        let one = [a.plant?.commonName ?? "", a.variety ?? a.plant?.variety ?? "", a.supplier ?? ""]
        let two = [b.plant?.commonName ?? "", b.variety ?? b.plant?.variety ?? "", b.supplier ?? ""]
        for (mine, theirs) in zip(one, two) where mine.lowercased() != theirs.lowercased() {
            return mine.localizedCaseInsensitiveCompare(theirs) == .orderedAscending
        }
        return false
    }

    /// The name a packet is shown by: its plant and variety.
    static func title(of packet: SeedPacket) -> String {
        let name = packet.plant?.commonName ?? "Unknown plant"
        if let variety = packet.variety ?? packet.plant?.variety, !variety.isEmpty {
            return "\(name) '\(variety)'"
        }
        return name
    }

    // MARK: - Reading the spreadsheet's From column

    /// True when the words in the From column mean seed William saved.
    ///
    /// ⚠️ CHECK, Claude's reading of the sheet: "Homegrown 2025",
    /// "Grow wilder; collected 20/09/2025" and "Redcatch community
    /// garden (collected October 2025)" are saved seed. A seed swap
    /// ("Bristol Seed Swap (collected 2025)") and "Wild 2025" are not
    /// marked saved: they keep their words as the supplier.
    static func isSavedSeed(from words: String?) -> Bool {
        let text = (words ?? "").lowercased()
        if text.contains("swap") { return false }
        return text.contains("homegrown") || text.contains("home grown") || text.contains("collected")
    }

    /// The year in the From column, if one is written there: 2025 from
    /// "Homegrown 2025" or "collected 20/09/2025". A year after "Sown",
    /// as in "Heritage Seed Library (Sown 2023)", is when it was sown,
    /// not when the seed came, so it is not read.
    static func packetYear(from words: String?) -> Int? {
        guard let text = words, !text.lowercased().contains("sown") else { return nil }
        guard let range = text.range(of: "(19|20)[0-9]{2}", options: .regularExpression) else { return nil }
        return Int(text[range])
    }

    /// The key a packet is matched by, so loading the sheet twice does
    /// not make it twice: its plant, variety and supplier.
    static func matchKey(plantID: UUID?, variety: String?, supplier: String?) -> String {
        let tidy = { (text: String?) in (text ?? "").trimmingCharacters(in: .whitespaces).lowercased() }
        return [plantID?.uuidString ?? "", tidy(variety), tidy(supplier)].joined(separator: "|")
    }
}
