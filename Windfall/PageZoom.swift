//
//  PageZoom.swift
//  Windfall
//
//  Two things a Mac's keyboard and trackpad can do to a page:
//
//    Command and plus or minus   make everything on the page larger or
//                                smaller. Command and 0 puts it back.
//    Two fingers, swiped right   go back to the page before, as in Safari.
//
//  WHY THE PAGE IS ZOOMED, NOT THE TEXT
//  An iPhone or iPad has a text size setting that every app follows.
//  A Mac has none that apps can follow: checked on William's Mac on 13
//  November 2026, asking for larger type changed nothing. So the page is
//  drawn for a narrower window and then enlarged to fit, which is what a
//  web browser does. Cards, icons and gaps grow with the words.
//
//  The sum for stepping between sizes is in TextSize.swift.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - The zoom

extension View {
    /// Shows this view at the size chosen with Command and plus or
    /// minus. On a Mac only: an iPhone or iPad has its own text size
    /// setting. (A checking aid, `-pageZoomEverywhere YES -pageZoom 1.3`,
    /// switches it on anywhere, so a simulator can show it.)
    @ViewBuilder
    func pageZoomWhereOffered() -> some View {
        #if os(macOS)
        modifier(PageZoom())
        #else
        if UserDefaults.standard.bool(forKey: "pageZoomEverywhere") {
            modifier(PageZoom())
        } else {
            self
        }
        #endif
    }
}

/// Lays a view out for a smaller space and enlarges it to fill the real
/// one (or the other way about, for a size below normal).
private struct PageZoom: ViewModifier {

    /// The chosen size. `@AppStorage` keeps it on the device, and the
    /// menu's buttons change the same stored number.
    @AppStorage("pageZoom") private var zoom = TextSize.normal
    /// How many dots the screen has to each point. Text is drawn at this
    /// fineness.
    @Environment(\.displayScale) private var displayScale

    func body(content: Content) -> some View {
        // At the normal size none of this changes anything. It is kept
        // in place all the same: taking it away and putting it back
        // would make SwiftUI rebuild the page and lose the place in it.
        GeometryReader { geometry in
            // The strip Eira's bar takes at the foot of the window.
            // Pages normally scroll underneath it. Once the page is
            // zoomed it no longer reaches that far by itself, so it is
            // made that much taller and told to keep its last lines
            // clear of the strip.
            let below = zoom == TextSize.normal ? 0 : geometry.safeAreaInsets.bottom

            content
                .safeAreaPadding(.bottom, below / zoom)
                // Lay it out as if the window were this much smaller...
                .frame(width: geometry.size.width / zoom, height: (geometry.size.height + below) / zoom)
                // ...have the words drawn finer, so they stay sharp...
                .environment(\.displayScale, displayScale * max(zoom, 1))
                // ...and enlarge the result to fill the window.
                .scaleEffect(zoom, anchor: .topLeading)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
    }
}

/// Windfall's lines in the Mac's View menu: the sidebar and the three
/// text sizes.
struct TextSizeCommands: Commands {

    @AppStorage("pageZoom") private var zoom = TextSize.normal
    /// The same stored switch the window's sidebar button changes.
    @AppStorage("sidebarIsHidden") private var sidebarIsHidden = false

    var body: some Commands {
        // `after: .toolbar` puts them in the View menu.
        CommandGroup(after: .toolbar) {
            // Control, Command and S is the Mac's usual shortcut for this.
            Button(sidebarIsHidden ? "Show Sidebar" : "Hide Sidebar") {
                withAnimation(.smooth(duration: 0.3)) { sidebarIsHidden.toggle() }
            }
            .keyboardShortcut("s", modifiers: [.control, .command])
            Divider()
            Button("Bigger") { zoom = TextSize.stepped(from: zoom, by: 1) }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(zoom >= TextSize.steps[TextSize.steps.count - 1])
            Button("Smaller") { zoom = TextSize.stepped(from: zoom, by: -1) }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(zoom <= TextSize.steps[0])
            Button("Actual Size (now \(TextSize.percent(zoom)))") { zoom = TextSize.normal }
                .keyboardShortcut("0", modifiers: .command)
            Divider()
        }
    }
}

// MARK: - Going back

/// Remembers how to leave each page that has been opened on top of
/// another, newest last, so a swipe can leave the one on top.
///
/// A page that was pushed on (a plant's page, say) is given a `dismiss`
/// action by SwiftUI: calling it goes back. Only the page itself can get
/// hold of it. So each page hands its own to this list when it appears
/// and takes it away when it goes (see `BackSwipeMarker`, which
/// `paperScreen()` puts on every page).
@Observable
final class BackSwipe {

    static let shared = BackSwipe()

    private var leaving: [(id: UUID, leave: () -> Void)] = []

    func add(id: UUID, leave: @escaping () -> Void) {
        leaving.removeAll { $0.id == id }
        leaving.append((id: id, leave: leave))
    }

    func remove(id: UUID) {
        leaving.removeAll { $0.id == id }
    }

    /// Goes back from the page on top. Returns false if there is no
    /// page to go back from.
    @discardableResult
    func goBack() -> Bool {
        guard let top = leaving.last else { return false }
        top.leave()
        return true
    }

    #if os(macOS)
    // The swipe under way.
    private var watcher: Any?
    private var travel: CGFloat = 0
    private var rise: CGFloat = 0
    private var hasFired = false

    /// How far two fingers must travel to the right, in points.
    private let needed: CGFloat = 90

    /// Starts watching the trackpad. Safe to call more than once.
    func watchTrackpad() {
        guard watcher == nil else { return }
        watcher = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] scroll in
            self?.scrolled(scroll)
            // Never used up: whatever is under the pointer still scrolls.
            return scroll
        }
    }

    private func scrolled(_ scroll: NSEvent) {
        // Only a trackpad's two-finger scroll has a beginning and an
        // end. A mouse wheel, and the glide after the fingers lift, are
        // not swipes.
        guard scroll.momentumPhase.isEmpty, !scroll.phase.isEmpty else { return }
        if scroll.phase.contains(.began) || scroll.phase.contains(.mayBegin) {
            travel = 0
            rise = 0
            hasFired = false
        }
        guard !hasFired else { return }
        // A sliding switch under the pointer owns a sideways swipe. So
        // does a sheet, which has its own Cancel or Done.
        guard !PointerClaims.isOverSwitch,
              let window = scroll.window, window.attachedSheet == nil, window.sheetParent == nil else { return }

        // Fingers moving right count up. See GlassSwitch for why the
        // sign is turned when "natural scrolling" is off.
        travel += scroll.isDirectionInvertedFromDevice ? scroll.scrollingDeltaX : -scroll.scrollingDeltaX
        rise += abs(scroll.scrollingDeltaY)

        // Far enough to the right, and clearly more across than up or down.
        if travel > needed && travel > rise * 2.5 {
            hasFired = true
            goBack()
        }
    }
    #endif
}

/// Put on every page by `paperScreen()`. If the page was opened on top
/// of another, it tells `BackSwipe` how to leave it.
struct BackSwipeMarker: View {

    /// True for a page that was pushed on or presented, false for the
    /// first page of a place.
    @Environment(\.isPresented) private var isPresented
    @Environment(\.dismiss) private var dismiss
    @State private var id = UUID()

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear {
                guard isPresented else { return }
                BackSwipe.shared.add(id: id) { dismiss() }
            }
            .onDisappear { BackSwipe.shared.remove(id: id) }
    }
}
