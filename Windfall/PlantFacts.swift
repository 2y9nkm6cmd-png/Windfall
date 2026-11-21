//
//  PlantFacts.swift
//  Windfall
//
//  Every fact a plant's record holds, in one list.
//
//  Four parts of the app go through a plant's facts one by one: the
//  page that shows them (PlantPage.swift), the sheet that changes them
//  (PlantEditView.swift), the import that must not undo a change made
//  by hand (GardenData.swift) and the backup (BackupService.swift).
//  Before 14 November 2026 each spelt the facts out for itself and they
//  did not agree: of the 66 facts the page showed 49, the backup kept
//  8, and nothing in the app could change any.
//
//  So the list is written once, here. Each line of it names one fact:
//  the word it is stored under, what the page calls it, which card it
//  sits on, what kind of thing it is and where it lives in the record.
//
//  Nothing here draws anything, so it can be tested without a screen.
//

import Foundation

enum PlantFacts {

    // MARK: - The cards

    /// The groups the facts fall into: the groups of columns in the
    /// spreadsheet the library came from, in its order. Each is a card
    /// on a plant's page, except the first, which is the page's heading.
    enum Group: String, CaseIterable, Identifiable {
        case naming = "Name and kind"
        case patterns = "Growth Patterns"
        case habits = "Growth Habits"
        case permaculture = "Permaculture Category"
        case sowing = "Sowing from Seed"
        case constraints = "Growth Constraints"
        case management = "Human Management"
        case ecology = "Ecological Interactions"
        case description = "Description"

        var id: String { rawValue }
        var title: String { rawValue }

        /// The groups that are cards on the page.
        static var cards: [Group] { allCases.filter { $0 != .naming } }
    }

    // MARK: - What kind of thing a fact is

    /// How a fact is shown and how it is typed in.
    enum Kind: Equatable {
        /// A word or a few: "Herbaceous".
        case text
        /// A sentence or more, given the full width and several lines.
        case longText
        /// A figure with a unit, such as "m". The record holds the
        /// figure and the page adds the unit.
        case measure(String)
        /// A length of time: "7-14 days", "12-16 weeks".
        case duration
        /// Months of the year, drawn as a strip of twelve.
        case months(PlantPage.MonthKind)
        /// Yes or no. On the page a yes is a chip, and a no is nothing.
        case yesNo
    }

    // MARK: - One fact

    /// One fact a plant's record can hold.
    struct Field: Identifiable {
        /// The word it is filed under: in the list of facts changed by
        /// hand and in a backup file. It is the name of the place in
        /// the record. Never shown, and never to be changed, or an old
        /// backup would no longer find its way home.
        let key: String
        /// What the page and the editing sheet call it.
        let label: String
        let group: Group
        let kind: Kind
        /// Grey words shown in an empty box, as an example of what to
        /// type.
        let hint: String

        /// Reads the fact out of a record. Nil when it is not filled in.
        fileprivate let read: (Plant) -> String?
        /// Writes it back. Nil clears it.
        fileprivate let write: (Plant, String?) -> Void

        var id: String { key }
    }

    /// What a yes-or-no fact holds, as text, when it is yes. When it is
    /// no it holds nothing, like any other fact that is not filled in.
    static let yes = "yes"

    // The two helpers below build one line of the list each.
    //
    // `\.latinName` is a "key path": a way of naming a place in a
    // record without reading it yet, like the label on a drawer. The
    // helper is handed the label and makes the two small pieces of code
    // that open that drawer, one to read and one to write. That is what
    // lets 66 facts be listed in 66 lines.

    /// A fact held as text.
    private static func words(_ key: String, _ label: String, _ factGroup: Group,
                              _ place: ReferenceWritableKeyPath<Plant, String?>,
                              _ factKind: Kind = .text, hint: String = "") -> Field {
        Field(key: key, label: label, group: factGroup, kind: factKind, hint: hint,
              read: { $0[keyPath: place] },
              write: { plant, newText in plant[keyPath: place] = newText })
    }

    /// A fact held as true or false.
    private static func yesNo(_ key: String, _ label: String, _ factGroup: Group,
                              _ place: ReferenceWritableKeyPath<Plant, Bool>) -> Field {
        Field(key: key, label: label, group: factGroup, kind: .yesNo, hint: "",
              read: { $0[keyPath: place] ? yes : nil },
              write: { plant, newText in plant[keyPath: place] = (newText == yes) })
    }

    // MARK: - The list

    /// Every fact, in the order the page shows them.
    static let all: [Field] = [
        // Name and kind. The common name is the one fact that can never
        // be blank, so it has its own two pieces of code.
        Field(key: "commonName", label: "Common name", group: .naming, kind: .text, hint: "Achillea",
              read: { $0.commonName },
              write: { plant, newText in
                  if let newText, !newText.isEmpty { plant.commonName = newText }
              }),
        words("latinName", "Latin name", .naming, \.latinName, hint: "Achillea millefolium"),
        words("variety", "Variety or cultivar", .naming, \.variety, hint: "Summer berries"),
        words("group", "Group", .naming, \.group, hint: "Wildflower, Fruit, Alliums"),
        words("classification", "Classification", .naming, \.classification, hint: "Hardy perennial"),
        words("typeLabel", "Type", .naming, \.typeLabel, hint: "Plant, Seeds, Scion"),

        // Growth Patterns
        words("floweringMonthsText", "Flowering", .patterns, \.floweringMonthsText, .months(.flowering)),
        words("stemGrowthMonthsText", "Stem growth", .patterns, \.stemGrowthMonthsText, .months(.growth)),
        words("foliageMonthsText", "Foliage", .patterns, \.foliageMonthsText, .months(.growth)),
        words("fruitingMonthsText", "Fruiting", .patterns, \.fruitingMonthsText, .months(.fruiting)),
        words("plantType", "Plant type", .patterns, \.plantType, hint: "Tree, Bush, Climber"),
        words("foliagePattern", "Foliage pattern", .patterns, \.foliagePattern, hint: "Deciduous or evergreen"),
        words("habits", "Habits", .patterns, \.habits, .longText, hint: "Clump forming"),

        // Growth Habits
        words("maxHeightM", "Max height", .habits, \.maxHeightM, .measure("m"), hint: "0.3-0.9"),
        words("timeToUltimateHeight", "Time to full height", .habits, \.timeToUltimateHeight, hint: "2-5 years"),
        words("spreadM", "Spread", .habits, \.spreadM, .measure("m"), hint: "0.3-0.6"),
        words("rootDepthM", "Root depth", .habits, \.rootDepthM, .measure("m"), hint: "0.3"),
        words("rootSpreadM", "Root spread", .habits, \.rootSpreadM, .measure("m"), hint: "0.6"),
        words("leafSizeCM", "Leaf size", .habits, \.leafSizeCM, .measure("cm"), hint: "30-45"),
        words("spacingM", "Spacing", .habits, \.spacingM, .measure("m"), hint: "0.35"),
        words("leafDescription", "Leaf description", .habits, \.leafDescription, .longText),
        words("leafColour", "Leaf colour", .habits, \.leafColour, hint: "Blue-green"),
        words("flowerSizeCM", "Flower size", .habits, \.flowerSizeCM, .measure("cm"), hint: "0.6-1"),
        words("flowerForm", "Flower form", .habits, \.flowerForm, hint: "Stellate"),
        words("fruitSizeCM", "Fruit size", .habits, \.fruitSizeCM, .measure("cm")),
        words("fruitType", "Fruit type", .habits, \.fruitType),
        words("pollinationGroup", "Pollination group", .habits, \.pollinationGroup, hint: "3 / C"),
        words("ploidy", "Ploidy", .habits, \.ploidy, hint: "Diploid or triploid"),
        words("layer", "Layer", .habits, \.layer, hint: "Trees, Shrubs, Herbaceous"),

        // Permaculture Category
        yesNo("isPollinator", "Pollinator plant", .permaculture, \.isPollinator),
        yesNo("isRepeller", "Pest repeller", .permaculture, \.isRepeller),
        yesNo("isUmbelliferous", "Umbelliferous", .permaculture, \.isUmbelliferous),
        yesNo("isNitrogenFixer", "Nitrogen fixer", .permaculture, \.isNitrogenFixer),
        yesNo("isDynamicAccumulator", "Dynamic accumulator", .permaculture, \.isDynamicAccumulator),
        yesNo("isGroundCover", "Ground cover", .permaculture, \.isGroundCover),

        // Sowing from Seed
        words("sowIndoorsMonthsText", "Sow indoors", .sowing, \.sowIndoorsMonthsText, .months(.sowIndoors)),
        words("sowOutdoorsMonthsText", "Sow outdoors", .sowing, \.sowOutdoorsMonthsText, .months(.sowOutdoors)),
        words("plantOutMonthsText", "Plant out", .sowing, \.plantOutMonthsText, .months(.plantOut)),
        words("harvestMonthsText", "Harvest", .sowing, \.harvestMonthsText, .months(.harvest)),
        words("germinationDaysText", "Germination", .sowing, \.germinationDaysText, .duration, hint: "7-14 days"),
        words("sowToCropText", "Sow to crop", .sowing, \.sowToCropText, .duration, hint: "12-16 weeks"),
        words("sowingDepthMM", "Sowing depth", .sowing, \.sowingDepthMM, .measure("mm"), hint: "10"),
        words("sowingTemperatureC", "Sowing temperature", .sowing, \.sowingTemperatureC, .measure("°C"), hint: "18-20"),
        words("sowingPreference", "Sowing preference", .sowing, \.sowingPreference, hint: "Indoors or outdoors"),
        // Added 21 November 2026, for "Sow again" (SowAgain.swift).
        words("sowAgainEvery", "Sow again every", .sowing, \.sowAgainEvery, .duration, hint: "3 weeks"),
        yesNo("needsPropagator", "Needs a propagator", .sowing, \.needsPropagator),
        words("rootstock", "Rootstock", .sowing, \.rootstock, hint: "MM106"),
        words("propagation", "Propagation", .sowing, \.propagation, hint: "Seed, cuttings, division"),

        // Growth Constraints
        words("sunShade", "Sun / shade", .constraints, \.sunShade, hint: "Full sun or part shade"),
        words("position", "Position", .constraints, \.position, .longText, hint: "Sunny, sheltered"),
        words("hardiness", "Hardiness", .constraints, \.hardiness, hint: "H6"),
        words("soilPH", "Soil pH", .constraints, \.soilPH, hint: "Acid, Neutral"),
        words("preferredSoilConditions", "Soil conditions", .constraints, \.preferredSoilConditions, .longText,
              hint: "Loamy, fertile"),
        // Added 21 November 2026: the spreadsheet's Moisture column.
        words("moisture", "Moisture", .constraints, \.moisture, hint: "Moist but well-drained"),
        words("knownPests", "Pests", .constraints, \.knownPests, .longText, hint: "slugs; aphids"),
        words("knownDiseases", "Diseases", .constraints, \.knownDiseases, .longText),

        // Human Management
        words("maintenancePropagationFrequency", "Maintenance propagation", .management,
              \.maintenancePropagationFrequency, .longText, hint: "Divide every 3 years"),
        words("pruning", "Pruning", .management, \.pruning, .longText),
        words("pruningGroup", "Pruning group", .management, \.pruningGroup),
        words("culinaryUses", "Culinary uses", .management, \.culinaryUses, .longText),
        words("medicinalUses", "Medicinal uses", .management, \.medicinalUses, .longText),
        words("toxicityCautions", "Toxicity", .management, \.toxicityCautions, .longText),

        // Ecological Interactions
        words("partnerPlants", "Partner plants", .ecology, \.partnerPlants, .longText),
        words("antagonisticPlants", "Antagonistic plants", .ecology, \.antagonisticPlants, .longText),
        words("pollinators", "Pollinators", .ecology, \.pollinators, .longText),

        // Description
        words("appearance", "Appearance", .description, \.appearance, .longText),
        words("history", "History", .description, \.history, .longText),
        words("notes", "Notes", .description, \.notes, .longText)
    ]

    /// The fact filed under a key, if there is one.
    static func named(_ key: String) -> Field? {
        all.first { $0.key == key }
    }

    /// The facts on one card, in order.
    static func fields(in factGroup: Group) -> [Field] {
        all.filter { $0.group == factGroup }
    }

    /// Facts that have a sheet of their own, opened from a button under
    /// Edit, and so are left off the cards of the page and of the
    /// editing sheet. Only Notes, for now (William, 21 November 2026:
    /// the spreadsheet's notes sat at the very foot of the page, where
    /// nobody found them). They are still in `all`, so the import, the
    /// backup and Eira read and write them as before.
    static let ownSheetKeys: Set<String> = ["notes"]

    /// The facts drawn on one card: `fields(in:)` without those that
    /// have a sheet of their own.
    static func cardFields(in factGroup: Group) -> [Field] {
        fields(in: factGroup).filter { !ownSheetKeys.contains($0.key) }
    }

    // MARK: - Reading and writing one fact

    /// A fact as text, with the spaces trimmed from its ends. Empty
    /// when it is not filled in.
    static func value(of factField: Field, in plant: Plant) -> String {
        (factField.read(plant) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Writes one fact. Blank text clears it. The common name is the
    /// exception: it is left as it was.
    static func setValue(_ newText: String, for factField: Field, in plant: Plant) {
        let tidy = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        factField.write(plant, tidy.isEmpty ? nil : tidy)
    }

    /// True for a value that stands for "nothing here": a lone star,
    /// question mark or dash, which the spreadsheet uses as a marker.
    /// The page leaves these out. The editing sheet still shows them,
    /// so they can be replaced.
    static func isPlaceholder(_ text: String) -> Bool {
        !text.contains { $0.isLetter || $0.isNumber }
    }

    // MARK: - All of a plant's facts at once

    /// Every fact of a plant as text, by key. A fact that is not filled
    /// in is there as empty text, so every key is always present.
    ///
    /// The editing sheet works on one of these. Nothing reaches the
    /// record until Save, so Cancel has nothing to undo.
    static func values(of plant: Plant) -> [String: String] {
        var found: [String: String] = [:]
        for factField in all { found[factField.key] = value(of: factField, in: plant) }
        return found
    }

    /// The facts whose text in `values` differs from the record, in the
    /// list's order. A key missing from `values` counts as unchanged.
    static func changed(_ values: [String: String], from plant: Plant) -> [Field] {
        all.filter { factField in
            guard let typed = values[factField.key] else { return false }
            let tidy = typed.trimmingCharacters(in: .whitespacesAndNewlines)
            // A blank common name is not a change. It cannot be saved.
            if factField.key == "commonName", tidy.isEmpty { return false }
            return tidy != value(of: factField, in: plant)
        }
    }

    /// Writes the changed facts to the record and notes each as changed
    /// by hand, so that loading a spreadsheet file later leaves it be.
    /// Returns the keys of what changed.
    @discardableResult
    static func save(_ values: [String: String], to plant: Plant) -> [String] {
        let toWrite = changed(values, from: plant)
        guard !toWrite.isEmpty else { return [] }

        // The name the file knows it by, noted before the first rename.
        let nameIsChanging = toWrite.contains { $0.key == "commonName" || $0.key == "variety" }
        if nameIsChanging, plant.importedAs == nil, plant.sourceSheet != nil {
            plant.importedAs = libraryKey(name: plant.commonName, variety: plant.variety)
        }

        for factField in toWrite {
            setValue(values[factField.key] ?? "", for: factField, in: plant)
            if !plant.changedByHand.contains(factField.key) {
                plant.changedByHand.append(factField.key)
            }
        }
        return toWrite.map(\.key)
    }

    /// Writes one fact and notes it as changed by hand. For anything
    /// that writes a single box of a plant's record from outside the
    /// editing sheet, such as a fact kept from a web page: going through
    /// here is what stops a later load of the spreadsheet file from
    /// replacing it. Returns false, and writes nothing, if the key is
    /// not one in the list.
    @discardableResult
    static func write(_ newText: String, forKey key: String, to plant: Plant) -> Bool {
        guard named(key) != nil else { return false }
        save([key: newText], to: plant)
        return true
    }

    // MARK: - Months

    /// Months as the spreadsheet writes them: "jan feb mar".
    static func monthText(_ months: [Int]) -> String {
        let names = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        return Set(months).filter { (1...12).contains($0) }.sorted().map { names[$0 - 1] }.joined(separator: " ")
    }

    /// The text of a months fact with one month switched on or off. The
    /// result is always in the spreadsheet's own style, whatever style
    /// the text came in.
    static func toggling(_ month: Int, in text: String) -> String {
        var months = Set(MonthParser.months(in: text))
        if months.contains(month) { months.remove(month) } else { months.insert(month) }
        return monthText(Array(months))
    }

    // MARK: - Keeping what was changed by hand

    /// The name a plant is known by when files are matched against the
    /// library: its common name and variety, in small letters. Two rows
    /// with the same key are the same plant.
    static func libraryKey(name: String, variety: String?) -> String {
        (name + "|" + (variety ?? "")).lowercased()
    }

    /// Runs `rewrite`, which may write anything it likes to the plant's
    /// record, then puts back every fact that had been changed by hand.
    /// Returns how many facts it had to put back.
    ///
    /// The import uses this: a row of the spreadsheet file is copied on
    /// to the record, and whatever was typed in the app survives it.
    static func keepingHandChanges(in plant: Plant, during rewrite: () -> Void) -> Int {
        let byHand = plant.changedByHand.compactMap { named($0) }
        guard !byHand.isEmpty else {
            rewrite()
            return 0
        }
        let before = byHand.map { value(of: $0, in: plant) }
        rewrite()

        var putBack = 0
        for (factField, old) in zip(byHand, before) where value(of: factField, in: plant) != old {
            setValue(old, for: factField, in: plant)
            putBack += 1
        }
        return putBack
    }

    // MARK: - For the backup

    /// A plant's filled-in facts by key, with the empty ones left out.
    /// This is what a backup file keeps for each plant.
    static func record(of plant: Plant) -> [String: String] {
        values(of: plant).filter { !$0.value.isEmpty }
    }

    /// Fills an empty record from a backup's facts. A key this version
    /// of the app does not know is skipped.
    static func fill(_ plant: Plant, from record: [String: String]) {
        for (key, text) in record {
            if let factField = named(key) { setValue(text, for: factField, in: plant) }
        }
    }

    /// Carries a backup's hand-made changes on to a record that is
    /// already in the library, which is what a restore meets on a fresh
    /// copy of the app: the starter library is there, as the spreadsheet
    /// had it, and the changes typed in the app are only in the backup.
    ///
    /// A fact the record has itself had changed by hand is left alone,
    /// so a restore never undoes newer work. Returns how many facts
    /// were written.
    @discardableResult
    static func restoreHandChanges(_ keys: [String], from record: [String: String],
                                   importedAs: String?, to plant: Plant) -> Int {
        var written = 0
        for key in keys where !plant.changedByHand.contains(key) {
            guard let factField = named(key) else { continue }
            let old = value(of: factField, in: plant)
            setValue(record[key] ?? "", for: factField, in: plant)
            plant.changedByHand.append(key)
            if value(of: factField, in: plant) != old { written += 1 }
        }
        if plant.importedAs == nil { plant.importedAs = importedAs }
        return written
    }
}
