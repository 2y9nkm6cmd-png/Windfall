//
//  ExportService.swift
//  Windfall
//
//  Producing CSV files for iRecord and the Pollinator Monitoring Scheme.
//
//  The critical constraint: iRecord rejects the ENTIRE file if any single
//  row is invalid. So validation happens before a file is written, not
//  after it is uploaded. Records that aren't ready are held back and
//  listed, rather than silently included and taking everything else down
//  with them.
//
//  iRecord's minimum columns are species name, grid reference, date,
//  recorder and stage.
//

import Foundation
import SwiftData

// MARK: - CSV writing

enum CSV {

    /// Escapes a field. Commas, quotes and newlines all need quoting, and
    /// a quote inside a quoted field is doubled.
    static func escape(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "" }
        let needsQuotes = value.contains(",") || value.contains("\"")
            || value.contains("\n") || value.contains("\r")
        guard needsQuotes else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func row(_ fields: [String?]) -> String {
        fields.map(escape).joined(separator: ",")
    }

    static func document(headers: [String], rows: [[String?]]) -> String {
        ([headers.joined(separator: ",")] + rows.map(row)).joined(separator: "\r\n")
    }
}

// MARK: - Result

struct ExportResult {
    let fileURL: URL
    let includedCount: Int
    let excluded: [(description: String, problems: [String])]

    var hasExclusions: Bool { !excluded.isEmpty }
}

// MARK: - Service

@Observable
@MainActor
final class ExportService {

    var lastError: String?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"     // iRecord's preferred form
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    // MARK: Casual records

    /// Wildlife observations, in iRecord's occurrence format.
    ///
    /// Only confirmed identifications are exported. A machine guess is
    /// never sent to a national database — that's the whole reason
    /// `confirmedID` is separate from `provisionalID`.
    func exportObservations(_ observations: [WildlifeObservation]) throws -> ExportResult {

        var rows: [[String?]] = []
        var excluded: [(String, [String])] = []

        for observation in observations where !observation.submittedToIRecord {
            let problems = observation.validationProblems

            guard problems.isEmpty else {
                excluded.append((observation.bestAvailableName ?? "Unnamed record", problems))
                continue
            }

            rows.append([
                observation.confirmedID,
                observation.gridReference,
                Self.dateFormatter.string(from: observation.observedAt),
                observation.recorderName,
                observation.lifeStage,
                observation.quantity.map(String.init),
                observation.sex,
                observation.associatedPlantName.map { "On \($0)" },
                [observation.interaction, observation.notes]
                    .compactMap { $0 }.joined(separator: ". "),
                observation.acceptedScientificName
            ])
        }

        let csv = CSV.document(
            headers: ["Species", "Grid Reference", "Date", "Recorder", "Stage",
                      "Quantity", "Sex", "Habitat", "Comment", "Determiner"],
            rows: rows
        )

        let url = try write(csv, named: "windfall-irecord-\(Self.fileStamp()).csv")
        return ExportResult(fileURL: url, includedCount: rows.count, excluded: excluded)
    }

    // MARK: FIT Counts

    /// Surveys in a form matching the PoMS submission spreadsheet.
    /// Each survey produces one row per insect group.
    func exportFITCounts(_ surveys: [Survey]) throws -> ExportResult {

        var rows: [[String?]] = []
        var excluded: [(String, [String])] = []

        for survey in surveys where survey.scheme == .fitCount && !survey.submitted {
            let problems = survey.validationProblems

            guard problems.isEmpty else {
                excluded.append((
                    "\(survey.targetPlantName ?? "Unnamed") on \(Self.dateFormatter.string(from: survey.startedAt))",
                    problems
                ))
                continue
            }

            // A group with zero seen is still a row — absence is data.
            for group in RecordingScheme.fitCount.groups {
                rows.append([
                    Self.dateFormatter.string(from: survey.startedAt),
                    Self.timeFormatter.string(from: survey.startedAt),
                    survey.gridReference,
                    survey.recorderName,
                    survey.targetPlantName,
                    survey.floralUnitCount.map(String.init),
                    group,
                    String(survey.total(forGroup: group)),
                    survey.temperatureC.map { String(format: "%.1f", $0) },
                    survey.skyCondition?.displayName,
                    survey.isWindy ? "Yes" : "No",
                    survey.durationSeconds.map { String($0 / 60) },
                    survey.notes
                ])
            }
        }

        let csv = CSV.document(
            headers: ["Date", "Start Time", "Grid Reference", "Recorder",
                      "Target Flower", "Floral Units", "Insect Group", "Count",
                      "Temperature C", "Sky", "Windy", "Duration Mins", "Comment"],
            rows: rows
        )

        let url = try write(csv, named: "windfall-fitcounts-\(Self.fileStamp()).csv")
        return ExportResult(fileURL: url, includedCount: rows.count, excluded: excluded)
    }

    // MARK: Earthworm counts

    func exportEarthwormCounts(_ surveys: [Survey]) throws -> ExportResult {

        var rows: [[String?]] = []
        var excluded: [(String, [String])] = []

        for survey in surveys where survey.scheme == .earthwormCount && !survey.submitted {
            let problems = survey.validationProblems
            guard problems.isEmpty else {
                excluded.append(("Pit \(survey.pitNumber ?? 0)", problems))
                continue
            }

            for group in RecordingScheme.earthwormCount.groups {
                rows.append([
                    Self.dateFormatter.string(from: survey.startedAt),
                    survey.gridReference,
                    survey.recorderName,
                    survey.pitNumber.map(String.init),
                    group,
                    String(survey.total(forGroup: group)),
                    survey.soilConditionNotes,
                    survey.notes
                ])
            }
        }

        let csv = CSV.document(
            headers: ["Date", "Grid Reference", "Recorder", "Pit",
                      "Ecological Group", "Count", "Soil Conditions", "Comment"],
            rows: rows
        )

        let url = try write(csv, named: "windfall-earthworms-\(Self.fileStamp()).csv")
        return ExportResult(fileURL: url, includedCount: rows.count, excluded: excluded)
    }

    // MARK: Harvest summary

    /// Not for a scheme — for you. What the garden produced, and where it went.
    func exportHarvests(_ harvests: [Harvest]) throws -> ExportResult {

        let rows: [[String?]] = harvests
            .sorted { $0.date < $1.date }
            .map { harvest in
                [
                    Self.dateFormatter.string(from: harvest.date),
                    harvest.planting?.plant?.commonName,
                    harvest.planting?.plant?.variety,
                    harvest.planting?.successionRound.map(String.init),
                    harvest.planting?.bedNames,
                    harvest.quantity.formatted(),
                    harvest.unit.displayName,
                    harvest.destination?.rawValue,
                    harvest.quality,
                    harvest.notes
                ]
            }

        let csv = CSV.document(
            headers: ["Date", "Plant", "Variety", "Round", "Bed",
                      "Quantity", "Unit", "Destination", "Quality", "Notes"],
            rows: rows
        )

        let url = try write(csv, named: "windfall-harvests-\(Self.fileStamp()).csv")
        return ExportResult(fileURL: url, includedCount: rows.count, excluded: [])
    }

    // MARK: Writing

    private func write(_ contents: String, named filename: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
        let url = directory.appendingPathComponent(filename)

        // BOM so Excel opens it as UTF-8 rather than mangling accents.
        let bom = Data([0xEF, 0xBB, 0xBF])
        var data = bom
        data.append(contents.data(using: .utf8) ?? Data())

        try data.write(to: url, options: .atomic)
        return url
    }

    private static func fileStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }
}

// MARK: - Export screen

import SwiftUI

struct ExportView: View {

    @Query private var observations: [WildlifeObservation]
    @Query private var surveys: [Survey]
    @Query private var harvests: [Harvest]

    @State private var service = ExportService()
    @State private var result: ExportResult?
    @State private var shareURL: URL?

    private var pendingObservations: Int {
        observations.filter { !$0.submittedToIRecord && $0.isReadyForSubmission }.count
    }

    private var pendingFITCounts: Int {
        surveys.filter { $0.scheme == .fitCount && !$0.submitted && $0.isReadyForSubmission }.count
    }

    var body: some View {
        Form {
            Section {
                exportRow("Wildlife sightings",
                          count: pendingObservations,
                          systemImage: "ant") {
                    try service.exportObservations(observations)
                }

                exportRow("FIT Counts",
                          count: pendingFITCounts,
                          systemImage: "camera.macro") {
                    try service.exportFITCounts(surveys)
                }

                exportRow("Earthworm counts",
                          count: surveys.filter { $0.scheme == .earthwormCount && !$0.submitted }.count,
                          systemImage: "chart.bar.doc.horizontal") {
                    try service.exportEarthwormCounts(surveys)
                }
            } header: {
                Text("For recording schemes")
            } footer: {
                Text("Upload the file at irecord.org.uk. If one record is invalid the whole file is rejected, so anything not ready is held back and listed here instead.")
            }

            Section("For you") {
                exportRow("Harvest record",
                          count: harvests.count,
                          systemImage: "basket") {
                    try service.exportHarvests(harvests)
                }
            }

            if let result {
                Section("Last export") {
                    Label("\(result.includedCount) rows written", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)

                    if result.hasExclusions {
                        ForEach(result.excluded, id: \.description) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.description)
                                    .font(.callout)
                                ForEach(item.problems, id: \.self) { problem in
                                    Label(problem, systemImage: "exclamationmark.circle")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }

                    ShareLink(item: result.fileURL) {
                        Label("Share the file", systemImage: "square.and.arrow.up")
                    }
                }
            }

            if let error = service.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Export")
    }

    @ViewBuilder
    private func exportRow(_ title: String, count: Int, systemImage: String,
                           action: @escaping () throws -> ExportResult) -> some View {
        Button {
            do {
                result = try action()
                service.lastError = nil
            } catch {
                service.lastError = error.localizedDescription
            }
        } label: {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Text("\(count)")
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(count == 0)
    }
}
