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
        // The Year page: months joined into runs
        check(YearCalendar.runs(in: [2, 3, 4, 9]) == [MonthRun(first: 2, last: 4), MonthRun(first: 9, last: 9)], "months in a row join into one run and a lone month stays alone")
        check(YearCalendar.runs(in: [4, 2, 3, 3, 0, 13]) == [MonthRun(first: 2, last: 4)], "months are put in order, and repeats and non-months are dropped")
        let wrapped = YearCalendar.runs(in: [10, 11, 12, 1, 2])
        check(wrapped.count == 2 && wrapped[0] == MonthRun(first: 1, last: 2, continuesBefore: true) && wrapped[1] == MonthRun(first: 10, last: 12, continuesAfter: true), "a window over the new year is two runs that know they are joined")
        let allYear = YearCalendar.runs(in: Array(1...12))
        check(allYear == [MonthRun(first: 1, last: 12)], "all twelve months is one run with no loose ends")
        check(YearCalendar.runs(in: [1, 12]).allSatisfy { $0.length == 1 } && YearCalendar.runs(in: [1, 12])[0].continuesBefore, "December and January alone still wrap")
        check(YearCalendar.runs(in: []).isEmpty, "no months, no runs")
        check(YearCalendar.opens([10, 11, 12, 1, 2]) == 10 && YearCalendar.opens([3, 4, 5]) == 3 && YearCalendar.opens(Array(1...12)) == 1 && YearCalendar.opens([]) == 13, "a window opens in the first month that follows a gap")
        check(YearCalendar.words(for: YearCalendar.runs(in: [2, 3, 4, 9])) == "February to April and September", "runs are read out in words")
        check(YearCalendar.words(for: wrapped) == "October to February", "a window over the new year is read as one stretch")
        check(YearCalendar.words(for: allYear) == "all year" && YearCalendar.words(for: []) == "no months", "all year and no months have their own words")
        check(YearCalendar.words(for: YearCalendar.runs(in: [1, 3, 5])) == "January, March and May", "three runs are listed with a comma and an and")
        check(YearCalendar.familyKey("Alliums") == YearCalendar.familyKey(" allium ") && YearCalendar.familyKey("Beans") != YearCalendar.familyKey("Brassicas") && YearCalendar.familyKey("Gas") == "gas", "a family spelt with and without a final s is one family")
        check(YearCalendar.familyTitle(from: ["Allium", "Alliums", "Alliums"]) == "Alliums" && YearCalendar.familyTitle(from: ["Allium", "Alliums"]) == "Alliums" && YearCalendar.familyTitle(from: []) == "", "a family is shown under its commonest spelling")
        let yearPlant = Plant(commonName: "Wild garlic")
        yearPlant.sowOutdoorsMonthsText = "Oct-Feb"; yearPlant.harvestMonthsText = "apr may jun"
        check(YearActivity.sowOutdoors.months(for: yearPlant).sorted() == [1, 2, 10, 11, 12] && YearActivity.harvest.months(for: yearPlant) == [4, 5, 6] && YearActivity.plantOut.months(for: yearPlant).isEmpty, "each job reads its own months from the plant")
        let yearTree = Plant(commonName: "Pear"); yearTree.fruitingMonthsText = "sep oct"
        check(YearActivity.harvest.months(for: yearTree) == [9, 10], "a fruit tree's fruiting months show as its harvest on the Year page")
        yearTree.harvestMonthsText = "oct nov"
        check(YearActivity.harvest.months(for: yearTree) == [9, 10, 11], "harvest and fruiting months together are each counted once")

        // The weather diary
        var london = Calendar(identifier: .gregorian); london.timeZone = TimeZone(identifier: "Europe/London")!
        let diaryNow = london.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 22))!
        check(WeatherDiary.dayKey(for: diaryNow, calendar: london) == "2026-11-12" && WeatherDiary.date(forKey: "2026-11-12", calendar: london).map { london.component(.hour, from: $0) } == 12 && WeatherDiary.date(forKey: "nonsense") == nil, "a day is kept as text and turned back into midday on that day")
        check(WeatherDiary.days(from: "2026-10-31", to: "2026-11-12", calendar: london) == 12, "days are counted across a month end and a clock change")
        check(WeatherDiary.request(complete: [], today: "2026-11-12", calendar: london) == .recent(pastDays: 92), "with nothing held, the full three months are asked for")
        var heldDays = Set((1...92).map { WeatherDiary.dayKey(for: london.date(byAdding: .day, value: -$0, to: diaryNow)!, calendar: london) })
        check(WeatherDiary.request(complete: heldDays, today: "2026-11-12", calendar: london) == .recent(pastDays: 1), "with everything held, only yesterday and today are asked for")
        heldDays.remove("2026-10-29"); heldDays.remove("2026-11-05")
        check(WeatherDiary.request(complete: heldDays, today: "2026-11-12", calendar: london) == .recent(pastDays: 14), "a gap is filled from its earliest missing day")
        check(WeatherDiary.gapRequest(complete: heldDays, today: "2026-11-12", calendar: london) == .archive(start: "2026-10-29", end: "2026-11-05") && WeatherDiary.gapRequest(complete: heldDays.union(["2026-10-29", "2026-11-05"]), today: "2026-11-12", calendar: london) == nil, "older days still missing are asked of the long-term record, and nothing is asked when none are")
        check(WeatherDiary.gapRequest(complete: heldDays.union(["2026-10-29", "2026-11-05"]).subtracting(["2026-11-09"]), today: "2026-11-12", calendar: london) == nil, "a day too new for the long-term record is not asked of it")
        check(WeatherDiary.earlierRequest(earliest: "2026-08-12", calendar: london) == .archive(start: "2025-08-12", end: "2026-08-11") && WeatherDiary.earlierRequest(earliest: nil) == nil, "earlier weather is the year before the first day held")
        let recentURL = WeatherDiary.url(for: .recent(pastDays: 500), latitude: 51.50017, longitude: -2.5577, timeZone: london.timeZone)?.absoluteString ?? ""
        check(recentURL.hasPrefix("https://api.open-meteo.com/v1/forecast?") && recentURL.contains("past_days=92") && recentURL.contains("latitude=51.500") && !recentURL.contains("51.50017") && recentURL.contains("soil_temperature_6cm") && (recentURL.contains("Europe/London") || recentURL.contains("Europe%2FLondon")), "the ordinary address is asked for at most 92 days, with the place rounded")
        let archiveURL = WeatherDiary.url(for: .archive(start: "2025-08-12", end: "2026-08-11"), latitude: 51.5, longitude: -2.55, timeZone: london.timeZone)?.absoluteString ?? ""
        check(archiveURL.hasPrefix("https://archive-api.open-meteo.com/v1/archive?") && archiveURL.contains("start_date=2025-08-12") && archiveURL.contains("soil_temperature_0_to_7cm"), "older days are asked of the long-term record, which names its soil layer differently")

        // A reply shaped like the real one: two finished days, today and tomorrow.
        func weatherReply(soilName: String = "soil_temperature_6cm") -> Data {
            let dayKeys = ["2026-11-10", "2026-11-11", "2026-11-12", "2026-11-13"]
            let times = dayKeys.flatMap { day in (0..<24).map { "\"\(day)T\(String(format: "%02d", $0)):00\"" } }.joined(separator: ",")
            func hourly(_ make: (Int, Int) -> String) -> String { (0..<4).flatMap { d in (0..<24).map { make(d, $0) } }.joined(separator: ",") }
            let text = """
            {"latitude":51.5,"daily":{"time":["2026-11-10","2026-11-11","2026-11-12","2026-11-13"],"temperature_2m_min":[5.9,-1.2,1.8,3.0],"temperature_2m_max":[7.2,10.0,7.2,8.0],"precipitation_sum":[6.8,1.5,0.0,0.2],"wind_speed_10m_max":[17.3,14.4,20.2,9.0],"sunshine_duration":[0.0,0.0,23647.65,100],"et0_fao_evapotranspiration":[0.33,0.43,0.85,0.5],"weather_code":[61,51,3,0]},
            "hourly":{"time":[\(times)],"temperature_2m":[\(hourly { d, h in "\(Double(d) + Double(h) / 10)" })],"precipitation":[\(hourly { d, h in d == 0 && h == 9 ? "2.5" : "0.0" })],"cloud_cover":[\(hourly { _, h in h < 12 ? "100" : "0" })],"wind_speed_10m":[\(hourly { _, _ in "10.0" })],"\(soilName)":[\(hourly { d, h in d == 1 && h == 0 ? "null" : "6.0" })]}}
            """
            return Data(text.utf8)
        }
        let weatherReadings = (try? WeatherDiary.readings(from: weatherReply())) ?? []
        check(weatherReadings.count == 4 && weatherReadings[0].dayKey == "2026-11-10" && weatherReadings[0].minTemperatureC == 5.9 && weatherReadings[0].rainfallMM == 6.8 && weatherReadings[0].weatherCode == 61, "a reply becomes one reading a day")
        check(abs((weatherReadings[2].sunshineHours ?? 0) - 6.57) < 0.01 && weatherReadings[1].hourly.soilC[0] == nil, "sunshine is turned from seconds into hours, and a missing figure stays missing")
        check(weatherReadings[0].hourly.temperatureC.count == 24 && weatherReadings[1].hourly.temperatureC.first == 1.0 && weatherReadings[0].hourly.rainMM[9] == 2.5 && weatherReadings[1].hourly.soilC[0] == nil && weatherReadings[1].soilTemperatureC == 6.0, "each day gets its own 24 hours, and soil temperature is the average of the hours that have one")
        check(((try? WeatherDiary.readings(from: weatherReply(soilName: "soil_temperature_0_to_7cm"))) ?? []).first?.soilTemperatureC == 6.0, "the long-term record's soil layer is read too")
        let morning = weatherReadings[0].hourly.conditions(atHour: 9), evening = weatherReadings[0].hourly.conditions(atHour: 21)
        check(morning?.temperatureC == 0.9 && morning?.precipitationMM == 2.5 && morning?.skyCondition != .sunny && evening?.skyCondition == .sunny && weatherReadings[0].hourly.conditions(atHour: 24) == nil, "the conditions at any hour of a day can be looked up")
        check((try? WeatherDiary.readings(from: Data(#"{"error":true,"reason":"Too many requests"}"#.utf8))) == nil, "a refusal from the service is an error, not an empty day")

        let weatherStore = ModelContext()
        check(WeatherDiary.store(weatherReadings, site: "allotment", source: "recent", today: "2026-11-12", into: weatherStore, calendar: london) == 3, "today and the days before are stored, and tomorrow is not")
        var storedDays = ((try? weatherStore.fetch(FetchDescriptor<WeatherDay>())) ?? []).sorted { $0.dayKey < $1.dayKey }
        check(storedDays.map(\.isComplete) == [true, true, false] && storedDays[1].hadFrost && !storedDays[0].hadFrost && WeatherDiary.hours(of: storedDays[0])?.rainMM[9] == 2.5, "finished days are complete, today is not, and the hours come back out")
        storedDays[0].rainfallMM = 99
        check(WeatherDiary.store(weatherReadings, site: "allotment", source: "recent", today: "2026-11-13", into: weatherStore, calendar: london) == 2 && storedDays[0].rainfallMM == 99 && storedDays[2].isComplete && ((try? weatherStore.fetch(FetchDescriptor<WeatherDay>())) ?? []).count == 4, "a second fetch finishes today, adds the new day and leaves complete days alone")
        check(WeatherDiary.store(weatherReadings, site: "garden", source: "recent", today: "2026-11-12", into: weatherStore, calendar: london) == 3, "another garden keeps its own days")
        var blankDay = weatherReadings[0]; blankDay.dayKey = "2026-09-01"; blankDay.minTemperatureC = nil
        var holedDay = weatherReadings[0]; holedDay.dayKey = "2026-09-02"; holedDay.rainfallMM = nil
        check(WeatherDiary.store([blankDay, holedDay], site: "garden", source: "recent", today: "2026-11-12", into: weatherStore, calendar: london) == 0, "a day the service left blank, or a finished day with no rain figure, is not stored")
        storedDays = (try? weatherStore.fetch(FetchDescriptor<WeatherDay>())) ?? []
        check(WeatherDiary.recordFrosts(from: storedDays, into: weatherStore, calendar: london) == 1 && WeatherDiary.recordFrosts(from: storedDays, into: weatherStore, calendar: london) == 0, "a frosty day is recorded as a frost once, even when two gardens had it")
        let foundFrost = ((try? weatherStore.fetch(FetchDescriptor<FrostRecord>())) ?? []).first
        check(foundFrost?.minimumTemperatureC == -1.2 && foundFrost?.kind == .firstAutumnFrost && WeatherDiary.frostKind(month: 4) == .lastSpringFrost && WeatherDiary.frostKind(month: 1) == .other, "the frost keeps its temperature and its season")

        let home = Garden(name: "Home", siteKey: "home"); home.latitude = 51.5; home.longitude = -2.55; home.displayOrder = 0
        let nextDoor = Garden(name: "Next door", siteKey: "next"); nextDoor.latitude = 51.505; nextDoor.longitude = -2.55
        let farAway = Garden(name: "Orchard", siteKey: "orchard"); farAway.latitude = 51.7; farAway.longitude = -2.4
        let noPlace = Garden(name: "Unmeasured", siteKey: "none")
        check(WeatherDiary.places(for: [home, nextDoor, farAway, noPlace]).map(\.site) == ["home", "orchard"], "gardens within a mile share one diary, and a garden with no location has none")
        check(WeatherDiary.words(forCode: 61) == "Light rain" && WeatherDiary.words(forCode: 0) == "Clear" && WeatherDiary.words(forCode: nil) == nil && WeatherDiary.degrees(-0.3) == "0°" && WeatherDiary.degrees(-1.6) == "-2°", "weather codes and temperatures are put into words")
        check(WeatherDiary.summary(of: storedDays.first { $0.dayKey == "2026-11-12" }!) == "Low 2°, high 7°. Dry. 6.6 hours of sun.", "a day reads as a sentence")

        // The whole run, with a stand-in for the network
        let diaryStore = ModelContext(); diaryStore.insert(home)
        let diaryDefaults = UserDefaults(suiteName: "windfall-weather-\(UUID().uuidString)")!
        var asked: [String] = []
        let diaryService = WeatherDiaryService(defaults: diaryDefaults, fetch: { url in asked.append(url.absoluteString); return weatherReply() })
        await diaryService.bringUpToDate(in: diaryStore, now: diaryNow, calendar: london)
        check(asked.count == 2 && asked[0].contains("past_days=92") && asked[1].contains("archive-api") && asked[1].contains("end_date=2026-11-06") && ((try? diaryStore.fetch(FetchDescriptor<WeatherDay>())) ?? []).count == 3 && ((try? diaryStore.fetch(FetchDescriptor<FrostRecord>())) ?? []).count == 1 && diaryService.lastError == nil, "opening the app fills the diary and finds the frost")
        await diaryService.bringUpToDate(in: diaryStore, now: diaryNow.addingTimeInterval(600), calendar: london)
        check(asked.count == 2, "the service is not asked again within the hour")
        await diaryService.bringUpToDate(in: diaryStore, now: diaryNow.addingTimeInterval(600), force: true, calendar: london)
        check(asked.count == 4 && ((try? diaryStore.fetch(FetchDescriptor<WeatherDay>())) ?? []).count == 3, "asking by hand fetches again and doubles nothing")
        let emptied = ModelContext(); emptied.insert(home)
        await diaryService.bringUpToDate(in: emptied, now: diaryNow.addingTimeInterval(900), calendar: london)
        check(asked.count == 6 && ((try? emptied.fetch(FetchDescriptor<WeatherDay>())) ?? []).count == 3, "an empty diary is filled at once, even if the service was asked a moment ago")
        let failing = WeatherDiaryService(defaults: diaryDefaults, fetch: { _ in throw WeatherDiary.ReplyError(message: "offline") })
        await failing.bringUpToDate(in: diaryStore, now: diaryNow, force: true, calendar: london)
        check(failing.lastError == "offline" && ((try? diaryStore.fetch(FetchDescriptor<WeatherDay>())) ?? []).count == 3, "with no connection the diary keeps what it has and says why")
        let emptyService = WeatherDiaryService(defaults: diaryDefaults, fetch: { _ in asked.append("x"); return weatherReply() })
        await emptyService.bringUpToDate(in: ModelContext(), now: diaryNow, calendar: london)
        check(asked.count == 6 && emptyService.lastMessage == "No garden has a location yet.", "with no garden location nothing is fetched")

        // Month text is read once and remembered
        check(MonthParser.months(in: "Sept, Oct") == [9, 10] && MonthParser.months(in: "Sept, Oct") == [9, 10] && MonthParser.months(in: "september") == [9] && MonthParser.months(in: "Oct-Feb") == [10, 11, 12, 1, 2] && MonthParser.months(in: nil).isEmpty && MonthParser.months(in: "").isEmpty, "reading the same month text twice gives the same answer, and long and short names agree")

        // The Plants screen's filters
        check(PlantKind.of(group: "Fruit") == .fruit && PlantKind.of(group: "Brassicas") == .vegetables && PlantKind.of(group: "Root veg") == .vegetables && PlantKind.of(group: "Allium") == .vegetables && PlantKind.of(group: "Leaves") == .vegetables, "fruit and vegetable groups are recognised, in either spelling")
        check(PlantKind.of(group: "Herbs") == .herbs && PlantKind.of(group: "Wildflower") == .flowers && PlantKind.of(group: "Green manure") == .greenManure && PlantKind.of(group: "Shrub") == .flowers, "herbs, flowers and green manure are recognised")
        check(PlantKind.of(group: nil) == .unsorted && PlantKind.of(group: "  ") == .unsorted && PlantKind.of(group: "Something new") == .unsorted, "a missing or unknown group is not sorted, not guessed")
        check(PlantFilter.layerKey(" Herbaceous ") == "herbaceous" && PlantFilter.layerKey("") == nil && PlantFilter.layerRank("trees") < PlantFilter.layerRank("shrubs") && PlantFilter.layerRank("shrubs") < PlantFilter.layerRank("herbaceous") && PlantFilter.layerRank("herbaceous") < PlantFilter.layerRank("ground cover") && PlantFilter.layerRank("ground cover") < PlantFilter.layerRank("vines") && PlantFilter.layerRank("something") > PlantFilter.layerRank("vines"), "layers keep their spelling and go from the canopy down")
        let apple = Plant(commonName: "Apple"); apple.variety = "Spartan"; apple.group = "Fruit"; apple.layer = "Trees"; apple.isPollinator = true
        apple.floweringMonthsText = "apr may"; apple.fruitingMonthsText = "sep oct"
        let kale = Plant(commonName: "Kale"); kale.group = "Brassicas"; kale.sowIndoorsMonthsText = "mar"; kale.sowOutdoorsMonthsText = "apr may"; kale.harvestMonthsText = "oct nov dec"
        let leek = Plant(commonName: "Leek"); leek.group = "Allium"; leek.layer = "Herbaceous"; leek.sowIndoorsMonthsText = "feb mar"
        let onion = Plant(commonName: "Onion"); onion.group = "Alliums"; onion.status = .wanted
        let clover = Plant(commonName: "Clover"); clover.group = "Green manure"; clover.layer = "Ground Cover"; clover.isNitrogenFixer = true; clover.isPollinator = true; clover.floweringMonthsText = "may jun jul"
        let mystery = Plant(commonName: "Aster")
        let shelf = [apple, kale, leek, onion, clover, mystery]
        var plantFilter = PlantFilter()
        check(plantFilter.filter(shelf, today: 11).map(\.commonName) == ["Apple", "Kale", "Leek", "Clover", "Aster"] && !plantFilter.isNarrowed, "at first only growing plants show, and nothing counts as chosen")
        plantFilter.kind = .vegetables
        check(plantFilter.filter(shelf, today: 11).map(\.commonName) == ["Kale", "Leek"] && plantFilter.isNarrowed, "vegetables are kale and leek, and the filter now counts as chosen")
        check(plantFilter.familyChoices(shelf, today: 11).map(\.title) == ["Allium", "Brassicas"], "with vegetables chosen only vegetable families are offered")
        plantFilter.status = nil
        let families = plantFilter.familyChoices(shelf, today: 11)
        check(families.map(\.title) == ["Alliums", "Brassicas"] && families.first?.count == 2 && families.first?.key == "allium", "two spellings of one family are offered once, under the commoner spelling, with both plants counted")
        plantFilter.family = "allium"
        check(plantFilter.filter(shelf, today: 11).map(\.commonName) == ["Leek", "Onion"], "choosing a family shows every plant in it")
        plantFilter = PlantFilter(); plantFilter.kind = .unsorted
        check(plantFilter.filter(shelf, today: 11).map(\.commonName) == ["Aster"], "plants with no group can be found")
        plantFilter = PlantFilter(); plantFilter.layer = "herbaceous"
        check(plantFilter.filter(shelf, today: 11).map(\.commonName) == ["Leek"], "a layer matches whatever its capitals")
        check(PlantFilter().layerChoices(shelf, today: 11).map(\.title) == ["Trees", "Herbaceous", "Ground Cover"], "layers are offered from the canopy down, only where plants have them")
        plantFilter = PlantFilter(); plantFilter.season = .cropping
        check(plantFilter.filter(shelf, today: 11).map(\.commonName) == ["Kale"] && plantFilter.filter(shelf, today: 10).map(\.commonName) == ["Apple", "Kale"], "fruiting or harvest reads both the harvest and the fruiting months, in this month")
        plantFilter.seasonMonth = 9
        check(plantFilter.filter(shelf, today: 11).map(\.commonName) == ["Apple"], "a chosen month is used in place of this month")
        plantFilter = PlantFilter(); plantFilter.season = .sowing
        check(plantFilter.filter(shelf, today: 3).map(\.commonName) == ["Kale", "Leek"] && plantFilter.filter(shelf, today: 5).map(\.commonName) == ["Kale"], "sowing means indoors or outdoors")
        plantFilter.season = .sowOutdoors
        check(plantFilter.filter(shelf, today: 3).isEmpty, "sowing outdoors does not count sowing indoors")
        let seasons = PlantFilter().seasonChoices(shelf, today: 5)
        check(seasons.first { $0.key == PlantSeason.flowering.rawValue }?.count == 2 && seasons.first { $0.key == PlantSeason.sowing.rawValue }?.count == 1, "each season says how many plants it has this month")
        plantFilter = PlantFilter(); plantFilter.roles = [.pollinator]
        check(plantFilter.filter(shelf, today: 11).map(\.commonName) == ["Apple", "Clover"], "a role shows only plants that have it")
        plantFilter.roles.insert(.nitrogenFixer)
        check(plantFilter.filter(shelf, today: 11).map(\.commonName) == ["Clover"], "two roles mean both")
        check(PlantFilter().roleChoices(shelf, today: 11).first { $0.key == PlantRole.pollinator.rawValue }?.count == 2, "a role says how many plants it would show")
        plantFilter = PlantFilter(); plantFilter.search = "  spart "
        check(plantFilter.filter(shelf, today: 11).map(\.commonName) == ["Apple"] && !plantFilter.isNarrowed, "search looks in the variety, and typing alone does not count as a filter")
        plantFilter = PlantFilter(); plantFilter.kind = .fruit; plantFilter.status = nil
        let checkingDefaults = UserDefaults(suiteName: "windfall-filter-\(UUID().uuidString)")!
        check(PlantFilter.fromLaunchArguments(checkingDefaults) == .standard, "with no checking aid the filter starts as standard")
        checkingDefaults.set("Vegetables", forKey: "plantsKind"); checkingDefaults.set("Brassicas", forKey: "plantsFamily"); checkingDefaults.set("Sowing", forKey: "plantsSeason"); checkingDefaults.set(4, forKey: "plantsMonth"); checkingDefaults.set("Pollinator", forKey: "plantsRole")
        let fromArguments = PlantFilter.fromLaunchArguments(checkingDefaults)
        check(fromArguments.kind == .vegetables && fromArguments.family == "brassica" && fromArguments.season == .sowing && fromArguments.seasonMonth == 4 && fromArguments.roles == [.pollinator], "the checking aid sets each filter from launch arguments")
        check(plantFilter.kindChoices(shelf, today: 11).map(\.count) == [1, 3, 1, 1] && plantFilter.kindChoices(shelf, today: 11).map(\.key) == ["Fruit", "Vegetables", "Green manure", "Not sorted"], "kind counts ignore the kind already chosen, so each says what it would show")
        // What is on screen is passed to the model, and only to the model
        conversation.screenNote = "the plant Apple, Spartan"
        conversation.send("What grows well beside this?"); await waitUntilIdle(conversation)
        check(engine.prompts.last?.contains("the plant Apple, Spartan") == true && engine.prompts.last?.hasSuffix("What grows well beside this?") == true, "the model is told what is on screen, ahead of the question")
        check(conversation.messages.last(where: { $0.role == .user })?.content == "What grows well beside this?", "the question on screen stays as it was typed")
        let promptsBeforeNote = engine.prompts.count
        conversation.send("Are these mushrooms safe to eat?"); await waitUntilIdle(conversation)
        check(engine.prompts.count == promptsBeforeNote, "a fixed safety reply still wins when something is on screen")
        conversation.screenNote = nil
        conversation.send("And now?"); await waitUntilIdle(conversation)
        check(engine.prompts.last == "And now?", "with nothing on screen the question goes as typed")
        // The tracker of which screen is on top
        let tracker = EiraScreen()
        let rootID = UUID(), detailID = UUID()
        tracker.show(EiraSight(short: nil, full: "the plant library"), id: rootID)
        tracker.show(EiraSight(short: "Apple, Spartan", full: "the plant Apple, Spartan"), id: detailID)
        check(tracker.current?.short == "Apple, Spartan", "the newest screen is the one being looked at")
        tracker.hide(id: detailID)
        check(tracker.current?.full == "the plant library", "closing a screen goes back to the one beneath")
        tracker.show(EiraSight(short: "Apple, Spartan", full: "the plant Apple, Spartan"), id: detailID)
        tracker.hide(id: rootID)
        tracker.show(EiraSight(short: nil, full: "the plant library"), id: rootID)
        check(tracker.current?.full == "the plant library", "a screen that comes back goes on top")
        tracker.hide(id: rootID); tracker.hide(id: detailID)
        check(tracker.current == nil, "with every screen gone there is nothing to tell")
        check(EiraSight.name("Apple", variety: "Spartan") == "Apple, Spartan" && EiraSight.name("Chervil", variety: " ") == "Chervil" && EiraSight.name("Chervil", variety: nil) == "Chervil", "a name carries its variety only when it has one")
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
            // The Plants screen's filters against the real library
            let everyStatus = { () -> PlantFilter in var f = PlantFilter(); f.status = nil; return f }()
            let kindCounts = Dictionary(uniqueKeysWithValues: everyStatus.kindChoices(plants, today: 11).map { ($0.key, $0.count) })
            check((kindCounts["Fruit"] ?? 0) > 50 && (kindCounts["Vegetables"] ?? 0) > 50 && (kindCounts["Herbs"] ?? 0) > 20 && (kindCounts["Flowers"] ?? 0) > 50, "the real library has fruit, vegetables, herbs and flowers (\(kindCounts))")
            check(kindCounts.values.reduce(0, +) == plants.count, "every plant in the library is in exactly one kind")
            check(everyStatus.layerChoices(plants, today: 11).map(\.title) == ["Trees", "Shrubs", "Herbaceous", "Ground Cover", "Vines"], "the real layers are offered from the canopy down (\(everyStatus.layerChoices(plants, today: 11).map(\.title)))")
            var brassicaFilter = everyStatus; brassicaFilter.family = "brassica"
            check(brassicaFilter.filter(plants, today: 11).count >= 10 && brassicaFilter.filter(plants, today: 11).allSatisfy { PlantKind.of(group: $0.group) == .vegetables }, "the brassicas can be picked out, and all are vegetables")
            print("   (plant filters on the real library: \(kindCounts.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")); families: \(everyStatus.familyChoices(plants, today: 11).map { "\($0.title) \($0.count)" }.joined(separator: ", ")))")

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

        // MARK: Sun and shade
        func near(_ a: Double, _ b: Double, _ tolerance: Double) -> Bool { abs(a - b) <= tolerance }
        let bristol = 51.8

        check(near(Sun.declination(dayOfYear: 81), 0, 0.5), "the sun is over the equator at the March equinox")
        check(near(Sun.declination(dayOfYear: 172), 23.45, 0.1) && near(Sun.declination(dayOfYear: 355), -23.45, 0.1), "the sun's tilt is about 23.4 degrees at the solstices")
        check(near(Sun.noonAltitude(latitude: bristol, dayOfYear: 81), 38.2, 0.5), "midday sun at the equinox is 90 minus the latitude")
        check(near(Sun.noonAltitude(latitude: bristol, dayOfYear: 172), 61.6, 0.5), "midday sun at midsummer is about 62 degrees")
        check(near(Sun.noonAltitude(latitude: bristol, dayOfYear: 355), 14.8, 0.5), "midday sun at midwinter is about 15 degrees")
        check(near(Sun.position(latitude: bristol, dayOfYear: 172, solarHour: 12).azimuth, 180, 0.01), "the midday sun is due south")
        check(Sun.position(latitude: bristol, dayOfYear: 172, solarHour: 9).azimuth < 180 && Sun.position(latitude: bristol, dayOfYear: 172, solarHour: 15).azimuth > 180, "the sun is in the east in the morning and the west in the afternoon")
        check(near(Sun.dayLength(latitude: bristol, dayOfYear: 81), 12, 0.1), "day and night are equal at the equinox")
        check(near(Sun.dayLength(latitude: bristol, dayOfYear: 172), 16.5, 0.2) && near(Sun.dayLength(latitude: bristol, dayOfYear: 355), 7.5, 0.2), "midsummer days are about sixteen and a half hours, midwinter about seven and a half")
        let midsummer = Sun.sunriseAndSunset(latitude: bristol, dayOfYear: 172)
        let sunrise = Sun.position(latitude: bristol, dayOfYear: 172, solarHour: midsummer.sunrise)
        check(near(sunrise.altitude, 0, 0.5) && near(sunrise.azimuth, 50, 1.5), "the midsummer sun rises in the north-east")
        check(near(Sun.position(latitude: bristol, dayOfYear: 81, solarHour: 6).azimuth, 90, 1), "the equinox sun rises due east")
        check(Sun.dayLength(latitude: 80, dayOfYear: 355) == 0 && Sun.dayLength(latitude: 80, dayOfYear: 172) == 24, "polar night and the midnight sun are handled")
        check(near(Sun.position(latitude: -34, dayOfYear: 355, solarHour: 12).azimuth, 0, 0.01) || near(Sun.position(latitude: -34, dayOfYear: 355, solarHour: 12).azimuth, 360, 0.01), "south of the equator the midday sun is in the north")
        check(near(Sun.equationOfTimeMinutes(dayOfYear: 307), 16.4, 1) && near(Sun.equationOfTimeMinutes(dayOfYear: 42), -14.2, 1), "a sundial runs about 16 minutes fast in early November and 14 slow in February")
        check(near(Sun.solarHour(utcHour: 12, longitude: -2.6, dayOfYear: 307), 12.10, 0.02), "clock time becomes time by the sun")
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let juneNoon = utc.date(from: DateComponents(year: 2027, month: 6, day: 21, hour: 12, minute: 10))!
        check(near(Sun.position(latitude: bristol, longitude: -2.6, at: juneNoon).altitude, 61.6, 0.6), "the sun's position can be worked out from a date")

        check(Compass.name(forBearing: 0) == "north" && Compass.name(forBearing: 220) == "south-west" && Compass.name(forBearing: 200) == "south" && Compass.name(forBearing: 350) == "north" && Compass.name(forBearing: -90) == "west", "bearings are named to the nearest of eight points")
        check(Compass.difference(350, 10) == 20 && Compass.normalised(-90) == 270, "bearings wrap round at north")

        // Shapes on the plan
        let north = PlanGeometry.step(towardsBearing: 0, topFaces: 0)
        check(near(north.x, 0, 1e-9) && near(north.y, -1, 1e-9), "with north at the top, north is up the plan")
        let northWhenTopIsEast = PlanGeometry.step(towardsBearing: 0, topFaces: 90)
        check(near(northWhenTopIsEast.x, -1, 1e-9) && near(northWhenTopIsEast.y, 0, 1e-9), "with east at the top, north is to the left")
        let square = PlanGeometry.rectangle(x: 2, y: 3, length: 4, width: 1)
        check(square == [PlanPoint(x: 2, y: 3), PlanPoint(x: 6, y: 3), PlanPoint(x: 6, y: 4), PlanPoint(x: 2, y: 4)], "a rectangle's corners are measured from its first corner")
        let quarterTurn = PlanGeometry.rectangle(x: 2, y: 3, length: 4, width: 1, rotation: 90)
        check(near(quarterTurn[0].x, 2, 1e-9) && near(quarterTurn[0].y, 3, 1e-9) && near(quarterTurn[1].x, 2, 1e-9) && near(quarterTurn[1].y, 7, 1e-9), "turning a bed keeps its first corner where it was measured")
        check(PlanGeometry.contains(PlanPoint(x: 3, y: 3.5), in: square) && !PlanGeometry.contains(PlanPoint(x: 7, y: 3.5), in: square), "a point is found inside or outside an outline")
        check(PlanGeometry.overlap(square, PlanGeometry.rectangle(x: 5, y: 3.5, length: 4, width: 1)), "two beds on top of each other are noticed")
        check(!PlanGeometry.overlap(square, PlanGeometry.rectangle(x: 2, y: 4, length: 4, width: 1)) && !PlanGeometry.overlap(square, PlanGeometry.rectangle(x: 2, y: 4.6, length: 4, width: 1)), "beds side by side or with a path between do not count as overlapping")
        check(PlanGeometry.overlap(square, PlanGeometry.rectangle(x: 3, y: 2, length: 3, width: 1.2, rotation: 45)), "a turned bed crossing another is noticed")
        let tree = PlanGeometry.ellipse(x: 0, y: 0, length: 4, width: 4)
        check(tree.count == 16 && PlanGeometry.contains(PlanPoint(x: 2, y: 2), in: tree) && !PlanGeometry.contains(PlanPoint(x: 0.2, y: 0.2), in: tree), "a tree is round, so the corner of its box is outside it")
        let stacked = PlanGeometry.stackedPositions(sizes: [(length: 4, width: 1.2), (length: 4, width: 1.2), (length: 3, width: 2)])
        check(stacked.count == 3 && near(stacked[1].y - stacked[0].y, 1.8, 1e-9) && near(stacked[2].y - stacked[1].y, 1.8, 1e-9), "unplaced beds are stacked with a path between")

        // Shadows
        let equinoxNoon = Sun.position(latitude: bristol, dayOfYear: 81, solarHour: 12)
        let wall = PlanShape(corners: PlanGeometry.rectangle(x: 0, y: 10, length: 10, width: 0.2), height: 2)
        let noonShadow = PlanGeometry.shadow(of: wall, sun: equinoxNoon, topFaces: 0) ?? []
        let reach = 10 - (noonShadow.map(\.y).min() ?? 10)
        check(near(reach, 2 / tan(Sun.radians(equinoxNoon.altitude)), 0.01) && near(reach, 2.54, 0.05), "a two metre wall casts about two and a half metres of shade at midday in March")
        check(near(noonShadow.map(\.y).max() ?? 0, 10.2, 1e-6), "the shadow falls north of the wall, not south")
        check(PlanGeometry.shadow(of: wall, sun: SunPosition(altitude: -3, azimuth: 0), topFaces: 0) == nil, "there is no shadow at night")
        check(PlanGeometry.shadow(of: PlanShape(corners: wall.corners, height: 0), sun: equinoxNoon, topFaces: 0) == nil, "something with no height casts no shadow")
        let turnedShadow = PlanGeometry.shadow(of: wall, sun: equinoxNoon, topFaces: 180) ?? []
        check(near((turnedShadow.map(\.y).max() ?? 0) - 10.2, 2.54, 0.05), "turn the plan round and the shadow falls the other way")
        let lateShadow = PlanGeometry.shadow(of: wall, sun: Sun.position(latitude: bristol, dayOfYear: 81, solarHour: 16), topFaces: 0) ?? []
        check((lateShadow.map(\.x).max() ?? 0) > 12, "afternoon shadows stretch to the east")

        // Hours of sun
        let openBed = PlanGeometry.samplePoints(x: 0, y: 0, length: 4, width: 1.2)
        let open = Shade.sunHours(on: openBed, obstacles: [], topFaces: 0, latitude: bristol, dayOfYear: 172)
        check(open.direct == open.possible && open.possible > 14 && open.possible < 16.5 && open.label == "full sun", "a bed in the open gets sun all day (\(open.direct) hours at midsummer)")
        let bedNorthOfWall = PlanGeometry.samplePoints(x: 3, y: 8.3, length: 4, width: 1.2)
        let bedSouthOfWall = PlanGeometry.samplePoints(x: 3, y: 10.7, length: 4, width: 1.2)
        let shadedWinter = Shade.sunHours(on: bedNorthOfWall, obstacles: [wall], topFaces: 0, latitude: bristol, dayOfYear: 355)
        let shadedSummer = Shade.sunHours(on: bedNorthOfWall, obstacles: [wall], topFaces: 0, latitude: bristol, dayOfYear: 172)
        let sunnyWinter = Shade.sunHours(on: bedSouthOfWall, obstacles: [wall], topFaces: 0, latitude: bristol, dayOfYear: 355)
        check(shadedWinter.direct < 0.5 && shadedWinter.label == "shade", "a bed just north of a wall gets almost no winter sun (\(shadedWinter.direct) hours)")
        check(shadedSummer.direct > 8, "the same bed gets plenty in summer, when the sun is high (\(shadedSummer.direct) hours)")
        check(sunnyWinter.direct == sunnyWinter.possible && sunnyWinter.possible > 3, "a bed south of the wall is not shaded by it (\(sunnyWinter.direct) hours)")
        let byMonth = Shade.monthlySunHours(on: bedNorthOfWall, obstacles: [wall], topFaces: 0, latitude: bristol)
        check(byMonth.count == 12 && byMonth[5].direct > byMonth[2].direct && byMonth[2].direct > byMonth[11].direct, "sun on a shaded bed rises from winter to summer")

        // Gardens, features and beds as records
        let plot = ModelContext()
        check(GardenPlan.ensureStartingGardens(in: plot) == 2 && GardenPlan.ensureStartingGardens(in: plot) == 0, "the two starting gardens are made once and not again")
        let gardens = (try? plot.fetch(FetchDescriptor<Garden>())) ?? []
        check(Set(gardens.map(\.siteKey)) == ["allotment", "permaculture"] && gardens.contains { $0.name == "Permaculture garden" }, "their keys match what existing beds already store")
        let allotment = gardens.first { $0.siteKey == "allotment" }!
        allotment.widthMetres = 25; allotment.depthMetres = 10; allotment.latitude = bristol
        allotment.slopeDownDegrees = 180; allotment.slopeSteepness = .gentle; allotment.soil = .clay
        check(allotment.slopeDescription == "Slopes gently down to the south" && allotment.facingDescription == "Top of the plan faces north" && Garden(name: "New").slopeDescription == "Flat", "a garden describes its slope and which way it faces")
        check(Garden(name: "A").siteKey != Garden(name: "B").siteKey, "each new garden gets its own key")

        let bedOne = Bed(name: "Bed 1"), bedTwo = Bed(name: "Bed 2"), bedThree = Bed(name: "Bed 3", site: .permaculture)
        bedOne.displayOrder = 1; bedTwo.displayOrder = 2
        for bed in [bedOne, bedTwo, bedThree] { bed.lengthMetres = 4; bed.widthMetres = 1.2; plot.insert(bed) }
        check(GardenPlan.overlappingBeds([bedOne, bedTwo, bedThree], siteKey: "allotment").count == 1, "new beds all start in the corner, on top of each other")
        check(GardenPlan.placeUnpositionedBeds([bedOne, bedTwo, bedThree], siteKey: "allotment") == 2 && GardenPlan.overlappingBeds([bedOne, bedTwo, bedThree], siteKey: "allotment").isEmpty, "unplaced beds are spread out so none overlap")
        check(bedThree.originX == 0 && bedThree.originY == 0, "beds in another garden are left alone")
        bedOne.originX = 3; bedOne.originY = 8.3
        check(GardenPlan.placeUnpositionedBeds([bedOne, bedTwo, bedThree], siteKey: "allotment") == 0 && bedOne.originY == 8.3, "beds that have been placed are never moved")
        check(Compass.name(forBearing: bedOne.longSideFaces(in: allotment)) == "south", "a bed running east to west has a long side facing south")
        bedTwo.rotationDegrees = 90
        check(["east", "west"].contains(Compass.name(forBearing: bedTwo.longSideFaces(in: allotment))), "a bed running north to south faces east and west")
        bedTwo.rotationDegrees = 0

        let hedge = GardenFeature(name: "Hedge", kind: .hedge, siteKey: "allotment")
        hedge.originX = 0; hedge.originY = 10; hedge.lengthMetres = 10; hedge.widthMetres = 0.2; hedge.heightMetres = 2
        let ash = GardenFeature(name: "Neighbour's ash", kind: .tree, siteKey: "allotment")
        ash.originX = 21; ash.originY = 11; ash.lengthMetres = 4; ash.widthMetres = 4
        let cage = GardenFeature(name: "Fruit cage", kind: .other, siteKey: "allotment")
        cage.heightMetres = 2; cage.blocksLight = false
        let pond = GardenFeature(name: "Pond", kind: .water, siteKey: "allotment")
        for feature in [hedge, ash, cage, pond] { plot.insert(feature) }
        check(ash.heightMetres == 4 && pond.heightMetres == 0 && hedge.kind.displayName == "Hedge", "a new feature starts with a typical height for its kind")
        check(ash.isOutside(allotment) && !hedge.isOutside(allotment) && ash.outline.count == 16, "a neighbour's tree beyond the boundary is outside the plot, and round")
        check(cage.shadeShape == nil && pond.shadeShape == nil && hedge.shadeShape != nil, "see-through and flat things cast no shade")
        let shapes = GardenPlan.shadeShapes(beds: [bedOne, bedTwo, bedThree], features: [hedge, ash, cage, pond], siteKey: "allotment", excluding: bedOne)
        check(shapes.count == 2, "only the hedge and the tree shade this garden")
        bedTwo.heightMetres = 0.4
        check(GardenPlan.shadeShapes(beds: [bedOne, bedTwo, bedThree], features: [], siteKey: "allotment", excluding: bedTwo).isEmpty && GardenPlan.shadeShapes(beds: [bedOne, bedTwo, bedThree], features: [], siteKey: "allotment", excluding: bedOne).count == 1, "a raised bed casts shade on others, never on itself")
        hedge.removedAt = .now
        check(hedge.shadeShape == nil, "a hedge that has been taken out no longer shades anything")
        hedge.removedAt = nil
        let bedSun = GardenPlan.monthlySunHours(for: bedOne, in: allotment, beds: [bedOne, bedTwo, bedThree], features: [hedge, ash, cage, pond])
        check(bedSun?.count == 12 && (bedSun?[11].direct ?? 9) < 1 && (bedSun?[5].direct ?? 0) > 8, "a bed behind the hedge gets little sun in December and plenty in June")
        check(GardenPlan.monthlySunHours(for: bedOne, in: Garden(name: "Unknown"), beds: [], features: []) == nil, "sun hours are not guessed for a garden with no location")
        let allBeds = [bedOne, bedTwo, bedThree], allFeatures = [hedge, ash, cage, pond]
        for dayOfYear in [Sun.midMonthDays[0], Sun.midMonthDays[5], Sun.midMonthDays[10]] {
            let together = GardenPlan.sunHours(forBedsIn: allotment, beds: allBeds, features: allFeatures, dayOfYear: dayOfYear) ?? [:]
            let oneByOne = allBeds.map { bed in
                Shade.sunHours(on: bed.samplePoints, obstacles: GardenPlan.shadeShapes(beds: allBeds, features: allFeatures, siteKey: "allotment", excluding: bed), topFaces: allotment.topFacesDegrees, latitude: bristol, dayOfYear: dayOfYear, stepMinutes: 15)
            }
            check(together.count == 2 && together[bedOne.id] == oneByOne[0] && together[bedTwo.id] == oneByOne[1] && together[bedThree.id] == nil, "sun hours for every bed in a garden at once match the sums done bed by bed, and leave out the other garden's beds (day \(dayOfYear))")
        }
        check(GardenPlan.sunHours(forBedsIn: Garden(name: "Unknown"), beds: allBeds, features: [], dayOfYear: 172) == nil, "sun hours for every bed are not guessed for a garden with no location")

        // The backup file carries the layout
        let lateFrost = FrostRecord(); lateFrost.kind = .lastSpringFrost; lateFrost.minimumTemperatureC = -1.5; lateFrost.siteRaw = "allotment"; lateFrost.damageNotes = "Potato tops blackened"
        plot.insert(lateFrost)
        let backupService = BackupService()
        if let file = try? backupService.export(from: plot) {
            let fresh = ModelContext()
            GardenPlan.ensureStartingGardens(in: fresh)
            try? backupService.restore(from: file, into: fresh)
            let restoredGardens = (try? fresh.fetch(FetchDescriptor<Garden>())) ?? []
            let restoredAllotment = restoredGardens.first { $0.siteKey == "allotment" }
            check(restoredGardens.count == 2 && restoredAllotment?.widthMetres == 25 && restoredAllotment?.soil == .clay && restoredAllotment?.latitude == bristol, "a restore fills in the starting gardens and does not double them")
            let restoredBeds = (try? fresh.fetch(FetchDescriptor<Bed>())) ?? []
            let restoredOne = restoredBeds.first { $0.name == "Bed 1" }
            check(restoredBeds.count == 3 && restoredOne?.originX == 3 && restoredOne?.originY == 8.3 && restoredOne?.lengthMetres == 4 && restoredBeds.first { $0.name == "Bed 2" }?.heightMetres == 0.4, "beds come back where they were measured")
            let restoredFeatures = (try? fresh.fetch(FetchDescriptor<GardenFeature>())) ?? []
            check(restoredFeatures.count == 4 && restoredFeatures.first { $0.name == "Fruit cage" }?.blocksLight == false && restoredFeatures.first { $0.name == "Neighbour's ash" }?.kind == .tree, "sheds, trees and the rest come back too")
            let restoredFrosts = (try? fresh.fetch(FetchDescriptor<FrostRecord>())) ?? []
            check(restoredFrosts.count == 1 && restoredFrosts.first?.minimumTemperatureC == -1.5 && restoredFrosts.first?.siteRaw == "allotment" && restoredFrosts.first?.damageNotes == "Potato tops blackened", "frosts come back from a backup, with their garden and damage notes")
            restoredAllotment?.widthMetres = 30
            try? backupService.restore(from: file, into: fresh)
            check(((try? fresh.fetch(FetchDescriptor<FrostRecord>())) ?? []).count == 1, "a second restore does not double the frosts")
            check(restoredAllotment?.widthMetres == 30 && ((try? fresh.fetch(FetchDescriptor<GardenFeature>())) ?? []).count == 4, "a second restore changes nothing that is already there")
            let oldFile = FileManager.default.temporaryDirectory.appendingPathComponent("windfall-v1-backup.json")
            try? Data(#"{"version":1,"created":"2026-11-01T10:00:00Z","beds":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Old bed","site":"allotment","order":1,"raised":true,"hugel":false,"sections":[{"id":"7F9619FF-8B86-D011-B42D-00C04FC964FF","label":"A","order":0}]}],"plants":[],"plantings":[],"harvests":[],"surveys":[],"observations":[],"diary":[],"frosts":[]}"#.utf8).write(to: oldFile)
            let older = ModelContext()
            try? backupService.restore(from: oldFile, into: older)
            let oldBeds = (try? older.fetch(FetchDescriptor<Bed>())) ?? []
            check(oldBeds.count == 1 && oldBeds.first?.orderedSections.first?.lengthMetres == 1.2 && oldBeds.first?.lengthMetres == nil, "a backup made before gardens existed still restores")
        } else {
            check(false, "the backup file can be written")
        }

        print("   logic tests: \(passes) passed, \(failures) failed")
        exit(failures == 0 ? 0 : 1)
    }
}
#endif
