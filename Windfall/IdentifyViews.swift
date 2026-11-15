//
//  IdentifyViews.swift
//  Windfall
//
//  The Identify place: every way the app has of putting a name to
//  something, in one spot.
//
//    IdentifyHub          the page in the sidebar on a Mac or an iPad:
//                         Identify from a photo, then each fungus key
//    FungusKeyShelfView   the same keys on a page of their own, reached
//                         from Wildlife on an iPhone, which has no room
//                         for another tab
//    FungusKeyTiles       one tile for each key in the app (FungusKeys)
//    KeyVerdictSwitch     the switch for an author's verdicts on eating
//
//  William chose this on 15 November 2026: "Identify place". His wild
//  flower key, when it is built, belongs here too (project doc 77).
//

import SwiftUI

struct IdentifyHub: View {

    var body: some View {
        GeometryReader { geometry in
            let layout = PageWidth(geometry.size.width)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(title: "Identify", detail: "From a photo, or step by step through a key")
                    GlassEffectContainer(spacing: 10) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                                 count: layout == .narrow ? 2 : 4),
                                  spacing: 10) {
                            GrowingLink { IdentifyView() } label: {
                                HubTile(icon: .drawn(.photo), title: "Identify from a photo",
                                        detail: "Ask what you have seen")
                            }
                            .hubTileGlass()
                            FungusKeyTiles.tiles()
                        }
                    }
                    KeyVerdictSwitch()
                }
                .padding(.leading, layout.leading)
                .padding(.trailing, layout.trailing)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .paperScreen()
        .navigationTitle("Identify")
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }
}

/// The fungus keys on a page of their own, for an iPhone.
struct FungusKeyShelfView: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Fungus keys", detail: "Choose a key to step through")
                GlassEffectContainer(spacing: 10) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                              spacing: 10) {
                        FungusKeyTiles.tiles()
                    }
                }
                KeyVerdictSwitch()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .paperScreen()
        .navigationTitle("Fungus keys")
    }
}

/// One tile for each key in the app.
///
/// A function that hands back a `ForEach`, not a view of its own, so a
/// grid lays the tiles out one by one beside its other tiles.
enum FungusKeyTiles {

    static func tiles() -> some View {
        ForEach(FungusKeys.inApp) { shelved in
            GrowingLink { FungusKeyView(key: shelved.key) } label: {
                HubTile(icon: .drawn(.fungusKey), title: shelved.key.displayTitle,
                        detail: detail(for: shelved.key))
            }
            .hubTileGlass()
        }
    }

    /// The tile's second line.
    static func detail(for key: FungusKey) -> String {
        if key.isSample { return "A sample, to try a key to species" }
        if let credit = key.credit { return "By \(credit.author)" }
        return "Step to a group for a record"
    }
}

/// The switch for an author's verdicts on eating.
///
/// It only appears when a key in the app has an author who allowed
/// them, and it starts off. `@AppStorage` keeps the setting between
/// visits, under the same name the key's page reads.
struct KeyVerdictSwitch: View {

    @AppStorage("showsKeyVerdicts") private var showsVerdicts = false

    var body: some View {
        if FungusKeys.inApp.contains(where: { $0.key.mayShowVerdicts }) {
            Toggle(isOn: $showsVerdicts) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Show the author's verdicts on eating")
                        .font(.body)
                        .foregroundStyle(Theme.ink)
                    Text("Only on a key whose author has allowed it, kept apart and in his words. Windfall's own key never says whether a fungus can be eaten.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .glassCard(cornerRadius: 16, padding: 14)
        }
    }
}
