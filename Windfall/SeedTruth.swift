//
//  SeedTruth.swift
//  Windfall
//
//  Which plants come true from seed, which do not, and what the sowing
//  form should ask about each.
//
//  WHY IT IS HERE
//  William tried to record a sowing of the apple 'Pendragon' (13
//  November 2026). A pip from a Pendragon does not grow a Pendragon. It
//  grows a new seedling, half of whose make-up came from whatever
//  pollinated the flower. So for some plants "sowed" is the wrong word
//  for what usually happens (a tree is planted), and when seed really
//  is sown, the question that matters is what it crossed with.
//
//  THREE HABITS
//    kept by cloning   The variety is kept going by grafting, cuttings,
//                      division, runners, tubers or cloves. Seed gives a
//                      new seedling. Apples, potatoes, garlic, rhubarb.
//    crosses readily   Grown from seed, but the flowers are pollinated
//                      by other plants, so seed you save yourself may be
//                      a cross unless the flowers were kept apart.
//                      Squash, cabbages, sweetcorn, beetroot.
//    mostly true       Pollinates itself before the flower opens, so
//                      saved seed is nearly always like its parent.
//                      Tomatoes, peas, French beans, lettuce.
//
//  ⚠️ CHECK: the three lists below are from Claude's general knowledge of
//  seed saving. They were not looked up for this, and William has not
//  checked them. Good places to check them against: Garden Organic's
//  Heritage Seed Library seed saving guidelines, and Real Seeds' seed
//  saving instructions. Anything not on a list is "not known" and the
//  form asks nothing.
//
//  Nothing in this file draws anything, so it can be tested without a
//  screen. The form is NewPlantingView in PlantingViews.swift.
//

import Foundation

/// How a kind of plant behaves when grown from seed.
enum SeedHabit: String, Equatable {
    case keptByCloning, crossesReadily, mostlyTrue, notKnown
}

/// How one sowing was started.
enum PlantingStart: String, CaseIterable, Identifiable {
    /// Seed from a packet, or seed whose source does not matter.
    case packetSeed
    /// Seed saved from a plant, or from a cross made on purpose.
    case savedSeed
    /// Not seed at all: a tree, a plant, a tuber, a clove, a crown.
    case plant

    var id: String { rawValue }
}

enum SeedTruth {

    // Two-word names are looked for first, as whole phrases, so that
    // "broad bean" is not mistaken for a French bean.

    /// Kept going by grafting, cuttings, division, runners, tubers or
    /// cloves. ⚠️ CHECK
    static let cloned: [String] = [
        "crab apple", "apple", "pear", "quince", "medlar", "plum", "damson", "greengage", "gage",
        "bullace", "cherry", "peach", "nectarine", "apricot", "fig", "grape", "vine", "mulberry",
        "hazel", "cobnut", "filbert", "walnut", "raspberry", "blackberry", "loganberry", "tayberry",
        "boysenberry", "wineberry", "blackcurrant", "redcurrant", "whitecurrant", "currant",
        "gooseberry", "jostaberry", "blueberry", "honeyberry", "strawberry", "rhubarb", "potato",
        "jerusalem artichoke", "sweet potato", "oca", "yacon", "garlic", "shallot", "horseradish",
        "mint", "tarragon", "comfrey", "hop", "rose", "lavender", "rosemary", "bay", "kiwi"]

    /// Seed-grown, but pollinated by other plants. ⚠️ CHECK
    static let crossers: [String] = [
        "runner bean", "broad bean", "field bean", "brussel sprout", "pak choi", "spring onion",
        "squash", "pumpkin", "courgette", "marrow", "cucumber", "gherkin", "melon", "sweetcorn",
        "corn", "cabbage", "kale", "broccoli", "calabrese", "cauliflower", "kohlrabi", "turnip",
        "swede", "mizuna", "mustard", "radish", "rocket", "beetroot", "chard", "spinach", "carrot",
        "parsnip", "celery", "celeriac", "onion", "leek", "sunflower", "fennel"]

    /// Pollinates itself. ⚠️ CHECK
    static let selfers: [String] = [
        "french bean", "dwarf bean", "climbing bean", "alpine strawberry", "wild strawberry",
        "tomato", "pea", "mangetout", "sugar snap", "lettuce", "pepper", "chilli", "aubergine"]

    /// Names that look like one thing and are another.
    /// The first nine were found by running the lists over William's
    /// own plant library on 13 November 2026.
    private static let notWhatTheySeem: [String: SeedHabit] = [
        "rock rose": .notKnown,         // Helianthemum, a wildflower, not a rose
        "sea lavender": .notKnown,      // Limonium, not lavender
        "grape hyacinth": .notKnown,    // a bulb, not a grape
        "digitalis": .notKnown,         // a foxglove that happens to be called 'Peach'
        "water mint": .notKnown,        // the wild plant, which seeds itself
        "corn chamomile": .notKnown,    // a cornfield wildflower, not sweetcorn
        "corn marigold": .notKnown,
        "bristol onion": .notKnown,     // a wild allium
        "pepper saxifrage": .notKnown,  // a meadow wildflower
        "wild garlic": .notKnown,       // ramsons, a woodland bulb, not garlic
        "sea kale": .notKnown,
        "sweet pea": .mostlyTrue,       // a flower, and it does pollinate itself
        "sweet pepper": .mostlyTrue,
        "globe artichoke": .keptByCloning
    ]

    /// The habit of a plant, from its common name.
    static func habit(commonName: String) -> SeedHabit {
        let name = " " + words(in: commonName).joined(separator: " ") + " "
        for (phrase, answer) in notWhatTheySeem where name.contains(" \(phrase) ") { return answer }
        // Whole phrases first, then single words, each list in turn.
        for wantsPhrase in [true, false] {
            for (list, answer) in [(selfers, SeedHabit.mostlyTrue), (cloned, .keptByCloning), (crossers, .crossesReadily)] {
                for entry in list where entry.contains(" ") == wantsPhrase && name.contains(" \(entry) ") {
                    return answer
                }
            }
        }
        return .notKnown
    }

    /// The words of a name in lower case, each without a plural ending,
    /// so "Leeks" matches "leek" and "Radishes" matches "radish".
    static func words(in name: String) -> [String] {
        name.lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .map { piece -> String in
                let text = String(piece)
                if text.count > 4, text.hasSuffix("ies") { return String(text.dropLast(3)) + "y" }
                if text.count > 4, text.hasSuffix("oes") { return String(text.dropLast(2)) }
                if text.count > 4, text.hasSuffix("shes") || text.hasSuffix("ches") { return String(text.dropLast(2)) }
                // Latin names such as "digitalis" and "ranunculus" end in "s"
                // without being plurals.
                if text.count > 3, text.hasSuffix("s"), !text.hasSuffix("ss"), !text.hasSuffix("is"), !text.hasSuffix("us") {
                    return String(text.dropLast(1))
                }
                return text
            }
    }

    /// True for a variety sold as an F1 hybrid, whose saved seed does
    /// not come true whatever the plant.
    static func isF1(variety: String?) -> Bool {
        guard let variety else { return false }
        return variety.lowercased().split(whereSeparator: { !($0.isLetter || $0.isNumber) }).contains("f1")
    }

    /// The ways of starting that the form offers for this plant, the
    /// usual one first. Empty means the form asks nothing.
    static func starts(for habit: SeedHabit, isF1: Bool) -> [PlantingStart] {
        switch habit {
        case .keptByCloning: return [.plant, .savedSeed]
        case .crossesReadily: return [.packetSeed, .savedSeed]
        case .mostlyTrue, .notKnown: return isF1 ? [.packetSeed, .savedSeed] : []
        }
    }

    /// What the form calls each way of starting, for this plant.
    static func title(of begun: PlantingStart, habit: SeedHabit) -> String {
        switch begun {
        case .plant: return "A plant, tree or tuber"
        case .packetSeed: return "Seed from a packet"
        case .savedSeed: return habit == .keptByCloning ? "Seed, for a new seedling" : "Seed I saved"
        }
    }

    /// A sentence or two for the form, saying why it is asking. Nil if
    /// there is nothing to say. `name` is the plant's common name.
    static func advice(habit: SeedHabit, isF1: Bool, begun: PlantingStart, name: String) -> String? {
        let plant = name.isEmpty ? "This plant" : name
        switch (habit, begun) {
        case (.keptByCloning, .plant):
            return "\(plant) is kept true by grafting, cuttings, division or planting tubers and cloves, not by seed. This will be recorded as planted."
        case (.keptByCloning, .savedSeed):
            return "Seed from \(plant.lowercased()) does not come true. What grows is a new seedling, part its seed parent and part whatever pollinated the flower. Record both parents if you know them."
        case (.crossesReadily, .savedSeed):
            return "\(plant) is pollinated by other plants of its kind, so saved seed can be a cross unless the flowers were kept apart or pollinated by hand. Record what it may have crossed with."
        case (_, .savedSeed) where isF1:
            return "This is an F1 hybrid. Seed saved from it will not come true: the seedlings vary and few match the parent."
        default:
            return nil
        }
    }

    /// One line for the record, such as "Seedling of Apple, Pendragon ×
    /// Egremont Russet (hand cross)". Nil when the sowing was not from
    /// saved seed.
    static func parentage(seedParent: String?, pollenParent: String?, byHand: Bool) -> String? {
        guard let seedParent, !seedParent.isEmpty else { return nil }
        let pollen = (pollenParent ?? "").trimmingCharacters(in: .whitespaces)
        if pollen.isEmpty { return "Seed of \(seedParent), pollen parent not known" }
        return "\(seedParent) × \(pollen)" + (byHand ? " (hand cross)" : "")
    }
}
