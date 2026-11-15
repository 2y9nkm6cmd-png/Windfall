//
//  WidgetSummary.swift
//  WindfallShared
//
//  What the app tells its widgets.
//
//  A widget is a second small program that ships inside Windfall. iOS
//  fences the two apart: a widget cannot open the app's database. What
//  they can both open is one shared folder, called an App Group. So the
//  app writes a small summary file there, and the widgets read it. Your
//  records stay where they are and are never opened by a second program.
//
//  Everything in this folder (WindfallShared) is built into both the app
//  and the widgets, so both agree on what the file holds.
//
//  `nonisolated` on each type says it may be used from any thread. The
//  app treats its own code as main-thread-only unless told otherwise,
//  and a widget reads this file away from the main thread.
//

import Foundation
#if os(macOS)
import Security
#endif

// MARK: - The shared folder

nonisolated enum WindfallGroup {

    /// The App Group's name. The same text is in both entitlements
    /// files, which is what gives each program its key to the folder.
    static let identifier = "group.com.54brookroad.Windfall"

    /// The shared folder, or nil where there is none: in any copy built
    /// without signing. Everything below does nothing when this is nil.
    static var folder: URL? {
        #if os(macOS)
        // A Mac hands the folder's address to any program that asks,
        // key or no key, and then questions the person at the keyboard
        // when a program without the key tries to use it. So the key is
        // looked for first. An unsigned copy has none and gets nil.
        guard holdsKey else { return nil }
        #endif
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    #if os(macOS)
    /// True if this copy of the program was signed with the App Group
    /// in its entitlements. Asked once and remembered.
    private static let holdsKey: Bool = {
        guard let task = SecTaskCreateFromSelf(nil),
              let groups = SecTaskCopyValueForEntitlement(task, "com.apple.security.application-groups" as CFString, nil) as? [String]
        else { return false }
        return groups.contains(identifier)
    }()
    #endif

    /// Small settings both programs can read and write, such as which
    /// jobs are ticked. Nil where there is no shared folder, and the app
    /// then uses its own settings as it always has.
    static var defaults: UserDefaults? {
        folder == nil ? nil : UserDefaults(suiteName: identifier)
    }
}

// MARK: - What the file holds

/// One urgent job, as "This week" words it.
nonisolated struct WidgetJob: Codable, Equatable, Identifiable {
    var id: String
    /// frost, wind, dry, sow, plantOut or harvest.
    var kind: String
    var title: String
    var detail: String
}

/// The urgent jobs as they will stand on one day. The app works these
/// out for today and the week ahead, so "Last week to sow" still turns
/// up on the right day if the app is not opened in between.
nonisolated struct WidgetDay: Codable, Equatable {
    /// The day, written "2026-11-14".
    var dayKey: String
    var jobs: [WidgetJob]
}

/// One plant on the "This month" widget.
nonisolated struct WidgetMonthLine: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    /// "Sow outdoors", "Plant out" and so on.
    var job: String
    /// "Last chance", "This month only" or "Starts now". Nil otherwise.
    var tag: String?
    /// "to March" or "All year", shown when there is no tag.
    var wait: String?
    /// True for a last chance or a single month.
    var isPressing: Bool
}

/// One month's counts and its most pressing plants.
nonisolated struct WidgetMonth: Codable, Equatable {
    /// 1 for January.
    var month: Int
    var toSowOrPlant: Int
    var toHarvest: Int
    var inFlower: Int
    var lastChances: Int
    var lines: [WidgetMonthLine]
}

/// One day of the forecast.
nonisolated struct WidgetNight: Codable, Equatable {
    var dayKey: String
    /// The day's lowest temperature, which is nearly always around dawn.
    var lowC: Double?
    var rainMM: Double?
    /// The day's strongest gust, in kilometres an hour. Kept so the app
    /// can work the week's jobs out again when it has no fresh forecast.
    var gustKMH: Double?
}

/// Eira's last answer to a photo.
nonisolated struct WidgetAnswer: Codable, Equatable {
    var headline: String
    var subheading: String?
    /// "Probable", "Possible" and so on, in the app's own words.
    var confidence: String?
    /// The warning that goes with a plant that could hurt someone. A
    /// widget that shows the answer always shows this with it.
    var warning: String?
    var when: Date
    var hasPhoto: Bool
}

nonisolated struct WidgetSummary: Codable, Equatable {
    /// When the app last wrote the file.
    var written: Date
    var days: [WidgetDay] = []
    var months: [WidgetMonth] = []
    var nights: [WidgetNight] = []
    var answer: WidgetAnswer?
    /// Where the app asks the weather about, so a widget can fetch the
    /// forecast for itself. Nil until the app has fetched the weather
    /// once. See WidgetForecast.swift. Both of these are optional so
    /// that a file written before they existed can still be read.
    var place: WidgetPlace?
    /// When the forecast in `nights` was fetched, by the app or a widget.
    var forecastFetched: Date?
}

// MARK: - Has anything changed?

nonisolated extension WidgetSummary {

    /// True when this summary and another would put the same things on
    /// every widget. The app asks this before writing the file, so that
    /// a file which would come out the same is not written again and
    /// the widgets are not asked to redraw for nothing.
    ///
    /// Two things are left out of the comparison:
    /// - `written`, which is only a note of when the file was saved.
    /// - Fractions of a second in `forecastFetched`. The file keeps
    ///   times to the whole second, so a time read back from it is up
    ///   to a second away from the one that was saved.
    func showsTheSame(as other: WidgetSummary) -> Bool {
        switch (forecastFetched, other.forecastFetched) {
        case (nil, nil): break
        case let (mine?, theirs?): if abs(mine.timeIntervalSince(theirs)) >= 1 { return false }
        default: return false
        }
        var mine = self, theirs = other
        mine.written = .distantPast; theirs.written = .distantPast
        mine.forecastFetched = nil; theirs.forecastFetched = nil
        return mine == theirs
    }
}

// MARK: - Reading it for one day

nonisolated extension WidgetSummary {

    /// A day as "2026-11-14", the way the weather diary writes it.
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// The urgent jobs for a day. Nil means the file has nothing for
    /// that day: the app has not been opened for more than a week.
    func jobs(on date: Date, calendar: Calendar = .current) -> [WidgetJob]? {
        let key = Self.dayKey(for: date, calendar: calendar)
        return days.first { $0.dayKey == key }?.jobs
    }

    func month(on date: Date, calendar: Calendar = .current) -> WidgetMonth? {
        let number = calendar.component(.month, from: date)
        return months.first { $0.month == number }
    }

    /// The forecast for the day `daysOn` days after `date`.
    func night(_ daysOn: Int, after date: Date, calendar: Calendar = .current) -> WidgetNight? {
        guard let day = calendar.date(byAdding: .day, value: daysOn, to: date) else { return nil }
        let key = Self.dayKey(for: day, calendar: calendar)
        return nights.first { $0.dayKey == key }
    }

    /// Tonight's lowest temperature. A day's coldest moment is around
    /// dawn, so tonight's low is tomorrow's: the same rule as the frost
    /// job in "This week".
    func tonight(on date: Date, calendar: Calendar = .current) -> WidgetNight? {
        night(1, after: date, calendar: calendar)
    }

    /// The next five nights, each named for its evening: "Sat", "Sun".
    func comingNights(from date: Date, calendar: Calendar = .current) -> [(name: String, lowC: Double)] {
        (0..<5).compactMap { evening in
            guard let low = night(evening + 1, after: date, calendar: calendar)?.lowC,
                  let day = calendar.date(byAdding: .day, value: evening, to: date) else { return nil }
            let name = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: day) - 1]
            return (name, low)
        }
    }

    /// "4 mm of rain on Thursday", for the first wet day of the next
    /// five. Nil if none has a millimetre or more.
    func nextRain(from date: Date, calendar: Calendar = .current) -> String? {
        for daysOn in 0..<5 {
            guard let rain = night(daysOn, after: date, calendar: calendar)?.rainMM, rain >= 1,
                  let day = calendar.date(byAdding: .day, value: daysOn, to: date) else { continue }
            let amount = "\(Int(rain.rounded())) mm of rain"
            if daysOn == 0 { return "\(amount) today" }
            if daysOn == 1 { return "\(amount) tomorrow" }
            return "\(amount) on \(calendar.weekdaySymbols[calendar.component(.weekday, from: day) - 1])"
        }
        return nil
    }
}

// MARK: - Reading and writing the file

nonisolated enum WidgetSummaryStore {

    static var fileURL: URL? { WindfallGroup.folder?.appendingPathComponent("widget-summary.json") }
    /// A small copy of the last photo Eira was asked about.
    static var photoURL: URL? { WindfallGroup.folder?.appendingPathComponent("widget-last-photo.jpg") }

    static func read() -> WidgetSummary? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSummary.self, from: data)
    }

    /// Writes the file. `.atomic` writes a new file beside the old one
    /// and swaps them, so a widget never reads half a file.
    static func write(_ summary: WidgetSummary) {
        guard let fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(summary) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Ticked jobs

/// Which jobs are ticked, as the Today screen keeps them: one line of
/// text, the month first and then each ticked job, with a bar between.
/// The same rules as `TickedJobs` in TodayView.swift, here so that a
/// widget can tick a job too. If one changes, change the other.
nonisolated enum WidgetTicks {

    /// The setting's name. Today uses the same one.
    static let key = "todayTickedJobs"

    private static func monthKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)"
    }

    static func ids(in line: String, on date: Date = .now) -> Set<String> {
        let pieces = line.split(separator: "|").map(String.init)
        guard pieces.first == monthKey(date) else { return [] }
        return Set(pieces.dropFirst())
    }

    static func toggling(_ id: String, in line: String, on date: Date = .now) -> String {
        var ticked = ids(in: line, on: date)
        if ticked.contains(id) { ticked.remove(id) } else { ticked.insert(id) }
        return ([monthKey(date)] + ticked.sorted()).joined(separator: "|")
    }

    /// The ticks as they stand now, read from the shared settings.
    static func current() -> Set<String> {
        ids(in: WindfallGroup.defaults?.string(forKey: key) ?? "")
    }
}

// MARK: - Links from a widget into the app

/// A tap on a widget opens the app with a link such as
/// `windfall://capture/sowing`. The app reads it in `WidgetRoute`.
nonisolated enum WidgetLink {
    static let scheme = "windfall"

    static let today = URL(string: "windfall://today")!
    static let identify = URL(string: "windfall://identify")!
    static let eira = URL(string: "windfall://eira")!

    /// sowing, harvest, sighting, fit, note or photo.
    static func capture(_ kind: String) -> URL { URL(string: "windfall://capture/\(kind)")! }

    /// What a link asks for: "sowing", "identify", "eira", "today".
    /// Nil if the link is not one of Windfall's.
    static func request(in url: URL) -> String? {
        guard url.scheme == scheme, let place = url.host else { return nil }
        return place == "capture" ? url.lastPathComponent : place
    }
}

// MARK: - Example content

extension WidgetSummary {

    /// Made-up content, shown in the widget gallery while you choose a
    /// widget and on the app's own checking page. Never written to the
    /// shared file.
    nonisolated static func example(on date: Date = .now, calendar: Calendar = .current) -> WidgetSummary {
        let jobs = [
            WidgetJob(id: "frost-example", kind: "frost", title: "Frost tonight",
                      detail: "Down to about -1°C. Cover or bring in anything tender before dark."),
            WidgetJob(id: "sow-example", kind: "sow", title: "Last week to sow Broad beans",
                      detail: "Outdoors. Its sowing months end with November."),
            WidgetJob(id: "harvest-example", kind: "harvest", title: "Harvest Leeks",
                      detail: "Should be ready on Thursday. Bed 3."),
            WidgetJob(id: "wind-example", kind: "wind", title: "Strong wind on Friday",
                      detail: "Gusts to about 45 mph. Check stakes, ties, netting and covers."),
            WidgetJob(id: "plantout-example", kind: "plantOut", title: "Last week to plant out Garlic",
                      detail: "For Bed 2. Its planting-out months end with November.")
        ]
        let lows: [Double] = [3, -1, 2, 5, 4, 0, 6]
        let nights = lows.enumerated().map { offset, low in
            WidgetNight(dayKey: dayKey(for: calendar.date(byAdding: .day, value: offset, to: date) ?? date, calendar: calendar),
                        lowC: low, rainMM: offset == 3 ? 4 : 0)
        }
        let lines = [
            WidgetMonthLine(id: "1", name: "Garlic", job: "Plant out", tag: "Last chance", wait: nil, isPressing: true),
            WidgetMonthLine(id: "2", name: "Broad beans", job: "Sow outdoors", tag: "Last chance", wait: nil, isPressing: true),
            WidgetMonthLine(id: "3", name: "Leeks", job: "Harvest", tag: nil, wait: "to March", isPressing: false)
        ]
        return WidgetSummary(
            written: date,
            days: [WidgetDay(dayKey: dayKey(for: date, calendar: calendar), jobs: jobs)],
            months: [WidgetMonth(month: calendar.component(.month, from: date), toSowOrPlant: 12, toHarvest: 18,
                                 inFlower: 8, lastChances: 2, lines: lines)],
            nights: nights,
            answer: WidgetAnswer(headline: "Red admiral", subheading: "Vanessa atalanta", confidence: "Probable",
                                 warning: nil, when: date, hasPhoto: false))
    }
}
