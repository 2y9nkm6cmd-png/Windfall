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
//  The pressing ones come first in each card. The arrows by the month's
//  name step to the month before and after.
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

    /// The month being shown, 1 for January to 12 for December. `@State`
    /// because the arrows change it while the page stays open.
    @State private var shownMonth: Int
    /// The kind of plant the Year page was filtered to when this page
    /// was opened, such as vegetables. Nil means every kind.
    let plantKind: PlantKind?
    /// The cards that have been asked to show their whole list.
    @State private var opened: Set<YearActivity> = []

    /// How many plants a card lists before it offers "Show all".
    private let shortList = 10

    init(month: Int, plantKind: PlantKind? = nil) {
        // `_shownMonth` with the underscore is the store behind the
        // @State value. This is how a @State is given its first value
        // from outside.
        _shownMonth = State(initialValue: min(max(month, 1), 12))
        self.plantKind = plantKind
    }

    private var thisMonth: Int { Calendar.current.component(.month, from: .now) }
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

    /// Each job's plants for the month being shown. A dictionary is a
    /// look-up table: hand it a job and it hands back that job's list.
    private var monthLists: [YearActivity: [MonthEntry]] {
        let chosenFrom = growing
        var lists: [YearActivity: [MonthEntry]] = [:]
        for job in YearActivity.allCases {
            lists[job] = YearCalendar.entries(for: job, in: shownMonth, from: chosenFrom)
        }
        return lists
    }

    // MARK: The screen

    var body: some View {
        // Worked out once for this redraw.
        let lists = monthLists

        // GeometryReader says how wide the page is.
        GeometryReader { geometry in
            let isWide = geometry.size.width >= 720

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    summary(lists)

                    if isWide {
                        // Two columns, each as tall as its own cards.
                        HStack(alignment: .top, spacing: 16) {
                            VStack(spacing: 16) {
                                jobCard(.sowIndoors, lists)
                                jobCard(.sowOutdoors, lists)
                                jobCard(.plantOut, lists)
                            }
                            VStack(spacing: 16) {
                                jobCard(.harvest, lists)
                                jobCard(.flowering, lists)
                            }
                        }
                    } else {
                        ForEach(YearActivity.allCases) { job in
                            jobCard(job, lists)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
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
    }

    // MARK: The top of the page

    /// The month's name in the large serif letters, with an arrow each
    /// side to step through the year.
    private var header: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ScreenHeader(title: monthTitle, detail: headerDetail)
            stepButton(monthsOn: -1, symbol: "chevron.left")
            stepButton(monthsOn: 1, symbol: "chevron.right")
        }
    }

    /// The small line above the name: how the month stands to today, and
    /// the kind of plant if the Year page was filtered.
    private var headerDetail: String {
        var words: String
        if shownMonth == thisMonth {
            words = "This month"
        } else if shownMonth == YearCalendar.monthAfter(thisMonth) {
            words = "Next month"
        } else if shownMonth == YearCalendar.monthBefore(thisMonth) {
            words = "Last month"
        } else {
            words = "Year"
        }
        if let plantKind { words += " · \(plantKind.rawValue) only" }
        return words
    }

    /// A round glass button that moves to the month before (`monthsOn`
    /// of -1) or the month after (1).
    private func stepButton(monthsOn: Int, symbol: String) -> some View {
        let target = monthsOn < 0 ? YearCalendar.monthBefore(shownMonth) : YearCalendar.monthAfter(shownMonth)
        return Button {
            withAnimation(.smooth(duration: 0.25)) {
                shownMonth = target
                // A new month starts with short lists again.
                opened = []
            }
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Theme.card.opacity(0.4)).interactive(), in: .circle)
        .accessibilityLabel(PlantFilter.monthName(target))
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
    private func jobCard(_ job: YearActivity, _ lists: [YearActivity: [MonthEntry]]) -> some View {
        let found = lists[job] ?? []
        let showsAll = opened.contains(job) || found.count <= shortList
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
                Text("\(Self.nothingWords(for: job)) in \(monthTitle).")
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
