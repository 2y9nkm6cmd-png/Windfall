//
//  EiraPanel.swift
//  Windfall
//
//  The panel that grows out of Eira's bar.
//
//  Until 14 November 2026 a conversation opened from the bar came up as
//  a sheet: a second window in the middle of the screen, with a box of
//  its own to type in, while the bar it came from sat idle underneath.
//  William, with a picture of the two together: "Can we make it so that
//  chat expands from the Eira bar, rather than opening up a new window?"
//
//  Now, on a Mac and an iPad, the bar itself grows upwards into a panel
//  of glass. The conversation is drawn inside it, and the box to type in
//  is along the panel's foot, where the bar was. "Done" lowers it back
//  into the bar. The page behind is not dimmed and can still be used.
//
//  This file holds the parts the bar and the two conversations share:
//
//  - `EiraPanelControls`: what a conversation is handed so that it can
//    close the panel or ask for the larger size.
//  - `EiraPanel`: the panel's sizes, kept in one place.
//  - `PanelPage`: the heading a conversation wears inside the panel.
//
//  The panel itself is drawn by EiraFloatingBar.swift, because it has
//  to start from exactly where the bar is.
//
//  On an iPhone nothing has changed: a conversation still slides up as
//  a sheet, which on a screen that size is nearly the same thing.
//

import SwiftUI

/// What a conversation is handed when it is drawn in the panel.
///
/// A conversation that is given one of these knows it is in the panel
/// and not in a sheet. `JournalChatView` and `EiraChatView` both take
/// one, and both work as before when given none.
struct EiraPanelControls {
    /// True while the panel is at its larger size. A `Binding` is a
    /// value that lives somewhere else (here, in the bar) and can be
    /// both read and changed from here.
    let isLarge: Binding<Bool>
    /// True if the conversation's box should take the keyboard as soon
    /// as the panel opens, so that typing carries straight on from the
    /// bar. Always true on a Mac. On an iPad it is true only if the
    /// bar's own box had the keyboard, so that giving Eira a photo does
    /// not make the keyboard jump up.
    let takesKeyboard: Bool
    /// Lowers the panel back into the bar.
    let close: () -> Void
}

/// The panel's sizes.
///
/// An `enum` with no cases cannot be made into a value. It is used
/// here only as a named place to keep these numbers and one sum.
enum EiraPanel {

    /// How wide the panel is, unless the bar is narrower or the larger
    /// size has been asked for. A line of text much wider than this is
    /// tiring to read.
    static let usualWidth: CGFloat = 760
    /// How tall the panel is, unless the page is shorter or the larger
    /// size has been asked for.
    static let usualHeight: CGFloat = 620
    /// The roundness of the panel's corners once it is up.
    static let corner: CGFloat = 28
    /// The space left between the panel's top and the top of the page.
    static let gapAbove: CGFloat = 12
    /// The panel is never shorter than this, however small the window.
    static let leastHeight: CGFloat = 280

    /// How tall the panel should be.
    ///
    /// - `room`: the distance from the top of the page down to the
    ///   bar's bottom edge, which is all the height there is. Nought
    ///   means it is not known, and the usual height is used.
    /// - `isLarge`: true once the button for the larger size has been
    ///   pressed, when the panel takes all the room.
    static func height(room: CGFloat, isLarge: Bool) -> CGFloat {
        guard room > 0 else { return usualHeight }
        let most = max(room - gapAbove, leastHeight)
        return isLarge ? most : min(most, usualHeight)
    }
}

/// The heading and frame of a conversation drawn inside the panel.
///
/// It does the job `SheetPage` does for a sheet: a title, a quieter
/// line under it, and the buttons on the right. It differs in three
/// ways. It paints no paper behind itself, because the panel is glass.
/// It sets no size, because the panel does. And its "Done" lowers the
/// panel, where a sheet's closes the sheet.
///
/// `Accessory` and `Content` are placeholders for "some kind of view".
/// `Accessory` is anything extra to put beside the buttons, such as the
/// Options menu in Eira's chat.
struct PanelPage<Accessory: View, Content: View>: View {

    private let title: String
    private let detail: String?
    private let controls: EiraPanelControls
    private let accessory: () -> Accessory
    private let content: () -> Content

    init(_ title: String,
         detail: String? = nil,
         controls: EiraPanelControls,
         @ViewBuilder accessory: @escaping () -> Accessory,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.detail = detail
        self.controls = controls
        self.accessory = accessory
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.title, design: .serif, weight: .medium))
                    .foregroundStyle(Theme.ink)
                if let detail {
                    Text(detail)
                        .font(.body)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            // Lets a long title or line wrap on to a second line.
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            accessory()

            // `wrappedValue` is the true or false that the binding
            // points at.
            let isLarge = controls.isLarge.wrappedValue
            Button {
                withAnimation(.smooth(duration: 0.3)) { controls.isLarge.wrappedValue.toggle() }
            } label: {
                Image(systemName: isLarge ? "arrow.down.right.and.arrow.up.left"
                                          : "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(QuietGlassButton())
            .help(isLarge ? "Back to the usual size" : "Make this larger")
            .accessibilityLabel(isLarge ? "Back to the usual size" : "Make this larger")

            Button("Done") { controls.close() }
                .buttonStyle(QuietGlassButton())
                // The Esc key presses this.
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }
}

extension PanelPage where Accessory == EmptyView {

    /// The same, with nothing extra beside the buttons. `EmptyView` is
    /// SwiftUI's name for "no view at all".
    init(_ title: String,
         detail: String? = nil,
         controls: EiraPanelControls,
         @ViewBuilder content: @escaping () -> Content) {
        self.init(title, detail: detail, controls: controls, accessory: { EmptyView() }, content: content)
    }
}
