//
//  GardenDataView.swift
//  Windfall
//
//  The screen for bringing reference data in: the starter data that ships
//  with the app, or a file of your own chosen with Apple's file picker.
//
//  The work is done by GardenDataImporter in GardenData.swift. This file
//  is only the buttons and the wording.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct GardenDataView: View {

    @Environment(\.modelContext) private var context

    // @Query keeps each of these lists up to date by itself, so the
    // counts on screen change the moment an import finishes.
    @Query private var plants: [Plant]
    @Query private var fauna: [Fauna]
    @Query private var links: [PlantFaunaLink]
    @Query private var shapes: [FlowerShape]
    @Query private var cascades: [Cascade]
    @Query private var companions: [CompanionPair]

    @State private var importer = GardenDataImporter()
    @State private var showingFilePicker = false
    @State private var confirmingStarter = false
    /// A CSV file that has been read and is waiting for you to say which
    /// table it is.
    @State private var waitingCSV: WaitingCSV?

    private struct WaitingCSV {
        let fileName: String
        let rows: [[String: String]]
        var kind: GardenTableKind
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Plants", value: "\(plants.count)")
                LabeledContent("Wildlife species", value: "\(fauna.count)")
                LabeledContent("Plant and wildlife links", value: "\(links.count)")
                LabeledContent("Flower shapes", value: "\(shapes.count)")
                LabeledContent("Cascades", value: "\(cascades.count)")
                LabeledContent("Companion pairs", value: "\(companions.count)")
            } header: {
                Text("In Windfall now")
            } footer: {
                Text("Stored on this device only.")
            }

            Section {
                Button {
                    if plants.isEmpty {
                        importer.loadStarterData(into: context)
                    } else {
                        confirmingStarter = true
                    }
                } label: {
                    Label("Load the starter data", systemImage: "leaf")
                }
            } footer: {
                Text("The starter data was made from your Garden Planning spreadsheet and ships inside the app.")
            }

            Section {
                Button {
                    showingFilePicker = true
                } label: {
                    Label("Import from a file…", systemImage: "folder")
                }
            } footer: {
                Text("A Windfall data file (.json), or one table saved as CSV from Numbers or Excel.")
            }

            if let waiting = waitingCSV {
                Section {
                    LabeledContent("File", value: waiting.fileName)
                    LabeledContent("Rows", value: "\(waiting.rows.count)")
                    Picker("This table is", selection: Binding(
                        get: { waiting.kind },
                        set: { waitingCSV?.kind = $0 }
                    )) {
                        ForEach(GardenTableKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    Button("Import these rows") { importWaitingCSV() }
                    Button("Cancel", role: .cancel) { waitingCSV = nil }
                } header: {
                    Text("Check before importing")
                } footer: {
                    Text(waiting.kind.isPlantTable
                         ? "Plants already in the library are updated, not duplicated."
                         : "This replaces what Windfall holds for this table.")
                }
            }

            if let error = importer.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            } else if !importer.message.isEmpty {
                Section {
                    Label(importer.message, systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Garden data")
        .paperScreen()
        // .json and .commaSeparatedText are Apple's names for the two
        // kinds of file this screen can read.
        .fileImporter(isPresented: $showingFilePicker,
                      allowedContentTypes: [.json, .commaSeparatedText]) { result in
            switch result {
            case .success(let url): read(url)
            case .failure(let error): importer.lastError = error.localizedDescription
            }
        }
        .confirmationDialog("Load the starter data again?",
                            isPresented: $confirmingStarter,
                            titleVisibility: .visible) {
            Button("Load starter data") { importer.loadStarterData(into: context) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Plants in the starter data are updated to match it. Where you have changed one of those plants in the app, the starter data's values replace yours. Plants you added yourself are left alone. The wildlife list, links and companion pairs are replaced.")
        }
    }

    // MARK: Reading a chosen file

    private func read(_ url: URL) {
        importer.lastError = nil
        importer.message = ""
        waitingCSV = nil

        // A file chosen outside the app's own folder is locked until the
        // app asks to open it, and should be locked again afterwards.
        let unlocked = url.startAccessingSecurityScopedResource()
        defer { if unlocked { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            importer.lastError = "That file could not be opened."
            return
        }

        if url.pathExtension.lowercased() == "csv" {
            // Numbers saves CSV as UTF-8. Older programs use Windows Latin.
            let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .windowsCP1252) ?? ""
            guard let table = CSVReader.table(from: text), !table.rows.isEmpty else {
                importer.lastError = "No rows were found in that CSV file."
                return
            }
            guard let kind = GardenTableKind.guess(fromHeaders: table.headers) else {
                importer.lastError = "The column headings in that CSV file are not ones Windfall knows."
                return
            }
            waitingCSV = WaitingCSV(fileName: url.lastPathComponent, rows: table.rows, kind: kind)
        } else {
            do {
                let file = try GardenDataFile.decode(data)
                importer.importAll(file, into: context)
            } catch {
                importer.lastError = error.localizedDescription
            }
        }
    }

    private func importWaitingCSV() {
        guard let waiting = waitingCSV else { return }
        let file = GardenDataFile(
            source: waiting.fileName,
            tables: [GardenTable(name: waiting.kind.tableName, rows: waiting.rows)])
        importer.importAll(file, into: context)
        waitingCSV = nil
    }
}

#Preview {
    NavigationStack { GardenDataView() }
        .modelContainer(for: [Plant.self, Fauna.self, PlantFaunaLink.self,
                              FlowerShape.self, Cascade.self, CompanionPair.self],
                        inMemory: true)
}
