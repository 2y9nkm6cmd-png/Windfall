//
//  HubScreens.swift
//  Windfall
//
//  The Gardens and Wildlife pages, drawn in the same way as Today: a large
//  serif title, glass cards and tiles, and real numbers from the records,
//  in place of plain lists of links.
//
//  Moved here from MainTabView.swift on 12 November 2026, when they were
//  redrawn at William's request.
//

import SwiftUI
import SwiftData

// MARK: - Shared pieces

/// The top of a page: a short line of facts above a large serif title,
/// as on Today.
struct ScreenHeader: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
            Text(title)
                .font(.screenTitle)
                .foregroundStyle(Theme.ink)
                // VoiceOver reads it as the page's heading.
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// An icon for a tile: one of the app's own drawings where there is one,
/// otherwise one of Apple's symbols until a drawing is made.
enum HubIcon {
    case drawn(WIcon)
    case symbol(String)
}

/// A square of glass with an icon, a name and a line of facts. Used for
/// the places a page leads to.
struct HubTile: View {
    let icon: HubIcon
    let title: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            iconView
                .foregroundStyle(Theme.leaf)
                .frame(width: 30, height: 30, alignment: .leading)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(14)
        .contentShape(.rect)
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .drawn(let drawing):
            WIconView(drawing, size: 28)
        case .symbol(let name):
            // Light weight, to sit closer to the fine line of the drawings.
            Image(systemName: name)
                .font(.system(size: 22, weight: .light))
                .accessibilityHidden(true)
        }
    }
}

extension View {
    /// The glass behind a tile, as on Today's capture buttons.
    func hubTileGlass() -> some View {
        self
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(Theme.card.opacity(0.5)).interactive(),
                         in: .rect(cornerRadius: 18))
    }
}

/// A small heading over a group of tiles or cards.
struct HubSectionTitle: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(Theme.ink)
            .padding(.top, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

/// "View all" with an arrow, leading to a full list.
struct ViewAllLink<Destination: View>: View {
    let destination: Destination

    init(@ViewBuilder destination: () -> Destination) {
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 3) {
                Text("View all")
                WIconView(.arrowRight, size: 13)
            }
            .font(.subheadline)
            .foregroundStyle(Theme.leaf)
        }
        .buttonStyle(.plain)
    }
}

/// How wide a page is, and so how it is laid out. The same widths as Today.
private enum PageWidth {
    case narrow, middle, wide

    init(_ width: CGFloat) {
        self = width >= 840 ? .wide : (width >= 600 ? .middle : .narrow)
    }

    /// Room each side of the page, as on Today.
    var leading: CGFloat { self == .narrow ? 16 : 14 }
    var trailing: CGFloat { self == .narrow ? 16 : 24 }
}

// MARK: - Gardens

/// The Gardens page: the garden plans first, then tiles for everything to
/// do with growing.
///
/// On an iPhone this is also the way to Year and Plants, which have no tab
/// of their own there.
struct GardenTab: View {

    @Query(sort: [SortDescriptor(\Garden.displayOrder)]) private var gardens: [Garden]
    // Beds that have been taken out of use are left off.
    @Query(filter: #Predicate<Bed> { $0.retiredAt == nil },
           sort: [SortDescriptor(\Bed.displayOrder)]) private var beds: [Bed]
    @Query private var features: [GardenFeature]
    @Query private var plants: [Plant]
    @Query private var plantings: [Planting]
    @Query private var seedPackets: [SeedPacket]

    /// Which garden's plan is shown on an iPhone, where there is room for
    /// one at a time. The same choice as on Today.
    @State private var shownGardenKey: String?

    private var activeGardens: [Garden] { gardens.filter(\.isActive) }
    private var month: Int { Calendar.current.component(.month, from: .now) }

    var body: some View {
        GeometryReader { geometry in
            let layout = PageWidth(geometry.size.width)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(title: "Gardens", detail: summary)
                    if layout == .narrow {
                        // On an iPhone this page is the way to Plants and
                        // Year, so their tiles come first.
                        tiles(columns: 2)
                        HubSectionTitle("Plans")
                        plans(layout)
                    } else {
                        plans(layout)
                        HubSectionTitle("In the garden")
                        tiles(columns: 4)
                    }
                }
                .padding(.leading, layout.leading)
                .padding(.trailing, layout.trailing)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .paperScreen()
        .navigationTitle("Gardens")
        #if os(iOS)
        // The big "Gardens" above is the title, as on Today.
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    // MARK: The line above the title

    /// "2 gardens · 14 beds · 6 sowings on the go".
    private var summary: String {
        var parts = [counted(activeGardens.count, "garden"), counted(beds.count, "bed")]
        if onTheGo > 0 { parts.append(counted(onTheGo, "sowing") + " on the go") }
        return parts.joined(separator: " · ")
    }

    /// Sowings that have started and not yet finished or failed.
    private var onTheGo: Int {
        plantings.filter { ![.planned, .finished, .failed].contains($0.status) }.count
    }

    // MARK: Plans

    /// One card per garden, drawn to scale. Side by side on a wide screen.
    @ViewBuilder
    private func plans(_ layout: PageWidth) -> some View {
        if activeGardens.isEmpty {
            Text("No gardens yet.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
        } else if layout == .wide {
            HStack(alignment: .top, spacing: 14) {
                ForEach(activeGardens) { planCard(for: $0) }
            }
        } else if layout == .narrow {
            // One at a time, with a switch between them, as on Today.
            let shown = activeGardens.first { $0.siteKey == shownGardenKey } ?? activeGardens[0]
            if activeGardens.count > 1 {
                Picker("Garden", selection: Binding(
                    get: { shown.siteKey },
                    set: { shownGardenKey = $0 }
                )) {
                    ForEach(activeGardens) { Text($0.name).tag($0.siteKey) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            planCard(for: shown)
        } else {
            ForEach(activeGardens) { planCard(for: $0) }
        }
    }

    private func planCard(for garden: Garden) -> some View {
        GardenPlanCard(garden: garden,
                       beds: beds.filter { $0.siteRaw == garden.siteKey },
                       features: features.filter { $0.siteRaw == garden.siteKey })
    }

    // MARK: Tiles

    private func tiles(columns: Int) -> some View {
        GlassEffectContainer(spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns),
                      spacing: 10) {
                NavigationLink { PlantLibraryView() } label: {
                    HubTile(icon: .drawn(.plants), title: "Plants", detail: plantsLine)
                }
                .hubTileGlass()

                NavigationLink { YearView() } label: {
                    HubTile(icon: .drawn(.year), title: "Year", detail: yearLine)
                }
                .hubTileGlass()

                NavigationLink { PlantingListView() } label: {
                    HubTile(icon: .drawn(.sowing), title: "Sowings",
                            detail: onTheGo == 0 ? "None on the go" : "\(onTheGo) on the go")
                }
                .hubTileGlass()

                NavigationLink { BedListView() } label: {
                    HubTile(icon: .symbol("square.grid.3x3"), title: "Beds",
                            detail: counted(beds.count, "bed"))
                }
                .hubTileGlass()

                NavigationLink { GardenMapView() } label: {
                    HubTile(icon: .drawn(.plans), title: "Garden map", detail: "Beds and features")
                }
                .hubTileGlass()

                NavigationLink { SeedListView() } label: {
                    HubTile(icon: .symbol("bag"), title: "Seed", detail: seedLine)
                }
                .hubTileGlass()

                NavigationLink { SeedPacketScanView() } label: {
                    HubTile(icon: .symbol("text.viewfinder"), title: "Scan a seed packet",
                            detail: "Read one with the camera")
                }
                .hubTileGlass()

                NavigationLink { FrostRecordsView() } label: {
                    HubTile(icon: .drawn(.temperature), title: "Frost and weather",
                            detail: "Frost dates and records")
                }
                .hubTileGlass()
            }
        }
    }

    /// "335 growing · 40 to buy".
    private var plantsLine: String {
        let growing = plants.filter { $0.status == .growing }.count
        let wanted = plants.filter { $0.status == .wanted }.count
        return wanted > 0 ? "\(growing) growing · \(wanted) to buy" : "\(growing) growing"
    }

    /// "12 to sow this month", read from the plants' sowing months.
    private var yearLine: String {
        let sowable = plants.filter { plant in
            plant.status == .growing && PlantSeason.sowing.months(for: plant).contains(month)
        }.count
        return sowable == 0 ? "Nothing to sow this month" : "\(sowable) to sow this month"
    }

    /// "8 packets · 2 past their date".
    private var seedLine: String {
        guard !seedPackets.isEmpty else { return "No packets yet" }
        let expired = seedPackets.filter(\.isExpired).count
        let packets = counted(seedPackets.count, "packet")
        return expired > 0 ? "\(packets) · \(expired) past their date" : packets
    }
}

// MARK: - Wildlife

/// The Wildlife page: tiles for sightings, surveys, the species list and
/// identifying from a photo, then the latest sightings and surveys.
struct WildlifeTab: View {

    @Query(sort: [SortDescriptor(\WildlifeObservation.observedAt, order: .reverse)])
    private var sightings: [WildlifeObservation]
    @Query(sort: [SortDescriptor(\Survey.startedAt, order: .reverse)])
    private var surveys: [Survey]
    @Query private var species: [Fauna]

    var body: some View {
        GeometryReader { geometry in
            let layout = PageWidth(geometry.size.width)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(title: "Wildlife", detail: summary)
                    tiles(columns: layout == .narrow ? 2 : 4)

                    if layout == .narrow {
                        sightingsCard
                        surveysCard
                    } else {
                        HStack(alignment: .top, spacing: 14) {
                            sightingsCard
                            surveysCard
                        }
                    }
                }
                .padding(.leading, layout.leading)
                .padding(.trailing, layout.trailing)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .paperScreen()
        .navigationTitle("Wildlife")
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    // MARK: The line above the title

    private var thisYear: Int { Calendar.current.component(.year, from: .now) }

    private func isThisYear(_ date: Date) -> Bool {
        Calendar.current.component(.year, from: date) == thisYear
    }

    /// "14 sightings and 3 surveys this year · 2 to confirm".
    private var summary: String {
        let seen = sightings.filter { isThisYear($0.observedAt) }.count
        let surveyed = surveys.filter { isThisYear($0.startedAt) }.count
        var line = "\(counted(seen, "sighting")) and \(counted(surveyed, "survey")) this year"
        let waiting = sightings.filter { !$0.isConfirmed }.count
        if waiting > 0 { line += " · \(waiting) to confirm" }
        return line
    }

    // MARK: Tiles

    private func tiles(columns: Int) -> some View {
        GlassEffectContainer(spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns),
                      spacing: 10) {
                NavigationLink { ObservationListView() } label: {
                    HubTile(icon: .drawn(.sighting), title: "Sightings",
                            detail: "\(sightings.count) recorded")
                }
                .hubTileGlass()

                NavigationLink { SurveyListView() } label: {
                    HubTile(icon: .drawn(.fitCount), title: "Surveys",
                            detail: surveys.isEmpty ? "None yet" : counted(surveys.count, "count"))
                }
                .hubTileGlass()

                NavigationLink { FaunaListView() } label: {
                    HubTile(icon: .drawn(.butterfly), title: "Species",
                            detail: "\(species.count) in the reference")
                }
                .hubTileGlass()

                NavigationLink { IdentifyView() } label: {
                    HubTile(icon: .drawn(.photo), title: "Identify from a photo",
                            detail: "Ask what you have seen")
                }
                .hubTileGlass()
            }
        }
    }

    // MARK: Latest sightings

    private var sightingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Latest sightings")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                if sightings.count > 5 {
                    ViewAllLink { ObservationListView() }
                }
            }

            if sightings.isEmpty {
                Text("Nothing seen yet. Record a sighting from Today, or from Sightings above.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
            ForEach(sightings.prefix(5)) { sighting in
                NavigationLink {
                    ObservationEditor(observation: sighting)
                } label: {
                    sightingRow(sighting)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func sightingRow(_ sighting: WildlifeObservation) -> some View {
        let name = sighting.bestAvailableName ?? "Unidentified sighting"
        // The same record shape Today uses, for its picture and its date.
        let record = RecentRecord(id: sighting.id, date: sighting.observedAt,
                                  icon: RecentRecord.picture(forSighting: name, group: sighting.schemeGroupName),
                                  title: name, kind: "Sighting",
                                  detail: sighting.associatedPlantName.map { "On \($0)" }, sighting: sighting)
        return HStack(alignment: .top, spacing: 12) {
            WIconView(record.icon, size: 30)
                .foregroundStyle(Theme.leaf)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                Text([record.dateText, record.detail].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 8)
            if sighting.isConfirmed {
                StatusTag(text: "Confirmed", fill: Theme.leafFill)
            } else {
                StatusTag(text: "Provisional", fill: Theme.amber)
            }
        }
        .contentShape(.rect)
    }

    // MARK: Latest surveys

    private var surveysCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Latest surveys")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                if surveys.count > 3 {
                    ViewAllLink { SurveyListView() }
                }
            }

            if surveys.isEmpty {
                Text("No counts yet. A FIT Count can be started from Today.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
            ForEach(surveys.prefix(3)) { survey in
                NavigationLink {
                    SurveyDetailView(survey: survey)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        WIconView(.fitCount, size: 30)
                            .foregroundStyle(Theme.leaf)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(survey.scheme.displayName)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.ink)
                            Text("\(survey.startedAt.formatted(.dateTime.day().month(.wide).year())) · \(survey.totalCount) counted")
                                .font(.caption)
                                .foregroundStyle(Theme.inkSoft)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

// MARK: - Plurals

/// "1 bed" and "3 beds". Every word these pages count makes its plural
/// with an "s", so this is all they need.
private func counted(_ count: Int, _ word: String) -> String {
    "\(count) \(word)\(count == 1 ? "" : "s")"
}
