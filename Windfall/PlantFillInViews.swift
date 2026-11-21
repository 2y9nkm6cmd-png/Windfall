//
//  PlantFillInViews.swift
//  Windfall
//
//  The screens for filling in what a plant's record does not yet say.
//  The working out is in PlantFillIn.swift, which has no screens in it
//  and is covered by the logic tests. This file only shows what that
//  one finds and passes on which button was pressed.
//
//  There are four pieces:
//
//    NewPlantSheet     a short form: the name, the variety and the kind.
//                      Adding the plant opens the next sheet at once.
//    FillInSheet       looks the plant up and shows one card for each
//                      thing found. Each card has Keep and Skip.
//    GapsCard          the card on a plant's page: how full the record
//                      is, and a button that opens FillInSheet.
//    NewPlantOfferCard Eira's card in a conversation, when what was
//                      said names a plant the library does not have.
//
//  The one rule that matters most: nothing is written to a plant's
//  record until Keep is pressed on that one suggestion. Closing the
//  sheet keeps what was kept and leaves everything else as it was.
//
//  ⚠️ Written on 14 November 2026 without the Mac, so none of this has
//  been built or seen running. It is checked for valid Swift only.
//

import SwiftUI
import SwiftData

// MARK: - Adding a plant by hand

/// The form for a plant that is not in the library yet.
///
/// It asks for as little as will do, because the point of what follows
/// is that the rest is looked up. A name is the one thing it must have.
struct NewPlantSheet: View {

    /// A name to start with, when Eira heard one in a conversation.
    private let startingName: String

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    // `@Query` reads the library from the database and keeps the list
    // up to date. It is used here to warn of a plant already there and
    // to offer the groups the library already uses.
    @Query(sort: \Plant.commonName) private var plants: [Plant]

    @State private var name: String
    @State private var variety = ""
    @State private var latinName = ""
    @State private var group = ""
    @State private var status: PlantStatus = .growing
    /// The plant just added. Setting it opens the sheet that fills it
    /// in, and closing that sheet closes this one too.
    @State private var added: Plant?
    /// True when what was typed before and not added was put back.
    @State private var carriedOn = false

    /// What is kept if the sheet is closed before the plant is added
    /// (review pass, 21 November 2026, doc 145). See FormDraft.swift.
    struct Draft: Codable, Equatable {
        var name = ""
        var variety = ""
        var latinName = ""
        var group = ""
        var status: PlantStatus = .growing
    }

    private var draft: Draft {
        Draft(name: name, variety: variety, latinName: latinName, group: group, status: status)
    }
    /// One copy for a plant added by hand, and one for each name Eira
    /// offered, so one never fills in the other.
    private var draftKey: String {
        startingName.isEmpty ? "new-plant" : "new-plant.\(startingName.lowercased())"
    }
    private var draftIsEmpty: Bool { draft == Draft(name: startingName) }

    private func use(_ typedBefore: Draft) {
        name = typedBefore.name
        variety = typedBefore.variety
        latinName = typedBefore.latinName
        group = typedBefore.group
        status = typedBefore.status
    }

    init(startingName: String = "") {
        self.startingName = startingName
        _name = State(initialValue: startingName)
    }

    private var tidyName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var tidyVariety: String { variety.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// True if the library already has this name and variety.
    private var isAlreadyThere: Bool {
        let key = PlantFacts.libraryKey(name: tidyName, variety: tidyVariety.isEmpty ? nil : tidyVariety)
        return plants.contains { PlantFacts.libraryKey(name: $0.commonName, variety: $0.variety) == key }
    }

    /// The groups the library already uses, commonest first, so that a
    /// new plant is filed with the same word as its neighbours.
    private var knownGroups: [String] {
        var counts: [String: Int] = [:]
        for plant in plants {
            if let used = plant.group?.trimmingCharacters(in: .whitespaces), !used.isEmpty { counts[used, default: 0] += 1 }
        }
        return counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map(\.key)
    }

    var body: some View {
        SheetPage("New plant",
                  detail: "Add it, and Windfall looks up the rest for you to approve.",
                  confirmTitle: "Add and look it up",
                  canConfirm: !tidyName.isEmpty && !isAlreadyThere,
                  onConfirm: add) {
            SheetScroll {
                if carriedOn {
                    DraftNotice {
                        use(Draft(name: startingName))
                        FormDraft.clear(key: draftKey)
                        carriedOn = false
                    }
                }
                SheetCard("What is it?") {
                    FieldBox {
                        TextField("Common name, such as Medlar", text: $name)
                            .autocorrectionDisabled()
                    }
                    FieldBox {
                        TextField("Variety, if it has one, such as Nottingham", text: $variety)
                            .autocorrectionDisabled()
                    }
                    FieldBox {
                        TextField("Latin name, if you know it", text: $latinName)
                            .autocorrectionDisabled()
                    }
                    if isAlreadyThere {
                        Text("Your plant library already has this plant. Open its page and use Fill the gaps there.")
                            .font(.footnote)
                            .foregroundStyle(Theme.amber)
                    }
                }

                SheetCard("Where it belongs") {
                    SettingRow("Group") {
                        // A menu of the groups already in use, with
                        // "Not sure yet" to leave it for the look-up.
                        Menu {
                            Button("Not sure yet") { group = "" }
                            ForEach(knownGroups, id: \.self) { known in
                                Button(known) { group = known }
                            }
                        } label: {
                            Text(group.isEmpty ? "Not sure yet" : group)
                                .foregroundStyle(Theme.leaf)
                        }
                    }
                    SettingRow("Do you have it?") {
                        Menu {
                            Button("Growing it") { status = .growing }
                            Button("On the wish list") { status = .wanted }
                        } label: {
                            Text(status == .wanted ? "On the wish list" : "Growing it")
                                .foregroundStyle(Theme.leaf)
                        }
                    }
                    Text("The group decides which filters and which crop rotation it falls under. It can be changed later.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        // The sheet that fills the new plant in, opened as soon as the
        // plant exists. `onDismiss` runs when it closes.
        .sheet(item: $added, onDismiss: { dismiss() }) { plant in
            FillInSheet(plant: plant, wasJustAdded: true)
        }
        .keepsDraft(draftKey, draft, isEmpty: draftIsEmpty, carriedOn: $carriedOn, restore: use)
    }

    /// Makes the plant's record, with the little that was typed, and
    /// opens the sheet that looks up the rest.
    private func add() {
        FormDraft.clear(key: draftKey)
        let plant = Plant(commonName: tidyName)
        plant.variety = tidyVariety.isEmpty ? nil : tidyVariety
        let latin = latinName.trimmingCharacters(in: .whitespacesAndNewlines)
        plant.latinName = latin.isEmpty ? nil : latin
        plant.group = group.isEmpty ? nil : group
        plant.status = status
        context.insert(plant)
        try? context.save()
        added = plant
    }
}

// MARK: - Going through the suggestions

/// Looks a plant up and shows what was found, one card for each empty
/// box of its record. Each card is kept or skipped on its own.
struct FillInSheet: View {

    let plant: Plant
    /// True when the plant was made a moment ago, which changes only
    /// the wording at the top.
    var wasJustAdded = false

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    /// The app's note of what is on screen, which is also how a page
    /// hands Eira a question. Nil in a preview. See EiraScreen.swift.
    @Environment(EiraScreen.self) private var eiraScreen: EiraScreen?
    @Query private var plants: [Plant]
    @Query private var keptFacts: [KeptFact]

    /// How far the looking has got.
    private enum Stage { case starting, online, finished }
    @State private var stage: Stage = .starting

    /// What the library's other varieties gave, kept so that the list
    /// can be worked out again when a page comes in.
    @State private var fromLibrary: [FillSuggestion] = []
    /// What has been read online so far.
    @State private var online = OnlineReading()
    /// The suggestions on show.
    @State private var suggestions: [FillSuggestion] = []
    /// What is typed on each card, by the box's key. A suggestion can
    /// be put right before it is kept.
    @State private var typed: [String: String] = [:]
    /// The kept suggestions, by box, each with the record it made, so
    /// that Undo knows what to take back.
    @State private var kept: [String: UUID] = [:]
    /// The boxes skipped in this sitting.
    @State private var skipped: Set<String> = []

    /// A web address pasted in to be read.
    @State private var pastedAddress = ""
    @State private var isReadingPasted = false
    @State private var pastedProblem: String?
    /// True while the plant's own Edit sheet is open.
    @State private var isTypingIn = false
    /// True when corrections typed on the cards before were put back.
    @State private var carriedOn = false
    private var draftKey: String { FormDraft.key("fill-in", plant.id) }

    /// The suggestions still waiting for an answer.
    private var waiting: [FillSuggestion] {
        suggestions.filter { kept[$0.key] == nil && !skipped.contains($0.key) }
    }

    /// The gaps nothing was found for.
    private var stillEmpty: [PlantGaps.Gap] {
        let offered = Set(suggestions.map(\.key))
        return PlantGaps.gaps(in: plant).filter { !offered.contains($0.key) }
    }

    private var summary: String {
        switch stage {
        case .starting: return "Looking in your own plant library."
        case .online: return "Reading the RHS. This takes a few seconds."
        case .finished:
            if suggestions.isEmpty { return "Nothing was found for the empty boxes." }
            let left = waiting.count
            return left == 0 ? "Every suggestion has been dealt with."
                : left == 1 ? "1 suggestion to look at." : "\(left) suggestions to look at."
        }
    }

    var body: some View {
        SheetPage(wasJustAdded ? "\(plant.commonName) is added" : "Fill the gaps",
                  detail: plant.displayName,
                  dismissTitle: nil,
                  confirmTitle: "Done",
                  onConfirm: { dismiss() }) {
            SheetScroll {
                if carriedOn {
                    DraftNotice {
                        typed = [:]
                        FormDraft.clear(key: draftKey)
                        carriedOn = false
                    }
                }
                SheetCard {
                    HStack(spacing: 10) {
                        if stage != .finished { ProgressView() }
                        Text(summary)
                            .foregroundStyle(Theme.ink)
                    }
                    Text("Nothing is written to the plant's record until you press Keep on it. Each suggestion shows where it came from and the words it was read from.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(online.problems, id: \.self) { problem in
                        Text(problem)
                            .font(.footnote)
                            .foregroundStyle(Theme.amber)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(online.pages, id: \.address) { page in
                        pageLine(page)
                    }
                }

                ForEach(suggestions) { suggestion in
                    SuggestionCard(
                        suggestion: suggestion,
                        typed: Binding(get: { typed[suggestion.key] ?? suggestion.value },
                                       set: { typed[suggestion.key] = $0 }),
                        isKept: kept[suggestion.key] != nil,
                        isSkipped: skipped.contains(suggestion.key),
                        onKeep: { keep(suggestion) },
                        onSkip: { skipped.insert(suggestion.key) },
                        onUndo: { undo(suggestion) })
                }

                if stage == .finished { restCard }
            }
        }
        // `.task` runs once when the sheet appears, and is stopped if
        // the sheet is closed before it has finished.
        .task { await gather() }
        .sheet(isPresented: $isTypingIn) {
            PlantEditView(plant: plant)
        }
        // A swipe down closes the sheet as Done does, suggestions waiting
        // or not (review pass, 21 November 2026; until then it was
        // switched off while any waited). What was Kept is already in
        // the record; the rest is looked for again next time, and any
        // correction typed on a card is kept here until then.
        .keepsDraft(draftKey, typed, isEmpty: typed.isEmpty, carriedOn: $carriedOn) { typed = $0 }
    }

    /// One page that was read: its title, the site and a way to open it.
    private func pageLine(_ page: PageReading) -> some View {
        HStack(spacing: 8) {
            Text("Read: \(page.title ?? page.address) · \(page.sourceName), \(page.trust.label.lowercased())")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            if let url = WebPageReader.webURL(from: page.address) {
                Link("Open", destination: url)
                    .font(.footnote)
                    .foregroundStyle(Theme.leaf)
            }
        }
    }

    // MARK: What is left

    /// The foot of the sheet: the gaps nothing was found for, and the
    /// three other ways to fill them.
    private var restCard: some View {
        SheetCard(stillEmpty.isEmpty ? "More" : "Still empty") {
            ForEach(stillEmpty) { gap in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(gap.label)
                            .foregroundStyle(Theme.ink)
                        if let why = gap.why {
                            Text(why)
                                .font(.footnote)
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                    Spacer(minLength: 8)
                    // Eira has a lookup for some of these. Her answer
                    // comes with a card that offers to keep it.
                    if let question = PlantGaps.questionForEira(about: gap.key, plant: plant.commonName), eiraScreen != nil {
                        Button("Ask Eira") {
                            eiraScreen?.ask(question)
                            dismiss()
                        }
                        .buttonStyle(QuietGlassButton())
                    }
                }
            }

            Text("Read a page for more. Paste the address of this plant's page on the RHS, a seed supplier or any other site, and the same rules read it.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                FieldBox {
                    TextField("A web address", text: $pastedAddress)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                }
                if isReadingPasted {
                    ProgressView()
                } else {
                    Button("Read it") { Task { await readPasted() } }
                        .buttonStyle(QuietGlassButton())
                        .disabled(WebPageReader.webURL(from: pastedAddress) == nil)
                }
            }
            if let pastedProblem {
                Text(pastedProblem)
                    .font(.footnote)
                    .foregroundStyle(Theme.amber)
            }

            Button("Type facts in yourself") { isTypingIn = true }
                .buttonStyle(QuietGlassButton())
        }
    }

    // MARK: Doing the work

    /// Gathers the suggestions: first from the library, which is at
    /// once, and then from the RHS, which waits for the internet.
    ///
    /// `await` marks each place the function waits. The screen stays
    /// alive meanwhile, and the library's suggestions are already
    /// showing.
    private func gather() async {
        guard stage == .starting else { return }
        fromLibrary = LibraryFill.suggestions(for: plant, among: plants)
        workOutSuggestions()

        stage = .online
        // A plain copy of the few things the look-up needs, so that
        // the record itself is not touched while waiting.
        let whichPlant = PlantAsked(plant)
        online = await PlantFillIn.lookUp(whichPlant)
        workOutSuggestions()
        stage = .finished
    }

    /// Works the list out afresh from everything gathered so far. A
    /// suggestion already kept stays in the list, although its box is
    /// no longer empty, so that it can still be undone.
    private func workOutSuggestions() {
        var next = suggestions.filter { kept[$0.key] != nil }
        let fresh = PlantFillIn.suggestions(for: plant, fromLibrary: fromLibrary, online: online)
        for suggestion in fresh where !next.contains(where: { $0.key == suggestion.key }) {
            next.append(suggestion)
        }
        let order = Dictionary(uniqueKeysWithValues: PlantFacts.all.enumerated().map { ($1.key, $0) })
        suggestions = next.sorted { (order[$0.key] ?? 0) < (order[$1.key] ?? 0) }
    }

    /// Writes one suggestion into its box, as it now reads on its card.
    private func keep(_ suggestion: FillSuggestion) {
        let value = typed[suggestion.key] ?? suggestion.value
        if let fact = KeptFactStore(context: context).keep(suggestion, as: value, in: plant) {
            kept[suggestion.key] = fact.id
        }
    }

    /// Takes a kept suggestion back out of the record.
    private func undo(_ suggestion: FillSuggestion) {
        if let id = kept[suggestion.key], let fact = keptFacts.first(where: { $0.id == id }) {
            KeptFactStore(context: context).remove(fact)
        }
        kept[suggestion.key] = nil
        skipped.remove(suggestion.key)
    }

    /// Reads the page at the pasted address and adds what it gives.
    private func readPasted() async {
        isReadingPasted = true
        pastedProblem = nil
        let name = plant.commonName
        if let page = await PlantFillIn.readPage(at: pastedAddress, plantName: name) {
            // In front of the pages already read: a page you chose
            // yourself is taken before the ones Windfall found.
            online.pages.insert(page, at: 0)
            let before = suggestions.count
            workOutSuggestions()
            if suggestions.count == before {
                pastedProblem = "That page was read, and the rules found nothing new on it for the empty boxes."
            }
            pastedAddress = ""
        } else {
            pastedProblem = "That page could not be read."
        }
        isReadingPasted = false
    }
}

// MARK: - One suggestion

/// One suggestion: the box, what would go in it, where that came from
/// and the two buttons.
private struct SuggestionCard: View {

    let suggestion: FillSuggestion
    /// What is typed on the card. A `Binding` is a link to a value
    /// held by another view, here the sheet, so typing here changes it
    /// there.
    @Binding var typed: String
    let isKept: Bool
    let isSkipped: Bool
    let onKeep: () -> Void
    let onSkip: () -> Void
    let onUndo: () -> Void

    /// True for a box of months, which shows the months in words under
    /// what is typed, so "feb mar" can be read at a glance.
    private var monthsInWords: String? {
        guard let box = PlantFacts.named(suggestion.key), case .months = box.kind else { return nil }
        let months = MonthParser.months(in: typed)
        return months.isEmpty ? "No months in that." : MonthParser.describe(months)
    }

    /// The unit the box's figure is in, if it has one: "m" or "mm".
    private var unit: String? {
        guard let box = PlantFacts.named(suggestion.key), case .measure(let unit) = box.kind else { return nil }
        return unit
    }

    var body: some View {
        if isSkipped {
            // A skipped suggestion shrinks to one line, with the way back.
            HStack(spacing: 10) {
                Text("\(suggestion.label): skipped")
                    .foregroundStyle(Theme.inkSoft)
                Button("Bring back") { onUndo() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.inkSoft)
                    .underline()
            }
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
        } else {
            SheetCard(suggestion.label) {
                if suggestion.isYesNo {
                    Text("Yes")
                        .foregroundStyle(Theme.ink)
                } else if isKept {
                    Text(unit.map { "\(typed) \($0)" } ?? typed)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(spacing: 8) {
                        FieldBox {
                            TextField(suggestion.label, text: $typed, axis: .vertical)
                                .lineLimit(1...6)
                        }
                        if let unit {
                            Text(unit)
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                }
                if let monthsInWords {
                    Text(monthsInWords)
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }

                // The words it was read from, or the reason for it.
                if !suggestion.evidence.isEmpty {
                    Text(suggestion.evidence)
                        .font(.footnote)
                        .italic()
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // Where another source says something different.
                if let otherView = suggestion.otherView {
                    Text(otherView)
                        .font(.footnote)
                        .foregroundStyle(Theme.amber)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    Text("\(suggestion.sourceName) · \(suggestion.trust.label)")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.ink)
                    if let address = suggestion.address, let url = WebPageReader.webURL(from: address) {
                        Link("Open the page", destination: url)
                            .font(.footnote)
                            .foregroundStyle(Theme.leaf)
                    }
                }

                if isKept {
                    HStack(spacing: 10) {
                        Label("Kept", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Theme.leaf)
                        Button("Undo") { onUndo() }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.inkSoft)
                            .underline()
                    }
                    .font(.footnote)
                } else {
                    HStack(spacing: 8) {
                        Button("Keep") { onKeep() }
                            .buttonStyle(.glassProminent)
                            .tint(Theme.leaf)
                            .foregroundStyle(Theme.onLeaf)
                            .disabled(typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Skip") { onSkip() }
                            .buttonStyle(QuietGlassButton())
                    }
                }
            }
        }
    }
}

// MARK: - On a plant's page

/// The card on a plant's page: how full its record is, the gaps that
/// matter most and the button that looks them up. Left out altogether
/// when the record has no gap worth filling.
struct GapsCard: View {

    let plant: Plant
    let onFill: () -> Void

    var body: some View {
        let gaps = PlantGaps.gaps(in: plant)
        if !gaps.isEmpty {
            let fullness = PlantGaps.fullness(of: plant)
            VStack(alignment: .leading, spacing: 10) {
                Text("Fill the gaps")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(fullness.filled) of \(fullness.wanted) of the facts that matter are filled in. Missing: \(named(gaps)).")
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Look them up") { onFill() }
                    .buttonStyle(QuietGlassButton())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
    }

    /// The first few gaps by name, heaviest first, and how many more.
    private func named(_ gaps: [PlantGaps.Gap]) -> String {
        let first = gaps.prefix(4).map { $0.label.lowercased() }.joined(separator: ", ")
        return gaps.count > 4 ? "\(first) and \(gaps.count - 4) more" : first
    }
}

// MARK: - In a conversation

/// Eira's card when what was said names a plant the library does not
/// have: "Medlar is not in your plant library yet."
///
/// Pressing the button opens the form for a new plant with the name
/// filled in. Nothing is added by the card itself.
struct NewPlantOfferCard: View {

    let name: String
    let onDismiss: () -> Void

    @State private var isAdding = false

    var body: some View {
        OfferFrame("\(name) is not in your plant library yet",
                   addTitle: "Add it and look it up",
                   refuseTitle: "No thanks",
                   canAdd: true,
                   onAdd: { isAdding = true },
                   onRefuse: onDismiss) {
            Text("I can add it and look up what the RHS says about it. You approve each fact before it is kept.")
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .sheet(isPresented: $isAdding, onDismiss: onDismiss) {
            NewPlantSheet(startingName: name)
        }
    }
}
