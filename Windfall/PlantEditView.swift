//
//  PlantEditView.swift
//  Windfall
//
//  The sheet that adds to and changes what is known about a plant.
//
//  Why it exists: until 14 November 2026 a plant's facts could only
//  come in from the spreadsheet file. Nothing in the app could add one
//  or put one right. (William, that day, on a plant's page: "It doesn't
//  seem to show any way to add information about the plants either".)
//
//  How it works, in three steps:
//
//  1. When the sheet opens it takes a copy of every fact as text
//     (`values`). All the typing happens in the copy.
//  2. Nothing reaches the plant's record until Save is pressed, so
//     Cancel has nothing to undo.
//  3. Save writes only the facts that differ from the record, and notes
//     each as changed by hand. Loading the spreadsheet file again then
//     leaves those facts as they are.
//
//  Which facts there are is not decided here. The sheet draws whatever
//  is in the list in PlantFacts.swift, card by card, which is the same
//  list the plant's page is drawn from. A fact added to that list
//  appears in both places with no change to this file.
//

import SwiftUI

struct PlantEditView: View {

    /// The plant being changed.
    let plant: Plant
    /// The card the sheet scrolls to when it opens: the one whose Edit
    /// button was pressed.
    private let opensAt: PlantFacts.Group

    /// How to close the sheet, handed down by SwiftUI.
    @Environment(\.dismiss) private var dismiss

    /// The sheet's working copy: every fact as text, by its key. A
    /// `[String: String]` is a "dictionary": a set of pairs, here a key
    /// such as "spacingM" and the text typed for it.
    @State private var values: [String: String]
    /// True when changes typed before and not saved were put back.
    @State private var carriedOn = false

    init(plant: Plant, openingAt factGroup: PlantFacts.Group = .naming) {
        self.plant = plant
        opensAt = factGroup
        // The copy is taken once, here, as the sheet is made.
        _values = State(initialValue: PlantFacts.values(of: plant))
    }

    /// The facts typed differently from the record, worked out afresh
    /// each time the sheet redraws.
    private var changes: [PlantFacts.Field] { PlantFacts.changed(values, from: plant) }

    /// What is kept if the sheet is closed without Save (review pass, 21
    /// November 2026, doc 145): only the facts typed differently, so a
    /// fact changed some other way meanwhile (a fill-in, a new
    /// spreadsheet) is not put back over. See FormDraft.swift.
    private var draft: [String: String] {
        Dictionary(uniqueKeysWithValues: changes.map { ($0.key, values[$0.key] ?? "") })
    }
    private var draftKey: String { FormDraft.key("plant-edit", plant.id) }

    /// True if the name box has been emptied. A plant must have a name.
    private var nameIsBlank: Bool {
        (values["commonName"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        let changeCount = changes.count

        // Built from the pieces in SheetParts.swift, like the sowing form.
        SheetPage("Edit \(plant.commonName)",
                  // The line under the title counts the changes. It is
                  // left out until there is one.
                  detail: changeCount == 0 ? nil : changeCount == 1 ? "1 fact changed" : "\(changeCount) facts changed",
                  confirmTitle: "Save",
                  canConfirm: changeCount > 0 && !nameIsBlank,
                  onConfirm: save) {
            // A ScrollViewReader can move the scrolling area inside it
            // to any view that has been given an `id`.
            ScrollViewReader { scroller in
                SheetScroll {
                    if carriedOn {
                        DraftNotice {
                            values = PlantFacts.values(of: plant)
                            FormDraft.clear(key: draftKey)
                            carriedOn = false
                        }
                    }
                    Text("What you change here is kept when the spreadsheet file is loaded again.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)

                    ForEach(PlantFacts.Group.allCases) { factGroup in
                        card(for: factGroup)
                            .id(factGroup)
                    }
                }
                // Once the sheet is up, bring the wanted card to the top.
                .task {
                    if opensAt != .naming { scroller.scrollTo(opensAt, anchor: .top) }
                }
                // A checking aid, for the example garden only: types
                // the changes named when the app was started, and saves
                // them if asked. See DemoGarden.typedEdits.
                .onAppear {
                    for (key, text) in DemoGarden.typedEdits { values[key] = text }
                    if DemoGarden.savesTypedEdits { save() }
                }
            }
        }
        // A swipe down closes the sheet, changes typed or not: they are
        // kept until Save or Clear (review pass, 21 November 2026). Until
        // then a swipe down did nothing once something was changed.
        .keepsDraft(draftKey, draft, isEmpty: changeCount == 0, carriedOn: $carriedOn) { typedBefore in
            values.merge(typedBefore) { _, fromBefore in fromBefore }
        }
    }

    // MARK: One card

    /// One group of facts, laid out as its card on the page is: rows of
    /// months, then short facts side by side, then long ones full
    /// width, then the yes-or-no ones as tick boxes.
    private func card(for factGroup: PlantFacts.Group) -> some View {
        // Notes are typed in their own sheet (PlantNotesView.swift), so
        // there is one place to change them, not two.
        let fields = PlantFacts.cardFields(in: factGroup)
        let monthFields = fields.filter { if case .months = $0.kind { return true } else { return false } }
        let longFields = fields.filter { $0.kind == .longText }
        let tickFields = fields.filter { $0.kind == .yesNo }
        let shortFields = fields.filter { factField in
            switch factField.kind {
            case .text, .measure, .duration: return true
            case .longText, .months, .yesNo: return false
            }
        }

        return SheetCard(factGroup.title) {
            ForEach(monthFields) { factField in
                if case .months(let monthKind) = factField.kind {
                    MonthPicker(label: factField.label, text: typed(factField.key), tint: monthKind.tint)
                }
            }

            if !shortFields.isEmpty {
                // As many across as will fit, each at least 200 points
                // wide: one on an iPhone, two on a Mac's sheet and three
                // when the sheet is made larger.
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12, alignment: .topLeading)],
                          alignment: .leading, spacing: 10) {
                    ForEach(shortFields) { factField in
                        labelled(factField) {
                            HStack(spacing: 6) {
                                TextField(example(factField), text: typed(factField.key))
                                // A measurement has its unit beside the
                                // box, so only the figure is typed.
                                if case .measure(let unit) = factField.kind {
                                    Text(unit)
                                        .foregroundStyle(Theme.inkSoft)
                                }
                            }
                        }
                    }
                }
            }

            ForEach(longFields) { factField in
                labelled(factField) {
                    // `axis: .vertical` lets the box grow downwards as
                    // more is typed, from one line up to eight.
                    TextField(example(factField), text: typed(factField.key), axis: .vertical)
                        .lineLimit(1...8)
                }
            }

            if !tickFields.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10, alignment: .leading)],
                          alignment: .leading, spacing: 10) {
                    ForEach(tickFields) { factField in
                        tick(factField)
                    }
                }
            }

            if factGroup == .naming, changes.contains(where: { $0.key == "commonName" || $0.key == "variety" }),
               plant.sourceSheet != nil {
                Text("The spreadsheet file knows this plant by its old name and variety. Windfall remembers them, so loading the file again still finds this plant.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Pieces

    /// A way for a text box to read and write one entry of `values`.
    ///
    /// A TextField needs a `Binding`: a pair of small pieces of code,
    /// one that fetches the text and one that stores what was typed.
    /// Each box gets its own, made here from its fact's key.
    private func typed(_ key: String) -> Binding<String> {
        Binding(get: { values[key] ?? "" },
                set: { values[key] = $0 })
    }

    /// The grey words in an empty box. They begin "e.g." so that an
    /// example is never taken for something the record holds.
    private func example(_ factField: PlantFacts.Field) -> String {
        factField.hint.isEmpty ? "" : "e.g. \(factField.hint)"
    }

    /// A fact's name in small soft letters above its box.
    private func labelled<Box: View>(_ factField: PlantFacts.Field, @ViewBuilder box: () -> Box) -> some View {
        // The box is made here, once, and the finished box is handed to
        // FieldBox. FieldBox keeps hold of what it is given to use
        // later, and Swift does not let it keep `box` itself, which is
        // only lent to this function for as long as it runs.
        let inside = box()
        return VStack(alignment: .leading, spacing: 5) {
            Text(factField.label)
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
            FieldBox {
                inside
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A yes-or-no fact as a box to tick.
    private func tick(_ factField: PlantFacts.Field) -> some View {
        let isOn = values[factField.key] == PlantFacts.yes
        return Button {
            values[factField.key] = isOn ? "" : PlantFacts.yes
        } label: {
            HStack(spacing: 10) {
                TickBox(isOn: isOn)
                Text(factField.label)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func save() {
        FormDraft.clear(key: draftKey)
        PlantFacts.save(values, to: plant)
        dismiss()
    }
}

// MARK: - Choosing months

/// Twelve buttons, January to December. Pressing one switches that
/// month on or off. Drawn like the strips on a plant's page, but taller
/// so that a finger can hit one.
private struct MonthPicker: View {

    let label: String
    /// The fact's text, such as "jan feb mar". `@Binding` means this
    /// view reads and changes text that is kept somewhere else: in the
    /// sheet's `values`.
    @Binding var text: String
    let tint: Color

    var body: some View {
        // The months the text names. MonthParser reads any of the ways
        // the spreadsheet writes them.
        let chosen = MonthParser.months(in: text)

        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)

            HStack(spacing: 4) {
                ForEach(1...12, id: \.self) { month in
                    let isOn = chosen.contains(month)
                    Button {
                        // The text is rewritten with that month added or
                        // taken away. See PlantFacts.toggling.
                        text = PlantFacts.toggling(month, in: text)
                    } label: {
                        VStack(spacing: 3) {
                            Text(String(Array("JFMAMJJASOND")[month - 1]))
                                .font(.caption)
                                .foregroundStyle(Theme.inkSoft)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isOn ? tint : Theme.hairline.opacity(0.7))
                                .frame(height: 24)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    // VoiceOver says "March, selected" and not "M".
                    .accessibilityLabel(Calendar.current.monthSymbols[month - 1])
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }

            // Words that are not months, such as "Spring to summer".
            // They are kept as they are unless a month is chosen.
            if !text.isEmpty && chosen.isEmpty {
                Text("The record says “\(text)”, which is not a list of months. Choosing a month replaces it.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
