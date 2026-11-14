//
//  YearMonthView.swift
//  Windfall
//
//  One month of the Year page, opened up.
//
//  Tap a month at the top of the Year page and this page opens: the
//  month's name in large letters and a card for each job, listing the
//  plants it can be done for that month. What to sow and plant is on the
//  left, what to pick and what is in flower on the right. On a narrow
//  screen the cards sit in one column, sowing and planting first.
//
//  Beside a plant:
//    "This month only"   the job can be done in this month and no other
//    "Last chance"       this is the last month of its stretch
//    "Starts now"        this is the first month of its stretch
//    "to March"          it can wait: the stretch runs on until then
//
//  The pressing ones come first in each card.
//
//  Moving between months (asked for by William on 14 November 2026,
//  15:31):
//    - swipe sideways, like turning the pages of a calendar
//    - press the arrows by the month's name
//    - press the month's name for a list of the twelve months
//
//  How the swiping works: the months are laid side by side in a row that
//  scrolls sideways and stops on a whole page each time. Each page is a
//  month, with its own name and cards, and scrolls up and down by
//  itself. The row holds the twelve months many times over, so December
//  leads on to January (see `YearCalendar.monthPageCount`).
//
//  On a Mac the row is moved by hand instead (William, 14 November
//  2026, 16:49: the iPhone's swipe is "exactly as I want it... like
//  you're dragging something. This is how I want it to work with two
//  finger swipe on the mac"). Three pages are laid in a row, the month
//  showing with its neighbours either side, and the row is drawn as far
//  across as two fingers on the trackpad have moved. Lifting the fingers
//  lets it slide on to the next month or settle back. See `handRow`,
//  `MonthDrag` and `MonthSwipes`.
//
//  Asked for by William on 14 November 2026: "when you click or tap the
//  month at the top of this page, you can see the month bigger and see
//  what needs to be planted that month".
//
//  The sums (which plants, and where the month falls in each stretch)
//  are in YearCalendar.swift, where they are tested without a screen.
//

import SwiftUI
import SwiftData

struct YearMonthView: View {

    // Every plant, A to Z. `@Query` keeps the list up to date by itself
    // when a record changes.
    @Query(sort: [SortDescriptor(\Plant.commonName)]) private var plants: [Plant]

    /// Which page of the row of months is showing. `@State` because
    /// swiping, the arrows and the list of months all change it while
    /// this screen stays open. The `?` is there because the scrolling
    /// row wants a value that may be empty. It never is in practice.
    @State private var shownPage: Int?
    /// The kind of plant the Year page was filtered to when this page
    /// was opened, such as vegetables. Nil means every kind.
    let plantKind: PlantKind?
    /// The cards that have been asked to show their whole list.
    @State private var opened: Set<YearActivity> = []

    /// How many plants a card lists before it offers "Show all".
    private let shortList = 10

    /// How far the row of months has been dragged sideways, on a Mac.
    /// See `MonthDrag` at the foot of this file.
    @State private var monthDrag = MonthDrag()

    #if os(macOS)
    /// Watches the Mac's trackpad for two fingers moving sideways. See
    /// `MonthSwipes` at the foot of this file.
    @State private var trackpadSwipes = MonthSwipes()
    #endif

    /// True where the row of months is moved by hand: on a Mac, whose
    /// trackpad does not scroll a row of pages the way a finger does on
    /// an iPhone. (A checking aid, `-demoMonthMacRow YES`, gives the
    /// Mac's row to an iPad in the simulator, where it can be looked at.)
    private var movesRowByHand: Bool {
        #if os(macOS)
        return true
        #else
        return DemoGarden.usesMacMonthRow
        #endif
    }

    init(month: Int, plantKind: PlantKind? = nil) {
        // `_shownPage` with the underscore is the store behind the
        // @State value. This is how a @State is given its first value
        // from outside.
        _shownPage = State(initialValue: YearCalendar.middlePage(for: month))
        self.plantKind = plantKind
    }

    private var thisMonth: Int { Calendar.current.component(.month, from: .now) }
    /// The page showing, as a plain number.
    private var pageNow: Int { shownPage ?? YearCalendar.middlePage(for: thisMonth) }
    /// The month showing, 1 for January to 12 for December.
    private var shownMonth: Int { YearCalendar.month(atPage: pageNow) }
    private var monthTitle: String { PlantFilter.monthName(shownMonth) }

    /// The plants this page chooses from: the same ones the Year page
    /// lists. Only what is being grown, and only the chosen kind.
    private var growing: [Plant] {
        plants.filter { plant in
            guard plant.status == .growing else { return false }
            if let plantKind, PlantKind.of(group: plant.group) != plantKind { return false }
            return true
        }
    }

    /// Each job's plants for one month. A dictionary is a look-up
    /// table: hand it a job and it hands back that job's list.
    private func monthLists(for month: Int, from chosenFrom: [Plant]) -> [YearActivity: [MonthEntry]] {
        var lists: [YearActivity: [MonthEntry]] = [:]
        for job in YearActivity.allCases {
            lists[job] = YearCalendar.entries(for: job, in: month, from: chosenFrom)
        }
        return lists
    }

    // MARK: The screen

    var body: some View {
        // Worked out once for this redraw, and shared by every page.
        let chosenFrom = growing

        // GeometryReader says how big the screen's space is. Each page
        // is made exactly that wide, so one page fills it.
        GeometryReader { geometry in
            let isWide = geometry.size.width >= 720

            if movesRowByHand {
                handRow(from: chosenFrom, isWide: isWide, space: geometry.size)
            } else {
                // The row of months. It scrolls sideways.
                ScrollView(.horizontal) {
                    // "Lazy" means a page is only built when it is about
                    // to slide into view, so 240 pages cost no more than
                    // three.
                    LazyHStack(alignment: .top, spacing: 0) {
                        ForEach(0..<YearCalendar.monthPageCount, id: \.self) { page in
                            monthPage(YearCalendar.month(atPage: page), from: chosenFrom, isWide: isWide)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                    }
                    // Marks each page as a place the scrolling can stop.
                    .scrollTargetLayout()
                }
                // Stops on a whole page, never between two.
                .scrollTargetBehavior(.paging)
                // Ties the row to `shownPage` both ways: a swipe changes
                // the number, and changing the number scrolls the row.
                .scrollPosition(id: $shownPage)
                .scrollIndicators(.hidden)
            }
        }
        .paperScreen()
        .navigationTitle(monthTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        // The large name on the page is the title, so the bar shows no
        // words of its own.
        .toolbar { ToolbarItem(placement: .principal) { Text("") } }
        // Tells Eira which month is open. See EiraScreen.
        .eiraLooksAt("the month of \(monthTitle) on the Year page, which lists what can be sown, planted out and harvested then and what is in flower",
                     short: monthTitle)
        // A new month starts with short lists again.
        .onChange(of: shownPage) { opened = [] }
        #if os(macOS)
        .onAppear {
            // While this page is showing, a sideways swipe turns the
            // month, and the swipe that goes back a page stands aside.
            PointerClaims.monthPageIsOpen = true
            trackpadSwipes.start(
                // While the fingers move, the row goes with them, no
                // further than one page either way.
                whenDragged: { travel in
                    guard !monthDrag.isSettling else { return }
                    let most = monthDrag.pageWidth
                    monthDrag.across = max(-most, min(most, travel))
                },
                // When they lift, it slides on or settles back.
                whenLifted: { steps in settleRow(turning: steps) }
            )
        }
        .onDisappear {
            PointerClaims.monthPageIsOpen = false
            trackpadSwipes.stop()
        }
        #endif
        // Checking aids: see DemoGarden.stepsMonth and thenMonth.
        .task {
            let steps = DemoGarden.stepsMonth
            let then = DemoGarden.thenMonth
            guard steps != 0 || then != nil else { return }
            try? await Task.sleep(for: .seconds(1.5))
            if steps != 0 { turnPages(by: steps) }
            if let then { showMonth(then) }
        }
        // A checking aid: holds the Mac's row part-way through a drag.
        // See DemoGarden.dragsMonthRow.
        .task {
            guard let held = DemoGarden.dragsMonthRow else { return }
            try? await Task.sleep(for: .seconds(1.5))
            monthDrag.across = held
        }
    }

    /// The row of months on a Mac: the month showing with the month
    /// before on its left and the month after on its right. Only the
    /// middle one is in view until the row is dragged.
    private func handRow(from chosenFrom: [Plant], isWide: Bool, space: CGSize) -> some View {
        let threePages = [pageNow - 1, pageNow, pageNow + 1]

        // `MonthRowSlide` draws the row as far across as it has been
        // dragged. It is a view of its own so that a drag redraws only
        // the row's place, and not every card on the three pages.
        return MonthRowSlide(monthDrag: monthDrag) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(threePages, id: \.self) { page in
                    monthPage(YearCalendar.month(atPage: page), from: chosenFrom, isWide: isWide)
                        .frame(width: space.width, height: space.height)
                        // The two at the sides are for looking at as
                        // they slide past. They take no clicks, and
                        // VoiceOver does not read them.
                        .allowsHitTesting(page == pageNow)
                        .accessibilityHidden(page != pageNow)
                }
            }
        }
        // The row is three pages wide. This frame is one page wide and
        // holds the row by its middle, so the middle page fills it.
        .frame(width: space.width, height: space.height)
        // Hides whatever falls outside the frame: the pages either side.
        .clipped()
        // Keeps a note of the page's width, which is how far the row
        // slides to turn a page. `initial: true` runs it once at the
        // start as well as on every change.
        .onChange(of: space.width, initial: true) { monthDrag.pageWidth = space.width }
    }

    /// One month: its name, its count and its cards, scrolling up and
    /// down.
    private func monthPage(_ month: Int, from chosenFrom: [Plant], isWide: Bool) -> some View {
        let lists = monthLists(for: month, from: chosenFrom)

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(for: month)
                summary(lists)

                if isWide {
                    // Two columns, each as tall as its own cards.
                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 16) {
                            jobCard(.sowIndoors, lists, month: month)
                            jobCard(.sowOutdoors, lists, month: month)
                            jobCard(.plantOut, lists, month: month)
                        }
                        VStack(spacing: 16) {
                            jobCard(.harvest, lists, month: month)
                            jobCard(.flowering, lists, month: month)
                        }
                    }
                } else {
                    ForEach(YearActivity.allCases) { job in
                        jobCard(job, lists, month: month)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
    }

    // MARK: Moving between months

    /// Turns the pages forward (1) or back (-1), sliding.
    private func turnPages(by steps: Int) {
        if movesRowByHand {
            settleRow(turning: steps)
            return
        }
        let target = pageNow + steps
        guard (0..<YearCalendar.monthPageCount).contains(target) else {
            // Off the end of the pages, after ten years of turning one
            // way. Start again from the middle, on the right month.
            showMonth(YearCalendar.month(atPage: target))
            return
        }
        withAnimation(.smooth(duration: 0.35)) { shownPage = target }
    }

    /// Goes straight to a month, by the shortest way round, with no
    /// sliding: a slide across five months would have to build every
    /// page it passed.
    private func showMonth(_ month: Int) {
        let target: Int
        if (0..<YearCalendar.monthPageCount).contains(pageNow) {
            target = YearCalendar.page(for: month, nearest: pageNow)
        } else {
            target = YearCalendar.middlePage(for: month)
        }
        // A Transaction carries how a change should be shown. This one
        // says: with no animation.
        var quiet = Transaction()
        quiet.disablesAnimations = true
        withTransaction(quiet) {
            shownPage = target
            monthDrag.across = 0
        }
    }

    /// On a Mac: finishes a drag, or does the whole of a turn when an
    /// arrow is pressed. With 1 the row slides left until the month
    /// after fills the page, with -1 it slides right to the month
    /// before, and with 0 it settles back where it was.
    private func settleRow(turning steps: Int) {
        // One turn at a time.
        guard !monthDrag.isSettling else { return }
        guard steps != 0 else {
            withAnimation(.smooth(duration: 0.25)) { monthDrag.across = 0 }
            return
        }

        monthDrag.isSettling = true
        let landing = steps > 0 ? -monthDrag.pageWidth : monthDrag.pageWidth
        var target = pageNow + steps
        if !(0..<YearCalendar.monthPageCount).contains(target) {
            target = YearCalendar.middlePage(for: YearCalendar.month(atPage: target))
        }

        // First the slide. `completion` is run when it has finished.
        withAnimation(.smooth(duration: 0.3)) {
            monthDrag.across = landing
        } completion: {
            // Then, in one go and with no animation: the month that slid
            // into view becomes the month showing, and the row goes back
            // to rest. The two cancel out, so nothing is seen to move.
            var quiet = Transaction()
            quiet.disablesAnimations = true
            withTransaction(quiet) {
                shownPage = target
                monthDrag.across = 0
            }
            monthDrag.isSettling = false
        }
    }

    // MARK: The top of the page

    /// The month's name in the large serif letters, with an arrow each
    /// side to step through the year. The name itself is a button that
    /// brings up a list of the twelve months.
    private func header(for month: Int) -> some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(headerDetail(for: month))
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                monthMenu(for: month)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            stepButton(monthsOn: -1, symbol: "chevron.left")
            stepButton(monthsOn: 1, symbol: "chevron.right")
        }
    }

    /// The month's name as a button. Pressing it lists the twelve
    /// months, with a tick by the one showing. Choosing one goes there.
    private func monthMenu(for month: Int) -> some View {
        // A Binding is a two-way link to a value. This one reads the
        // month showing, and when the list is used it goes to the month
        // chosen.
        let monthChoice = Binding<Int>(
            get: { shownMonth },
            set: { showMonth($0) }
        )
        return Menu {
            // A Picker inside a Menu gives a list with a tick beside
            // the chosen one. `tag` says which month each line stands for.
            Picker("Month", selection: monthChoice) {
                ForEach(1...12, id: \.self) { listed in
                    Text(listed == thisMonth
                         ? "\(PlantFilter.monthName(listed)) (this month)"
                         : PlantFilter.monthName(listed))
                        .tag(listed)
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(PlantFilter.monthName(month))
                    .font(.screenTitle)
                    .foregroundStyle(Theme.ink)
                // A small arrow, to show the name can be pressed.
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .contentShape(.rect)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        // The Mac would otherwise stretch the button across the page.
        .fixedSize()
        .accessibilityLabel(PlantFilter.monthName(month))
        .accessibilityHint("Lists the months to choose from")
        .accessibilityAddTraits(.isHeader)
    }

    /// The small line above the name: how the month stands to today, and
    /// the kind of plant if the Year page was filtered.
    private func headerDetail(for month: Int) -> String {
        var words: String
        if month == thisMonth {
            words = "This month"
        } else if month == YearCalendar.monthAfter(thisMonth) {
            words = "Next month"
        } else if month == YearCalendar.monthBefore(thisMonth) {
            words = "Last month"
        } else {
            words = "Year"
        }
        if let plantKind { words += " · \(plantKind.rawValue) only" }
        return words
    }

    /// A round glass button that turns to the month before (`monthsOn`
    /// of -1) or the month after (1).
    private func stepButton(monthsOn: Int, symbol: String) -> some View {
        Button {
            turnPages(by: monthsOn)
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Theme.card.opacity(0.4)).interactive(), in: .circle)
        .accessibilityLabel(monthsOn < 0 ? "The month before" : "The month after")
    }

    /// One line under the name that counts the month up.
    private func summary(_ lists: [YearActivity: [MonthEntry]]) -> some View {
        func count(_ job: YearActivity) -> Int { lists[job]?.count ?? 0 }
        // A plant that can be sown indoors and outdoors is one plant to
        // sow, so the three planting jobs are counted by plant.
        var toPlant = Set<UUID>()
        for job in [YearActivity.sowIndoors, .sowOutdoors, .plantOut] {
            for entry in lists[job] ?? [] { toPlant.insert(entry.plant.id) }
        }
        var parts: [String] = []
        parts.append(toPlant.isEmpty ? "Nothing to sow or plant" : "\(toPlant.count) to sow or plant")
        if count(.harvest) > 0 { parts.append("\(count(.harvest)) to harvest") }
        if count(.flowering) > 0 { parts.append("\(count(.flowering)) in flower") }

        return Text(parts.joined(separator: " · "))
            .font(.subheadline)
            .foregroundStyle(Theme.inkSoft)
    }

    // MARK: The cards

    /// One job's card: its name, how many plants, and the plants.
    private func jobCard(_ job: YearActivity, _ lists: [YearActivity: [MonthEntry]], month: Int) -> some View {
        let found = lists[job] ?? []
        // "Show all" belongs to the month showing. The pages either
        // side, part-seen during a swipe, keep their short lists.
        let showsAll = (month == shownMonth && opened.contains(job)) || found.count <= shortList
        let shown = showsAll ? found : Array(found.prefix(shortList))

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                // The job's coloured dot, as on the Year page's buttons.
                YearKey(activity: job, asLine: false)
                Text(job.rawValue)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                if !found.isEmpty {
                    Text(found.count == 1 ? "1 plant" : "\(found.count) plants")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            if found.isEmpty {
                Text("\(Self.nothingWords(for: job)) in \(PlantFilter.monthName(month)).")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            } else {
                ForEach(shown) { entry in
                    Divider()
                        .overlay(Theme.hairline)
                    // Tapping a plant opens its page, as on the Year page.
                    NavigationLink {
                        PlantDetailView(plant: entry.plant)
                    } label: {
                        entryRow(entry, job: job)
                    }
                    .buttonStyle(.plain)
                }

                if !showsAll {
                    Divider()
                        .overlay(Theme.hairline)
                    Button {
                        withAnimation(.smooth(duration: 0.25)) { _ = opened.insert(job) }
                    } label: {
                        Text("Show all \(found.count)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.leaf)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    /// One plant in a card: its name and variety, and on the right the
    /// pressing words or how long the job can wait.
    private func entryRow(_ entry: MonthEntry, job: YearActivity) -> some View {
        let variety = (entry.plant.variety ?? "").trimmingCharacters(in: .whitespaces)
        let pressing = YearCalendar.tag(for: entry.monthPlace, job: job)

        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.plant.commonName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                if !variety.isEmpty {
                    Text(variety)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            Spacer(minLength: 8)
            if let pressing {
                // A small coloured label. Amber for what cannot wait,
                // green for what has just begun. The words say which,
                // so the meaning does not rest on the colour.
                let isUrgent = entry.monthPlace != .opening
                Text(pressing)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background((isUrgent ? Theme.amber : Theme.leafFill).opacity(isUrgent ? 0.35 : 0.8),
                                in: .capsule)
            } else {
                Text(Self.waitWords(for: entry))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .lineLimit(1)
        .contentShape(.rect)
        // Read out as one line: "Leek, Musselburgh. Last chance."
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(EiraSight.name(entry.plant.commonName, variety: entry.plant.variety))
        .accessibilityValue(pressing ?? Self.waitWords(for: entry))
    }

    // MARK: Words

    /// "to March" when the stretch runs on, or "All year".
    private static func waitWords(for entry: MonthEntry) -> String {
        guard let end = entry.lastMonth else { return "All year" }
        return "to \(PlantFilter.monthName(end))"
    }

    /// What an empty card says, before "in November."
    private static func nothingWords(for job: YearActivity) -> String {
        switch job {
        case .sowIndoors: return "Nothing to sow indoors"
        case .sowOutdoors: return "Nothing to sow outdoors"
        case .plantOut: return "Nothing to plant out"
        case .harvest: return "Nothing to harvest"
        case .flowering: return "Nothing in flower"
        }
    }
}


// MARK: - The row of months, moved by hand

/// How far the row of months has been dragged, on a Mac.
///
/// It is a `class` marked `@Observable`, kept apart from the page, for
/// one reason: speed. A drag changes `across` a hundred times a second.
/// Only a view that reads `across` is redrawn when it changes, and the
/// only one that does is `MonthRowSlide` below, which just draws the row
/// in a new place. The pages and their cards are left alone.
@Observable
final class MonthDrag {
    /// How far the row is drawn to the right of where it rests, in
    /// points. Less than zero is to the left.
    var across: CGFloat = 0
    /// True while the row is sliding the rest of the way by itself.
    var isSettling = false
    /// How wide one page is.
    var pageWidth: CGFloat = 800
}

/// Draws the row of months as far across as it has been dragged.
///
/// `Months` in angle brackets stands for "whatever kind of view the row
/// turns out to be". `@ViewBuilder` lets the row be written between
/// braces where this is used.
struct MonthRowSlide<Months: View>: View {

    let monthDrag: MonthDrag
    @ViewBuilder let monthRow: Months

    var body: some View {
        // `offset` draws a view somewhere else without moving anything
        // around it.
        monthRow.offset(x: monthDrag.across)
    }
}

#if os(macOS)
import AppKit

// MARK: - Two fingers on a Mac's trackpad

/// Watches the Mac's trackpad while a month's page is open. It says how
/// far two fingers have moved sideways, as they move, and which way to
/// turn when they lift.
///
/// It works the way `BackSwipe` does in PageZoom.swift: the Mac passes
/// every scroll in the app through here first.
///
/// It is a `class`, not a `struct`, because the Mac holds on to it
/// between one piece of a scroll and the next, and it has to remember
/// how far the fingers have gone.
final class MonthSwipes {

    private var watcher: Any?
    private var travel: CGFloat = 0
    private var rise: CGFloat = 0
    /// Whether this swipe is a sideways one. Nil until the fingers have
    /// moved far enough to tell.
    private var isSideways: Bool?
    /// True after a sideways swipe, while the Mac is still sending the
    /// glide that follows the fingers lifting.
    private var swallowsGlide = false
    private var whenDragged: ((CGFloat) -> Void)?
    private var whenLifted: ((Int) -> Void)?

    /// How far two fingers must have travelled, in points, for lifting
    /// them to turn the month.
    private let needed: CGFloat = 60

    /// Starts watching.
    /// - `whenDragged` is handed how far the fingers have moved so far:
    ///   more than zero to the right, less to the left.
    /// - `whenLifted` is handed 1 to go on to the next month (the fingers
    ///   went left), -1 for the month before, or 0 to stay.
    func start(whenDragged: @escaping (CGFloat) -> Void, whenLifted: @escaping (Int) -> Void) {
        self.whenDragged = whenDragged
        self.whenLifted = whenLifted
        guard watcher == nil else { return }
        watcher = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] scroll in
            // Handing back nil uses the scroll up, so nothing else sees
            // it. Handing the scroll back lets it carry on as usual.
            (self?.usedUp(scroll) ?? false) ? nil : scroll
        }
    }

    func stop() {
        if let watcher { NSEvent.removeMonitor(watcher) }
        watcher = nil
        whenDragged = nil
        whenLifted = nil
    }

    /// Looks at one piece of a scroll. Returns true if it was used up
    /// here and should go no further.
    private func usedUp(_ scroll: NSEvent) -> Bool {
        // After the fingers lift, a trackpad keeps sending a glide that
        // dies away. After a sideways swipe it is used up here, so the
        // page under the pointer does not drift.
        if !scroll.momentumPhase.isEmpty {
            let wasSwallowing = swallowsGlide
            if scroll.momentumPhase.contains(.ended) || scroll.momentumPhase.contains(.cancelled) {
                swallowsGlide = false
            }
            return wasSwallowing
        }
        // A mouse wheel has no beginning or end. It is left to the page.
        guard !scroll.phase.isEmpty else { return false }

        if scroll.phase.contains(.began) || scroll.phase.contains(.mayBegin) {
            travel = 0
            rise = 0
            isSideways = nil
            swallowsGlide = false
        }

        // The fingers have lifted, or the swipe was called off.
        if scroll.phase.contains(.ended) || scroll.phase.contains(.cancelled) {
            guard isSideways == true else {
                isSideways = false
                return false
            }
            isSideways = false
            swallowsGlide = true
            var steps = 0
            if scroll.phase.contains(.ended), abs(travel) > needed {
                // Fingers to the left pull the next month in from the
                // right, as a finger does on an iPhone.
                steps = travel < 0 ? 1 : -1
            }
            whenLifted?(steps)
            // Handed on, so the page under the pointer also hears that
            // the swipe is over.
            return false
        }

        guard isSideways != false else { return false }
        // A sliding switch under the pointer owns a sideways swipe. So
        // does a sheet, such as Eira's chat.
        guard !PointerClaims.isOverSwitch,
              let window = scroll.window, window.attachedSheet == nil, window.sheetParent == nil else {
            isSideways = false
            return false
        }

        // Fingers moving right count up. See GlassSwitch for why the
        // sign is turned when "natural scrolling" is off.
        travel += scroll.isDirectionInvertedFromDevice ? scroll.scrollingDeltaX : -scroll.scrollingDeltaX
        rise += abs(scroll.scrollingDeltaY)

        if isSideways == nil {
            // Wait until the fingers have moved a little, then decide
            // once: more across than up or down is a sideways swipe.
            // Anything else is ordinary scrolling, left alone until the
            // next swipe.
            guard abs(travel) + rise > 10 else { return false }
            isSideways = abs(travel) > rise * 1.5
            guard isSideways == true else { return false }
        }

        whenDragged?(travel)
        return true
    }
}
#endif
