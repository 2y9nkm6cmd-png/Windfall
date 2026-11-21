//
//  GrowFromTile.swift
//  Windfall
//
//  A page that grows out of the tile that was tapped.
//
//  Asked for by William on 14 November 2026, with a recording of the
//  Gardens page on his iPhone: tapping "Garden map" or "Weather" slid the
//  new page in from the right, as every iPhone app does by default. He
//  wanted the page to grow from the tile itself, and to keep the swipe
//  back.
//
//  HOW IT WORKS
//  Apple calls this a "zoom" transition (it is how a photo opens in the
//  Photos app). It needs two things tied together:
//
//    1. the thing that was tapped is marked as the SOURCE, and
//    2. the page that opens is told to ZOOM from that source.
//
//  The two are tied by a name (an `id`) inside a `Namespace`. A namespace
//  is a private box of names: the same id in two different boxes is two
//  different things, so every tile can call itself "tile" without them
//  getting mixed up.
//
//  GOING BACK
//  The back button and the swipe from the left edge both still work, and
//  the page shrinks back into its tile. That part is Apple's, not ours.
//
//  ON A MAC
//  Apple built this transition for the iPhone and iPad. Everything here
//  is fenced with `#if os(iOS)`, which covers the iPad too, so a Mac is
//  left exactly as it was, with its own back swipe from PageZoom.swift.
//  (Not tried: whether a Mac would accept the same two lines. Apple's
//  pages list the modifier for macOS but the zoom itself comes from the
//  iPhone's own toolkit.)
//

import SwiftUI

/// The switch for the whole thing.
enum TileGrowth {

    /// False puts the old slide back everywhere. It is a checking aid:
    /// start the app with `-tilesSlide YES` to compare the two, or to get
    /// out of trouble if growing misbehaves on some version of iOS.
    ///
    /// `static let` means it is worked out once, the first time it is
    /// asked for, and never changes while the app is open.
    static let isOn = !UserDefaults.standard.bool(forKey: "tilesSlide")
}

extension View {

    /// Marks this view as the thing a page grows out of.
    ///
    /// `id` names it and `space` is the box of names it belongs to. The
    /// page it opens must be given the same pair with `growsFrom`.
    ///
    /// `@ViewBuilder` lets the function hand back one kind of view or
    /// another depending on an `if`, which Swift does not otherwise allow.
    @ViewBuilder
    func growSource(_ id: some Hashable, in space: Namespace.ID) -> some View {
        #if os(iOS)
        if TileGrowth.isOn {
            matchedTransitionSource(id: id, in: space)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Makes this page grow out of the view that was marked with
    /// `growSource` under the same `id` and `space`, and shrink back
    /// into it on the way out.
    ///
    /// If that view cannot be found (it has scrolled off the screen,
    /// say) the page grows from the middle of the screen instead.
    @ViewBuilder
    func growsFrom(_ id: some Hashable, in space: Namespace.ID) -> some View {
        #if os(iOS)
        if TileGrowth.isOn {
            navigationTransition(.zoom(sourceID: id, in: space))
        } else {
            self
        }
        #else
        self
        #endif
    }
}

/// A link that opens a page by growing it out of the link itself. Used
/// in place of `NavigationLink` for a tile or a card:
///
///     GrowingLink { WeatherDiaryView() } label: {
///         HubTile(icon: .drawn(.temperature), title: "Weather", detail: nil)
///     }
///
/// `Destination` and `Tile` in the angle brackets are placeholders for
/// "whatever kind of view is handed in". That is what lets one link
/// serve every tile.
struct GrowingLink<Destination: View, Tile: View>: View {

    /// This link's own box of names. Each link gets a fresh one, so the
    /// single name below never clashes with another link's.
    @Namespace private var space

    private let destination: Destination
    private let tile: Tile

    /// The one name used inside this link's namespace.
    private let name = "tile"

    init(@ViewBuilder destination: () -> Destination, @ViewBuilder label: () -> Tile) {
        self.destination = destination()
        self.tile = label()
    }

    var body: some View {
        NavigationLink {
            destination.growsFrom(name, in: space)
        } label: {
            tile.growSource(name, in: space)
        }
    }
}

// MARK: - A swipe down closes a grown page

// Asked for by William on 21 November 2026: "the life stages drawings
// should [have] a swipe down to close screen."
//
// Apple's zoom transition is meant to let a grown page be pulled down
// to close it, but William found the zoomed Life stages page would not
// close that way. The likeliest reason (not proved): the page is almost
// all one sideways strip, and the strip takes the finger. So the page is
// given a pull-down of its own.
//
// HOW IT WORKS
//   - A drag is watched alongside the strip's own sideways scrolling
//     (`simultaneousGesture`), so the strip still slides as before.
//   - The first few points of a drag decide which way it is going. Only
//     a drag that starts more down than across pulls the page.
//   - While pulled, the page follows the finger down and shrinks a
//     little, so it is plain that letting go will close it.
//   - Let go past 120 points down, or flick it down, and the page
//     closes, shrinking back into the card it grew from. Let go sooner
//     and it springs back.
//
// ON A MAC
// Nothing changes. A drag there is a click and drag, not a finger, and
// the Back button and two-finger swipe back are the way out.

extension View {

    /// On an iPhone or iPad, a drag down on this page closes it, the
    /// same as Back. Put it on the page's contents, inside its paper
    /// background, so the contents move and the paper stays still.
    func swipeDownCloses() -> some View {
        modifier(SwipeDownCloses())
    }
}

private struct SwipeDownCloses: ViewModifier {

    /// Apple's "go back" for whatever page this is on. For a page that
    /// was pushed (as a grown page is) it does what Back does.
    @Environment(\.dismiss) private var dismiss

    /// What the finger is doing right now.
    ///
    /// `isDown` is decided once, at the start of a drag: `nil` means not
    /// yet decided, `true` a pull down, `false` a sideways slide of the
    /// strip, which is left alone. `by` is how far down it has pulled.
    private struct Pull {
        var isDown: Bool? = nil
        var by: CGFloat = 0
    }

    /// `@GestureState` puts itself back to the starting value when the
    /// finger lifts, or when iOS takes the drag away for something else,
    /// so the page can never be left stuck halfway down. The reset is
    /// given a spring, so a pull that is let go too soon floats back up.
    @GestureState(resetTransaction: Transaction(animation: .spring(duration: 0.3)))
    private var pull = Pull()

    /// Where the page was when it was let go to close. It holds the page
    /// there while it shrinks away, so it does not jump back up first.
    @State private var leftAt: CGFloat = 0

    /// How far down the finger must travel to close, in points, unless
    /// it is flicked.
    private let needed: CGFloat = 120

    func body(content: Content) -> some View {
        #if os(iOS)
        // The larger of the two: the live pull, or where it was let go.
        let down = max(pull.by, leftAt)
        content
            // Up to a sixth smaller when pulled 500 points down.
            .scaleEffect(1 - min(down, 500) / 3000)
            // `offset` draws the page lower without moving anything
            // round it, so it follows the finger.
            .offset(y: down)
            .simultaneousGesture(drag)
        #else
        content
        #endif
    }

    #if os(iOS)
    private var drag: some Gesture {
        // `.global` measures in the screen's own points, which do not
        // move when the page itself moves down.
        DragGesture(minimumDistance: 16, coordinateSpace: .global)
            .updating($pull) { drag, pull, _ in
                let moved = drag.translation
                if pull.isDown == nil {
                    pull.isDown = moved.height > abs(moved.width)
                }
                if pull.isDown == true {
                    pull.by = max(0, moved.height)
                }
            }
            .onEnded { drag in
                let moved = drag.translation
                // Still more down than across at the end, so a slide of
                // the strip that wandered downwards does not close it.
                guard moved.height > abs(moved.width) else { return }
                // A flick counts even if it was short: the predicted end
                // is where the finger was heading.
                let goes = moved.height > needed || drag.predictedEndTranslation.height > needed * 2.5
                if goes {
                    leftAt = moved.height
                    dismiss()
                }
            }
    }
    #endif
}
