//
//  MainTabView.swift
//  Windfall
//
//  The frame every screen sits in.
//
//  On a Mac or an iPad there is a sidebar down the left, made of dark
//  green glass. On an iPhone, where there is no room for one, the same
//  places are tabs along the bottom.
//
//  Eira is not in the list. She floats in the bottom right corner of
//  every screen as her snowdrop (see EiraFloatingBar).
//

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

/// The places in the app. This one list drives both the sidebar and the
/// tabs, so they can never disagree.
enum AppSection: String, CaseIterable, Identifiable {
    case today, gardens, year, plants, wildlife, journal, more

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .gardens: return "Gardens"
        case .year: return "Year"
        case .plants: return "Plants"
        case .wildlife: return "Wildlife"
        case .journal: return "Journal"
        case .more: return "Settings"
        }
    }

    var icon: WIcon {
        switch self {
        case .today: return .today
        case .gardens: return .gardens
        case .year: return .year
        case .plants: return .plants
        case .wildlife: return .wildlife
        case .journal: return .journal
        case .more: return .settings
        }
    }

    /// An iPhone has room for five tabs. Year and Plants are reached from
    /// Gardens there.
    static let phoneTabs: [AppSection] = [.today, .gardens, .wildlife, .journal, .more]

    /// What Eira is told when this place is open and nothing more
    /// particular, such as one plant, is on top of it. See EiraScreen.
    var eiraPhrase: String {
        switch self {
        case .today: return "the Today screen, with the weather, today's jobs and recent records"
        case .gardens: return "the Gardens screen, with the beds, sowings and garden plans"
        case .year: return "the Year screen, a calendar of when each plant is sown, planted out and harvested"
        case .plants: return "the plant library"
        case .wildlife: return "the Wildlife screen, with sightings and surveys"
        case .journal: return "the journal"
        case .more: return "the settings and tools"
        }
    }
}

struct MainTabView: View {

    @Environment(\.modelContext) private var context
    // The size class says whether the screen is wide (a Mac, an iPad) or
    // narrow (an iPhone, or an iPad sharing its screen with another app).
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// The place shown first. Normally Today. Starting the app with the
    /// launch argument `-startSection gardens` (or any other place) opens
    /// there instead, which is handy when checking one screen repeatedly.
    @State private var selection: AppSection =
        UserDefaults.standard.string(forKey: "startSection").flatMap(AppSection.init(rawValue:)) ?? .today

    /// Keeps track of which screen is on top, so Eira can be told what
    /// is being looked at. See EiraScreen.
    @State private var eiraScreen = EiraScreen()

    /// Keeps the weather diary up to date. See WeatherDiary.swift.
    @State private var weatherDiary = WeatherDiaryService()
    /// A speed check, switched in Settings.
    @AppStorage("plainTransitions") private var plainTransitions = false
    /// True when the sidebar has been put away to give the page the
    /// whole window. Remembered between visits.
    @AppStorage("sidebarIsHidden") private var sidebarIsHidden = false
    // Says whether the app is on screen, in the background or closed.
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if sizeClass == .compact {
                phoneTabs
            } else {
                sidebarLayout
            }
        }
        .background {
            PaperBackground()
                // Tells every page where the window's background is, so
                // their washes of colour match it. See PaperBackground.
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { PaperCanvas.shared.frame = $0 }
        }
        // Apple's own controls, such as switches, use this colour.
        .tint(Theme.leaf)
        // Hands the screen tracker to every screen inside, and to Eira's bar.
        .environment(eiraScreen)
        // The first time the app runs, fill the plant library from the
        // starter data that ships inside it. After that this does nothing.
        .task {
            if DemoGarden.isRequested {
                // The example garden: see DemoGarden. It loads the plant
                // library into memory and adds made-up beds and records.
                DemoGarden.fill(context)
                // A checking aid: puts the test sheet to Eira with nobody
                // at the keyboard. It does nothing unless the app was
                // started from Terminal with a questions file. It is
                // started as its own Task so the weather below is not
                // kept waiting. See EiraTestRun.
                Task { await EiraTestRun.runIfAsked(context: context) }
                // Its twin for photos: see SpeciesTestRun.
                Task { await SpeciesTestRun.runIfAsked() }
            } else {
                GardenDataImporter().loadStarterDataIfNeeded(into: context)
                // Make sure the allotment and the permaculture garden
                // exist as records. It only adds what is missing.
                GardenPlan.ensureStartingGardens(in: context)
            }
            // Fill in any days of weather missed since the app was last
            // open. Done after the gardens exist, because it needs to
            // know where they are.
            await weatherDiary.bringUpToDate(in: context)
        }
        // And again each time the app comes back to the front, which on
        // an iPhone is far more often than it is opened afresh. The
        // service is asked at most once an hour, so this is cheap.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await weatherDiary.bringUpToDate(in: context) }
            }
        }
    }

    // MARK: Mac and iPad

    private var sidebarLayout: some View {
        HStack(spacing: 0) {
            // The sidebar can be put away, as in Apple's own apps. On a
            // Mac the button is in the bar at the top of the window, and
            // "Hide Sidebar" is in the View menu (Control, Command and
            // S). On an iPad the button is in the sidebar's own heading,
            // and a slim strip with one button brings it back.
            if !sidebarIsHidden {
                SidebarView(selection: $selection, onHide: toggleSidebar)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                #if !os(macOS)
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 40, height: 40)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Show the sidebar")
                .padding(.leading, 10)
                .padding(.top, 12)
                .frame(maxHeight: .infinity, alignment: .top)
                .transition(.opacity)
                #endif
            }

            // Each place gets its own NavigationStack, which is what lets
            // a screen push another on top and offer a way back.
            NavigationStack {
                screen(for: selection)
                    .eiraLooksAt(selection.eiraPhrase)
            }
            // A new identity for each place gives it a fresh stack, so
            // the "back" trail from one never leaks into another.
            .id(selection)
            // When the place changes, the old screen melts away and the
            // new one comes into focus, in step with the sidebar.
            // (Settings has a speed check that swaps the melt for a plain
            // fade, to see whether the melt is what feels slow.)
            .transition(plainTransitions ? AnyTransition.opacity : AnyTransition(.blurReplace))
            // On a Mac, Command and plus or minus make the page larger
            // or smaller. See PageZoom.swift.
            .pageZoomWhereOffered()
            // A little air between the sidebar and a screen's title.
            .padding(.leading, 10)
            // safeAreaInset places Eira's button along the bottom and tells
            // every screen that the strip is taken, so a long list can
            // always be scrolled clear of it.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // The bar opens across the page and stops a little inside
                // the edges of the cards above it. The cards begin 14 to
                // 16 points in from the left and 16 to 24 from the right.
                // (It ran on past them to the sidebar until William
                // asked, on 13 November 2026, for it to sit within.)
                EiraFloatingBar()
                    .padding(.leading, 20)
                    .padding(.trailing, 28)
                    .padding(.bottom, 14)
            }
        }
        #if os(macOS)
        // Lets the paper show through the strip at the top of the window.
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        // Two fingers swiped right on the trackpad go back a page.
        .onAppear { BackSwipe.shared.watchTrackpad() }
        .toolbar {
            // `.navigation` is the left-hand end of the window's bar,
            // where Apple's apps keep this button.
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar) {
                    Label(sidebarIsHidden ? "Show Sidebar" : "Hide Sidebar", systemImage: "sidebar.left")
                }
                .help(sidebarIsHidden ? "Show the sidebar" : "Hide the sidebar")
            }
        }
        #endif
    }

    private func toggleSidebar() {
        withAnimation(.smooth(duration: 0.3)) { sidebarIsHidden.toggle() }
    }

    // MARK: iPhone

    private var phoneTabs: some View {
        TabView(selection: phoneSelection) {
            ForEach(AppSection.phoneTabs) { section in
                Tab(section.title, image: "Icons/\(section.icon.rawValue)", value: section) {
                    NavigationStack {
                        screen(for: section)
                            .eiraLooksAt(section.eiraPhrase)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        EiraFloatingBar()
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }
                }
            }
        }
    }

    /// Year and Plants have no tab on an iPhone. If one of them was chosen
    /// on a wide screen that then became narrow, Gardens is shown.
    private var phoneSelection: Binding<AppSection> {
        Binding(
            get: { AppSection.phoneTabs.contains(selection) ? selection : .gardens },
            set: { selection = $0 }
        )
    }

    // MARK: Which screen

    @ViewBuilder
    private func screen(for section: AppSection) -> some View {
        switch section {
        case .today: TodayView()
        case .gardens:
            if DemoGarden.opensEditor {
                DemoGardenEditor()
            } else if DemoGarden.opensWeatherDay {
                DemoWeatherDay()
            } else if DemoGarden.opensWeather {
                WeatherDiaryView()
            } else if DemoGarden.opensYear {
                YearView()
            } else if let name = DemoGarden.opensPlant {
                DemoPlantPage(name: name)
            } else if let name = DemoGarden.opensCompanions {
                CompanionView(plantName: name)
            } else if DemoGarden.opensPests {
                PestHelpersView()
            } else {
                GardenTab()
            }
        case .year: YearView()
        case .plants: PlantLibraryView()
        case .wildlife: WildlifeTab()
        case .journal: JournalTimelineView()
        case .more: MoreTab()
        }
    }
}

// MARK: - Sidebar

/// The list of places down the left of a Mac or iPad screen: a floating
/// panel of dark green glass.
struct SidebarView: View {

    @Binding var selection: AppSection
    /// Puts the sidebar away. Nil where there is no way to bring it back.
    var onHide: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Some people ask their device for less see-through. For them the
    // lens stays flat and solid.
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let rowHeight: CGFloat = 44
    private let rowGap: CGFloat = 4
    private let panelWidth: CGFloat = 212
    private let panelPadding: CGFloat = 12

    // The lens is the piece of glass that marks the chosen row. Its top
    // and bottom edges are kept separately, measured down from the first
    // row, so that one edge can race ahead and the other catch up. That
    // stretch and snap is what makes it move like a drop of liquid.
    @State private var lensTop: CGFloat = 0
    @State private var lensBottom: CGFloat = 44
    /// True while the lens is on the move. It lifts off the surface: a
    /// little larger and quite clear, so the rows beneath show through
    /// it, magnified and bent.
    @State private var isLifted = false
    /// Counts the moves, so an older move never finishes on top of a newer one.
    @State private var moveNumber = 0

    #if os(macOS)
    // For two-finger scrolling on a Mac's trackpad. See "Scrolling the
    // lens" further down.
    /// True while the pointer is over the sidebar.
    @State private var isPointerOver = false
    /// The Mac's handle on the scroll watcher, kept so it can be removed.
    @State private var scrollWatcher: Any?
    /// Where the lens was when the scroll under way began, and how far
    /// the fingers have carried it since.
    @State private var scrollStart: CGFloat = 0
    @State private var scrollTravel: CGFloat = 0
    /// True from the moment a trackpad scroll begins until it ends.
    @State private var isScrollingLens = false
    /// When a mouse wheel last moved the lens, so one spin of a
    /// free-running wheel does not race through every row.
    @State private var lastWheelStep = Date.distantPast
    /// How far the lens moves for each point the fingers scroll. Under 1
    /// so that a short flick does not cross the whole list.
    private let scrollGearing: CGFloat = 0.6
    #endif

    /// How far down the last row starts. The lens never goes below it.
    private var lastRowTop: CGFloat {
        CGFloat(AppSection.allCases.count - 1) * (rowHeight + rowGap)
    }

    /// True when the lens is lifted and allowed to be see-through.
    private var bends: Bool { LensRefraction.isBuilt && isLifted && !reduceTransparency }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                WIconView(.sprig, size: 28)
                Text("Windfall")
                    .font(.wordmark)
                    // Never broken over two lines.
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            #if !os(macOS)
            // On an iPad the button to put the sidebar away lives here,
            // laid over the right-hand end of the heading so that it
            // takes no room from the name. A Mac has the button in the
            // bar at the top of the window.
            .overlay(alignment: .trailing) {
                if let onHide {
                    Button(action: onHide) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 15, weight: .medium))
                            .frame(width: 30, height: 34)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Hide the sidebar")
                }
            }
            #endif
            .foregroundStyle(Theme.sidebarInk)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 20)

            // Three layers, drawn in this order, each on top of the last.
            ZStack(alignment: .top) {
                // 1. The rows, in the sidebar's cream ink. These are the
                //    real buttons. While the lens is lifted, the part of
                //    them under it is magnified and bent (LensRefraction).
                rows
                    .modifier(LensRefraction(top: lensTop, bottom: lensBottom,
                                             strength: bends ? 1 : 0,
                                             width: panelWidth - panelPadding * 2))

                // 2. The lens itself.
                lens

                // 3. The words again in dark ink, cut to the shape of the
                //    lens, so the chosen row reads sharply on it. They
                //    fade out while the lens is lifted and clear.
                rowLabels
                    .foregroundStyle(Theme.sidebarSelectedInk)
                    .mask(alignment: .top) {
                        RoundedRectangle(cornerRadius: 14)
                            .frame(height: max(lensBottom - lensTop, 8))
                            .offset(y: lensTop)
                    }
                    .opacity(bends ? 0 : 1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            // Press and slide anywhere on the rows to carry the lens along,
            // as on the tab bar in Apple's own apps. "Simultaneous" means
            // the buttons underneath still get their taps.
            .simultaneousGesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in carryLens(to: value.location.y) }
                    .onEnded { value in dropLens(at: value.location.y) }
            )

            Spacer(minLength: 0)
        }
        .padding(panelPadding)
        .frame(width: panelWidth)
        .frame(maxHeight: .infinity)
        // Glass tinted dark green. The tint is nearly solid so the cream
        // words stay easy to read over whatever is behind.
        .glassEffect(.regular.tint(Theme.sidebar.opacity(0.9)), in: .rect(cornerRadius: 26))
        .padding(.leading, 12)
        .padding(.vertical, 12)
        .onAppear {
            moveLens(to: selection, animated: false)
            // A checking aid. Starting the app with `-sidebarLensHeld 0.5`
            // leaves the lens lifted, moved down by that many rows, so a
            // still picture can show how it bends what is under it. Use 0
            // to hold it over the chosen row.
            if UserDefaults.standard.object(forKey: "sidebarLensHeld") != nil {
                let nudge = (rowHeight + rowGap) * UserDefaults.standard.double(forKey: "sidebarLensHeld")
                isLifted = true
                lensTop += nudge
                lensBottom += nudge
            }
        }
        .onChange(of: selection) { _, section in
            moveLens(to: section, animated: true)
        }
        #if os(macOS)
        .onHover { isPointerOver = $0 }
        .onAppear { watchScrolling() }
        .onDisappear { stopWatchingScrolling() }
        #endif
    }

    // MARK: The pieces

    private var rows: some View {
        VStack(spacing: rowGap) {
            ForEach(AppSection.allCases) { section in
                Button {
                    withAnimation(.smooth(duration: 0.3)) { selection = section }
                } label: {
                    rowLabel(section)
                        .foregroundStyle(Theme.sidebarInk)
                        // Makes the whole row tappable, not only its words.
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(section == selection ? .isSelected : [])
            }
        }
    }

    /// The same words and icons as the rows, with nothing to press.
    private var rowLabels: some View {
        VStack(spacing: rowGap) {
            ForEach(AppSection.allCases) { section in
                rowLabel(section)
            }
        }
    }

    private func rowLabel(_ section: AppSection) -> some View {
        HStack(spacing: 12) {
            WIconView(section.icon, size: 22)
            Text(section.title)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: rowHeight)
    }

    /// The lens has two looks and fades between them.
    ///
    /// At rest it is Apple's own glass, tinted with the sidebar's lime
    /// and nearly solid. Lifted, it is a clear lens: a breath of tint, a
    /// bright rim and a soft shadow, with the bending done underneath by
    /// LensRefraction.
    ///
    /// Why not Apple's glass for both: Apple's glass frosts whatever is
    /// behind it, which would hide the very thing the lens should show.
    /// The clear, magnifying lens on Apple's tab bar is not something
    /// Apple lets other apps use, so this one is drawn here.
    private var lens: some View {
        ZStack {
            Color.clear
                // `.identity` means "no glass", and is how glass is
                // switched off without the view being rebuilt.
                .glassEffect(bends ? .identity : .regular.tint(Theme.sidebarSelected.opacity(0.92)),
                             in: .rect(cornerRadius: 14))

            ZStack {
                // A soft dark edge underneath, standing in for a shadow.
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.black.opacity(0.35), lineWidth: 4)
                    .blur(radius: 6)
                    .offset(y: 3)
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.sidebarSelected.opacity(0.14))
                // The rim: bright where the light catches it at the top
                // left, fading round to a fainter glint at the bottom right.
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.75), .white.opacity(0.10), .white.opacity(0.40)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1.3)
            }
            .opacity(bends ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: max(lensBottom - lensTop, 8))
        .scaleEffect(bends ? LensRefraction.lift : 1)
        .offset(y: lensTop)
        // Touches pass through to the rows underneath.
        .allowsHitTesting(false)
    }

    // MARK: Moving the lens

    /// Slides the lens to a row.
    ///
    /// It lifts off, and the edge nearer the new row sets off first and
    /// quickly. A moment later the other edge follows on a bouncier
    /// spring, so in between the lens is stretched across both rows.
    /// Then it sets itself back down.
    private func moveLens(to section: AppSection, animated: Bool) {
        let index = CGFloat(AppSection.allCases.firstIndex(of: section) ?? 0)
        let top = index * (rowHeight + rowGap)
        let bottom = top + rowHeight

        guard animated, !reduceMotion else {
            lensTop = top
            lensBottom = bottom
            isLifted = false
            return
        }

        moveNumber += 1
        let thisMove = moveNumber
        let goingDown = top > lensTop

        withAnimation(.spring(duration: 0.28, bounce: 0.15)) {
            isLifted = true
            if goingDown { lensBottom = bottom } else { lensTop = top }
        }
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            // If another row was chosen in the meantime, leave it to that move.
            guard thisMove == moveNumber else { return }
            withAnimation(.spring(duration: 0.55, bounce: 0.42)) {
                lensTop = top
                lensBottom = bottom
            }
            // Once it has arrived, set it back down.
            try? await Task.sleep(for: .milliseconds(300))
            guard thisMove == moveNumber else { return }
            withAnimation(.smooth(duration: 0.35)) { isLifted = false }
        }
    }

    /// The lens is being carried under a finger or the pointer.
    private func carryLens(to y: CGFloat) {
        guard !reduceMotion else { return }
        // Cancels a slide that is still finishing.
        moveNumber += 1
        // Keep the middle of the lens under the finger, within the rows.
        let top = min(max(y - rowHeight / 2, 0), lastRowTop)
        withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.75)) {
            isLifted = true
            lensTop = top
            lensBottom = top + rowHeight
        }
    }

    /// The lens has been let go. It settles on the nearest row.
    private func dropLens(at y: CGFloat) {
        guard !reduceMotion else { return }
        let step = rowHeight + rowGap
        let nearest = Int(((y - rowHeight / 2) / step).rounded())
        let index = min(max(nearest, 0), AppSection.allCases.count - 1)
        let section = AppSection.allCases[index]
        if section == selection {
            // The same place as before: just set the lens back down on it.
            moveLens(to: section, animated: true)
        } else {
            // Choosing the place moves the lens too (see onChange above).
            withAnimation(.smooth(duration: 0.3)) { selection = section }
        }
    }

    // MARK: Scrolling the lens (Mac)

    #if os(macOS)
    /// Starts watching for scrolling.
    ///
    /// SwiftUI has no "this view was scrolled over" for a view that is
    /// not a scrolling list. So this asks the Mac itself to pass every
    /// scroll in the app through here first. A scroll with the pointer
    /// over the sidebar is used to move the lens and goes no further.
    /// Any other scroll is handed straight back, untouched, to wherever
    /// it was going.
    private func watchScrolling() {
        guard scrollWatcher == nil else { return }
        scrollWatcher = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { scroll in
            guard isPointerOver else { return scroll }
            lensScrolled(by: scroll)
            return nil
        }
    }

    private func stopWatchingScrolling() {
        if let scrollWatcher { NSEvent.removeMonitor(scrollWatcher) }
        scrollWatcher = nil
    }

    /// Moves the lens for one piece of a scroll.
    private func lensScrolled(by scroll: NSEvent) {
        // After the fingers lift, a trackpad keeps sending a glide that
        // dies away. The lens has already settled, so that is ignored.
        guard scroll.momentumPhase.isEmpty else { return }

        // How far down the list to go, in points. The Mac has already
        // turned the scroll the way System Settings says, so the lens
        // moves as a list would scroll. With natural scrolling (the
        // Mac's default) fingers pushed up go down the list.
        // (Until 13 November 2026 the lens followed the fingers like a
        // drag instead, which William found backwards.)
        let fingers = -scroll.scrollingDeltaY

        // A mouse wheel has no beginning or end, only clicks. Each
        // click moves one row.
        if scroll.phase.isEmpty {
            guard fingers != 0, Date.now.timeIntervalSince(lastWheelStep) > 0.15 else { return }
            lastWheelStep = .now
            stepSelection(by: fingers > 0 ? 1 : -1)
            return
        }

        if scroll.phase.contains(.began) {
            let index = CGFloat(AppSection.allCases.firstIndex(of: selection) ?? 0)
            scrollStart = index * (rowHeight + rowGap)
            scrollTravel = 0
            isScrollingLens = true
        }
        // Two fingers resting on the trackpad, or lifted again without
        // moving, are reported too. Neither is a scroll.
        guard isScrollingLens else { return }

        // Add up how far the fingers have gone, never past either end.
        let wanted = scrollStart + scrollTravel + fingers * scrollGearing
        scrollTravel = min(max(wanted, 0), lastRowTop) - scrollStart
        // carryLens and dropLens are given the middle of the lens, as
        // they are when it is dragged.
        let middle = scrollStart + scrollTravel + rowHeight / 2

        if scroll.phase.contains(.ended) || scroll.phase.contains(.cancelled) {
            if reduceMotion {
                // No sliding lens. A scroll of any size is one step.
                if abs(scrollTravel) > 12 { stepSelection(by: scrollTravel > 0 ? 1 : -1) }
            } else {
                dropLens(at: middle)
            }
            scrollTravel = 0
            isScrollingLens = false
        } else {
            carryLens(to: middle)
        }
    }

    /// Chooses the row above (-1) or below (+1) the chosen one.
    private func stepSelection(by amount: Int) {
        let sections = AppSection.allCases
        let index = sections.firstIndex(of: selection) ?? 0
        let next = min(max(index + amount, 0), sections.count - 1)
        guard next != index else { return }
        withAnimation(.smooth(duration: 0.3)) { selection = sections[next] }
    }
    #endif
}

/// Magnifies and bends whatever lies under the sidebar's lens.
///
/// The bending is done by a small program for the graphics chip, in
/// Lens.metal. This passes it where the lens is and how strong to be.
///
/// `Animatable` matters here. SwiftUI can glide a colour or a position
/// from one value to another by itself, but it knows nothing about the
/// numbers handed to a graphics program. `animatableData` names the
/// numbers to glide, and SwiftUI then calls `body` afresh for every
/// frame with the in-between values, so the bend keeps exact step with
/// the lens drawn on top of it.
struct LensRefraction: ViewModifier, Animatable {

    /// Whether the graphics program (Lens.metal) is part of the app.
    ///
    /// Set this to false to switch the bending off in one place. The
    /// lens then keeps its solid lime look while it moves. Handy if the
    /// effect ever misbehaves on some device.
    static let isBuilt = true

    /// How much larger the lens is while lifted. The lens drawn on top
    /// uses the same figure, so the two always match.
    static let lift: CGFloat = 1.06

    /// The lens's top and bottom edges, measured down from the first row.
    var top: CGFloat
    var bottom: CGFloat
    /// 0 for no bending, 1 for the full effect.
    var strength: CGFloat
    /// The width of the rows.
    var width: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(top, bottom), strength) }
        set {
            top = newValue.first.first
            bottom = newValue.first.second
            strength = newValue.second
        }
    }

    func body(content: Content) -> some View {
        if Self.isBuilt {
            let height = max(bottom - top, 8)
            // The lens grows as it lifts.
            let grown = 1 + (Self.lift - 1) * strength
            content.layerEffect(
                ShaderLibrary.lensRefraction(
                    .float2(width / 2, top + height / 2),
                    .float2(width / 2 * grown, height / 2 * grown),
                    .float(16),
                    .float(strength)),
                // The furthest the program may reach for a dot's colour.
                maxSampleOffset: CGSize(width: 32, height: 32),
                isEnabled: strength > 0.001)
        } else {
            content
        }
    }
}

// The Gardens and Wildlife pages are in HubScreens.swift.

// MARK: - More

struct MoreTab: View {
    var body: some View {
        List {
            NavigationLink { UniversalSearchView() } label: {
                Label("Search everything", systemImage: "magnifyingglass")
            }
            NavigationLink { KnowledgeBaseView() } label: {
                Label("Knowledge base", systemImage: "brain")
            }
            NavigationLink { ChartsView() } label: {
                Label("Charts", systemImage: "chart.xyaxis.line")
            }
            NavigationLink { ExportView() } label: {
                Label("Export records", systemImage: "square.and.arrow.up")
            }
            NavigationLink { NotificationSettingsView() } label: {
                Label("Reminders", systemImage: "bell")
            }
            NavigationLink { VoiceSettingsView() } label: {
                Label("Voice", systemImage: "mic")
            }
            NavigationLink { BackupView() } label: {
                Label("Backup", systemImage: "externaldrive")
            }
            NavigationLink { SettingsView() } label: {
                Label("Settings", systemImage: "gear")
            }
        }
        .navigationTitle("Settings and tools")
        .paperScreen()
    }
}

// MARK: - Settings

struct SettingsView: View {

    @AppStorage("recorderName") private var recorderName = ""
    @AppStorage("gridPrecision") private var gridPrecision = 100
    @AppStorage("eiraBarStaysOpen") private var eiraBarStaysOpen = false
    @AppStorage("plainBackground") private var plainBackground = false
    @AppStorage("plainTransitions") private var plainTransitions = false
    /// True when the sidebar has been put away to give the page the
    /// whole window. Remembered between visits.
    @AppStorage("sidebarIsHidden") private var sidebarIsHidden = false

    var body: some View {
        Form {
            Section {
                TextField("Your name", text: $recorderName)

                Picker("Grid precision", selection: $gridPrecision) {
                    Text("10 m").tag(10)
                    Text("100 m").tag(100)
                    Text("1 km").tag(1000)
                }
            } header: {
                Text("Recording")
            } footer: {
                Text("iRecord needs a recorder name on every record. Coarser grid precision publishes a garden record without pinpointing the house.")
            }

            Section {
                Toggle("Keep her bar open", isOn: $eiraBarStaysOpen)
            } header: {
                Text("Eira's button")
            } footer: {
                Text("Eira's snowdrop floats in the bottom right corner. Tap it to ask, search or open anything. With this on, her bar is always there to type into.")
            }

            Section {
                NavigationLink {
                    GardenDataView()
                } label: {
                    Label("Garden data", systemImage: "tray.and.arrow.down")
                }
            } header: {
                Text("Data")
            } footer: {
                Text("Your records are stored on this device and are not sent anywhere. To fetch the weather, the app sends the weather service each garden's location, rounded to about a hundred metres, and nothing else.")
            }

            Section {
                Toggle("Plain background", isOn: $plainBackground)
                Toggle("Plain fade between places", isOn: $plainTransitions)
            } header: {
                Text("Speed checks")
            } footer: {
                Text("If the app feels slow, try these one at a time. The first leaves out the soft washes of colour behind every screen. The second swaps the melt between places for a simple fade. If one of them makes the difference, that is what to change for good.")
            }

            Section("Credits") {
                WeatherCredit()
            }
        }
        .navigationTitle("Settings")
        .paperScreen()
    }
}
