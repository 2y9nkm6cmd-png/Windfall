//
//  NotificationService.swift
//  Windfall
//
//  Reminders that follow the season and the weather rather than the calendar.
//
//  The design decision that matters: a quarterly reminder to do a FIT
//  Count would put two of its four prompts in months with no insects. So
//  prompts are scheduled only inside the recording season, and the app
//  checks conditions before nagging you to go outside.
//
//  Notifications need no entitlement and no Developer Programme
//  membership — just the user's permission.
//

import Foundation
import UserNotifications
import CoreLocation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class NotificationService {

    private(set) var isAuthorised = false
    private(set) var lastError: String?

    private let centre = UNUserNotificationCenter.current()

    // Identifiers, so a reminder can be replaced rather than duplicated.
    private enum ID {
        static let fitCountSeason = "windfall.fitcount.season"
        static let wormCount = "windfall.worm.season"
        static let frostWarning = "windfall.frost.warning"
        static func sowing(_ month: Int) -> String { "windfall.sowing.\(month)" }
    }

    // MARK: Permission

    func requestPermission() async {
        do {
            isAuthorised = try await centre.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshStatus() async {
        let settings = await centre.notificationSettings()
        isAuthorised = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    // MARK: Scheduling

    /// Rebuilds every scheduled reminder from current data.
    /// Cheap to call, so it runs on launch rather than trying to keep
    /// individual notifications in step as records change.
    func rescheduleAll(context: ModelContext) async {
        guard isAuthorised else { return }

        centre.removeAllPendingNotificationRequests()

        await scheduleFITCountPrompts(context: context)
        await scheduleWormCountPrompt()
        await scheduleSowingPrompts(context: context)
    }

    /// A weekly nudge, but only between April and September, and only when
    /// it's been more than ten days since the last count.
    private func scheduleFITCountPrompts(context: ModelContext) async {
        let surveys = (try? context.fetch(FetchDescriptor<Survey>())) ?? []
        let fitCounts = surveys.filter { $0.scheme == .fitCount }
        let latest = fitCounts.map(\.startedAt).max()

        let calendar = Calendar.current
        let now = Date.now
        let month = calendar.component(.month, from: now)

        guard (4...9).contains(month) else { return }

        if let latest, calendar.dateComponents([.day], from: latest, to: now).day ?? 0 < 10 {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Time for a FIT Count"
        content.body = latest == nil
            ? "Ten minutes watching one flower. The season runs to 30 September."
            : "It's been a while since the last one. Dry weather and 13°C in sun is all it takes."
        content.sound = .default

        // Late morning, when insects are active and it's usually warmest.
        var components = DateComponents()
        components.hour = 11
        components.minute = 30
        components.weekday = 7   // Saturday

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: ID.fitCountSeason,
                                            content: content, trigger: trigger)
        try? await centre.add(request)
    }

    /// Spring and autumn only. Worms sit deeper in high summer and hard
    /// frost, so counts made then undercount badly and aren't comparable.
    private func scheduleWormCountPrompt() async {
        let month = Calendar.current.component(.month, from: .now)
        guard [3, 4, 5, 9, 10, 11].contains(month) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Good month for an earthworm count"
        content.body = "A 20 cm pit, five minutes of hand-sorting. Spring and autumn are the only times it's comparable."
        content.sound = .default

        var components = DateComponents()
        components.day = 15
        components.hour = 10

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try? await centre.add(UNNotificationRequest(
            identifier: ID.wormCount, content: content, trigger: trigger))
    }

    /// One prompt per month listing what's sowable, built from the
    /// spreadsheet's own month text.
    private func scheduleSowingPrompts(context: ModelContext) async {
        let plants = (try? context.fetch(FetchDescriptor<Plant>())) ?? []
        let calendar = Calendar.current
        let thisMonth = calendar.component(.month, from: .now)

        // Next three months, so there's always something queued.
        for offset in 0..<3 {
            let month = ((thisMonth - 1 + offset) % 12) + 1

            let sowable = plants.filter { plant in
                plant.status == .growing &&
                (MonthParser.months(in: plant.sowIndoorsMonthsText).contains(month)
                 || MonthParser.months(in: plant.sowOutdoorsMonthsText).contains(month))
            }

            guard sowable.count >= 3 else { continue }

            let names = sowable.prefix(4).map(\.commonName).joined(separator: ", ")

            let content = UNMutableNotificationContent()
            content.title = "Sowing this month"
            content.body = sowable.count > 4
                ? "\(names) and \(sowable.count - 4) more are ready to sow."
                : "\(names) are ready to sow."
            content.sound = .default

            var components = DateComponents()
            components.day = 1
            components.month = month
            components.hour = 9

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            try? await centre.add(UNNotificationRequest(
                identifier: ID.sowing(month), content: content, trigger: trigger))
        }
    }

    /// Fired when the forecast shows a frost coming — worth knowing the
    /// night before rather than the morning after.
    func scheduleFrostWarning(minimumC: Double, on date: Date) async {
        guard isAuthorised, minimumC <= 2 else { return }

        let content = UNMutableNotificationContent()
        content.title = minimumC <= 0 ? "Frost forecast tonight" : "Near-freezing tonight"
        content.body = String(format: "Down to %.0f°C. Anything tender wants covering or bringing in.", minimumC)
        content.sound = .default

        // Late afternoon, while there's still light to do something.
        guard let fireDate = Calendar.current.date(
            bySettingHour: 16, minute: 0, second: 0,
            of: date.addingTimeInterval(-86_400)) else { return }
        guard fireDate > .now else { return }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        try? await centre.add(UNNotificationRequest(
            identifier: ID.frostWarning, content: content, trigger: trigger))
    }

    func cancelAll() {
        centre.removeAllPendingNotificationRequests()
    }
}

// MARK: - Settings section

struct NotificationSettingsView: View {

    @Environment(\.modelContext) private var context
    @State private var service = NotificationService()

    var body: some View {
        Form {
            Section {
                if service.isAuthorised {
                    Label("Reminders are on", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)

                    Button("Reschedule now") {
                        Task { await service.rescheduleAll(context: context) }
                    }

                    Button("Turn off all reminders", role: .destructive) {
                        service.cancelAll()
                    }
                } else {
                    Button("Turn on reminders") {
                        Task {
                            await service.requestPermission()
                            await service.rescheduleAll(context: context)
                        }
                    }
                }
            } header: {
                Text("Reminders")
            } footer: {
                Text("Prompts follow the season rather than the calendar: FIT Counts only between April and September, earthworm counts only in spring and autumn, and sowing lists built from your own spreadsheet.")
            }

            Section("What you'll get") {
                Label("Weekly FIT Count nudge, in season only", systemImage: "camera.macro")
                Label("Earthworm count in spring and autumn", systemImage: "chart.bar.doc.horizontal")
                Label("Monthly list of what's sowable", systemImage: "leaf")
                Label("Frost warning the afternoon before", systemImage: "snowflake")
            }
            .font(.callout)
        }
        .navigationTitle("Reminders")
        .task { await service.refreshStatus() }
    }
}
