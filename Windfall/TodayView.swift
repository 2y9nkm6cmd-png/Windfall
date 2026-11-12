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

import SwiftUI
import SwiftData
import CoreLocation

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

    private var month: Int { Calendar.current.component(.month, from: .now) }
    private var activeGardens: [Garden] { gardens.filter(\.isActive) }

    // MARK: Body

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    conditionsCard(stacked: width < 600)
                    captureButtons(columns: width >= 700 ? 6 : 3)

                    if width >= 840 {
                        // Three columns: jobs, gardens, records.
                        HStack(alignment: .top, spacing: 14) {
                            jobsCard.frame(width: width * 0.25)
                            VStack(spacing: 14) { gardenCards(oneAtATime: false) }
                            VStack(spacing: 14) { recentCard; journalOffer }
                                .frame(width: width * 0.28)
                        }
                    } else if width >= 600 {
                        // Two columns.
                        HStack(alignment: .top, spacing: 14) {
                            VStack(spacing: 14) { jobsCard; recentCard }
                            VStack(spacing: 14) { gardenCards(oneAtATime: true); journalOffer }
                        }
                    } else {
                        // One column, for an iPhone.
                        jobsCard
                        gardenCards(oneAtATime: true)
                        recentCard
                        journalOffer
                    }
                }
                .padding(.leading, width >= 600 ? 14 : 16)
                .padding(.trailing, width >= 600 ? 24 : 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
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
            await refreshWeather(mayAskForLocation: false)
        }
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
            .buttonStyle(.glass)
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

    private func startNote(draft: String) {
        let entry = DiaryEntry(body: draft)
        context.insert(entry)
        sheet = .note(entry)
    }

    @ViewBuilder
    private func captureForm(for sheet: CaptureSheet) -> some View {
        switch sheet {
        case .sowing:
            NewPlantingView().macSheetSize(width: 520, height: 640)
        case .harvest:
            HarvestPicker().macSheetSize(width: 480, height: 560)
        case .identify:
            IdentifyView().macSheetSize(width: 520, height: 640)
        case .newSighting(let observation):
            NavigationStack { ObservationEditor(observation: observation, isNew: true) }
                .macSheetSize(width: 520, height: 680)
        case .sighting(let observation):
            NavigationStack {
                ObservationEditor(observation: observation)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { self.sheet = nil }
                        }
                    }
            }
            .macSheetSize(width: 520, height: 680)
        case .survey(let survey):
            RunSurveyView(survey: survey).macSheetSize(width: 520, height: 680)
        case .note(let entry):
            DiaryEntryEditor(entry: entry).macSheetSize(width: 520, height: 640)
        }
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

    private var jobsCard: some View {
        // Worked out once here. Written as plain `jobs` below, each
        // mention would go through the whole plant library again.
        let jobs = self.jobs
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("This month")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                if jobs.count > 5 {
                    NavigationLink {
                        AllJobsView(jobs: jobs, tickedStore: $tickedStore)
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
                                        .buttonStyle(.glass)
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

// MARK: - Supporting pieces

/// Which form a capture button opens. `Identifiable` lets SwiftUI tell
/// one from the next when it shows them as sheets.
enum CaptureSheet: Identifiable {
    case sowing, harvest, identify
    case newSighting(WildlifeObservation)
    case sighting(WildlifeObservation)
    case survey(Survey)
    case note(DiaryEntry)

    var id: String {
        switch self {
        case .sowing: return "sowing"
        case .harvest: return "harvest"
        case .identify: return "identify"
        case .newSighting(let observation): return "new-sighting-\(observation.id)"
        case .sighting(let observation): return "sighting-\(observation.id)"
        case .survey(let survey): return "survey-\(survey.id)"
        case .note(let entry): return "note-\(entry.id)"
        }
    }
}

/// One line in "This month".
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
            if let detail = job.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(.top, 5)
        .multilineTextAlignment(.leading)
    }
}

/// Every job for the month, reached from "View all".
struct AllJobsView: View {

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
        .navigationTitle("This month")
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

/// Chooses which sowing a harvest belongs to, then opens the harvest form.
struct HarvestPicker: View {

    @Environment(\.dismiss) private var dismiss
    @Query private var plantings: [Planting]
    @State private var chosen: Planting?

    /// Sowings that could be giving a crop: not finished and not failed.
    private var growing: [Planting] {
        plantings
            .filter { $0.status != .finished && $0.status != .failed && $0.status != .planned }
            .sorted { ($0.dateSown ?? .distantPast) > ($1.dateSown ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            List {
                if growing.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing growing yet", systemImage: "basket")
                    } description: {
                        Text("A harvest is recorded against a sowing. Record the sowing first.")
                    }
                }
                ForEach(growing) { planting in
                    Button {
                        chosen = planting
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(planting.plant?.displayName ?? "Unknown plant")
                            if !planting.bedNames.isEmpty {
                                Text(planting.bedNames)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("What did you harvest?")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .paperScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            // When the harvest form closes, this picker closes too.
            .sheet(item: $chosen, onDismiss: { dismiss() }) { planting in
                HarvestEditor(planting: planting)
            }
        }
    }
}
