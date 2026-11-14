//
//  PlantFilter.swift
//  Windfall
//
//  The workings behind the filters on the Plants screen: what a plant is
//  grown for, which permaculture layer it sits in, its family, when it is
//  sown, flowers or crops, and what it does for the garden.
//
//  Nothing in this file draws anything, so it can be tested without a
//  screen. The buttons that use it are in PlantLibraryView.swift.
//
//  Everything here is read from what the records already say. Nothing is
//  guessed. A plant whose record has no group, for instance, is "Not
//  sorted" rather than put somewhere that might be wrong.
//

import Foundation

// MARK: - What a plant is grown for

/// Fruit, vegetables, herbs and so on, worked out from the plant's group.
///
/// The records have no column that says "fruit" or "vegetable". They do
/// have a group: "Fruit", "Brassicas", "Root veg", "Wildflower" and so
/// on. Each group belongs to one kind.
enum PlantKind: String, CaseIterable, Identifiable {
    case fruit = "Fruit"
    case vegetables = "Vegetables"
    case herbs = "Herbs"
    case flowers = "Flowers"
    case greenManure = "Green manure"
    /// No group in the record, or a group not listed below.
    case unsorted = "Not sorted"

    var id: String { rawValue }

    /// Which kind a group belongs to.
    ///
    /// The group is first tidied by `YearCalendar.familyKey`, which lower-
    /// cases it and drops a final "s", so "Alliums" and "Allium" (both are
    /// in the records) are the same here.
    static func of(group: String?) -> PlantKind {
        guard let group, !group.trimmingCharacters(in: .whitespaces).isEmpty else { return .unsorted }
        switch YearCalendar.familyKey(group) {
        case "fruit":
            return .fruit
        case "root veg", "leave", "brassica", "gourd", "allium", "bean",
             "nightshade", "microgreen", "vegetable":
            return .vegetables
        case "herb":
            return .herbs
        // "Shrub" is the roses, the hydrangea and the spiraea: grown for
        // their flowers.
        case "wildflower", "flower", "pollinator", "ornamental", "shrub":
            return .flowers
        case "green manure":
            return .greenManure
        default:
            return .unsorted
        }
    }
}

// MARK: - When

/// The times of year a plant can be chosen by.
enum PlantSeason: String, CaseIterable, Identifiable {
    case sowing = "Sowing"
    case sowIndoors = "Sowing indoors"
    case sowOutdoors = "Sowing outdoors"
    case plantingOut = "Planting out"
    case flowering = "Flowering"
    case cropping = "Fruiting or harvest"

    var id: String { rawValue }

    /// The months, 1 for January to 12 for December, in which the plant
    /// does this. Read from the words in its record by MonthParser.
    func months(for plant: Plant) -> Set<Int> {
        switch self {
        case .sowing:
            // Indoors or outdoors, either will do.
            return Set(MonthParser.months(in: plant.sowIndoorsMonthsText))
                .union(MonthParser.months(in: plant.sowOutdoorsMonthsText))
        case .sowIndoors:
            return Set(MonthParser.months(in: plant.sowIndoorsMonthsText))
        case .sowOutdoors:
            return Set(MonthParser.months(in: plant.sowOutdoorsMonthsText))
        case .plantingOut:
            return Set(MonthParser.months(in: plant.plantOutMonthsText))
        case .flowering:
            return Set(MonthParser.months(in: plant.floweringMonthsText))
        case .cropping:
            // The allotment sheet calls it "Harvest" and the permaculture
            // sheet "Fruiting/Harvest", so they arrive in two places.
            return Set(MonthParser.months(in: plant.harvestMonthsText))
                .union(MonthParser.months(in: plant.fruitingMonthsText))
        }
    }

    /// How the season reads in the button: "Flowering in June".
    func phrase(month: Int) -> String {
        "\(rawValue) in \(PlantFilter.monthName(month))"
    }
}

// MARK: - What it does for the garden

/// The permaculture roles ticked in the records.
enum PlantRole: String, CaseIterable, Identifiable {
    case pollinator = "Pollinator"
    case nitrogenFixer = "Nitrogen fixer"
    case accumulator = "Dynamic accumulator"
    case groundCover = "Ground cover"
    case repeller = "Pest repeller"
    case umbellifer = "Umbellifer"

    var id: String { rawValue }

    func applies(to plant: Plant) -> Bool {
        switch self {
        case .pollinator: return plant.isPollinator
        case .nitrogenFixer: return plant.isNitrogenFixer
        case .accumulator: return plant.isDynamicAccumulator
        case .groundCover: return plant.isGroundCover
        case .repeller: return plant.isRepeller
        case .umbellifer: return plant.isUmbelliferous
        }
    }
}

// MARK: - The filter

/// Everything chosen on the Plants screen at once. A plant is shown only
/// if it passes every part.
///
/// It is a struct, a bundle of plain values, so SwiftUI can keep one in a
/// @State and redraw the list whenever any part of it changes.
struct PlantFilter: Equatable {

    /// Growing, to buy or previously owned. Nil shows all three.
    var status: PlantStatus? = .growing
    var kind: PlantKind?
    /// A layer as the records spell it, such as "Shrubs".
    var layer: String?
    /// A family key from `YearCalendar.familyKey`, such as "brassica".
    var family: String?
    var season: PlantSeason?
    /// The month the season is looked for in. Nil means this month, so a
    /// screen left open overnight on "Sowing this month" stays right.
    var seasonMonth: Int?
    /// Roles the plant must have. With two chosen it must have both.
    var roles: Set<PlantRole> = []
    var search = ""

    /// The filter as it is when the screen first opens.
    static let standard = PlantFilter()

    /// A checking aid. Starting the app with, for example,
    /// `-plantsKind Vegetables -plantsFamily brassica -plantsSeason Sowing`
    /// opens the Plants screen with those already chosen, so a still
    /// picture can show a filtered list. Without them it is the standard.
    static func fromLaunchArguments(_ defaults: UserDefaults = .standard) -> PlantFilter {
        var filter = PlantFilter()
        if let kind = defaults.string(forKey: "plantsKind") { filter.kind = PlantKind(rawValue: kind) }
        filter.layer = defaults.string(forKey: "plantsLayer")
        filter.family = defaults.string(forKey: "plantsFamily").map { YearCalendar.familyKey($0) }
        if let season = defaults.string(forKey: "plantsSeason") { filter.season = PlantSeason(rawValue: season) }
        let month = defaults.integer(forKey: "plantsMonth")
        if (1...12).contains(month) { filter.seasonMonth = month }
        if let role = defaults.string(forKey: "plantsRole").flatMap(PlantRole.init(rawValue:)) { filter.roles = [role] }
        // `-plantsSearch apple` opens the screen with "apple" already typed.
        filter.search = defaults.string(forKey: "plantsSearch") ?? ""
        return filter
    }

    /// True when anything beyond the standard is chosen, which is when the
    /// "Clear" button is worth showing.
    var isNarrowed: Bool {
        var plain = self
        plain.search = ""
        return plain != .standard
    }

    /// The month to look for a season in, with "this month" worked out.
    func month(today: Int) -> Int { seasonMonth ?? today }

    // MARK: Testing one plant

    /// Whether a plant passes. `today` is this month, 1 to 12. It is passed
    /// in rather than read from the clock so the tests can choose it.
    func matches(_ plant: Plant, today: Int) -> Bool {
        if let status, plant.status != status { return false }
        if let kind, PlantKind.of(group: plant.group) != kind { return false }
        if let layer, PlantFilter.layerKey(plant.layer) != PlantFilter.layerKey(layer) { return false }
        if let family, PlantFilter.familyKey(of: plant) != family { return false }
        if let season, !season.months(for: plant).contains(month(today: today)) { return false }
        for needed in roles where !needed.applies(to: plant) { return false }
        return PlantFilter.matchesSearch(plant, search)
    }

    /// The words typed into the search box, looked for in the plant's
    /// names and group. Upper and lower case are treated alike.
    static func matchesSearch(_ plant: Plant, _ search: String) -> Bool {
        let needle = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return true }
        return [plant.commonName, plant.latinName, plant.variety, plant.group]
            .compactMap { $0?.lowercased() }
            .contains { $0.contains(needle) }
    }

    // MARK: The choices offered in each menu

    /// One choice in a menu, with how many plants it would show.
    struct Choice: Identifiable, Equatable {
        /// What is stored when it is chosen.
        let key: String
        /// What the menu says.
        let title: String
        let count: Int
        var id: String { key }
    }

    /// The kinds that have plants, with counts.
    ///
    /// Each count is worked out with every other filter still applied, so
    /// a number says exactly how many plants choosing it would show.
    func kindChoices(_ plants: [Plant], today: Int) -> [Choice] {
        var others = self
        others.kind = nil
        var counts: [PlantKind: Int] = [:]
        for plant in plants where others.matches(plant, today: today) {
            counts[PlantKind.of(group: plant.group), default: 0] += 1
        }
        return PlantKind.allCases.compactMap { kind in
            guard let count = counts[kind] else { return nil }
            return Choice(key: kind.rawValue, title: kind.rawValue, count: count)
        }
    }

    /// The layers that have plants, from the canopy down, with counts.
    func layerChoices(_ plants: [Plant], today: Int) -> [Choice] {
        var others = self
        others.layer = nil
        var spellings: [String: [String]] = [:]
        for plant in plants where others.matches(plant, today: today) {
            guard let layer = plant.layer, let key = PlantFilter.layerKey(layer) else { continue }
            spellings[key, default: []].append(layer.trimmingCharacters(in: .whitespaces))
        }
        return spellings.keys
            .sorted { PlantFilter.layerRank($0) < PlantFilter.layerRank($1)
                || (PlantFilter.layerRank($0) == PlantFilter.layerRank($1) && $0 < $1) }
            .map { key in
                let names = spellings[key] ?? []
                // The layer is stored and shown as the records spell it.
                let shown = YearCalendar.familyTitle(from: names)
                return Choice(key: shown, title: shown, count: names.count)
            }
    }

    /// The families that have plants, A to Z, with counts. If a kind is
    /// chosen, only that kind's families are offered.
    func familyChoices(_ plants: [Plant], today: Int) -> [Choice] {
        var others = self
        others.family = nil
        var spellings: [String: [String]] = [:]
        for plant in plants where others.matches(plant, today: today) {
            guard let key = PlantFilter.familyKey(of: plant), let group = plant.group else { continue }
            spellings[key, default: []].append(group.trimmingCharacters(in: .whitespaces))
        }
        return spellings
            .map { key, names in
                let shown = YearCalendar.familyTitle(from: names)
                return Choice(key: key, title: shown, count: names.count)
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// The seasons, with how many plants each has in the chosen month.
    func seasonChoices(_ plants: [Plant], today: Int) -> [Choice] {
        var others = self
        others.season = nil
        let chosen = others.filter(plants, today: today)
        let month = month(today: today)
        return PlantSeason.allCases.map { season in
            let count = chosen.filter { season.months(for: $0).contains(month) }.count
            return Choice(key: season.rawValue, title: season.rawValue, count: count)
        }
    }

    /// The roles, each with how many plants would show if it were added.
    func roleChoices(_ plants: [Plant], today: Int) -> [Choice] {
        PlantRole.allCases.map { each in
            var withRole = self
            withRole.roles.insert(each)
            let count = plants.filter { withRole.matches($0, today: today) }.count
            return Choice(key: each.rawValue, title: each.rawValue, count: count)
        }
    }

    /// The plants that pass, in the order given.
    func filter(_ plants: [Plant], today: Int) -> [Plant] {
        plants.filter { matches($0, today: today) }
    }

    // MARK: Tidying names

    /// The family a plant is filed under, tidied so that two spellings of
    /// one group match. Nil when the record has no group.
    static func familyKey(of plant: Plant) -> String? {
        guard let group = plant.group, !group.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return YearCalendar.familyKey(group)
    }

    /// A layer tidied for comparing: lower case, no spaces at the ends.
    ///
    /// Not `familyKey`, which drops a final "s" and would turn
    /// "Herbaceous" into "herbaceou".
    static func layerKey(_ layer: String?) -> String? {
        guard let key = layer?.trimmingCharacters(in: .whitespaces).lowercased(), !key.isEmpty else { return nil }
        return key
    }

    /// Where a layer comes in a forest garden, from the tallest down. The
    /// records use the first spelling of each. Others are kept in case a
    /// future record uses them. Anything not listed goes last.
    static func layerRank(_ key: String) -> Int {
        let order = [["canopy", "trees", "tree"],
                     ["sub-canopy", "subcanopy", "small trees"],
                     ["shrubs", "shrub"],
                     ["herbaceous"],
                     ["ground cover", "groundcover"],
                     ["vines", "vine", "climbers", "climber"],
                     ["roots", "root", "rhizosphere", "underground"]]
        return order.firstIndex { $0.contains(key) } ?? order.count
    }

    /// "January" for 1, and so on.
    static func monthName(_ month: Int) -> String {
        let names = Calendar.current.monthSymbols
        return (1...12).contains(month) ? names[month - 1] : ""
    }
}
