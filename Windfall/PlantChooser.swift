//
//  PlantChooser.swift
//  Windfall
//
//  Choosing one plant from the whole library, with a row of letters to
//  jump by.
//
//  Until 14 November 2026 "Which plant" on the sighting form was a
//  standard menu: every plant in one long list, 376 of them, to be
//  scrolled from the top. William: "could you make it so that you can
//  select letters of the alphabet for the first letter so that you can
//  jump to those plants first."
//
//  PlantChooser      the box on the form. It shows the chosen plant and
//                    opens the list
//  PlantChooserList  the list: a row of letters, then the plants under
//                    a heading for each letter
//
//  The sorting and the splitting by letter are in PlantFilter.swift
//  (`PlantLetters`), where they can be tested without a screen.
//

import SwiftUI

// MARK: - The box on the form

/// A box showing the chosen plant. Pressing it opens the list.
struct PlantChooser: View {

    /// Every plant that can be chosen.
    let plants: [Plant]
    /// The chosen plant, or nil for none. A "binding" is a two-way link
    /// to a value kept somewhere else, here on the sighting, so choosing
    /// a plant in the list changes the sighting itself.
    @Binding var selection: Plant?
    /// The words in the box.
    let shown: String

    /// True while the list is open. `@State` is a value this view keeps
    /// for itself, and the view is drawn again whenever it changes.
    @State private var isOpen = false

    var body: some View {
        Button {
            isOpen = true
        } label: {
            ChoiceLabel(shown: shown)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Which plant")
        .accessibilityValue(shown)
        // A popover is a panel that points at what opened it. On an
        // iPhone there is no room for one, so the same list slides up
        // as a sheet instead. SwiftUI makes that change by itself.
        .popover(isPresented: $isOpen) {
            PlantChooserList(plants: plants, selection: $selection)
        }
        // A checking aid: opens the list by itself a moment after the
        // form appears, so a still picture can be taken of it. See
        // DemoGarden.jumpsToPlantLetter.
        .task {
            guard DemoGarden.jumpsToPlantLetter != nil else { return }
            // Waits for the form's own sheet to finish sliding up. A
            // panel cannot open while another is still arriving.
            try? await Task.sleep(for: .seconds(1.5))
            isOpen = true
        }
    }
}

// MARK: - The list

/// The list of plants, split up by first letter, under a row of letters
/// that jump to each.
struct PlantChooserList: View {

    @Binding private var selection: Plant?
    /// The plants in order and split up by letter. Worked out once, as
    /// the list opens, not every time it is drawn.
    private let groups: [LetterGroup<Plant>]
    /// The letters that have a plant under them. A `Set` answers "is
    /// this letter in here?" quickly.
    private let lettersInUse: Set<String>

    /// How to close this panel, handed down by SwiftUI.
    @Environment(\.dismiss) private var dismiss

    init(plants: [Plant], selection: Binding<Plant?>) {
        // The underscore reaches the binding itself, not the plant it
        // points at.
        _selection = selection
        let groups = PlantLetters.groups(plants, name: { $0.commonName }, detail: { $0.variety })
        self.groups = groups
        lettersInUse = Set(groups.map(\.letter))
    }

    /// The letters on the row: A to Z, then "#" when a plant's name
    /// begins with something that is not a letter.
    private var letters: [String] {
        PlantLetters.alphabet + (lettersInUse.contains(PlantLetters.other) ? [PlantLetters.other] : [])
    }

    var body: some View {
        // A ScrollViewReader can move the scrolling area inside it to
        // any view that has been given a name with `.id`. `scroller` is
        // the handle it gives for doing that.
        ScrollViewReader { scroller in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Which plant")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Button("Cancel") { dismiss() }
                        .buttonStyle(QuietGlassButton())
                }

                letterRow(scroller)

                ScrollView {
                    // Not a "lazy" stack, which builds rows only as they
                    // come into view and so has to guess how far down a
                    // row it has not built yet is. With every row built,
                    // a jump lands exactly on its letter. A few hundred
                    // rows of text are quick to build.
                    VStack(alignment: .leading, spacing: 2) {
                        row("None", isChosen: selection == nil) { choose(nil) }

                        ForEach(groups) { group in
                            Text(group.letter)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.inkSoft)
                                .padding(.horizontal, 12)
                                .padding(.top, 12)
                                .padding(.bottom, 2)
                                // VoiceOver reads this as a heading, so
                                // its rotor can step from letter to letter.
                                .accessibilityAddTraits(.isHeader)
                                // The name the row of letters jumps to.
                                .id(group.letter)

                            ForEach(group.items) { plant in
                                row(plant.displayName, isChosen: selection == plant) { choose(plant) }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .onAppear {
                // Opens at the chosen plant's letter, so the tick is in
                // view. (Or, for checking, at the letter asked for.)
                let chosen = selection.map { PlantLetters.letter(for: $0.commonName) }
                if let letter = DemoGarden.jumpsToPlantLetter ?? chosen, lettersInUse.contains(letter) {
                    scroller.scrollTo(letter, anchor: .top)
                }
            }
        }
        // Smallest, usual and largest size. A popover opens at "usual"
        // (ideal). A sheet on an iPhone fills whatever it is given.
        .frame(minWidth: 300, idealWidth: 400, maxWidth: .infinity,
               minHeight: 320, idealHeight: 560, maxHeight: .infinity, alignment: .top)
        .background { PaperBackground() }
    }

    // MARK: The row of letters

    /// The letters, wrapping on to a second line where they do not fit
    /// on one. A letter with no plants under it is greyed out.
    private func letterRow(_ scroller: ScrollViewProxy) -> some View {
        // "Adaptive" columns fit as many 30-point letters across as
        // there is room for, and start a new line for the rest.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 30), spacing: 4)], spacing: 4) {
            ForEach(letters, id: \.self) { letter in
                let isInUse = lettersInUse.contains(letter)
                Button {
                    // `withAnimation` makes the list glide to the letter
                    // and not snap. `anchor: .top` puts the letter's
                    // heading at the top of the list.
                    withAnimation(.smooth(duration: 0.25)) {
                        scroller.scrollTo(letter, anchor: .top)
                    }
                } label: {
                    Text(letter)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isInUse ? Theme.ink : Theme.inkSoft.opacity(0.45))
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background(isInUse ? Theme.leafFill.opacity(0.55) : .clear, in: .rect(cornerRadius: 8))
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(!isInUse)
                .accessibilityLabel(letter == PlantLetters.other ? "Jump to other names" : "Jump to \(letter)")
            }
        }
    }

    // MARK: A row of the list

    /// One line of the list: a tick if it is the chosen one, then the name.
    private func row(_ words: String, isChosen: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.leaf)
                    // Always there and only shown when chosen, so every
                    // name starts at the same place.
                    .opacity(isChosen ? 1 : 0)
                Text(words)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isChosen ? Theme.leafFill.opacity(0.55) : .clear, in: .rect(cornerRadius: 10))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    /// Sets the plant and closes the list.
    private func choose(_ plant: Plant?) {
        selection = plant
        dismiss()
    }
}
