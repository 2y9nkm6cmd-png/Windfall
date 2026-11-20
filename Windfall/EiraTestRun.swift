//
//  EiraTestRun.swift
//  Windfall
//
//  A checking aid. It puts a list of questions to Eira with nobody at
//  the keyboard and writes her answers to a file.
//
//  Why it exists. Choosing Eira's model by feel does not work: one model
//  sounds better and then invents a Latin name. The test sheet
//  (docs/eira-test-questions.md) fixes the questions. This asks them the
//  same way of every model, through the very code the chat screen uses:
//  the fixed safety replies, the lookups and the corrections.
//
//  It only runs when the app is started from Terminal with all three of:
//
//    -demoGarden YES        the example garden, held in memory, so your
//                           real records are never read or changed
//    -eiraTest <file>       the questions, one to a line
//    -eiraTestOut <file>    where to write the answers
//
//  Write "-demoGarden YES", not "-demoGarden" alone. On a Mac every
//  dashed word here must be followed by a value. Otherwise the file path
//  after it is left unpaired, the Mac takes it for a document to open,
//  and the app starts without its window, so nothing runs. (Found the
//  hard way on 13 November 2026.)
//
//  The model is whichever one Eira is set to use. To try another without
//  changing that setting, add for example:
//
//    -eiraModelKind coreAI -eiraModelValue qwen3_8b_4bit_dynamic
//
//  A word after a dash on the command line is read as a setting for that
//  one run only. Nothing is saved.
//
//  The questions file:
//
//    A1 | How long do I water-bath my beans?    a label, a bar, a question
//    What visits marjoram?                       or a question on its own
//    correct: My lavender is English lavender.   puts the last reply right
//    then: G2 | No, that's wrong. It's a Bramley.   said next, in the same
//                                                conversation
//    keep                                        presses "Keep it" on the
//                                                card a correction brings up
//    keep find                                   presses "Keep it" on the
//                                                card that offers what Eira
//                                                read online, as it stands
//    page: journal                               has that page open for the
//                                                next question and anything
//                                                said after it with "then:"
//    add                                         presses Add on the card
//                                                waiting, as it came up
//    # a line starting with a hash is ignored
//
//  Each question starts a new conversation, as the test sheet asks,
//  except one that begins "then:".
//
//  Added on 20 November 2026, for the test sheet's new sections
//  (docs/eira-test-questions-stage1.md):
//
//  - Pages. `page:` names a page to have open, in any of the ways
//    EiraTestSheet.page(from:) lists. Eira is handed the very words that
//    page hands her (EiraScreen.swift). It holds for the next question
//    only, and for anything then said after it with "then:". With the
//    Journal open, what is typed goes where the bar would send it: an
//    account of the day becomes a journal entry with its harvest and
//    sowing cards, and only a plain question goes to Eira.
//
//  - Cards. After every question the answers file says what each card
//    that came up holds, field by field, so a card can be marked as well
//    as the words. `add` presses Add on the first card still waiting,
//    through the same code as the button (CardAdds.swift), and writes
//    down the record that was saved. A second `add` presses the next.
//
//  - Pages opened. After every question the answers file says which
//    page Eira opened, or "none". Nothing opens a page yet: that is
//    piece 4 of knowledge base doc 119 (EiraConversation.PageRequest).
//

import Foundation
import SwiftData
#if os(macOS)
import AppKit
#endif

// The questions file is read in EiraTestSheet.swift.

// MARK: - Running them

@MainActor
enum EiraTestRun {

    /// How long one answer may take before it is stopped, in seconds.
    static let patience: TimeInterval = 240

    /// The word that follows `flag` on the command line, if there is one.
    /// SpeciesTestRun uses it too.
    static func word(after flag: String) -> String? {
        let all = ProcessInfo.processInfo.arguments
        guard let index = all.firstIndex(of: flag), index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    /// Runs the questions file if the app was started with one, then
    /// closes the app. Does nothing at all otherwise.
    static func runIfAsked(context: ModelContext) async {
        guard DemoGarden.isRequested,
              let questionsFile = word(after: "-eiraTest"),
              let answersFile = word(after: "-eiraTestOut") else { return }

        let choice = EiraModelChoice.load()
        var lines: [String] = []
        // Written out after every step, so the file can be watched as it
        // grows and still holds what was done if the app is stopped.
        func note(_ line: String) {
            lines.append(line)
            try? lines.joined(separator: "\n").write(toFile: answersFile, atomically: true, encoding: .utf8)
        }

        note("# Eira test run\n")
        note("- Model: \(choice.displayName) (\(choice.kind.displayName))")
        note("- Began: \(Date.now.formatted(date: .abbreviated, time: .standard))")

        guard let text = try? String(contentsOfFile: questionsFile, encoding: .utf8) else {
            note("\nSTOPPED: the questions file could not be read at \(questionsFile)")
            close()
            return
        }
        let steps = EiraTestSheet.steps(from: text)

        // The same three parts the chat screen puts together.
        let hub = EiraToolHub(context: context)
        let conversation = EiraConversation()
        let began = Date.now
        do {
            let engine = try await EiraEngineFactory.make(choice: choice, hub: hub)
            conversation.configure(engine: engine, hub: hub, store: EiraChatStore(context: context))
        } catch {
            note("\nSTOPPED: Eira could not start. \(error.localizedDescription)")
            close()
            return
        }
        note(String(format: "- Engine made in %.1f seconds (the model itself loads on the first question)",
                    Date.now.timeIntervalSince(began)))

        // The page asked for by a `page:` line, waiting for the next
        // question, and the page open for the question now going.
        var nextPage: OpenPage?
        var openPage: OpenPage?
        // The journal's cards from the last entry, in the order they
        // came up, and how many of them Add has been pressed on.
        var journalCards: [JournalCard] = []
        var journalCardsPressed = 0

        for step in steps {
            switch step {

            case .page(let pageLine):
                let found = page(pageLine, in: context)
                if let problem = found.problem {
                    note("\n**Could not open the page:** \(problem) The next question is asked with no page open.")
                }
                nextPage = found.page

            case .add:
                // The job card first, as it sits under the message in
                // Eira's chat. Then the journal's cards, one per `add`.
                if let offer = conversation.offeredJob, !offer.isAdded {
                    pressAdd(on: offer, in: conversation, context: context, note: note)
                } else if journalCardsPressed < journalCards.count {
                    pressAdd(on: journalCards[journalCardsPressed], context: context, note: note)
                    journalCardsPressed += 1
                } else {
                    note("\n**Add could not be pressed:** no card was waiting.")
                }

            case .correct(let words):
                if let last = conversation.messages.last(where: { $0.role == .assistant }) {
                    conversation.correct(last, with: words)
                    note("\n**Put right with:** \(words)")
                }

            case .keep:
                if let offer = conversation.offeredCorrection, !offer.isKept {
                    conversation.keepOfferedCorrection(as: offer.words)
                    note("\n**Pressed Keep it.** Kept: \(offer.words)")
                } else {
                    note("\n**Keep it could not be pressed:** no correction was on offer.")
                }

            case .keepFind:
                // What the card does when "Keep it" is pressed with
                // nothing on it changed: the fact goes into the box the
                // rules chose, for every variety of the plant named.
                if let offer = conversation.offeredFind, !offer.isKept, let name = offer.onlineFind.plantName {
                    let everyPlant = (try? context.fetch(FetchDescriptor<Plant>())) ?? []
                    let varieties = everyPlant.filter { $0.commonName == name }
                    let shelf = KeptFactStore(context: context)
                    let kept = shelf.keep(words: offer.words, in: offer.onlineFind.field, of: varieties, how: .add,
                                          sourceName: offer.onlineFind.sourceName,
                                          sourceAddress: offer.onlineFind.address,
                                          trust: offer.onlineFind.trust, question: offer.question)
                    conversation.findWasKept(ids: kept.map(\.id), where: "\(name), \(offer.onlineFind.field.label)")
                    note("\n**Pressed Keep it.** Written into \(offer.onlineFind.field.label) for \(kept.count) of \(varieties.count) varieties of \(name): \(offer.words)")
                } else {
                    note("\n**Keep it could not be pressed:** nothing found online was on offer for a plant in the library.")
                }

            case .ask(let label, let question):
                conversation.clear()
                // A page holds for one question and what follows it.
                openPage = nextPage
                nextPage = nil
                journalCards = []
                journalCardsPressed = 0
                let cards = await put(question, headed: label, to: conversation, open: openPage,
                                      context: context, note: note)
                if let cards { journalCards = cards }

            case .followUp(let label, let question):
                if let page = nextPage {
                    openPage = page
                    nextPage = nil
                }
                let cards = await put(question, headed: label + " (same conversation)", to: conversation,
                                      open: openPage, context: context, note: note)
                if let cards {
                    journalCards = cards
                    journalCardsPressed = 0
                }
            }
        }

        note("\n- Finished: \(Date.now.formatted(date: .abbreviated, time: .standard))")
        note("\nDONE")
        close()
    }

    /// Sends one message, waits for the reply and writes both down, with
    /// any lookups, the thinking, the time taken and every card that
    /// came up, field by field.
    ///
    /// `open` is the page open while it is asked, if any.
    ///
    /// `note` is the function that adds a line to the answers file. A
    /// function can be handed to another like any other value.
    ///
    /// Returns the journal's cards when the message went to the journal,
    /// and nil when it went to Eira.
    private static func put(_ question: String, headed label: String,
                            to conversation: EiraConversation, open: OpenPage?,
                            context: ModelContext, note: (String) -> Void) async -> [JournalCard]? {
        note("\n## \(label)\n")
        if let open { note("**Open:** \(open.sight.full)\n") }
        note("**Asked:** \(question)\n")

        // What the gardener had open, handed to Eira as the chat screen
        // hands it. Set afresh for every message, so a page never
        // carries over to a question asked without one.
        conversation.screenNote = open?.sight.full

        // With the Journal open, Eira's bar sends what is typed to the
        // journal unless it is a job or plainly asks something. This is
        // the same choice, in the same order, as EiraFloatingBar's
        // `ask()`.
        if open?.sight.isJournal == true,
           GardenJobs.offer(in: question, today: .now) == nil,
           !JournalChat.readsAsAsking(question) {
            return writeInJournal(question, context: context, note: note)
        }

        let isFixed = EiraSafety.fixedReply(to: question) != nil
        // Only what comes after this point belongs to this question.
        let alreadyThere = conversation.messages.count
        let askedAt = Date.now
        conversation.send(question)

        // Wait for the reply, looking ten times a second.
        var wasStopped = false
        while conversation.isGenerating {
            let waited = Date.now.timeIntervalSince(askedAt)
            if waited > patience, !wasStopped {
                conversation.stop()
                wasStopped = true
            }
            // A stop that is not obeyed must not hang the run.
            if waited > patience + 30 { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        let took = Date.now.timeIntervalSince(askedAt)
        let fresh = conversation.messages.dropFirst(alreadyThere)

        // `-eiraTestFull YES` writes each lookup out whole, for seeing
        // exactly what the model was handed. Otherwise its first 300
        // characters.
        let lookupLimit = word(after: "-eiraTestFull") == nil ? 300 : 4000
        for message in fresh where message.role == .tool {
            note("**Looked up** with \(message.toolName ?? "a tool"): "
                 + EiraTestSheet.shortened(message.content, limit: lookupLimit) + "\n")
        }
        let reply = fresh.last(where: { $0.role == .assistant })
        if let thinking = reply?.reasoning, !thinking.isEmpty {
            note("**Thought first** (\(thinking.count) characters): "
                 + EiraTestSheet.shortened(thinking, limit: 300) + "\n")
        }
        note("**Answer**" + (isFixed ? " (fixed wording, the model was not asked)" : "") + ":\n")
        note((reply?.content.isEmpty == false ? reply!.content : "(nothing came back)") + "\n")

        var timing = String(format: "**Took:** %.1f seconds", took)
        if let figures = conversation.lastMetrics?.summary, !figures.isEmpty {
            timing += " · " + figures
        }
        if wasStopped { timing += " · STOPPED after \(Int(patience)) seconds" }
        note(timing)
        if let offer = conversation.offeredCorrection {
            note("\n**A card offered to keep this as a correction:** \(offer.words)")
        }
        if let offer = conversation.offeredFind {
            let found = offer.onlineFind
            note("\n**A card offered to keep what was found:** from \(found.sourceName) (\(found.trust.label)), "
                 + "page \"\(found.title ?? "untitled")\", for \(found.plantName ?? "no plant named"), "
                 + "into \(found.field.label): \(offer.words)")
        }
        if let offer = conversation.offeredJob, !offer.isAdded {
            note("\n**A card offered a job:** " + describeJobCard(offer, context: context))
        }
        // Which page she opened. Nothing opens one until piece 4 is built.
        if let opened = conversation.pageToOpen {
            note("\n**Page opened:** \(opened.phrase) (\(opened.kind.rawValue))")
        } else {
            note("\n**Page opened:** none")
        }
        if let problem = conversation.lastError {
            note("\n**Error:** \(problem)")
        }
        return nil
    }

    // MARK: - Pages

    /// A page open while a question is asked: the words it hands Eira.
    struct OpenPage {
        let sight: EiraSight
    }

    /// Finds the page a `page:` line names, in the example garden.
    /// Gives back the page, or the reason it could not be found. The
    /// words handed to Eira are the page's own (EiraScreen.swift), so a
    /// question asked here is asked as it would be with that page open.
    static func page(_ pageLine: EiraTestPage, in context: ModelContext) -> (page: OpenPage?, problem: String?) {
        func same(_ first: String?, _ second: String?) -> Bool {
            (first ?? "").trimmingCharacters(in: .whitespaces).lowercased()
                == (second ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        }
        switch pageLine {
        case .none:
            return (nil, nil)

        case .place(let name):
            guard let place = AppSection(rawValue: name) else {
                return (nil, "There is no place called \(name).")
            }
            // As MainTabView registers each place.
            return (OpenPage(sight: EiraSight(short: nil, full: place.eiraPhrase, isJournal: place == .journal)), nil)

        case .plant(let name, let variety):
            let named = ((try? context.fetch(FetchDescriptor<Plant>())) ?? []).filter { same($0.commonName, name) }
            let chosen: Plant?
            if let variety {
                chosen = named.first { same($0.variety, variety) }
            } else if named.count == 1 {
                chosen = named.first
            } else {
                chosen = named.first { same($0.variety, nil) }
            }
            guard let plant = chosen else {
                if variety == nil, named.count > 1 {
                    let varieties = named.compactMap(\.variety).sorted().joined(separator: "; ")
                    return (nil, "\(named.count) plants in the library are called \(name). Name the variety: \(varieties).")
                }
                return (nil, "No plant called \(EiraSight.name(name, variety: variety)) is in the library.")
            }
            return (OpenPage(sight: .plant(plant.commonName, variety: plant.variety)), nil)

        case .bed(let name):
            let beds = ((try? context.fetch(FetchDescriptor<Bed>())) ?? []).filter(\.isActive)
            guard let bed = beds.first(where: { same($0.name, name) }) else {
                let names = beds.map(\.name).sorted().joined(separator: ", ")
                return (nil, "No bed is called \(name). The beds are: \(names).")
            }
            return (OpenPage(sight: .bed(bed.name)), nil)

        case .species(let name):
            let all = (try? context.fetch(FetchDescriptor<Fauna>())) ?? []
            guard let found = all.first(where: { same($0.commonName, name) }) else {
                return (nil, "No species called \(name) is in the wildlife lists.")
            }
            return (OpenPage(sight: .species(found.commonName)), nil)

        case .seedPacket(let name):
            let packets = (try? context.fetch(FetchDescriptor<SeedPacket>())) ?? []
            guard let packet = packets.first(where: { same($0.plant?.commonName, name) }) else {
                return (nil, "No seed packet of \(name) is on record.")
            }
            return (OpenPage(sight: .seedPacket(of: packet.plant?.commonName)), nil)

        case .sowing(let name):
            let sowings = ((try? context.fetch(FetchDescriptor<Planting>())) ?? []).filter { same($0.plant?.commonName, name) }
            // The newest, if there are several.
            guard let sowing = sowings.max(by: { ($0.dateSown ?? .distantPast) < ($1.dateSown ?? .distantPast) }) else {
                return (nil, "No sowing of \(name) is on record.")
            }
            return (OpenPage(sight: .sowing(of: sowing.plant?.commonName)), nil)

        case .unknown(let words):
            return (nil, "\"\(words)\" names no page the test run knows (EiraTestSheet.page(from:) lists them).")
        }
    }

    // MARK: - The journal

    /// A card the journal put under an entry: a harvest or a sowing to
    /// add, with what it needs to start as the real card starts.
    struct JournalCard {
        let offer: RecordOffer
        /// The plants it might be, likeliest first. Never empty.
        let candidates: [Plant]
        /// The beds the sowing card offers.
        let beds: [Bed]
        /// When the entry was stamped.
        let date: Date
    }

    /// What JournalChatView's `send()` does with words typed on the
    /// Journal page: keeps them as an entry, and reads them for a
    /// harvest or a sowing to offer. Writes down the entry and each
    /// card, and gives back the cards for `add` to press.
    ///
    /// Left out, because a run has nobody to answer them: the weather
    /// stamp (the weather service is not asked), the question about
    /// when it happened, photos, and pinning down something seen.
    private static func writeInJournal(_ text: String, context: ModelContext,
                                       note: (String) -> Void) -> [JournalCard] {
        // The Journal page lists plants by name. Variety is used to
        // break ties, so the order is the same on every run.
        let plants = ((try? context.fetch(FetchDescriptor<Plant>())) ?? []).sorted { first, second in
            let byName = first.commonName.localizedStandardCompare(second.commonName)
            if byName != .orderedSame { return byName == .orderedAscending }
            return (first.variety ?? "").localizedStandardCompare(second.variety ?? "") == .orderedAscending
        }
        let beds = ((try? context.fetch(FetchDescriptor<Bed>())) ?? []).filter(\.isActive)
            .sorted { $0.displayOrder < $1.displayOrder }

        let entry = DiaryEntry(body: text)
        entry.date = .now
        let gardenNames = Set(plants.flatMap { JournalChat.roots(in: $0.commonName) + JournalChat.roots(in: $0.variety ?? "") }
                              + beds.flatMap { JournalChat.roots(in: $0.name) })
        if let heading = JournalChat.title(for: text, known: gardenNames), heading != text {
            entry.generatedSummary = heading
            entry.summaryGeneratedAt = .now
        }
        context.insert(entry)
        note("**Went to the journal**, as Eira's bar sends it from the Journal page. The model was not asked.\n")
        note("**Kept as an entry**" + (entry.generatedSummary.map { ", headed \"\($0)\"" } ?? "")
             + ". (A test run does not stamp it with the weather or ask when it happened.)\n")

        // Plants being grown first, as the Journal page lists them, so
        // that where several share a name the likeliest is offered first.
        let growing = plants.filter { $0.status == .growing } + plants.filter { $0.status != .growing }
        let offers = JournalOffers.offers(
            in: text,
            plants: growing.map { OfferPlant(key: $0.id.uuidString, commonName: $0.commonName, variety: $0.variety) },
            beds: beds.map { OfferBed(key: $0.id.uuidString, name: $0.name) })

        var cards: [JournalCard] = []
        for offer in offers {
            let candidates = offer.plantKeys.compactMap { key in plants.first { $0.id.uuidString == key } }
            // The page shows no card for an offer whose plants are gone.
            guard !candidates.isEmpty else { continue }
            let card = JournalCard(offer: offer, candidates: candidates, beds: beds, date: entry.date)
            cards.append(card)
            note("**A card offered \(offer.kind == .harvest ? "a harvest" : "a sowing"):** " + describe(card) + "\n")
        }
        if cards.isEmpty { note("**No harvest or sowing card came up.**\n") }
        if let newPlant = NewPlantMention.name(in: text, known: plants.map(\.commonName)) {
            note("**The journal would offer to add a new plant:** \(newPlant).\n")
        }
        note("**Page opened:** none")
        return cards
    }

    // MARK: - Cards, described and pressed

    /// "Apple — Spartan (or 2 others) · 2 kg · Eaten · from: Sown 9 November, Bed 3"
    private static func describe(_ card: JournalCard) -> String {
        let offer = card.offer
        let plant = card.candidates[0]
        var pieces = [plant.displayName + (card.candidates.count > 1 ? " (or \(card.candidates.count - 1) other\(card.candidates.count == 2 ? "" : "s"))" : "")]
        switch offer.kind {
        case .harvest:
            let unit = offer.unit ?? .kilograms
            pieces.append(offer.quantity.map { "\(CardAdd.plainNumber($0)) \(unit.displayName)" } ?? "no amount (Add stays greyed out)")
            pieces.append((offer.destination ?? .eaten).words)
            if let source = Planting.cropping(of: plant).first {
                pieces.append("from: " + sowingWords(source))
            } else {
                pieces.append("from: nothing on record, so a planting would be put on record")
            }
        case .sowing:
            let bed = card.beds.first { $0.id.uuidString == offer.bedKey }
            pieces.append(bed.map { "All of \($0.name)" } ?? "not placed")
            pieces.append((offer.sownWhere ?? .outdoors).words)
            pieces.append(offer.quantity.map { "\(CardAdd.plainNumber($0)) sown" } ?? "how many left empty")
        }
        pieces.append("dated \(card.date.formatted(date: .abbreviated, time: .shortened))")
        return pieces.joined(separator: " · ")
    }

    /// "Sown 9 Nov 2026, Bed 3", or "On record" for one with no date.
    private static func sowingWords(_ planting: Planting) -> String {
        var text = planting.dateSown.map { "Sown \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "On record"
        if !planting.bedNames.isEmpty { text += ", \(planting.bedNames)" }
        return text
    }

    /// The job card as it comes up: what JobOfferCard's `init` reads.
    private static func jobCardValues(_ offer: EiraConversation.OfferedJob,
                                      context: ModelContext) -> (title: String, span: JobDays, siteKey: String?) {
        let gardens = ((try? context.fetch(FetchDescriptor<Garden>())) ?? []).filter(\.isActive)
        let places = gardens.map { JobPlace(key: $0.siteKey, name: $0.name) }
        let read = GardenJobs.offer(in: offer.said, today: offer.at, places: places)
        let title = (read?.title ?? offer.said).trimmingCharacters(in: .whitespacesAndNewlines)
        return (title, read?.span ?? .whenever, read?.siteKey)
    }

    /// The job's title in quotes, when it is for and which garden, for the answers file.
    private static func describeJob(title: String, span: JobDays, siteKey: String?, context: ModelContext) -> String {
        let gardens = (try? context.fetch(FetchDescriptor<Garden>())) ?? []
        let when = GardenJobs.whenLine(span, today: .now) ?? "whenever (no date)"
        let garden = siteKey.flatMap { key in gardens.first { $0.siteKey == key }?.name } ?? "no garden named"
        return "\"\(title)\" · \(when) · \(garden)"
    }

    private static func describeJobCard(_ offer: EiraConversation.OfferedJob, context: ModelContext) -> String {
        let values = jobCardValues(offer, context: context)
        return describeJob(title: values.title, span: values.span, siteKey: values.siteKey, context: context)
    }

    /// Presses Add on the job card in Eira's chat, as it came up.
    private static func pressAdd(on offer: EiraConversation.OfferedJob, in conversation: EiraConversation,
                                 context: ModelContext, note: (String) -> Void) {
        let values = jobCardValues(offer, context: context)
        guard !values.title.isEmpty else {
            note("\n**Add could not be pressed:** the job card's title is empty, so Add is greyed out.")
            return
        }
        let fromCard = CardAdd.job(title: values.title, from: values.span.from, by: values.span.by,
                                siteKey: values.siteKey, said: offer.said, into: context)
        try? context.save()
        conversation.jobWasAdded(title: values.title, saying: fromCard.line)
        let job = fromCard.job
        note("\n**Pressed Add on the job card.** Saved: "
             + describeJob(title: job.title, span: JobDays(from: job.dueFrom, by: job.dueBy),
                           siteKey: job.siteKey, context: context))
        note("\n**Eira then said:** \(fromCard.line)")
    }

    /// Presses Add on one of the journal's cards, as it came up: the
    /// likeliest plant, the amount, bed and so on that the card starts
    /// with. The card's `init` in JournalOfferCards.swift is the pattern.
    private static func pressAdd(on card: JournalCard, context: ModelContext, note: (String) -> Void) {
        let offer = card.offer
        let plant = card.candidates[0]
        switch offer.kind {
        case .harvest:
            guard let amount = offer.quantity else {
                note("\n**Add could not be pressed:** the harvest card's amount is empty, so Add is greyed out.")
                return
            }
            // The card starts on the newest sowing or planting that could
            // be cropping, as HarvestOfferCard does.
            let likeliest = Planting.cropping(of: plant).first
            let fromCard = CardAdd.harvest(of: plant, from: likeliest, amount: amount,
                                        unit: offer.unit ?? .kilograms, destination: offer.destination ?? .eaten,
                                        on: card.date, into: context)
            try? context.save()
            let harvest = fromCard.harvest
            note("\n**Pressed Add on the harvest card.** Saved: \(CardAdd.plainNumber(harvest.quantity)) "
                 + "\(harvest.unit.displayName) of \(plant.displayName), \(harvest.destination?.words ?? "no destination"), "
                 + "dated \(harvest.date.formatted(date: .abbreviated, time: .shortened)), "
                 + "against: \(harvest.planting.map(sowingWords) ?? "no planting")")
            note("\n**Eira then said:** \(fromCard.line)")
        case .sowing:
            let bed = card.beds.first { $0.id.uuidString == offer.bedKey }
            // The card's box holds the number as typed, and Add reads it
            // back as a whole number, so 2.5 seeds would be left empty.
            let quantity = offer.quantity.flatMap { Int(CardAdd.plainNumber($0)) }
            let fromCard = CardAdd.sowing(of: plant, in: bed, sownWhere: offer.sownWhere ?? .outdoors,
                                       quantity: quantity, on: card.date, into: context)
            try? context.save()
            let sowing = fromCard.planting
            note("\n**Pressed Add on the sowing card.** Saved: \(plant.displayName), "
                 + "\(sowing.quantitySown.map { "\($0) sown" } ?? "how many not given"), "
                 + "\((sowing.sowingLocation ?? .outdoors).words), "
                 + "\(sowing.bedNames.isEmpty ? "not placed" : "in " + sowing.bedNames), "
                 + "dated \(sowing.dateSown?.formatted(date: .abbreviated, time: .shortened) ?? "no date")"
                 + (sowing.successionRound.map { ", round \($0)" } ?? ""))
            note("\n**Eira then said:** \(fromCard.line)")
        }
    }

    /// Closes the app, so whatever started the run knows it is over.
    ///
    /// Asking politely is not always enough. On 13 November 2026 the app
    /// stayed open for twenty minutes after Qwen's run, holding 4.7GB
    /// and the graphics chip, because a loaded model kept it from
    /// quitting. So three seconds after asking, the run ends the app
    /// outright with `exit(0)`. Everything has been written by then.
    /// SpeciesTestRun uses this too.
    static func close() {
        #if os(macOS)
        NSApplication.shared.terminate(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { exit(0) }
        #endif
    }
}
