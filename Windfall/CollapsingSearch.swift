//
//  CollapsingSearch.swift
//  Windfall
//
//  A search box for a Mac window's toolbar that rests as a magnifying
//  glass and opens into a box to type in when it is clicked.
//
//  Why it exists: SwiftUI's own `.searchable` puts a wide search box in
//  the toolbar for good. Apple does offer a version that shrinks to a
//  button (`.searchToolbarBehavior(.minimize)`), but marks it as not
//  available on a Mac, so this one is drawn here.
//
//  It only draws the box. What the typed words do is up to the screen
//  that owns the text, as with `.searchable`.
//

#if os(macOS)
import SwiftUI

struct CollapsingSearchField: View {

    /// The words typed. `@Binding` means this view does not keep the
    /// text itself. It reads and writes the screen's own copy, so the
    /// screen's list narrows as each letter is typed.
    @Binding var text: String

    /// The grey words shown in the empty box, such as "Search plants".
    let prompt: String

    /// True while the box is open. `@State` is a value the view keeps
    /// for itself and redraws when it changes.
    @State private var open = false

    /// True while the typing cursor is in the box. Setting it to true
    /// from code puts the cursor there.
    @FocusState private var typing: Bool

    var body: some View {
        HStack(spacing: 4) {
            // The magnifying glass. Always there, so Command-F always
            // has something to press.
            Button(action: pressGlass) {
                Label(prompt, systemImage: "magnifyingglass")
            }
            .keyboardShortcut("f", modifiers: .command)
            .help(open ? "Close search" : prompt)

            if open {
                TextField(prompt, text: $text)
                    .textFieldStyle(.plain)
                    .frame(width: 190)
                    .focused($typing)
                    // The box is not on screen at the moment the glass
                    // is pressed, so the cursor is placed once it
                    // has appeared.
                    .onAppear { typing = true }
                    // Escape empties the box and closes it.
                    .onExitCommand(perform: close)

                if !text.isEmpty {
                    Button {
                        text = ""
                        typing = true
                    } label: {
                        Label("Clear search", systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                }

                // A little room so the words do not touch the glass edge.
                Spacer().frame(width: 6)
            }
        }
        // If the screen opens with words already in the search, show them.
        .onAppear { if !text.isEmpty { open = true } }
        // Clicking away from an empty box closes it. A box with words
        // in it stays open, so it is always plain why the list is short.
        .onChange(of: typing) { _, isTyping in
            if !isTyping && text.isEmpty { open = false }
        }
        // Words can arrive from outside, for example "Clear" being pressed.
        .onChange(of: text) { _, words in
            if !words.isEmpty { open = true }
        }
    }

    /// The glass opens the box. Pressed again with nothing typed, it
    /// closes it. With words typed, it puts the cursor back in the box.
    private func pressGlass() {
        if open && text.isEmpty {
            open = false
        } else {
            open = true
            typing = true
        }
    }

    private func close() {
        text = ""
        open = false
    }
}
#endif
