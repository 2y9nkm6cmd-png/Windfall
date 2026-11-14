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

    /// Goes up by one each time the cursor should be put in the box.
    /// The box watches the number and takes the cursor when it changes.
    /// A number is used, not true and false, so that asking twice in a
    /// row still counts as two requests.
    @State private var cursorRequests = 0

    var body: some View {
        HStack(spacing: 4) {
            // The magnifying glass.
            Button(action: pressGlass) {
                Label(prompt, systemImage: "magnifyingglass")
            }
            .help(open ? "Close search" : "\(prompt) (Command-F)")

            if open {
                // The box itself is AppKit's text field, not SwiftUI's
                // `TextField`. See ToolbarTextBox below for why.
                ToolbarTextBox(
                    text: $text,
                    prompt: prompt,
                    cursorRequests: cursorRequests,
                    // Escape empties the box and closes it.
                    onEscape: close,
                    // Clicking away from an empty box closes it. A box
                    // with words in it stays open, so it is always plain
                    // why the list is short.
                    onLeave: { if text.isEmpty { open = false } }
                )
                .frame(width: 190)

                if !text.isEmpty {
                    Button {
                        text = ""
                        cursorRequests += 1
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
        // Words can arrive from outside, for example "Clear" being pressed.
        .onChange(of: text) { _, words in
            if !words.isEmpty { open = true }
        }
        // "Find" in the Edit menu, or Command-F. The menu sends a message
        // (see FindCommands below) and any search glass on screen hears it.
        // If the box is already open this just puts the cursor back in it.
        .onReceive(NotificationCenter.default.publisher(for: .windfallFind)) { _ in
            open = true
            cursorRequests += 1
        }
    }

    /// The glass opens the box. Pressed again with nothing typed, it
    /// closes it. With words typed, it puts the cursor back in the box.
    private func pressGlass() {
        if open && text.isEmpty {
            open = false
        } else {
            open = true
            cursorRequests += 1
        }
    }

    private func close() {
        text = ""
        open = false
    }
}

// MARK: - The box to type in

/// The text box inside the glass.
///
/// Why it is not SwiftUI's own `TextField`: the first version was, with
/// `@FocusState` to put the cursor in it. Inside a Mac toolbar that did
/// nothing. The box opened and the cursor stayed where it was, with or
/// without a pause first (tried 14 November 2026, while the same
/// `@FocusState` worked for Eira's bar in the same window). So this uses
/// AppKit, the older Mac toolkit that SwiftUI sits on, where the window
/// can be told outright which box has the cursor.
///
/// `NSViewRepresentable` is SwiftUI's way of holding an AppKit view.
/// SwiftUI calls `makeNSView` once to build it and `updateNSView` each
/// time something it depends on changes.
private struct ToolbarTextBox: NSViewRepresentable {

    @Binding var text: String
    let prompt: String
    let cursorRequests: Int
    let onEscape: () -> Void
    let onLeave: () -> Void

    func makeNSView(context: Context) -> CursorTakingField {
        let field = CursorTakingField()
        field.placeholderString = prompt
        // No border, background or blue ring of its own. The toolbar's
        // glass is the box.
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        // One line that scrolls sideways when the words are too long.
        field.cell?.usesSingleLineMode = true
        field.cell?.isScrollable = true
        // The helper below is told about typing, Escape and leaving.
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: CursorTakingField, context: Context) {
        context.coordinator.textBox = self
        // Words changed from outside, such as the cross being pressed.
        if field.stringValue != text { field.stringValue = text }
        // A new request for the cursor since the last look.
        if context.coordinator.requestsSeen != cursorRequests {
            context.coordinator.requestsSeen = cursorRequests
            field.takeCursor()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// The helper AppKit reports to. AppKit tells a "delegate" object
    /// what happens in a text field, and this passes it on to SwiftUI.
    final class Coordinator: NSObject, NSTextFieldDelegate {
        /// Named `textBox`, not `box`: the project's cross-file check
        /// goes by names, and read every other `box` in the app (a
        /// rectangle on the garden plan) as one of these.
        var textBox: ToolbarTextBox
        /// Starts at 0, the same as a box that opens without being
        /// asked for, so that one does not grab the cursor.
        var requestsSeen = 0

        init(_ textBox: ToolbarTextBox) { self.textBox = textBox }

        /// A letter was typed or removed.
        func controlTextDidChange(_ note: Notification) {
            guard let field = note.object as? NSTextField else { return }
            textBox.text = field.stringValue
        }

        /// The cursor left the box.
        func controlTextDidEndEditing(_ note: Notification) {
            textBox.onLeave()
        }

        /// A key that is a command, not a letter. Escape arrives as
        /// "cancel". Returning true says it has been dealt with.
        func control(_ control: NSControl, textView: NSTextView, doCommandBy command: Selector) -> Bool {
            if command == #selector(NSResponder.cancelOperation(_:)) {
                textBox.onEscape()
                return true
            }
            return false
        }
    }
}

/// A text field that can be asked for the cursor before it has been
/// put in a window, and takes it as soon as it arrives there.
final class CursorTakingField: NSTextField {

    private var waitingForWindow = false

    func takeCursor() {
        guard let window else {
            waitingForWindow = true
            return
        }
        // "First responder" is AppKit's name for whatever has the cursor.
        // Done on the next turn of the app's loop, so it does not happen
        // in the middle of SwiftUI drawing the screen.
        DispatchQueue.main.async { window.makeFirstResponder(self) }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if waitingForWindow, window != nil {
            waitingForWindow = false
            takeCursor()
        }
    }
}

// MARK: - Find in the Edit menu

extension Notification.Name {
    /// The message sent when Find is chosen. A notification is a note
    /// pinned to a board that any part of the app can be watching. The
    /// menu does not need to know which screen is showing, and a screen
    /// with no search simply is not watching.
    static let windfallFind = Notification.Name("windfallFind")
}

/// "Find" in the Mac's Edit menu, with Command-F.
///
/// Why it is a menu line and not a shortcut on the glass itself: a
/// shortcut given to a button in the toolbar was not picked up when
/// William tried it (14 November 2026). A menu line always is, and the
/// Edit menu is where a Mac user looks for Find.
struct FindCommands: Commands {
    var body: some Commands {
        // `after: .pasteboard` puts it below Cut, Copy and Paste.
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Find") {
                NotificationCenter.default.post(name: .windfallFind, object: nil)
            }
            .keyboardShortcut("f", modifiers: .command)
        }
    }
}
#endif
