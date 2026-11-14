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
