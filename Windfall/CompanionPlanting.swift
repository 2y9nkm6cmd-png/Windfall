//
//  CompanionPlanting.swift
//  Windfall
//
//  The 2,777-row companion matrix, finally doing something.
//
//  As a spreadsheet it's a lookup table you have to remember to consult.
//  In the app it can watch what you're actually planting and speak up —
//  which is the difference between having the data and using it.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Model

enum CompanionEffect: String, Codable, CaseIterable, Identifiable {
    case beneficial
    case detrimental
    case neutral

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beneficial:  return "Good together"
        case .detrimental: return "Keep apart"
        case .neutral:     return "No strong effect"
        }
    }

    var colour: Color {
        switch self {
        case .beneficial:  return .green
        case .detrimental: return .red
        case .neutral:     return .secondary
        }
    }

    var symbolName: String {
        switch self {
        case .beneficial:  return "checkmark.circle"
        case .detrimental: return "xmark.circle"
        case .neutral:     return "minus.circle"
        }
    }

    /// The sheet marks these with + and −.
    static func parse(_ text: String?) -> CompanionEffect {
        guard let text = text?.trimmingCharacters(in: .whitespaces) else { return .neutral }
        if text.hasPrefix("+") || text.lowercased().contains("benefi") { return .beneficial }
        if text.hasPrefix("-") || text.hasPrefix("−")
            || text.lowercased().contains("detri") || text.lowercased().contains("avoid") {
            return .detrimental
        }
        return .neutral
    }
}

@Model
final class CompanionPair {

    var id: UUID = UUID()

    var plantOneName: String = ""
    var plantTwoName: String = ""
    var effectRaw: String = CompanionEffect.neutral.rawValue
    var mechanism: String?      // how it impacts
    var notes: String?

    var lastSyncedAt: Date?

    init() {}

    var effect: CompanionEffect {
        get { CompanionEffect(rawValue: effectRaw) ?? .neutral }
        set { effectRaw = newValue.rawValue }
    }

    /// The relationship is symmetric, so a lookup must check both columns.
    func involves(_ name: String) -> Bool {
        let needle = name.lowercased()
        return plantOneName.lowercased() == needle || plantTwoName.lowercased() == needle
    }

    func partner(of name: String) -> String? {
        let needle = name.lowercased()
        if plantOneName.lowercased() == needle { return plantTwoName }
        if plantTwoName.lowercased() == needle { return plantOneName }
        return nil
    }
}

// MARK: - Checking a bed

enum CompanionChecker {

    struct Finding: Identifiable {
        let id = UUID()
        let plantA: String
        let plantB: String
        let effect: CompanionEffect
        let mechanism: String?
    }

    /// Every meaningful relationship among the plants currently in a bed.
    static func check(bed: Bed, against pairs: [CompanionPair]) -> [Finding] {
        let growing = bed.orderedSections
            .flatMap { $0.plantings ?? [] }
            .filter { $0.status != .finished && $0.status != .failed }
            .compactMap { $0.plant?.commonName }

        let unique = Array(Set(growing))
        guard unique.count > 1 else { return [] }

        var findings: [Finding] = []

        for i in 0..<unique.count {
            for j in (i + 1)..<unique.count {
                let a = unique[i], b = unique[j]
                guard let pair = pairs.first(where: {
                    ($0.plantOneName.lowercased() == a.lowercased()
                        && $0.plantTwoName.lowercased() == b.lowercased())
                    || ($0.plantOneName.lowercased() == b.lowercased()
                        && $0.plantTwoName.lowercased() == a.lowercased())
                }) else { continue }

                findings.append(Finding(plantA: a, plantB: b,
                                        effect: pair.effect, mechanism: pair.mechanism))
            }
        }

        // Problems first.
        return findings.sorted { $0.effect == .detrimental && $1.effect != .detrimental }
    }
}

// MARK: - Why two plants go together, or do not

/// The kind of reason the matrix gives for a pairing. Each has a few
/// words and a symbol, so a list of companions can be taken in at a
/// glance before the reasons are read.
///
/// The matrix's reasons are free writing ("Repel aphids, improve
/// flavour"). `kinds(in:effect:)` sorts each into one or more of these
/// by the words in it. A reason that fits none still shows, with a
/// plain tick or cross.
enum CompanionReason: String, CaseIterable, Identifiable {
    // Reasons to grow together.
    case deters, decoy, helpers, soil, space, shelter, crop, conditions
    // Reasons to keep apart.
    case sharedPests, competes, stunts, toxic, mismatch

    var id: String { rawValue }

    var words: String {
        switch self {
        case .deters: return "Keeps pests off"
        case .decoy: return "Draws pests away"
        case .helpers: return "Brings helpful insects"
        case .soil: return "Feeds or opens the soil"
        case .space: return "Shares the space"
        case .shelter: return "Gives shade or cover"
        case .crop: return "Better crop or flavour"
        case .conditions: return "Likes the same conditions"
        case .sharedPests: return "Shares pests"
        case .competes: return "Competes"
        case .stunts: return "Stunts growth"
        case .toxic: return "Toxic"
        case .mismatch: return "Wants different conditions"
        }
    }

    /// One of Apple's symbols, standing in until Windfall has drawings
    /// of its own for these.
    var symbolName: String {
        switch self {
        case .deters: return "shield"
        case .decoy: return "scope"
        case .helpers: return "ladybug"
        case .soil: return "leaf"
        case .space: return "square.grid.2x2"
        case .shelter: return "umbrella"
        case .crop: return "arrow.up.right"
        case .conditions, .mismatch: return "thermometer.medium"
        case .sharedPests: return "ant"
        case .competes: return "arrow.left.arrow.right"
        case .stunts: return "arrow.down.right"
        case .toxic: return "exclamationmark.triangle"
        }
    }

    /// The words that mark each kind, as roots (see `JournalChat.root`).
    /// The order matters for the good ones: a reason is tried against
    /// each in turn.
    private static let goodMarks: [(CompanionReason, [[String]])] = [
        (.decoy, [["draw"], ["lure"], ["sacrificial"], ["trap"]]),
        (.helpers, [["beneficial"], ["pollinator"], ["predator"], ["predatory"], ["parasitic"], ["parasite"],
                    ["feed", "on", "pest"], ["eat", "aphid"]]),
        (.deters, [["deter"], ["repel"], ["repellant"], ["drive", "off"], ["pest", "control"], ["mask"], ["suppresse"],
                   ["suppress"], ["prevent"], ["kill"], ["hide"], ["fungicide"], ["away"], ["barrier"]]),
        (.soil, [["nitrogen"], ["soil"], ["bioaccumulator"], ["nutrition"]]),
        (.space, [["intercropping"], ["space"], ["spacing"], ["compete"], ["marginal"]]),
        (.shelter, [["shade"], ["cover"], ["mulch"], ["moisture"]]),
        (.crop, [["yield"], ["flavour"], ["growth"], ["quality"]]),
        (.conditions, [["condition"], ["hardy"]])
    ]

    private static let badMarks: [(CompanionReason, [[String]])] = [
        (.sharedPests, [["pest"]]),
        (.stunts, [["stunt"], ["sulphur"]]),
        (.competes, [["compete"], ["nutrient"], ["feeder"]]),
        (.toxic, [["toxic"]]),
        (.mismatch, [["condition"]])
    ]

    /// The kinds a written reason falls under. Empty if it fits none.
    static func kinds(in reason: String, effect: CompanionEffect) -> [CompanionReason] {
        let roots = JournalChat.roots(in: reason)
        let marks = effect == .detrimental ? badMarks : goodMarks
        return marks.filter { mark in
            mark.1.contains { CompanionPests.contains($0, in: roots) }
        }.map(\.0)
    }
}

// MARK: - Pests named in the matrix

/// Finds the pests a written reason names, so that plants can be looked
/// up by the pest they help against.
///
/// It works from a list of pests and the ways the matrix writes them.
/// A pest the list does not have is not found.
///
/// ⚠️ CHECK: the grouping is Claude's, made on 13 November 2026 from the
/// reasons in the matrix as shipped. Greenfly and blackfly are counted
/// as aphids. Cabbage worms, cabbage moths and cabbage whites are
/// counted as caterpillars. Carrot root fly and carrot rust fly are
/// counted as carrot fly.
enum CompanionPests {

    /// Each pest with the ways it is written, as roots.
    private static let known: [(name: String, written: [[String]])] = [
        ("Aphids", [["aphid"], ["greenfly"], ["blackfly"], ["black", "fly"]]),
        ("Whitefly", [["whitefly"]]),
        ("Carrot fly", [["carrot", "fly"], ["carrot", "root", "fly"], ["carrot", "rust", "fly"], ["rust", "fly"]]),
        ("Onion fly", [["onion", "fly"]]),
        ("Leek moth", [["leek", "moth"]]),
        ("Caterpillars", [["caterpillar"], ["cabbage", "worm"], ["cabbage", "moth"], ["cabbage", "white"], ["hornworm"]]),
        ("Flea beetles", [["flea", "beetle"]]),
        ("Asparagus beetle", [["asparagus", "beetle"]]),
        ("Slugs and snails", [["slug"], ["snail"]]),
        ("Nematodes", [["nematode"]]),
        ("Spider mites", [["spider", "mite"]]),
        ("Root maggots", [["root", "maggot"]]),
        ("Rodents", [["rodent"], ["squirrel"], ["vole"], ["mice"]]),
        ("Birds", [["bird"]]),
        ("Ants", [["ant"]]),
        ("Blight", [["blight"]])
    ]

    /// True if the words in `phrase` appear together, in order, in `roots`.
    static func contains(_ phrase: [String], in roots: [String]) -> Bool {
        guard !phrase.isEmpty, roots.count >= phrase.count else { return false }
        return (0...(roots.count - phrase.count)).contains { start in
            Array(roots[start..<(start + phrase.count)]) == phrase
        }
    }

    /// The pests a reason names, in the list's order.
    static func named(in reason: String) -> [String] {
        let roots = JournalChat.roots(in: reason)
        return known.filter { pest in pest.written.contains { contains($0, in: roots) } }.map(\.name)
    }

    /// A plant that helps against a pest, with the crops the matrix
    /// records it helping.
    struct Helper: Identifiable, Equatable {
        let plant: String
        let protects: [String]
        let reasons: [String]

        var id: String { plant.lowercased() }
    }

    /// Every pest the matrix names in a reason to grow two plants
    /// together, with how many plants help against it, commonest first.
    static func all(in pairs: [CompanionPair]) -> [(name: String, helpers: Int)] {
        var plants: [String: Set<String>] = [:]
        for pair in pairs where pair.effect == .beneficial {
            for pest in named(in: pair.mechanism ?? "") {
                plants[pest, default: []].insert(pair.plantTwoName.lowercased())
            }
        }
        return known.map(\.name)
            .compactMap { name in plants[name].map { (name: name, helpers: $0.count) } }
            .sorted { $0.helpers > $1.helpers }
    }

    /// The plants that help against one pest. In the matrix the second
    /// plant of a pair is the one doing something for the first, so the
    /// helper is the second plant and the crop it protects is the first.
    static func helpers(against pest: String, in pairs: [CompanionPair]) -> [Helper] {
        var order: [String] = []
        var names: [String: String] = [:]
        var protects: [String: [String]] = [:]
        var reasons: [String: [String]] = [:]

        for pair in pairs where pair.effect == .beneficial {
            guard let reason = pair.mechanism, named(in: reason).contains(pest) else { continue }
            let key = pair.plantTwoName.lowercased()
            if names[key] == nil {
                names[key] = pair.plantTwoName
                order.append(key)
            }
            if !(protects[key] ?? []).contains(pair.plantOneName) { protects[key, default: []].append(pair.plantOneName) }
            if !(reasons[key] ?? []).contains(reason) { reasons[key, default: []].append(reason) }
        }
        return order
            .map { Helper(plant: names[$0] ?? $0, protects: (protects[$0] ?? []).sorted(), reasons: reasons[$0] ?? []) }
            // The plants recorded helping the most crops come first.
            .sorted { $0.protects.count != $1.protects.count ? $0.protects.count > $1.protects.count : $0.plant < $1.plant }
    }
}

// MARK: - Friends and enemies

/// A plant that goes well or badly with another, with every reason the
/// matrix gives, kept apart by which of the two the reason is about.
struct CompanionPartner: Identifiable, Equatable {
    let name: String
    /// What the partner does to the plant whose page this is.
    let doesForPlant: [String]
    /// What the plant whose page this is does to the partner.
    let plantDoesForIt: [String]
    /// The kinds of reason, for the symbol beside it.
    let kinds: [CompanionReason]
    /// The pests it helps the plant against, if any are named.
    let pests: [String]

    var id: String { name.lowercased() }
}

extension CompanionChecker {

    /// The plants that have one kind of effect with a plant, each
    /// listed once, in alphabetical order.
    ///
    /// Two things are put right here that a plain list of the matrix
    /// gets wrong:
    ///
    /// - The matrix can hold the same two plants more than once. Listed
    ///   as they stand, the plant appears twice. Here it appears once.
    /// - Each row of the matrix says what its second plant does for its
    ///   first. "Carrots, Garlic: deters carrot fly" is garlic helping
    ///   carrots. "Garlic, Carrots: repel onion fly" is carrots helping
    ///   garlic. Both are kept, each under whom it is for.
    static func partners(of plantName: String, effect: CompanionEffect, in pairs: [CompanionPair]) -> [CompanionPartner] {
        let plant = plantName.lowercased().trimmingCharacters(in: .whitespaces)
        var order: [String] = []
        var names: [String: String] = [:]
        var given: [String: [String]] = [:]
        var received: [String: [String]] = [:]

        for pair in pairs where pair.effect == effect {
            guard let otherName = pair.partner(of: plantName) else { continue }
            let key = otherName.lowercased().trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            if names[key] == nil {
                names[key] = otherName.trimmingCharacters(in: .whitespaces)
                order.append(key)
            }
            // "None" in the matrix means no reason was written down.
            guard let reason = pair.mechanism?.trimmingCharacters(in: .whitespaces),
                  !reason.isEmpty, reason.lowercased() != "none" else { continue }
            // The plant is the row's first plant: the partner does this
            // for it. Otherwise it is the plant doing it for the partner.
            if pair.plantOneName.lowercased().trimmingCharacters(in: .whitespaces) == plant {
                if !(given[key] ?? []).contains(reason) { given[key, default: []].append(reason) }
            } else {
                if !(received[key] ?? []).contains(reason) { received[key, default: []].append(reason) }
            }
        }

        return order.map { key in
            let forPlant = given[key] ?? []
            let forPartner = received[key] ?? []
            var kinds: [CompanionReason] = []
            for reason in forPlant + forPartner {
                for kind in CompanionReason.kinds(in: reason, effect: effect) where !kinds.contains(kind) {
                    kinds.append(kind)
                }
            }
            var pests: [String] = []
            if effect == .beneficial {
                for reason in forPlant {
                    for pest in CompanionPests.named(in: reason) where !pests.contains(pest) { pests.append(pest) }
                }
            }
            return CompanionPartner(name: names[key] ?? key, doesForPlant: forPlant, plantDoesForIt: forPartner,
                                    kinds: kinds, pests: pests)
        }
        .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
}

// MARK: - Companion view

/// A plant's friends and enemies.
///
/// With room, the two are side by side: what it grows well with on the
/// left, what to keep apart from it on the right. In a narrow window
/// there is room for one list, so a sliding switch at the top chooses
/// which.
///
/// Each plant in a list has a symbol for the kind of reason, and the
/// reasons are kept apart by which of the two plants they are about.
/// If the friends help against pests the matrix names, those pests are
/// offered as chips: pick one and only the plants that help against it
/// are listed.
struct CompanionView: View {

    let plantName: String

    @Query private var pairs: [CompanionPair]

    /// Which list is showing when there is room for only one.
    @State private var shown: CompanionEffect = .beneficial
    /// The pest picked from the chips, if one is.
    @State private var pest: String?

    var body: some View {
        // Worked out once for this redraw. Each goes through the whole
        // matrix.
        let allFriends = CompanionChecker.partners(of: plantName, effect: .beneficial, in: pairs)
        let enemies = CompanionChecker.partners(of: plantName, effect: .detrimental, in: pairs)

        // The pests the friends help against, with how many friends
        // help against each, commonest first.
        let pests = Dictionary(grouping: allFriends.flatMap(\.pests), by: { $0 })
            .map { (name: $0.key, helpers: $0.value.count) }
            .sorted { $0.helpers != $1.helpers ? $0.helpers > $1.helpers : $0.name < $1.name }
        let friends = pest.map { picked in allFriends.filter { $0.pests.contains(picked) } } ?? allFriends

        // GeometryReader says how wide the page is, which decides
        // between two columns and one.
        GeometryReader { geometry in
            let isWide = geometry.size.width >= 640

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(title: "Companions", detail: "For \(plantName)")

                    if allFriends.isEmpty && enemies.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nothing recorded")
                                .font(.headline)
                                .foregroundStyle(Theme.ink)
                            Text("The companion matrix has nothing for \(plantName).")
                                .font(.subheadline)
                                .foregroundStyle(Theme.inkSoft)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()
                    } else {
                        if !pests.isEmpty {
                            pestChips(pests)
                        }

                        if isWide {
                            HStack(alignment: .top, spacing: 14) {
                                partnerCard(friends, effect: .beneficial)
                                partnerCard(enemies, effect: .detrimental)
                            }
                        } else {
                            GlassSwitch(choices: [CompanionEffect.beneficial, .detrimental], selection: $shown) { effect in
                                effect == .beneficial ? "Friends · \(friends.count)" : "Enemies · \(enemies.count)"
                            }
                            partnerCard(shown == .beneficial ? friends : enemies, effect: shown)
                        }
                    }

                    // The same idea for the whole garden: start from the
                    // pest, whatever it is on.
                    NavigationLink {
                        PestHelpersView(startingWith: pest)
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Found a pest?")
                                    .font(.headline)
                                    .foregroundStyle(Theme.ink)
                                Text("See every plant the matrix records as helping against it.")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.inkSoft)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 8)
                            WIconView(.arrowRight, size: 16)
                                .foregroundStyle(Theme.leaf)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .glassCard()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .paperScreen()
        .navigationTitle("Companions")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        // The large "Companions" above is the title. The bar keeps the
        // name for the back button and VoiceOver, but shows no words.
        .toolbar { ToolbarItem(placement: .principal) { Text("") } }
    }

    /// The pests the friends help against, as chips to pick from.
    private func pestChips(_ pests: [(name: String, helpers: Int)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A pest on your \(plantName.lowercased())? Pick it to see what helps.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    PestChip(title: "All", isChosen: pest == nil) { pest = nil }
                    ForEach(pests, id: \.name) { found in
                        PestChip(title: "\(found.name) · \(found.helpers)", isChosen: pest == found.name) {
                            pest = pest == found.name ? nil : found.name
                            // A pest is only ever helped against by
                            // friends, so show them.
                            shown = .beneficial
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    /// One list as a glass card: a heading, then each plant with its
    /// symbol and reasons.
    private func partnerCard(_ partners: [CompanionPartner], effect: CompanionEffect) -> some View {
        let isGood = effect == .beneficial
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: effect.symbolName)
                    .foregroundStyle(isGood ? Theme.leaf : Theme.amber)
                Text(isGood ? "Grows well with" : "Keep apart from")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text("\(partners.count)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }

            if partners.isEmpty {
                Text(isGood ? "Nothing in the matrix yet." : "Nothing to keep it apart from.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }

            ForEach(partners) { partner in
                Divider()
                    .overlay(Theme.hairline)
                partnerRow(partner, isGood: isGood)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func partnerRow(_ partner: CompanionPartner, isGood: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // The symbol for the first kind of reason. A plain tick or
            // cross if the reason fits no kind.
            Image(systemName: partner.kinds.first?.symbolName ?? (isGood ? "checkmark" : "xmark"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isGood ? Theme.leaf : Theme.amber)
                .frame(width: 30, height: 30)
                .background((isGood ? Theme.leafFill : Theme.card).opacity(0.8), in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(partner.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                if !partner.kinds.isEmpty {
                    // The kinds in words, so the symbol never has to be
                    // guessed at.
                    Text(partner.kinds.map(\.words).joined(separator: " · "))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(isGood ? Theme.leaf : Theme.amber)
                }
                ForEach(partner.doesForPlant, id: \.self) { reason in
                    Text("\(isGood ? "Helps" : "Harms") \(plantName): \(reason)")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                ForEach(partner.plantDoesForIt, id: \.self) { reason in
                    Text("\(plantName) \(isGood ? "helps" : "harms") it: \(reason)")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
    }
}

/// A chip to pick a pest with. Filled with pale green when chosen.
struct PestChip: View {

    let title: String
    let isChosen: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isChosen ? .semibold : .regular))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint((isChosen ? Theme.leafFill : Theme.card).opacity(isChosen ? 0.8 : 0.4)).interactive(),
                     in: .capsule)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}

// MARK: - Plants for a pest

/// Start from a pest and see every plant the matrix records as helping
/// against it, and the crops it is recorded helping.
struct PestHelpersView: View {

    @Query private var pairs: [CompanionPair]

    @State private var chosen: String?

    /// - `startingWith`: a pest to open on, if the page was reached from
    ///   one.
    init(startingWith pest: String? = nil) {
        _chosen = State(initialValue: pest)
    }

    var body: some View {
        let pests = CompanionPests.all(in: pairs)
        let picked = chosen ?? pests.first?.name
        let helpers = picked.map { CompanionPests.helpers(against: $0, in: pairs) } ?? []

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Pest helpers", detail: "Plants that help against a pest")

                if pests.isEmpty {
                    Text("The companion matrix names no pests yet.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()
                } else {
                    // As many chips across as will fit.
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8, alignment: .leading)],
                              alignment: .leading, spacing: 8) {
                        ForEach(pests, id: \.name) { found in
                            PestChip(title: "\(found.name) · \(found.helpers)", isChosen: picked == found.name) {
                                chosen = found.name
                            }
                        }
                    }

                    if let picked {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Against \(picked.lowercased())")
                                .font(.headline)
                                .foregroundStyle(Theme.ink)

                            ForEach(helpers) { helper in
                                Divider()
                                    .overlay(Theme.hairline)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(helper.plant)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Theme.ink)
                                    Text("Recorded with: \(helper.protects.joined(separator: ", "))")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Theme.leaf)
                                    Text(helper.reasons.joined(separator: ". "))
                                        .font(.caption)
                                        .foregroundStyle(Theme.inkSoft)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()
                    }

                    Text("From your companion matrix. Each pairing was recorded for the crops named, and may not hold for others.")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .paperScreen()
        .navigationTitle("Pest helpers")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { ToolbarItem(placement: .principal) { Text("") } }
        .eiraLooksAt("the pest helpers page, which lists plants recorded as helping against a pest")
    }
}

// MARK: - Bed check view

struct BedCompanionCheckView: View {

    let bed: Bed

    @Query private var pairs: [CompanionPair]

    private var findings: [CompanionChecker.Finding] {
        CompanionChecker.check(bed: bed, against: pairs)
    }

    var body: some View {
        List {
            if findings.isEmpty {
                ContentUnavailableView {
                    Label("Nothing to flag", systemImage: "checkmark.circle")
                } description: {
                    Text("No known conflicts among what's growing in \(bed.name).")
                }
            }

            ForEach(findings) { finding in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: finding.effect.symbolName)
                            .foregroundStyle(finding.effect.colour)
                        Text("\(finding.plantA) and \(finding.plantB)")
                            .font(.subheadline)
                    }
                    if let mechanism = finding.mechanism {
                        Text(mechanism)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 24)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("\(bed.name) companions")
        .paperScreen()
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
