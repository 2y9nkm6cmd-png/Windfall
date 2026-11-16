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
//  Since 15 November 2026 this file does only half the job. It turns a
//  photo into lines of words, each with its place on the photo, and
//  draws the sheet. Deciding what the words mean is PacketReading.swift,
//  which needs no photo and so can be tested without a Mac. The sheet
//  also takes two photos now, the back and the front, and reads them
//  into one list.
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

/// A value read off a packet, as one row of the sheet: what
/// PacketReading found, and whether you have ticked or corrected it.
struct ExtractedField: Identifiable {
    let id = UUID()
    /// Which thing it is: the variety, the sowing months and so on.
    let field: PacketField
    var value: String
    /// The value as it was first read. Kept so that a correction made
    /// by hand is not lost when the packet's other side is read.
    let readValue: String
    let confidence: Double
    /// The words it came from, so you can see what it was reading.
    let sourceText: String
    /// Which side of the packet those words were on.
    let side: PacketSide
    var accepted: Bool = true

    /// `init` is the code that makes a new one. This one is handed a
    /// finding and copies its parts across.
    init(_ packetFinding: PacketFinding) {
        field = packetFinding.field
        value = packetFinding.value
        readValue = packetFinding.value
        confidence = packetFinding.confidence
        sourceText = packetFinding.sourceText
        side = packetFinding.side
    }

    var label: String { field.label }

    /// The row turned back into a finding, with any correction in it.
    var asFinding: PacketFinding {
        PacketFinding(field: field, value: value, confidence: confidence, sourceText: sourceText, side: side)
    }

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

    /// The lines read from each side that has been photographed.
    /// `[PacketSide: [PacketLine]]` is a "dictionary": a list you look
    /// things up in by a key, here the side.
    private(set) var linesBySide: [PacketSide: [PacketLine]] = [:]
    /// Any barcode found on each side, read as a barcode.
    private var barcodesBySide: [PacketSide: [String]] = [:]
    /// The rows of the sheet. The plant's name is not among them: it
    /// goes in the "Which plant?" box (see `nameFound`).
    private(set) var fields: [ExtractedField] = []
    /// The plant's name, if one was found.
    private(set) var nameFound: PacketFinding?
    private(set) var isScanning = false
    private(set) var lastError: String?

    /// The common names in the plant library, handed in by the sheet.
    /// A line of the packet that names one of them is taken as its name.
    var knownPlants: [String] = []

    /// Every line read, the front's first.
    var linesRead: [PacketLine] {
        PacketSide.allCases.flatMap { linesBySide[$0] ?? [] }
    }

    // MARK: Recognition

    /// Reads one side of the packet from a photo, and works the rows
    /// out again from everything read so far.
    func scan(imageData: Data, side: PacketSide) async {
        isScanning = true
        lastError = nil
        defer { isScanning = false }

        #if os(iOS)
        guard UIImage(data: imageData) != nil else {
            lastError = "Couldn't read that image."
            return
        }
        #elseif os(macOS)
        guard NSImage(data: imageData) != nil else {
            lastError = "Couldn't read that image."
            return
        }
        #endif

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-GB", "en-US"]

        // A second question for Vision: is there a barcode? Reading
        // the bars is surer than reading the small digits under them.
        let barcodeRequest = VNDetectBarcodesRequest()

        // Vision is given the photo's file, not just its pixels. A phone
        // stores a portrait photo on its side with a note saying which
        // way to turn it. Given the file, Vision reads the note and
        // turns the picture upright before looking for words. Given
        // only the pixels (as it was until 14 November 2026) it read a
        // portrait photo sideways.
        let handler = VNImageRequestHandler(data: imageData, options: [:])

        do {
            try handler.perform([request])

            let observations = request.results ?? []
            linesBySide[side] = observations.compactMap { (lineSeen) -> PacketLine? in
                guard let candidate = lineSeen.topCandidates(1).first else { return nil }
                // Where the line sits, as shares of the photo from 0 to
                // 1. Vision measures up from the bottom, and
                // PacketReading wants down from the top, hence `1 -`.
                let box = lineSeen.boundingBox
                return PacketLine(text: candidate.string,
                                  confidence: Double(candidate.confidence),
                                  left: Double(box.minX),
                                  right: Double(box.maxX),
                                  top: Double(1 - box.maxY),
                                  height: Double(box.height),
                                  side: side)
            }

            // `try?` means "if this fails, carry on without it". A
            // packet with no barcode found is still a packet read.
            try? handler.perform([barcodeRequest])
            barcodesBySide[side] = (barcodeRequest.results ?? []).compactMap(\.payloadStringValue)

            rework()

        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Extraction

    /// Works the rows out again from every line read so far, on both
    /// sides. What the words mean is decided in PacketReading.swift.
    ///
    /// A row you have unticked or corrected keeps that, so long as the
    /// packet still reads the same for it. Without this, photographing
    /// the front after correcting the back would undo the corrections.
    private func rework() {
        let barcodes = PacketSide.allCases.flatMap { barcodesBySide[$0] ?? [] }
        let findings = PacketReading.read(linesRead, knownPlants: knownPlants, barcodes: barcodes)
        nameFound = findings.first { $0.field == .plantName }

        let earlier = fields
        fields = findings.filter { $0.field != .plantName }.map { finding in
            var row = ExtractedField(finding)
            if let was = earlier.first(where: { $0.field == finding.field && $0.readValue == finding.value }) {
                row.value = was.value
                row.accepted = was.accepted
            }
            return row
        }
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
        nameFound = nil
        linesBySide = [:]
        barcodesBySide = [:]
        lastError = nil
    }
}

// MARK: - Scanning screen

struct SeedPacketScanView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Plant.commonName)]) private var plants: [Plant]

    /// How the screen should begin, if it has been told. The Seed page
    /// opens it with `.camera` or `.library`, so the camera or the
    /// Photos library comes up without a second tap. The tile on the
    /// Gardens page says nothing, and the screen waits to be asked.
    private let startsWith: SeedPacketStart?

    /// `= nil` gives a value to fall back on, so plain
    /// `SeedPacketScanView()` still works where it was already used.
    init(startsWith: SeedPacketStart? = nil) {
        self.startsWith = startsWith
    }

    @State private var scanner = SeedPacketScanner()
    @State private var pickerItem: PhotosPickerItem?
    /// The photo taken or chosen of each side, so it can be shown.
    @State private var photos: [PacketSide: Data] = [:]
    /// Which side the next photo is of. Set by whichever button was
    /// tapped, just before the camera or the library opens.
    @State private var sideInHand: PacketSide = .back
    /// True while the camera is open, on an iPhone or iPad.
    @State private var isTakingPhoto = false
    /// True while the Photos library is open.
    @State private var isChoosingPhoto = false
    /// True once `startsWith` has been acted on, so that it happens
    /// once and not every time the screen comes back into view.
    @State private var hasBegun = false
    @State private var plantName = ""
    /// The name the reader last put in the box. If the box still holds
    /// it, the reader may change it. A name you typed is left alone.
    @State private var nameFilledIn = ""
    @State private var matchedPlant: Plant?
    /// True when you have asked for a new plant to be made on Save.
    @State private var addsNewPlant = false
    @State private var showingRawText = false

    var body: some View {
        NavigationStack {
            Form {
                // The back first: it holds the sowing details.
                sideSection(.back)
                sideSection(.front)

                if scanner.isScanning {
                    Section {
                        HStack { ProgressView(); Text("Reading the packet…") }
                    }
                } else if !photos.isEmpty, !hasFindings, scanner.lastError == nil {
                    // A photo was read and nothing useful came of
                    // it. Before 15 November 2026 the screen showed
                    // nothing at all here, which looked like a
                    // fault.
                    Section {
                        Label(scanner.linesRead.isEmpty
                              ? "No words could be read from that photo."
                              : "Words were read, but none looked like sowing or packet details.",
                              systemImage: "questionmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }

                if hasFindings {
                    Section {
                        TextField("Plant name", text: $plantName)

                        ForEach(matchingPlants.prefix(6)) { plant in
                            Button {
                                matchedPlant = plant
                                plantName = plant.commonName
                                addsNewPlant = false
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

                        // Making a new plant is offered, never done
                        // unasked. Before 15 November 2026 a name that
                        // matched nothing quietly became a new plant
                        // on Save, which is how a plant called "PRICE"
                        // nearly joined the library.
                        if !trimmedName.isEmpty {
                            Button {
                                matchedPlant = nil
                                addsNewPlant.toggle()
                            } label: {
                                HStack {
                                    Text("Add \(newPlantTitle) as a new plant")
                                    Spacer()
                                    if addsNewPlant, matchedPlant == nil {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Which plant?")
                    } footer: {
                        Text(whichPlantNote)
                    }

                    if !scanner.fields.isEmpty {
                        Section {
                            ForEach(scanner.fields) { field in
                                ExtractedFieldRow(field: field, scanner: scanner)
                            }
                        } header: {
                            Text("Found on the packet")
                        } footer: {
                            Text("Everything here was read automatically and needs checking. Untick anything wrong, or tap a value to correct it. Nothing is saved until you press Save. On a plant you already have, only its empty boxes are filled.")
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
                            ForEach(PacketSide.allCases) { side in
                                let texts = (scanner.linesBySide[side] ?? []).map(\.text)
                                if !texts.isEmpty {
                                    Text("\(side.title) of the packet")
                                        .font(.footnote.weight(.semibold))
                                    // `enumerated` numbers the lines, and
                                    // `id: \.offset` tells them apart by
                                    // that number, so two lines with the
                                    // same words are still two rows.
                                    ForEach(Array(texts.enumerated()), id: \.offset) { numbered in
                                        Text(numbered.element)
                                            .font(.footnote.monospaced())
                                            .foregroundStyle(.secondary)
                                    }
                                }
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
                        .disabled(!canSave)
                }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                // Noted now, in case another button is tapped while
                // the photo is still being fetched.
                let side = sideInHand
                Task {
                    let data = try? await item.loadTransferable(type: Data.self)
                    // Emptied, so that choosing the same photo again
                    // (for the other side, say) still counts as a change.
                    pickerItem = nil
                    guard let data else { return }
                    await read(data, side: side)
                }
            }
            // A plant ticked in the list stays ticked only while the
            // box still holds its name.
            .onChange(of: plantName) { _, typed in
                if let matchedPlant, matchedPlant.commonName != typed {
                    self.matchedPlant = nil
                }
            }
            // The camera. A picture of a packet is not copied to the
            // Photos library, whatever the switch in Settings says.
            .cameraPhoto(isPresented: $isTakingPhoto, savesToPhotos: false) { data in
                let side = sideInHand
                Task { await read(data, side: side) }
            }
            // The Photos library. What is picked lands in `pickerItem`,
            // and the `.onChange(of: pickerItem)` above reads it, just
            // as it did when the button was a `PhotosPicker`.
            .photosPicker(isPresented: $isChoosingPhoto, selection: $pickerItem, matching: .images)
            // `.task` runs when the screen appears.
            .task { await begin() }
        }
    }

    /// The part of the sheet for one side of the packet: its photo once
    /// there is one, and a button for each way of giving one.
    ///
    /// `@ViewBuilder` lets a function hand back a piece of screen made
    /// of several parts, some of them behind an `if`.
    @ViewBuilder
    private func sideSection(_ side: PacketSide) -> some View {
        Section {
            if let data = photos[side], let image = uiImage(from: data) {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Only on a device with a camera. See CameraPhoto.swift.
            if CameraPhoto.isAvailable {
                Button {
                    sideInHand = side
                    isTakingPhoto = true
                } label: {
                    Label(photos[side] == nil ? "Photograph \(side.words)" : "Photograph \(side.words) again",
                          systemImage: "camera")
                }
            }

            // A plain button that sets a true-or-false, with the
            // library added lower down by `.photosPicker(isPresented:)`.
            // The reason: the Seed page needs to open the library
            // without this button being tapped, and only that form can
            // be opened from code.
            Button {
                sideInHand = side
                isChoosingPhoto = true
            } label: {
                Label(photos[side] == nil ? "Choose a photo of \(side.words)" : "Choose a different photo of \(side.words)",
                      systemImage: "photo.on.rectangle")
            }
        } header: {
            Text("\(side.title) of the packet")
        } footer: {
            Text(side == .back
                 ? "Flat and well lit. The back holds the sowing details. The words are read on the device and nothing is sent anywhere."
                 : "Not needed, but the front often shows the name and variety more plainly. Both sides are read into one list.")
        }
    }

    /// True once a photo has given a name or at least one row.
    private var hasFindings: Bool {
        !scanner.fields.isEmpty || scanner.nameFound != nil
    }

    /// The name in the box, without spaces at its ends.
    private var trimmedName: String {
        plantName.trimmingCharacters(in: .whitespaces)
    }

    /// How a new plant would be called in the offer to add it:
    /// "Linaria" and its variety "Fairy Bouquet Mixed" together.
    private var newPlantTitle: String {
        let variety = scanner.fields.first { $0.field == .variety && $0.accepted }?.value ?? ""
        return variety.isEmpty ? trimmedName : "\(trimmedName) \u{2018}\(variety)\u{2019}"
    }

    /// The line under "Which plant?", which says where things stand.
    private var whichPlantNote: String {
        if trimmedName.isEmpty { return "No name could be read. Type the plant's name." }
        if let matchedPlant { return "The packet will be kept under \(matchedPlant.displayName), and its empty boxes filled." }
        if addsNewPlant { return "A new plant will be made for it when you press Save." }
        if matchingPlants.isEmpty {
            return "\(trimmedName) is not in your plant library. Tick the line above to add it, or type another name."
        }
        return "Tick the plant this packet is for, or add it as a new one."
    }

    /// Save needs a name and a choice: one of your plants, or a new one.
    private var canSave: Bool {
        !trimmedName.isEmpty && (matchedPlant != nil || addsNewPlant)
    }

    /// Opens the camera or the Photos library straight away, if the
    /// screen was asked to start with one. The photo is of the back.
    private func begin() async {
        guard !hasBegun else { return }
        hasBegun = true

        // A checking aid: read a photo from a file, with no tap.
        if let demo = DemoGarden.packetPhoto {
            await read(demo, side: .back)
            return
        }
        guard let startsWith, startsWith.readsAPhoto else { return }

        // A short wait, four tenths of a second. This screen is itself
        // a sheet sliding up, and iOS will not open a second thing on
        // top while the first is still moving. `try?` means "if the
        // wait is cut short, carry on anyway".
        try? await Task.sleep(for: .milliseconds(400))

        sideInHand = .back
        if startsWith == .camera, CameraPhoto.isAvailable {
            isTakingPhoto = true
        } else {
            // Asked for the library, or asked for a camera this device
            // does not have.
            isChoosingPhoto = true
        }
    }

    /// Your plants that the name in the box could mean, the likeliest
    /// first. "Carrot" finds "Carrots", and every variety of it you
    /// have. The matching itself is in PacketReading.swift.
    private var matchingPlants: [Plant] {
        guard !trimmedName.isEmpty else { return [] }
        let names = PacketReading.libraryNames(matching: trimmedName, among: plants.map(\.commonName))
        return names.flatMap { name in plants.filter { $0.commonName == name } }
    }

    /// Shows a photo of one side of a packet and reads it. Both ways
    /// in, the Photos library and the camera, end here, so they behave
    /// alike.
    private func read(_ data: Data, side: PacketSide) async {
        photos[side] = data
        scanner.knownPlants = plants.map(\.commonName)
        await scanner.scan(imageData: data, side: side)
        suggestPlant()
    }

    /// Puts the name read from the packet in the box, and ticks the
    /// plant of yours it means when there is no doubt which.
    ///
    /// There is no doubt when you have a plant of that name with the
    /// packet's variety, or just one plant of that name and it has no
    /// variety of its own. Otherwise the choice is left to you: a
    /// packet of "Nantes 2" is not your "Autumn King".
    private func suggestPlant() {
        guard let found = scanner.nameFound?.value, !found.isEmpty else { return }
        // A name typed by hand is left alone.
        guard plantName.isEmpty || plantName == nameFilledIn else { return }
        plantName = found
        nameFilledIn = found
        addsNewPlant = false

        let sameName = plants.filter { $0.commonName == found }
        let variety = (scanner.fields.first { $0.field == .variety }?.value ?? "").lowercased()
        if !variety.isEmpty, let sameVariety = sameName.first(where: { ($0.variety ?? "").lowercased() == variety }) {
            matchedPlant = sameVariety
        } else if sameName.count == 1, (sameName[0].variety ?? "").isEmpty {
            matchedPlant = sameName[0]
        } else {
            matchedPlant = nil
        }
    }

    private func save() {
        let accepted = scanner.fields.filter(\.accepted)

        // Either one of your plants, or a new one you asked for.
        let plant: Plant
        let isNew: Bool
        if let matchedPlant {
            plant = matchedPlant
            isNew = false
        } else {
            plant = Plant(commonName: trimmedName)
            plant.status = .growing
            // "Seeds" is what the library calls a plant held as seed.
            plant.typeLabel = "Seeds"
            context.insert(plant)
            isNew = true
        }

        // Each ticked row that has a box in the plant's record fills
        // it, if the box is empty. `recordText` turns what the sheet
        // shows into the library's way of writing it ("15 cm" becomes
        // 0.15, in metres). `PlantFacts.write` notes the box as changed
        // by hand, so loading the spreadsheet file later leaves it be.
        for row in accepted {
            guard let key = row.field.plantKey,
                  let text = PacketReading.recordText(for: row.field, shown: row.value) else { continue }
            // The variety names a new plant. A plant you already have
            // keeps its own, and the packet records the packet's.
            if row.field == .variety, !isNew { continue }
            if PlantGaps.isEmpty(key, in: plant) {
                PlantFacts.write(text, forKey: key, to: plant)
            }
        }

        // A packet was scanned, so record the packet too.
        let packet = SeedPacket()
        packet.plant = plant
        packet.dateAcquired = .now
        packet.variety = accepted.first { $0.field == .variety }?.value
        packet.supplier = accepted.first { $0.field == .supplier }?.value
        if let sowBy = accepted.first(where: { $0.field == .useBy }),
           let date = PacketReading.sowByYearAndMonth(sowBy.value) {
            packet.packetYear = date.year
            packet.useByDate = PacketReading.lastDay(ofMonth: date.month, year: date.year)
        }
        if let count = accepted.first(where: { $0.field == .seedCount }) {
            packet.quantityRemaining = Int(count.value)
        }
        // The note says it was read from a photo, and holds what the
        // records have no box for: the rows, sowing again, the barcode.
        packet.notes = PacketReading.note(for: accepted.map(\.asFinding),
                                          on: Date.now.formatted(date: .abbreviated, time: .omitted))
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
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(field.confidenceLabel)
                    .font(.caption)
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

            Text("read from \(field.side.words): \(field.sourceText)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
        .opacity(field.accepted ? 1 : 0.5)
    }
}
