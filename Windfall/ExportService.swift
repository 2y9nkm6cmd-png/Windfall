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
        fields.map { escape($0) }.joined(separator: ",")
    }

    static func document(headers: [String], rows: [[String?]]) -> String {
        ([headers.joined(separator: ",")] + rows.map { row($0) }).joined(separator: "\r\n")
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
    ///
    /// - `leavingOut`: sightings William chose to keep back this time,
    ///   after the odd-record warnings (`RecordWarnings`). They are listed
    ///   with the others held back, and stay waiting for the next file.
    func exportObservations(_ observations: [WildlifeObservation],
                            leavingOut: Set<UUID> = []) throws -> ExportResult {

        var rows: [[String?]] = []
        var excluded: [(String, [String])] = []

        for observation in observations where !observation.submittedToIRecord {
            if leavingOut.contains(observation.id) {
                excluded.append((observation.bestAvailableName ?? "Unnamed record", ["Left out this time, to check first"]))
                continue
            }
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

// MARK: - What is waiting to be sent

/// How many records are ready to go to a recording scheme and have not
/// been sent yet.
///
/// Kept in one place so that the Export page and the tile that leads to
/// it (on the Settings and tools page) can never give different numbers.
// MARK: - Odd-record warnings

extension WildlifeObservation {

    /// What looks odd about this sighting before it goes to iRecord: out
    /// of season, not on the UK list, dated in the future, or a grid
    /// reference missing or the wrong shape. See RecordWarnings.swift.
    /// Looked up by the accepted scientific name, or the one given.
    func exportWarnings(book: WildlifeReference = .shared, now: Date = .now,
                        calendar: Calendar = .current) -> [RecordWarning] {
        RecordWarnings.warnings(scientificName: acceptedScientificName ?? scientificName,
                                observedAt: observedAt, gridReference: gridReference,
                                book: book, now: now, calendar: calendar)
    }
}

extension ExportWaiting {

    /// The sightings not yet sent that have a warning, with their
    /// warnings, in the order given.
    static func oddSightings(_ observations: [WildlifeObservation], book: WildlifeReference = .shared,
                             now: Date = .now) -> [(sighting: WildlifeObservation, warnings: [RecordWarning])] {
        observations.filter { !$0.submittedToIRecord }.compactMap { sighting in
            let warnings = sighting.exportWarnings(book: book, now: now)
            return warnings.isEmpty ? nil : (sighting, warnings)
        }
    }
}

/// An `enum` with no cases is used here as a labelled box for functions:
/// nothing is ever made from it, the functions are called on its name,
/// as in `ExportWaiting.sightings(...)`.
enum ExportWaiting {

    /// Sightings not yet sent to iRecord that pass every check.
    static func sightings(_ observations: [WildlifeObservation]) -> Int {
        observations.filter { !$0.submittedToIRecord && $0.isReadyForSubmission }.count
    }

    /// FIT Counts not yet sent that pass every check.
    static func fitCounts(_ surveys: [Survey]) -> Int {
        surveys.filter { $0.scheme == .fitCount && !$0.submitted && $0.isReadyForSubmission }.count
    }

    /// Earthworm counts not yet sent.
    static func wormCounts(_ surveys: [Survey]) -> Int {
        surveys.filter { $0.scheme == .earthwormCount && !$0.submitted }.count
    }

    /// All three added together.
    static func altogether(sightings observations: [WildlifeObservation], surveys: [Survey]) -> Int {
        sightings(observations) + fitCounts(surveys) + wormCounts(surveys)
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
    /// True while the question "send the odd ones too?" is showing.
    @State private var isAskingAboutOdd = false

    /// Sightings waiting to go that look odd, with what looks odd.
    private var odd: [(sighting: WildlifeObservation, warnings: [RecordWarning])] {
        ExportWaiting.oddSightings(observations)
    }

    /// Of those, the ones that would otherwise go in the file: ready to
    /// send, and with a warning that does not keep them out anyway.
    private var oddButReady: [WildlifeObservation] {
        odd.filter { $0.sighting.isReadyForSubmission && $0.warnings.contains { !$0.holdsBack } }.map(\.sighting)
    }

    private var pendingObservations: Int { ExportWaiting.sightings(observations) }

    private var pendingFITCounts: Int { ExportWaiting.fitCounts(surveys) }

    private var pendingWormCounts: Int { ExportWaiting.wormCounts(surveys) }

    var body: some View {
        Form {
            if !odd.isEmpty {
                oddSection
            }

            Section {
                // With odd sightings among those ready, the button asks
                // first (the question below) rather than making the file.
                if oddButReady.isEmpty {
                    exportRow("Wildlife sightings",
                              count: pendingObservations,
                              systemImage: "ant") {
                        try service.exportObservations(observations)
                    }
                } else {
                    Button {
                        isAskingAboutOdd = true
                    } label: {
                        HStack {
                            Label("Wildlife sightings", systemImage: "ant")
                            Spacer()
                            Text("\(pendingObservations)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(pendingObservations == 0)
                }

                exportRow("FIT Counts",
                          count: pendingFITCounts,
                          systemImage: "camera.macro") {
                    try service.exportFITCounts(surveys)
                }

                exportRow("Earthworm counts",
                          count: pendingWormCounts,
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
                                    .font(.body)
                                ForEach(item.problems, id: \.self) { problem in
                                    Label(problem, systemImage: "exclamationmark.circle")
                                        .font(.footnote)
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
        .paperScreen()
        // The question, shown when odd sightings are among those ready.
        // `titleVisibility: .visible` shows the title on an iPhone too.
        .confirmationDialog(oddQuestion, isPresented: $isAskingAboutOdd, titleVisibility: .visible) {
            Button("Send all \(pendingObservations)") {
                make { try service.exportObservations(observations) }
            }
            Button("Leave the \(oddButReady.count) out this time") {
                let keptBack = Set(oddButReady.map(\.id))
                make { try service.exportObservations(observations, leavingOut: keptBack) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They are listed under \"Worth a second look\". Left out, they stay waiting for the next file.")
        }
    }

    private var oddQuestion: String {
        let count = oddButReady.count
        return count == 1 ? "1 sighting looks odd. Send it anyway?" : "\(count) sightings look odd. Send them anyway?"
    }

    /// Each sighting that looks odd, with what looks odd about it.
    private var oddSection: some View {
        Section {
            ForEach(odd, id: \.sighting.id) { oddOne in
                VStack(alignment: .leading, spacing: 3) {
                    Text(oddOne.sighting.bestAvailableName ?? "Unnamed record")
                        .font(.body)
                    Text(oddOne.sighting.observedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(oddOne.warnings) { warning in
                        Label(warning.words, systemImage: warning.holdsBack ? "xmark.circle" : "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
        } header: {
            Text("Worth a second look")
        } footer: {
            Text("Seasons come from iNaturalist's confirmed UK records, month by month. Not on the UK list means fewer than 20 confirmed UK records there. These do not stop a record being sent: you decide.")
        }
    }

    /// Makes a file and keeps the result, or the error.
    private func make(_ action: () throws -> ExportResult) {
        do {
            result = try action()
            service.lastError = nil
        } catch {
            service.lastError = error.localizedDescription
        }
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
