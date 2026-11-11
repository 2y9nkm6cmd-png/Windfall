#if !canImport(SwiftUI)
// Tests for the parts of Windfall that are pure logic.
//
// These run without a Mac, as part of Tools/checks/run-checks.sh. They are
// not part of the app. Each `check` states one thing that must be true.

import Foundation

nonisolated(unsafe) var failures = 0
nonisolated(unsafe) var passes = 0
func check(_ condition: @autoclosure () -> Bool, _ what: String, line: Int = #line) {
    if condition() { passes += 1 } else { failures += 1; print("  FAILED (line \(line)): \(what)") }
}

/// A stand-in engine that replies with fixed text, so the conversation
/// logic can be tested without a model.
@MainActor
final class FakeEngine: EiraEngine {
    let displayName = "fake"
    var starts: [(instructions: String, history: [ChatMessage])] = []
    var prompts: [String] = []
    var pieces: [StreamEvent] = [.reasoning("thinking"), .content("Hello "), .content("there"), .finished]
    var errorToThrow: Error?
    var delayNanoseconds: UInt64 = 0
    var unloaded = false

    func startConversation(instructions: String, history: [ChatMessage]) {
        starts.append((instructions, history))
    }
    func reply(to prompt: String,
               onEvent: @escaping @MainActor (StreamEvent) -> Void) async throws -> GenerationMetrics {
        prompts.append(prompt)
        for piece in pieces {
            if delayNanoseconds > 0 { try await Task.sleep(nanoseconds: delayNanoseconds) }
            try Task.checkCancellation()
            onEvent(piece)
        }
        if let errorToThrow { throw errorToThrow }
        return GenerationMetrics(timeToFirstToken: 0.1, tokensGenerated: 2, totalTime: 1)
    }
    func unload() { unloaded = true }
}

@MainActor
func waitUntilIdle(_ conversation: EiraConversation) async {
    for _ in 0..<400 where conversation.isGenerating {
        try? await Task.sleep(nanoseconds: 5_000_000)
    }
}

@main
struct LogicTests {
    @MainActor
    static func main() async {
        // The 12GB rule
        let gib: UInt64 = 1024 * 1024 * 1024
        check(!DeviceCapability.canRunEira(physicalMemory: 8 * gib), "an 8GB device cannot run Eira")
        check(!DeviceCapability.canRunEira(physicalMemory: UInt64(7.5 * Double(gib))), "a device reporting 7.5GB cannot run Eira")
        check(DeviceCapability.canRunEira(physicalMemory: UInt64(11.3 * Double(gib))), "a 12GB device reporting 11.3GB can run Eira")
        check(DeviceCapability.canRunEira(physicalMemory: 24 * gib), "a 24GB Mac can run Eira")
        check(DeviceCapability.memoryDescription(physicalMemory: UInt64(11.3 * Double(gib))) == "11GB"
              || DeviceCapability.memoryDescription(physicalMemory: UInt64(11.6 * Double(gib))) == "12GB", "memory is described in whole GB")

        // Model choice is saved and read back
        let defaults = UserDefaults(suiteName: "windfall-tests-\(UUID().uuidString)")!
        check(EiraModelChoice.load(from: defaults) == .appleBuiltIn, "the built-in model is the starting choice")
        EiraModelChoice(kind: .coreAI, value: "qwen3.5-2B").save(to: defaults)
        check(EiraModelChoice.load(from: defaults) == EiraModelChoice(kind: .coreAI, value: "qwen3.5-2B"), "a saved choice is read back")
        check(EiraModelChoice.Kind.online.isPrivate == false && EiraModelChoice.Kind.coreAI.isPrivate, "only the online kind leaves the device")

        // Titles
        check(EiraChatStore.title(from: "What visits marjoram?\nsecond line") == "What visits marjoram?", "a title is the first line")
        check(EiraChatStore.title(from: String(repeating: "a", count: 100)).count == 61, "a long title is cut to 60 characters plus an ellipsis")

        // Web pages to plain text
        let html = "<html><head><title>Bees &amp; Wasps</title><style>p{}</style></head><body><script>alert('x')</script><h1>Bees</h1><p>Red mason bee &lt;Osmia&gt;&nbsp;nests in walls.</p><!-- hidden --><p>Second.</p></body></html>"
        let text = WebText.plainText(fromHTML: html)
        check(!text.contains("alert") && !text.contains("p{}") && !text.contains("hidden"), "scripts, styles and comments are removed")
        check(text.contains("Red mason bee <Osmia> nests in walls."), "entities are decoded: \(text)")
        check(text.contains("Bees\n") && text.contains("Second."), "paragraphs become separate lines")
        check(WebText.title(fromHTML: html) == "Bees & Wasps", "the page title is read")
        check(WebText.decodeEntities("&amp;lt;") == "&lt;", "a double-encoded entity is decoded once only")
        let long = WebText.truncate(String(repeating: "word ", count: 100), to: 52)
        check(long.count <= 53 && long.hasSuffix("…") && !long.hasSuffix(" …"), "long text is cut at a word with an ellipsis")

        // Web addresses
        check(WebPageReader.webURL(from: "rhs.org.uk/plants")?.absoluteString == "https://rhs.org.uk/plants", "a bare address is treated as https")
        check(WebPageReader.webURL(from: "file:///etc/passwd") == nil, "a file path is refused")
        check(WebPageReader.webURL(from: "not an address") == nil, "text with spaces is refused")
        check(WebPageReader.webURL(from: "localhost") == nil, "an address without a dot is refused")

        // Wikipedia replies
        let search = #"{"query":{"search":[{"title":"Osmia bicornis","snippet":"x"},{"title":"Mason bee"}]}}"#
        check(WikipediaLookup.parseSearchTitles(Data(search.utf8)) == ["Osmia bicornis", "Mason bee"], "search titles are read in order")
        let summary = #"{"title":"Osmia bicornis","extract":"A species of mason bee.","content_urls":{"desktop":{"page":"https://en.wikipedia.org/wiki/Osmia_bicornis"}}}"#
        check(WikipediaLookup.parseSummary(Data(summary.utf8)) == WikipediaLookup.Article(title: "Osmia bicornis", extract: "A species of mason bee.", url: "https://en.wikipedia.org/wiki/Osmia_bicornis"), "a summary is read")
        check(WikipediaLookup.parseSummary(Data("{}".utf8)) == nil && WikipediaLookup.parseSearchTitles(Data("oops".utf8)).isEmpty, "bad replies give nothing, not a crash")

        // Tool results keep their source when shortened
        let big = ToolResult(text: String(repeating: "line of text\n", count: 300), source: "user's plant database")
        let trimmed = EiraToolHub.trimmed(big, limit: 200)
        check(trimmed.count < 320 && trimmed.hasSuffix("[source: user's plant database]") && trimmed.contains("(shortened)"), "a long result is cut but keeps its source")
        check(EiraToolHub.trimmed(ToolResult(text: "short", source: "s"), limit: 200) == "short\n\n[source: s]", "a short result is unchanged")
        check(EiraToolHub.json(["name": "say \"hi\""]) == #"{"name":"say \"hi\""}"#, "quotation marks are written safely")

        // Standing instructions
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Europe/London")!
        let november = calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 12))!
        let prompt = EiraPrompt.build(date: november, gardenNotes: "Clay slope.", corrections: ["On \"lavender\": mine is English lavender"], calendar: calendar)
        check(prompt.contains("Tuesday 10 November 2026") && prompt.contains("The season is autumn"), "today's date and season are filled in")
        check(prompt.contains("Clay slope.") && prompt.contains("- On \"lavender\": mine is English lavender"), "garden notes and corrections are included")
        check(prompt.contains("Never identify fungi"), "the fungi rule is present")
        check(!EiraPrompt.build(date: november, gardenNotes: "x", corrections: [], calendar: calendar).contains("Corrections the gardener"), "no corrections heading when there are none")
        let july = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!, january = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        check(EiraPrompt.season(for: july, calendar: calendar) == "summer" && EiraPrompt.season(for: january, calendar: calendar) == "winter", "seasons follow the months")

        // Keeping a conversation within the model's memory
        var talk: [ChatMessage] = []
        for i in 0..<6 {
            talk.append(ChatMessage(role: .user, content: "question \(i) " + String(repeating: "q", count: 400)))
            talk.append(ChatMessage(role: .tool, content: String(repeating: "t", count: 2000), toolName: "search_garden"))
            talk.append(ChatMessage(role: .assistant, content: "answer \(i) " + String(repeating: "a", count: 400), reasoning: "r"))
        }
        check(EiraContext.needsCondensing(talk), "a long conversation needs condensing")
        check(!EiraContext.needsCondensing([ChatMessage(role: .user, content: "hi")]), "a short one does not")
        let condensed = EiraContext.condensed(talk)
        check(condensed.count == 12 && condensed.allSatisfy { $0.role != .tool && $0.reasoning == nil }, "lookups and reasoning are dropped")
        check(condensed.prefix(8).allSatisfy { $0.content.count <= 241 } && condensed.suffix(4).allSatisfy { $0.content.count > 400 }, "older turns are shortened and the last four kept whole")
        check(!EiraContext.needsCondensing(condensed), "the condensed conversation fits")
        check(EiraContext.historyText([ChatMessage(role: .user, content: "a"), ChatMessage(role: .tool, content: "x"), ChatMessage(role: .assistant, content: "b")]) == "Gardener: a\nEira: b", "history is written as plain turns")

        // A whole conversation, with a stand-in engine
        let context = ModelContext()
        let engine = FakeEngine()
        let conversation = EiraConversation()
        conversation.send("ignored")
        check(conversation.messages.isEmpty, "nothing is sent before an engine is set")
        conversation.configure(engine: engine, hub: EiraToolHub(context: context), store: EiraChatStore(context: context))
        conversation.send("  What visits marjoram?  ")
        check(conversation.isGenerating, "a reply starts")
        await waitUntilIdle(conversation)
        check(conversation.messages.map(\.role) == [.user, .assistant], "the question and the reply are recorded")
        check(conversation.messages.last?.content == "Hello there" && conversation.messages.last?.reasoning == "thinking", "the reply and its reasoning are assembled from the pieces")
        check(conversation.messages.first?.content == "What visits marjoram?", "spaces around a question are trimmed")
        check(engine.starts.count == 1 && engine.starts[0].history.isEmpty && engine.starts[0].instructions.contains("You are Eira"), "the engine is started once with the instructions")
        check(conversation.lastMetrics?.tokensGenerated == 2 && conversation.lastError == nil, "speed figures are kept")

        conversation.send("And thyme?")
        await waitUntilIdle(conversation)
        check(engine.starts.count == 1 && engine.prompts.count == 2, "a second question does not restart the engine")

        // A forced lookup runs first and its result is shown and passed on
        conversation.send("nonexistent plant", forcedTool: EiraTools.searchGarden)
        await waitUntilIdle(conversation)
        check(conversation.messages.contains { $0.role == .tool && $0.toolName == "search_garden" && $0.content.contains("[source: user's plant database]") }, "a forced lookup appears with its source")
        check(engine.prompts.last?.contains("already looked this up") == true && engine.prompts.last?.contains("nonexistent plant") == true, "the lookup result is handed to the model")

        // A correction restarts the engine with fresh instructions
        if let reply = conversation.messages.last(where: { $0.role == .assistant }) { conversation.correct(reply, with: "Thyme is visited by honeybees here.") }
        conversation.send("Again?")
        await waitUntilIdle(conversation)
        check(engine.starts.count == 2 && engine.starts[1].history.count == conversation.messages.filter { $0.role == .user || $0.role == .assistant }.count - 2, "after a correction the engine restarts with the earlier turns")

        // A failure is reported and what arrived is kept
        struct Boom: LocalizedError { var errorDescription: String? { "the model fell over" } }
        engine.errorToThrow = Boom()
        conversation.send("Break")
        await waitUntilIdle(conversation)
        check(conversation.lastError == "the model fell over" && conversation.messages.last?.content == "Hello there", "an error is shown and the partial reply kept")
        engine.errorToThrow = nil

        // Stop really stops
        engine.delayNanoseconds = 200_000_000
        conversation.send("Slow one")
        try? await Task.sleep(nanoseconds: 300_000_000)
        conversation.stop()
        await waitUntilIdle(conversation)
        check(!conversation.isGenerating && conversation.lastError == nil, "stop ends the reply without an error")
        check(conversation.messages.last?.role == .user || conversation.messages.last?.content.hasSuffix("(stopped)") == true || conversation.messages.last?.reasoning != nil, "a stopped reply is marked")
        engine.delayNanoseconds = 0

        // A long conversation is condensed before the next question
        conversation.clear()
        check(conversation.messages.isEmpty, "clear empties the conversation")
        engine.pieces = [.content(String(repeating: "long answer ", count: 400)), .finished]
        conversation.send("one"); await waitUntilIdle(conversation)
        conversation.send("two"); await waitUntilIdle(conversation)
        let startsBefore = engine.starts.count
        conversation.send("three"); await waitUntilIdle(conversation)
        check(engine.starts.count == startsBefore + 1 && (engine.starts.last?.history.count ?? 0) >= 4, "a long conversation is condensed and the engine restarted")

        // The fungi rule is fixed wording, never the model
        for question in [
            "I found some mushrooms on the lawn. Are they safe to eat?",
            "Can I eat these mushrooms?",
            "What mushroom is this?",
            "Is this fungus poisonous?",
            "Are the toadstools in my lawn safe for my dog?",
            "Could I cook the puffballs by the shed?",
            "Can you identify a mushroom for me?"
        ] {
            check(EiraSafety.fixedReply(to: question) != nil, "stopped before the model: \(question)")
        }
        for question in [
            "Are fungi good for my soil?",
            "What is this fungus on my rose leaves?",
            "Is it safe to compost leaves with a fungal disease?",
            "How do I get rid of mushrooms in the lawn?",
            "What should I sow this month?",
            "Is it safe to eat rhubarb leaves?"
        ] {
            check(EiraSafety.fixedReply(to: question) == nil, "goes to the model: \(question)")
        }
        let promptsBeforeFungi = engine.prompts.count
        conversation.send("Are these mushrooms safe to eat?"); await waitUntilIdle(conversation)
        check(engine.prompts.count == promptsBeforeFungi, "the model is not asked a fungi question")
        check(conversation.messages.last?.content == EiraSafety.fungiReply && conversation.messages.last?.role == .assistant, "the fixed fungi reply is what the gardener sees")
        check(!EiraSafety.fungiReply.contains("describe") && EiraSafety.fungiReply.contains("fatal"), "the fixed reply warns and does not ask for a description")
        // Preserving, pesticides and medicine are fixed wording too
        let stopped: [(String, String)] = [
            ("How long do I need to water-bath can my runner beans?", EiraSafety.preservingReply),
            ("How long should I blanch broad beans before freezing?", EiraSafety.preservingReply),
            ("How many minutes do I blanch peas?", EiraSafety.preservingReply),
            ("Is it safe to make chutney with green tomatoes?", EiraSafety.preservingReply),
            ("What temperature should I pressure can carrots at?", EiraSafety.preservingReply),
            ("How much slug pellet should I put down per square metre?", EiraSafety.pesticideReply),
            ("How much washing-up liquid do I mix with water for aphids?", EiraSafety.pesticideReply),
            ("What strength glyphosate kills bindweed?", EiraSafety.pesticideReply),
            ("How many nematodes per square metre for vine weevil?", EiraSafety.pesticideReply),
            ("Is comfrey tea safe to drink for a bad back?", EiraSafety.medicineReply),
            ("What are the medicinal uses of yarrow?", EiraSafety.medicineReply),
            ("How much feverfew should I eat for a headache?", EiraSafety.medicineReply),
            ("Can I make a tincture from my calendula?", EiraSafety.medicineReply),
            ("Is elderflower good for a cold?", EiraSafety.medicineReply)
        ]
        for (question, reply) in stopped {
            check(EiraSafety.fixedReply(to: question) == reply, "gets the right fixed reply: \(question)")
        }
        for question in [
            "How do I store onions over winter?",
            "How long should I blanch my endive?",
            "When do I start blanching celery?",
            "What's the best time to pick plums for jam?",
            "How long can my tomatoes stay on the plant?",
            "How do I get rid of slugs organically?",
            "How much comfrey tea should I give my tomatoes?",
            "Is comfrey good for my compost?",
            "Will the cold kill my plants?",
            "When do painted lady butterflies arrive?",
            "What should I plant in my back garden?",
            "How much water do my seedlings need?",
            "Which plants help bees in winter?"
        ] {
            check(EiraSafety.fixedReply(to: question) == nil, "goes to the model: \(question)")
        }
        check(EiraSafety.tidied("Water-bath, what's this?") == " water bath whats this ", "questions are tidied before matching")
        for reply in [EiraSafety.preservingReply, EiraSafety.pesticideReply, EiraSafety.medicineReply] {
            check(reply.rangeOfCharacter(from: .decimalDigits) == nil, "a fixed reply never contains a number")
        }
        let startsBeforeFollowUp = engine.starts.count
        conversation.send("what should I sow?"); await waitUntilIdle(conversation)
        check(engine.starts.count == startsBeforeFollowUp + 1, "after a fixed reply the model is handed the conversation afresh")

        // Species lookup: reading names out of Wikipedia and GBIF replies
        check(ToolRunner.scientificNameCandidates(title: "Osmia bicornis", extract: "Osmia bicornis (synonym Osmia rufa) is a species of mason bee, known as the red mason bee.") == ["Osmia bicornis"], "a title that is a scientific name is used")
        check(ToolRunner.scientificNameCandidates(title: "European robin", extract: "The European robin (Erithacus rubecula), known simply as the robin, is a small bird.").first == "Erithacus rubecula", "a scientific name in brackets comes first")
        check(ToolRunner.scientificNameCandidates(title: "Compost", extract: "Compost is a mixture of ingredients used as plant fertiliser.").isEmpty, "an article with no scientific name gives none")
        check(WikipediaLookup.parseSummary(Data(#"{"type":"disambiguation","title":"Robin","extract":"Robin most commonly refers to several species of birds."}"#.utf8)) == nil, "a Wikipedia list of meanings is not treated as an article")
        check(WikipediaLookup.parseSummary(Data(#"{"type":"standard","title":"Osmia bicornis","extract":"Osmia bicornis is a species of mason bee."}"#.utf8))?.title == "Osmia bicornis", "a normal Wikipedia summary is read")
        check(ToolRunner.describeGBIFMatch(["matchType": "NONE"]) == nil, "GBIF finding nothing is reported as nothing")
        check(ToolRunner.describeGBIFMatch(["matchType": "EXACT", "scientificName": "Osmia bicornis (Linnaeus, 1758)", "rank": "SPECIES", "family": "Megachilidae", "confidence": 99])?.first == "Accepted name: Osmia bicornis (Linnaeus, 1758)", "a GBIF match is described")
        check(prompt.contains("Never ask for a description of a fungus") && prompt.contains("nothing is recorded"), "the prompt carries the new fungi and no-records rules")

        // Garden data: looking up a column by its heading
        let row = DataRow(["Sowing temperature [C]": "18", "Propagator?": "yes", "Max Height (m)": "1.5",
                           "Notes": "  ", "Soil pH": "#N/A", "Germination (days)": "7-14 days", "Germination days": "7"])
        check(row["Sowing temperature"] == "18", "a heading is found without its units")
        check(row.bool("Propagator"), "a heading is found without its question mark")
        check(row["max height (m)"] == "1.5", "capitals in a heading do not matter")
        check(row["Notes"] == nil && row["Soil pH"] == nil, "blanks and spreadsheet errors are treated as nothing")
        check(row["Germination (days)"] == "7-14 days" && row["Germination days"] == "7", "two similar headings are kept apart")
        check(row["Hardiness"] == nil, "a heading that is not there gives nothing")

        // Garden data: reading CSV
        let csv = "Name,Notes,Category\r\nGarlic,\"Plant in autumn, harvest in July\",Alliums\nLeek,\"Variety \"\"Musselburgh\"\"\",Alliums\n"
        let csvRows = CSVReader.rows(from: csv)
        check(csvRows.count == 3 && csvRows[1] == ["Garlic", "Plant in autumn, harvest in July", "Alliums"], "a comma inside quotes stays in its cell")
        check(csvRows[2][1] == "Variety \"Musselburgh\"", "a doubled quote is read as one quote")
        let csvTable = CSVReader.table(from: "found,,\nGrowth Patterns,,\nType,Common Name,Latin Name\nPlant,Apple,Malus domestica\n,,\n")
        check(csvTable?.headers == ["Type", "Common Name", "Latin Name"] && csvTable?.rows.count == 1 && csvTable?.rows.first?["Common Name"] == "Apple", "the heading row is found even when it is not the first row")
        check(GardenTableKind.guess(fromHeaders: ["Plant 1", "Plant 2", "+/-"]) == .companions
              && GardenTableKind.guess(fromHeaders: ["Plant", "Fauna", "Relationship"]) == .links
              && GardenTableKind.guess(fromHeaders: ["Fauna ID", "Common Name", "Taxon Group"]) == .fauna
              && GardenTableKind.guess(fromHeaders: ["Type", "Common Name"]) == .permaculture
              && GardenTableKind.guess(fromHeaders: ["Types", "Category", "Name"]) == .allotment
              && GardenTableKind.guess(fromHeaders: ["Date", "Amount"]) == nil, "a table is recognised from its headings")

        // Garden data: files
        check((try? GardenDataFile.decode(Data("not json".utf8))) == nil, "a file that is not garden data is refused")
        check((try? GardenDataFile.decode(Data(#"{"formatVersion":99,"source":"x","generated":"x","tables":[]}"#.utf8))) == nil, "a file from a newer version of the app is refused")

        // Garden data: importing the real starter file
        if let path = ProcessInfo.processInfo.environment["WINDFALL_STARTER"],
           let data = FileManager.default.contents(atPath: path),
           let starter = try? GardenDataFile.decode(data) {
            let store = ModelContext()
            let importer = GardenDataImporter()
            let first = importer.importAll(starter, into: store)
            check(importer.lastError == nil, "the starter data imports without an error (\(importer.lastError ?? ""))")
            let rowsInFile = GardenTableKind.plantKinds.compactMap { starter.table(named: $0.tableName)?.rows.count }.reduce(0, +)
            let plants = (try? store.fetch(FetchDescriptor<Plant>())) ?? []
            check(first.plantsAdded == plants.count && plants.count > 300 && plants.count <= rowsInFile, "plants arrive, and a plant on two sheets becomes one record (\(plants.count) plants from \(rowsInFile) rows)")
            check(first.fauna == 21 && first.links == 58 && first.flowerShapes == 20 && first.cascades == 7 && first.companionPairs == 410, "the reference tables arrive in full (\(first.description))")
            let garlic = plants.filter { $0.commonName.lowercased() == "garlic" }
            check(!garlic.isEmpty, "garlic is in the library")
            check(plants.contains { $0.sourceSites.count == 2 }, "a plant grown in both gardens lists both")
            check(plants.contains { $0.status == .wanted } && plants.contains { $0.status == .previouslyOwned }, "plants to buy and previously owned plants keep their status")
            check(plants.contains { $0.sowingTemperatureC != nil } && plants.contains { $0.needsPropagator }, "columns with units or a question mark in the heading are read")
            let pairs = (try? store.fetch(FetchDescriptor<CompanionPair>())) ?? []
            check(pairs.contains { ($0.mechanism ?? "").isEmpty == false }, "companion pairs carry their reason")
            let links = (try? store.fetch(FetchDescriptor<PlantFaunaLink>())) ?? []
            check(links.contains { $0.fauna != nil }, "links are joined to the wildlife list")

            // Importing twice must not duplicate anything.
            let second = importer.importAll(starter, into: store)
            let plantsAfter = (try? store.fetch(FetchDescriptor<Plant>()))?.count ?? 0
            let pairsAfter = (try? store.fetch(FetchDescriptor<CompanionPair>()))?.count ?? 0
            check(second.plantsAdded == 0 && second.plantsUpdated == plants.count && plantsAfter == plants.count && pairsAfter == 410, "importing the same file again adds nothing (\(second.description))")

            // A single table leaves the others alone.
            let onlyFauna = GardenDataFile(source: "test", tables: [GardenTable(name: "Fauna", rows: [["Common Name": "Red mason bee", "Scientific Name": "Osmia bicornis"]])])
            let third = importer.importAll(onlyFauna, into: store)
            let faunaAfter = (try? store.fetch(FetchDescriptor<Fauna>()))?.count ?? 0
            check(third.fauna == 1 && faunaAfter == 1 && ((try? store.fetch(FetchDescriptor<Plant>()))?.count ?? 0) == plants.count, "importing one table replaces that table and leaves the rest")

            let empty = importer.importAll(GardenDataFile(source: "test", tables: [GardenTable(name: "Shopping", rows: [["Item": "Twine"]])]), into: store)
            check(empty.tablesRead == 0 && importer.lastError != nil, "a file with no known tables is reported, not silently accepted")

            // First launch
            let fresh = ModelContext()
            let suite = UserDefaults(suiteName: "windfall-tests-\(UUID().uuidString)")!
            check(GardenDataImporter().loadStarterDataIfNeeded(into: store, defaults: suite) == nil && suite.bool(forKey: GardenDataImporter.starterLoadedKey), "starter data is not loaded over an existing library")
            _ = fresh
        } else {
            check(false, "the starter data file could be read for testing")
        }

        // Switching model unloads the old one, and unavailability is recorded
        conversation.setUnavailable("needs 12GB")
        check(engine.unloaded && conversation.modelName == nil && conversation.setupProblem == "needs 12GB", "an engine is unloaded when Eira becomes unavailable")

        // Older logic: months and grid references
        check(MonthParser.months(in: "mar apr may") == [3, 4, 5], "month lists are read")
        check(MonthParser.months(in: "Oct-Mar") == [10, 11, 12, 1, 2, 3], "a range across the new year is read")
        // A well-known check point. In GPS (WGS84) terms 52°39'28.72"N 1°42'57.79"E.
        // On the Ordnance Survey's own datum the same spot is 52°39'27.25"N
        // 1°43'04.52"E, which is grid position 651409.9, 313177.3 (TG 51409 13177).
        // Feeding in the wrong one of the two lands about 130 metres away,
        // which is exactly the error this conversion exists to prevent.
        let reference = OSGridReference.eastingNorthing(from: CLLocationCoordinate2D(latitude: 52.657978, longitude: 1.716053))
        check(reference.map { abs($0.easting - 651409.9) < 6 && abs($0.northing - 313177.3) < 6 } ?? false, "the grid reference conversion is within 6 metres of the Ordnance Survey example (got \(String(describing: reference)))")

        print("   logic tests: \(passes) passed, \(failures) failed")
        exit(failures == 0 ? 0 : 1)
    }
}
#endif
