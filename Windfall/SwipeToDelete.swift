//
//  SwipeToDelete.swift
//  Windfall
//
//  Swipe a row to the left to delete it, as in Mail and Messages. Asked
//  for by William on 15 November 2026, for the sightings on the Wildlife
//  page.
//
//  Why it is drawn here. Apple's own `.swipeActions` only works on rows
//  of a `List`, and Windfall's pages are cards in a scroll view, not
//  lists. So this does the same job by hand.
//
//  How it behaves:
//  - A short swipe left and let go: the row stays slid over with a red
//    Delete showing. Tap Delete to delete, or tap the row to close it.
//  - A long swipe, past half the row's width: the red grows across the
//    row, and letting go deletes it. Coming back short of half before
//    letting go changes your mind.
//  - A long press (a right-click on a Mac) gives a menu with Delete.
//
//  16 November 2026, William: "The delete swipe make the delete a lot
//  bigger than the area you're deleting" and "You also aren't able to
//  keep swiping along to delete." The red is now drawn behind the row,
//  so it is exactly the row's height, the row is trimmed to its own
//  bounds while it slides, and a long swipe deletes.
//

import SwiftUI

extension View {

    /// Lets this row be swiped left to delete it.
    ///
    /// - `onDelete`: what deleting does. The row's owner decides, which is
    ///   usually `context.delete(record)`.
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
    /// The row's own width, measured, so a long swipe can be told from a
    /// short one.
    @State private var rowWidth: CGFloat = 320

    /// How wide Delete is when the row stays open.
    private let buttonWidth: CGFloat = 88

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// True once the row has been slid past half its width: letting go
    /// now deletes.
    private var isPastHalfway: Bool { -offset > rowWidth / 2 }

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .offset(x: offset)
            // While open, a tap on the row closes it rather than opening
            // the sighting, as in Mail.
            .overlay {
                if offset < 0 {
                    Color.clear
                        .contentShape(.rect)
                        .onTapGesture { settle(open: false) }
                }
            }
            // The red sits behind the row and takes the row's own size,
            // so it is never taller than the row. It fills the space the
            // row has slid out of, from the right-hand edge.
            .background(alignment: .trailing) {
                if offset < 0 {
                    Button(role: .destructive) {
                        deleteNow()
                    } label: {
                        Text("Delete")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            // Past halfway the word moves to the left-hand
                            // side of the red, as Mail's does, to show that
                            // letting go will delete.
                            .frame(maxWidth: .infinity, alignment: isPastHalfway ? .leading : .center)
                            .padding(.horizontal, 16)
                            .frame(width: -offset)
                            .frame(maxHeight: .infinity)
                            .background(Color.red, in: .rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            // Nothing slides outside the row's own bounds.
            .clipShape(.rect(cornerRadius: 10))
            // Measures the row's width each time it changes.
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
            // UIKit's pan, which only starts for a sideways movement
            // (`SidewaysPan`, below). Until 16 November 2026 this was a
            // SwiftUI drag running alongside the page's scrolling, and
            // the page was slow to start scrolling: William, "It takes a
            // long time to let you scroll down on this page".
            .gesture(SidewaysPan(
                began: { startOffset = offset },
                moved: { across in
                    // Only to the left, and no further than the row.
                    offset = min(0, max(startOffset + across, -rowWidth))
                },
                ended: { speed in
                    if isPastHalfway {
                        deleteNow()
                    } else {
                        // Open if slid over half the button's width, or
                        // flicked left. Closed otherwise.
                        settle(open: -offset > buttonWidth / 2 || speed < -500)
                    }
                }))
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

    /// Slides the row the rest of the way off, then deletes it.
    private func deleteNow() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            offset = -rowWidth
        } completion: {
            onDelete()
        }
    }

    private func settle(open: Bool) {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) {
            offset = open ? -buttonWidth : 0
        }
    }
}

#if os(iOS)
/// UIKit's pan gesture, handed to SwiftUI, that only starts when the
/// finger moves more sideways than up or down.
///
/// Why UIKit's: a gesture can be asked "should you start?" at the moment
/// the finger has moved far enough to tell its direction
/// (`gestureRecognizerShouldBegin`). This one says yes only for sideways.
/// It also tells the page's scrolling to wait for it to say no
/// (`shouldBeRequiredToFailBy`), which it does at once for an up or down
/// movement, so the page scrolls straight away. Today's cards use the
/// same borrowing (`FingerHold`, in TodayBoard.swift).
struct SidewaysPan: UIGestureRecognizerRepresentable {
    let began: () -> Void
    /// How far the finger has moved sideways since it started, in
    /// points: below 0 is to the left.
    let moved: (CGFloat) -> Void
    /// How fast it was moving sideways when let go, in points a second.
    let ended: (CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ pan: UIPanGestureRecognizer, context: Context) {
        switch pan.state {
        case .began:
            began()
            moved(pan.translation(in: pan.view).x)
        case .changed:
            moved(pan.translation(in: pan.view).x)
        case .ended, .cancelled, .failed:
            ended(pan.velocity(in: pan.view).x)
        default:
            break
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        /// Starts only for a sideways movement.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let speed = pan.velocity(in: pan.view)
            return abs(speed.x) > abs(speed.y)
        }

        /// The page's scrolling waits for this to start or give up. It
        /// gives up at once for an up or down movement.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
            other.view is UIScrollView
        }
    }
}
#endif
