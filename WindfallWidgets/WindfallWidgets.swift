//
//  WindfallWidgets.swift
//  WindfallWidgets
//
//  The widget program itself, for iPhone, iPad and Mac.
//
//  How a widget works. iOS does not run a widget all the time. It asks
//  for a "timeline": a stack of ready-made cards, each with the time it
//  should go on show. iOS then shows each card at its time, and asks
//  again when the stack runs out or the app says something has changed.
//
//  The three parts below:
//    1. What can be chosen and pressed (the look, and ticking a job)
//    2. The timeline: reading the shared file and making the cards
//    3. The widgets, each wrapping one view from WidgetViews.swift
//
//  The drawing is all in WindfallShared/WidgetViews.swift.
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - 1. What can be chosen and pressed

/// The look, as offered when you press and hold a widget and choose
/// "Edit Widget". `AppEnum` is what lets iOS list the choices.
enum LookChoice: String, AppEnum {
    case paper, green

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Look"
    static let caseDisplayRepresentations: [LookChoice: DisplayRepresentation] = [
        .paper: "Paper", .green: "Garden green"
    ]
}

/// The one setting every Windfall widget has.
struct LookIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Look"
    static let description: IntentDescription? = IntentDescription("Paper follows light and dark mode. Garden green is the sidebar's green.")

    @Parameter(title: "Look", default: .paper)
    var look: LookChoice
}

/// Ticks a job off, or unticks it, from the large "This week" widget.
/// It runs here in the widget program: the app is not opened. The tick
/// is kept in the shared settings, where Today reads it too.
struct TickJobIntent: AppIntent {
    static let title: LocalizedStringResource = "Tick off a job"

    @Parameter(title: "Job")
    var jobID: String

    init() {}
    init(jobID: String) { self.jobID = jobID }

    func perform() async throws -> some IntentResult {
        if let defaults = WindfallGroup.defaults {
            let line = defaults.string(forKey: WidgetTicks.key) ?? ""
            defaults.set(WidgetTicks.toggling(jobID, in: line), forKey: WidgetTicks.key)
        }
        // iOS asks for a fresh timeline by itself after a widget's
        // button has run, so the tick shows at once.
        return .result()
    }
}

// MARK: - 2. The timeline

/// One card: everything a widget needs to draw itself at one moment.
struct WindfallEntry: TimelineEntry {
    let date: Date
    let summary: WidgetSummary?
    let ticked: Set<String>
    let look: WidgetLook
    let photo: CGImage?

    var palette: WidgetPalette { .of(look) }
}

struct WindfallProvider: AppIntentTimelineProvider {

    private func look(_ intent: LookIntent) -> WidgetLook { intent.look == .green ? .green : .paper }

    /// The made-up card shown while a real one is being fetched.
    func placeholder(in context: Context) -> WindfallEntry {
        WindfallEntry(date: .now, summary: .example(), ticked: ["harvest-example"], look: .paper, photo: nil)
    }

    /// The card shown in the widget gallery. Example content there, so
    /// the gallery never looks empty. Real content everywhere else.
    func snapshot(for configuration: LookIntent, in context: Context) async -> WindfallEntry {
        if context.isPreview {
            return WindfallEntry(date: .now, summary: .example(), ticked: ["harvest-example"],
                                 look: look(configuration), photo: nil)
        }
        return entry(at: .now, configuration)
    }

    /// One card for now and one for each of the next seven midnights,
    /// because every widget's content turns over with the day.
    ///
    /// Before the cards are made, the forecast is fetched afresh if the
    /// one in the file is more than three hours old, so the widgets keep
    /// up with the weather without the app being opened. See
    /// WindfallShared/WidgetForecast.swift.
    func timeline(for configuration: LookIntent, in context: Context) async -> Timeline<WindfallEntry> {
        let calendar = Calendar.current
        var times: [Date] = [.now]
        let startOfToday = calendar.startOfDay(for: .now)
        for day in 1...7 {
            if let midnight = calendar.date(byAdding: .day, value: day, to: startOfToday) { times.append(midnight) }
        }
        // Reads the file, and fetches a new forecast first if one is due.
        let summary = await WidgetForecast.refreshIfDue()
        let ticked = WidgetTicks.current()
        let photo = widgetLastPhoto()
        let entries = times.map {
            WindfallEntry(date: $0, summary: summary, ticked: ticked, look: look(configuration), photo: photo)
        }
        // When to be asked again. `.after` names a time: three hours
        // after the forecast was fetched. Where the file names no place
        // to ask about, `.atEnd` waits until the last card has been
        // shown. The app also asks whenever it writes the file.
        if let nextLook = WidgetForecast.nextLook(summary) {
            return Timeline(entries: entries, policy: .after(nextLook))
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func entry(at date: Date, _ configuration: LookIntent) -> WindfallEntry {
        WindfallEntry(date: date, summary: WidgetSummaryStore.read(), ticked: WidgetTicks.current(),
                      look: look(configuration), photo: widgetLastPhoto())
    }
}

// MARK: - 3. The widgets

extension View {
    /// What every Home Screen widget needs: its background, handed to
    /// iOS so it can be swapped for glass or a tint, and the place a
    /// tap on the widget as a whole opens.
    func windfallWidget(_ palette: WidgetPalette, opens url: URL) -> some View {
        containerBackground(palette.ground, for: .widget).widgetURL(url)
    }
}

/// The Lock Screen shapes, which exist only on iPhone and iPad. On a
/// Mac both lists are empty, so a widget there offers its other sizes.
enum WidgetShapes {
    #if os(iOS)
    static let weekLockScreen: [WidgetFamily] = [.accessoryInline, .accessoryCircular, .accessoryRectangular]
    static let lockScreenCircle: [WidgetFamily] = [.accessoryCircular]
    #else
    static let weekLockScreen: [WidgetFamily] = []
    static let lockScreenCircle: [WidgetFamily] = []
    #endif
}

private extension WidgetFamily {
    var size: WidgetSize {
        switch self {
        case .systemSmall: return .small
        case .systemLarge, .systemExtraLarge: return .large
        default: return .medium
        }
    }
}

// This week, on the Home Screen and the Lock Screen.

struct WeekWidgetBody: View {
    let entry: WindfallEntry
    // Which shape iOS is asking for: small, medium, a Lock Screen circle…
    @Environment(\.widgetFamily) private var family

    private var jobs: [WidgetJob]? { entry.summary?.jobs(on: entry.date) }
    private var toDo: [WidgetJob] { (jobs ?? []).filter { !entry.ticked.contains($0.id) } }

    var body: some View {
        #if os(iOS)
        // The Lock Screen shapes. A Mac has none, and the `#if` keeps
        // these lines out of the Mac's copy of the program altogether.
        switch family {
        case .accessoryInline:
            // The single line above the Lock Screen's clock.
            Label(toDo.first?.title ?? "Nothing pressing this week", systemImage: "leaf")
                .widgetURL(WidgetLink.today)
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: -2) {
                    Text("\(toDo.count)").font(.system(size: 24, weight: .semibold))
                    Text(toDo.count == 1 ? "job" : "jobs").font(.system(size: 11))
                }
            }
            .containerBackground(.clear, for: .widget)
            .widgetURL(WidgetLink.today)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text("This week").font(.system(size: 12, weight: .semibold))
                Text(toDo.first?.title ?? "Nothing pressing").font(.system(size: 14, weight: .semibold)).lineLimit(1)
                if toDo.count > 1 { Text("\(toDo.count - 1) more").font(.system(size: 12)) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(.clear, for: .widget)
            .widgetURL(WidgetLink.today)
        default:
            home
        }
        #else
        home
        #endif
    }

    /// The Home Screen and desktop sizes.
    private var home: some View {
        WeekWidgetView(jobs: jobs, ticked: entry.ticked, size: family.size, palette: entry.palette,
                       tickControl: { job, ring in
                           // Button(intent:) is the kind of button a
                           // widget may have: it runs TickJobIntent.
                           AnyView(Button(intent: TickJobIntent(jobID: job.id)) { ring }.buttonStyle(.plain))
                       })
            .windfallWidget(entry.palette, opens: WidgetLink.today)
    }
}

struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WindfallWeek", intent: LookIntent.self, provider: WindfallProvider()) {
            WeekWidgetBody(entry: $0)
        }
        .configurationDisplayName("This week")
        .description("The jobs that will not wait: frost, wind, last chances to sow and crops that are ready.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge] + WidgetShapes.weekLockScreen)
    }
}

// This month.

struct MonthWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WindfallMonth", intent: LookIntent.self, provider: WindfallProvider()) { entry in
            MonthWidgetBody(entry: entry)
        }
        .configurationDisplayName("This month")
        .description("How much there is to sow, plant and pick this month, and what is on its last chance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MonthWidgetBody: View {
    let entry: WindfallEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        MonthWidgetView(month: entry.summary?.month(on: entry.date), size: family.size, palette: entry.palette)
            .windfallWidget(entry.palette, opens: WidgetLink.today)
    }
}

// Frost and weather.

struct FrostWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WindfallFrost", intent: LookIntent.self, provider: WindfallProvider()) { entry in
            FrostWidgetBody(entry: entry)
        }
        .configurationDisplayName("Frost and weather")
        .description("Tonight's lowest temperature, and the next five nights.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FrostWidgetBody: View {
    let entry: WindfallEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        FrostWidgetView(tonightC: entry.summary?.tonight(on: entry.date)?.lowC,
                        nights: entry.summary?.comingNights(from: entry.date) ?? [],
                        rain: entry.summary?.nextRain(from: entry.date),
                        size: family.size, palette: entry.palette)
            .windfallWidget(entry.palette, opens: WidgetLink.today)
    }
}

// Identify: the button, and the button with Eira's last answer.

struct IdentifyWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WindfallIdentify", intent: LookIntent.self, provider: WindfallProvider()) { entry in
            IdentifyWidgetBody(entry: entry)
        }
        .configurationDisplayName("Identify")
        .description("Give Eira a photo. The wider one also shows her last answer.")
        .supportedFamilies([.systemSmall, .systemMedium] + WidgetShapes.lockScreenCircle)
    }
}

struct IdentifyWidgetBody: View {
    let entry: WindfallEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        #if os(iOS)
        if family == .accessoryCircular {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "camera").font(.system(size: 24))
            }
            .accessibilityLabel("Identify")
            .containerBackground(.clear, for: .widget)
            .widgetURL(WidgetLink.identify)
        } else {
            home
        }
        #else
        home
        #endif
    }

    private var home: some View {
        IdentifyWidgetView(answer: entry.summary?.answer, photo: entry.photo,
                           style: family == .systemSmall ? .button : .withAnswer, palette: entry.palette)
            .windfallWidget(entry.palette, opens: WidgetLink.identify)
    }
}

// Eira's last answer alone, under its photo.

struct LastAnswerWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WindfallLastAnswer", intent: LookIntent.self, provider: WindfallProvider()) { entry in
            IdentifyWidgetView(answer: entry.summary?.answer, photo: entry.photo, style: .answerOnly, palette: entry.palette)
                .windfallWidget(entry.palette, opens: WidgetLink.identify)
        }
        .configurationDisplayName("Last answer")
        .description("The last thing Eira named from a photo.")
        .supportedFamilies([.systemSmall])
        // The photo runs to the widget's edges, so iOS's own margins
        // are switched off and the view keeps its own.
        .contentMarginsDisabled()
    }
}

// Capture.

struct CaptureWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WindfallCapture", intent: LookIntent.self, provider: WindfallProvider()) { entry in
            CaptureWidgetView(palette: entry.palette)
                .windfallWidget(entry.palette, opens: WidgetLink.today)
        }
        .configurationDisplayName("Capture")
        .description("The six buttons from Today: a sowing, a harvest, a sighting, a FIT Count, a note or a photo.")
        .supportedFamilies([.systemMedium])
    }
}

// Ask Eira.

struct EiraWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WindfallEira", intent: LookIntent.self, provider: WindfallProvider()) { entry in
            EiraWidgetBody(entry: entry)
        }
        .configurationDisplayName("Ask Eira")
        .description("Opens Eira's chat.")
        .supportedFamilies([.systemSmall] + WidgetShapes.lockScreenCircle)
    }
}

struct EiraWidgetBody: View {
    let entry: WindfallEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        #if os(iOS)
        if family == .accessoryCircular {
            ZStack {
                AccessoryWidgetBackground()
                WidgetSnowdrop().fill(.primary).padding(12)
            }
            .accessibilityLabel("Ask Eira")
            .containerBackground(.clear, for: .widget)
            .widgetURL(WidgetLink.eira)
        } else {
            home
        }
        #else
        home
        #endif
    }

    private var home: some View {
        EiraWidgetView(palette: entry.palette)
            .windfallWidget(entry.palette, opens: WidgetLink.eira)
    }
}

// MARK: - The list of widgets

/// `@main` marks where the widget program starts. The bundle is the
/// list iOS shows in its widget gallery.
@main
struct WindfallWidgetBundle: WidgetBundle {
    var body: some Widget {
        WeekWidget()
        MonthWidget()
        FrostWidget()
        IdentifyWidget()
        LastAnswerWidget()
        CaptureWidget()
        EiraWidget()
    }
}
