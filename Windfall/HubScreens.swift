//
//  HubScreens.swift
//  Windfall
//
//  The Gardens, Wildlife and Settings pages, drawn in the same way as Today: a large
//  serif title, glass cards and tiles, and real numbers from the records,
//  in place of plain lists of links.
//
//  Moved here from MainTabView.swift on 12 November 2026, when they were
//  redrawn at William's request.
//
//  The Settings and tools page joined them on 14 November 2026, redrawn
//  in the same way.
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
                .font(.body)
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
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                if let detail {
                    Text(detail)
                        .font(.footnote)
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
            .font(.title3.weight(.semibold))
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
            .font(.body)
            .foregroundStyle(Theme.leaf)
        }
        .buttonStyle(.plain)
    }
}

/// How wide a page is, and so how it is laid out. The same widths as Today.
enum PageWidth {
    case narrow, middle, wide

    init(_ width: CGFloat) {
        self = width >= 840 ? .wide : (width >= 600 ? .middle : .narrow)
    }

    /// Room each side of the page, as on Today.
    var leading: CGFloat { self == .narrow ? 16 : 14 }
    var trailing: CGFloat { self == .narrow ? 16 : 24 }
}

/// A ready-made question for the database: the newest finished day of
/// weather, and only that one. It lives outside GardenTab because a
/// `@Query` cannot refer to the screen it sits in.
private enum WeatherFetch {
    static var newestFinishedDay: FetchDescriptor<WeatherDay> {
        var newest = FetchDescriptor<WeatherDay>(predicate: #Predicate { $0.isComplete },
                                                 sortBy: [SortDescriptor(\.dayKey, order: .reverse)])
        newest.fetchLimit = 1
        return newest
    }
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
    @Query private var crosses: [PlantCross]
    // Only the newest finished day is wanted, for one line on a tile, so
    // only that one record is fetched.
    @Query(WeatherFetch.newestFinishedDay) private var latestWeather: [WeatherDay]

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
                .font(.body)
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
                GlassSwitch(choices: activeGardens.map(\.siteKey), selection: Binding(
                    get: { shown.siteKey },
                    set: { shownGardenKey = $0 }
                )) { key in
                    activeGardens.first { $0.siteKey == key }?.name ?? key
                }
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
                GrowingLink { PlantLibraryView() } label: {
                    HubTile(icon: .drawn(.plants), title: "Plants", detail: plantsLine)
                }
                .hubTileGlass()

                GrowingLink { YearView() } label: {
                    HubTile(icon: .drawn(.year), title: "Year", detail: yearLine)
                }
                .hubTileGlass()

                GrowingLink { PlantingListView() } label: {
                    HubTile(icon: .drawn(.sowing), title: "Sowings",
                            detail: onTheGo == 0 ? "None on the go" : "\(onTheGo) on the go")
                }
                .hubTileGlass()

                GrowingLink { BedListView() } label: {
                    HubTile(icon: .symbol("square.grid.3x3"), title: "Beds",
                            detail: counted(beds.count, "bed"))
                }
                .hubTileGlass()

                GrowingLink { GardenMapView() } label: {
                    HubTile(icon: .drawn(.plans), title: "Garden map", detail: "Beds and features")
                }
                .hubTileGlass()

                GrowingLink { SeedListView() } label: {
                    HubTile(icon: .symbol("bag"), title: "Seed", detail: seedLine)
                }
                .hubTileGlass()

                // Crosses made between plants, written down on the day
                // so that next year's seedlings have their parents on
                // record. See Crosses.swift.
                GrowingLink { CrossListView() } label: {
                    HubTile(icon: .symbol("arrow.triangle.merge"), title: "Crosses",
                            detail: crosses.isEmpty ? "None recorded" : (crosses.count == 1 ? "1 cross" : "\(crosses.count) crosses"))
                }
                .hubTileGlass()

                GrowingLink { SeedPacketScanView() } label: {
                    HubTile(icon: .symbol("text.viewfinder"), title: "Scan a seed packet",
                            detail: "Read one with the camera")
                }
                .hubTileGlass()

                GrowingLink { WeatherDiaryView() } label: {
                    HubTile(icon: .drawn(.temperature), title: "Weather", detail: weatherLine)
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

    /// "Yesterday 2° to 7°, dry", from the weather diary.
    private var weatherLine: String {
        guard let day = latestWeather.first, let low = day.minTemperatureC, let high = day.maxTemperatureC else {
            return "Each day's weather and frosts"
        }
        let when = Calendar.current.isDateInYesterday(day.date) ? "Yesterday" : day.date.formatted(.dateTime.day().month(.abbreviated))
        let rain = (day.rainfallMM ?? 0) < 0.1 ? "dry" : "\((day.rainfallMM ?? 0).formatted(.number.precision(.fractionLength(1)))) mm rain"
        return "\(when) \(WeatherDiary.degrees(low)) to \(WeatherDiary.degrees(high)), \(rain)"
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
    /// Where records are saved and deleted. Used to delete a sighting
    /// swiped away in Latest sightings.
    @Environment(\.modelContext) private var context

    /// Narrow on an iPhone, which has no Identify place in its tabs, so
    /// the ways to identify are kept here as tiles. On a Mac or an iPad
    /// they are in Identify, in the sidebar (IdentifyViews.swift).
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var keepsIdentifyTiles: Bool { sizeClass == .compact }

    var body: some View {
        GeometryReader { geometry in
            let layout = PageWidth(geometry.size.width)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(title: "Wildlife", detail: summary)
                    tiles(columns: layout == .narrow ? 2 : (keepsIdentifyTiles ? 4 : 3))

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
                GrowingLink { ObservationListView() } label: {
                    HubTile(icon: .drawn(.sighting), title: "Sightings",
                            detail: "\(sightings.count) recorded")
                }
                .hubTileGlass()

                GrowingLink { SurveyListView() } label: {
                    HubTile(icon: .drawn(.fitCount), title: "Surveys",
                            detail: surveys.isEmpty ? "None yet" : counted(surveys.count, "count"))
                }
                .hubTileGlass()

                GrowingLink { FaunaListView() } label: {
                    // Says what is inside: William's own species and the
                    // UK guide. Until 15 November 2026 it read "21 in the
                    // reference", and William could not tell what it was.
                    HubTile(icon: .drawn(.butterfly), title: "Species",
                            detail: speciesTileWords)
                }
                .hubTileGlass()

                if keepsIdentifyTiles {
                    GrowingLink { IdentifyView() } label: {
                        HubTile(icon: .drawn(.photo), title: "Identify from a photo",
                                detail: "Ask what you have seen")
                    }
                    .hubTileGlass()

                    // The image model knows no fungi, so they have keys
                    // of their own to step through (IdentifyViews.swift).
                    GrowingLink { FungusKeyShelfView() } label: {
                        HubTile(icon: .drawn(.fungusKey), title: "Fungus keys",
                                detail: FungusKeys.inApp.count == 1 ? "Step to a group for a record" : "\(FungusKeys.inApp.count) keys to step through")
                    }
                    .hubTileGlass()
                }
            }
        }
    }

    /// The Species tile's second line: "Your 21, and 4,180 UK animals".
    private var speciesTileWords: String {
        let uk = WildlifeReference.shared.animals.count
        let yours = "Your \(species.count)"
        return uk > 0 ? "\(yours), and \(uk.formatted()) UK animals" : "\(yours) species"
    }

    // MARK: Latest sightings

    private var sightingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Latest sightings")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if sightings.count > 5 {
                    ViewAllLink { ObservationListView() }
                }
            }

            if sightings.isEmpty {
                Text("Nothing seen yet. Record a sighting from Today, or from Sightings above.")
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)
            }
            ForEach(sightings.prefix(5)) { sighting in
                NavigationLink {
                    ObservationEditor(observation: sighting)
                } label: {
                    sightingRow(sighting)
                }
                .buttonStyle(.plain)
                // Swipe left for Delete (SwipeToDelete.swift). Its photos
                // go with it (`deleteRule: .cascade` in WildlifeModels.swift).
                .swipeToDelete { context.delete(sighting) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func sightingRow(_ sighting: WildlifeObservation) -> some View {
        // The English name large, the Latin under it in italics
        // (`shownNames`, in WildlifeReference.swift).
        let names = sighting.shownNames(yourSpecies: species, ukGuide: .shared)
        // The same record shape Today uses, for its picture and its date.
        let record = RecentRecord(id: sighting.id, date: sighting.observedAt,
                                  icon: RecentRecord.picture(forSighting: names.oneLine, group: sighting.schemeGroupName),
                                  title: names.title, kind: "Sighting",
                                  detail: sighting.associatedPlantName.map { "On \($0)" }, sighting: sighting)
        return HStack(alignment: .top, spacing: 12) {
            WIconView(record.icon, size: 30)
                .foregroundStyle(Theme.leaf)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                if let latin = names.latinBeside {
                    // Latin names are written in italics by custom.
                    Text(latin)
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(Theme.inkSoft)
                }
                Text([record.dateText, record.detail].compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote)
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
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if surveys.count > 3 {
                    ViewAllLink { SurveyListView() }
                }
            }

            if surveys.isEmpty {
                Text("No counts yet. A FIT Count can be started from Today.")
                    .font(.body)
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
                                .font(.body.weight(.medium))
                                .foregroundStyle(Theme.ink)
                            Text("\(survey.startedAt.formatted(.dateTime.day().month(.wide).year())) · \(survey.totalCount) counted")
                                .font(.footnote)
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

// MARK: - Settings and tools

/// The Settings and tools page: tiles in three groups, each with a line
/// saying what is behind it, in place of a plain list of names.
///
/// Redrawn on 14 November 2026 at William's request ("Can you make this
/// settings page better?") to match Gardens and Wildlife, and moved here
/// from MainTabView.swift at the same time. The pages the tiles lead to
/// are unchanged.
///
/// It is still called `MoreTab`, its name from when the last tab on an
/// iPhone was "More", so that nothing else in the app has to change.
struct MoreTab: View {

    // These three are only counted, for the lines on two of the tiles.
    // `@Query` asks the database for every record of a kind and redraws
    // the page when one is added or removed.
    @Query private var documents: [KnowledgeDocument]
    @Query private var sightings: [WildlifeObservation]
    @Query private var surveys: [Survey]

    // `@AppStorage` reads one saved setting and redraws the page when it
    // changes. Both of these are set on the pages the tiles lead to, so
    // each tile can say how things stand without being opened.
    /// The name that goes on every record sent to iRecord.
    @AppStorage("recorderName") private var recorderName = ""
    /// Whether Eira reads her replies aloud.
    @AppStorage("eiraSpeaksReplies") private var speaksReplies = false

    /// Asks the system whether Windfall may send reminders.
    @State private var reminders = NotificationService()
    /// The system's answer. It is nil (nothing) until the answer has
    /// come back, so the tile never says "Off" and then changes its mind.
    @State private var remindersAreOn: Bool?

    /// A checking aid: `-startSection more -demoCorner YES` opens the
    /// corner drawing's preview at once, so a picture can be taken of it.
    @State private var showsCornerPreview = UserDefaults.standard.bool(forKey: "demoCorner")

    var body: some View {
        GeometryReader { geometry in
            let layout = PageWidth(geometry.size.width)
            // Two tiles across on an iPhone, four on anything wider, as
            // on Gardens and Wildlife.
            let columns = layout == .narrow ? 2 : 4
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(title: "Settings and tools",
                                 detail: "Set Windfall up, find things and look after your records")

                    HubSectionTitle("Set up")
                    tileGrid(columns) {
                        tile(.drawn(.settings), "Settings", settingsLine) { SettingsView() }
                        tile(.symbol("bell"), "Reminders", remindersLine) { NotificationSettingsView() }
                        tile(.drawn(.microphone), "Voice", voiceLine) { VoiceSettingsView() }
                        // Every month of the drawing in Today's corner,
                        // with the wind and the weather to try. See
                        // LivingCorner.swift.
                        tile(.drawn(.sprig), "Corner drawing", "Today's corner, month by month") { CornerPreviewView() }
                    }

                    HubSectionTitle("Find and look back")
                    tileGrid(columns) {
                        tile(.drawn(.search), "Search everything", "Plants, records and the journal") { UniversalSearchView() }
                        tile(.symbol("chart.xyaxis.line"), "Charts", "Harvests and pollinators by year") { ChartsView() }
                        tile(.symbol("books.vertical"), "Knowledge base", knowledgeLine) { KnowledgeBaseView() }
                    }

                    HubSectionTitle("Your records")
                    tileGrid(columns) {
                        tile(.symbol("externaldrive"), "Backup", "Everything but photos, in one file") { BackupView() }
                        tile(.symbol("square.and.arrow.up"), "Export records", exportLine) { ExportView() }
                    }
                }
                .padding(.leading, layout.leading)
                .padding(.trailing, layout.trailing)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .paperScreen()
        .navigationTitle("Settings and tools")
        #if os(iOS)
        // The big "Settings and tools" above is the title, as on Today.
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationDestination(isPresented: $showsCornerPreview) { CornerPreviewView() }
        // `.task` runs once the page is on screen. `await` waits for the
        // system's answer without freezing the page in the meantime.
        .task {
            await reminders.refreshStatus()
            remindersAreOn = reminders.isAuthorised
        }
    }

    // MARK: Tiles

    /// One group of tiles, laid out in a grid `columns` wide.
    ///
    /// `Tiles` in the angle brackets stands for "whatever views are
    /// handed in", and `@ViewBuilder` is what lets them be written as a
    /// plain list between the curly brackets, as above.
    private func tileGrid<Tiles: View>(_ columns: Int, @ViewBuilder tiles: () -> Tiles) -> some View {
        // The container lets tiles of glass that sit close together be
        // worked out as one piece, which is quicker to draw.
        GlassEffectContainer(spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns),
                      spacing: 10) {
                tiles()
            }
        }
    }

    /// One tile: its icon, its name, a line about it and the page it
    /// opens. On an iPhone or iPad the page grows out of the tile
    /// (`GrowingLink`, in GrowFromTile.swift).
    private func tile<Page: View>(_ icon: HubIcon, _ title: String, _ detail: String,
                                  @ViewBuilder page: () -> Page) -> some View {
        GrowingLink(destination: page) {
            HubTile(icon: icon, title: title, detail: detail)
        }
        .hubTileGlass()
    }

    // MARK: The line on each tile

    /// "Recording as William", or what the page holds if no name is set.
    private var settingsLine: String {
        // Spaces alone do not count as a name.
        let name = recorderName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Your name, photos and Eira's bar" : "Recording as \(name)"
    }

    /// "On · counts, sowing and frost".
    private var remindersLine: String {
        // Not known yet: say only what the reminders are for. `guard let`
        // unwraps the answer if there is one, and leaves early if not.
        guard let isOn = remindersAreOn else { return "Counts, sowing and frost" }
        return (isOn ? "On" : "Off") + " · counts, sowing and frost"
    }

    private var voiceLine: String {
        speaksReplies ? "Speak to Eira · replies read aloud" : "Speak to Eira · replies on screen"
    }

    /// "3 documents for Eira to search".
    private var knowledgeLine: String {
        documents.isEmpty ? "Add notes for Eira to search"
                          : "\(counted(documents.count, "document")) for Eira to search"
    }

    /// "4 records ready to send", counted by the same rule as the
    /// Export page uses (`ExportWaiting`, in ExportService.swift).
    private var exportLine: String {
        let waiting = ExportWaiting.altogether(sightings: sightings, surveys: surveys)
        return waiting == 0 ? "Nothing waiting to send" : "\(counted(waiting, "record")) ready to send"
    }
}

// MARK: - Plurals

/// "1 bed" and "3 beds". Every word these pages count makes its plural
/// with an "s", so this is all they need.
private func counted(_ count: Int, _ word: String) -> String {
    "\(count) \(word)\(count == 1 ? "" : "s")"
}
