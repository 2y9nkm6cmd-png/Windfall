//
//  GardenData.swift
//  Windfall
//
//  Brings your plant and wildlife reference data into the app from a file.
//
//  This replaces the Google Sheets link. The app's own database is now the
//  master copy. Data arrives in one of three ways:
//
//    Starter data   StarterData.json, built from Garden_Planning.xlsx and
//                   shipped inside the app. Loaded once, on first launch.
//    A JSON file    The same format, picked with the Files chooser.
//    A CSV file     One table, such as an export from Numbers.
//
//  Two decisions carried over from the Sheets importer:
//
//  1. Columns are found by HEADER NAME, never by position. Move a column
//     in the spreadsheet and nothing breaks.
//
//  2. Worked-out columns are ignored. Germination days, sow-to-crop days
//     and the plant variety label are spreadsheet formulas. The app works
//     them out itself from the source text, so there is one version of
//     the sum instead of two that can drift apart.
//

import Foundation
import SwiftData
import Observation

// MARK: - The file

/// One table from the file: a name and its rows. Each row is a set of
/// "column heading: value" pairs. A blank cell is simply not there.
struct GardenTable: Codable, Equatable {
    var name: String
    var rows: [[String: String]]
}

/// A whole data file. `Codable` means Swift can read it from JSON and
/// write it back without any hand-written conversion.
struct GardenDataFile: Codable, Equatable {

    /// Raised if the layout of the file ever changes, so an old app can
    /// tell it has been handed something it does not understand.
    var formatVersion: Int = 1
    /// Where the data came from, such as "Garden_Planning.xlsx".
    var source: String = ""
    /// The date the file was made.
    var generated: String = ""
    var tables: [GardenTable] = []

    /// The newest layout this version of the app can read.
    static let newestFormat = 1

    func table(named name: String) -> GardenTable? {
        tables.first { $0.name.lowercased() == name.lowercased() }
    }

    /// Reads a file from raw JSON.
    static func decode(_ data: Data) throws -> GardenDataFile {
        let file: GardenDataFile
        do {
            file = try JSONDecoder().decode(GardenDataFile.self, from: data)
        } catch {
            throw GardenDataError.unreadable
        }
        guard file.formatVersion <= newestFormat else {
            throw GardenDataError.newerFormat(file.formatVersion)
        }
        return file
    }

    /// The starter data shipped inside the app.
    static func starter(bundle: Bundle = .main) throws -> GardenDataFile {
        guard let url = bundle.url(forResource: "StarterData", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            throw GardenDataError.starterMissing
        }
        return try decode(data)
    }
}

enum GardenDataError: LocalizedError {
    case starterMissing
    case unreadable
    case newerFormat(Int)
    case nothingRecognised

    var errorDescription: String? {
        switch self {
        case .starterMissing:
            return "The starter data is missing from the app."
        case .unreadable:
            return "That file is not Windfall garden data."
        case .newerFormat(let version):
            return "That file was made for a newer version of Windfall (format \(version))."
        case .nothingRecognised:
            return "None of the tables in that file are ones Windfall knows."
        }
    }
}

// MARK: - A row

/// One row, looked up by column heading so the code reads like the sheet.
struct DataRow {

    private let exact: [String: String]
    private let loose: [String: String]

    init(_ fields: [String: String]) {
        var exact: [String: String] = [:]
        var loose: [String: String] = [:]
        for (header, value) in fields {
            exact[DataRow.normalise(header)] = value
            // If two headings loosen to the same thing, the first is kept.
            let key = DataRow.loosen(header)
            if loose[key] == nil { loose[key] = value }
        }
        self.exact = exact
        self.loose = loose
    }

    /// Looks up a value by its column heading.
    ///
    /// An exact match on the heading is tried first, ignoring capitals.
    /// If that fails, units and question marks are ignored, so asking for
    /// "Sowing temperature" finds a column headed "Sowing temperature [C]"
    /// and "Propagator" finds "Propagator?".
    ///
    /// Returns nil for blanks and for spreadsheet error values, which
    /// should never reach the database.
    subscript(_ header: String) -> String? {
        guard let found = exact[DataRow.normalise(header)] ?? loose[DataRow.loosen(header)] else {
            return nil
        }
        let raw = found.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        // #REF!, #N/A and the like.
        if raw.hasPrefix("#") && (raw.hasSuffix("!") || raw.hasSuffix("?") || raw == "#N/A") {
            return nil
        }
        return raw
    }

    func bool(_ header: String) -> Bool {
        BoolParser.value(self[header])
    }

    static func normalise(_ header: String) -> String {
        header.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
    }

    /// A heading with its units, brackets and question marks removed:
    /// "Max Height (m)" becomes "max height".
    static func loosen(_ header: String) -> String {
        var text = normalise(header)
        text = text.replacingOccurrences(of: "\\[[^\\]]*\\]", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\([^)]*\\)", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "?", with: "")
        text = text.replacingOccurrences(of: " +", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - The tables Windfall knows

/// Every kind of table the importer understands.
enum GardenTableKind: String, CaseIterable, Identifiable {
    case permaculture, allotment, toBuy, previouslyOwned
    case companions, fauna, links, flowerShapes, cascades

    var id: String { rawValue }

    /// The table's name in the file, which is the sheet's name in the workbook.
    var tableName: String {
        switch self {
        case .permaculture:    return "Permaculture Garden"
        case .allotment:       return "Allotment Garden"
        case .toBuy:           return "Permaculture Plants to buy"
        case .previouslyOwned: return "Previously Owned Plants"
        case .companions:      return "Companion planting"
        case .fauna:           return "Fauna"
        case .links:           return "Plant-Fauna Links"
        case .flowerShapes:    return "Flower Form Guide"
        case .cascades:        return "Cascades"
        }
    }

    /// A name for people to read.
    var displayName: String {
        switch self {
        case .permaculture:    return "Plants: permaculture garden"
        case .allotment:       return "Plants: allotment"
        case .toBuy:           return "Plants: to buy"
        case .previouslyOwned: return "Plants: previously owned"
        case .companions:      return "Companion planting"
        case .fauna:           return "Wildlife list"
        case .links:           return "Plant and wildlife links"
        case .flowerShapes:    return "Flower shape guide"
        case .cascades:        return "Cascades"
        }
    }

    static let plantKinds: [GardenTableKind] = [.permaculture, .allotment, .toBuy, .previouslyOwned]

    var isPlantTable: Bool { GardenTableKind.plantKinds.contains(self) }

    /// Which garden a plant table belongs to, and what it says about a plant.
    var site: GardenSite { self == .allotment ? .allotment : .permaculture }

    var status: PlantStatus {
        switch self {
        case .toBuy:           return .wanted
        case .previouslyOwned: return .previouslyOwned
        default:               return .growing
        }
    }

    /// Works out which table a set of column headings belongs to. Used
    /// for CSV files, which carry no table name of their own.
    static func guess(fromHeaders headers: [String]) -> GardenTableKind? {
        let have = Set(headers.map { DataRow.normalise($0) })
        func has(_ names: String...) -> Bool { names.allSatisfy { have.contains($0) } }

        if has("plant 1", "plant 2") { return .companions }
        if has("plant", "fauna") { return .links }
        if has("taxon group") || has("recording group") { return .fauna }
        if has("flower shape") { return .flowerShapes }
        if has("cascade type") { return .cascades }
        if has("common name") { return .permaculture }
        // The allotment sheet calls the column "Name" and has "Category".
        if has("name") { return .allotment }
        return nil
    }
}

// MARK: - CSV

/// Reads comma-separated text, the format Numbers and Excel export.
enum CSVReader {

    /// Splits CSV text into rows of cells.
    ///
    /// The rules are the standard ones: cells are separated by commas, a
    /// cell containing a comma or a line break is wrapped in double
    /// quotes, and a double quote inside such a cell is written twice.
    static func rows(from text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var cell = ""
        var insideQuotes = false

        // Windows line endings are two characters. Treat them as one.
        var characters = Array(text.replacingOccurrences(of: "\r\n", with: "\n"))
        // Some programs start the file with an invisible marker.
        if characters.first == "\u{FEFF}" { characters.removeFirst() }

        var index = 0
        while index < characters.count {
            let character = characters[index]
            if insideQuotes {
                if character == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        cell.append("\"")       // a doubled quote is one quote
                        index += 1
                    } else {
                        insideQuotes = false
                    }
                } else {
                    cell.append(character)
                }
            } else if character == "\"" {
                insideQuotes = true
            } else if character == "," {
                row.append(cell)
                cell = ""
            } else if character == "\n" || character == "\r" {
                row.append(cell)
                rows.append(row)
                row = []
                cell = ""
            } else {
                cell.append(character)
            }
            index += 1
        }
        if !cell.isEmpty || !row.isEmpty {
            row.append(cell)
            rows.append(row)
        }
        return rows
    }

    /// Turns CSV text into rows keyed by column heading.
    ///
    /// The heading row is not always the first. Your permaculture sheet
    /// has two rows above it. So the first few rows are searched for one
    /// that Windfall recognises, and that row is taken as the headings.
    static func table(from text: String) -> (headers: [String], rows: [[String: String]])? {
        let all = rows(from: text).filter { row in
            row.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        }
        guard !all.isEmpty else { return nil }

        let headerIndex = all.prefix(6).firstIndex {
            GardenTableKind.guess(fromHeaders: $0) != nil
        } ?? 0
        let headers = all[headerIndex].map { $0.trimmingCharacters(in: .whitespaces) }

        var result: [[String: String]] = []
        for cells in all.dropFirst(headerIndex + 1) {
            var record: [String: String] = [:]
            for (position, header) in headers.enumerated()
            where !header.isEmpty && position < cells.count {
                let value = cells[position].trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { record[header] = value }
            }
            if !record.isEmpty { result.append(record) }
        }
        return (headers.filter { !$0.isEmpty }, result)
    }
}

// MARK: - The importer

/// Copies tables from a data file into the database.
@Observable
@MainActor
final class GardenDataImporter {

    /// What happened, in words for the screen.
    var message = ""
    var lastError: String?

    /// A count of what one import did.
    struct Summary: Equatable {
        var plantsAdded = 0
        var plantsUpdated = 0
        var fauna = 0
        var links = 0
        var flowerShapes = 0
        var cascades = 0
        var companionPairs = 0
        var tablesRead = 0

        var description: String {
            var parts: [String] = []
            if plantsAdded > 0 { parts.append("\(plantsAdded) plants added") }
            if plantsUpdated > 0 { parts.append("\(plantsUpdated) plants updated") }
            if fauna > 0 { parts.append("\(fauna) wildlife species") }
            if links > 0 { parts.append("\(links) plant and wildlife links") }
            if flowerShapes > 0 { parts.append("\(flowerShapes) flower shapes") }
            if cascades > 0 { parts.append("\(cascades) cascades") }
            if companionPairs > 0 { parts.append("\(companionPairs) companion pairs") }
            return parts.isEmpty ? "Nothing to import." : parts.joined(separator: ", ") + "."
        }
    }

    // MARK: Everything in a file

    /// Imports every table in the file that Windfall recognises.
    ///
    /// Plants are MERGED: a plant already in the library is updated, not
    /// duplicated. Reference tables are REPLACED: the wildlife list,
    /// links, flower shapes, cascades and companion pairs are each
    /// cleared and refilled, because the file is where they are written.
    /// A table that is not in the file is left exactly as it was.
    @discardableResult
    func importAll(_ file: GardenDataFile, into context: ModelContext) -> Summary {
        lastError = nil
        var summary = Summary()

        do {
            // Plants first, so the links have plants to join to.
            let plantTables = GardenTableKind.plantKinds.compactMap { kind in
                file.table(named: kind.tableName).map { (kind, $0) }
            }
            if !plantTables.isEmpty {
                let counts = try importPlants(plantTables, into: context)
                summary.plantsAdded = counts.added
                summary.plantsUpdated = counts.updated
                summary.tablesRead += plantTables.count
            }

            if let table = file.table(named: GardenTableKind.fauna.tableName) {
                summary.fauna = try importFauna(table, into: context)
                summary.tablesRead += 1
            }
            if let table = file.table(named: GardenTableKind.links.tableName) {
                summary.links = try importLinks(table, into: context)
                summary.tablesRead += 1
            }
            if let table = file.table(named: GardenTableKind.flowerShapes.tableName) {
                summary.flowerShapes = try importFlowerShapes(table, into: context)
                summary.tablesRead += 1
            }
            if let table = file.table(named: GardenTableKind.cascades.tableName) {
                summary.cascades = try importCascades(table, into: context)
                summary.tablesRead += 1
            }
            if let table = file.table(named: GardenTableKind.companions.tableName) {
                summary.companionPairs = try importCompanions(table, into: context)
                summary.tablesRead += 1
            }

            guard summary.tablesRead > 0 else { throw GardenDataError.nothingRecognised }

            // Join every link to its plant and its animal by name. Done
            // last, because either side may just have been replaced.
            try relink(in: context)
            try context.save()
            message = summary.description

        } catch {
            lastError = error.localizedDescription
            message = ""
        }
        return summary
    }

    // MARK: Plants

    /// Reads the plant tables and merges them into the library.
    ///
    /// Matching is on common name plus variety. A plant on two sheets,
    /// such as garlic, becomes ONE record listing both gardens, which is
    /// the whole point of keeping Plant separate from Planting.
    private func importPlants(_ tables: [(GardenTableKind, GardenTable)],
                              into context: ModelContext) throws -> (added: Int, updated: Int) {
        var index: [String: Plant] = [:]
        for plant in try context.fetch(FetchDescriptor<Plant>()) {
            index[Self.key(plant.commonName, plant.variety)] = plant
        }

        var added = 0
        var alreadyThere = Set<String>()
        for key in index.keys { alreadyThere.insert(key) }
        var touched = Set<String>()

        for (kind, table) in tables {
            for fields in table.rows {
                let row = DataRow(fields)
                guard let name = row["Common Name"] ?? row["Name"] else { continue }
                let key = Self.key(name, row["Variety/Cultivar"])

                let plant: Plant
                if let found = index[key] {
                    plant = found
                } else {
                    plant = Plant(commonName: name)
                    context.insert(plant)
                    index[key] = plant
                    added += 1
                }
                touched.insert(key)
                apply(row, to: plant, kind: kind)
            }
        }
        // "Updated" counts plants that were in the library before this
        // import and appear in the file, each counted once.
        let updated = touched.intersection(alreadyThere).count
        return (added, updated)
    }

    /// Copies one row onto a Plant.
    ///
    /// A value in the file replaces what is there. A blank in the file
    /// leaves the existing value alone, so the fuller permaculture record
    /// is not wiped by the sparser allotment one.
    private func apply(_ row: DataRow, to plant: Plant, kind: GardenTableKind) {

        func fill(_ current: String?, _ new: String?) -> String? {
            new ?? current
        }

        plant.commonName = row["Common Name"] ?? row["Name"] ?? plant.commonName
        plant.latinName   = fill(plant.latinName, row["Latin Name"])
        plant.variety     = fill(plant.variety, row["Variety/Cultivar"])
        plant.group       = fill(plant.group, row["Group"] ?? row["Category"])
        plant.classification = fill(plant.classification,
                                    row["Classification"] ?? row["Annual/perennial"])
        plant.typeLabel   = fill(plant.typeLabel, row["Type"] ?? row["Types"])

        if !plant.sourceSites.contains(kind.site.rawValue) {
            plant.sourceSites.append(kind.site.rawValue)
        }
        if kind.status != .growing { plant.status = kind.status }

        // Growth patterns. Stored as the sheet's own text and read when needed.
        plant.floweringMonthsText  = fill(plant.floweringMonthsText, row["Flowering"])
        plant.stemGrowthMonthsText = fill(plant.stemGrowthMonthsText, row["Stem Growth"])
        plant.foliageMonthsText    = fill(plant.foliageMonthsText, row["Foliage"])
        plant.fruitingMonthsText   = fill(plant.fruitingMonthsText,
                                          row["Fruiting"] ?? row["Fruiting/Harvest"])
        plant.plantType       = fill(plant.plantType, row["Plant Type"])
        plant.foliagePattern  = fill(plant.foliagePattern, row["Foliage Pattern"])
        plant.habits          = fill(plant.habits, row["Habits"])

        // Growth habits
        plant.maxHeightM = fill(plant.maxHeightM, row["Max Height (m)"] ?? row["Height [m]"])
        plant.timeToUltimateHeight = fill(plant.timeToUltimateHeight, row["Time to ultimate height"])
        plant.spreadM      = fill(plant.spreadM, row["Spread [m]"])
        plant.rootDepthM   = fill(plant.rootDepthM, row["Root depth [m]"])
        plant.rootSpreadM  = fill(plant.rootSpreadM, row["Root spread [m]"])
        plant.leafSizeCM   = fill(plant.leafSizeCM, row["Leaf Size [cm]"])
        plant.spacingM     = fill(plant.spacingM, row["Spacing [m]"])
        plant.leafDescription = fill(plant.leafDescription, row["Leaf description"])
        plant.leafColour   = fill(plant.leafColour, row["Leaf Colour"])
        plant.flowerSizeCM = fill(plant.flowerSizeCM, row["Flower size [cm]"])
        plant.flowerForm   = fill(plant.flowerForm, row["Flower Form"])
        plant.fruitSizeCM  = fill(plant.fruitSizeCM, row["Fruit Size [cm]"])
        plant.fruitType    = fill(plant.fruitType, row["Fruit Type"])
        plant.pollinationGroup = fill(plant.pollinationGroup, row["Pollination Group"])
        plant.ploidy       = fill(plant.ploidy, row["Ploidy"])
        plant.layer        = fill(plant.layer, row["Layer"])

        // Permaculture roles. The spellings on the right are the sheet's own.
        plant.isPollinator         = plant.isPollinator || row.bool("Pollinator")
        plant.isRepeller           = plant.isRepeller || row.bool("Repeller")
        plant.isUmbelliferous      = plant.isUmbelliferous || row.bool("Umberlliferous")
        plant.isNitrogenFixer      = plant.isNitrogenFixer || row.bool("Nitrogen Fixers")
        plant.isDynamicAccumulator = plant.isDynamicAccumulator || row.bool("Dynamic Accumalator")
        plant.isGroundCover        = plant.isGroundCover || row.bool("Ground Cover")

        // Sowing. Source text only, because the numeric columns are formulas.
        plant.sowIndoorsMonthsText  = fill(plant.sowIndoorsMonthsText, row["Sow indoors"])
        plant.plantOutMonthsText    = fill(plant.plantOutMonthsText, row["Plant out"])
        plant.sowOutdoorsMonthsText = fill(plant.sowOutdoorsMonthsText, row["Sow outdoors"])
        plant.harvestMonthsText     = fill(plant.harvestMonthsText, row["Harvest"])
        plant.germinationDaysText   = fill(plant.germinationDaysText, row["Germination (days)"])
        plant.sowToCropText         = fill(plant.sowToCropText, row["Sow to crop"])
        plant.sowingDepthMM         = fill(plant.sowingDepthMM, row["Sowing depth [mm]"])
        plant.sowingTemperatureC    = fill(plant.sowingTemperatureC, row["Sowing temperature"])
        plant.sowingPreference      = fill(plant.sowingPreference, row["Sowing preference"])
        plant.needsPropagator = plant.needsPropagator || row.bool("Propagator")
        plant.rootstock       = fill(plant.rootstock, row["Rootstock"])
        plant.propagation     = fill(plant.propagation, row["Propagation"])

        // Constraints
        plant.sunShade   = fill(plant.sunShade, row["Sun/shade"])
        plant.position   = fill(plant.position, row["Position"])
        plant.hardiness  = fill(plant.hardiness, row["Hardiness"])
        plant.soilPH     = fill(plant.soilPH, row["Soil pH"])
        plant.preferredSoilConditions = fill(plant.preferredSoilConditions,
                                             row["Preferred soil conditions"])
        plant.knownPests    = fill(plant.knownPests, row["Pests"])
        plant.knownDiseases = fill(plant.knownDiseases, row["Diseases"])

        // Management
        plant.maintenancePropagationFrequency = fill(plant.maintenancePropagationFrequency,
                                                    row["Maintenance propagation frequency"])
        plant.pruning       = fill(plant.pruning, row["Pruning"])
        plant.pruningGroup  = fill(plant.pruningGroup, row["Pruning Group"])
        plant.culinaryUses  = fill(plant.culinaryUses, row["Culinary uses"])
        plant.medicinalUses = fill(plant.medicinalUses, row["Medicinal uses"])
        plant.toxicityCautions = fill(plant.toxicityCautions, row["Toxicity / cautions"])

        // Ecology
        plant.partnerPlants      = fill(plant.partnerPlants, row["Partner plants"])
        plant.antagonisticPlants = fill(plant.antagonisticPlants, row["Antagonistic Plants"])
        plant.pollinators        = fill(plant.pollinators, row["Pollinators"])

        // Description
        plant.appearance = fill(plant.appearance, row["Appearance"])
        plant.history    = fill(plant.history, row["History"])
        plant.notes      = fill(plant.notes, row["Notes"])

        plant.sourceSheet  = kind.tableName
        plant.lastSyncedAt = .now
    }

    private static func key(_ name: String, _ variety: String?) -> String {
        (name + "|" + (variety ?? "")).lowercased()
    }

    // MARK: Reference tables

    private func importFauna(_ table: GardenTable, into context: ModelContext) throws -> Int {
        for old in try context.fetch(FetchDescriptor<Fauna>()) { context.delete(old) }

        var count = 0
        for fields in table.rows {
            let row = DataRow(fields)
            guard let name = row["Common Name"] else { continue }
            let fauna = Fauna(commonName: name)
            fauna.scientificName     = row["Scientific Name"]
            fauna.taxonGroupRaw      = row["Taxon Group"]?.lowercased()
            fauna.recordingGroup     = row["Recording Group"]
            fauna.tongueLength       = row["Tongue Length"]
            fauna.flightPeriodText   = row["Flight Period"]
            fauna.favouredPlants     = row["Favoured Plants / Habits"]
            fauna.conservationStatus = row["Notes"]
            fauna.genus = fauna.scientificName?
                .split(separator: " ").first.map(String.init)
            fauna.sourceSheet  = table.name
            fauna.lastSyncedAt = .now
            context.insert(fauna)
            count += 1
        }
        return count
    }

    private func importLinks(_ table: GardenTable, into context: ModelContext) throws -> Int {
        for old in try context.fetch(FetchDescriptor<PlantFaunaLink>()) { context.delete(old) }

        var count = 0
        for fields in table.rows {
            let row = DataRow(fields)
            guard let plantName = row["Plant"], let faunaName = row["Fauna"] else { continue }
            let link = PlantFaunaLink()
            link.plantName      = plantName
            link.plantLatinName = row["Plant Latin Name"]
            link.faunaName      = faunaName
            link.faunaLatinName = row["Fauna Latin Name"]
            link.relationship   = FaunaRelationship.parse(row["Relationship"])
            link.flowerShape    = row["Flower Shape: Description"] ?? row["Flower Form"]
            link.seasonText     = row["Season"]
            link.notes          = row["Notes"]
            link.lastSyncedAt   = .now
            context.insert(link)
            count += 1
        }
        return count
    }

    private func importFlowerShapes(_ table: GardenTable, into context: ModelContext) throws -> Int {
        for old in try context.fetch(FetchDescriptor<FlowerShape>()) { context.delete(old) }

        var count = 0
        for fields in table.rows {
            let row = DataRow(fields)
            guard let name = row["Flower Shape"] ?? row["Flower Form"] else { continue }
            let shape = FlowerShape(name: name)
            shape.shapeDescription = row["Shape Description"]
            shape.plainDescription = row["Plain Description"]
            shape.examplePlants    = row["Example Plants"]
            shape.insectsServed    = row["Insects Served"]
            shape.notes            = row["Notes"]
            context.insert(shape)
            count += 1
        }
        return count
    }

    private func importCascades(_ table: GardenTable, into context: ModelContext) throws -> Int {
        for old in try context.fetch(FetchDescriptor<Cascade>()) { context.delete(old) }

        var count = 0
        for fields in table.rows {
            let row = DataRow(fields)
            guard let plantStep = row["Step 1 — Plant"] ?? row["Step 1 - Plant"] else { continue }
            let cascade = Cascade()
            cascade.cascadeType   = row["Cascade Type"] ?? ""
            cascade.plantStep     = plantStep
            cascade.herbivoreStep = row["Step 2 — Herbivore"] ?? row["Step 2 - Herbivore"]
            cascade.predatorStep  = row["Step 3 — Predator"] ?? row["Step 3 - Predator"]
            cascade.notes         = row["Notes"]
            context.insert(cascade)
            count += 1
        }
        return count
    }

    private func importCompanions(_ table: GardenTable, into context: ModelContext) throws -> Int {
        for old in try context.fetch(FetchDescriptor<CompanionPair>()) { context.delete(old) }

        var count = 0
        for fields in table.rows {
            let row = DataRow(fields)
            guard let one = row["Plant 1"] ?? row["Plant One"],
                  let two = row["Plant 2"] ?? row["Plant Two"] else { continue }

            let effect = CompanionEffect.parse(row["+/-"] ?? row["Effect"])
            // Pairs with no mark are most of the sheet and say nothing
            // either way. Leaving them out keeps the database small.
            guard effect != .neutral else { continue }

            let pair = CompanionPair()
            pair.plantOneName = one
            pair.plantTwoName = two
            pair.effect = effect
            // The sheet's heading is "How plant2 impacts plant1".
            pair.mechanism = row["How plant2 impacts plant1"] ?? row["How it impacts"] ?? row["Mechanism"]
            pair.notes = row["Notes"]
            pair.lastSyncedAt = .now
            context.insert(pair)
            count += 1
        }
        return count
    }

    /// Joins each plant and wildlife link to the real records, by name.
    private func relink(in context: ModelContext) throws {
        var plants: [String: Plant] = [:]
        for plant in try context.fetch(FetchDescriptor<Plant>()) {
            // If two plants share a common name, the first is kept.
            let key = plant.commonName.lowercased()
            if plants[key] == nil { plants[key] = plant }
        }
        var fauna: [String: Fauna] = [:]
        for animal in try context.fetch(FetchDescriptor<Fauna>()) {
            fauna[animal.commonName.lowercased()] = animal
        }
        for link in try context.fetch(FetchDescriptor<PlantFaunaLink>()) {
            link.plant = plants[link.plantName.lowercased()]
            link.fauna = fauna[link.faunaName.lowercased()]
        }
    }

    // MARK: Starter data

    /// The setting that records that the starter data has been loaded.
    static let starterLoadedKey = "starterDataLoaded"

    /// Loads the starter data the first time the app runs.
    ///
    /// It only happens when the plant library is empty and it has not
    /// been done before, so it can never overwrite anything of yours.
    /// Returns what was imported, or nil if there was nothing to do.
    @discardableResult
    func loadStarterDataIfNeeded(into context: ModelContext,
                                 defaults: UserDefaults = .standard,
                                 bundle: Bundle = .main) -> Summary? {
        guard !defaults.bool(forKey: Self.starterLoadedKey) else { return nil }
        let plantCount = (try? context.fetchCount(FetchDescriptor<Plant>())) ?? 0
        guard plantCount == 0 else {
            // There is already a library, so there is nothing to start.
            defaults.set(true, forKey: Self.starterLoadedKey)
            return nil
        }
        return loadStarterData(into: context, defaults: defaults, bundle: bundle)
    }

    /// Loads the starter data whether or not it has been loaded before.
    @discardableResult
    func loadStarterData(into context: ModelContext,
                         defaults: UserDefaults = .standard,
                         bundle: Bundle = .main) -> Summary? {
        do {
            let file = try GardenDataFile.starter(bundle: bundle)
            let summary = importAll(file, into: context)
            if lastError == nil { defaults.set(true, forKey: Self.starterLoadedKey) }
            return summary
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
}
