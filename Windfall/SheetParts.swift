//
//  SheetParts.swift
//  Windfall
//
//  The pieces a pop-up sheet is built from, so that the forms reached
//  from a button look like the screens they are opened from: cream
//  paper, glass cards, the serif title, the green filled button.
//
//  A "sheet" is the panel that slides over a screen for one job, such
//  as recording a sowing. The standard way to build one is a `Form`.
//  A Form looks at home on an iPhone. On a Mac it lays everything out
//  in two columns meant for a settings window, and puts a bar across
//  the top and bottom of the sheet. These pieces replace it:
//
//  SheetPage      the whole sheet: title, Cancel and Save, the paper
//  SheetScroll    the scrolling middle, with the usual margins
//  SheetCard      a glass card with a heading
//  SettingRow     a name on the left, something to set on the right
//  FieldBox       the look of a box to type in
//  NumberStepper  a number with a button either side
//  ProblemsCard   a list of warnings
//  SheetMainButton  the one wide filled button at the foot of a sheet
//  GlassSwitch    a row of choices with a piece of glass that slides
//                 to the chosen one (it lives in GlassSwitch.swift)
//
//  A sheet built from these is as tall as what is in it, up to a limit,
//  and scrolls beyond that. It has no bars of its own.
//
//  Built so far with these: the counts (SurveyViews.swift), the sowing
//  form and the harvest forms (PlantingViews.swift, TodayView.swift).
//  The other forms in the app are still standard Forms.
//

import SwiftUI

// MARK: - The sheet

/// The frame of a sheet: a title, up to two buttons and the paper
/// behind. Whatever is put inside goes under the title.
///
/// `<Content: View>` makes this "generic": it works with any kind of
/// view inside it, and Swift checks each use on its own.
struct SheetPage<Content: View>: View {

    private let title: String
    private let detail: String?
    private let dismissTitle: String?
    private let onDismiss: (() -> Void)?
    private let confirmTitle: String?
    private let canConfirm: Bool
    private let onConfirm: () -> Void
    private let content: () -> Content

    /// How to close the sheet this sits in, handed down by SwiftUI.
    @Environment(\.dismiss) private var dismiss

    /// - `detail`: a quieter line under the title.
    /// - `dismissTitle`: the plain button, "Cancel" unless told
    ///   otherwise. Nil leaves it out.
    /// - `onDismiss`: what the plain button does. Left out, it closes
    ///   the sheet.
    /// - `confirmTitle`: the filled button, such as "Save". Nil leaves
    ///   it out.
    /// - `canConfirm`: false greys the filled button out.
    init(_ title: String,
         detail: String? = nil,
         dismissTitle: String? = "Cancel",
         onDismiss: (() -> Void)? = nil,
         confirmTitle: String? = nil,
         canConfirm: Bool = true,
         onConfirm: @escaping () -> Void = {},
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.detail = detail
        self.dismissTitle = dismissTitle
        self.onDismiss = onDismiss
        self.confirmTitle = confirmTitle
        self.canConfirm = canConfirm
        self.onConfirm = onConfirm
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { PaperBackground() }
        #if os(macOS)
        // On a Mac a sheet takes the size of what is in it. A set width,
        // and a height that follows the content up to a limit.
        .frame(width: 520)
        .frame(minHeight: 200, maxHeight: 720)
        #endif
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.title2, design: .serif, weight: .medium))
                    .foregroundStyle(Theme.ink)
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            // Lets a long title or line wrap on to a second line.
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            if let dismissTitle {
                Button(dismissTitle) {
                    if let onDismiss { onDismiss() } else { dismiss() }
                }
                .buttonStyle(.glass)
                // The Esc key on a Mac presses this.
                .keyboardShortcut(.cancelAction)
            }
            if let confirmTitle {
                Button(confirmTitle) { onConfirm() }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.leaf)
                    .foregroundStyle(Theme.onLeaf)
                    .disabled(!canConfirm)
                    // The Return key on a Mac presses this.
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }
}

/// The scrolling middle of a sheet. Cards go inside, one under another.
struct SheetScroll<Content: View>: View {

    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
    }
}

// MARK: - Inside a sheet

/// A glass card, like those on the Today screen, with a heading if one
/// is given.
struct SheetCard<Content: View>: View {

    private let title: String?
    private let content: () -> Content

    init(_ title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

/// A name on the left and something to set on the right.
struct SettingRow<Control: View>: View {

    private let name: String
    private let control: () -> Control

    init(_ name: String, @ViewBuilder control: @escaping () -> Control) {
        self.name = name
        self.control = control
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(name)
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            control()
        }
    }
}

/// The app's own look for a box to type in: a soft fill and a hairline.
struct FieldBox<Content: View>: View {

    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            // "Plain" removes the system's own border, so this one shows.
            .textFieldStyle(.plain)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Theme.card.opacity(0.7), in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Theme.hairline)
            }
    }
}

/// A number with a button either side to lower or raise it.
struct NumberStepper: View {

    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 10) {
            roundButton("minus", says: "One fewer") { value = max(range.lowerBound, value - 1) }
                .disabled(value <= range.lowerBound)
                .opacity(value <= range.lowerBound ? 0.35 : 1)
            Text("\(value)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .frame(minWidth: 34)
            roundButton("plus", says: "One more") { value = min(range.upperBound, value + 1) }
                .disabled(value >= range.upperBound)
                .opacity(value >= range.upperBound ? 0.35 : 1)
        }
    }

    private func roundButton(_ symbol: String, says words: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 36, height: 36)
                .background(Theme.card.opacity(0.8), in: .circle)
                .overlay { Circle().strokeBorder(Theme.hairline) }
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(words)
    }
}

/// A card of warnings, each with an amber triangle.
struct ProblemsCard: View {

    let problems: [String]
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(problems, id: \.self) { problem in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Theme.amber)
                    Text(problem)
                        .foregroundStyle(Theme.ink)
                }
                .font(.callout)
            }
            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

/// The one wide filled button at the foot of a sheet.
struct SheetMainButton: View {

    private let title: String
    private let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .tint(Theme.leaf)
        .foregroundStyle(Theme.onLeaf)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 18)
    }
}

// The sliding switch (GlassSwitch) is in GlassSwitch.swift.
