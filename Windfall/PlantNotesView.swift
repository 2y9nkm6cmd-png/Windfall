//
//  PlantNotesView.swift
//  Windfall
//
//  A plant's notes, in a sheet of their own.
//
//  Why it exists: the Notes column of the spreadsheet came into the app
//  (161 plants have notes, most of them the sowing text from a seed
//  packet), but it was the last thing on a plant's page, under every
//  other card, and nobody found it. William, 21 November 2026, from the
//  iPad: "make it a button that you can tap under or near the edit
//  button that opens a card with the notes on and allows you to tap
//  into it and add more notes if you need to." (Project doc 150.)
//
//  How it works:
//
//  1. The Notes button under Edit on a plant's page opens this sheet.
//  2. The notes are in one box. Tap anywhere in it to type: to change a
//     word, or to add to the end.
//  3. "Add a note" starts a new paragraph at the end with today's date,
//     so a note added in the app can be told apart from the packet's.
//  4. Save writes the notes through PlantFacts.write, which marks them
//     as changed by hand, so loading the spreadsheet file again keeps
//     them. Cancel or a swipe down keeps what was typed until Save or
//     Clear, as every other form does (FormDraft.swift).
//

import SwiftUI

struct PlantNotesView: View {

    /// The plant whose notes these are.
    let plant: Plant

    /// How to close the sheet, handed down by SwiftUI.
    @Environment(\.dismiss) private var dismiss

    /// The notes as they are being typed. Nothing reaches the plant's
    /// record until Save.
    @State private var text: String
    /// True when typing kept from before was put back.
    @State private var carriedOn = false
    /// True while the box has the keyboard. `@FocusState` is SwiftUI's
    /// way of saying which box is being typed in; setting it to true
    /// puts the cursor in the box.
    @FocusState private var isTyping: Bool

    init(plant: Plant) {
        self.plant = plant
        // The copy is taken once, here, as the sheet is made.
        _text = State(initialValue: plant.notes ?? "")
    }

    /// The notes as the record holds them now.
    private var notesOnRecord: String { plant.notes ?? "" }

    /// True when something differs from the record. Spaces at either
    /// end do not count, because Save trims them off anyway.
    private var hasChanged: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            != notesOnRecord.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The name of this sheet's kept copy: one for each plant.
    private var draftKey: String { FormDraft.key("plant-notes", plant.id) }

    var body: some View {
        SheetPage("Notes",
                  // "African Daisy 'Pink Sun'", so it is plain which
                  // plant these are.
                  detail: PlantPage.notesTitleLine(plant),
                  confirmTitle: "Save",
                  canConfirm: hasChanged,
                  onConfirm: save) {
            SheetScroll {
                if carriedOn {
                    DraftNotice {
                        text = notesOnRecord
                        FormDraft.clear(key: draftKey)
                        carriedOn = false
                    }
                }

                SheetCard {
                    // `axis: .vertical` makes the box grow downwards as
                    // the text grows, so long packet notes are shown in
                    // full and the sheet scrolls, instead of the box
                    // scrolling on its own inside it.
                    FieldBox {
                        TextField("Nothing yet. Tap here to write a note about this plant.",
                                  text: $text, axis: .vertical)
                            .font(.body)
                            .lineLimit(4...)
                            .focused($isTyping)
                    }

                    HStack(spacing: 10) {
                        Button {
                            addDatedNote()
                        } label: {
                            Label("Add a note", systemImage: "plus")
                        }
                        .buttonStyle(QuietGlassButton())
                        .accessibilityHint("Starts a new paragraph at the end, with today's date")

                        Spacer(minLength: 0)
                    }
                }

                Text("What you change here is kept when the spreadsheet file is loaded again.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
        // Typing not yet saved is kept if the sheet is swiped away, and
        // put back next time (review pass, 21 November 2026, doc 145).
        // The copy is taken away again if the box is put back as it was.
        .keepsDraft(draftKey, text, isEmpty: !hasChanged, carriedOn: $carriedOn) { typedBefore in
            text = typedBefore
        }
    }

    /// Adds a blank line and today's date at the end, then puts the
    /// cursor in the box so the note can be typed straight away.
    private func addDatedNote() {
        text = PlantPage.addingDatedNote(to: text, on: .now)
        isTyping = true
    }

    private func save() {
        FormDraft.clear(key: draftKey)
        // Through the one list of facts, so the notes are marked as
        // changed by hand and a later load of the spreadsheet file
        // leaves them alone. An emptied box clears the notes.
        PlantFacts.write(text, forKey: "notes", to: plant)
        dismiss()
    }
}
