//
//  SeedPacketScanner.swift
//  Windfall
//
//  Reading a seed packet with the camera.
//
//  Uses Apple's Vision framework: on-device, free, no key, no network.
//  Text recognition has been good enough for printed packets since iOS 13.
//
//  The governing principle, from the outset of this project: anything
//  extracted automatically is flagged for checking, never accepted
//  silently. Every field carries a confidence and a source, the UI shows
//  which values came from the packet rather than from you, and nothing is
//  written to a Plant record until you confirm it.
//

import Foundation
import Vision
import SwiftUI
import SwiftData
import PhotosUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - An extracted field

/// A value read off a packet, with how confident the extraction was.
struct ExtractedField: Identifiable {
    let id = UUID()
    let label: String
    var value: String
    let confidence: Double
    /// The line of text it came from, so you can see what it was reading.
    let sourceText: String
    var accepted: Bool = true

    var confidenceLabel: String {
        switch confidence {
        case 0.85...:  return "High"
        case 0.6..<0.85: return "Medium"
        default:       return "Low"
        }
    }

    var confidenceColour: Color {
        switch confidence {
        case 0.85...:    return .green
        case 0.6..<0.85: return .orange
        default:         return .red
        }
    }
}

// MARK: - The scanner

@Observable
@MainActor
final class SeedPacketScanner {

    private(set) var recognisedLines: [String] = []
    private(set) var fields: [ExtractedField] = []
    private(set) var isScanning = false
    private(set) var lastError: String?

    // MARK: Recognition

    func scan(imageData: Data) async {
        isScanning = true
        lastError = nil
        defer { isScanning = false }

        #if os(iOS)
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else {
            lastError = "Couldn't read that image."
            return
        }
        #elseif os(macOS)
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            lastError = "Couldn't read that image."
            return
        }
        #endif

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-GB", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])

            let observations = request.results ?? []
            recognisedLines = observations.compactMap {
                $0.topCandidates(1).first?.string
            }

            fields = Self.extract(from: observations)

        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Extraction

    /// Pulls known fields out of the recognised lines.
    ///
    /// Confidence combines Vision's own confidence in reading the
    /// characters with how well the line matches an expected pattern. A
    /// crisply-read line that only loosely resembles a sowing instruction
    /// should not be treated as certain.
    private static func extract(from observations: [VNRecognizedTextObservation]) -> [ExtractedField] {

        var results: [ExtractedField] = []

        let lines: [(text: String, confidence: Float)] = observations.compactMap {
            guard let candidate = $0.topCandidates(1).first else { return nil }
            return (candidate.string, candidate.confidence)
        }

        let joined = lines.map(\.text).joined(separator: "\n")

        // Latin name: two capitalised-then-lowercase words, often italic.
        if let match = joined.range(of: #"\b[A-Z][a-z]{3,}\s+[a-z]{3,}\b"#,
                                    options: .regularExpression) {
            let value = String(joined[match])
            if let line = lines.first(where: { $0.text.contains(value) }) {
                results.append(ExtractedField(
                    label: "Latin name",
                    value: value,
                    confidence: Double(line.confidence) * 0.75,   // pattern is loose
                    sourceText: line.text
                ))
            }
        }

        // Sowing months
        for line in lines {
            let lower = line.text.lowercased()
            guard lower.contains("sow") || lower.contains("plant") else { continue }

            let months = MonthParser.months(in: line.text)
            guard !months.isEmpty else { continue }

            let label = lower.contains("indoor") ? "Sow indoors"
                : lower.contains("out") ? "Sow outdoors"
                : lower.contains("plant out") ? "Plant out"
                : "Sowing time"

            results.append(ExtractedField(
                label: label,
                value: MonthParser.describe(months),
                confidence: Double(line.confidence) * 0.9,
                sourceText: line.text
            ))
        }

        // Harvest months
        for line in lines where line.text.lowercased().contains("harvest") {
            let months = MonthParser.months(in: line.text)
            guard !months.isEmpty else { continue }
            results.append(ExtractedField(
                label: "Harvest",
                value: MonthParser.describe(months),
                confidence: Double(line.confidence) * 0.9,
                sourceText: line.text
            ))
        }

        // Germination time
        for line in lines {
            let lower = line.text.lowercased()
            guard lower.contains("germinat") || lower.contains("days to emerge") else { continue }
            guard let range = RangeParser.range(in: line.text) else { continue }
            results.append(ExtractedField(
                label: "Germination (days)",
                value: range.description,
                confidence: Double(line.confidence) * 0.85,
                sourceText: line.text
            ))
        }

        // Sowing depth
        for line in lines {
            let lower = line.text.lowercased()
            guard lower.contains("depth") || lower.contains("deep") else { continue }
            guard let range = RangeParser.range(in: line.text) else { continue }

            // Packets give depth in cm or mm; normalise to mm.
            let isCM = lower.contains("cm")
            let value = isCM ? range.midpoint * 10 : range.midpoint

            results.append(ExtractedField(
                label: "Sowing depth (mm)",
                value: value.formatted(.number.precision(.fractionLength(0...1))),
                confidence: Double(line.confidence) * 0.8,
                sourceText: line.text
            ))
        }

        // Spacing
        for line in lines {
            let lower = line.text.lowercased()
            guard lower.contains("spac") || lower.contains("thin to") || lower.contains("apart") else { continue }
            guard let range = RangeParser.range(in: line.text) else { continue }
            results.append(ExtractedField(
                label: "Spacing",
                value: range.description + (lower.contains("cm") ? " cm" : ""),
                confidence: Double(line.confidence) * 0.75,
                sourceText: line.text
            ))
        }

        // Use-by / packed-for year
        for line in lines {
            let lower = line.text.lowercased()
            guard lower.contains("sow by") || lower.contains("use by")
                    || lower.contains("packed for") || lower.contains("best before") else { continue }
            if let match = line.text.range(of: #"20\d\d"#, options: .regularExpression) {
                results.append(ExtractedField(
                    label: "Use by",
                    value: String(line.text[match]),
                    confidence: Double(line.confidence) * 0.9,
                    sourceText: line.text
                ))
            }
        }

        // Seed count
        for line in lines {
            let lower = line.text.lowercased()
            guard lower.contains("seed") else { continue }
            guard let match = line.text.range(of: #"\b\d{2,4}\b"#, options: .regularExpression),
                  let count = Int(line.text[match]), count >= 5, count <= 5000 else { continue }
            results.append(ExtractedField(
                label: "Approx. seed count",
                value: String(count),
                confidence: Double(line.confidence) * 0.65,
                sourceText: line.text
            ))
        }

        // Deduplicate by label, keeping the most confident.
        var best: [String: ExtractedField] = [:]
        for field in results {
            if let existing = best[field.label], existing.confidence >= field.confidence { continue }
            best[field.label] = field
        }
        return best.values.sorted { $0.confidence > $1.confidence }
    }

    func setAccepted(_ accepted: Bool, for id: UUID) {
        guard let index = fields.firstIndex(where: { $0.id == id }) else { return }
        fields[index].accepted = accepted
    }

    func updateValue(_ value: String, for id: UUID) {
        guard let index = fields.firstIndex(where: { $0.id == id }) else { return }
        fields[index].value = value
    }

    func reset() {
        fields = []
        recognisedLines = []
        lastError = nil
    }
}

// MARK: - Scanning screen

struct SeedPacketScanView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Plant.commonName)]) private var plants: [Plant]

    @State private var scanner = SeedPacketScanner()
    @State private var pickerItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var plantName = ""
    @State private var matchedPlant: Plant?
    @State private var showingRawText = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let imageData, let image = uiImage(from: imageData) {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label(imageData == nil ? "Choose a photo of the packet" : "Choose a different photo",
                              systemImage: "camera")
                    }

                    if scanner.isScanning {
                        HStack { ProgressView(); Text("Reading the packet…") }
                    }
                } header: {
                    Text("Packet")
                } footer: {
                    Text("Photograph the back of the packet, flat and well lit. Text recognition happens on the device — nothing is sent anywhere.")
                }

                if !scanner.fields.isEmpty {
                    Section {
                        ForEach(scanner.fields) { field in
                            ExtractedFieldRow(field: field, scanner: scanner)
                        }
                    } header: {
                        Text("Found on the packet")
                    } footer: {
                        Text("Everything here was read automatically and needs checking. Untick anything wrong, or tap a value to correct it. Nothing is saved until you press Save.")
                    }

                    Section("Which plant?") {
                        TextField("Plant name", text: $plantName)

                        ForEach(matchingPlants.prefix(5)) { plant in
                            Button {
                                matchedPlant = plant
                                plantName = plant.commonName
                            } label: {
                                HStack {
                                    Text(plant.displayName)
                                    Spacer()
                                    if matchedPlant?.id == plant.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Section {
                        Button {
                            showingRawText.toggle()
                        } label: {
                            Label(showingRawText ? "Hide what was read" : "Show what was read",
                                  systemImage: "text.viewfinder")
                        }

                        if showingRawText {
                            ForEach(scanner.recognisedLines, id: \.self) { line in
                                Text(line)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let error = scanner.lastError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Scan a packet")
            .paperScreen()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(scanner.fields.filter(\.accepted).isEmpty || plantName.isEmpty)
                }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                    imageData = data
                    scanner.reset()
                    await scanner.scan(imageData: data)
                    guessPlantName()
                }
            }
        }
    }

    private var matchingPlants: [Plant] {
        guard !plantName.isEmpty else { return [] }
        let needle = plantName.lowercased()
        return plants.filter { $0.commonName.lowercased().contains(needle) }
    }

    /// The largest text on a packet is usually the crop name.
    private func guessPlantName() {
        guard plantName.isEmpty else { return }
        for line in scanner.recognisedLines.prefix(4) {
            let cleaned = line.trimmingCharacters(in: .whitespaces)
            guard cleaned.count > 2, cleaned.count < 30 else { continue }
            if let match = plants.first(where: {
                cleaned.lowercased().contains($0.commonName.lowercased())
            }) {
                matchedPlant = match
                plantName = match.commonName
                return
            }
            plantName = cleaned
            return
        }
    }

    private func save() {
        let accepted = scanner.fields.filter(\.accepted)

        // Either update an existing plant's blanks, or make a new one.
        let plant = matchedPlant ?? {
            let new = Plant(commonName: plantName)
            new.status = .growing
            context.insert(new)
            return new
        }()

        for field in accepted {
            switch field.label {
            case "Latin name":
                if plant.latinName == nil { plant.latinName = field.value }
            case "Sow indoors":
                if plant.sowIndoorsMonthsText == nil { plant.sowIndoorsMonthsText = field.value }
            case "Sow outdoors", "Sowing time":
                if plant.sowOutdoorsMonthsText == nil { plant.sowOutdoorsMonthsText = field.value }
            case "Plant out":
                if plant.plantOutMonthsText == nil { plant.plantOutMonthsText = field.value }
            case "Harvest":
                if plant.harvestMonthsText == nil { plant.harvestMonthsText = field.value }
            case "Germination (days)":
                if plant.germinationDaysText == nil { plant.germinationDaysText = field.value }
            case "Sowing depth (mm)":
                if plant.sowingDepthMM == nil { plant.sowingDepthMM = field.value }
            case "Spacing":
                if plant.spacingM == nil { plant.spacingM = field.value }
            default:
                break
            }
        }

        // A packet was scanned, so record the packet too.
        let packet = SeedPacket()
        packet.plant = plant
        packet.dateAcquired = .now
        if let useBy = accepted.first(where: { $0.label == "Use by" }),
           let year = Int(useBy.value) {
            packet.packetYear = year
            var components = DateComponents()
            components.year = year
            components.month = 12
            components.day = 31
            packet.useByDate = Calendar.current.date(from: components)
        }
        if let count = accepted.first(where: { $0.label == "Approx. seed count" }) {
            packet.quantityRemaining = Int(count.value)
        }
        packet.notes = "Read from a packet photo on \(Date.now.formatted(date: .abbreviated, time: .omitted)). Values need checking."
        context.insert(packet)

        dismiss()
    }

    private func uiImage(from data: Data) -> Image? {
        #if os(iOS)
        guard let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
        #elseif os(macOS)
        guard let ns = NSImage(data: data) else { return nil }
        return Image(nsImage: ns)
        #endif
    }
}

// MARK: - One extracted field

private struct ExtractedFieldRow: View {

    let field: ExtractedField
    let scanner: SeedPacketScanner

    @State private var editedValue: String = ""
    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button {
                    scanner.setAccepted(!field.accepted, for: field.id)
                } label: {
                    Image(systemName: field.accepted ? "checkmark.square.fill" : "square")
                        .foregroundStyle(field.accepted ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)

                Text(field.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(field.confidenceLabel)
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(field.confidenceColour.opacity(0.18), in: Capsule())
                    .foregroundStyle(field.confidenceColour)
            }

            if isEditing {
                TextField("Value", text: $editedValue)
                    .onSubmit {
                        scanner.updateValue(editedValue, for: field.id)
                        isEditing = false
                    }
            } else {
                Text(field.value)
                    .font(.body)
                    .onTapGesture {
                        editedValue = field.value
                        isEditing = true
                    }
            }

            Text("read from: \(field.sourceText)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
        .opacity(field.accepted ? 1 : 0.5)
    }
}
