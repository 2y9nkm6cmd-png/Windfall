//
//  KeptFacts.swift
//  Windfall
//
//  Facts you have read somewhere and chosen to keep in a plant's record.
//
//  Why this exists. On 14 November 2026 William asked Eira whether to
//  chop back the rhubarb's leaves after a frost. Her records had nothing
//  on it, and she turned "nothing recorded" into advice. The RHS has a
//  plain answer. So now a fact found online, or typed in by hand, can be
//  kept, and it goes into the plant's own record: the Pruning box, the
//  sowing months and so on. Next time the answer is local, instant and
//  works with no connection.
//
//  Three rules hold throughout:
//
//    1. Nothing is written unless you press a button to say so.
//    2. Every kept fact remembers where it came from and when, in a
//       small record of its own (KeptFact). A box in a plant's record
//       holds only its words, so the source has to live beside it.
//    3. After two years a kept fact is marked "due a check", because
//       advice changes. It goes on being used in the meantime.
//
//  Nothing here draws anything. The screens are in KeptFactViews.swift.
//  So all of this is covered by the logic tests.
//

import Foundation
import SwiftData

// MARK: - The record of where a value came from

/// One fact kept in a plant's record, and where it came from.
///
/// `@Model` makes this a record type: something the database stores,
/// like a sowing or a sighting. Every property has a starting value or
/// may be empty (the `?`), which is the rule for records that may one
/// day sync through iCloud.
@Model
final class KeptFact {

    var id: UUID = UUID()
    /// When you pressed Keep.
    var keptAt: Date = Date.now
    /// When you last pressed "Still right", if you have.
    var checkedAt: Date?

    /// Which plant: that plant's own `id`. Held as an id and not as a
    /// link, so that removing this record can never disturb the plant.
    var plantID: UUID?
    /// The plant's name when the fact was kept, for the list of them.
    var plantName: String = ""
    /// Which box of the plant's record it went into. See PlantField.
    var fieldRaw: String = PlantField.notes.rawValue
    /// The box by its key in PlantFacts.swift, such as "maxHeightM",
    /// when the fact was kept by filling in a plant's gaps
    /// (PlantFillIn.swift). That can reach every box of the record,
    /// where `fieldRaw` knows only the 21 a sentence fits. Nil for a
    /// fact kept from Eira's chat or by hand, which use `fieldRaw`.
    var factKey: String?

    /// The fact in your words, as it stood on the card.
    var words: String = ""
    /// What the box held before. Nil if it was empty. Kept for undo.
    var valueBefore: String?
    /// What the box held straight after. If the box still holds this
    /// when the fact is removed, the old value can safely be put back.
    var valueAfter: String?

    /// "RHS", "Gardeners' World", "A book" and so on.
    var sourceName: String = ""
    /// The page's web address, if it came from one.
    var sourceAddress: String?
    /// How far the source is trusted. See SourceTrust.
    var trustRaw: String = SourceTrust.unknown.rawValue
    /// What you had asked, if it was kept from Eira's chat.
    var question: String?

    init() {}

    var field: PlantField { PlantField(rawValue: fieldRaw) ?? .notes }

    /// The box this fact sits in, by its key in PlantFacts.swift,
    /// however it was kept.
    var boxKey: String { factKey ?? field.factKey }
    /// The box's name as a plant's page shows it: "Max height".
    var boxLabel: String { PlantFacts.named(boxKey)?.label ?? field.label }
    /// True when the fact can be changed with the form for kept facts,
    /// which offers only the 21 boxes. Any other is changed with the
    /// plant's own Edit sheet.
    var canChangeInForm: Bool { factKey == nil }
    /// What the fact's box holds now, or nil if it is empty.
    func presentValue(in plant: Plant) -> String? {
        guard let box = PlantFacts.named(boxKey) else { return nil }
        let held = PlantFacts.value(of: box, in: plant)
        return held.isEmpty ? nil : held
    }
    var trust: SourceTrust { SourceTrust(rawValue: trustRaw) ?? .unknown }
}

// MARK: - The boxes of a plant's record a fact can go into

/// The boxes of a plant's record that a kept fact can be written into.
///
/// Each one knows its name as the plant's page shows it, how to read
/// its value from a plant and how to write a new one.
///
/// Left out on purpose: medicinal uses (Eira gives no medical advice,
/// and nor should a kept web page), and the boxes that hold a bare
/// number, such as sowing depth, which a sentence would not fit.
enum PlantField: String, CaseIterable, Identifiable {
    case pruning, propagation
    case sunShade, position, hardiness, soilPH, soil
    case pests, diseases
    case sowIndoors, sowOutdoors, plantOut, harvest, flowering
    case spacing
    case culinaryUses, toxicity
    case partnerPlants, pollinators
    case appearance, notes

    var id: String { rawValue }

    /// The name on the plant's page. These match PlantPage.swift, which
    /// is how a source label finds the fact it belongs beside.
    var label: String {
        switch self {
        case .pruning: return "Pruning"
        case .propagation: return "Propagation"
        case .sunShade: return "Sun / shade"
        case .position: return "Position"
        case .hardiness: return "Hardiness"
        case .soilPH: return "Soil pH"
        case .soil: return "Soil conditions"
        case .pests: return "Pests"
        case .diseases: return "Diseases"
        case .sowIndoors: return "Sow indoors"
        case .sowOutdoors: return "Sow outdoors"
        case .plantOut: return "Plant out"
        case .harvest: return "Harvest"
        case .flowering: return "Flowering"
        case .spacing: return "Spacing"
        case .culinaryUses: return "Culinary uses"
        case .toxicity: return "Toxicity"
        case .partnerPlants: return "Partner plants"
        case .pollinators: return "Pollinators"
        case .appearance: return "Appearance"
        case .notes: return "Notes"
        }
    }

    /// True for the boxes that hold months. What goes into one of
    /// these is a list of months, "Mar, Apr, May", never a sentence,
    /// because the Year page and the sowing reminders read them.
    var holdsMonths: Bool {
        switch self {
        case .sowIndoors, .sowOutdoors, .plantOut, .harvest, .flowering: return true
        default: return false
        }
    }

    /// What the box holds for this plant, or nil if it is empty.
    func value(in plant: Plant) -> String? {
        let held: String?
        switch self {
        case .pruning: held = plant.pruning
        case .propagation: held = plant.propagation
        case .sunShade: held = plant.sunShade
        case .position: held = plant.position
        case .hardiness: held = plant.hardiness
        case .soilPH: held = plant.soilPH
        case .soil: held = plant.preferredSoilConditions
        case .pests: held = plant.knownPests
        case .diseases: held = plant.knownDiseases
        case .sowIndoors: held = plant.sowIndoorsMonthsText
        case .sowOutdoors: held = plant.sowOutdoorsMonthsText
        case .plantOut: held = plant.plantOutMonthsText
        case .harvest: held = plant.harvestMonthsText
        case .flowering: held = plant.floweringMonthsText
        case .spacing: held = plant.spacingM
        case .culinaryUses: held = plant.culinaryUses
        case .toxicity: held = plant.toxicityCautions
        case .partnerPlants: held = plant.partnerPlants
        case .pollinators: held = plant.pollinators
        case .appearance: held = plant.appearance
        case .notes: held = plant.notes
        }
        let trimmed = held?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    /// The word this box is filed under in PlantFacts.swift, the one
    /// list of every fact a plant's record holds.
    var factKey: String {
        switch self {
        case .pruning: return "pruning"
        case .propagation: return "propagation"
        case .sunShade: return "sunShade"
        case .position: return "position"
        case .hardiness: return "hardiness"
        case .soilPH: return "soilPH"
        case .soil: return "preferredSoilConditions"
        case .pests: return "knownPests"
        case .diseases: return "knownDiseases"
        case .sowIndoors: return "sowIndoorsMonthsText"
        case .sowOutdoors: return "sowOutdoorsMonthsText"
        case .plantOut: return "plantOutMonthsText"
        case .harvest: return "harvestMonthsText"
        case .flowering: return "floweringMonthsText"
        case .spacing: return "spacingM"
        case .culinaryUses: return "culinaryUses"
        case .toxicity: return "toxicityCautions"
        case .partnerPlants: return "partnerPlants"
        case .pollinators: return "pollinators"
        case .appearance: return "appearance"
        case .notes: return "notes"
        }
    }

    /// Writes a value into the box. Nil empties it.
    ///
    /// The box is also noted as changed by hand (see PlantModels.swift),
    /// so that loading the spreadsheet file again leaves a kept fact
    /// where it is. Added when this work met the editing sheet, which
    /// brought that note in.
    func set(_ value: String?, in plant: Plant) {
        if !plant.changedByHand.contains(factKey) { plant.changedByHand.append(factKey) }
        switch self {
        case .pruning: plant.pruning = value
        case .propagation: plant.propagation = value
        case .sunShade: plant.sunShade = value
        case .position: plant.position = value
        case .hardiness: plant.hardiness = value
        case .soilPH: plant.soilPH = value
        case .soil: plant.preferredSoilConditions = value
        case .pests: plant.knownPests = value
        case .diseases: plant.knownDiseases = value
        case .sowIndoors: plant.sowIndoorsMonthsText = value
        case .sowOutdoors: plant.sowOutdoorsMonthsText = value
        case .plantOut: plant.plantOutMonthsText = value
        case .harvest: plant.harvestMonthsText = value
        case .flowering: plant.floweringMonthsText = value
        case .spacing: plant.spacingM = value
        case .culinaryUses: plant.culinaryUses = value
        case .toxicity: plant.toxicityCautions = value
        case .partnerPlants: plant.partnerPlants = value
        case .pollinators: plant.pollinators = value
        case .appearance: plant.appearance = value
        case .notes: plant.notes = value
        }
    }
}

// MARK: - What a care question is about

/// The kinds of thing a care question asks about.
///
/// Each kind has three lists. `asked` is how it shows up in a question.
/// `pageWords` is how it shows up on a gardening page, which is how the
/// right paragraph is picked out of a long one. `field` is the box of
/// the plant's record where the answer belongs.
///
/// The order of the cases matters: the first kind found in a question
/// wins. "After the first frost, do I need to chop the leaves back?" is
/// about cutting back, not about frost, so cutting back comes first.
enum CareTopic: String, CaseIterable {
    case cuttingBack, feeding, watering, dividing, plantingOut, sowing, harvesting
    case pests, diseases, winter, position, soil

    /// Pieces of a tidied question that mean this kind. A leading space
    /// marks the start of a word, so " prun" finds "prune" and
    /// "pruning" but not "sprung". (EiraSafety.tidied puts the question
    /// in lower case, turns punctuation into spaces and puts a space at
    /// each end.)
    var asked: [String] {
        switch self {
        case .cuttingBack: return [" prun", " cut back", " cut down", " cutting back", " cutting down", " cut off",
                                   " cut it ", " cut them ", " cut the ", " chop", " trim", " deadhead", " dead head", " tidy", " remove the leaves",
                                   " remove the old", " shear"]
        case .feeding: return [" feed", " fertilis", " fertiliz", " mulch", " manure", " top dress"]
        case .watering: return [" water ", " watering ", " watered "]
        case .dividing: return [" divide", " dividing", " split ", " splitting", " propagat", " cuttings", " layering"]
        case .plantingOut: return [" plant out", " planting out", " planted out", " transplant", " harden off", " hardening off",
                                   " pot on", " potting on"]
        case .sowing: return [" sow ", " sowing ", " sown ", " germinat"]
        case .harvesting: return [" harvest", " pick ", " picking ", " ripe ", " ripen", " ready to pull", " ready to pick",
                                  " ready to lift", " lift the "]
        case .pests: return [" pest", " slug", " snail", " aphid", " greenfly", " blackfly", " whitefly", " caterpillar",
                             " eaten ", " eating my ", " holes in "]
        case .diseases: return [" disease", " mildew", " blight", " rust ", " rot ", " rotting ", " canker", " scab ",
                                " mould", " yellowing", " spots on ", " leaf spot"]
        case .winter: return [" frost", " winter", " overwinter", " fleece", " protect"]
        case .position: return [" sun ", " shade ", " sunny ", " shady ", " where should i plant", " where to plant",
                                " where do i plant", " aspect "]
        case .soil: return [" soil", " ph ", " clay ", " drainage", " well drained"]
        }
    }

    /// Words that mark the right paragraph of a gardening page. Looked
    /// for anywhere in a line, in lower case.
    var pageWords: [String] {
        switch self {
        case .cuttingBack: return ["cut back", "cut away", "cut down", "cut off", "cutting back", "prun", "die back",
                                   "dies back", "died back", "died down", "die down", "old leaves", "dead leaves",
                                   "old foliage", "trim", "tidy"]
        case .feeding: return ["feed", "fertilis", "mulch", "manure", "organic matter"]
        case .watering: return ["water"]
        case .dividing: return ["divid", "split", "propagat", "cutting", "layer"]
        case .plantingOut: return ["plant out", "planting out", "transplant", "harden", "pot on", "planting"]
        case .sowing: return ["sow", "germinat", "seed"]
        case .harvesting: return ["harvest", "pick", "ripe", "ready"]
        case .pests: return ["pest", "slug", "snail", "aphid", "caterpillar", "fly"]
        case .diseases: return ["disease", "mildew", "blight", "rust", "rot", "canker", "scab", "mould"]
        case .winter: return ["frost", "winter", "cold", "hardy", "protect", "fleece"]
        case .position: return ["sun", "shade", "shelter", "site", "position"]
        case .soil: return ["soil", "drain", "clay", "acid", "alkaline"]
        }
    }

    /// The boxes of the plant's record that answer this kind, best
    /// first. A fact kept on this kind goes into the first.
    var fields: [PlantField] {
        switch self {
        case .cuttingBack: return [.pruning]
        case .feeding, .watering, .winter: return [.notes]
        case .dividing: return [.propagation]
        case .plantingOut: return [.plantOut]
        case .sowing: return [.sowOutdoors, .sowIndoors]
        case .harvesting: return [.harvest]
        case .pests: return [.pests]
        case .diseases: return [.diseases]
        case .position: return [.sunShade, .position]
        case .soil: return [.soil, .soilPH]
        }
    }

    /// The kind in words, for "No ... advice is recorded".
    var name: String {
        switch self {
        case .cuttingBack: return "pruning or cutting back"
        case .feeding: return "feeding or mulching"
        case .watering: return "watering"
        case .dividing: return "dividing or propagating"
        case .plantingOut: return "planting out"
        case .sowing: return "sowing"
        case .harvesting: return "harvesting"
        case .pests: return "pest"
        case .diseases: return "disease"
        case .winter: return "winter care"
        case .position: return "sun or shade"
        case .soil: return "soil"
        }
    }

    /// The kind of care a piece of text is about, or nil if none.
    static func find(in text: String) -> CareTopic? {
        let tidied = EiraSafety.tidied(text)
        return allCases.first { topic in topic.asked.contains { tidied.contains($0) } }
    }
}

// MARK: - The rules

enum KeptFacts {

    // MARK: Which plant a question is about

    /// The plant a piece of text names, out of the names in the plant
    /// library. Returns the name as the library spells it, or nil.
    ///
    ///   "do I need to chop the rhubarb back?"   Rhubarb
    ///   "when do I prune the apples?"           Apple
    ///   "are my broad beans frost hardy?"       Broad bean, not Bean
    ///   "should I prune?"                       nil
    ///
    /// A name must appear as whole words, so "pea" is not found in
    /// "pear". One or more plants is allowed for, in either direction:
    /// "carrot" finds Carrots and "apples" finds Apple. When two names
    /// fit, the longer wins. When "Apple" and "Apple (Cider)" both fit
    /// "apple", the plain one wins: the names are tried shortest first,
    /// and a later one must be longer to take its place.
    static func plantNamed(in text: String, among names: [String]) -> String? {
        let tidied = EiraSafety.tidied(text)
        var best: String?
        var bestLength = 0
        // Sorted, so that the answer is the same every time.
        let inOrder = Set(names).sorted { $0.count != $1.count ? $0.count < $1.count : $0 < $1 }
        for name in inOrder {
            // "Apple (Cider)" is looked for as "apple".
            let plain = EiraSafety.tidied(withoutBrackets(name)).trimmingCharacters(in: .whitespaces)
            guard plain.count >= 3, plain.count > bestLength else { continue }
            let fits = spellings(of: plain).contains { tidied.contains(" \($0) ") }
            if fits {
                best = name
                bestLength = plain.count
            }
        }
        return best
    }

    /// True for a short care question that names no plant and could
    /// only be answered by asking which: "Should I prune?", "When do I
    /// mulch?". Only for cutting back, feeding and dividing, which are
    /// always about one plant. "Is it frosty?" is short too, and is
    /// not asking about a plant at all.
    static func shouldAskWhichPlant(_ question: String) -> Bool {
        guard let topic = CareTopic.find(in: question),
              [.cuttingBack, .feeding, .dividing].contains(topic) else { return false }
        return EiraSafety.tidied(question).split(separator: " ").count <= 5
    }

    /// A name with anything in brackets taken off: "Apple (Cider)"
    /// becomes "Apple".
    static func withoutBrackets(_ name: String) -> String {
        name.replacingOccurrences(of: "\\([^)]*\\)", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// A name as one and as several: "carrot" and "carrots",
    /// "raspberry" and "raspberries", "potato" and "potatoes".
    static func spellings(of name: String) -> [String] {
        var found = [name]
        if name.hasSuffix("ies"), name.count > 4 {
            found.append(String(name.dropLast(3)) + "y")
        } else if name.hasSuffix("oes"), name.count > 4 {
            found.append(String(name.dropLast(2)))
        } else if name.hasSuffix("s"), !name.hasSuffix("ss"), name.count > 3 {
            found.append(String(name.dropLast()))
        } else if name.hasSuffix("y"), name.count > 3, !"aeiou".contains(name.dropLast().last ?? "a") {
            found.append(String(name.dropLast()) + "ies")
        } else if name.hasSuffix("o"), name.count > 3 {
            found.append(name + "es")
            found.append(name + "s")
        } else {
            found.append(name + "s")
        }
        return found
    }

    // MARK: What to look for on a page

    /// The words of a question that tell one paragraph of a page from
    /// another, for WebText.passages.
    ///
    /// These are the question's own words that matter, less the plant's
    /// name, which is on every line of a page about that plant. A
    /// question that asks when ("When do I prune the lavender?") also
    /// looks for the months, the seasons and words such as "timing",
    /// so that the paragraph that says when comes first.
    static func pageWords(forQuestion question: String, plant: String? = nil) -> [String] {
        var words = EiraChecks.wordsThatMatter(in: question)
        let dull: Set<String> = ["need", "back", "first", "after", "before", "page", "says", "http", "https",
                                 "leave", "leaf", "plant", "thing", "time"]
        words.subtract(dull)
        if let plant {
            for each in EiraSafety.tidied(withoutBrackets(plant)).split(separator: " ") {
                for spelling in spellings(of: String(each)) { words.remove(spelling) }
            }
        }
        let tidied = EiraSafety.tidied(question)
        // "When do I prune?" asks when. "When the rhubarb has wilted, do
        // I cut it back?" does not, so "when" must be followed by one
        // of the words a question puts after it.
        let asksWhen = [" when do ", " when does ", " when should ", " when can ", " when is ", " when are ",
                        " when to ", " when would ", " when will ", " what time ", " which month", " what month"]
        if asksWhen.contains(where: { tidied.contains($0) }) {
            words.formUnion(["timing", "january", "february", "march", "april", "may ", "june", "july", "august",
                             "september", "october", "november", "december", "spring", "summer", "autumn",
                             "winter", "every year", "each year", "annual"])
        }
        return words.sorted()
    }

    // MARK: Which box a fact belongs in

    /// The box of a plant's record a fact belongs in, by plain rules.
    ///
    /// The question is read first, because it says what was wanted, and
    /// then the fact itself. A fact about sowing goes to "Sow indoors"
    /// if it speaks of indoors, a greenhouse or a windowsill. Anything
    /// the rules cannot place goes to Notes. You can always choose
    /// another on the card: this is only the starting choice.
    static func field(forQuestion question: String, words: String) -> PlantField {
        guard let topic = CareTopic.find(in: question) ?? CareTopic.find(in: words) else { return .notes }
        if topic == .sowing {
            let both = EiraSafety.tidied(question + " " + words)
            let indoors = [" indoors", " under cover", " undercover", " greenhouse", " windowsill", " propagator", " under glass"]
            if indoors.contains(where: { both.contains($0) }) { return .sowIndoors }
        }
        return topic.fields[0]
    }

    // MARK: Months

    private static let monthShort = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// The months a sentence names, as numbers, 1 for January.
    ///
    /// "Sow from March to May" gives 3, 4 and 5. The app's own month
    /// reader (MonthParser) understands a range written with a dash,
    /// "Mar-May", so "to", "until" and "through" between two months are
    /// turned into a dash first.
    static func months(in words: String) -> [Int] {
        let month = "(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)"
        let joined = words.lowercased().replacingOccurrences(
            of: "\(month)\\s*(?:to|until|till|through|\u{2013}|\u{2014})\\s*\(month)",
            with: "$1-$2", options: .regularExpression)
        return MonthParser.months(in: joined)
    }

    /// Months as the plant's record writes them: "Mar, Apr, May".
    static func monthsText(_ months: [Int]) -> String {
        months.filter { (1...12).contains($0) }.map { monthShort[$0 - 1] }.joined(separator: ", ")
    }

    // MARK: Writing a fact into a box

    /// Whether a fact takes the place of what a box holds, or joins it.
    enum How: String, CaseIterable, Identifiable {
        case replace, add
        var id: String { rawValue }
        var title: String { self == .replace ? "Replace" : "Add to it" }
    }

    /// What a box would hold once a fact is kept, or nil if the fact
    /// cannot go in that box.
    ///
    /// - A box of months takes only months. "Sow from March to May"
    ///   becomes "Mar, Apr, May". A fact naming no month cannot go in.
    /// - Adding to a box of months joins the two sets of months.
    /// - Adding to a box of words puts the fact after what is there.
    static func newValue(for field: PlantField, words: String, present: String?, how: How) -> String? {
        let fact = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fact.isEmpty else { return nil }

        if field.holdsMonths {
            var found = months(in: fact)
            guard !found.isEmpty else { return nil }
            if how == .add { found = Array(Set(found + MonthParser.months(in: present))).sorted() }
            return monthsText(found)
        }
        guard how == .add, let present, !present.isEmpty else { return fact }
        // Do not write the same thing twice.
        if present.localizedCaseInsensitiveContains(fact) { return present }
        let joiner = present.hasSuffix(".") || present.hasSuffix("!") || present.hasSuffix("?") ? " " : ". "
        return present + joiner + fact
    }

    // MARK: The check after two years

    /// How long a kept fact stands before it is due a check.
    static let yearsBeforeCheck = 2

    /// The day a fact is due a check: two years after it was kept, or
    /// after you last said it was still right.
    static func dueDate(for fact: KeptFact, calendar: Calendar = .current) -> Date {
        let from = max(fact.keptAt, fact.checkedAt ?? .distantPast)
        return calendar.date(byAdding: .year, value: yearsBeforeCheck, to: from) ?? from
    }

    static func isDue(_ fact: KeptFact, today: Date = .now, calendar: Calendar = .current) -> Bool {
        today >= dueDate(for: fact, calendar: calendar)
    }

    // MARK: Words

    /// "RHS, kept Nov 2026", for the small label beside a value.
    static func sourceLabel(for fact: KeptFact) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "MMM yyyy"
        let when = "kept \(formatter.string(from: fact.keptAt))"
        let name = fact.sourceName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? when : "\(name), \(when)"
    }

    /// The same for Eira, who is handed it beside the value so that
    /// she says where a fact came from and how old it is.
    static func saidToEira(of fact: KeptFact, today: Date = .now) -> String {
        var said = "kept by the gardener from \(fact.sourceName.isEmpty ? "their own reading" : fact.sourceName)"
        said += ", \(fact.trust.said)"
        said += ", " + sourceLabel(for: fact).components(separatedBy: ", ").last!
        if isDue(fact, today: today) { said += ", over two years ago and due a check" }
        return said
    }
}

// MARK: - Reading and writing kept facts

/// Keeps, removes and lists kept facts.
///
/// `@MainActor` means this runs on the app's main thread, where the
/// database's `ModelContext` lives.
@MainActor
struct KeptFactStore {

    let context: ModelContext

    /// Every kept fact, newest first.
    func all() -> [KeptFact] {
        let facts = (try? context.fetch(FetchDescriptor<KeptFact>())) ?? []
        return facts.sorted { $0.keptAt > $1.keptAt }
    }

    /// The kept facts for one plant, newest first.
    func facts(for plant: Plant) -> [KeptFact] {
        all().filter { $0.plantID == plant.id }
    }

    /// Writes a fact into a box of each plant's record and remembers
    /// where it came from. Returns the records made: one for each plant
    /// the fact could be written to.
    ///
    /// `plants` is usually every variety of one plant. Rhubarb is in
    /// the library three times (Champagne, Timperley Early, Victoria),
    /// and when to cut its leaves back is the same for all three.
    @discardableResult
    func keep(words: String, in field: PlantField, of plants: [Plant], how: KeptFacts.How,
              sourceName: String, sourceAddress: String?, trust: SourceTrust,
              question: String? = nil, on date: Date = .now) -> [KeptFact] {
        var made: [KeptFact] = []
        for plant in plants {
            let before = field.value(in: plant)
            guard let after = KeptFacts.newValue(for: field, words: words, present: before, how: how) else { continue }
            field.set(after, in: plant)

            let fact = KeptFact()
            fact.keptAt = date
            fact.plantID = plant.id
            fact.plantName = plant.displayName
            fact.fieldRaw = field.rawValue
            fact.words = words.trimmingCharacters(in: .whitespacesAndNewlines)
            fact.valueBefore = before
            fact.valueAfter = after
            fact.sourceName = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
            let address = sourceAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            fact.sourceAddress = address.isEmpty ? nil : address
            fact.trustRaw = trust.rawValue
            fact.question = question
            context.insert(fact)
            made.append(fact)
        }
        try? context.save()
        return made
    }

    /// Takes a kept fact away. If the box still holds exactly what the
    /// fact put there, the value from before is put back and this
    /// returns true. If the box has been changed since, it is left as
    /// it is, because the change is yours, and this returns false.
    @discardableResult
    func remove(_ fact: KeptFact) -> Bool {
        var putBack = false
        let plants = (try? context.fetch(FetchDescriptor<Plant>())) ?? []
        if let plant = plants.first(where: { $0.id == fact.plantID }),
           fact.presentValue(in: plant) == fact.valueAfter {
            // Through PlantFacts, which knows every box by its key.
            PlantFacts.write(fact.valueBefore ?? "", forKey: fact.boxKey, to: plant)
            putBack = true
        }
        context.delete(fact)
        try? context.save()
        return putBack
    }

    /// A checking aid: keeps two example facts for the example
    /// garden's rhubarb, one of them old enough to be due a check, so
    /// that still pictures can be taken of the cards and the list.
    /// Only ever called for the example garden, whose records live in
    /// memory. Does nothing if anything is already kept.
    func keepExamples(asOf: Date = .now) {
        guard all().isEmpty else { return }
        let everyPlant = (try? context.fetch(FetchDescriptor<Plant>())) ?? []
        let rhubarbs = everyPlant.filter { $0.commonName == "Rhubarb" }
        guard let oneRhubarb = rhubarbs.first else { return }
        keep(words: "Let the leaves die back in autumn, then cut the old ones away so that the winter cold reaches the crown.",
             in: .pruning, of: rhubarbs, how: .add, sourceName: "RHS",
             sourceAddress: "https://www.rhs.org.uk/vegetables/rhubarb/grow-your-own", trust: .checked,
             question: "Do I need to chop the rhubarb's leaves back after a frost?", on: asOf)
        keep(words: "Split the crown every five years or so, in late autumn, to keep it cropping well.",
             in: .propagation, of: [oneRhubarb], how: .add, sourceName: "The Fruit Garden Displayed",
             sourceAddress: nil, trust: .ownReading,
             on: asOf.addingTimeInterval(-86_400 * 800))
    }

    /// "Still right": the fact stands for another two years.
    func markChecked(_ fact: KeptFact, on date: Date = .now) {
        fact.checkedAt = date
        try? context.save()
    }

    /// The source labels for one plant's page: the name of a box, as
    /// the page shows it, to "RHS, kept Nov 2026". Only for a box that
    /// still holds what the fact put there.
    func sourceLabels(for plant: Plant) -> [String: String] {
        var labels: [String: String] = [:]
        // Oldest first, so the newest fact for a box is the one shown.
        for fact in facts(for: plant).reversed() where fact.presentValue(in: plant) == fact.valueAfter {
            labels[fact.boxLabel] = KeptFacts.sourceLabel(for: fact)
        }
        return labels
    }
}
