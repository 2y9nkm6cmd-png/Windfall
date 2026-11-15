//
//  YearView.swift
//  Windfall
//
//  The Year page: every plant against the twelve months.
//
//  How to read it:
//    a small faint dot   nothing to do that month
//    a filled dot        the job can be done in that one month
//    a bar, round ends   the job can be done in each of those months in
//                        a row
//    a ring in a mark    it can be done now
//
//  The buttons along the top choose the job: sow indoors, sow outdoors,
//  plant out, harvest or flowering. "Every job" shows all of them at once
//  as five thin lines on each plant, like the back of a seed packet.
//
//  William's design, chosen on 12 November 2026 from four options: the
//  small dots of one, the bars of another, and the seed-packet view as a
//  switch.
//
//  Tapping a month's name at the top opens that month on a page of its
//  own, with what to sow, plant out and harvest in it. That page is in
//  YearMonthView.swift.
//
//  Where the columns are too narrow for "Jan", "Feb" and so on to be
//  written across, as on an iPad held upright, the names are turned on
//  their sides. See `monthHeading` and `OnItsSide`.
//
//  The sums (which months join into a bar) are in YearCalendar.swift.
//

import SwiftUI
import SwiftData

// MARK: - Colours

extension YearActivity {
    /// One colour for each job. The set was checked so that people who
    /// are colour-blind can tell the jobs apart.
    var colour: Color {
        switch self {
        case .sowIndoors:  return Theme.sowIndoors
        case .sowOutdoors: return Theme.sowOutdoors
        case .plantOut:    return Theme.plantOut
        case .harvest:     return Theme.harvest
        case .flowering:   return Theme.flowering
        }
    }
}

// MARK: - The page

struct YearView: View {

    @Query(sort: [SortDescriptor(\Plant.commonName)]) private var plants: [Plant]

    // Narrow (an iPhone) or wide (an iPad, a Mac).
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// The job being shown.
    @State private var activity: YearActivity = .sowOutdoors
    /// True when every job is shown at once. @AppStorage remembers the
    /// choice the next time the app opens.
    @AppStorage("yearShowsEveryJob") private var showsEveryJob = false
    /// Jobs switched off while every job is shown.
    @State private var hiddenJobs: Set<YearActivity> = []
    @AppStorage("yearArrangement") private var arrangementRaw = Arrangement.family.rawValue
    @State private var search = ""
    /// Fruit, vegetables, herbs and so on. Nil shows every kind. The
    /// same sorting as the Plants page uses (PlantFilter.swift).
    @State private var plantKind: PlantKind?
    /// The month whose own page is open, 1 to 12. Nil when none is.
    /// Tapping a month's name at the top sets it.
    @State private var openMonth: Int?

    /// The ways the plants can be put in order.
    enum Arrangement: String, CaseIterable, Identifiable {
        case family, start, name

        var id: String { rawValue }

        var title: String {
            switch self {
            case .family: return "By family"
            case .start: return "By when it starts"
            case .name: return "A to Z"
            }
        }
    }

    private var arrangement: Arrangement { Arrangement(rawValue: arrangementRaw) ?? .family }
    private var isNarrow: Bool { sizeClass == .compact }
    private var thisMonth: Int { Calendar.current.component(.month, from: .now) }

    // Measurements shared by the heading of months and every row, so the
    // columns always line up.
    private var sidePadding: CGFloat { isNarrow ? 16 : 24 }
    private var nameWidth: CGFloat { isNarrow ? 128 : 250 }
    private var rowHeight: CGFloat {
        if showsEveryJob { return isNarrow ? 58 : 54 }
        return isNarrow ? 46 : 36
    }

    /// The jobs to draw: all that are switched on, or just the chosen one.
    private var shownJobs: [YearActivity] {
        showsEveryJob ? YearActivity.allCases.filter { !hiddenJobs.contains($0) } : [activity]
    }

    // MARK: Working out the rows

    /// One line of the page for each plant that has something to show.
    private var rows: [YearRow] {
        let jobs = shownJobs
        let wanted = search.trimmingCharacters(in: .whitespaces).lowercased()
        return plants.compactMap { plant -> YearRow? in
            guard plant.status == .growing else { return nil }
            if let plantKind, PlantKind.of(group: plant.group) != plantKind { return nil }
            if !wanted.isEmpty,
               !plant.commonName.lowercased().contains(wanted),
               !(plant.variety ?? "").lowercased().contains(wanted) {
                return nil
            }
            var lanes: [YearLane] = []
            var earliest = 13
            for job in jobs {
                let months = job.months(for: plant)
                lanes.append(YearLane(activity: job, runs: YearCalendar.runs(in: months)))
                earliest = min(earliest, YearCalendar.opens(months))
            }
            // A plant with no months for any of these jobs is left out.
            guard lanes.contains(where: { !$0.runs.isEmpty }) else { return nil }
            return YearRow(plant: plant, lanes: lanes, opens: earliest)
        }
    }

    /// The rows in order, in one block or in a block for each family.
    private var blocks: [YearBlock] {
        let all = rows
        func byStart(_ list: [YearRow]) -> [YearRow] {
            list.sorted { a, b in
                if a.opens != b.opens { return a.opens < b.opens }
                return a.sortName < b.sortName
            }
        }
        switch arrangement {
        case .name:
            return [YearBlock(title: nil, rows: all.sorted { $0.sortName < $1.sortName })]
        case .start:
            return [YearBlock(title: nil, rows: byStart(all))]
        case .family:
            // Group by a tidied form of the family's name, so "Allium"
            // and "Alliums" are one group, then pick the name to show.
            let grouped = Dictionary(grouping: all) { YearCalendar.familyKey($0.family) }
            let made = grouped.values.map { members -> YearBlock in
                let shown = YearCalendar.familyTitle(from: members.map(\.family))
                return YearBlock(title: shown, rows: byStart(members))
            }
            // Alphabetical, with "Other" kept to the end.
            return made.sorted { a, b in
                let first = a.title ?? "", second = b.title ?? ""
                if (first == YearRow.noFamily) != (second == YearRow.noFamily) { return second == YearRow.noFamily }
                return first.lowercased() < second.lowercased()
            }
        }
    }

    // MARK: The screen

    var body: some View {
        let blocks = self.blocks
        let count = blocks.reduce(0) { $0 + $1.rows.count }

        VStack(spacing: 0) {
            jobButtons
            monthHeading(count: count)

            ScrollView {
                // "Lazy" means a row is only built when it is about to
                // scroll into view, which keeps a long list quick.
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(blocks) { block in
                        if let title = block.title {
                            familyHeading(title, count: block.rows.count)
                        }
                        ForEach(block.rows) { row in
                            NavigationLink {
                                PlantDetailView(plant: row.plant)
                            } label: {
                                rowView(row)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, sidePadding)
                .padding(.bottom, 24)
                // The soft band down this month's column, behind the rows.
                .background { monthBand }
            }
            .overlay {
                if count == 0 {
                    ContentUnavailableView {
                        Label("Nothing to show", systemImage: "calendar")
                    } description: {
                        Text(plantKind != nil
                             ? "Nothing of that kind has months recorded for these jobs. Choose \"Every kind\" to see the rest."
                             : (showsEveryJob
                                ? "No plants have months recorded for the jobs switched on."
                                : "No plants have \(activity.rawValue.lowercased()) months recorded."))
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Filter plants")
        .navigationTitle("Year")
        .paperScreen()
        // When `openMonth` is given a month, that month's page slides
        // in. Going back sets it to nil again. The page keeps to the
        // kind of plant chosen here.
        .navigationDestination(item: $openMonth) { month in
            YearMonthView(month: month, plantKind: plantKind)
        }
        // A checking aid: `-demoMonth 4` opens April's page at once, so
        // a still picture can be taken of it. See DemoGarden.opensMonth.
        .onAppear {
            if let month = DemoGarden.opensMonth, openMonth == nil { openMonth = month }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Arrange", selection: $arrangementRaw) {
                        ForEach(Arrangement.allCases) { way in
                            Text(way.title).tag(way.rawValue)
                        }
                    }
                } label: {
                    Label("Arrange", systemImage: "arrow.up.arrow.down")
                }
            }
        }
    }

    // MARK: The buttons along the top

    private var jobButtons: some View {
        // Sideways scrolling, so the buttons never have to squash to fit
        // an iPhone.
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    everyJobButton
                    ForEach(YearActivity.allCases) { job in
                        jobButton(job)
                    }
                    // A little apart, because it chooses plants and the
                    // rest choose jobs.
                    kindButton
                        .padding(.leading, 10)
                }
                .padding(.horizontal, sidePadding)
                .padding(.vertical, 8)
            }
        }
    }

    /// Chooses which kind of plant is listed: fruit, vegetables, herbs,
    /// flowers or green manure. A menu, like the filters on the Plants
    /// page. (Asked for by William on 13 November 2026.)
    private var kindButton: some View {
        Menu {
            // A Picker inside a Menu gives a list with a tick beside
            // the chosen one. `tag` says which value each line stands for.
            Picker("Kind of plant", selection: $plantKind) {
                Text("Every kind").tag(PlantKind?.none)
                ForEach(PlantKind.allCases) { kind in
                    Text(kind.rawValue).tag(PlantKind?.some(kind))
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 6) {
                Text(plantKind?.rawValue ?? "Fruit, veg\u{2026}")
                    .font(.body)
                    .fontWeight(plantKind == nil ? .regular : .semibold)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .contentShape(.capsule)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .glassEffect(.regular.tint((plantKind == nil ? Theme.card : Theme.leafFill).opacity(plantKind == nil ? 0.4 : 0.8)).interactive(),
                     in: .capsule)
        .accessibilityLabel("Kind of plant")
    }

    /// The switch between one job at a time and every job on one line.
    private var everyJobButton: some View {
        Button {
            withAnimation(.smooth(duration: 0.25)) { showsEveryJob.toggle() }
        } label: {
            HStack(spacing: 8) {
                // A tiny picture of three stacked lines.
                VStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule().frame(width: 14, height: 2.5)
                    }
                }
                Text("Every job")
                    .font(.body)
                    .fontWeight(showsEveryJob ? .semibold : .regular)
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint((showsEveryJob ? Theme.leafFill : Theme.card).opacity(showsEveryJob ? 0.8 : 0.4)).interactive(),
                     in: .capsule)
        .accessibilityLabel("Every job on one line")
        .accessibilityAddTraits(showsEveryJob ? .isSelected : [])
    }

    /// One job's button. With one job at a time it chooses that job. With
    /// every job showing it switches that job's line on and off.
    private func jobButton(_ job: YearActivity) -> some View {
        // "On" means this job's lines are being drawn: the one chosen
        // job, or, with every job showing, each job not switched off.
        // A button that is on is lit green with bolder words, in both
        // cases. (Until 13 November 2026 only the single chosen job was
        // lit. With "Every job" on, all five looked switched off while
        // their lines were showing, and William could not tell what was
        // active.)
        let isOn = showsEveryJob ? !hiddenJobs.contains(job) : job == activity
        return Button {
            withAnimation(.smooth(duration: 0.25)) {
                if showsEveryJob {
                    if hiddenJobs.contains(job) { hiddenJobs.remove(job) } else { hiddenJobs.insert(job) }
                } else {
                    activity = job
                }
            }
        } label: {
            HStack(spacing: 8) {
                YearKey(activity: job, asLine: showsEveryJob)
                Text(job.rawValue)
                    .font(.body)
                    .fontWeight(isOn ? .semibold : .regular)
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint((isOn ? Theme.leafFill : Theme.card).opacity(isOn ? 0.8 : 0.4)).interactive(),
                     in: .capsule)
        // A job that is switched off is also faded, so the difference
        // does not rest on colour alone.
        .opacity(isOn ? 1 : 0.55)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: The months

    private func monthHeading(count: Int) -> some View {
        // One letter on an iPhone, three letters everywhere else.
        let names = isNarrow ? Calendar.current.veryShortMonthSymbols : Calendar.current.shortMonthSymbols
        // `ViewThatFits` is handed two or more versions of a view, the
        // best first. It measures each and shows the first one that fits
        // the room it has. Here: the names written across where every
        // column is wide enough for them, and the names turned on their
        // sides where it is not, as on an iPad held upright with the
        // sidebar showing. `in: .horizontal` means only the width is
        // measured. (Until 15 November 2026 a name with too little room
        // was drawn as "…", which told nobody which month it was.)
        return ViewThatFits(in: .horizontal) {
            monthRow(count: count, names: names, turned: false)
            monthRow(count: count, names: names, turned: true)
        }
        .padding(.horizontal, sidePadding)
    }

    /// The heading written one way: the count of plants, then the twelve
    /// months, either across (`turned` false) or on their sides (true).
    private func monthRow(count: Int, names: [String], turned: Bool) -> some View {
        // `alignment: .bottom` keeps the count level with the foot of the
        // month names when the turned names make the heading taller.
        HStack(alignment: .bottom, spacing: 0) {
            Text(count == 1 ? "1 plant" : "\(count) plants")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
                .frame(width: nameWidth, alignment: .leading)
                .frame(height: isNarrow ? 40 : 32)

            ForEach(1...12, id: \.self) { month in
                // Each month's name is a button that opens the month's
                // own page. (Asked for by William on 14 November 2026.)
                YearMonthButton(name: names[month - 1],
                                allNames: names,
                                turned: turned,
                                fullName: Calendar.current.monthSymbols[month - 1],
                                isThisMonth: month == thisMonth,
                                height: isNarrow ? 40 : 32) {
                    openMonth = month
                }
            }
        }
    }

    /// The band behind the rows, one column wide.
    private var monthBand: some View {
        // GeometryReader reports how wide the list is, which is needed to
        // work out where this month's column falls.
        GeometryReader { geometry in
            let column = (geometry.size.width - sidePadding * 2 - nameWidth) / 12
            UnevenRoundedRectangle(bottomLeadingRadius: 12, bottomTrailingRadius: 12)
                .fill(Theme.leaf.opacity(0.10))
                .frame(width: max(column, 0))
                .offset(x: sidePadding + nameWidth + CGFloat(thisMonth - 1) * column)
        }
    }

    // MARK: The rows

    private func familyHeading(_ title: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title.uppercased())
                .font(.footnote.weight(.semibold))
                .kerning(0.8)
            Text(count == 1 ? "1 plant" : "\(count) plants")
                .font(.footnote)
        }
        .foregroundStyle(Theme.inkSoft)
        .padding(.top, 20)
        .padding(.bottom, 6)
        .accessibilityAddTraits(.isHeader)
    }

    private func rowView(_ row: YearRow) -> some View {
        HStack(spacing: 0) {
            nameCell(row.plant)
                .frame(width: nameWidth, alignment: .leading)

            YearMarks(lanes: row.lanes, everyJob: showsEveryJob, thisMonth: thisMonth)
                .frame(maxWidth: .infinity)
        }
        .frame(height: rowHeight)
        // A fine line above each row.
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.hairline.opacity(0.8))
                .frame(height: 1)
        }
        .contentShape(.rect)
        // The marks are a drawing, which VoiceOver cannot read. This says
        // the same thing in words.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(EiraSight.name(row.plant.commonName, variety: row.plant.variety))
        .accessibilityValue(row.spoken)
    }

    @ViewBuilder
    private func nameCell(_ plant: Plant) -> some View {
        let variety = (plant.variety ?? "").trimmingCharacters(in: .whitespaces)
        if isNarrow {
            // On an iPhone the variety goes underneath.
            VStack(alignment: .leading, spacing: 1) {
                Text(plant.commonName)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                if !variety.isEmpty {
                    Text(variety)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .lineLimit(1)
            .padding(.trailing, 8)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(plant.commonName)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                    .layoutPriority(1)
                if !variety.isEmpty {
                    Text(variety)
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .lineLimit(1)
            .padding(.trailing, 12)
        }
    }
}

// MARK: - A month's name at the top

/// One month's name in the heading. Tapping it opens the month's page.
///
/// It is a view of its own so that it can remember one thing by itself:
/// whether the pointer is over it. On a Mac, and on an iPad with a
/// trackpad, the name lights up under the pointer to show it can be
/// pressed.
struct YearMonthButton: View {

    /// The name as written: "Nov", or "N" on an iPhone.
    let name: String
    /// All twelve names as written. Only used for measuring: see `label`.
    let allNames: [String]
    /// True when the name is turned on its side, reading upwards, because
    /// the column is too narrow for it to be written across.
    let turned: Bool
    /// The whole name, for VoiceOver and the Mac's pop-up hint.
    let fullName: String
    let isThisMonth: Bool
    /// The least height the button may have.
    let height: CGFloat
    /// What to do when it is pressed. `() -> Void` means a piece of code
    /// that takes nothing and hands nothing back.
    let onPress: () -> Void

    @State private var isUnderPointer = false

    /// This month's name, and the name under the pointer, are bold.
    private var isStrong: Bool { isThisMonth || isUnderPointer }

    var body: some View {
        Button(action: onPress) {
            label
                .frame(maxWidth: .infinity)
                // A turned name sits at the foot of the heading, so all
                // twelve start on the same line just above the rows.
                .frame(minHeight: height, alignment: turned ? .bottom : .center)
                .background {
                    if isThisMonth {
                        // The top of the band that runs down the rows.
                        UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12)
                            .fill(Theme.leaf.opacity(isUnderPointer ? 0.22 : 0.10))
                    } else if isUnderPointer {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.leaf.opacity(0.14))
                    }
                }
                // The whole box takes the press, not only the letters.
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isUnderPointer = $0 }
        .help("See \(fullName)")
        .accessibilityLabel(fullName)
        .accessibilityHint("Shows what to sow, plant and harvest in \(fullName)")
    }

    /// The name, with the room the longest of the twelve names needs.
    ///
    /// A `ZStack` lays views one on top of another and is as large as the
    /// largest of them. All twelve names are in it, in bold and hidden
    /// (`.hidden()` keeps a view's room but does not draw it), with the
    /// one name that shows on top. So every column asks for the same
    /// room, the room the longest name needs even in bold. That is what
    /// lets `ViewThatFits` in the heading tell whether the names fit
    /// across, and it keeps all twelve the same height when turned.
    private var label: some View {
        ZStack(alignment: turned ? .bottom : .center) {
            ForEach(allNames.indices, id: \.self) { index in
                word(allNames[index], bold: true).hidden()
            }
            word(name, bold: isStrong)
                .foregroundStyle(isStrong ? Theme.ink : Theme.inkSoft)
        }
        // A little air: between names written across, and above and
        // below names on their sides.
        .padding(.horizontal, turned ? 0 : 2)
        .padding(.vertical, turned ? 6 : 0)
    }

    /// One name, written across or turned on its side.
    @ViewBuilder
    private func word(_ text: String, bold: Bool) -> some View {
        // `fixedSize()` gives the word the room it needs and no less, so
        // it is never cut short to "…".
        let written = Text(text)
            .font(.footnote)
            .fontWeight(bold ? .bold : .regular)
            .lineLimit(1)
            .fixedSize()
        if turned {
            // A quarter turn anticlockwise, so the word reads upwards,
            // the way the label on the side of a chart does.
            OnItsSide { written.rotationEffect(.degrees(-90)) }
        } else {
            written
        }
    }
}

// MARK: - Room for a turned view

/// Makes room for a view that has been given a quarter turn.
///
/// `rotationEffect` only changes how a view is drawn. SwiftUI still lays
/// the page out as though the view were lying flat, so a turned word
/// would keep a wide, short space and spill over its neighbours.
///
/// A `Layout` is SwiftUI's way of letting code decide sizes and places.
/// This one asks its view how large it is lying flat, reports that size
/// with the width and height swapped (the room the turned view really
/// covers) and puts the view in the middle of that room.
struct OnItsSide: Layout {

    /// How much room this layout asks for.
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let view = subviews.first else { return .zero }
        // `.unspecified` asks the view for the size it would like best.
        let flat = view.sizeThatFits(.unspecified)
        return CGSize(width: flat.height, height: flat.width)
    }

    /// Where the view goes inside the room this layout was given.
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let view = subviews.first else { return }
        view.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: .unspecified)
    }
}

// MARK: - What a row holds

/// One job's runs of months for one plant.
struct YearLane {
    let activity: YearActivity
    let runs: [MonthRun]
}

/// One plant's line on the page.
struct YearRow: Identifiable {
    static let noFamily = "Other"

    let plant: Plant
    let lanes: [YearLane]
    /// The earliest month any of the shown jobs opens.
    let opens: Int

    var id: UUID { plant.id }

    /// The plant's family, such as "Alliums", or "Other" when it has none.
    var family: String {
        let name = (plant.group ?? "").trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? Self.noFamily : name
    }

    /// Lower-case name and variety, for putting rows in A to Z order.
    var sortName: String {
        (plant.commonName + " " + (plant.variety ?? "")).lowercased()
    }

    /// The row in words: "Sow outdoors February to April".
    var spoken: String {
        lanes.filter { !$0.runs.isEmpty }
            .map { "\($0.activity.rawValue) \(YearCalendar.words(for: $0.runs))" }
            .joined(separator: ". ")
    }
}

/// A group of rows under one heading.
struct YearBlock: Identifiable {
    let title: String?
    let rows: [YearRow]

    var id: String { title ?? "all" }
}

// MARK: - The drawing

/// Draws one plant's months: the dots and the bars.
///
/// `Canvas` is SwiftUI's drawing board. With several hundred plants, one
/// drawing a row is far lighter than hundreds of small separate shapes.
struct YearMarks: View {

    let lanes: [YearLane]
    /// True when every job is drawn, each on a thin line of its own.
    let everyJob: Bool
    let thisMonth: Int

    var body: some View {
        Canvas { context, size in
            // The row is split into twelve equal columns.
            let column = size.width / 12
            let middle = size.height / 2

            if everyJob {
                // Five thin lines. Each job keeps its own height in the
                // row whether or not it is switched on, so a line's place
                // always means the same job.
                let thick: CGFloat = 6
                let gap: CGFloat = 3
                let jobs = YearActivity.allCases
                let total = CGFloat(jobs.count) * thick + CGFloat(jobs.count - 1) * gap
                for lane in lanes {
                    guard let place = jobs.firstIndex(of: lane.activity) else { continue }
                    let y = middle - total / 2 + CGFloat(place) * (thick + gap) + thick / 2
                    for run in lane.runs {
                        Self.paint(run, for: lane.activity, y: y, thick: thick,
                                   column: column, width: size.width, in: &context)
                    }
                }
            } else if let lane = lanes.first {
                let thick = min(14, column * 0.6)

                // A small faint dot for each month with nothing to do.
                for month in 1...12 where !lane.runs.contains(where: { $0.contains(month) }) {
                    let x = (CGFloat(month) - 0.5) * column
                    let dot = CGRect(x: x - 2, y: middle - 2, width: 4, height: 4)
                    context.fill(Path(ellipseIn: dot), with: .color(Theme.inkSoft.opacity(0.4)))
                }

                for run in lane.runs {
                    let shape = Self.shape(of: run, y: middle, thick: thick, column: column, width: size.width)
                    context.fill(shape, with: .color(lane.activity.colour))

                    // A ring inside the mark where it crosses this month:
                    // the job can be done now.
                    if run.contains(thisMonth) {
                        let x = (CGFloat(thisMonth) - 0.5) * column
                        let radius = thick / 2 - 3
                        let ring = CGRect(x: x - radius, y: middle - radius, width: radius * 2, height: radius * 2)
                        context.stroke(Path(ellipseIn: ring), with: .color(Theme.paper), lineWidth: 1.5)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// The outline of one run: a circle for a single month, and for
    /// longer runs a bar whose round ends sit on its first and last
    /// months. Where a window carries on round the end of the year, that
    /// end is cut square and runs to the edge.
    static func shape(of run: MonthRun, y: CGFloat, thick: CGFloat, column: CGFloat, width: CGFloat) -> Path {
        let radius = thick / 2
        let left = run.continuesBefore ? 0 : (CGFloat(run.first) - 0.5) * column - radius
        let right = run.continuesAfter ? width : (CGFloat(run.last) - 0.5) * column + radius
        let box = CGRect(x: left, y: y - radius, width: right - left, height: thick)
        let leftCorner = run.continuesBefore ? 0 : radius
        let rightCorner = run.continuesAfter ? 0 : radius
        return Path(roundedRect: box,
                    cornerRadii: RectangleCornerRadii(topLeading: leftCorner, bottomLeading: leftCorner,
                                                      bottomTrailing: rightCorner, topTrailing: rightCorner))
    }

    /// Paints one run on its thin line when every job is shown.
    ///
    /// Sowing indoors is an outline and flowering is a row of dots. The
    /// rest are solid. So the lines differ by shape as well as by colour,
    /// which matters for anyone who finds the colours hard to tell apart.
    static func paint(_ run: MonthRun, for activity: YearActivity, y: CGFloat, thick: CGFloat,
                      column: CGFloat, width: CGFloat, in context: inout GraphicsContext) {
        let ink = GraphicsContext.Shading.color(activity.colour)
        switch activity {
        case .sowIndoors:
            let outline = shape(of: run, y: y, thick: thick - 1.4, column: column, width: width)
            context.stroke(outline, with: ink, lineWidth: 1.4)
        case .flowering:
            let radius = thick / 2
            let left = run.continuesBefore ? 0 : (CGFloat(run.first) - 0.5) * column
            let right = run.continuesAfter ? width : (CGFloat(run.last) - 0.5) * column
            var line = Path()
            line.move(to: CGPoint(x: left, y: y))
            line.addLine(to: CGPoint(x: max(right, left + 0.01), y: y))
            // A dash of almost no length with a round end draws as a dot.
            context.stroke(line, with: ink,
                           style: StrokeStyle(lineWidth: radius * 2, lineCap: .round, dash: [0.01, thick * 1.7]))
        default:
            context.fill(shape(of: run, y: y, thick: thick, column: column, width: width), with: ink)
        }
    }
}

/// The small mark on each job's button, matching how the job is drawn.
struct YearKey: View {

    let activity: YearActivity
    /// True when every job is shown and the jobs are thin lines.
    let asLine: Bool

    var body: some View {
        if asLine {
            Canvas { context, size in
                // Borrow the page's own painting: a run of four months
                // on columns 6 wide is a line 24 long.
                YearMarks.paint(MonthRun(first: 1, last: 4), for: activity, y: size.height / 2,
                                thick: 6, column: 6, width: size.width, in: &context)
            }
            .frame(width: 24, height: 10)
        } else {
            Circle()
                .fill(activity.colour)
                .frame(width: 10, height: 10)
        }
    }
}
