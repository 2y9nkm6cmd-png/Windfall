//
//  SheetExtras.swift
//  Windfall
//
//  The spreadsheet columns the app did not read until 21 November 2026
//  (knowledge base docs 151 and 152), and the one-off that brings them
//  into a library already on a device.
//
//  William's answers, 21 November 2026, 20:32 and 20:33:
//
//    Garden Area           into the plant's notes for now: "Garden
//                          area: Lower Orchard". Plants to buy get
//                          "Will go in: Pond". The garden layout reads
//                          its places from these lines once it is built.
//    Date Planted/Grafted  each becomes a planting, dated that day, so
//                          the plant shows as growing and a harvest can
//                          hang off it.
//    Moisture              a box of its own beside Soil conditions.
//    The seed columns      From, Use by, In box and Stock make a seed
//                          packet for each row of seed: the seed
//                          catalogue. "n" in Stock means none left, so
//                          it is used up and on the Seeds to buy list.
//    Next sowing days      the gap for "Sow again" (SowAgain.swift).
//    New or not            ignored.
//
//  Also mended here (card d-plant-notes-more-150, point A): a plant on
//  two rows of the sheets kept only the second row's notes. Both are
//  kept now, the first row's first.
//
//  Loading a spreadsheet file runs this after the plants are in
//  (GardenData.swift). A device that already has its library runs it
//  once at start-up instead (`applyIfNeeded`, called from
//  MainTabView.swift), because the starter data only loads into an
//  empty library. Either way, running it again adds nothing twice.
//
//  A fact changed in the app by hand is never touched.
//
//  ⚠️ CHECK (Claude's choices, card f-sheet-import-152): the words of the
//  garden area lines, "Grafted" in a scion's note, which From words mean
//  saved seed (SeedStock.isSavedSeed).
//

import Foundation
import SwiftData

@MainActor
enum SheetExtras {

    /// Bump when this file learns a new column, so a device's library
    /// is brought up to date again.
    static let version = 1

    /// The setting that records which version a device has had.
    static let doneKey = "sheetExtrasVersion"

    /// What one run did.
    struct Summary: Equatable {
        var seedPackets = 0
        var plantings = 0
        var moisture = 0
        var gaps = 0
        var notes = 0

        var isEmpty: Bool { self == Summary() }
    }

    /// The line at the top of a plant's notes saying where it grows.
    static func areaLine(_ area: String, toBuy: Bool) -> String {
        toBuy ? "Will go in: \(area)" : "Garden area: \(area)"
    }

    /// True for a line written by `areaLine`.
    static func isAreaLine(_ line: Substring) -> Bool {
        line.hasPrefix("Garden area: ") || line.hasPrefix("Will go in: ")
    }

    /// A plant's notes made from the sheet's rows.
    ///
    /// - `area`: the garden area line, if the sheet gives one.
    /// - `rows`: the Notes cell of each of the plant's rows, in order.
    /// - `existing`: the notes on the record now.
    ///
    /// The area line goes first. Then each row's notes once, in the
    /// sheet's order. Then anything already in the notes that is not
    /// one of those, so nothing on the record is lost. Running it again
    /// on its own result changes nothing.
    static func notes(area: String?, rows: [String], existing: String?) -> String? {
        var blocks: [String] = []
        for row in rows {
            let trimmed = row.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !blocks.contains(trimmed) { blocks.append(trimmed) }
        }
        var body = blocks.joined(separator: "\n\n")
        // What is on the record now, without its old area line.
        var lines = (existing ?? "").split(separator: "\n", omittingEmptySubsequences: false)
        while let first = lines.first, isAreaLine(first) || first.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.removeFirst()
        }
        let kept = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !kept.isEmpty, !body.contains(kept) {
            body = body.isEmpty ? kept : body + "\n\n" + kept
        }
        let result = [area, body.isEmpty ? nil : body].compactMap { $0 }.joined(separator: "\n\n")
        return result.isEmpty ? nil : result
    }

    /// A date written "2026-03-01", as the start of that day here.
    static func day(from text: String?, calendar: Calendar = .current) -> Date? {
        guard let text else { return nil }
        let parts = text.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// "2026-03-01" for a day, to match two plantings on the same day.
    private static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    /// The words every planting made from the sheet's dates begins with,
    /// so a backup can tell them from sowings recorded in the app.
    static let plantingNote = "From the spreadsheet"

    // MARK: - The run

    /// Brings the extra columns of a file's plant tables into the library.
    @discardableResult
    static func apply(_ file: GardenDataFile, in context: ModelContext,
                      calendar: Calendar = .current) -> Summary {
        var summary = Summary()

        // The library by the name a row knows a plant by.
        var index: [String: Plant] = [:]
        for plant in (try? context.fetch(FetchDescriptor<Plant>())) ?? [] {
            if let oldName = plant.importedAs, index[oldName] == nil { index[oldName] = plant }
            index[PlantFacts.libraryKey(name: plant.commonName, variety: plant.variety)] = plant
        }

        // What is already there, so nothing is made twice.
        var packetKeys = Set<String>()
        for packet in (try? context.fetch(FetchDescriptor<SeedPacket>())) ?? [] {
            packetKeys.insert(SeedStock.matchKey(plantID: packet.plant?.id, variety: packet.variety,
                                                 supplier: packet.supplier))
        }
        var plantingDays = Set<String>()
        for planting in (try? context.fetch(FetchDescriptor<Planting>())) ?? [] {
            guard let plant = planting.plant, let date = planting.dateSown else { continue }
            plantingDays.insert(plant.id.uuidString + "|" + dayKey(date, calendar: calendar))
        }

        // Each plant's notes and area, gathered over all its rows.
        var rowNotes: [UUID: [String]] = [:]
        var areas: [UUID: String] = [:]
        var touched: [UUID: Plant] = [:]
        var order: [UUID] = []

        for kind in GardenTableKind.plantKinds {
            guard let table = file.table(named: kind.tableName) else { continue }
            for fields in table.rows {
                let row = DataRow(fields)
                guard let written = row["Common Name"] ?? row["Name"] else { continue }
                let tidied = PlantNames.tidy(written)
                let key = PlantFacts.libraryKey(name: tidied, variety: row["Variety/Cultivar"])
                let asWritten = PlantFacts.libraryKey(name: written, variety: row["Variety/Cultivar"])
                guard let plant = index[key] ?? index[asWritten] else { continue }
                if touched[plant.id] == nil { order.append(plant.id) }
                touched[plant.id] = plant

                // Notes and the garden area.
                if let note = row["Notes"] { rowNotes[plant.id, default: []].append(note) }
                // The permaculture sheet's place wins over where a plant
                // to buy will go. That sheet is read first.
                if let area = row["Garden Area"] {
                    if kind == .permaculture {
                        areas[plant.id] = areaLine(area, toBuy: false)
                    } else if kind == .toBuy, areas[plant.id] == nil {
                        areas[plant.id] = areaLine(area, toBuy: true)
                    }
                }

                // Moisture.
                if let moisture = row["Moisture"], !plant.changedByHand.contains("moisture"),
                   plant.moisture != moisture {
                    plant.moisture = moisture
                    summary.moisture += 1
                }

                // The gap for sowing again, in days in the sheet.
                if let gap = row["Next sowing days"], let days = SowAgain.days(in: gap),
                   !plant.changedByHand.contains("sowAgainEvery") {
                    let words = "\(days) days"
                    if plant.sowAgainEvery != words {
                        plant.sowAgainEvery = words
                        summary.gaps += 1
                    }
                }

                // A seed packet for each row of seed or sets.
                if kind == .allotment, let type = row["Types"] ?? row["Type"],
                   ["seeds", "sets"].contains(type.lowercased()),
                   row["From"] != nil || row["Use by"] != nil || row["In box"] != nil || row["In box 03/01/26"] != nil {
                    let variety = row["Variety/Cultivar"]
                    let supplier = row["From"]
                    let match = SeedStock.matchKey(plantID: plant.id, variety: variety, supplier: supplier)
                    if !packetKeys.contains(match) {
                        packetKeys.insert(match)
                        let packet = SeedPacket()
                        packet.plant = plant
                        packet.variety = variety
                        packet.supplier = supplier
                        packet.isHomeSaved = SeedStock.isSavedSeed(from: supplier)
                        packet.packetYear = SeedStock.packetYear(from: supplier)
                        packet.useByDate = day(from: row["Use by"], calendar: calendar)
                        packet.storageLocation = row["In box 03/01/26"] ?? row["In box"]
                        if row["Stock"]?.lowercased() == "n" {
                            SeedLeft.usedUp.apply(to: packet)
                        }
                        packet.notes = "From the spreadsheet. Where it was kept is as on 3 January 2026."
                        context.insert(packet)
                        summary.seedPackets += 1
                    }
                }

                // A planting for each date planted or grafted.
                if kind == .permaculture, let date = day(from: row["Date Planted/Grafted"], calendar: calendar) {
                    let dayMatch = plant.id.uuidString + "|" + dayKey(date, calendar: calendar)
                    if !plantingDays.contains(dayMatch) {
                        plantingDays.insert(dayMatch)
                        let type = (row["Type"] ?? "").lowercased()
                        let planting = Planting()
                        planting.plant = plant
                        planting.dateSown = date
                        planting.status = .growing
                        if type == "seeds" {
                            planting.notes = plantingNote + ": sown on this date."
                        } else {
                            planting.startedFrom = .plant
                            planting.notes = plantingNote + (type == "scion" ? ": grafted on this date." : ": planted on this date.")
                        }
                        context.insert(planting)
                        summary.plantings += 1
                    }
                }
            }
        }

        // Notes, once every row of each plant has been read.
        for id in order {
            guard let plant = touched[id], !plant.changedByHand.contains("notes") else { continue }
            let made = notes(area: areas[id], rows: rowNotes[id] ?? [], existing: plant.notes)
            if made != plant.notes {
                plant.notes = made
                summary.notes += 1
            }
        }

        if !summary.isEmpty { try? context.save() }
        return summary
    }

    /// Runs once on a device for each version of this file.
    @discardableResult
    static func applyIfNeeded(in context: ModelContext, defaults: UserDefaults = .standard,
                              file: GardenDataFile? = nil) -> Summary? {
        guard defaults.integer(forKey: doneKey) < version else { return nil }
        // Nothing to bring in to an empty library: the starter data
        // will do it as it loads.
        guard ((try? context.fetchCount(FetchDescriptor<Plant>())) ?? 0) > 0 else { return nil }
        guard let source = file ?? (try? GardenDataFile.starter()) else { return nil }
        let summary = apply(source, in: context)
        defaults.set(version, forKey: doneKey)
        return summary
    }
}
