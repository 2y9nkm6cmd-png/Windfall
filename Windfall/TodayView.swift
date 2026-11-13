//
//  TodayView.swift
//  Windfall
//
//  The first screen: what the day and the garden look like right now.
//
//  Top to bottom:
//    the date and "Today"
//    a conditions card, with a button to start a count when one suits
//    six capture buttons
//    this month's jobs, the garden plans and the latest records
//
//  Almost everything here is worked out from your records each time the
//  screen is drawn. What is sowable comes from the plant library's month
//  text. Harvests due come from sowing dates. Nothing needs keeping up to
//  date by hand.
//
//  The layout changes with the room available: three columns on a Mac or
//  a wide iPad, two on a narrower iPad and one on an iPhone.
//
//  The cards can be rearranged. Press and hold one and they all start to
//  wiggle. Drag a card onto another to take its place, or use the two
//  arrows on each card. "Done" stops it. Which card goes where is kept
//  in TodayLayout.swift, and the pieces that do the wiggling and the
//  dragging are at the foot of this file.
//

import SwiftUI
import SwiftData
import CoreLocation
import UniformTypeIdentifiers

struct TodayView: View {

    @Environment(\.modelContext) private var context
    @Environment(LocationManager.self) private var locationManager

    // Each @Query keeps a live list of one kind of record. When a record
    // is added or changed, the screen redraws by itself.
    @Query(sort: [SortDescriptor(\Plant.commonName)]) private var plants: [Plant]
    @Query private var plantings: [Planting]
    @Query private var harvests: [Harvest]
    @Query private var surveys: [Survey]
    @Query private var sightings: [WildlifeObservation]
    @Query private var diary: [DiaryEntry]
    @Query private var seedPackets: [SeedPacket]
    @Query(filter: #Predicate<Bed> { $0.retiredAt == nil },
           sort: [SortDescriptor(\Bed.displayOrder)]) private var beds: [Bed]
    @Query(sort: [SortDescriptor(\Garden.displayOrder)]) private var gardens: [Garden]
    @Query private var features: [GardenFeature]
    /// The newest finished days of the weather diary, for "This week".
    @Query(TodayFetch.latestWeather) private var finishedWeather: [WeatherDay]

    /// The one weather service the whole app shares. Today is rebuilt
    /// each time it is returned to, and with a service of its own it lost
    /// the weather and fetched it again every time.
    private var weather: WeatherService { .shared }
    /// Where the weather was last asked about, used to tell day from night.
    @State private var weatherPlace: CLLocationCoordinate2D?
    @State private var sheet: CaptureSheet?
    @State private var shownGardenKey: String?

    /// Jobs ticked off this month, kept on the device.
    @AppStorage("todayTickedJobs") private var tickedStore = ""

    /// Where the cards have been put, at each of the three widths, as a
    /// line of saved text. Empty means the standard arrangement. See
    /// TodayLayout.swift.
    @AppStorage("todayArrangementWide") private var wideStore = ""
    @AppStorage("todayArrangementMiddle") private var middleStore = ""
    @AppStorage("todayArrangementNarrow") private var narrowStore = ""

    /// True while the cards are wiggling and can be moved. Starting the
    /// app with `-todayArranging YES` begins that way, as a checking aid.
    @State private var isArranging = UserDefaults.standard.bool(forKey: "todayArranging")
    /// The card being dragged, if one is.
    @State private var dragging: TodayPanel?
    /// What the dragged card is being held over.
    @State private var dropTarget: TodayDropTarget?

    private var month: Int { Calendar.current.component(.month, from: .now) }
    private var activeGardens: [Garden] { gardens.filter(\.isActive) }

    // MARK: Body

    var body: some View {
        GeometryReader { geometry in
            // Gathered once for the whole redraw: how wide the page is,
            // where each card has been put and whether there is a
            // journal offer to show.
            let canvas = TodayCanvas(
                width: geometry.size.width,
                arrangement: savedArrangement(columns: TodayArrangement.columns(forWidth: geometry.size.width)),
                journalIsOffered: journalIsOffered,
                isArranging: isArranging,
                week: weekJobs)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if canvas.columns == 1 {
                        // One list, for an iPhone.
                        zoneCards(0, on: canvas)
                    } else {
                        // A full-width stack, then the columns, then
                        // another full-width stack, empty to begin with.
                        zoneCards(0, on: canvas)
                        columnsRow(on: canvas)
                        if let bottom = canvas.arrangement.bottomZone {
                            zoneCards(bottom, on: canvas)
                        }
                    }

                    if !isArranging {
                        rearrangeButton
                    }
                }
                .padding(.leading, canvas.width >= 600 ? 14 : 16)
                .padding(.trailing, canvas.width >= 600 ? 24 : 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            // A card let go of where nothing can take it: forget the drag.
            .onDrop(of: [.text], isTargeted: nil) { _ in
                dragging = nil
                dropTarget = nil
                return false
            }
            // The bar takes room of its own at the top while rearranging,
            // so it sits above the page's heading and not over it.
            .safeAreaInset(edge: .top, spacing: 0) {
                if isArranging {
                    arrangingBar(columns: canvas.columns)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 6)
                }
            }
        }
        .paperScreen()
        .navigationTitle("Today")
        #if os(iOS)
        // The big "Today" above is the title, so Apple's own bar is hidden.
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationDestination(for: Plant.self) { PlantDetailView(plant: $0) }
        .navigationDestination(for: Planting.self) { PlantingDetailView(planting: $0) }
        .sheet(item: $sheet) { sheet in
            captureForm(for: sheet)
        }
        .task {
            openForChecking()
            await refreshWeather(mayAskForLocation: false)
        }
    }

    /// A checking aid: opens one sheet as soon as Today appears. See
    /// `DemoGarden.opens`.
    private func openForChecking() {
        switch DemoGarden.opens {
        case "sowing": sheet = .sowing
        case "harvest": sheet = .harvest
        case "worms": startSurvey(.earthwormCount)
        case "fit": startSurvey(.fitCount)
        case "sighting": startSighting()
        case "journal": startNote(draft: UserDefaults.standard.string(forKey: "demoDraft") ?? "")
        default: break
        }
    }

    // MARK: Laying out the cards

    /// The cards of one full-width zone, one under another. While
    /// rearranging, a space to drop into follows them.
    @ViewBuilder
    private func zoneCards(_ zone: Int, on canvas: TodayCanvas) -> some View {
        ForEach(canvas.arrangement.zones[zone].filter(canvas.isShowing)) { panel in
            card(panel, on: canvas, room: .page)
        }
        if isArranging {
            dropSpace(zone, on: canvas)
        }
    }

    /// The columns, side by side. A column with nothing in it is left out
    /// and its neighbours take the room, except while rearranging, when
    /// it is drawn so a card can be dropped into it.
    @ViewBuilder
    private func columnsRow(on canvas: TodayCanvas) -> some View {
        let shown = canvas.arrangement.shownColumns(includingEmpty: isArranging, isShowing: canvas.isShowing)
        let roomy = canvas.arrangement.roomyColumns(isShowing: canvas.isShowing)
        if !shown.isEmpty {
            HStack(alignment: .top, spacing: 14) {
                ForEach(shown, id: \.self) { zone in
                    // With three columns, any that hold a garden plan
                    // share whatever is left and the others get a set
                    // share. Otherwise the columns share equally.
                    let isBesidePlans = canvas.columns == 3 && shown.count > 1 && !roomy.isEmpty && !roomy.contains(zone)
                    let setWidth: CGFloat? = isBesidePlans ? canvas.width * (shown.count == 3 ? 0.265 : 0.32) : nil
                    VStack(spacing: 14) {
                        ForEach(canvas.arrangement.zones[zone].filter(canvas.isShowing)) { panel in
                            card(panel, on: canvas, room: isBesidePlans ? .sideColumn : .wideColumn)
                        }
                        if isArranging {
                            dropSpace(zone, on: canvas)
                        }
                    }
                    .frame(minWidth: setWidth, maxWidth: setWidth ?? .infinity)
                }
            }
        }
    }

    /// One card, with everything that lets it be rearranged wrapped
    /// around it.
    private func card(_ panel: TodayPanel, on canvas: TodayCanvas, room: PanelRoom) -> some View {
        panelContent(panel, on: canvas, room: room)
            // While rearranging, the buttons inside a card are switched
            // off, so a press moves the card and does not press them.
            .allowsHitTesting(!isArranging)
            .opacity(dragging == panel ? 0.4 : 1)
            .overlay {
                if isArranging {
                    arrangeControls(for: panel, on: canvas)
                }
            }
            // An outline on the card a dragged one is being held over.
            .overlay {
                if dropTarget == .panel(panel), dragging != panel {
                    RoundedRectangle(cornerRadius: Theme.cardRadius)
                        .strokeBorder(Theme.leaf, lineWidth: 2.5)
                }
            }
            .modifier(Wiggle(isOn: isArranging,
                             leansLeft: canvas.arrangement.readingOrder.firstIndex(of: panel).map { $0 % 2 == 0 } ?? false))
            .modifier(LiftToArrange(panel: panel, title: title(of: panel), isArranging: isArranging) { isLifted in
                beginArranging(lifting: isLifted ? panel : nil)
            })
            .onDrop(of: [.text], isTargeted: isTargeted(.panel(panel))) { _ in
                drop(onto: panel, columns: canvas.columns)
            }
    }

    /// What goes inside each card. Some are drawn differently when they
    /// have less room.
    @ViewBuilder
    private func panelContent(_ panel: TodayPanel, on canvas: TodayCanvas, room: PanelRoom) -> some View {
        switch panel {
        case .conditions:
            conditionsCard(stacked: room != .page || canvas.width < 600)
        case .capture:
            captureButtons(columns: room == .page ? (canvas.width >= 700 ? 6 : 3)
                                                  : (room == .wideColumn ? 3 : 2))
        case .week:
            weekCard(canvas.week)
        case .jobs:
            // A job already in "This week" is not listed twice.
            jobsCard(leavingOut: Set(canvas.week.map(\.id)))
        case .plans:
            // A wide screen has room for every garden. Others show one,
            // with a switch between them.
            VStack(spacing: 14) { gardenCards(oneAtATime: canvas.columns < 3) }
        case .recent:
            recentCard
        case .journal:
            if canvas.journalIsOffered {
                journalOffer
            } else {
                journalPlaceholder
            }
        default:
            // One garden's plan, as a card of its own. Each can be moved
            // separately (William, 13 November 2026).
            if let key = panel.gardenKey, let garden = activeGardens.first(where: { $0.siteKey == key }) {
                planCard(for: garden)
            }
        }
    }

    /// A card's name, for the label that follows a drag and for
    /// VoiceOver. A garden's plan is called by the garden's name.
    private func title(of panel: TodayPanel) -> String {
        if let key = panel.gardenKey, let garden = activeGardens.first(where: { $0.siteKey == key }) {
            return garden.name.isEmpty ? panel.title : "\(garden.name) plan"
        }
        return panel.title
    }

    // MARK: Rearranging

    /// The arrangement for a page with this many columns, read from its
    /// saved text.
    private func savedArrangement(columns: Int) -> TodayArrangement {
        switch columns {
        case 3: return TodayArrangement(columns: 3, stored: wideStore, gardens: gardenKeys)
        case 2: return TodayArrangement(columns: 2, stored: middleStore, gardens: gardenKeys)
        default: return TodayArrangement(columns: 1, stored: narrowStore, gardens: gardenKeys)
        }
    }

    /// The gardens' keys, in order. On a wide screen each garden's plan
    /// is a card of its own, so the arrangement has to know them.
    private var gardenKeys: [String] { activeGardens.map(\.siteKey) }

    private func save(_ arrangement: TodayArrangement) {
        // The standard arrangement is saved as nothing at all. If a later
        // version of the app changes its standard, anyone who never moved
        // a card gets the new one.
        let text = arrangement.isStandard(gardens: gardenKeys) ? "" : arrangement.stored
        switch arrangement.columns {
        case 3: wideStore = text
        case 2: middleStore = text
        default: narrowStore = text
        }
    }

    /// Starts the wiggling. `panel` is the card that was lifted to begin
    /// it, if one was.
    private func beginArranging(lifting panel: TodayPanel?) {
        if let panel { dragging = panel }
        if !isArranging { isArranging = true }
    }

    private func finishArranging() {
        dragging = nil
        dropTarget = nil
        isArranging = false
    }

    /// Lets a card or a drop space say "a dragged card is over me". A
    /// Binding is a value that can be both read and set from elsewhere.
    private func isTargeted(_ target: TodayDropTarget) -> Binding<Bool> {
        Binding(
            get: { dropTarget == target },
            set: { isOver in
                if isOver {
                    if dragging != nil { dropTarget = target }
                } else if dropTarget == target {
                    dropTarget = nil
                }
            })
    }

    /// A card was let go over another card. Returns true if it was moved.
    private func drop(onto target: TodayPanel, columns: Int) -> Bool {
        guard let moving = dragging else { return false }
        dragging = nil
        dropTarget = nil
        var changed = savedArrangement(columns: columns)
        changed.move(moving, onto: target)
        withAnimation(.snappy(duration: 0.3)) { save(changed) }
        return true
    }

    /// A card was let go over the space at the foot of a zone.
    private func drop(atEndOf zone: Int, columns: Int) -> Bool {
        guard let moving = dragging else { return false }
        dragging = nil
        dropTarget = nil
        var changed = savedArrangement(columns: columns)
        changed.move(moving, toEndOf: zone)
        withAnimation(.snappy(duration: 0.3)) { save(changed) }
        return true
    }

    /// What sits on top of a card while rearranging: a surface to drag it
    /// by, and two arrows for moving it without dragging.
    private func arrangeControls(for panel: TodayPanel, on canvas: TodayCanvas) -> some View {
        ZStack(alignment: .topTrailing) {
            DragSurface(panel: panel, title: title(of: panel)) { dragging = panel }
            // The arrows sit astride the card's top edge, half on and
            // half off, like the badge on a jiggling Home Screen icon.
            // Inside the corner they covered the compass on a garden's
            // plan (William's picture, 13 November 2026).
            HStack(spacing: 6) {
                moveButton(panel, by: -1, on: canvas)
                moveButton(panel, by: 1, on: canvas)
            }
            .padding(.trailing, 12)
            .offset(y: -18)
        }
    }

    /// An arrow that moves a card one place earlier (-1) or later (+1).
    private func moveButton(_ panel: TodayPanel, by step: Int, on canvas: TodayCanvas) -> some View {
        let canMove = canvas.arrangement.canNudge(panel, by: step)
        return Button {
            var changed = canvas.arrangement
            changed.nudge(panel, by: step)
            withAnimation(.snappy(duration: 0.3)) { save(changed) }
        } label: {
            Image(systemName: step < 0 ? "arrow.up" : "arrow.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 32, height: 32)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Theme.card.opacity(0.6)).interactive(), in: .circle)
        .disabled(!canMove)
        .opacity(canMove ? 1 : 0.35)
        .accessibilityLabel("Move \(title(of: panel)) \(step < 0 ? "earlier" : "later")")
    }

    /// A space at the foot of a zone that a card can be dropped into. It
    /// is only there while rearranging, and is how a card reaches an
    /// empty column.
    private func dropSpace(_ zone: Int, on canvas: TodayCanvas) -> some View {
        let isOver = dropTarget == .endOfZone(zone)
        let words = canvas.columns == 1 ? "Drop here for the end"
            : (canvas.arrangement.columnZones.contains(zone) ? "Drop here" : "Drop here for full width")
        return Text(words)
            .font(.caption)
            .foregroundStyle(Theme.inkSoft)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isOver ? Theme.leaf : Theme.inkSoft.opacity(0.5),
                                  style: StrokeStyle(lineWidth: isOver ? 2.5 : 1, dash: [6, 5]))
            }
            .contentShape(.rect)
            .onDrop(of: [.text], isTargeted: isTargeted(.endOfZone(zone))) { _ in
                drop(atEndOf: zone, columns: canvas.columns)
            }
    }

    /// The bar across the top while rearranging.
    private func arrangingBar(columns: Int) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Rearranging Today")
                    .font(.subheadline.weight(.semibold))
                Text("Drag a card onto another, or use its arrows.")
                    .font(.caption)
            }
            .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            Button("Reset") {
                withAnimation(.snappy(duration: 0.3)) { save(.standard(columns: columns, gardens: gardenKeys)) }
            }
            .buttonStyle(QuietGlassButton())
            Button("Done") { finishArranging() }
                .buttonStyle(.glassProminent)
                .tint(Theme.leaf)
                .foregroundStyle(Theme.onLeaf)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 520)
        .glassEffect(.regular.tint(Theme.card.opacity(0.7)), in: .rect(cornerRadius: 20))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// A quiet button at the foot of the page. Pressing and holding a
    /// card does the same, but a button can be found by anyone, and by
    /// VoiceOver.
    private var rearrangeButton: some View {
        Button("Rearrange this page") { beginArranging(lifting: nil) }
            .font(.subheadline)
            .foregroundStyle(Theme.leaf)
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide).year())
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                Text("Today")
                    .font(.screenTitle)
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            BotanicalCorner()
                .frame(width: 150, height: 96)
                .padding(.top, -6)
        }
    }

    // MARK: Conditions

    private var isFITSeason: Bool { (4...9).contains(month) }
    private var isWormSeason: Bool { [3, 4, 5, 9, 10, 11].contains(month) }

    private var daysSinceLastFITCount: Int? {
        let latest = surveys.filter { $0.scheme == .fitCount }.map(\.startedAt).max()
        return latest.flatMap { Calendar.current.dateComponents([.day], from: $0, to: .now).day }
    }

    /// True when the sun is below the horizon where the weather was
    /// asked about. Worked out with the same sums as the garden's shade.
    private var isNight: Bool {
        guard let place = weatherPlace else { return false }
        return Sun.position(latitude: place.latitude, longitude: place.longitude, at: .now).altitude < 0
    }

    /// "sunny" by day and "clear" by night, for the same empty sky.
    private func skyWords(_ conditions: CurrentConditions) -> String {
        if conditions.skyCondition == .sunny && isNight { return "clear" }
        return conditions.skyCondition.displayName.lowercased()
    }

    /// On a narrow screen the button drops below the words, so neither
    /// is squeezed.
    @ViewBuilder
    private func conditionsCard(stacked: Bool) -> some View {
        let words = HStack(spacing: 14) {
            weatherIcon
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(conditionsHeadline)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text(conditionsDetail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        if stacked {
            VStack(alignment: .leading, spacing: 12) {
                words
                conditionsButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        } else {
            HStack(spacing: 14) {
                words
                Spacer(minLength: 8)
                conditionsButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
    }

    @ViewBuilder
    private var weatherIcon: some View {
        if let now = weather.current {
            if !now.isDry {
                WIconView(.rain, size: 38).foregroundStyle(Theme.leaf)
            } else if now.isWindy {
                WIconView(.windy, size: 38).foregroundStyle(Theme.leaf)
            } else {
                switch now.skyCondition {
                case .sunny where isNight: WIconView(.clearNight, size: 38).foregroundStyle(Theme.leaf)
                case .sunny: WIconView(.sunny, size: 38)
                case .partlyCloudy: WIconView(.partlyCloudy, size: 38)
                case .cloudy: WIconView(.cloudy, size: 38).foregroundStyle(Theme.leaf)
                }
            }
        } else {
            WIconView(.partlyCloudy, size: 38).opacity(0.5)
        }
    }

    private var conditionsHeadline: String {
        guard let now = weather.current else {
            return weather.isLoading ? "Checking conditions…" : "Conditions not checked yet"
        }
        if isFITSeason {
            return now.suitsFITCount ? "Conditions suit a FIT Count."
                                     : "Not right for a FIT Count. \(now.fitCountBlockers.first ?? "")"
        }
        if isWormSeason { return "A good month for an earthworm count." }
        return "\(Int(now.temperatureC.rounded()))°C and \(skyWords(now))"
    }

    private var conditionsDetail: String {
        guard let now = weather.current else {
            return weather.lastError ?? "Weather comes from Open-Meteo, using your garden's location."
        }
        var parts = ["\(Int(now.temperatureC.rounded()))°C, \(skyWords(now)), \(now.isDry ? "dry" : "raining")."]
        if isFITSeason {
            if let days = daysSinceLastFITCount {
                parts.append("Last count \(days) \(days == 1 ? "day" : "days") ago.")
            } else {
                parts.append("No FIT Counts yet.")
            }
        } else if isWormSeason {
            parts.append("Worms sit deeper in summer and hard frost.")
        } else {
            parts.append("FIT Counts start again in April.")
        }
        return parts.joined(separator: " ")
    }

    @ViewBuilder
    private var conditionsButton: some View {
        if weather.current == nil {
            Button("Check now") {
                Task { await refreshWeather(mayAskForLocation: true) }
            }
            .buttonStyle(QuietGlassButton())
            .disabled(weather.isLoading)
        } else if isFITSeason || isWormSeason {
            Button {
                startSurvey(isFITSeason ? .fitCount : .earthwormCount)
            } label: {
                HStack(spacing: 6) {
                    Text("Start count")
                    WIconView(.arrowRight, size: 16)
                }
                .fontWeight(.semibold)
                .padding(.horizontal, 4)
                // Keeps the words on one line however little room there is.
                .fixedSize()
            }
            // The one filled button on the screen.
            .buttonStyle(.glassProminent)
            .tint(Theme.leaf)
            .foregroundStyle(Theme.onLeaf)
        }
    }

    /// Finds somewhere to ask the weather about: a garden with a location
    /// first, then the device. It only asks permission for the device's
    /// location when a button has been tapped, never on opening.
    private func refreshWeather(mayAskForLocation: Bool) async {
        var coordinate: CLLocationCoordinate2D?
        if let garden = activeGardens.first(where: { $0.latitude != nil && $0.longitude != nil }),
           let latitude = garden.latitude, let longitude = garden.longitude {
            coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        } else if let known = locationManager.location {
            coordinate = known.coordinate
        } else if locationManager.isAuthorised || mayAskForLocation {
            coordinate = await locationManager.currentLocation()?.coordinate
        }
        guard let coordinate else { return }
        weatherPlace = coordinate
        _ = await weather.conditions(at: coordinate)
    }

    // MARK: Capture

    private func captureButtons(columns: Int) -> some View {
        let buttons: [(title: String, icon: WIcon, action: () -> Void)] = [
            ("Sowing", .sowing, { sheet = .sowing }),
            ("Harvest", .harvest, { sheet = .harvest }),
            ("Sighting", .sighting, { startSighting() }),
            ("FIT Count", .fitCount, { startSurvey(.fitCount) }),
            ("Note", .note, { startNote(draft: "") }),
            ("Photo", .photo, { sheet = .identify })
        ]
        // GlassEffectContainer lets neighbouring pieces of glass share
        // one layer, which is quicker to draw and blends better.
        return GlassEffectContainer(spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
                ForEach(buttons, id: \.title) { button in
                    Button(action: button.action) {
                        VStack(spacing: 8) {
                            WIconView(button.icon, size: 28)
                                .foregroundStyle(Theme.leaf)
                            Text(button.title)
                                .font(.subheadline)
                                .foregroundStyle(Theme.ink)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 84)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(Theme.card.opacity(0.5)).interactive(),
                                 in: .rect(cornerRadius: 18))
                }
            }
        }
    }

    private func startSurvey(_ scheme: RecordingScheme) {
        let survey = Survey(scheme: scheme)
        survey.recorderName = UserDefaults.standard.string(forKey: "recorderName")
        context.insert(survey)
        sheet = .survey(survey)
    }

    private func startSighting() {
        let observation = WildlifeObservation()
        observation.recorderName = UserDefaults.standard.string(forKey: "recorderName")
        let precision = UserDefaults.standard.integer(forKey: "gridPrecision")
        observation.gridPrecisionMetres = precision == 0 ? 100 : precision
        context.insert(observation)
        sheet = .newSighting(observation)
    }

    /// Opens the journal's conversation, with some words to start from
    /// if there are any. Nothing is saved until something is sent.
    private func startNote(draft: String) {
        sheet = .journal(draft)
    }

    @ViewBuilder
    private func captureForm(for sheet: CaptureSheet) -> some View {
        switch sheet {
        // Sowing, harvest and the counts are built from SheetPage, which
        // sets its own size on a Mac.
        case .sowing:
            NewPlantingView()
        case .harvest:
            HarvestPicker()
        case .identify:
            IdentifyView().macSheetSize(width: 520, height: 640)
        case .newSighting(let observation):
            // The form brings its own title and buttons (SheetPage).
            ObservationEditor(observation: observation, isNew: true)
        case .sighting(let observation):
            ObservationEditor(observation: observation, inSheet: true)
        case .survey(let survey):
            RunSurveyView(survey: survey)
        case .journal(let draft):
            JournalChatView(draft: draft)
        }
    }

    // MARK: This week

    /// The urgent jobs. The rules that pick them are in WeekJobs.swift.
    /// This gathers the plain facts those rules need from the records.
    private var weekJobs: [WeekJob] {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: .now)

        // Sowing and planting-out months can only be about to end in
        // the last week of a month. For the rest of the month the plant
        // library is not gone through at all.
        let monthIsEnding = WeekJobs.daysLeftInMonth(today: .now) <= WeekJobs.window

        var shelf: [WeekPlant] = []
        if monthIsEnding {
            shelf = plants.filter { $0.status == .growing }.map { plant in
                WeekPlant(key: plant.id.uuidString, name: plant.displayName,
                          sowIndoors: MonthParser.months(in: plant.sowIndoorsMonthsText),
                          sowOutdoors: MonthParser.months(in: plant.sowOutdoorsMonthsText),
                          isSownThisYear: (plant.plantings ?? []).contains { planting in
                              planting.dateSown.map { calendar.component(.year, from: $0) == year } ?? false
                          })
            }
        }

        // Only sowings that could give a job are passed on: seedlings
        // waiting to go out, and crops due in the next few days.
        let soon = Date.now.addingTimeInterval(Double(WeekJobs.window + 1) * 86_400)
        let growing: [WeekSowing] = plantings.compactMap { planting in
            let isUnderCover = planting.sowingLocation == .indoors || planting.sowingLocation == .undercover
            let isWaiting = monthIsEnding && isUnderCover && planting.datePlantedOut == nil
                && (planting.status == .sown || planting.status == .germinated)
            var due: Date?
            if planting.status == .growing || planting.status == .plantedOut,
               let sown = planting.dateSown,
               let days = RangeParser.midpoint(in: planting.plant?.sowToCropText) {
                let ready = sown.addingTimeInterval(days * 86_400)
                if ready <= soon { due = ready }
            }
            guard isWaiting || due != nil else { return nil }
            return WeekSowing(key: planting.id.uuidString,
                              name: planting.plant?.displayName ?? "crop",
                              beds: planting.bedNames,
                              plantOut: isWaiting ? MonthParser.months(in: planting.plant?.plantOutMonthsText) : [],
                              isWaitingToGoOut: isWaiting,
                              cropDue: due)
        }

        // Last week's rain and water lost, from the weather diary: the
        // seven newest finished days for one garden. Left out if the
        // diary has not been brought up to date in the last few days.
        var rain: Double?
        var lost: Double?
        if let newest = finishedWeather.first, newest.date > Date.now.addingTimeInterval(-3 * 86_400) {
            let lastWeek = finishedWeather.filter { $0.siteRaw == newest.siteRaw }.prefix(7)
            if lastWeek.count == 7 {
                rain = lastWeek.reduce(0) { $0 + ($1.rainfallMM ?? 0) }
                lost = lastWeek.reduce(0) { $0 + ($1.evaporationMM ?? 0) }
            }
        }

        return WeekJobs.list(today: .now, plants: shelf, sowings: growing,
                             outlook: weather.outlook,
                             pastRainMM: rain, pastEvaporationMM: lost)
    }

    /// A week job as a line with a tick box, linked to its plant or
    /// sowing where it has one.
    private func row(for job: WeekJob) -> TodayJob {
        var link: TodayJob.Link?
        if let subject = job.subject {
            if job.kind == .sow {
                link = plants.first { $0.id.uuidString == subject }.map { TodayJob.Link.plant($0) }
            } else {
                link = plantings.first { $0.id.uuidString == subject }.map { TodayJob.Link.planting($0) }
            }
        }
        return TodayJob(id: job.id, title: job.title, detail: job.detail, link: link)
    }

    private func weekCard(_ week: [WeekJob]) -> some View {
        let rows = week.map { row(for: $0) }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("This week")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                if rows.count > 6 {
                    NavigationLink {
                        AllJobsView(title: "This week", jobs: rows, tickedStore: $tickedStore)
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

            if rows.isEmpty {
                Text("Nothing urgent.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
            }
            ForEach(rows.prefix(6)) { job in
                JobRow(job: job, tickedStore: $tickedStore)
            }

            // Says where the list comes from, and owns up when part of
            // it is missing.
            Text(weather.outlook.isEmpty
                 ? "The urgent few, from your sowing months and records. No forecast yet, so no weather warnings."
                 : "The urgent few, from your sowing months, your records and the week's forecast.")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: Jobs

    /// What is worth doing this month, worked out from the records.
    private var jobs: [TodayJob] {
        var list: [TodayJob] = []
        let year = Calendar.current.component(.year, from: .now)

        // Plants whose sowing months include this one and which have not
        // been sown this year.
        let sowable = plants.filter { plant in
            guard plant.status == .growing else { return false }
            let indoors = MonthParser.months(in: plant.sowIndoorsMonthsText)
            let outdoors = MonthParser.months(in: plant.sowOutdoorsMonthsText)
            guard indoors.contains(month) || outdoors.contains(month) else { return false }
            let sownThisYear = (plant.plantings ?? []).contains { planting in
                planting.dateSown.map { Calendar.current.component(.year, from: $0) == year } ?? false
            }
            return !sownThisYear
        }
        for plant in sowable.prefix(4) {
            let indoors = MonthParser.months(in: plant.sowIndoorsMonthsText).contains(month)
            list.append(TodayJob(id: "sow-\(plant.id)", title: "Sow \(plant.displayName)",
                                 detail: indoors ? "Indoors" : "Outdoors", link: .plant(plant)))
        }

        // Sowings that should be ready within a fortnight.
        let due = plantings.filter { planting in
            guard planting.status == .growing || planting.status == .plantedOut,
                  let sown = planting.dateSown,
                  let days = RangeParser.midpoint(in: planting.plant?.sowToCropText) else { return false }
            return sown.addingTimeInterval(days * 86_400) <= Date.now.addingTimeInterval(14 * 86_400)
        }
        for planting in due.prefix(3) {
            list.append(TodayJob(id: "harvest-\(planting.id)",
                                 title: "Harvest \(planting.plant?.displayName ?? "crop")",
                                 detail: planting.bedNames.isEmpty ? nil : planting.bedNames,
                                 link: .planting(planting)))
        }

        // Seed past its date or germinating poorly.
        for packet in seedPackets where packet.isExpired || (packet.viabilityRate.map { $0 < 0.5 } ?? false) {
            list.append(TodayJob(id: "seed-\(packet.id)",
                                 title: "Check seed: \(packet.plant?.displayName ?? "unknown")",
                                 detail: packet.isExpired ? "Past its use-by date" : "Germinating poorly",
                                 link: nil))
        }

        if isWormSeason {
            list.append(TodayJob(id: "worms", title: "Earthworm count",
                                 detail: "Spring and autumn only", link: nil))
        }
        return list
    }

    private func jobsCard(leavingOut urgent: Set<String>) -> some View {
        // Worked out once here. Written as plain `jobs` below, each
        // mention would go through the whole plant library again.
        let jobs = self.jobs.filter { !urgent.contains($0.id) }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("This month")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                if jobs.count > 5 {
                    NavigationLink {
                        AllJobsView(title: "This month", jobs: jobs, tickedStore: $tickedStore)
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

            if jobs.isEmpty {
                Text("Nothing pressing. Jobs appear here from your sowing months and records.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
            ForEach(jobs.prefix(5)) { job in
                JobRow(job: job, tickedStore: $tickedStore)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: Gardens

    @ViewBuilder
    private func gardenCards(oneAtATime: Bool) -> some View {
        if activeGardens.isEmpty {
            Text("No gardens yet.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
        } else if oneAtATime {
            let shown = activeGardens.first { $0.siteKey == shownGardenKey } ?? activeGardens[0]
            if activeGardens.count > 1 {
                gardenSwitch(showing: shown)
            }
            planCard(for: shown)
        } else {
            ForEach(activeGardens) { planCard(for: $0) }
        }
    }

    /// Chooses which garden's plan is shown. A sliding glass switch
    /// (SheetParts.swift), exactly as wide as the cards under it.
    private func gardenSwitch(showing shown: Garden) -> some View {
        GlassSwitch(choices: activeGardens.map(\.siteKey), selection: Binding(
            get: { shown.siteKey },
            set: { shownGardenKey = $0 }
        )) { key in
            activeGardens.first { $0.siteKey == key }?.name ?? key
        }
    }

    private func planCard(for garden: Garden) -> some View {
        GardenPlanCard(garden: garden,
                       beds: beds.filter { $0.siteRaw == garden.siteKey },
                       features: features.filter { $0.siteRaw == garden.siteKey })
    }

    // MARK: Recent records

    /// The five newest records of any kind.
    private var recent: [RecentRecord] {
        var list: [RecentRecord] = []
        list += plantings.map { planting in
            RecentRecord(id: planting.id, date: planting.dateSown ?? planting.createdAt,
                         icon: .sowing,
                         title: planting.plant?.displayName ?? "Unknown plant", kind: "Sowing",
                         detail: planting.bedNames.isEmpty ? nil : planting.bedNames, sighting: nil)
        }
        list += harvests.map { harvest in
            RecentRecord(id: harvest.id, date: harvest.date, icon: .harvest,
                         title: harvest.planting?.plant?.displayName ?? "Harvest", kind: "Harvest",
                         detail: "\(harvest.quantity.formatted()) \(harvest.unit.displayName)", sighting: nil)
        }
        list += surveys.map { survey in
            RecentRecord(id: survey.id, date: survey.startedAt, icon: .fitCount,
                         title: survey.scheme.displayName, kind: "Survey",
                         detail: "\(survey.totalCount) counted", sighting: nil)
        }
        list += sightings.map { sighting in
            let name = sighting.bestAvailableName ?? "Unidentified sighting"
            let picture = RecentRecord.picture(forSighting: name, group: sighting.schemeGroupName)
            return RecentRecord(id: sighting.id, date: sighting.observedAt, icon: picture,
                                title: name, kind: "Sighting",
                                detail: sighting.associatedPlantName.map { "On \($0)" }, sighting: sighting)
        }
        list += diary.map { entry in
            RecentRecord(id: entry.id, date: entry.date, icon: .journalEntry,
                         title: entry.displayTitle, kind: "Note", detail: nil, sighting: nil)
        }
        return Array(list.sorted { $0.date > $1.date }.prefix(5))
    }

    private var recentCard: some View {
        // Worked out once, for the same reason as the jobs above.
        let recent = self.recent
        return VStack(alignment: .leading, spacing: 12) {
            Text("Recent records")
                .font(.headline)
                .foregroundStyle(Theme.ink)

            if recent.isEmpty {
                Text("Nothing recorded yet. Use the buttons above to log a sowing, a harvest or a sighting.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
            ForEach(recent) { record in
                HStack(alignment: .top, spacing: 12) {
                    WIconView(record.icon, size: 30)
                        .foregroundStyle(Theme.leaf)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(record.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.ink)
                        Text("\(record.kind) · \(record.dateText)")
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                        if let detail = record.detail {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(Theme.inkSoft)
                        }
                        // Only sightings carry a tag. A sowing or a
                        // harvest is a fact, not an identification.
                        if let sighting = record.sighting {
                            HStack(spacing: 8) {
                                if sighting.isConfirmed {
                                    StatusTag(text: "Confirmed", fill: Theme.leafFill)
                                } else {
                                    StatusTag(text: "Provisional", fill: Theme.amber)
                                    Button("Confirm") { sheet = .sighting(sighting) }
                                        .font(.caption.weight(.semibold))
                                        .buttonStyle(QuietGlassButton())
                                        .tint(Theme.leaf)
                                }
                            }
                            .padding(.top, 2)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: Journal offer

    /// What was logged today, apart from diary entries themselves.
    private var loggedToday: [RecentRecord] {
        let calendar = Calendar.current
        var list: [RecentRecord] = []
        list += plantings.filter { calendar.isDateInToday($0.createdAt) }.map {
            RecentRecord(id: $0.id, date: $0.createdAt, icon: .sowing,
                         title: "Sowed \($0.plant?.displayName ?? "a plant")\($0.bedNames.isEmpty ? "" : " in \($0.bedNames)")",
                         kind: "", detail: nil, sighting: nil)
        }
        list += harvests.filter { calendar.isDateInToday($0.date) }.map {
            RecentRecord(id: $0.id, date: $0.date, icon: .harvest,
                         title: "Harvested \($0.quantity.formatted()) \($0.unit.displayName) of \($0.planting?.plant?.displayName ?? "a crop")",
                         kind: "", detail: nil, sighting: nil)
        }
        list += surveys.filter { calendar.isDateInToday($0.startedAt) }.map {
            RecentRecord(id: $0.id, date: $0.startedAt, icon: .fitCount,
                         title: "\($0.scheme.displayName): \($0.totalCount) counted",
                         kind: "", detail: nil, sighting: nil)
        }
        list += sightings.filter { calendar.isDateInToday($0.observedAt) }.map {
            RecentRecord(id: $0.id, date: $0.observedAt, icon: .sighting,
                         title: "Saw \($0.bestAvailableName ?? "something not yet identified")\($0.associatedPlantName.map { " on \($0)" } ?? "")",
                         kind: "", detail: nil, sighting: nil)
        }
        return list.sorted { $0.date < $1.date }
    }

    /// True on a day when something has been logged and no journal entry
    /// written, which is when the offer is shown.
    private var journalIsOffered: Bool {
        !loggedToday.isEmpty && !diary.contains { Calendar.current.isDateInToday($0.date) }
    }

    /// Stands in for the offer while rearranging on a day when there is
    /// none, so the offer can still be given a place.
    private var journalPlaceholder: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Journal offer")
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text("Appears here on days when you have logged something and not yet written an entry.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    @ViewBuilder
    private var journalOffer: some View {
        let logged = loggedToday
        let wroteToday = diary.contains { Calendar.current.isDateInToday($0.date) }
        if !logged.isEmpty && !wroteToday {
            Button {
                // The entry starts with a list of what was logged, as a
                // draft to edit. Nothing is saved until you choose to.
                startNote(draft: logged.map(\.title).joined(separator: "\n"))
            } label: {
                HStack(spacing: 12) {
                    WIconView(.journalEntry, size: 26)
                        .foregroundStyle(Theme.leaf)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You logged \(logged.count) \(logged.count == 1 ? "thing" : "things") today.")
                        Text("Write a journal entry?")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    Spacer()
                    WIconView(.arrowRight, size: 18)
                        .foregroundStyle(Theme.leaf)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(Theme.journalCard.opacity(0.8)).interactive(),
                         in: .rect(cornerRadius: Theme.cardRadius))
        }
    }
}

/// A ready-made question for the database: the newest finished days of
/// the weather diary. Three weeks' worth is asked for so that, with two
/// gardens far enough apart to keep separate diaries, one of them still
/// has its last seven days here. It lives outside TodayView because a
/// `@Query` cannot refer to the screen it sits in.
private enum TodayFetch {
    static var latestWeather: FetchDescriptor<WeatherDay> {
        var newest = FetchDescriptor<WeatherDay>(predicate: #Predicate { $0.isComplete },
                                                 sortBy: [SortDescriptor(\.dayKey, order: .reverse)])
        newest.fetchLimit = 21
        return newest
    }
}

// MARK: - Rearranging: the pieces

/// What the cards need to know about the page they are drawn on.
private struct TodayCanvas {
    let width: CGFloat
    let arrangement: TodayArrangement
    let journalIsOffered: Bool
    let isArranging: Bool
    /// This week's urgent jobs, worked out once for the whole redraw.
    /// Two cards need them: "This week" shows them and "This month"
    /// leaves them out.
    let week: [WeekJob]

    var columns: Int { arrangement.columns }

    /// A card with nothing to show is left out, except while rearranging,
    /// when it appears as a placeholder so it can be given a place.
    func isShowing(_ panel: TodayPanel) -> Bool {
        panel != .journal || journalIsOffered || isArranging
    }
}

/// How much room a card has: the full width of the page, a wide column,
/// or a narrower column beside the garden plans.
private enum PanelRoom {
    case page, wideColumn, sideColumn
}

/// The jiggle. A card rocks and bobs a little, over and over, while
/// `isOn` is true.
///
/// Apple publishes no figures for the jiggle of the icons on the Home
/// Screen, so this copies what can be seen there:
///
///   - each thing turns a degree or so about its middle, quickly;
///   - it also bobs up and down by about a point, at a pace of its own;
///   - no two things keep the same time, so they drift in and out of
///     step and never move as one.
///
/// The first version here rocked every card through the same angle at
/// the same pace, which read as a machine and not as a jiggle (William,
/// 13 November 2026).
///
/// A ViewModifier is a reusable change that can be applied to any view,
/// here with `.modifier(Wiggle(...))`.
private struct Wiggle: ViewModifier {
    let isOn: Bool
    /// Neighbouring cards start off leaning opposite ways.
    let leansLeft: Bool

    // Set in the system's Accessibility settings by people for whom
    // movement on screen is unpleasant.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tilt = 0.0
    @State private var bob = 0.0
    /// How wide the card is, which sets how far it may turn.
    @State private var cardWidth: CGFloat = 320
    // Each card's own pace, chosen once when it is made. `@State` keeps
    // the two numbers for as long as the card lives.
    @State private var tiltPace = Double.random(in: 0.115...0.165)
    @State private var bobPace = Double.random(in: 0.17...0.25)

    /// The angle that moves the card's corners about a point and three
    /// quarters. A small card turns further than a wide one, as an icon
    /// turns further than a widget.
    private var angle: Double {
        let radians = 1.75 / max(Double(cardWidth) / 2, 40)
        return min(1.8, max(0.22, radians * 180 / .pi))
    }

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(tilt))
            .offset(y: bob)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { cardWidth = $0 }
            .overlay {
                // With Reduce Motion on, a dashed outline says "this can
                // be moved" in place of the jiggle.
                if isOn && reduceMotion {
                    RoundedRectangle(cornerRadius: Theme.cardRadius)
                        .strokeBorder(Theme.inkSoft, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                }
            }
            // `initial: true` runs this when the card first appears too,
            // so a card that has just been moved carries on jiggling.
            .onChange(of: isOn, initial: true) { _, isNowOn in
                if isNowOn && !reduceMotion {
                    // Start at one end of the swing, then rock to the
                    // other and back for ever.
                    let lean = leansLeft ? -1.0 : 1.0
                    tilt = -angle * lean
                    bob = -0.7
                    withAnimation(.easeInOut(duration: tiltPace).repeatForever(autoreverses: true)) {
                        tilt = angle * lean
                    }
                    withAnimation(.easeInOut(duration: bobPace).repeatForever(autoreverses: true)) {
                        bob = 0.7
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.15)) {
                        tilt = 0
                        bob = 0
                    }
                }
            }
    }
}

/// Starts the rearranging from a press and hold on a card.
///
/// The two kinds of device do it differently:
/// - On an iPhone or iPad, pressing and holding lifts the card, ready to
///   drag, using the system's own drag and drop. The wiggling starts as
///   it lifts. That system is built to live alongside scrolling.
/// - On a Mac, clicking and holding for half a second starts the
///   wiggling. The card is then dragged by the surface laid over it.
private struct LiftToArrange: ViewModifier {
    let panel: TodayPanel
    let title: String
    let isArranging: Bool
    /// Called to begin. True when the card has been lifted for dragging.
    let begin: (Bool) -> Void

    func body(content: Content) -> some View {
        #if os(macOS)
        content.simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in begin(false) },
            // Once the wiggling has begun this gesture stands aside, so
            // it cannot get in the way of the dragging.
            including: isArranging ? .subviews : .all)
        #else
        content.onDrag {
            begin(true)
            // The system needs something to carry. The name is enough:
            // the screen itself remembers which card is moving.
            return NSItemProvider(object: panel.rawValue as NSString)
        } preview: {
            DragLabel(title: title)
        }
        #endif
    }
}

/// An invisible surface over a card while rearranging. It catches the
/// press, because the card's own buttons are switched off. On a Mac it is
/// also what the card is dragged by.
private struct DragSurface: View {
    let panel: TodayPanel
    /// What the card is called, for the label that follows the pointer.
    let title: String
    let began: () -> Void

    var body: some View {
        #if os(macOS)
        Color.clear
            .contentShape(.rect)
            .onDrag {
                began()
                return NSItemProvider(object: panel.rawValue as NSString)
            } preview: {
                DragLabel(title: title)
            }
        #else
        Color.clear
            .contentShape(.rect)
        #endif
    }
}

/// The small label that follows the finger or pointer while a card is
/// dragged. A label, not a picture of the whole card, so the cards
/// underneath can still be seen.
private struct DragLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.leafFill, in: .capsule)
    }
}

// MARK: - Supporting pieces

/// Which form a capture button opens. `Identifiable` lets SwiftUI tell
/// one from the next when it shows them as sheets.
enum CaptureSheet: Identifiable {
    case sowing, harvest, identify
    case newSighting(WildlifeObservation)
    case sighting(WildlifeObservation)
    case survey(Survey)
    /// The journal's conversation, with words to start from.
    case journal(String)

    var id: String {
        switch self {
        case .sowing: return "sowing"
        case .harvest: return "harvest"
        case .identify: return "identify"
        case .newSighting(let observation): return "new-sighting-\(observation.id)"
        case .sighting(let observation): return "sighting-\(observation.id)"
        case .survey(let survey): return "survey-\(survey.id)"
        case .journal: return "journal"
        }
    }
}

/// One line in "This week" or "This month".
struct TodayJob: Identifiable {
    enum Link {
        case plant(Plant)
        case planting(Planting)
    }

    let id: String
    let title: String
    let detail: String?
    let link: Link?
}

/// Remembers which jobs have been ticked. The ticks are kept as one line
/// of text on the device: the month first, then each ticked job, with a
/// bar between them. A new month starts a fresh list.
enum TickedJobs {

    private static var monthKey: String {
        let parts = Calendar.current.dateComponents([.year, .month], from: .now)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)"
    }

    static func ids(in line: String) -> Set<String> {
        let pieces = line.split(separator: "|").map(String.init)
        guard pieces.first == monthKey else { return [] }
        return Set(pieces.dropFirst())
    }

    static func toggling(_ id: String, in line: String) -> String {
        var ticked = ids(in: line)
        if ticked.contains(id) { ticked.remove(id) } else { ticked.insert(id) }
        return ([monthKey] + ticked.sorted()).joined(separator: "|")
    }
}

/// A job with its tick box. A ticked job is struck through.
struct JobRow: View {

    let job: TodayJob
    @Binding var tickedStore: String

    private var isTicked: Bool { TickedJobs.ids(in: tickedStore).contains(job.id) }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                tickedStore = TickedJobs.toggling(job.id, in: tickedStore)
            } label: {
                TickBox(isOn: isTicked)
                    .frame(width: 30, height: 30)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isTicked ? "Done: \(job.title)" : "Mark as done: \(job.title)")

            switch job.link {
            case .plant(let plant)?: NavigationLink(value: plant) { words }.buttonStyle(.plain)
            case .planting(let planting)?: NavigationLink(value: planting) { words }.buttonStyle(.plain)
            case nil: words
            }
            Spacer(minLength: 0)
        }
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(job.title)
                .font(.subheadline)
                .strikethrough(isTicked)
                .foregroundStyle(isTicked ? Theme.inkSoft : Theme.ink)
                // Lets a long line run on to the next. In a narrow
                // column it was being cut short with three dots.
                .fixedSize(horizontal: false, vertical: true)
            if let detail = job.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 5)
        .multilineTextAlignment(.leading)
    }
}

/// Every job in a list, reached from "View all".
struct AllJobsView: View {

    let title: String
    let jobs: [TodayJob]
    @Binding var tickedStore: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(jobs) { JobRow(job: $0, tickedStore: $tickedStore) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
            .padding()
        }
        .navigationTitle(title)
        .paperScreen()
    }
}

/// One line in "Recent records".
struct RecentRecord: Identifiable {
    let id: UUID
    let date: Date
    let icon: WIcon
    let title: String
    let kind: String
    let detail: String?
    let sighting: WildlifeObservation?

    /// "Today, 09:14" for today, "Sun 7 June" for any other day.
    var dateText: String {
        if Calendar.current.isDateInToday(date) {
            return "Today, \(date.formatted(.dateTime.hour().minute()))"
        }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.wide))
    }

    /// Picks a picture for a sighting from its name. Anything it does not
    /// recognise gets the binoculars.
    static func picture(forSighting name: String, group: String?) -> WIcon {
        let words = (name + " " + (group ?? "")).lowercased()
        if words.contains("butterfl") || words.contains("moth") || words.contains("tortoiseshell")
            || words.contains("admiral") || words.contains("peacock") || words.contains("brimstone") {
            return .butterfly
        }
        if words.contains("ladybird") { return .ladybird }
        if words.contains("bee") { return .bee }
        return .sighting
    }
}

/// Chooses which sowing a harvest belongs to, then shows the harvest
/// form in the same sheet.
struct HarvestPicker: View {

    @Query private var plantings: [Planting]
    @State private var chosen: Planting?

    /// Sowings that could be giving a crop: not finished and not failed.
    private var growing: [Planting] {
        plantings
            .filter { $0.status != .finished && $0.status != .failed && $0.status != .planned }
            .sorted { ($0.dateSown ?? .distantPast) > ($1.dateSown ?? .distantPast) }
    }

    var body: some View {
        // With only one thing growing there is nothing to choose
        // between, so the harvest form opens straight away.
        if let planting = chosen ?? (growing.count == 1 ? growing.first : nil) {
            HarvestEditor(planting: planting,
                          onBack: growing.count > 1 ? { chosen = nil } : nil)
        } else {
            SheetPage("What did you harvest?") {
                SheetScroll {
                    if growing.isEmpty {
                        SheetCard("Nothing growing yet") {
                            Text("A harvest is recorded against a sowing. Record the sowing first.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                    // Each sowing is a glass button. Choosing one swaps
                    // this list for the harvest form, in the same sheet.
                    ForEach(growing) { planting in
                        Button {
                            chosen = planting
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(planting.plant?.displayName ?? "Unknown plant")
                                        .foregroundStyle(Theme.ink)
                                    if !planting.bedNames.isEmpty {
                                        Text(planting.bedNames)
                                            .font(.caption)
                                            .foregroundStyle(Theme.inkSoft)
                                    }
                                }
                                Spacer(minLength: 8)
                                WIconView(.arrowRight, size: 15)
                                    .foregroundStyle(Theme.leaf)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.tint(Theme.card.opacity(0.5)).interactive(),
                                     in: .rect(cornerRadius: 18))
                    }
                }
            }
        }
    }
}
