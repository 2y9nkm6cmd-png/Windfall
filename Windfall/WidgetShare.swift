//
//  WidgetShare.swift
//  Windfall
//
//  The app's side of the widgets.
//
//  Four pieces:
//    WeekFacts      gathers what "This week" needs from the records,
//                   for any day. Today uses it and so do the widgets.
//    WidgetShare    writes the summary file the widgets read.
//    WidgetRoute    follows a tap on a widget to the right place.
//    WidgetGallery  a checking page that draws every widget in the app.
//
//  The file's layout, and why there is a file at all, are explained in
//  WindfallShared/WidgetSummary.swift.
//

import Foundation
import ImageIO
import Observation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import WidgetKit
#endif

// MARK: - The week's facts

enum WeekFacts {

    /// The newest finished days of the weather diary. The same question
    /// Today asks: see `TodayFetch` in TodayView.swift.
    static var latestWeather: FetchDescriptor<WeatherDay> {
        var newest = FetchDescriptor<WeatherDay>(predicate: #Predicate { $0.isComplete },
                                                 sortBy: [SortDescriptor(\.dayKey, order: .reverse)])
        newest.fetchLimit = 21
        return newest
    }

    /// The urgent jobs as they stand on `today`. The rules that pick
    /// them are in WeekJobs.swift. This gathers the plain facts those
    /// rules need from the records.
    ///
    /// It was part of TodayView until the widgets needed the same list
    /// for the days ahead. Having one copy means Today and a widget can
    /// never disagree.
    static func jobs(today: Date, plants: [Plant], plantings: [Planting],
                     finishedWeather: [WeatherDay], outlook: [OutlookDay]) -> [WeekJob] {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: today)

        // Sowing and planting-out months can only be about to end in
        // the last week of a month. For the rest of the month the plant
        // library is not gone through at all.
        let monthIsEnding = WeekJobs.daysLeftInMonth(today: today) <= WeekJobs.window

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
        let soon = today.addingTimeInterval(Double(WeekJobs.window + 1) * 86_400)
        let growing: [WeekSowing] = plantings.compactMap { planting in
            let isUnderCover = planting.sowingLocation == .indoors || planting.sowingLocation == .undercover
            let isWaiting = monthIsEnding && isUnderCover && planting.datePlantedOut == nil
                && (planting.status == .sown || planting.status == .germinated)
            var due: Date?
            if planting.status == .growing || planting.status == .plantedOut,
               let sown = planting.dateSown,
               // Sow to crop is written in weeks or months. DurationParser
               // turns it into days. See Parsing.swift.
               let days = DurationParser.days(in: planting.plant?.sowToCropText)?.midpoint {
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
        // diary's newest day is more than a few days before `today`.
        var rain: Double?
        var lost: Double?
        if let newest = finishedWeather.first, newest.date > today.addingTimeInterval(-3 * 86_400) {
            let lastWeek = finishedWeather.filter { $0.siteRaw == newest.siteRaw }.prefix(7)
            if lastWeek.count == 7 {
                rain = lastWeek.reduce(0) { $0 + ($1.rainfallMM ?? 0) }
                lost = lastWeek.reduce(0) { $0 + ($1.evaporationMM ?? 0) }
            }
        }

        return WeekJobs.list(today: today, plants: shelf, sowings: growing,
                             outlook: outlook,
                             pastRainMM: rain, pastEvaporationMM: lost)
    }
}

// MARK: - Writing the summary

enum WidgetShare {

    /// Brings the widgets' file up to date from the records. Called when
    /// Today has fetched the weather and when the app is put away.
    ///
    /// It does nothing where there is no shared folder: on a Mac, and in
    /// an unsigned copy. It only reads the records. It never changes one.
    static func refresh(context: ModelContext) {
        guard WindfallGroup.folder != nil else { return }
        let calendar = Calendar.current
        let now = Date.now
        var summary = WidgetSummaryStore.read() ?? WidgetSummary(written: now)

        let plants = (try? context.fetch(FetchDescriptor<Plant>(sortBy: [SortDescriptor(\.commonName)]))) ?? []
        let plantings = (try? context.fetch(FetchDescriptor<Planting>())) ?? []
        let weather = (try? context.fetch(WeekFacts.latestWeather)) ?? []

        // The forecast is held in memory and is gone when the app has
        // only just been opened, or there is no signal. The last one
        // written to the file is used then, so a frost warning does not
        // vanish from the widgets just because the app was opened.
        var outlook = WeatherService.shared.outlook
        if outlook.isEmpty {
            outlook = summary.nights.map {
                OutlookDay(dayKey: $0.dayKey, minTemperatureC: $0.lowC, rainMM: $0.rainMM, gustKMH: $0.gustKMH)
            }
        }
        summary.nights = outlook.map {
            WidgetNight(dayKey: $0.dayKey, lowC: $0.minTemperatureC, rainMM: $0.rainMM, gustKMH: $0.gustKMH)
        }

        // The urgent jobs for today and each of the next seven days.
        summary.days = (0...7).compactMap { daysOn in
            guard let day = calendar.date(byAdding: .day, value: daysOn, to: now) else { return nil }
            let jobs = WeekFacts.jobs(today: day, plants: plants, plantings: plantings,
                                      finishedWeather: weather, outlook: outlook)
            return WidgetDay(dayKey: WidgetSummary.dayKey(for: day, calendar: calendar),
                             jobs: jobs.map { WidgetJob(id: $0.id, kind: $0.kind.rawValue, title: $0.title, detail: $0.detail) })
        }

        // This month and next, so the widget turns over on the first of
        // the month without the app being opened.
        let growing = plants.filter { $0.status == .growing }
        let thisMonth = calendar.component(.month, from: now)
        summary.months = [thisMonth, YearCalendar.monthAfter(thisMonth)].map { monthCard($0, from: growing, calendar: calendar) }

        summary.written = now
        WidgetSummaryStore.write(summary)
        reload()
    }

    /// Asks iOS to draw the widgets again.
    static func reload() {
        #if os(iOS)
        guard WindfallGroup.folder != nil else { return }
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    /// One month for the "This month" widget: the same counts as the
    /// top of a month's page, and its most pressing plants.
    private static func monthCard(_ month: Int, from growing: [Plant], calendar: Calendar) -> WidgetMonth {
        var lists: [YearActivity: [MonthEntry]] = [:]
        for job in YearActivity.allCases {
            lists[job] = YearCalendar.entries(for: job, in: month, from: growing)
        }
        // A plant that can be sown indoors and outdoors is one plant to
        // sow, so the three planting jobs are counted by plant.
        var toPlant = Set<UUID>()
        var lastChances = Set<UUID>()
        for job in [YearActivity.sowIndoors, .sowOutdoors, .plantOut] {
            for entry in lists[job] ?? [] {
                toPlant.insert(entry.plant.id)
                if entry.monthPlace == .lastChance || entry.monthPlace == .onlyMonth { lastChances.insert(entry.plant.id) }
            }
        }
        // A few plants from each job, the pressing ones first. Each
        // job's own list already starts with its most pressing.
        var picked: [(place: Int, order: Int, line: WidgetMonthLine)] = []
        for job in [YearActivity.sowOutdoors, .sowIndoors, .plantOut, .harvest] {
            for entry in (lists[job] ?? []).prefix(3) {
                let tag = YearCalendar.tag(for: entry.monthPlace, job: job)
                let wait = entry.lastMonth.map { "to \(calendar.monthSymbols[$0 - 1])" } ?? "All year"
                let line = WidgetMonthLine(id: "\(job.rawValue)-\(entry.plant.id.uuidString)",
                                           name: entry.plant.displayName, job: job.rawValue,
                                           tag: tag, wait: tag == nil ? wait : nil,
                                           isPressing: entry.monthPlace == .lastChance || entry.monthPlace == .onlyMonth)
                picked.append((entry.monthPlace.rawValue, picked.count, line))
            }
        }
        picked.sort { ($0.place, $0.order) < ($1.place, $1.order) }
        return WidgetMonth(month: month, toSowOrPlant: toPlant.count,
                           toHarvest: lists[.harvest]?.count ?? 0, inFlower: lists[.flowering]?.count ?? 0,
                           lastChances: lastChances.count, lines: picked.prefix(4).map(\.line))
    }

    // MARK: Eira's last answer

    /// Notes Eira's answer to a photo for the Identify widgets, with a
    /// small copy of the photo. A warning about a plant that could hurt
    /// someone always travels with the answer.
    static func noteAnswer(_ identification: EiraIdentification, photo: Data?) {
        guard WindfallGroup.folder != nil, identification.verdict != .nothing else { return }
        var summary = WidgetSummaryStore.read() ?? WidgetSummary(written: .now)
        var hasPhoto = false
        if let photo, let url = WidgetSummaryStore.photoURL, let small = smallCopy(of: photo) {
            hasPhoto = (try? small.write(to: url, options: .atomic)) != nil
        }
        summary.answer = WidgetAnswer(headline: identification.headline,
                                      subheading: identification.subheading,
                                      confidence: identification.confidence?.displayName,
                                      warning: identification.cautions.first { $0.weight == .danger }?.words,
                                      when: .now, hasPhoto: hasPhoto)
        WidgetSummaryStore.write(summary)
        reload()
    }

    /// A copy of a photo no more than 360 dots across, as a JPEG. A
    /// widget has very little memory, so it is never handed the original.
    private static func smallCopy(of photo: Data) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Turns the picture the right way up, as the camera noted it.
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 360
        ]
        guard let source = CGImageSourceCreateWithData(photo as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}

// MARK: - Following a tap on a widget

/// A tap on a widget opens the app with a link, such as
/// `windfall://capture/sowing`. This holds what was asked for until the
/// screen that can do it has done so.
///
/// `@Observable` lets a screen notice when `pending` changes.
@Observable
final class WidgetRoute {
    static let shared = WidgetRoute()

    /// "sowing", "harvest", "sighting", "fit", "note", "photo",
    /// "identify" or "eira". Nil when nothing is waiting.
    var pending: String?

    /// Reads a link. True if it was one of Windfall's, in which case
    /// the app should show Today.
    func take(_ url: URL) -> Bool {
        guard let asked = WidgetLink.request(in: url) else { return false }
        pending = asked == "today" ? nil : asked
        return true
    }

    /// Hands over what is waiting if it is one of `wanted`, and clears
    /// it so that it is acted on once.
    func claim(_ wanted: Set<String>) -> String? {
        guard let pending, wanted.contains(pending) else { return nil }
        self.pending = nil
        return pending
    }
}

// MARK: - A checking page

/// Draws the widgets inside the app, with example content, so they can
/// be looked at in a simulator without putting them on a Home Screen.
/// Opened with `-demoOpen widgets`. `-demoWidgetPage 0`, 1 or 2 picks
/// which, and `-demoWidgetLook green` the look.
struct WidgetGallery: View {

    private let page = UserDefaults.standard.integer(forKey: "demoWidgetPage")
    private let look = WidgetLook(rawValue: UserDefaults.standard.string(forKey: "demoWidgetLook") ?? "") ?? .paper

    private var palette: WidgetPalette { .of(look) }

    var body: some View {
        let summary = WidgetSummary.example()
        let now = Date.now
        let jobs = summary.jobs(on: now)
        let ticked: Set<String> = ["harvest-example"]
        let risky = WidgetAnswer(headline: "Cow parsley, or one that looks like it", subheading: nil, confidence: "Possible",
                                 warning: "Carrot family. Do not eat it or handle it on the strength of a photo.",
                                 when: now, hasPhoto: false)
        ScrollView {
            VStack(spacing: 14) {
                switch page {
                case 1:
                    HStack(spacing: 14) {
                        small(MonthWidgetView(month: summary.month(on: now), size: .small, palette: palette))
                        small(FrostWidgetView(tonightC: summary.tonight(on: now)?.lowC, nights: [], rain: nil, size: .small, palette: palette))
                    }
                    medium(MonthWidgetView(month: summary.month(on: now), size: .medium, palette: palette))
                    medium(FrostWidgetView(tonightC: summary.tonight(on: now)?.lowC, nights: summary.comingNights(from: now),
                                           rain: summary.nextRain(from: now), size: .medium, palette: palette))
                    medium(CaptureWidgetView(palette: palette))
                case 2:
                    medium(IdentifyWidgetView(answer: summary.answer, photo: nil, style: .withAnswer, palette: palette))
                    medium(IdentifyWidgetView(answer: risky, photo: nil, style: .withAnswer, palette: palette))
                    HStack(spacing: 14) {
                        IdentifyWidgetView(answer: summary.answer, photo: nil, style: .answerOnly, palette: palette)
                            .frame(width: 170, height: 170)
                            .background(palette.ground)
                            .clipShape(.rect(cornerRadius: 24))
                        small(EiraWidgetView(palette: palette))
                    }
                    HStack(spacing: 14) {
                        IdentifyWidgetView(answer: risky, photo: nil, style: .answerOnly, palette: palette)
                            .frame(width: 170, height: 170)
                            .background(palette.ground)
                            .clipShape(.rect(cornerRadius: 24))
                        small(WeekWidgetView(jobs: nil, ticked: [], size: .small, palette: palette))
                    }
                default:
                    HStack(spacing: 14) {
                        small(WeekWidgetView(jobs: jobs, ticked: ticked, size: .small, palette: palette))
                        small(IdentifyWidgetView(answer: nil, photo: nil, style: .button, palette: palette))
                    }
                    medium(WeekWidgetView(jobs: jobs, ticked: ticked, size: .medium, palette: palette))
                    card(WeekWidgetView(jobs: jobs, ticked: ticked, size: .large, palette: palette), width: 364, height: 382)
                }
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .background(Color(hex: 0xC5D0BC))
    }

    /// A widget's frame, with the 16 points of margin iOS gives one.
    private func card(_ view: some View, width: CGFloat, height: CGFloat) -> some View {
        view.padding(16)
            .frame(width: width, height: height)
            .background(palette.ground, in: .rect(cornerRadius: 24))
    }

    private func small(_ view: some View) -> some View { card(view, width: 170, height: 170) }
    private func medium(_ view: some View) -> some View { card(view, width: 364, height: 170) }
}
