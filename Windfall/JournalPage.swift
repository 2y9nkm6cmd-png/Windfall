//
//  JournalPage.swift
//  Windfall
//
//  The sums behind the Journal page: which things fall on which day,
//  what a day is called and what its line of weather says.
//
//  Nothing here draws anything, so it can be tested without a screen.
//  The drawing is in JournalViews.swift.
//

import Foundation

extension TimelineKind {
    /// What one of these is called on its own line: "Sowing", where the
    /// filter's name for the kind is "Sowings".
    var rowName: String {
        switch self {
        case .diary: return "Entry"
        case .planting: return "Sowing"
        case .phenology: return "Flowering or fruiting"
        case .harvest: return "Harvest"
        case .problem: return "Pest or disease"
        case .survey: return "Count"
        case .sighting: return "Sighting"
        }
    }
}

enum JournalPage {

    /// One day's things, newest first.
    struct Day: Identifiable {
        /// Midnight at the start of the day.
        let start: Date
        let items: [TimelineItem]
        var id: Date { start }
    }

    /// One month's days, newest first.
    struct Month: Identifiable {
        /// Midnight on the first of the month.
        let start: Date
        let days: [Day]
        var id: Date { start }
    }

    /// Sorts things into days, and days into months, newest first.
    static func months(of items: [TimelineItem], calendar: Calendar = .current) -> [Month] {
        let byDay = Dictionary(grouping: items) { calendar.startOfDay(for: $0.date) }
        let days = byDay
            .map { Day(start: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.start > $1.start }
        let byMonth = Dictionary(grouping: days) { day in
            calendar.date(from: calendar.dateComponents([.year, .month], from: day.start)) ?? day.start
        }
        return byMonth
            .map { Month(start: $0.key, days: $0.value.sorted { $0.start > $1.start }) }
            .sorted { $0.start > $1.start }
    }

    /// "Today", "Yesterday" or "Friday 13 November". The month's own
    /// heading gives the year.
    static func title(for day: Date, today: Date = .now, calendar: Calendar = .current) -> String {
        let written = day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        if calendar.isDate(day, inSameDayAs: today) { return "Today · \(written)" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           calendar.isDate(day, inSameDayAs: yesterday) {
            return "Yesterday · \(written)"
        }
        return written
    }

    /// The line under a thing's name: "Sighting · 9:14 am". A record
    /// with a day but no time of day, such as a sowing, shows only what
    /// it is. Midnight exactly is taken to mean "no time given".
    static func caption(kind: String, at date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hasTime = (parts.hour ?? 0) != 0 || (parts.minute ?? 0) != 0 || (parts.second ?? 0) != 0
        return hasTime ? "\(kind) · \(date.formatted(.dateTime.hour().minute()))" : kind
    }

    /// The name the weather diary files a day under: "2026-11-13".
    static func dayKey(for day: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// "3 to 9°C · 2.4 mm of rain". Nil if there is nothing to say.
    static func weatherWords(low: Double?, high: Double?, rainMM: Double?) -> String? {
        var parts: [String] = []
        if let low, let high {
            parts.append("\(Int(low.rounded())) to \(Int(high.rounded()))°C")
        } else if let one = high ?? low {
            parts.append("\(Int(one.rounded()))°C")
        }
        if let rainMM {
            parts.append(rainMM < 0.05 ? "dry" : "\((rainMM * 10).rounded() / 10) mm of rain")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
