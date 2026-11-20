//
//  SpeaksFirst.swift
//  Windfall
//
//  Eira speaks first, part one (doc 119, piece 5; doc 140): frost
//  warnings and good days for a FIT count, as notifications.
//
//  The rules (what to say and when) are in SpeaksFirstPlan.swift. This
//  file fetches each placed garden's forecast, asks the rules, and hands
//  what they plan to the system's notification centre, replacing what
//  it planned before.
//
//  THE POWER RULES (doc 91). Nothing here runs while Windfall is
//  closed: no background mode, no background task. It runs only when
//  `WeatherNow.refresh` runs (Windfall opening, coming to the front, a
//  quarter of an hour while open), and then does nothing unless a
//  switch is on and an hour has passed since it last asked. The system
//  keeps the planned notices and shows them at their time, which costs
//  Windfall nothing. The price: if Windfall is not opened for a few
//  days, the warnings come from the last forecast it saw, and stop
//  after three nights. ⚠️ CHECK with William (card d-speaks-background-140).
//

import Foundation
import SwiftData
import SwiftUI
import UserNotifications

@MainActor
enum SpeaksFirst {

    /// The two switches, saved on the device (`@AppStorage` reads them).
    static let frostKey = "speaksFrostWarnings"
    static let fitKey = "speaksFITDays"
    /// When the forecast was last asked for, in seconds since 1970.
    static let lastRunKey = "speaksFirstLastRun"
    /// At most once an hour, like the weather diary.
    static let restSeconds: TimeInterval = 3600

    /// True while a run is under way, so two never overlap.
    private static var isRunning = false

    // MARK: Permission

    /// Whether the system lets Windfall show notifications, asking the
    /// first time. Apple shows its question once only; after a No this
    /// returns false and the switch in Settings explains where to go.
    static func askPermission() async -> Bool {
        let centre = UNUserNotificationCenter.current()
        let settings = await centre.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            return (try? await centre.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }

    // MARK: Planning

    /// Fetches the forecast for every placed garden and replaces the
    /// planned notices. `force` skips the hour's rest (used when a switch
    /// is turned on).
    static func refresh(context: ModelContext, force: Bool = false, now: Date = .now) async {
        let defaults = UserDefaults.standard
        let frostOn = defaults.bool(forKey: frostKey)
        let fitOn = defaults.bool(forKey: fitKey)
        // Never in the example garden, which is for checking and tests.
        guard frostOn || fitOn, !isRunning, !DemoGarden.isRequested else { return }
        if !force, now.timeIntervalSince1970 - defaults.double(forKey: lastRunKey) < restSeconds { return }
        // Not without permission: nothing would be shown.
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }

        isRunning = true
        defer { isRunning = false }

        // The same list of places the weather diary uses: every garden
        // in use with a place, leaving out one within a mile of another.
        let gardens = ((try? context.fetch(FetchDescriptor<Garden>())) ?? []).sorted { $0.displayOrder < $1.displayOrder }
        let places = WeatherDiary.places(for: gardens)
        var forecasts: [SpeakGardenForecast] = []
        for place in places {
            guard let url = SpeaksFirstPlan.forecastURL(latitude: place.latitude, longitude: place.longitude),
                  let data = try? await WeatherDiary.download(url),
                  let days = SpeaksFirstPlan.forecastDays(from: data) else { continue }
            forecasts.append(SpeakGardenForecast(gardenName: place.name, days: days))
        }
        // No signal: leave what was planned last time, and try again at
        // the next chance rather than after an hour.
        if !places.isEmpty && forecasts.isEmpty { return }

        let calendar = Calendar.current
        var notices: [SpeakNotice] = []
        if frostOn {
            notices += SpeaksFirstPlan.frostNotices(forecasts, now: now, calendar: calendar)
        }
        if fitOn {
            let surveys = (try? context.fetch(FetchDescriptor<Survey>())) ?? []
            let counted = Set(surveys.filter { $0.scheme == .fitCount }
                                     .map { WeatherDiary.dayKey(for: $0.startedAt, calendar: calendar) })
            notices += SpeaksFirstPlan.fitNotices(forecasts, countedOn: counted, now: now, calendar: calendar)
        }
        await replace(with: notices, calendar: calendar)
        defaults.set(now.timeIntervalSince1970, forKey: lastRunKey)
    }

    /// Takes away every notice planned here before, and hands the system
    /// the new ones. Reminders planned elsewhere (NotificationService)
    /// are left alone: only names starting `windfall.speaks.` go.
    static func replace(with notices: [SpeakNotice], calendar: Calendar = .current) async {
        await cancel(prefix: SpeaksFirstPlan.idPrefix)
        let centre = UNUserNotificationCenter.current()
        for notice in notices {
            let content = UNMutableNotificationContent()
            content.title = notice.title
            content.body = notice.body
            content.sound = .default
            // A date and time, once, in the device's own calendar.
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: notice.fireAt)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await centre.add(UNNotificationRequest(identifier: notice.id, content: content, trigger: trigger))
        }
    }

    /// Takes away the planned notices whose names start with `prefix`.
    static func cancel(prefix: String) async {
        let centre = UNUserNotificationCenter.current()
        let waiting = await centre.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        centre.removePendingNotificationRequests(withIdentifiers: waiting)
    }
}

// MARK: - The switches in Settings

/// "Eira speaks first": the two switches. Shown in Settings and on the
/// Reminders page; both read the same saved settings.
struct SpeaksFirstSection: View {

    @Environment(\.modelContext) private var context
    @AppStorage(SpeaksFirst.frostKey) private var frostOn = false
    @AppStorage(SpeaksFirst.fitKey) private var fitOn = false
    /// True after the system said no, so the page can say where to go.
    @State private var wasRefused = false
    @Query private var gardens: [Garden]

    var body: some View {
        Section {
            Toggle("Frost warnings", isOn: turning($frostOn, prefix: SpeaksFirstPlan.frostPrefix))
            Toggle("Good days for a FIT count", isOn: turning($fitOn, prefix: SpeaksFirstPlan.fitPrefix))
            if wasRefused {
                Text("Notifications are off for Windfall. Turn them on in the device's Settings, under Notifications, then Windfall.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
            if (frostOn || fitOn) && !gardens.contains(where: { $0.isActive && $0.latitude != nil }) {
                Text("No garden has a place on the map yet, so there is no forecast to go on. Give one a place above.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
        } header: {
            Text("Eira speaks first")
        } footer: {
            Text("A frost warning at 4 pm when a garden's forecast drops below 1 °C overnight, up to three nights ahead. From April to September, a note at 9:30 on the first coming day dry, still and warm enough for a FIT count. Both use the forecast fetched while Windfall is open, at most once an hour: nothing runs while it is closed, to spare the battery.")
        }
    }

    /// A switch that asks for permission when turned on, and takes away
    /// its planned notices when turned off. `Binding` lets the switch
    /// read and change the value through these two small pieces of code
    /// rather than directly.
    private func turning(_ value: Binding<Bool>, prefix: String) -> Binding<Bool> {
        Binding(
            get: { value.wrappedValue },
            set: { wanted in
                if wanted {
                    Task {
                        // The system's question comes up the first time.
                        if await SpeaksFirst.askPermission() {
                            wasRefused = false
                            value.wrappedValue = true
                            await SpeaksFirst.refresh(context: context, force: true)
                        } else {
                            wasRefused = true
                        }
                    }
                } else {
                    value.wrappedValue = false
                    Task { await SpeaksFirst.cancel(prefix: prefix) }
                }
            })
    }
}
