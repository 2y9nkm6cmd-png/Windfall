//
//  KeptFactViews.swift
//  Windfall
//
//  The screens for keeping a fact in a plant's record.
//
//  This file is only what you see. The rules are in KeptFacts.swift,
//  where they are tested, and the list of websites is in
//  EiraSources.swift.
//
//    FindOfferCard   under one of Eira's replies, when a lookup read a
//                    web page for it: "Keep this for next time?"
//    KeepFactSheet   the form for typing a fact in by hand, opened from
//                    a plant's page, and for changing a kept one
//    KeptFactRow     one kept fact: its words, its source, its buttons
//    KeptFactsCard   the kept facts on a plant's page
//    KeptFactsView   every kept fact, from the chat's Options menu
//
//  In all of them nothing is written to a plant's record until a button
//  is pressed, and every kept fact can be taken back.
//

import SwiftUI
import SwiftData

// MARK: - Pieces shared by the card and the form

/// Where a fact is going and what it will do there: the box of the
/// plant's record, the months it will hold if it is a box of months,
/// and what the box holds now with a switch to replace it or add to it.
///
/// The card in the chat and the form on a plant's page both use this,
/// so the two cannot drift apart.
private struct FactPlacement: View {

    /// The plants the fact would be written to.
    let plants: [Plant]
    let words: String
    // `@Binding` means the value lives in the view that made this one,
    // and a change here changes it there.
    @Binding var field: PlantField
    @Binding var how: KeptFacts.How

    /// What the chosen box holds now, across the plants. Usually one
    /// value or none. `Set` drops repeats.
    private var presentValues: [String] {
        Array(Set(plants.compactMap { field.value(in: $0) })).sorted()
    }

    var body: some View {
        SettingRow("Goes into") {
            // A Picker with the menu style is a button that opens a
            // list of choices. `.tag` says which value each line stands
            // for.
            Picker("Goes into", selection: $field) {
                ForEach(PlantField.allCases) { each in
                    Text(each.label).tag(each)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }

        if field.holdsMonths {
            let found = KeptFacts.months(in: words)
            if found.isEmpty {
                Label("\(field.label) holds months, and no month can be read from this. Choose another place, such as Notes.",
                      systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(Theme.amber)
            } else {
                Text("\(field.label) will hold: \(KeptFacts.monthsText(found))")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
        }

        if !presentValues.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("It holds now: \(presentValues.joined(separator: " / "))")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(4)
                GlassSwitch(choices: KeptFacts.How.allCases, selection: $how) { $0.title }
            }
        }
    }
}

// MARK: - The card under one of Eira's replies

/// "Keep this for next time?" Shown under a reply of Eira's that was
/// built on something a lookup read online.
///
/// The card says where the fact would go and where it came from, and
/// everything on it can be changed first: the words, the plant and the
/// box. Once kept it shrinks to a line that says where it went, with a
/// way to take it back.
struct FindOfferCard: View {

    private let offer: EiraConversation.OfferedFind
    private let onKept: ([UUID], String) -> Void
    private let onUndone: () -> Void
    private let onDismiss: () -> Void
    private let onShowAll: () -> Void

    @Environment(\.modelContext) private var context
    // `@Query` reads these from the database and keeps them up to date.
    @Query(sort: \Plant.commonName) private var plants: [Plant]
    @Query private var keptFacts: [KeptFact]

    @State private var words: String
    @State private var plantName: String
    @State private var field: PlantField
    @State private var how: KeptFacts.How = .add

    init(offer: EiraConversation.OfferedFind,
         onKept: @escaping ([UUID], String) -> Void,
         onUndone: @escaping () -> Void,
         onDismiss: @escaping () -> Void,
         onShowAll: @escaping () -> Void) {
        self.offer = offer
        self.onKept = onKept
        self.onUndone = onUndone
        self.onDismiss = onDismiss
        self.onShowAll = onShowAll
        // `_words` is the storage behind `@State var words`. This is how
        // a starting value is handed to it.
        _words = State(initialValue: offer.words)
        _plantName = State(initialValue: offer.onlineFind.plantName ?? "")
        _field = State(initialValue: offer.onlineFind.field)
    }

    /// Every variety of the plant named on the card.
    private var chosen: [Plant] {
        let wanted = plantName.trimmingCharacters(in: .whitespaces)
        guard !wanted.isEmpty else { return [] }
        return plants.filter { $0.commonName.caseInsensitiveCompare(wanted) == .orderedSame }
    }

    /// True if the fact could be written to at least one of them.
    private var canKeep: Bool {
        chosen.contains { KeptFacts.newValue(for: field, words: words, present: field.value(in: $0), how: how) != nil }
    }

    private var plantLine: String {
        switch chosen.count {
        case 0: return plantName.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Type the plant's name as your plant library has it."
            : "No plant of that name in your plant library."
        case 1: return "For \(chosen[0].displayName)."
        default: return "For all \(chosen.count) varieties of \(chosen[0].commonName)."
        }
    }

    var body: some View {
        if offer.isKept {
            keptLine
        } else {
            OfferFrame("Keep this for next time?",
                       addTitle: "Keep it",
                       refuseTitle: "No thanks",
                       canAdd: canKeep,
                       onAdd: keep,
                       onRefuse: onDismiss) {
                FieldBox {
                    TextField("The fact, in your own words", text: $words, axis: .vertical)
                        .lineLimit(2...6)
                }

                SettingRow("Plant") {
                    FieldBox {
                        TextField("Plant", text: $plantName)
                            .autocorrectionDisabled()
                    }
                    .frame(maxWidth: 220)
                }
                Text(plantLine)
                    .font(.footnote)
                    .foregroundStyle(chosen.isEmpty ? Theme.amber : Theme.inkSoft)

                FactPlacement(plants: chosen, words: words, field: $field, how: $how)

                sourceLine

                Text("It would be written into the plant's own record, with where it came from. Nothing is kept unless you press Keep it.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    /// The site, how far it is trusted, the page's title and a way to
    /// open it. The title is there so that a wrong page is plain to see.
    private var sourceLine: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text("From \(offer.onlineFind.sourceName) · \(offer.onlineFind.trust.label)")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.ink)
                if let url = URL(string: offer.onlineFind.address) {
                    Link("Open the page", destination: url)
                        .font(.footnote)
                        .foregroundStyle(Theme.leaf)
                }
            }
            if let title = offer.onlineFind.title, !title.isEmpty {
                Text("The page is called \u{201C}\(title)\u{201D}.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    /// What the card becomes once the fact is kept.
    private var keptLine: some View {
        HStack(spacing: 10) {
            Label("Kept in \(offer.keptWhere)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Theme.leaf)
            Button("Undo") { undo() }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.inkSoft)
                .underline()
            Button("See all") { onShowAll() }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.inkSoft)
                .underline()
        }
        .font(.footnote)
    }

    /// Writes the fact into the record of each plant chosen, and tells
    /// the conversation where it went.
    private func keep() {
        let shelf = KeptFactStore(context: context)
        let made = shelf.keep(
            words: words, in: field, of: chosen, how: how,
            sourceName: offer.onlineFind.sourceName, sourceAddress: offer.onlineFind.address,
            trust: offer.onlineFind.trust, question: offer.question)
        guard let first = chosen.first, !made.isEmpty else { return }
        onKept(made.map(\.id), "\(first.commonName), \(field.label)")
    }

    /// Takes the fact back out of the record and offers it again.
    private func undo() {
        for fact in keptFacts where offer.keptIDs.contains(fact.id) {
            KeptFactStore(context: context).remove(fact)
        }
        onUndone()
    }
}

// MARK: - Typing a fact in by hand

/// The form for keeping a fact you read yourself: in a book, on a seed
/// packet, on a website. Opened from a plant's page.
///
/// It is also how a kept fact is changed. Given `replacing`, it opens
/// with that fact's words, and saving takes the old one out before the
/// new one goes in.
struct KeepFactSheet: View {

    let plant: Plant
    /// The other varieties of the same plant, if any.
    let others: [Plant]
    /// A kept fact this one takes the place of, when changing one.
    let replacing: KeptFact?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var words: String
    @State private var field: PlantField
    @State private var how: KeptFacts.How = .add
    @State private var sourceName: String
    @State private var address: String
    @State private var alsoOthers = false

    init(plant: Plant, others: [Plant] = [], replacing: KeptFact? = nil) {
        self.plant = plant
        self.others = others
        self.replacing = replacing
        _words = State(initialValue: replacing?.words ?? "")
        _field = State(initialValue: replacing?.field ?? .notes)
        _sourceName = State(initialValue: replacing?.sourceName ?? "")
        _address = State(initialValue: replacing?.sourceAddress ?? "")
    }

    private var chosen: [Plant] { alsoOthers ? [plant] + others : [plant] }

    private var trimmedAddress: String { address.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The site, if a web address was given and it reads as one.
    private var site: WebSource? {
        guard !trimmedAddress.isEmpty, WebPageReader.webURL(from: trimmedAddress) != nil else { return nil }
        return WebSources.source(forAddress: trimmedAddress)
    }

    private var canKeep: Bool {
        KeptFacts.newValue(for: field, words: words, present: field.value(in: plant), how: how) != nil
    }

    var body: some View {
        SheetPage(replacing == nil ? "Keep a fact" : "Change a kept fact",
                  detail: plant.displayName,
                  confirmTitle: "Keep",
                  canConfirm: canKeep,
                  onConfirm: save) {
            SheetScroll {
                SheetCard("The fact") {
                    FieldBox {
                        // `axis: .vertical` lets the box grow downwards
                        // as you type, from three lines up to eight.
                        TextField("Cut the old leaves away once they have died back.",
                                  text: $words, axis: .vertical)
                            .lineLimit(3...8)
                    }
                    Text("Write it in your own words, as a plain fact.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                    FactPlacement(plants: [plant], words: words, field: $field, how: $how)
                }

                SheetCard("Where you read it") {
                    FieldBox {
                        TextField("RHS, a book, a seed packet, a neighbour", text: $sourceName)
                    }
                    FieldBox {
                        TextField("Web address, if it has one", text: $address)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            #endif
                    }
                    if let site {
                        Text("\(site.name) · \(site.trust.label)")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Text("This is kept beside the fact, shown on the plant's page and told to Eira. After two years the fact is marked as due a check.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }

                if !others.isEmpty && replacing == nil {
                    SheetCard {
                        Toggle("Also keep it for the other \(others.count == 1 ? "variety" : "\(others.count) varieties") of \(plant.commonName)",
                               isOn: $alsoOthers)
                            .tint(Theme.leaf)
                            .foregroundStyle(Theme.ink)
                    }
                }
            }
        }
    }

    private func save() {
        let shelf = KeptFactStore(context: context)
        // Changing a fact: the old one comes out first, which puts the
        // box back as it was, and then the new one goes in.
        if let replacing { shelf.remove(replacing) }

        let typedName = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        shelf.keep(words: words, in: field, of: chosen, how: how,
                   sourceName: typedName.isEmpty ? (site?.name ?? "") : typedName,
                   sourceAddress: site == nil ? nil : trimmedAddress,
                   trust: site?.trust ?? .ownReading)
        dismiss()
    }
}

// MARK: - One kept fact

/// One kept fact: which box it went into, its words, where it came from
/// and what can be done with it.
struct KeptFactRow: View {

    let fact: KeptFact
    /// True in the list of every fact, where the plant must be named.
    var showsPlant = false
    let onChange: () -> Void

    @Environment(\.modelContext) private var context

    private var isDue: Bool { KeptFacts.isDue(fact) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(showsPlant ? "\(fact.plantName) · \(fact.boxLabel)" : fact.boxLabel)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                if isDue {
                    Text("Due a check")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Theme.amber.opacity(0.3), in: .capsule)
                }
            }

            Text(fact.words)
                .font(.body)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            Text("\(KeptFacts.sourceLabel(for: fact)) · \(fact.trust.label)")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)

            if isDue {
                Text("Kept over two years ago. Advice changes, so it is worth a look at the source. Eira goes on using it meanwhile.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }

            HStack(spacing: 8) {
                if let address = fact.sourceAddress, let url = WebPageReader.webURL(from: address) {
                    Link("Open the source", destination: url)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.leaf)
                }
                Spacer(minLength: 0)
                if isDue {
                    Button("Still right") { KeptFactStore(context: context).markChecked(fact) }
                        .buttonStyle(QuietGlassButton())
                }
                // A fact kept by filling in a plant's gaps can sit in a
                // box this form does not offer. Those are changed with
                // the plant's own Edit sheet.
                if fact.canChangeInForm {
                    Button("Change it") { onChange() }
                        .buttonStyle(QuietGlassButton())
                }
                Button("Remove") { KeptFactStore(context: context).remove(fact) }
                    .buttonStyle(QuietGlassButton())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - On a plant's page

/// The card on a plant's page: the facts kept for this plant, and the
/// button to keep another.
struct KeptFactsCard: View {

    let plant: Plant
    /// Every kept fact. The card picks out this plant's.
    let allFacts: [KeptFact]
    let onKeep: () -> Void
    let onChange: (KeptFact) -> Void

    private var facts: [KeptFact] {
        allFacts.filter { $0.plantID == plant.id }.sorted { $0.keptAt > $1.keptAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kept facts")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)

            if facts.isEmpty {
                Text("Something you have read about this plant can be kept in its record, with where you read it.")
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)
            }

            ForEach(facts) { fact in
                KeptFactRow(fact: fact) { onChange(fact) }
                if fact.id != facts.last?.id { Divider() }
            }

            Button("Keep a fact") { onKeep() }
                .buttonStyle(QuietGlassButton())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

// MARK: - Every kept fact

/// Every kept fact, those due a check first. Opened from the Options
/// menu of Eira's chat.
struct KeptFactsView: View {

    @Query(sort: [SortDescriptor(\KeptFact.keptAt, order: .reverse)])
    private var facts: [KeptFact]
    @Query private var plants: [Plant]

    /// The fact being changed, while its form is open.
    @State private var changing: KeptFact?

    /// Those due a check come first. Within each, newest first.
    private var ordered: [KeptFact] {
        facts.filter { KeptFacts.isDue($0) } + facts.filter { !KeptFacts.isDue($0) }
    }

    private var detail: String {
        let due = facts.filter { KeptFacts.isDue($0) }.count
        if facts.isEmpty { return "Facts you have chosen to keep in a plant's record, from a website or your own reading." }
        return due == 0
            ? "Each is in its plant's record, where Eira finds it. A fact is due a check two years after it was kept."
            : "\(due) due a check. Each is in its plant's record, where Eira finds it."
    }

    var body: some View {
        SheetPage("Kept facts", detail: detail, dismissTitle: "Done") {
            SheetScroll {
                if facts.isEmpty {
                    SheetCard {
                        Text("Nothing yet. When Eira reads a web page for you, a card under her reply offers to keep what she found. Or open a plant's page and press \"Keep a fact\".")
                            .font(.body)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                ForEach(ordered) { fact in
                    SheetCard {
                        KeptFactRow(fact: fact, showsPlant: true) { changing = fact }
                    }
                }
            }
        }
        // `.sheet(item:)` puts the form up while `changing` holds a
        // fact, and sets it back to nothing when the form closes.
        .sheet(item: $changing) { fact in
            if let plant = plants.first(where: { $0.id == fact.plantID }) {
                KeepFactSheet(plant: plant, replacing: fact)
            } else {
                // The plant has gone from the library. The fact can
                // still be removed from the list.
                SheetPage("Change a kept fact", detail: fact.plantName, dismissTitle: "Close") {
                    SheetScroll {
                        SheetCard {
                            Text("This plant is no longer in your plant library, so there is no record to change. The fact can be removed from the list.")
                                .foregroundStyle(Theme.ink)
                        }
                    }
                }
            }
        }
    }
}
