//
//  EyeTestView.swift
//  Windfall
//
//  Testing the image models side by side.
//
//  An image model is the part of Eira that matches a photo to a list of
//  names (SpeciesEye.swift). More than one can be installed. This page
//  puts the same photos through each of them and lets you mark which
//  answers were right, so the choice between two models rests on your
//  own photos and not on somebody else's test.
//
//  What it shows for each model:
//
//    - how often its first answer was right
//    - how often the right answer was among its closest three
//    - how often it named something outright, and was right to
//    - how often it named something that is not on its list at all,
//      which is the mistake that matters most (project doc 30)
//    - how long a photo takes
//
//  It reaches the page from Wildlife, Identify from a photo.
//
//  The counting is done by EyeTestTally in EiraIdentify.swift, which
//  the logic tests cover. This file is the screen.
//
//  New things here:
//
//  Dictionary of dictionaries   `answers[folder][photo]` files each
//                               model's answer under the model's
//                               folder, then under the photo.
//  @AppStorage                  A setting that is saved on the device
//                               and redraws the screen when it changes.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// One photo in a test.
struct EyeTestPhoto: Identifiable, Equatable {
    let id = UUID()
    /// A file's name, or "Photo 3" for one from the Photos library.
    var name: String
    /// The photo at no more than 1024 pixels on its longest side.
    var data: Data
}

struct EyeTestView: View {

    /// The folder of the model Eira uses. Empty until one is chosen
    /// here, and then the first in order is hers. The name of the
    /// setting is SpeciesEyeFiles.choiceKey.
    @AppStorage("speciesEyeFolder") private var savedChoice = ""

    @State private var eyes: [EyeModel] = []
    /// A line of facts about each model's list, by its folder.
    @State private var facts: [String: String] = [:]
    /// Every name on any model's list: the plain form of a scientific
    /// or English name, then the scientific name as the list has it.
    @State private var listed: [String: String] = [:]

    @State private var shots: [EyeTestPhoto] = []
    /// Each model's answers: by model folder, then by photo.
    @State private var answers: [String: [UUID: EyeTestAnswer]] = [:]
    /// What you say each photo really is.
    @State private var truths: [UUID: EyeTruth] = [:]
    /// A name being typed for a photo, until it is marked.
    @State private var typed: [UUID: String] = [:]

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isChoosingFiles = false
    @State private var isRunning = false
    @State private var progress: String?
    @State private var problem: String?
    /// A line saying what a button just did, such as "Copied".
    @State private var done: String?

    /// The most photos in one test. Each is held in memory.
    private let most = 60

    /// The model Eira uses now.
    private var eiraEye: EyeModel? {
        EyeModel.pick(from: eyes, saved: savedChoice.isEmpty ? nil : savedChoice)
    }

    private var hasAnswers: Bool {
        answers.values.contains { !$0.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Test the image models",
                             detail: "The same photos through each one")
                modelsCard
                photosCard
                if let problem { ProblemsCard(problems: [problem]) }
                if hasAnswers { scoreCard }
                ForEach(shots) { shot in
                    shotCard(shot)
                }
            }
            // Reads best in a column, not across a wide window.
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Test the image models")
        .paperScreen()
        .task { readModels() }
        // Photos chosen in the Photos library arrive here as promises,
        // each read in turn.
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            pickerItems = []
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        add(data, named: "Photo \(shots.count + 1)")
                    }
                }
            }
        }
        .fileImporter(isPresented: $isChoosingFiles, allowedContentTypes: [.image],
                      allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            for url in urls {
                // Leave to read a file chosen in a file window lasts
                // only between these two calls.
                let hasLeave = url.startAccessingSecurityScopedResource()
                defer { if hasLeave { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) { add(data, named: url.lastPathComponent) }
            }
        }
    }

    // MARK: The models

    private var modelsCard: some View {
        SheetCard("Models installed") {
            if eyes.isEmpty {
                Text("No image model is installed on this device. One is a folder inside Windfall's Models folder holding the model, uk_species.json and uk_species_rows_f16.bin.")
                    .font(.callout)
                    .foregroundStyle(Theme.inkSoft)
            }
            ForEach(eyes) { eye in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(eye.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        if let fact = facts[eye.folder] {
                            Text(fact)
                        }
                        if let note = eye.note, !note.isEmpty {
                            Text(note)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)

                    Spacer(minLength: 8)

                    if eye == eiraEye {
                        Label("Eira uses this", systemImage: "checkmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(Theme.leaf)
                    } else {
                        Button("Use for Eira") {
                            savedChoice = eye.folder
                            // Let go of the old one. The new one loads
                            // with the next photo she is given.
                            SpeciesEye.shared.unload()
                        }
                        .buttonStyle(QuietGlassButton())
                        .disabled(isRunning)
                    }
                }
            }
            if eyes.count == 1 {
                Text("With one model installed there is nothing to compare it with, but its answers can still be marked.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    // MARK: The photos

    private var photosCard: some View {
        SheetCard("Photos") {
            Text(shots.isEmpty
                 ? "Choose photos you can name yourself. Use awkward ones as well as clear close-ups: the awkward ones are what tell two models apart. Include a few of things that are on no list, to see whether a model wrongly names them."
                 : "\(shots.count) chosen. They stay on this device.")
                .font(.callout)
                .foregroundStyle(Theme.inkSoft)

            HStack(spacing: 10) {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: most, matching: .images) {
                    Label("From Photos", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(QuietGlassButton())

                Button {
                    isChoosingFiles = true
                } label: {
                    Label("From files", systemImage: "folder")
                }
                .buttonStyle(QuietGlassButton())

                if !shots.isEmpty {
                    Button("Clear") {
                        shots = []
                        answers = [:]
                        truths = [:]
                        typed = [:]
                        done = nil
                    }
                    .buttonStyle(QuietGlassButton())
                }
            }
            .disabled(isRunning)

            if !shots.isEmpty, !eyes.isEmpty {
                Button {
                    Task { await run() }
                } label: {
                    HStack(spacing: 8) {
                        if isRunning { ProgressView().controlSize(.small) }
                        Text(isRunning ? (progress ?? "Running…") : (hasAnswers ? "Run the test again" : "Run the test"))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(Theme.leaf)
                .foregroundStyle(Theme.onLeaf)
                .disabled(isRunning)
            }
        }
    }

    // MARK: The score

    private var scoreCard: some View {
        SheetCard("Score") {
            ForEach(eyes) { eye in
                if let given = answers[eye.folder], !given.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(eye.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        ForEach(eyeScore(for: eye).lines, id: \.self) { line in
                            Text(line)
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(Theme.ink)
                        }
                    }
                }
            }
            if truths.isEmpty {
                Text("Mark each photo below with what it really is, and the scores fill in.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
            HStack(spacing: 10) {
                Button {
                    copy(report())
                    done = "Copied. Paste it into a chat or a note."
                } label: {
                    Label("Copy the results", systemImage: "doc.on.doc")
                }
                .buttonStyle(QuietGlassButton())

                if !truths.isEmpty {
                    Button {
                        done = keepAnswers()
                    } label: {
                        Label("Keep my answers", systemImage: "tray.and.arrow.down")
                    }
                    .buttonStyle(QuietGlassButton())
                }
            }
            if let done {
                Text(done)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    // MARK: One photo

    private func shotCard(_ shot: EyeTestPhoto) -> some View {
        SheetCard {
            HStack(alignment: .top, spacing: 14) {
                if let picture = PhotoPicture.image(shot.data) {
                    picture
                        .resizable()
                        .scaledToFill()
                        .frame(width: 110, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(shot.name)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)
                    ForEach(eyes) { eye in
                        if let eyeAnswer = answers[eye.folder]?[shot.id] {
                            answerRow(eye: eye, eyeAnswer: eyeAnswer, truth: truths[shot.id])
                        }
                    }
                    if answers.values.allSatisfy({ $0[shot.id] == nil }) {
                        Text("Not run yet")
                            .font(.callout)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            if answers.values.contains(where: { $0[shot.id] != nil }) {
                truthRow(shot)
            }
        }
    }

    /// One model's answer for one photo, with a tick or a cross once
    /// you have said what the photo really is.
    private func answerRow(eye: EyeModel, eyeAnswer: EyeTestAnswer, truth: EyeTruth?) -> some View {
        let top = eyeAnswer.guess.likeliest
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let truth {
                let isRight = EyeTestView.isRight(eyeAnswer.guess, against: truth)
                Image(systemName: isRight ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(isRight ? Theme.leaf : Color.red)
                    .accessibilityLabel(isRight ? "Right" : "Wrong")
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(eye.name)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                Text(top?.entry.title ?? "No answer")
                    .font(.callout)
                    .foregroundStyle(Theme.ink)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(top?.percent ?? ""), \(eyeAnswer.guess.isSure ? "named" : "not sure")")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(eyeAnswer.guess.isSure ? Theme.leaf : Theme.inkSoft)
                Text(String(format: "%.2f s", eyeAnswer.seconds))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    /// Whether an answer was right. For a species on the list, the
    /// first answer has to be it. For something on no list, the right
    /// answer is to have named nothing.
    static func isRight(_ guess: SpeciesGuess, against truth: EyeTruth) -> Bool {
        switch truth {
        case .species(let name):
            return guess.likeliest.map { SpeciesName.key($0.entry.scientific) == SpeciesName.key(name) } ?? false
        case .notOnList:
            return !guess.isSure
        }
    }

    /// The row where you say what a photo really is: a menu of the
    /// names the models gave, and a box for any other name.
    private func truthRow(_ shot: EyeTestPhoto) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("What is it really?")
                    .font(.callout)
                    .foregroundStyle(Theme.ink)
                // ChoiceMenu is the app's own menu box. It is given a
                // Picker, which draws a tick beside the chosen one.
                ChoiceMenu(shown: truthWords(truths[shot.id])) {
                    Picker("What is it really?", selection: mark(for: shot)) {
                        Text("Not marked").tag("")
                        ForEach(namesOffered(for: shot), id: \.self) { name in
                            Text(name).tag(name)
                        }
                        Text("Something not on the list").tag(EyeTestView.offList)
                    }
                }
            }
            HStack(spacing: 8) {
                FieldBox {
                    TextField("Or type its name", text: typedName(for: shot))
                        .onSubmit { markTyped(shot) }
                }
                Button("Mark") { markTyped(shot) }
                    .buttonStyle(QuietGlassButton())
                    .disabled((typed[shot.id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    /// What the menu's Picker stores for "not on the list". A Picker
    /// needs every choice to be the same kind of value, here a String,
    /// so this stands in for the choice that is not a species' name.
    private static let offList = "not on the list"

    /// A two-way link between the menu and a photo's mark: the mark
    /// read as a String, and a chosen String turned back into a mark.
    private func mark(for shot: EyeTestPhoto) -> Binding<String> {
        Binding(
            get: {
                switch truths[shot.id] {
                case .species(let name): return name
                case .notOnList:         return EyeTestView.offList
                case nil:                return ""
                }
            },
            set: { chosen in
                if chosen.isEmpty {
                    truths[shot.id] = nil
                } else if chosen == EyeTestView.offList {
                    truths[shot.id] = .notOnList
                } else {
                    truths[shot.id] = .species(chosen)
                }
            })
    }

    /// The scientific names the menu offers for a photo: those the
    /// models gave, and the one it is marked with if you typed another.
    private func namesOffered(for shot: EyeTestPhoto) -> [String] {
        var names = namesGiven(for: shot).map(\.scientific)
        if case .species(let name) = truths[shot.id], !names.contains(name) {
            names.append(name)
        }
        return names
    }

    /// A two-way link to the name being typed for one photo. A
    /// `Binding` is what a text box needs: a way to read the value and
    /// a way to change it.
    private func typedName(for shot: EyeTestPhoto) -> Binding<String> {
        Binding(get: { typed[shot.id] ?? "" },
                set: { typed[shot.id] = $0 })
    }

    /// What the menu shows for a photo's mark.
    private func truthWords(_ truth: EyeTruth?) -> String {
        switch truth {
        case .species(let name): return name
        case .notOnList:         return "Not on the list"
        case nil:                return "Choose"
        }
    }

    /// Every different name the models gave for a photo, closest first.
    private func namesGiven(for shot: EyeTestPhoto) -> [SpeciesEntry] {
        var seen: Set<String> = []
        var entries: [SpeciesEntry] = []
        for eye in eyes {
            for possible in answers[eye.folder]?[shot.id]?.guess.candidates ?? [] {
                if seen.insert(SpeciesName.key(possible.entry.scientific)).inserted {
                    entries.append(possible.entry)
                }
            }
        }
        return entries
    }

    /// Marks a photo with the name typed for it. A name that is on a
    /// model's list counts as that species, so a model that did not
    /// give it is marked wrong. Any other name counts as "not on the
    /// list", where the right answer was to name nothing.
    private func markTyped(_ shot: EyeTestPhoto) {
        let words = (typed[shot.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return }
        if let scientific = listed[SpeciesName.key(words)] ?? listed[words.lowercased()] {
            truths[shot.id] = .species(scientific)
        } else {
            truths[shot.id] = .notOnList
        }
    }

    // MARK: Doing things

    /// Finds the installed models and reads a line of facts about each.
    private func readModels() {
        eyes = SpeciesEyeFiles.installed()

        /// The parts of uk_species.json wanted here.
        struct ListFacts: Decodable {
            var rows: Int
            var notSureFloor: Double?
            var species: [SpeciesEntry]
            enum CodingKeys: String, CodingKey {
                case rows, species
                case notSureFloor = "not_sure_floor"
            }
        }

        for eye in eyes {
            let file = SpeciesEyeFiles.folder(of: eye).appendingPathComponent(SpeciesEyeFiles.listName)
            guard let data = try? Data(contentsOf: file),
                  let read = try? JSONDecoder().decode(ListFacts.self, from: data) else { continue }
            var fact = "\(read.rows) names to choose from."
            if let floor = read.notSureFloor {
                fact += " It names one outright at \(Int((floor * 100).rounded()))% or more."
            }
            facts[eye.folder] = fact
            for entry in read.species {
                listed[SpeciesName.key(entry.scientific)] = entry.scientific
                if let english = entry.common, !english.isEmpty {
                    listed[english.lowercased()] = entry.scientific
                }
            }
        }
    }

    /// Adds a photo to the test, shrunk, up to the limit.
    private func add(_ data: Data, named name: String) {
        guard shots.count < most else {
            problem = "A test holds \(most) photos at most. The rest were left out."
            return
        }
        let small = DiaryEntryEditor.thumbnail(from: data, maxDimension: 1024) ?? data
        shots.append(EyeTestPhoto(name: name, data: small))
    }

    /// Puts every photo through every model, one model at a time.
    ///
    /// One at a time because each model is large and they share the
    /// device's graphics chip: a model is loaded, given every photo,
    /// and let go of before the next is loaded. Eira's own copy is let
    /// go of first for the same reason.
    ///
    /// The first photo through a model also pays for loading it, which
    /// can take several seconds. So each model is given the first photo
    /// once to warm up, unmeasured, before the timed run.
    private func run() async {
        isRunning = true
        problem = nil
        done = nil
        defer {
            isRunning = false
            progress = nil
        }
        SpeciesEye.shared.unload()

        for eye in eyes {
            let tester = SpeciesEye(using: eye)
            defer { tester.unload() }
            do {
                progress = "\(eye.name): loading"
                if let first = shots.first { _ = try await tester.guess(forPhoto: first.data) }

                for (place, shot) in shots.enumerated() {
                    progress = "\(eye.name): photo \(place + 1) of \(shots.count)"
                    let began = Date.now
                    let guess = try await tester.guess(forPhoto: shot.data)
                    let took = Date.now.timeIntervalSince(began)
                    answers[eye.folder, default: [:]][shot.id] = EyeTestAnswer(guess: guess, seconds: took, truth: nil)
                }
            } catch let trouble {
                // One model failing does not stop the next being tried.
                problem = "\(eye.name): \(trouble.localizedDescription)"
            }
        }
    }

    /// One model's score, with your marks put beside its answers.
    private func eyeScore(for eye: EyeModel) -> EyeTestTally {
        let marked = shots.compactMap { shot -> EyeTestAnswer? in
            guard var eyeAnswer = answers[eye.folder]?[shot.id] else { return nil }
            eyeAnswer.truth = truths[shot.id]
            return eyeAnswer
        }
        return EyeTestTally.counting(marked)
    }

    /// The whole test as text, for pasting into a chat or a note.
    private func report() -> String {
        var lines = ["# Image model test, \(EiraIdentify.day(.now))", ""]
        for eye in eyes where !(answers[eye.folder] ?? [:]).isEmpty {
            lines.append("## \(eye.name)")
            lines.append(contentsOf: eyeScore(for: eye).lines.map { "- \($0)" })
            lines.append("")
        }
        lines.append("## Photo by photo")
        for shot in shots {
            lines.append("- \(shot.name). Really: \(truthWords(truths[shot.id]).replacingOccurrences(of: "Choose", with: "not marked"))")
            for eye in eyes {
                guard let eyeAnswer = answers[eye.folder]?[shot.id] else { continue }
                let three = eyeAnswer.guess.candidates.prefix(3)
                    .map { "\($0.entry.scientific) \($0.percent)" }
                    .joined(separator: "; ")
                lines.append("  - \(eye.name): \(eyeAnswer.guess.isSure ? "NAMED" : "not sure"). \(three)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private func copy(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }

    /// Saves each marked photo and its true name to a folder beside
    /// the Models folder, called "Photo answers".
    ///
    /// Why: a photo whose name you have confirmed is what an image
    /// model can later be taught from, and what a new model can be
    /// tested on (project doc 28). Nothing is taught by this page. It
    /// only keeps the photos and names where that work can find them.
    /// Returns a line saying what was done.
    private func keepAnswers() -> String {
        let folder = EiraModelLibrary.modelsFolder()
            .deletingLastPathComponent()
            .appendingPathComponent("Photo answers", isDirectory: true)
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: folder, withIntermediateDirectories: true)

            // The list so far, if there is one.
            let listFile = folder.appendingPathComponent("answers.json")
            var kept: [[String: String]] = []
            if let data = try? Data(contentsOf: listFile),
               let read = try? JSONDecoder().decode([[String: String]].self, from: data) {
                kept = read
            }

            var added = 0
            for shot in shots {
                guard let truth = truths[shot.id] else { continue }
                let fileName = "\(shot.id.uuidString).jpg"
                // A photo kept by an earlier press is not kept twice.
                if kept.contains(where: { $0["file"] == fileName }) { continue }
                try shot.data.write(to: folder.appendingPathComponent(fileName))

                var line = ["file": fileName, "from": shot.name, "marked": EiraIdentify.day(.now)]
                switch truth {
                case .species(let name): line["species"] = name
                case .notOnList:         line["species"] = "not on the list"
                }
                if let words = typed[shot.id], !words.isEmpty { line["typed"] = words }
                for eye in eyes {
                    if let top = answers[eye.folder]?[shot.id]?.guess.likeliest {
                        line["answer from \(eye.name)"] = "\(top.entry.scientific) \(top.percent)"
                    }
                }
                kept.append(line)
                added += 1
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(kept).write(to: listFile, options: .atomic)
            return added == 0
                ? "Those were kept already. \(kept.count) in all, in \(folder.path)."
                : "Kept \(added). \(kept.count) in all, in \(folder.path)."
        } catch let trouble {
            return "They could not be kept: \(trouble.localizedDescription)"
        }
    }
}
