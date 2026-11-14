//
//  SpeciesTestRun.swift
//  Windfall
//
//  A checking aid, the photo twin of EiraTestRun. It runs every photo in
//  a folder through the same code as the Identify screen and writes what
//  came back to a file, with nobody at the keyboard.
//
//  Why it exists. The figures for the identification model were measured
//  on the Mac in Python. Windfall prepares a photo with different code
//  (Apple's, not Python's), and a small difference there can cost
//  accuracy without anyone noticing. This measures the app itself.
//
//  It only runs when the app is started from Terminal with:
//
//    -demoGarden YES             as for every checking aid
//    -speciesTest <folder>       a folder of photos
//    -speciesTestOut <file>      where to write the results
//    -speciesTestKey <file>      optional: the right answers, as a JSON
//                                file of "photo name": "Scientific name"
//    -speciesEyeFolder <folder>  optional: which installed image model to
//                                use, by its folder's name in Models.
//                                Without it, the one Eira uses.
//    -speciesTestAll YES         optional: every installed image model,
//                                one after another, in the one run
//
//  Every dashed word must be followed by a value. EiraTestRun.swift
//  says why.
//

import Foundation

@MainActor
enum SpeciesTestRun {

    static func runIfAsked() async {
        guard DemoGarden.isRequested,
              let folderPath = EiraTestRun.word(after: "-speciesTest"),
              let resultsFile = EiraTestRun.word(after: "-speciesTestOut") else { return }

        var lines: [String] = []
        func note(_ line: String) {
            lines.append(line)
            try? lines.joined(separator: "\n").write(toFile: resultsFile, atomically: true, encoding: .utf8)
        }
        note("# Species test run\n")
        note("- Began: \(Date.now.formatted(date: .abbreviated, time: .standard))")

        // The right answers, if a file of them was given.
        var answers: [String: String] = [:]
        if let keyFile = EiraTestRun.word(after: "-speciesTestKey"),
           let data = FileManager.default.contents(atPath: keyFile),
           let read = try? JSONDecoder().decode([String: String].self, from: data) {
            answers = read
        }

        let folder = URL(fileURLWithPath: folderPath, isDirectory: true)
        let wanted: Set<String> = ["jpg", "jpeg", "png", "heic", "webp"]
        let photos = ((try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { wanted.contains($0.pathExtension.lowercased()) }
            .filter { answers.isEmpty || answers[$0.lastPathComponent] != nil }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        note("- Photos: \(photos.count)\n")

        /// Puts every photo through one image model and writes its totals.
        /// A function inside a function: it can use `photos`, `answers`
        /// and `note` from the lines above without being handed them.
        func runAll(through looker: SpeciesEye) async {
            var tried = 0, named = 0, namedRight = 0, firstRight = 0, inThree = 0, marked = 0
            // The carrot-family warning: how often it showed, how often the
            // photo really was of that family, and how often such a photo
            // went without it.
            var warned = 0, warnedRightly = 0, carrotFamilyPhotos = 0, carrotFamilyUnwarned = 0
            var seconds: TimeInterval = 0

            // Eira's judgement on top of the model's answer (EiraIdentify),
            // counted by the kind of answer she gave. The test photos carry
            // no records and their dates are not known, so only the rules
            // that need neither are measured: look-alikes, a genus when the
            // species is unclear, and dangers. Month 0 means "not known".
            let knowledge = IdentifyKnowledge(month: 0, lookalikes: SpeciesNotes.lookalikes)
            var judged: [String: (given: Int, right: Int)] = [:]
            var warnedOfDanger = 0
            var changed: [String] = []

            for photo in photos {
                guard let data = try? Data(contentsOf: photo) else { continue }
                let began = Date.now
                do {
                    let guess = try await looker.guess(forPhoto: data)
                    let took = Date.now.timeIntervalSince(began)
                    // The first photo also pays for loading the model, so
                    // it is left out of the average.
                    if tried > 0 { seconds += took }
                    tried += 1

                    let names = guess.candidates.prefix(3).map { "\($0.entry.scientific) \($0.percent)" }
                        .joined(separator: "; ")
                    var line = "- \(photo.lastPathComponent): \(guess.isSure ? "NAMED" : "not sure"). \(names)"
                    let isWarned = guess.lookAlikeWarning != nil
                    if isWarned { warned += 1; line += "  (carrot-family warning)" }

                    if let right = answers[photo.lastPathComponent] {
                        // Every photo in these tests is of a plant or an
                        // animal named by its key, so the group can be taken
                        // from the table where the name is in it.
                        let rightEntry = looker.table?.species.first { $0.scientific == right }
                        let isCarrotFamily = rightEntry.map { DangerousLookAlikes.isCarrotFamily($0) } ?? false
                        if isCarrotFamily {
                            carrotFamilyPhotos += 1
                            if isWarned { warnedRightly += 1 } else { carrotFamilyUnwarned += 1; line += "  (CARROT FAMILY, NO WARNING)" }
                        }
                        marked += 1
                        let isFirst = guess.likeliest?.entry.scientific == right
                        // Eira is handed five names. The score is still of the first three.
                        let isInThree = guess.candidates.prefix(3).contains { $0.entry.scientific == right }
                        if isFirst { firstRight += 1 }
                        if isInThree { inThree += 1 }
                        if guess.isSure { named += 1; if isFirst { namedRight += 1 } }
                        line += "  [really \(right): \(isFirst ? "right" : (isInThree ? "in the three" : "WRONG"))]"

                        // What Eira would say, and whether that is right.
                        let answer = EiraIdentify.judge(guess, knowing: knowledge)
                        let kind: String
                        switch answer.verdict {
                        case .named:        kind = "Named a species"
                        case .oneOfSeveral: kind = "Said one of several look-alikes"
                        case .genusOnly:    kind = "Gave the genus only"
                        case .notSure:      kind = "Said she was not sure"
                        case .nothing:      kind = "Gave no answer"
                        }
                        let standing = answer.mark(against: right)
                        judged[kind, default: (0, 0)].given += 1
                        if standing == .right { judged[kind, default: (0, 0)].right += 1 }
                        if answer.cautions.contains(where: { $0.weight == .danger }) { warnedOfDanger += 1 }
                        // Worth reading one by one: where the rules made a
                        // wrong first answer right, or kept a wrong one.
                        if !isFirst, standing != .declined {
                            changed.append("- \(photo.lastPathComponent): really \(right). The model's first answer was \(guess.likeliest?.entry.scientific ?? "nothing"). Eira: \(answer.headline) [\(standing == .right ? "right" : "WRONG")]")
                        }
                    } else if guess.isSure {
                        named += 1
                    }
                    line += String(format: "  %.2fs", took)
                    note(line)
                } catch {
                    note("- \(photo.lastPathComponent): FAILED. \(error.localizedDescription)")
                    // A missing model fails the same way for every photo.
                    if case SpeciesEyeError.notInstalled = error { break }
                    if case SpeciesEyeError.needsNewerSystem = error { break }
                }
            }

            note("\n## Totals\n")
            note("- Photos tried: \(tried)")
            if let eye = looker.loaded {
                note("- Image model: \(eye.name), in the folder \(eye.folder)")
            }
            if let table = looker.table {
                note("- Species in the table: \(table.species.count). Not-sure level: \(table.notSureFloor.map { String(format: "%.2f", $0) } ?? "none"). Made: \(table.made ?? "not said")")
            }
            if tried > 1 {
                note(String(format: "- Time a photo after the first: %.2f seconds", seconds / Double(tried - 1)))
            }
            if marked > 0 {
                note("- With a known answer: \(marked)")
                note("- First answer right: \(firstRight) (\(percent(firstRight, of: marked)))")
                note("- Right answer among the three: \(inThree) (\(percent(inThree, of: marked)))")
                note("- Named outright: \(named) (\(percent(named, of: marked))). Of those, right: \(namedRight) (\(percent(namedRight, of: named)))")
                note("- Carrot-family warning shown: \(warned). Photos really of that family: \(carrotFamilyPhotos), of which warned: \(warnedRightly), not warned: \(carrotFamilyUnwarned). Warned though not of that family: \(warned - warnedRightly)")
            } else {
                note("- Named outright: \(named)")
            }
            if !judged.isEmpty {
                note("\n## Eira's judgement on top\n")
                note("The rules in EiraIdentify, without records or the month. \"Right\" for a group of look-alikes means the true species is one of the group, and for a genus that the genus is the true one.\n")
                for kind in judged.keys.sorted() {
                    let count = judged[kind] ?? (0, 0)
                    let rightWords = kind.hasPrefix("Said she was not sure") || kind.hasPrefix("Gave no") ? "" : ", right: \(count.right) (\(percent(count.right, of: count.given)))"
                    note("- \(kind): \(count.given)\(rightWords)")
                }
                note("- Photos that brought a danger warning: \(warnedOfDanger)")
                if !changed.isEmpty {
                    note("\n### Where the model's first answer was wrong and Eira still gave an answer\n")
                    changed.forEach { note($0) }
                }
            }
        }

        // One model, or each of them in turn. With `-speciesTestAll YES`
        // every installed model is loaded, given all the photos and let
        // go of before the next, in the one run. That is how the "Test
        // the image models" page works, so this also checks that two
        // models can follow one another without the app being restarted.
        if UserDefaults.standard.bool(forKey: "speciesTestAll") {
            for eye in SpeciesEyeFiles.installed() {
                note("\n# \(eye.name)\n")
                let looker = SpeciesEye(using: eye)
                await runAll(through: looker)
                looker.unload()
            }
        } else {
            await runAll(through: SpeciesEye.shared)
        }
        note("\nDONE")
        EiraTestRun.close()
    }

    private static func percent(_ part: Int, of whole: Int) -> String {
        whole > 0 ? "\(Int((Double(part) / Double(whole) * 100).rounded()))%" : "none"
    }
}
