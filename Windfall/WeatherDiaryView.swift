//
//  WeatherDiaryView.swift
//  Windfall
//
//  The Weather page: what the weather diary holds, drawn in the same way
//  as Today. A few figures at the top, the last month as two charts, the
//  days one by one, and this year's frosts.
//
//  The record itself and the fetching are in WeatherDiary.swift.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - The page

struct WeatherDiaryView: View {

    // Newest first.
    @Query(sort: [SortDescriptor(\WeatherDay.dayKey, order: .reverse)]) private var allDays: [WeatherDay]
    @Query(sort: [SortDescriptor(\Garden.displayOrder)]) private var gardens: [Garden]
    @Query(sort: [SortDescriptor(\FrostRecord.date, order: .reverse)]) private var frosts: [FrostRecord]

    @Environment(\.modelContext) private var context

    @State private var service = WeatherDiaryService()
    /// Which garden's weather is shown, when more than one has a diary.
    @State private var shownSite: String?
    /// How many days the list shows. "Show more" adds a month.
    @State private var listed = 14

    private var places: [WeatherDiary.Place] { WeatherDiary.places(for: gardens) }

    var body: some View {
        let places = self.places
        let site = places.first { $0.site == shownSite }?.site ?? places.first?.site
        // One garden's days, newest first.
        let days = allDays.filter { $0.siteRaw == site }

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Weather", detail: headline(days))

                if places.count > 1, let site {
                    GlassSwitch(choices: places.map(\.site),
                                selection: Binding(get: { site }, set: { shownSite = $0 })) { key in
                        places.first { $0.site == key }?.name ?? key
                    }
                }

                if places.isEmpty {
                    explainer("The diary needs to know where a garden is.",
                              "Open a garden from the Gardens page, choose Edit layout and set its location. The weather for the last three months then fills in by itself.")
                } else if days.isEmpty {
                    explainer(service.isWorking ? "Fetching the last three months…" : "No weather recorded yet.",
                              service.lastError ?? "It fills in when the app can reach the weather service.")
                } else {
                    figures(days)
                    charts(days)
                    dayList(days)
                    frostCard
                }

                footer(hasDays: !days.isEmpty, hasPlaces: !places.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .paperScreen()
        .navigationTitle("Weather")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        // The large "Weather" above is the title. The bar keeps the name
        // for the back button and VoiceOver, but shows no words of its own.
        .toolbar { ToolbarItem(placement: .principal) { Text("") } }
        .eiraLooksAt("the weather diary, with each day's temperatures, rain and frosts")
        // Bring the diary up to date when the page opens. It asks the
        // service at most once an hour, so this costs nothing if the app
        // has only just done it.
        .task { await service.bringUpToDate(in: context) }
    }

    // MARK: The line above the title

    /// "92 days recorded, since 12 August 2026".
    private func headline(_ days: [WeatherDay]) -> String {
        guard let earliest = days.last else { return "A record of every day's weather" }
        let since = earliest.date.formatted(.dateTime.day().month(.wide).year())
        return "\(days.count) day\(days.count == 1 ? "" : "s") recorded, since \(since)"
    }

    // MARK: Figures

    /// Four small cards: the latest finished day, the week's rain, the
    /// soil, and the last frost.
    private func figures(_ days: [WeatherDay]) -> some View {
        let finished = days.filter(\.isComplete)
        let latest = finished.first
        let week = finished.prefix(7)
        let weekRain = week.compactMap(\.rainfallMM).reduce(0, +)
        let weekLoss = week.compactMap(\.evaporationMM).reduce(0, +)
        let lastFrost = frosts.first

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
            FigureCard(title: latest.map { relativeDay($0.date) } ?? "Yesterday",
                       figure: latest.flatMap { day in
                           day.minTemperatureC.flatMap { low in
                               day.maxTemperatureC.map { "\(WeatherDiary.degrees(low)) to \(WeatherDiary.degrees($0))" }
                           }
                       } ?? "No figures",
                       detail: WeatherDiary.words(forCode: latest?.weatherCode))
            FigureCard(title: "Rain, last 7 days",
                       figure: "\(weekRain.formatted(.number.precision(.fractionLength(1)))) mm",
                       // Rain in against water lost to the air.
                       detail: weekLoss > 0 ? "\(weekLoss.formatted(.number.precision(.fractionLength(1)))) mm lost to the air" : nil)
            FigureCard(title: "Soil at seed depth",
                       figure: latest?.soilTemperatureC.map { WeatherDiary.degrees($0) } ?? "No figure",
                       detail: latest?.soilTemperatureC.map { $0 < 7 ? "Too cold for most seed" : "Warm enough for hardy seed" })
            FigureCard(title: "Last frost",
                       figure: lastFrost.map { $0.date.formatted(.dateTime.day().month(.abbreviated)) } ?? "None recorded",
                       detail: lastFrost?.minimumTemperatureC.map { "Down to \($0.formatted(.number.precision(.fractionLength(1))))°C" })
        }
    }

    /// "Yesterday", or the day's name and date.
    private func relativeDay(_ date: Date) -> String {
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        if Calendar.current.isDateInToday(date) { return "Today" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }

    // MARK: Charts

    /// The last 30 days: a bar from each day's low to its high, and the
    /// rain beneath.
    private func charts(_ days: [WeatherDay]) -> some View {
        let month = Array(days.prefix(30))
        return VStack(alignment: .leading, spacing: 10) {
            Text("The last 30 days")
                .font(.headline)
                .foregroundStyle(Theme.ink)

            Text("Temperature, coldest to warmest")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
            Chart {
                ForEach(month) { day in
                    if let low = day.minTemperatureC, let high = day.maxTemperatureC {
                        BarMark(x: .value("Day", day.date, unit: .day),
                                yStart: .value("Coldest", low),
                                yEnd: .value("Warmest", high),
                                width: .ratio(0.55))
                            .clipShape(.capsule)
                            // A frosty day stands out in blue.
                            .foregroundStyle(day.hadFrost ? Theme.water : Theme.leaf)
                    }
                }
                // The freezing line.
                RuleMark(y: .value("Freezing", 0))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(Theme.inkSoft.opacity(0.6))
            }
            .chartYAxisLabel("°C")
            .frame(height: 150)
            .accessibilityLabel("Each day's coldest and warmest temperature over the last 30 days")

            Text("Rain")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
            Chart {
                ForEach(month) { day in
                    BarMark(x: .value("Day", day.date, unit: .day),
                            y: .value("Rain", day.rainfallMM ?? 0),
                            width: .ratio(0.55))
                        .foregroundStyle(Theme.water)
                }
            }
            .chartYAxisLabel("mm")
            .frame(height: 90)
            .accessibilityLabel("Each day's rainfall over the last 30 days")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: Day by day

    private func dayList(_ days: [WeatherDay]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Day by day")
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .padding(.bottom, 8)

            // "Lazy" builds a row only as it is about to scroll into view.
            LazyVStack(spacing: 0) {
                ForEach(days.prefix(listed)) { day in
                    NavigationLink {
                        WeatherDayView(day: day)
                    } label: {
                        WeatherDayRow(day: day)
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(Theme.hairline)
                }
            }

            if days.count > listed {
                Button("Show more") { listed += 30 }
                    .font(.subheadline)
                    .foregroundStyle(Theme.leaf)
                    .buttonStyle(.plain)
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: Frosts

    private var thisYear: Int { Calendar.current.component(.year, from: .now) }

    /// The year's frosts in one half of the year: January to June, or
    /// July to December.
    private func frostsThisYear(firstHalf: Bool) -> [FrostRecord] {
        frosts.filter {
            Calendar.current.component(.year, from: $0.date) == thisYear
                && (Calendar.current.component(.month, from: $0.date) <= 6) == firstHalf
        }
    }

    private var frostCard: some View {
        // Sorted newest first, so the last of spring is the first in its
        // list and the first of autumn is the last in its list.
        let lastSpring = frostsThisYear(firstHalf: true).first
        let firstAutumn = frostsThisYear(firstHalf: false).last
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Frosts this year")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                ViewAllLink { FrostRecordsView() }
            }
            LabeledContent("Last spring frost",
                           value: lastSpring.map { $0.date.formatted(.dateTime.day().month(.wide)) } ?? "None recorded")
            LabeledContent("First autumn frost",
                           value: firstAutumn.map { $0.date.formatted(.dateTime.day().month(.wide)) } ?? "None yet")
            Text("The gap between the two is the growing season for anything tender. The diary only knows about frosts on days it holds.")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        }
        .font(.subheadline)
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: Explaining and crediting

    private func explainer(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    /// Buttons to fetch, what the last fetch did, and the credit the
    /// weather service's licence asks for.
    private func footer(hasDays: Bool, hasPlaces: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if hasPlaces {
                HStack(spacing: 10) {
                    Button("Check now") {
                        Task { await service.bringUpToDate(in: context, force: true) }
                    }
                    if hasDays {
                        Button("Fetch a year of earlier weather") {
                            Task { await service.fetchEarlier(in: context) }
                        }
                    }
                    if service.isWorking { ProgressView().controlSize(.small) }
                }
                .buttonStyle(QuietGlassButton())
                .disabled(service.isWorking)
            }

            if let error = service.lastError {
                Text("The weather service could not be reached: \(error)")
                    .foregroundStyle(Theme.ink)
            } else if let message = service.lastMessage {
                Text(message)
            }

            Text("These figures are worked out for the garden's place on the map from the weather services' models. They are not readings taken in the garden, so a frost pocket or a sheltered wall will differ.")
            WeatherCredit()
        }
        .font(.caption)
        .foregroundStyle(Theme.inkSoft)
    }
}

/// The credit Open-Meteo's licence (CC BY 4.0) asks for wherever its
/// figures are shown.
struct WeatherCredit: View {
    var body: some View {
        if let link = URL(string: "https://open-meteo.com/") {
            Link("Weather data by Open-Meteo.com", destination: link)
                .font(.caption)
                .tint(Theme.leaf)
        }
    }
}

// MARK: - Pieces

/// A small card with one figure on it.
private struct FigureCard: View {
    let title: String
    let figure: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
            Text(figure)
                .font(.system(.title3, design: .serif, weight: .medium))
                .foregroundStyle(Theme.ink)
            Text(detail ?? " ")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 18, padding: 14)
        // Read out as one thing: "Rain, last 7 days, 12.3 mm".
        .accessibilityElement(children: .combine)
    }
}

/// One day in the list.
private struct WeatherDayRow: View {
    let day: WeatherDay

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 8)
            if day.hadFrost {
                StatusTag(text: "Frost", fill: Theme.water.opacity(0.35))
            }
            if let rain = day.rainfallMM, rain >= 0.1 {
                Text("\(rain.formatted(.number.precision(.fractionLength(1)))) mm")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
            if let low = day.minTemperatureC, let high = day.maxTemperatureC {
                Text("\(WeatherDiary.degrees(low)) to \(WeatherDiary.degrees(high))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
            }
            WIconView(.chevronRight, size: 12)
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.vertical, 9)
        .contentShape(.rect)
    }

    /// "Light rain", and "so far" for a day that has not ended.
    private var caption: String {
        let words = WeatherDiary.words(forCode: day.weatherCode) ?? "No description"
        return day.isComplete ? words : "\(words) · today so far, with the forecast"
    }
}

// MARK: - One day

/// A single day: its figures, and the temperature and rain hour by hour.
struct WeatherDayView: View {

    let day: WeatherDay

    /// One hour of the day, for the chart.
    private struct Hour: Identifiable {
        let id: Int
        let temperature: Double?
        let rain: Double
    }

    /// The hours unpacked once, when the page is built, not on every redraw.
    private let hours: [Hour]

    init(day: WeatherDay) {
        self.day = day
        let hourly = WeatherDiary.hours(of: day)
        hours = (hourly?.temperatureC ?? []).enumerated().map { index, temperature in
            let rain = hourly.flatMap { $0.rainMM.indices.contains(index) ? $0.rainMM[index] : nil } ?? 0
            return Hour(id: index, temperature: temperature, rain: rain)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: day.date.formatted(.dateTime.weekday(.wide).day().month(.wide)),
                             detail: WeatherDiary.words(forCode: day.weatherCode) ?? "Weather")

                Text(WeatherDiary.summary(of: day))
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()

                if !hours.isEmpty {
                    hourChart
                }

                VStack(alignment: .leading, spacing: 10) {
                    row("Coldest", day.minTemperatureC.map { "\($0.formatted(.number.precision(.fractionLength(1))))°C" })
                    row("Warmest", day.maxTemperatureC.map { "\($0.formatted(.number.precision(.fractionLength(1))))°C" })
                    row("Rain", day.rainfallMM.map { "\($0.formatted(.number.precision(.fractionLength(1)))) mm" })
                    row("Strongest wind", day.windMaxKMH.map { "\(Int(WeatherDiary.milesPerHour($0).rounded())) mph" })
                    row("Sunshine", day.sunshineHours.map { "\($0.formatted(.number.precision(.fractionLength(1)))) hours" })
                    row("Soil at seed depth", day.soilTemperatureC.map { "\($0.formatted(.number.precision(.fractionLength(1))))°C" })
                    row("Water lost to the air", day.evaporationMM.map { "\($0.formatted(.number.precision(.fractionLength(1)))) mm" })
                }
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()

                if !day.isComplete {
                    Text("This day has not ended. Its later hours are the forecast, and the figures will settle once it is over.")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                WeatherCredit()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .paperScreen()
        .navigationTitle("Weather")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .eiraLooksAt("the weather on \(day.date.formatted(.dateTime.day().month(.wide).year())): \(WeatherDiary.summary(of: day))",
                     short: "the weather that day")
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String?) -> some View {
        if let value {
            LabeledContent(label, value: value)
        }
    }

    private var hourChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hour by hour")
                .font(.headline)
                .foregroundStyle(Theme.ink)

            Text("Temperature")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
            Chart {
                ForEach(hours) { hour in
                    if let temperature = hour.temperature {
                        LineMark(x: .value("Hour", hour.id), y: .value("Temperature", temperature))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Theme.leaf)
                    }
                }
            }
            .chartXScale(domain: 0...23)
            .chartXAxis { hourAxis }
            .chartYAxisLabel("°C")
            .frame(height: 150)
            .accessibilityLabel("Temperature through the day")

            // Rain has a chart of its own. On the temperature scale a
            // drizzle of a fraction of a millimetre would not show.
            if hours.contains(where: { $0.rain > 0 }) {
                Text("Rain")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                Chart {
                    ForEach(hours) { hour in
                        // A set width in points. The hours are plain
                        // numbers, and a bar on a number line has no
                        // width of its own.
                        BarMark(x: .value("Hour", hour.id), y: .value("Rain", hour.rain), width: .fixed(7))
                            .foregroundStyle(Theme.water)
                    }
                }
                .chartXScale(domain: 0...23)
                .chartXAxis { hourAxis }
                // Three figures up the side are plenty for so short a chart.
                .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) }
                .chartYAxisLabel("mm")
                .frame(height: 100)
                .accessibilityLabel("Rain through the day")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    /// Midnight, 6:00, midday and 18:00 along the bottom of both charts.
    private var hourAxis: some AxisContent {
        AxisMarks(values: [0, 6, 12, 18]) { value in
            AxisGridLine()
            AxisValueLabel {
                if let hour = value.as(Int.self) {
                    Text(hour == 0 ? "Midnight" : (hour == 12 ? "Midday" : "\(hour):00"))
                }
            }
        }
    }
}

/// A checking aid. Starting the app with `-demoGarden -demoWeatherDay`
/// opens the newest finished day in place of the Gardens page, so a still
/// picture can show the hour-by-hour chart.
struct DemoWeatherDay: View {

    @Query(sort: [SortDescriptor(\WeatherDay.dayKey, order: .reverse)]) private var days: [WeatherDay]

    var body: some View {
        if let day = days.first(where: \.isComplete) {
            WeatherDayView(day: day)
        } else {
            ProgressView("Fetching the weather…")
        }
    }
}
