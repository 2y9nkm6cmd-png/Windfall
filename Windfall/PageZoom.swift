//
//  PageZoom.swift
//  Windfall
//
//  Two things a Mac's keyboard and trackpad can do to a page:
//
//    Command and plus or minus   make everything on the page larger or
//                                smaller. Command and 0 puts it back.
//    Two fingers, swiped right   go back to the page before, as in Safari.
//                                The page follows the fingers and slides
//                                away to the right.
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
/// and takes it away when it goes (see `BackSwipeSlide`, which
/// `paperScreen()` puts on every page).
///
/// THE PAGE FOLLOWS THE FINGERS (asked for by William on 14 November
/// 2026, with a picture of an iPhone's Settings part-way through a
/// swipe back). Until then the page went back all at once when the
/// fingers had travelled 90 points. Now `pull` says how far the fingers
/// have dragged the page on top, and that page draws itself that far to
/// the right. Lifting the fingers past `needed` sends it off the edge
/// and goes back. Lifting sooner lets it spring home.
///
/// `@Observable` means any view that reads `pull` is redrawn whenever
/// it changes, which is what makes the page move.
@Observable
final class BackSwipe {

    static let shared = BackSwipe()

    private var leaving: [(id: UUID, leave: () -> Void)] = []

    /// How far the page on top has been dragged to the right, in points.
    private(set) var pull: CGFloat = 0
    /// The page being dragged. Nil when none is.
    private(set) var pulledPage: UUID?

    func add(id: UUID, leave: @escaping () -> Void) {
        leaving.removeAll { $0.id == id }
        leaving.append((id: id, leave: leave))
    }

    func remove(id: UUID) {
        leaving.removeAll { $0.id == id }
        // The page that was dragged away has gone: forget the drag, so
        // the next page starts where it should.
        if pulledPage == id {
            pulledPage = nil
            pull = 0
        }
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
    /// Whether this swipe is a swipe back. Nil until the fingers have
    /// moved far enough to tell.
    private var isBackSwipe: Bool?
    /// How wide the window is, which is how far a page slides to be
    /// clear of it.
    private var windowWidth: CGFloat = 1200

    /// How far the page must be dragged for lifting the fingers to go
    /// back, in points.
    private let needed: CGFloat = 110

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
            isBackSwipe = nil
            // A drag left over from a swipe that never finished.
            if pulledPage != nil { settle(goingBack: false) }
        }

        // The fingers have lifted, or the swipe was called off.
        if scroll.phase.contains(.ended) || scroll.phase.contains(.cancelled) {
            if isBackSwipe == true {
                settle(goingBack: scroll.phase.contains(.ended) && pull > needed)
            }
            isBackSwipe = false
            return
        }

        guard isBackSwipe != false else { return }
        // A sliding switch under the pointer owns a sideways swipe. So
        // does a sheet, which has its own Cancel or Done. And so does a
        // month's page, where a sideways swipe turns the month.
        guard !PointerClaims.isOverSwitch, !PointerClaims.monthPageIsOpen,
              let window = scroll.window, window.attachedSheet == nil, window.sheetParent == nil else {
            isBackSwipe = false
            return
        }

        // Fingers moving right count up. See GlassSwitch for why the
        // sign is turned when "natural scrolling" is off.
        travel += scroll.isDirectionInvertedFromDevice ? scroll.scrollingDeltaX : -scroll.scrollingDeltaX
        rise += abs(scroll.scrollingDeltaY)

        if isBackSwipe == nil {
            // Wait until the fingers have moved a little, then decide
            // once: to the right, and clearly more across than up or
            // down, with a page to go back from. Anything else is
            // ordinary scrolling and is left alone until the next swipe.
            guard abs(travel) + rise > 14 else { return }
            guard travel > 0, travel > rise * 2, let top = leaving.last else {
                isBackSwipe = false
                return
            }
            isBackSwipe = true
            pulledPage = top.id
            windowWidth = window.frame.width
        }

        // The page follows the fingers. It cannot be dragged left of
        // where it started.
        pull = max(0, travel)
    }

    /// Finishes a drag: off to the right and back a page, or home again.
    private func settle(goingBack: Bool) {
        guard let dragged = pulledPage else { return }
        if goingBack, let top = leaving.last, top.id == dragged {
            // Slide the rest of the way off, then go back with no
            // animation of the Mac's own on top of ours.
            withAnimation(.easeOut(duration: 0.18)) { pull = windowWidth }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                var quiet = Transaction()
                quiet.disablesAnimations = true
                withTransaction(quiet) { top.leave() }
                // `remove` forgets the drag when the page has gone. This
                // is a safety net in case it never does.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    guard let self, self.pulledPage == dragged else { return }
                    self.pulledPage = nil
                    self.pull = 0
                }
            }
        } else {
            withAnimation(.smooth(duration: 0.25)) { pull = 0 }
            pulledPage = nil
        }
    }
    #endif
}

/// Put on every page by `paperScreen()`, on a Mac. If the page was
/// opened on top of another, it tells `BackSwipe` how to leave it, and
/// while two fingers drag it to the right it draws itself that far
/// across, with a soft shadow down its left edge like a sheet of paper
/// being slid off the one beneath.
///
/// A `ViewModifier` is a reusable change that can be put on any view.
/// `content` is the page it was put on.
struct BackSwipeSlide: ViewModifier {

    /// True for a page that was pushed on or presented, false for the
    /// first page of a place.
    @Environment(\.isPresented) private var isPresented
    @Environment(\.dismiss) private var dismiss
    @State private var id = UUID()

    func body(content: Content) -> some View {
        // Zero for every page but the one being dragged.
        let across = BackSwipe.shared.pulledPage == id ? BackSwipe.shared.pull : 0

        content
            .overlay(alignment: .leading) {
                // The shadow, drawn just outside the page's left edge.
                // Clear when the page is at rest.
                LinearGradient(colors: [.clear, .black.opacity(0.22)],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: 18)
                    .offset(x: -18)
                    .ignoresSafeArea()
                    .opacity(across > 0 ? 1 : 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            // `offset` draws the page somewhere else without moving
            // anything around it.
            .offset(x: across)
            .onAppear {
                guard isPresented else { return }
                BackSwipe.shared.add(id: id) { dismiss() }
            }
            .onDisappear { BackSwipe.shared.remove(id: id) }
    }
}
