//
//  SheetsWriteBack.swift
//  Windfall
//
//  Pushing records from the app into the spreadsheet.
//
//  This is the half of the bidirectional sync that keeps the spreadsheet
//  as a working check on the app. Reference data flows sheet → app;
//  records flow app → sheet.
//
//  Deliberately APPEND-ONLY. Overwriting rows would mean the app could
//  silently destroy something you'd typed there, and the whole point of
//  keeping the spreadsheet is that it's the copy you can trust when the
//  app is wrong. Each record carries an ID, so re-running skips what's
//  already up there rather than duplicating it.
//

import Foundation
import SwiftData

extension SheetsService {

    // MARK: Appending

    /// Adds rows to the end of a sheet. Google works out where the end is.
    private func append(rows: [[String]], to sheetName: String) async throws {
        guard !rows.isEmpty else { return }

        let token = try await auth.validAccessToken()
        let encoded = sheetName.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed) ?? sheetName

        var components = URLComponents(string:
            "https://sheets.googleapis.com/v4/spreadsheets/\(spreadsheetID)/values/\(encoded):append")!
        components.queryItems = [
            URLQueryItem(name: "valueInputOption", value: "USER_ENTERED"),
            URLQueryItem(name: "insertDataOption", value: "INSERT_ROWS")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["values": rows]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw SheetsError.badResponse(code)
        }
    }

    /// IDs already present in the first column of a sheet, so nothing
    /// gets written twice.
    private func existingIDs(in sheetName: String) async throws -> Set<String> {
        let rows = try await fetchValues(sheetName: sheetName)
        return Set(rows.compactMap { $0.first }.filter { !$0.isEmpty })
    }

    // MARK: The push

    /// Sends everything not yet in the spreadsheet.
    func pushRecords(from context: ModelContext) async {
        isImporting = true
        lastError = nil
        defer { isImporting = false }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        do {
            var written = 0

            // Plantings
            progressMessage = "Writing sowings…"
            let plantingIDs = try await existingIDs(in: "Plantings")
            let plantings = try context.fetch(FetchDescriptor<Planting>())

            let plantingRows = plantings.compactMap { planting -> [String]? in
                let id = Self.shortID(planting.id, prefix: "P")
                guard !plantingIDs.contains(id) else { return nil }
                let sections = (planting.sections ?? []).sorted { $0.displayOrder < $1.displayOrder }
                return [
                    id,
                    planting.plant?.commonName ?? "",
                    planting.plant?.latinName ?? "",
                    sections.first?.bed?.site.displayName ?? "",
                    sections.first?.bed?.name ?? "",
                    sections.map(\.label).joined(separator: ", "),
                    planting.successionRound.map(String.init) ?? "",
                    planting.sowingLocation?.rawValue ?? "",
                    planting.dateSown.map(formatter.string) ?? "",
                    planting.dateGerminated.map(formatter.string) ?? "",
                    planting.datePlantedOut.map(formatter.string) ?? "",
                    planting.quantitySown.map(String.init) ?? "",
                    planting.quantitySurvived.map(String.init) ?? "",
                    planting.status.rawValue,
                    "",
                    planting.notes ?? ""
                ]
            }

            try await append(rows: plantingRows, to: "Plantings")
            written += plantingRows.count

            // Harvests
            progressMessage = "Writing harvests…"
            let harvestIDs = try await existingIDs(in: "Harvests")
            let harvests = try context.fetch(FetchDescriptor<Harvest>())

            let harvestRows = harvests.compactMap { harvest -> [String]? in
                let id = Self.shortID(harvest.id, prefix: "H")
                guard !harvestIDs.contains(id) else { return nil }
                return [
                    id,
                    harvest.planting.map { Self.shortID($0.id, prefix: "P") } ?? "",
                    harvest.planting?.plant?.commonName ?? "",
                    formatter.string(from: harvest.date),
                    harvest.quantity.formatted(),
                    harvest.unit.displayName,
                    harvest.destination?.rawValue ?? "",
                    harvest.quality ?? "",
                    harvest.notes ?? ""
                ]
            }

            try await append(rows: harvestRows, to: "Harvests")
            written += harvestRows.count

            // FIT Counts
            progressMessage = "Writing surveys…"
            let countIDs = try await existingIDs(in: "FIT Counts")
            let surveys = try context.fetch(FetchDescriptor<Survey>())

            let fitCounts = surveys.filter { $0.scheme == .fitCount }
            let countRows = fitCounts.compactMap { survey -> [String]? in
                let id = Self.shortID(survey.id, prefix: "FC")
                guard !countIDs.contains(id) else { return nil }
                return [
                    id,
                    formatter.string(from: survey.startedAt),
                    timeFormatter.string(from: survey.startedAt),
                    survey.durationSeconds.map { String($0 / 60) } ?? "10",
                    survey.targetPlantName ?? "",
                    "",
                    survey.isSchemeTargetFlower ? "Yes" : "No",
                    survey.floralUnitCount.map(String.init) ?? "",
                    survey.site?.displayName ?? "",
                    survey.bed?.name ?? "",
                    survey.latitude.map { String($0) } ?? "",
                    survey.longitude.map { String($0) } ?? "",
                    survey.gridReference ?? "",
                    survey.temperatureC.map { String(format: "%.1f", $0) } ?? "",
                    survey.skyCondition?.displayName ?? "",
                    survey.isDry ? "Yes" : "No",
                    survey.isWindy ? "Yes" : "No",
                    survey.recorderName ?? "",
                    String(survey.totalCount),
                    survey.submitted ? "Yes" : "No",
                    survey.notes ?? ""
                ]
            }

            try await append(rows: countRows, to: "FIT Counts")
            written += countRows.count

            // Tallies — one row per group, for counts newly written
            let newCountIDs = Set(countRows.compactMap { $0.first })
            var tallyRows: [[String]] = []
            for survey in fitCounts {
                let id = Self.shortID(survey.id, prefix: "FC")
                guard newCountIDs.contains(id) else { continue }
                for tally in survey.tallies ?? [] {
                    tallyRows.append([id, tally.groupName, String(tally.quantity), tally.notes ?? ""])
                }
            }
            try await append(rows: tallyRows, to: "FIT Tallies")
            written += tallyRows.count

            // Sightings
            progressMessage = "Writing sightings…"
            let observationIDs = try await existingIDs(in: "Wildlife Observations")
            let observations = try context.fetch(FetchDescriptor<WildlifeObservation>())

            let observationRows = observations.compactMap { observation -> [String]? in
                let id = Self.shortID(observation.id, prefix: "OB")
                guard !observationIDs.contains(id) else { return nil }
                return [
                    id,
                    formatter.string(from: observation.observedAt),
                    timeFormatter.string(from: observation.observedAt),
                    observation.commonName ?? "",
                    observation.scientificName ?? "",
                    observation.acceptedScientificName ?? "",
                    observation.family ?? "",
                    observation.schemeGroupName ?? "",
                    observation.quantity.map(String.init) ?? "",
                    observation.lifeStage ?? "",
                    observation.associatedPlantName ?? "",
                    observation.interaction ?? "",
                    observation.latitude.map { String($0) } ?? "",
                    observation.longitude.map { String($0) } ?? "",
                    observation.gridReference ?? "",
                    String(observation.gridPrecisionMetres),
                    observation.provisionalConfidence?.displayName ?? "",
                    observation.provisionalSource?.rawValue ?? "",
                    observation.isConfirmed ? "Yes" : "No",
                    observation.recorderName ?? "",
                    "",
                    observation.survey.map { Self.shortID($0.id, prefix: "FC") } ?? "",
                    observation.submittedToIRecord ? "Yes" : "No",
                    observation.notes ?? ""
                ]
            }

            try await append(rows: observationRows, to: "Wildlife Observations")
            written += observationRows.count

            progressMessage = written == 0
                ? "Spreadsheet already up to date"
                : "\(written) rows written to the spreadsheet"
            lastImportDate = .now

        } catch {
            lastError = error.localizedDescription
            progressMessage = ""
        }
    }

    /// A short, stable, readable ID — "P4F2A9C1" rather than a full UUID.
    /// Stable because it's derived from the record's own id, so re-running
    /// produces the same string and duplicate detection works.
    static func shortID(_ uuid: UUID, prefix: String) -> String {
        prefix + uuid.uuidString.prefix(8)
    }
}

// MARK: - Sync screen

import SwiftUI

struct SyncView: View {

    @Environment(\.modelContext) private var context
    @Environment(AuthenticationManager.self) private var auth

    @State private var service: SheetsService?

    var body: some View {
        Form {
            Section {
                if let service {
                    Button {
                        Task { await service.importPlants(into: context) }
                    } label: {
                        Label("Read plants from the sheet", systemImage: "arrow.down.doc")
                    }

                    Button {
                        Task { await service.importReferenceData(into: context) }
                    } label: {
                        Label("Read reference data", systemImage: "books.vertical")
                    }

                    Button {
                        Task { await service.pushRecords(from: context) }
                    } label: {
                        Label("Write records to the sheet", systemImage: "arrow.up.doc")
                    }
                }
            } header: {
                Text("Google Sheets")
            } footer: {
                Text("Reference data flows from the sheet into the app. Your records flow the other way. Writing is append-only, so nothing you've typed into the spreadsheet can be overwritten.")
            }

            if let service, service.isImporting {
                Section {
                    HStack {
                        ProgressView()
                        Text(service.progressMessage)
                    }
                }
            }

            if let service, !service.progressMessage.isEmpty, !service.isImporting {
                Section {
                    Label(service.progressMessage, systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            }

            if let error = service?.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("Sync")
        .task {
            if service == nil { service = SheetsService(auth: auth) }
        }
    }
}
