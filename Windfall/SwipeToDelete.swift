//
//  SwipeToDelete.swift
//  Windfall
//
//  Swipe a row to the left to show a red Delete button, as in Mail and
//  Messages. Asked for by William on 15 November 2026, for the sightings
//  on the Wildlife page.
//
//  Why it is drawn here. Apple's own `.swipeActions` only works on rows
//  of a `List`, and Windfall's pages are cards in a scroll view, not
//  lists. So this does the same job by hand: it follows the finger
//  sideways, and when let go far enough it stays open with Delete
//  showing.
//
//  Nothing is deleted by the swipe alone. Delete has to be tapped. A
//  sighting, its photo and its place cannot be got back.
//

import SwiftUI

extension View {

    /// Lets this row be swiped left to show a Delete button.
    ///
    /// - `onDelete`: what Delete does. The row's owner decides, which is
    ///   usually `context.delete(record)`.
    ///
    /// A long press (a right-click on a Mac, which has no finger to swipe
    /// with) gives a menu with Delete as well.
    func swipeToDelete(onDelete: @escaping () -> Void) -> some View {
        modifier(SwipeToDelete(onDelete: onDelete))
    }
}

private struct SwipeToDelete: ViewModifier {

    let onDelete: () -> Void

    /// How far the row is slid to the left, in points: 0 is closed.
    @State private var offset: CGFloat = 0
    /// Where it was when this drag began: 0, or open.
    @State private var startOffset: CGFloat = 0
    /// Whether the drag under way is a sideways one, and so ours. Nil
    /// until the finger has moved far enough to tell. A drag that starts
    /// up or down belongs to the page's scrolling.
    @State private var isSideways: Bool?

    /// How wide the Delete button is, and so how far the row stays open.
    private let buttonWidth: CGFloat = 88

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        #if os(iOS)
        ZStack(alignment: .trailing) {
            // The red button sits behind the row, at its right-hand end.
            // It only shows as the row slides away from it.
            if offset < 0 {
                Button(role: .destructive) {
                    close()
                    onDelete()
                } label: {
                    Text("Delete")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: max(-offset, buttonWidth))
                        .frame(maxHeight: .infinity)
                        .background(Color.red, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }

            content
                .offset(x: offset)
                // While open, a tap on the row closes it rather than
                // opening the sighting, as in Mail.
                .overlay {
                    if offset < 0 {
                        Color.clear
                            .contentShape(.rect)
                            .onTapGesture { close() }
                    }
                }
        }
        // "Simultaneous" so the row's own tap, which opens the sighting,
        // still works. `minimumDistance` keeps a tap from counting as a drag.
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onChanged { drag in
                    if isSideways == nil {
                        isSideways = abs(drag.translation.width) > abs(drag.translation.height)
                        startOffset = offset
                    }
                    guard isSideways == true else { return }
                    // Only to the left, and a little stretch past the
                    // button, which pulls back when let go.
                    offset = min(0, max(startOffset + drag.translation.width, -buttonWidth * 1.6))
                }
                .onEnded { drag in
                    defer { isSideways = nil }
                    guard isSideways == true else { return }
                    // Open if slid over half the button's width, or
                    // flicked left. Closed otherwise.
                    let flicked = drag.predictedEndTranslation.width < -buttonWidth
                    settle(open: offset < -buttonWidth / 2 || flicked)
                }
        )
        // A long press gives the same Delete, as it did before swiping.
        .contextMenu {
            Button("Delete", role: .destructive) { onDelete() }
        }
        // VoiceOver cannot swipe a row, so Delete is offered as an action.
        .accessibilityAction(named: "Delete") { onDelete() }
        #else
        content
            .contextMenu {
                Button("Delete", role: .destructive) { onDelete() }
            }
        #endif
    }

    private func settle(open: Bool) {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) {
            offset = open ? -buttonWidth : 0
        }
    }

    private func close() { settle(open: false) }
}
