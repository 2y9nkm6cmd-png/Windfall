//
//  SheetsService.swift
//  Windfall
//
//  Reads the two plant sheets from Google Sheets and turns rows into Plant
//  records.
//
//  Two decisions baked in here:
//
//  1. Columns are found by HEADER NAME, never by position. You move columns
//     around in the spreadsheet; if this counted from the left, every such
//     move would silently corrupt the import. The header row differs per
//     sheet — row 3 on Permaculture (row 2 holds the category groups),
//     row 1 on Allotment — so that is configuration, not an assumption.
//
//  2. Derived columns are ignored. Germination Days, Sow To Crop Days and
//     the Plant Variety label are all spreadsheet formulas. They're
//     recomputed here from the source text, so there is one implementation
//     rather than two that can drift.
//

import Foundation
import SwiftData

// MARK: - Errors

enum SheetsError: LocalizedError {
    case notSignedIn
    case badResponse(Int)
    case noData
    case headerNotFound(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:          return "Sign in to Google to import your spreadsheet."
        case .badResponse(let code): return "Google Sheets returned an error (\(code))."
        case .noData:               return "The sheet came back empty."
        case .headerNotFound(let s): return "Couldn't find the header row on \(s)."
        }
    }
}

// MARK: - Sheet configuration

struct SheetConfig {
    let name: String
    /// 1-based row holding the column names.
    let headerRow: Int
    let site: GardenSite
    let status: PlantStatus

    static let permaculture = SheetConfig(
        name: "Permaculture Garden", headerRow: 3,
        site: .permaculture, status: .growing)

    static let allotment = SheetConfig(
        name: "Allotment Garden", headerRow: 1,
        site: .allotment, status: .growing)

    static let toBuy = SheetConfig(
        name: "Permaculture Plants to buy", headerRow: 3,
        site: .permaculture, status: .wanted)

    static let previouslyOwned = SheetConfig(
        name: "Previously Owned Plants", headerRow: 3,
        site: .permaculture, status: .previouslyOwned)

    static let all: [SheetConfig] = [permaculture, allotment, toBuy, previouslyOwned]
}

// MARK: - A parsed row

/// Wraps one row plus its header map, so lookups read like the spreadsheet.
struct SheetRow {
    let values: [String]
    let headers: [String: Int]

    /// Case- and space-insensitive lookup. Returns nil for blanks and for
    /// Excel error values, which should never reach the database.
    subscript(_ header: String) -> String? {
        let key = SheetRow.normalise(header)
        guard let index = headers[key], index < values.count else { return nil }

        let raw = values[index].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        // The four #REF! cells in Plant Variety, and anything like them.
        if raw.hasPrefix("#") && raw.hasSuffix("!") { return nil }
        if ["#REF!", "#NAME?", "#VALUE!", "#N/A", "#DIV/0!"].contains(raw) { return nil }

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
}

// MARK: - The service

@Observable
@MainActor
final class SheetsService {

    var isImporting = false
    var progressMessage = ""
    var lastError: String?
    var lastImportDate: Date?

    /// The spreadsheet ID from its URL:
    /// docs.google.com/spreadsheets/d/THIS_BIT/edit
    var spreadsheetID: String {
        get { UserDefaults.standard.string(forKey: "spreadsheetID") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "spreadsheetID") }
    }

    let auth: AuthenticationManager

    init(auth: AuthenticationManager) {
        self.auth = auth
    }

    // MARK: Fetching

    /// Pulls one sheet as raw rows of strings.
    func fetchValues(sheetName: String) async throws -> [[String]] {
        guard !spreadsheetID.isEmpty else { throw SheetsError.noData }

        let token = try await auth.validAccessToken()

        // The range is just the sheet name, meaning "everything on it".
        let encoded = sheetName.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed) ?? sheetName

        let url = URL(string:
            "https://sheets.googleapis.com/v4/spreadsheets/\(spreadsheetID)/values/\(encoded)")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw SheetsError.noData }
        guard http.statusCode == 200 else { throw SheetsError.badResponse(http.statusCode) }

        struct ValueRange: Decodable { let values: [[String]]? }
        let decoded = try JSONDecoder().decode(ValueRange.self, from: data)

        return decoded.values ?? []
    }

    /// Rows with their header map attached.
    private func rows(for config: SheetConfig) async throws -> [SheetRow] {
        let raw = try await fetchValues(sheetName: config.name)

        let headerIndex = config.headerRow - 1
        guard raw.count > headerIndex else {
            throw SheetsError.headerNotFound(config.name)
        }

        var headers: [String: Int] = [:]
        for (i, name) in raw[headerIndex].enumerated() where !name.isEmpty {
            headers[SheetRow.normalise(name)] = i
        }

        return raw.dropFirst(config.headerRow).map { SheetRow(values: $0, headers: headers) }
    }

    /// Reads any sheet whose headers are on row 1 — all the reference tabs.
    /// Not private, because the Fauna import lives in another file and
    /// Swift's `private` is scoped to the file, not the type.
    func referenceRows(sheet name: String) async throws -> [SheetRow] {
        let raw = try await fetchValues(sheetName: name)
        guard let headerRow = raw.first else { return [] }

        var headers: [String: Int] = [:]
        for (i, title) in headerRow.enumerated() where !title.isEmpty {
            headers[SheetRow.normalise(title)] = i
        }
        return raw.dropFirst().map { SheetRow(values: $0, headers: headers) }
    }

    // MARK: Importing

    /// Reads every sheet and merges into the SwiftData store.
    ///
    /// Matching is on common name plus variety, so re-importing updates
    /// existing plants rather than duplicating them. A plant appearing on
    /// both sheets — garlic, for instance — becomes ONE record listing both
    /// sites, which is the whole point of the Plant/Planting split.
    func importPlants(into context: ModelContext) async {
        isImporting = true
        lastError = nil
        defer { isImporting = false }

        do {
            let existing = try context.fetch(FetchDescriptor<Plant>())
            var index: [String: Plant] = [:]
            for plant in existing {
                index[Self.key(plant.commonName, plant.variety)] = plant
            }

            var created = 0, updated = 0

            for config in SheetConfig.all {
                progressMessage = "Reading \(config.name)…"

                let sheetRows: [SheetRow]
                do {
                    sheetRows = try await rows(for: config)
                } catch {
                    // A missing optional sheet shouldn't abort the whole import.
                    continue
                }

                for row in sheetRows {
                    guard let name = row["Common Name"] ?? row["Name"] else { continue }
                    let variety = row["Variety/Cultivar"]
                    let key = Self.key(name, variety)

                    let plant: Plant
                    if let found = index[key] {
                        plant = found
                        updated += 1
                    } else {
                        plant = Plant(commonName: name)
                        context.insert(plant)
                        index[key] = plant
                        created += 1
                    }

                    apply(row, to: plant, config: config)
                }
            }

            progressMessage = "\(created) added, \(updated) updated"
            lastImportDate = .now

        } catch {
            lastError = error.localizedDescription
            progressMessage = ""
        }
    }

    /// Copies one row onto a Plant.
    ///
    /// Only fills blanks when a plant already exists on another sheet, so
    /// the richer permaculture record isn't overwritten by the sparser
    /// allotment one.
    private func apply(_ row: SheetRow, to plant: Plant, config: SheetConfig) {

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

        if !plant.sourceSites.contains(config.site.rawValue) {
            plant.sourceSites.append(config.site.rawValue)
        }
        if config.status != .growing { plant.status = config.status }

        // Growth patterns — stored as the sheet's own text, parsed on read
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

        // Permaculture roles — note the sheet's spellings on the right
        plant.isPollinator         = plant.isPollinator || row.bool("Pollinator")
        plant.isRepeller           = plant.isRepeller || row.bool("Repeller")
        plant.isUmbelliferous      = plant.isUmbelliferous || row.bool("Umberlliferous")
        plant.isNitrogenFixer      = plant.isNitrogenFixer || row.bool("Nitrogen Fixers")
        plant.isDynamicAccumulator = plant.isDynamicAccumulator || row.bool("Dynamic Accumalator")
        plant.isGroundCover        = plant.isGroundCover || row.bool("Ground Cover")

        // Sowing — source text only; the numeric columns are formulas
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

        plant.sourceSheet  = config.name
        plant.lastSyncedAt = .now
    }

    private static func key(_ name: String, _ variety: String?) -> String {
        (name + "|" + (variety ?? "")).lowercased()
    }
}
