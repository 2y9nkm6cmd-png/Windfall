//
//  SafetyCopyPlan.swift
//  Windfall
//
//  The rules for safety copies, kept apart from the copying itself so
//  the logic tests can check them without a device (Tools/checks).
//
//  A safety copy is the whole of Windfall's records on one device,
//  photos included, copied into a dated folder beside the records
//  themselves. One is made by itself once a day when Windfall opens,
//  and the newest seven are kept. Any of them can be put back. Built
//  20 November 2026 (knowledge base docs 123 and 138), so that a day's
//  records can be got back before Eira is ever allowed to fill in cards
//  that change them.
//
//  The copying is in SafetyCopy.swift. This file only decides: what a
//  copy's folder is called, whether a new one is due, which old ones to
//  let go, and the words that describe one.
//
//  `nonisolated` in front of each type: in this project everything runs
//  on the main thread unless it says otherwise (the build setting
//  "default actor isolation: MainActor"). These are used by the copying,
//  which runs away from the main thread so the screen never freezes, so
//  they say they may be used from anywhere. They hold no shared state,
//  so that is safe.
//

import Foundation

/// Why a copy was made.
nonisolated enum SafetyCopyKind: String, Codable {
    /// Made by itself, the first time Windfall opened that day.
    case daily
    /// Made with Make a safety copy now.
    case byHand
    /// Made just before another copy was put back, so that putting a
    /// copy back can itself be undone.
    case beforePuttingBack

    /// How the list in Settings names it.
    var words: String {
        switch self {
        case .daily: return "Made by itself"
        case .byHand: return "Made by hand"
        case .beforePuttingBack: return "Made before a copy was put back"
        }
    }
}

/// What is written beside each copy, in a small file called
/// `about.json`, so the list can describe a copy without opening it.
///
/// `Codable` means it can be turned into JSON text and back.
nonisolated struct SafetyCopyNote: Codable, Equatable {
    var made: Date
    var kind: SafetyCopyKind
    /// How many plants and photos the copy holds, counted in the copy
    /// itself once it was made. Nil if they could not be counted.
    var plants: Int?
    var photos: Int?
    /// The size of the whole folder, photos included, in bytes.
    var bytes: Int64
    /// True when SQLite's own check of the copied database found
    /// nothing wrong (`PRAGMA quick_check`).
    var checkedWhole: Bool
}

nonisolated enum SafetyCopyPlan {

    /// How many copies are kept. The newest copy made before a copy was
    /// put back is kept as well, whatever its age, so a put-back can
    /// always be undone.
    static let keep = 7

    /// The folder for a copy: "Safety copy 2026-11-20 203512". The date
    /// and time first, so the folders sort by age; seconds, so two made
    /// in the same minute do not share a name. Written the same way on
    /// every device whatever its language (`en_US_POSIX` is Apple's
    /// fixed, never-changing form for dates written for machines).
    static func folderName(made: Date, timeZone: TimeZone = .current) -> String {
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.timeZone = timeZone
        format.dateFormat = "yyyy-MM-dd HHmmss"
        return "Safety copy " + format.string(from: made)
    }

    /// True when no copy has been made yet today, so today's should be
    /// made now. "Today" is the calendar day where the device is, so a
    /// copy made at 23:50 does not stop one being made at 00:10.
    static func isDailyDue(newest: Date?, now: Date, calendar: Calendar = .current) -> Bool {
        guard let newest else { return true }
        return !calendar.isDate(newest, inSameDayAs: now)
    }

    /// Which copies to let go, by folder name, oldest first.
    ///
    /// The `keep` newest stay. So does the newest copy made before a
    /// put-back, even if it is older than those.
    static func toLetGo(_ copies: [(name: String, about: SafetyCopyNote)], keep: Int = keep) -> [String] {
        let newestFirst = copies.sorted { $0.about.made > $1.about.made }
        var keeping = Set(newestFirst.prefix(keep).map(\.name))
        if let undo = newestFirst.first(where: { $0.about.kind == .beforePuttingBack }) {
            keeping.insert(undo.name)
        }
        return newestFirst.reversed().map(\.name).filter { !keeping.contains($0) }
    }

    /// "4.2 MB", "860 KB", "12 bytes". Written here rather than with
    /// Apple's formatter so it reads the same on every device and in the
    /// tests.
    static func sizeWords(_ bytes: Int64) -> String {
        let kilo = 1000.0
        let value = Double(bytes)
        if value >= kilo * kilo * kilo { return String(format: "%.1f GB", value / (kilo * kilo * kilo)) }
        if value >= kilo * kilo { return String(format: "%.1f MB", value / (kilo * kilo)) }
        if value >= kilo { return "\(Int((value / kilo).rounded())) KB" }
        return bytes == 1 ? "1 byte" : "\(bytes) bytes"
    }

    /// The line under a copy's date: "376 plants, 11 photos, 4.2 MB".
    /// With a warning first if SQLite found something wrong in it.
    static func summary(_ about: SafetyCopyNote) -> String {
        var parts: [String] = []
        if let plants = about.plants { parts.append(plants == 1 ? "1 plant" : "\(plants) plants") }
        if let photos = about.photos { parts.append(photos == 1 ? "1 photo" : "\(photos) photos") }
        parts.append(sizeWords(about.bytes))
        let line = parts.joined(separator: ", ")
        return about.checkedWhole ? line : "Not whole: SQLite's check found a fault. " + line
    }
}
