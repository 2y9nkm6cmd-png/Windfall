//
//  WeekJobs.swift
//  Windfall
//
//  "This week" on the Today screen: the jobs that cannot wait.
//
//  "This month" lists everything worth doing in the month. This file
//  picks out the urgent few:
//
//  - a frost, strong wind or a dry spell, from the forecast
//  - the last week a seed can be sown before its sowing months end
//  - the last week to plant out something raised under cover
//  - a crop that should be ready within seven days
//
//  The picking is done by fixed rules, not by the AI model behind Eira.
//  A list of what is urgent has to be the same every time it is worked
//  out, and has to be true. Rules can promise that and can be tested.
//
//  Nothing in this file draws anything or touches the records. The
//  Today screen hands it plain facts (TodayView.swift gathers them) and
//  gets a list back, which is why it can be tested without a screen.
//
//  ⚠️ CHECK: the four weather thresholds near the top of `WeekJobs` are
//  Claude's rules of thumb, not William's. They are easy to change.
//

import Foundation

// MARK: - What the rules are told

/// What the rules need to know about one plant in the library.
struct WeekPlant {
    /// The plant's own identifier, as text.
    let key: String
    let name: String
    /// Month numbers, 1 for January.
    let sowIndoors: [Int]
    let sowOutdoors: [Int]
    /// True if there is a sowing of it dated this year.
    let isSownThisYear: Bool
}

/// What the rules need to know about one sowing.
struct WeekSowing {
    let key: String
    let name: String
    /// Where it is growing, such as "3B, 3C". Empty if not yet placed.
    let beds: String
    /// The months its plant can be planted out.
    let plantOut: [Int]
    /// True if it was raised under cover and is not yet in the ground.
    let isWaitingToGoOut: Bool
    /// When the crop should be ready. Nil if that cannot be worked out,
    /// or if the sowing is no longer growing.
    let cropDue: Date?
}

/// One day of the weather forecast.
struct OutlookDay: Equatable {
    /// The day, written "2026-11-14".
    let dayKey: String
    let minTemperatureC: Double?
    let rainMM: Double?
    /// The strongest gust of the day, in kilometres an hour.
    let gustKMH: Double?
}

// MARK: - What comes back

/// One urgent job.
struct WeekJob: Identifiable, Equatable {

    enum Kind: String {
        case frost, wind, dry, sow, plantOut, harvest
    }

    /// Sowing and harvest jobs use the same identifiers as "This month",
    /// so a job ticked in one list is ticked in the other.
    let id: String
    let kind: Kind
    let title: String
    let detail: String
    /// The key of the plant or sowing it is about, if it is about one.
    let subject: String?
    /// How soon it matters, in days. Used to put the list in order.
    let daysLeft: Int
}

// MARK: - The rules

enum WeekJobs {

    // ⚠️ CHECK: rules of thumb, chosen by Claude on 13 November 2026.

    /// Air this cold or colder is called a frost.
    static let frostC = 0.0
    /// Air this cold can still mean frost on the ground, which is
    /// colder than the air a little above it.
    static let nearFrostC = 2.0
    /// Gusts this strong are worth a warning: 64 km/h is 40 mph.
    static let strongGustKMH = 64.0
    /// A week that has lost this many more millimetres of water to the
    /// air than fell as rain counts as dry.
    static let dryShortfallMM = 15.0
    /// Less rain than this forecast over three days is "little rain".
    static let littleRainMM = 5.0

    /// How many days an urgent job may be away and still be listed.
    static let window = 7

    // MARK: Months

    /// How many days are left in a run of months, counting today.
    ///
    /// `months` is a plant's sowing or planting-out months. If today's
    /// month is one of them, the run carries on through each following
    /// month that is also listed, round the end of the year if need be.
    /// On 28 May, with March, April and May listed, the answer is 4.
    ///
    /// Nil if this month is not listed, or if every month is.
    static func daysLeft(in months: [Int], today: Date, calendar: Calendar = .current) -> Int? {
        let listed = Set(months)
        let month = calendar.component(.month, from: today)
        guard listed.contains(month), listed.count < 12 else { return nil }

        // Count the listed months that follow this one without a gap.
        // `(month + monthsOn) % 12 + 1` is the next month's number, with
        // January following December.
        var monthsOn = 0
        while listed.contains((month + monthsOn) % 12 + 1) { monthsOn += 1 }

        let startOfToday = calendar.startOfDay(for: today)
        guard let thisMonth = calendar.dateInterval(of: .month, for: startOfToday),
              let dayAfterRun = calendar.date(byAdding: .month, value: monthsOn + 1, to: thisMonth.start) else { return nil }
        return calendar.dateComponents([.day], from: startOfToday, to: dayAfterRun).day
    }

    /// How many days are left in this month, counting today.
    static func daysLeftInMonth(today: Date, calendar: Calendar = .current) -> Int {
        daysLeft(in: [calendar.component(.month, from: today)], today: today, calendar: calendar) ?? 31
    }

    // MARK: The list

    /// Works out the urgent jobs.
    ///
    /// - `outlook`: the forecast, one entry a day. May be empty.
    /// - `pastRainMM` and `pastEvaporationMM`: the last seven finished
    ///   days added up, from the weather diary. Nil if not known.
    static func list(today: Date,
                     plants: [WeekPlant],
                     sowings: [WeekSowing],
                     outlook: [OutlookDay],
                     pastRainMM: Double?,
                     pastEvaporationMM: Double?,
                     calendar: Calendar = .current) -> [WeekJob] {
        var found: [WeekJob] = []
        let todayKey = WeatherDiary.dayKey(for: today, calendar: calendar)
        let thisMonth = calendar.monthSymbols[calendar.component(.month, from: today) - 1]

        // The forecast days still to come, each with how far off it is:
        // 0 for today, 1 for tomorrow.
        let coming: [(day: OutlookDay, daysOff: Int)] = outlook.compactMap { day in
            guard let daysOff = WeatherDiary.days(from: todayKey, to: day.dayKey, calendar: calendar),
                  (0...window).contains(daysOff) else { return nil }
            return (day, daysOff)
        }

        // Frost. A day's coldest moment is nearly always around dawn, so
        // the frost is named for the night before: Thursday's low is
        // "Wednesday night".
        let nights = coming.filter { $0.daysOff >= 1 && $0.day.minTemperatureC != nil }
        let frosty = nights.filter { ($0.day.minTemperatureC ?? 99) <= frostC }
        let nearly = nights.filter { ($0.day.minTemperatureC ?? 99) <= nearFrostC }
        if let first = frosty.first, let low = first.day.minTemperatureC {
            let more = frosty.count - 1
            var words = "Down to about \(degrees(low)). Cover or bring in anything tender before dark."
            if more > 0 { words += " \(more) more frosty \(more == 1 ? "night" : "nights") this week." }
            found.append(WeekJob(id: "frost-\(first.day.dayKey)", kind: .frost,
                                 title: "Frost \(nightName(before: first.day.dayKey, daysOff: first.daysOff, calendar: calendar))",
                                 detail: words, subject: nil, daysLeft: first.daysOff))
        } else if let first = nearly.first, let low = first.day.minTemperatureC {
            found.append(WeekJob(id: "frost-\(first.day.dayKey)", kind: .frost,
                                 title: "Close to freezing \(nightName(before: first.day.dayKey, daysOff: first.daysOff, calendar: calendar))",
                                 detail: "About \(degrees(low)) in the air, which can mean frost on the ground. Tender plants may want covering.",
                                 subject: nil, daysLeft: first.daysOff))
        }

        // Wind: the day with the strongest gusts, if strong enough.
        let windiest = coming.filter { $0.day.gustKMH != nil }.max { ($0.day.gustKMH ?? 0) < ($1.day.gustKMH ?? 0) }
        if let windiest, let gust = windiest.day.gustKMH, gust >= strongGustKMH {
            let speed = Int(WeatherDiary.milesPerHour(gust).rounded())
            found.append(WeekJob(id: "wind-\(windiest.day.dayKey)", kind: .wind,
                                 title: "Strong wind \(dayName(windiest.day.dayKey, daysOff: windiest.daysOff, calendar: calendar))",
                                 detail: "Gusts to about \(speed) mph. Check stakes, ties, netting and covers.",
                                 subject: nil, daysLeft: windiest.daysOff))
        }

        // A dry spell: more water lost than fell last week, and little
        // rain coming in the next three days.
        let nextThreeDays = coming.filter { $0.daysOff <= 2 }
        if let rain = pastRainMM, let lost = pastEvaporationMM, lost - rain >= dryShortfallMM, nextThreeDays.count == 3 {
            let rainComing = nextThreeDays.reduce(0) { $0 + ($1.day.rainMM ?? 0) }
            if rainComing < littleRainMM {
                let week = calendar.component(.weekOfYear, from: today)
                found.append(WeekJob(id: "dry-\(calendar.component(.yearForWeekOfYear, from: today))-\(week)", kind: .dry,
                                     title: "Dry spell: water this week",
                                     detail: "About \(Int(rain.rounded())) mm of rain in the last week against \(Int(lost.rounded())) mm lost to the air, and little forecast. Pots and new plantings first.",
                                     subject: nil, daysLeft: 0))
            }
        }

        // The last week to sow. Indoor and outdoor months are taken
        // together: if sowing indoors ends this month and sowing
        // outdoors opens next month, nothing is closing.
        for candidate in plants where !candidate.isSownThisYear {
            guard let left = daysLeft(in: candidate.sowIndoors + candidate.sowOutdoors, today: today, calendar: calendar),
                  left <= window else { continue }
            let month = calendar.component(.month, from: today)
            let indoors = candidate.sowIndoors.contains(month), outdoors = candidate.sowOutdoors.contains(month)
            let place = indoors && outdoors ? "Indoors or outdoors" : (indoors ? "Indoors" : "Outdoors")
            found.append(WeekJob(id: "sow-\(candidate.key)", kind: .sow,
                                 title: "\(lastChance(left)) to sow \(candidate.name)",
                                 detail: "\(place). Its sowing months end with \(thisMonth).",
                                 subject: candidate.key, daysLeft: left))
        }

        for sowing in sowings {
            // The last week to plant out.
            if sowing.isWaitingToGoOut,
               let left = daysLeft(in: sowing.plantOut, today: today, calendar: calendar), left <= window {
                let place = sowing.beds.isEmpty ? "" : "For \(sowing.beds). "
                found.append(WeekJob(id: "plantout-\(sowing.key)", kind: .plantOut,
                                     title: "\(lastChance(left)) to plant out \(sowing.name)",
                                     detail: "\(place)Its planting-out months end with \(thisMonth).",
                                     subject: sowing.key, daysLeft: left))
            }

            // A crop due within the week, or up to a fortnight overdue.
            // Anything later than that stays in "This month".
            if let due = sowing.cropDue,
               let daysOff = calendar.dateComponents([.day], from: calendar.startOfDay(for: today),
                                                     to: calendar.startOfDay(for: due)).day,
               (-14...window).contains(daysOff) {
                let when: String
                if daysOff < 0 {
                    when = "Should have been ready \(-daysOff) \(daysOff == -1 ? "day" : "days") ago"
                } else if daysOff == 0 {
                    when = "Should be ready today"
                } else {
                    when = "Should be ready \(dayName(WeatherDiary.dayKey(for: due, calendar: calendar), daysOff: daysOff, calendar: calendar))"
                }
                found.append(WeekJob(id: "harvest-\(sowing.key)", kind: .harvest,
                                     title: "Harvest \(sowing.name)",
                                     detail: sowing.beds.isEmpty ? "\(when)." : "\(when). \(sowing.beds).",
                                     subject: sowing.key, daysLeft: max(daysOff, 0)))
            }
        }

        // Weather first, then whatever runs out soonest.
        return found.sorted { first, second in
            let firstIsWeather = isWeather(first.kind), secondIsWeather = isWeather(second.kind)
            if firstIsWeather != secondIsWeather { return firstIsWeather }
            if first.daysLeft != second.daysLeft { return first.daysLeft < second.daysLeft }
            return first.title < second.title
        }
    }

    private static func isWeather(_ kind: WeekJob.Kind) -> Bool {
        kind == .frost || kind == .wind || kind == .dry
    }

    // MARK: Wording

    private static func lastChance(_ daysLeft: Int) -> String {
        daysLeft <= 1 ? "Last day" : "Last week"
    }

    /// "-2°C". Whole degrees are as exact as a forecast deserves.
    private static func degrees(_ value: Double) -> String {
        "\(Int(value.rounded()))°C"
    }

    /// "today", "tomorrow" or "on Thursday".
    private static func dayName(_ dayKey: String, daysOff: Int, calendar: Calendar) -> String {
        if daysOff == 0 { return "today" }
        if daysOff == 1 { return "tomorrow" }
        guard let date = WeatherDiary.date(forKey: dayKey, calendar: calendar) else { return "this week" }
        return "on \(calendar.weekdaySymbols[calendar.component(.weekday, from: date) - 1])"
    }

    /// The night before a day: "tonight" or "on Wednesday night".
    private static func nightName(before dayKey: String, daysOff: Int, calendar: Calendar) -> String {
        if daysOff <= 1 { return "tonight" }
        guard let date = WeatherDiary.date(forKey: dayKey, calendar: calendar),
              let evening = calendar.date(byAdding: .day, value: -1, to: date) else { return "this week" }
        return "on \(calendar.weekdaySymbols[calendar.component(.weekday, from: evening) - 1]) night"
    }

    // MARK: Reading the forecast

    /// The part of the weather service's reply that holds the days ahead.
    private struct OutlookReply: Decodable {
        struct Daily: Decodable {
            let time: [String]
            let temperature_2m_min: [Double?]?
            let precipitation_sum: [Double?]?
            let wind_gusts_10m_max: [Double?]?
        }
        let daily: Daily?
    }

    /// Turns the weather service's reply into one entry a day. A reply
    /// with no days in it gives an empty list.
    static func outlook(from data: Data) -> [OutlookDay] {
        guard let daily = (try? JSONDecoder().decode(OutlookReply.self, from: data))?.daily else { return [] }
        func value(_ figures: [Double?]?, _ index: Int) -> Double? {
            guard let figures, figures.indices.contains(index) else { return nil }
            return figures[index]
        }
        return daily.time.enumerated().map { index, day in
            OutlookDay(dayKey: day,
                       minTemperatureC: value(daily.temperature_2m_min, index),
                       rainMM: value(daily.precipitation_sum, index),
                       gustKMH: value(daily.wind_gusts_10m_max, index))
        }
    }
}
