//
//  SurveyViews.swift
//  Windfall
//
//  Running a survey: the ten-minute FIT Count and the earthworm pit count.
//
//  New things here:
//
//  TimelineView    SwiftUI's clock-driven view. Redraws on a schedule
//                  without you managing a Timer object. (Nothing to do with
//                  our own timeline in Journal.swift. The names clash by
//                  bad luck, which is why ours is called TimelineItem.)
//
//  @State + .task  for work that runs while a view is on screen.
//
//  The counting UI is deliberately large-buttoned and single-screen. You
//  will be using it one-handed, outdoors, watching a flower rather than
//  the phone.
//
//  The sheet a count runs in is drawn with the app's own glass cards
//  (RunSurveyView), from the pieces in SheetParts.swift. The list of
//  past surveys and a survey's detail page are still standard lists
//  and forms.
//

import SwiftUI
import SwiftData

// MARK: - Survey list

struct SurveyListView: View {

    @Query(sort: [SortDescriptor(\Survey.startedAt, order: .reverse)])
    private var surveys: [Survey]

    @Environment(\.modelContext) private var context

    @State private var runningSurvey: Survey?
    @State private var showingNewSurvey = false

    var body: some View {
        List {
            if surveys.isEmpty {
                ContentUnavailableView {
                    Label("No surveys yet", systemImage: "list.clipboard")
                } description: {
                    Text("A FIT Count takes ten minutes and records what visits one flower.")
                }
            }

            ForEach(surveys) { survey in
                NavigationLink(value: survey) {
                    SurveyRow(survey: survey)
                }
            }
            .onDelete { offsets in
                for i in offsets { context.delete(surveys[i]) }
            }
        }
        .navigationTitle("Surveys")
        .paperScreen()
        .navigationDestination(for: Survey.self) { survey in
            SurveyDetailView(survey: survey)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        start(.fitCount)
                    } label: {
                        Label("FIT Count", systemImage: "camera.macro")
                    }
                    Button {
                        start(.earthwormCount)
                    } label: {
                        Label("Earthworm count", systemImage: "chart.bar.doc.horizontal")
                    }
                } label: {
                    Label("New survey", systemImage: "plus")
                }
            }
        }
        .sheet(item: $runningSurvey) { survey in
            RunSurveyView(survey: survey)
        }
    }

    private func start(_ scheme: RecordingScheme) {
        let survey = Survey(scheme: scheme)
        survey.recorderName = UserDefaults.standard.string(forKey: "recorderName")
        context.insert(survey)
        runningSurvey = survey
    }
}

private struct SurveyRow: View {

    let survey: Survey

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(survey.scheme.displayName)
                    .font(.headline)
                Spacer()
                Text(survey.startedAt, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let plant = survey.targetPlantName {
                Text(plant)
                    .font(.subheadline)
            }

            HStack(spacing: 8) {
                Label("\(survey.totalCount)", systemImage: "number")

                if survey.submitted {
                    Label("Submitted", systemImage: "checkmark.seal")
                        .foregroundStyle(.green)
                } else if !survey.validationProblems.isEmpty {
                    Label("\(survey.validationProblems.count) to fix",
                          systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Running a count

/// The sheet a count is run in. It has three stages, shown one after
/// another: setting up, counting and the result.
///
/// It is drawn with the app's own cards and buttons. It used to be a
/// standard form, which on a Mac lines everything up in two columns
/// meant for a settings window and looked out of place.
struct RunSurveyView: View {

    @Bindable var survey: Survey

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var phase: Phase = .setup
    @State private var startTime: Date?
    /// How long the count ran, set when it finishes.
    @State private var elapsed: TimeInterval = 0
    @State private var isAskingToAbandon = false
    /// True when the conditions were filled in from the weather service.
    @State private var conditionsWereFilled = false

    enum Phase { case setup, counting, finished }

    /// How long the count is meant to last, from the scheme's own rules.
    private var duration: TimeInterval {
        TimeInterval(survey.scheme.defaultDurationSeconds ?? survey.durationSeconds ?? 600)
    }

    var body: some View {
        // SheetPage draws the title, the button at the top right and the
        // paper. See SheetParts.swift.
        SheetPage(survey.scheme.displayName,
                  detail: headerLine,
                  // The result has its own Done button, so none up here.
                  dismissTitle: phase == .finished ? nil : (phase == .counting ? "Abandon" : "Close"),
                  onDismiss: close) {
            switch phase {
            case .setup: setupView
            case .counting: countingView
            case .finished: finishedView
            }
        }
        #if os(iOS)
        .interactiveDismissDisabled(phase == .counting)
        #endif
        .confirmationDialog("Abandon this count?", isPresented: $isAskingToAbandon, titleVisibility: .visible) {
            Button("Abandon count", role: .destructive) { abandon() }
            Button("Keep counting", role: .cancel) { }
        } message: {
            Text("Nothing from it will be kept.")
        }
        .onAppear { fillConditionsFromWeather() }
    }

    private var headerLine: String {
        switch phase {
        case .setup:
            return survey.scheme == .earthwormCount
                ? "A 20 × 20 × 20 cm pit. Hand-sort the soil for five minutes."
                : "Ten minutes watching one 50 × 50 cm patch of flowers."
        case .counting:
            if survey.scheme == .earthwormCount { return "Pit \(survey.pitNumber ?? 1)" }
            return survey.targetPlantName ?? "Counting"
        case .finished:
            return "Finished"
        }
    }

    // MARK: Setup

    private var setupView: some View {
        VStack(spacing: 0) {
            SheetScroll {
                if survey.scheme == .fitCount { flowerCard }
                if survey.scheme == .earthwormCount { pitCard }
                conditionsCard
                if !survey.meetsProtocolConditions || !survey.isInSeason {
                    ProblemsCard(problems: survey.validationProblems.filter { $0.contains("season") || $0.contains("Conditions") },
                                 footnote: "You can still record this. It just won't be submitted to the scheme.")
                }
            }
            SheetMainButton("Start the \(Int(duration / 60))-minute count") { begin() }
        }
    }

    private var flowerCard: some View {
        SheetCard("Target flower") {
            FieldBox {
                TextField("Plant name", text: Binding(
                    get: { survey.targetPlantName ?? "" },
                    set: { survey.targetPlantName = $0.isEmpty ? nil : $0 }
                ))
            }
            SettingRow("Floral units") {
                NumberStepper(value: Binding(
                    get: { survey.floralUnitCount ?? 0 },
                    set: { survey.floralUnitCount = $0 }
                ), range: 0...500)
            }
            Toggle("On the PoMS target list", isOn: $survey.isSchemeTargetFlower)
                .tint(Theme.leaf)
                .foregroundStyle(Theme.ink)
            Text("Count the floral units in the patch before starting the timer.")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private var pitCard: some View {
        SheetCard("Pit") {
            SettingRow("Pit number") {
                NumberStepper(value: Binding(
                    get: { survey.pitNumber ?? 1 },
                    set: { survey.pitNumber = $0 }
                ), range: 1...20)
            }
        }
    }

    private var conditionsCard: some View {
        SheetCard("Conditions") {
            SettingRow("Temperature") {
                FieldBox {
                    HStack(spacing: 4) {
                        TextField("", value: $survey.temperatureC, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 56)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text("°C")
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }

            // Three sliding switches (GlassSwitch, in SheetParts.swift).
            // Every choice can be seen at once, where a menu would hide
            // all but one.
            GlassSwitch(choices: SkyCondition.allCases, selection: Binding(
                get: { survey.skyCondition ?? .sunny },
                set: { survey.skyCondition = $0 }
            )) { $0.displayName }

            HStack(spacing: 10) {
                GlassSwitch(choices: [true, false], selection: $survey.isDry) { $0 ? "Dry" : "Raining" }
                GlassSwitch(choices: [false, true], selection: $survey.isWindy) { $0 ? "Windy" : "Calm" }
            }

            if conditionsWereFilled {
                Text("Filled in from the weather service for your garden. Change anything that is different where you are standing.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    /// Saves typing outdoors: if the Today screen checked the weather
    /// within the last hour, a new count starts with those conditions.
    /// Anything already filled in is left alone.
    private func fillConditionsFromWeather() {
        let service = WeatherService.shared
        guard phase == .setup, survey.temperatureC == nil, survey.skyConditionRaw == nil,
              let now = service.current,
              let fetched = service.lastFetched, Date.now.timeIntervalSince(fetched) < 3600 else { return }
        // One decimal place is as exact as the figure is.
        survey.temperatureC = (now.temperatureC * 10).rounded() / 10
        survey.skyCondition = now.skyCondition
        survey.isDry = now.isDry
        survey.isWindy = now.isWindy
        conditionsWereFilled = true
    }

    // MARK: Counting

    private var countingView: some View {
        VStack(spacing: 0) {
            // TimelineView redraws what is inside it on a schedule, here
            // once a second, and says what time it is each time.
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                clock(left: remaining(at: timeline.date))
            }
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(survey.scheme.groups, id: \.self) { group in
                        TallyRow(
                            title: group,
                            hint: survey.scheme.hint(for: group),
                            count: survey.total(forGroup: group),
                            increment: { add(to: group, 1) },
                            decrement: { add(to: group, -1) }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            SheetMainButton("Finish count") { finish() }
        }
        // `.task` runs for as long as this stage is on screen and is
        // stopped when it leaves. This one waits for the time to run
        // out and then finishes the count.
        .task { await finishWhenTimeIsUp() }
    }

    /// The time left as a ring that empties, with the figures inside it.
    private func clock(left: TimeInterval) -> some View {
        let isNearlyDone = left < 60
        return ZStack {
            Circle()
                .stroke(Theme.hairline, lineWidth: 8)
            // `trim` draws only part of the circle: all of it at the
            // start, none at the end.
            Circle()
                .trim(from: 0, to: duration > 0 ? left / duration : 0)
                .stroke(isNearlyDone ? Theme.amber : Theme.leaf,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round))
                // A circle starts at three o'clock. This turns the start
                // to twelve.
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: left)

            VStack(spacing: 2) {
                Text(timeString(left))
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(Theme.ink)
                Text("\(survey.totalCount) counted")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .frame(width: 164, height: 164)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func remaining(at date: Date) -> TimeInterval {
        guard let startTime else { return duration }
        return max(0, duration - date.timeIntervalSince(startTime))
    }

    // MARK: Finished

    private var finishedView: some View {
        VStack(spacing: 0) {
            SheetScroll {
                SheetCard("Result") {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(survey.totalCount)")
                            .font(.system(size: 42, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Text("counted in \(Int(elapsed) / 60) min \(Int(elapsed) % 60) s")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                    }

                    // A short list, like the four worm groups, shows
                    // every group, because none found is worth
                    // knowing. A long one shows only what was seen.
                    let showsEmptyGroups = survey.scheme.groups.count <= 4
                    ForEach(survey.scheme.groups, id: \.self) { group in
                        let found = survey.total(forGroup: group)
                        if found > 0 || showsEmptyGroups {
                            resultRow(group, count: found, of: survey.totalCount)
                        }
                    }

                    if survey.totalCount == 0 {
                        Text("A count of zero is a real result. Absence is data.")
                            .font(.callout)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }

                SheetCard("Notes") {
                    FieldBox {
                        TextField("Anything worth recording", text: Binding(
                            get: { survey.notes ?? "" },
                            set: { survey.notes = $0.isEmpty ? nil : $0 }
                        ), axis: .vertical)
                        .lineLimit(3...6)
                    }
                }

                if !survey.validationProblems.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Before submitting")
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 4)
                        ProblemsCard(problems: survey.validationProblems)
                    }
                }
            }
            SheetMainButton("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
    }

    /// One group in the result: its name, its count and a bar as long
    /// as its share of the whole count.
    private func resultRow(_ group: String, count: Int, of total: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(group)
                Spacer()
                Text("\(count)")
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .foregroundStyle(Theme.ink)

            // GeometryReader says how wide the space is, so the bar can
            // be made a share of it.
            GeometryReader { geometry in
                Capsule()
                    .fill(Theme.leaf)
                    .frame(width: total > 0 ? geometry.size.width * CGFloat(count) / CGFloat(total) : 0)
            }
            .frame(height: 6)
            .background(Theme.hairline, in: .capsule)
        }
    }

    // MARK: Actions

    private func begin() {
        // The pit number shows as 1 until it is changed. Make sure that
        // 1 is what gets recorded.
        if survey.scheme == .earthwormCount && survey.pitNumber == nil { survey.pitNumber = 1 }
        survey.startedAt = .now
        startTime = .now
        phase = .counting
        keepScreenAwake(true)
    }

    private func finish() {
        guard phase == .counting else { return }
        if let startTime {
            // Never longer than the count was meant to be, even if the
            // device slept through the end of it.
            elapsed = min(Date.now.timeIntervalSince(startTime), duration)
        }
        survey.durationSeconds = Int(elapsed.rounded())
        phase = .finished
        keepScreenAwake(false)
    }

    /// Waits until the time is up, then finishes the count.
    private func finishWhenTimeIsUp() async {
        guard let startTime else { return }
        let wait = duration - Date.now.timeIntervalSince(startTime)
        if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
        // If the count was finished or abandoned first, this wait was
        // cut short and there is nothing left to do.
        guard !Task.isCancelled, phase == .counting else { return }
        #if os(iOS)
        // A buzz, for hands that are busy and eyes that are elsewhere.
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        finish()
    }

    /// The button at the top: Close before the count, Abandon during it.
    private func close() {
        switch phase {
        case .setup:
            // Nothing was counted, so no record is left behind.
            context.delete(survey)
            dismiss()
        case .counting:
            isAskingToAbandon = true
        case .finished:
            dismiss()
        }
    }

    /// Throws the count away. It used to be kept, looking like a
    /// finished five-minute count with whatever had been tallied.
    private func abandon() {
        keepScreenAwake(false)
        context.delete(survey)
        dismiss()
    }

    /// Stops an iPhone or iPad dimming and locking in the middle of a
    /// count. Always switched back off afterwards.
    private func keepScreenAwake(_ isOn: Bool) {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = isOn
        #endif
    }

    /// Finds the tally for a group, or makes one, then adjusts it.
    private func add(to group: String, _ delta: Int) {
        let existing = (survey.tallies ?? []).first { $0.groupName == group }

        if let existing {
            existing.quantity = max(0, existing.quantity + delta)
        } else if delta > 0 {
            let tally = SurveyTally(groupName: group, quantity: delta)
            tally.survey = survey
            survey.tallies?.append(tally)
        }

        #if os(iOS)
        if delta > 0 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        #endif
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Pieces of the count

private extension RecordingScheme {

    /// A line to help put a worm in the right group while sorting.
    ///
    /// ⚠️ CHECK: written by Claude on 13 November 2026 from AHDB's "How
    /// to count earthworms" (ahdb.org.uk/knowledge-library/soil-macrofauna-earthworms).
    /// William has not checked them against his own guide.
    func hint(for group: String) -> String? {
        guard self == .earthwormCount else { return nil }
        switch group {
        case "Epigeic": return "Lives in the litter. Small, dark red, about a matchstick long. Often quick."
        case "Anecic": return "Deep burrower. Large, about a pencil long, with a dark red or black head."
        case "Endogeic": return "Lives in the topsoil. Pale or green, not red. Often curls up when held."
        case "Juvenile": return "No saddle yet: the wider band around an adult worm."
        default: return nil
        }
    }
}

/// One group being counted: its name, a hint, the count so far and a
/// large button to add one. The buttons are big on purpose. They are
/// pressed outdoors, one-handed, without much looking.
private struct TallyRow: View {

    let title: String
    let hint: String?
    let count: Int
    let increment: () -> Void
    let decrement: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                if let hint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        // Lets the hint run on to a second line.
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: decrement) {
                Image(systemName: "minus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Theme.card.opacity(0.8), in: .circle)
                    .overlay { Circle().strokeBorder(Theme.hairline) }
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .disabled(count == 0)
            .opacity(count == 0 ? 0.35 : 1)
            .accessibilityLabel("One fewer \(title)")

            Text("\(count)")
                .font(.system(.title, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: count)
                .foregroundStyle(Theme.ink)
                .frame(minWidth: 40)

            Button(action: increment) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.onLeaf)
                    .frame(width: 68, height: 54)
                    .background(Theme.leaf, in: .rect(cornerRadius: 16))
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add one \(title)")
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        // The row turns green once something has been counted in it.
        .glassEffect(.regular.tint((count > 0 ? Theme.leafFill : Theme.card).opacity(count > 0 ? 0.7 : 0.5)),
                     in: .rect(cornerRadius: 18))
    }
}

// MARK: - Survey detail

struct SurveyDetailView: View {

    @Bindable var survey: Survey

    var body: some View {
        Form {
            Section("Survey") {
                LabeledContent("Scheme", value: survey.scheme.displayName)
                LabeledContent("Date", value: survey.startedAt.formatted(date: .long, time: .shortened))
                if let plant = survey.targetPlantName {
                    LabeledContent("Target flower", value: plant)
                }
                if let units = survey.floralUnitCount {
                    LabeledContent("Floral units", value: "\(units)")
                }
                LabeledContent("Total recorded", value: "\(survey.totalCount)")
            }

            Section("Counts") {
                ForEach((survey.tallies ?? []).sorted { $0.groupName < $1.groupName }) { tally in
                    LabeledContent(tally.groupName, value: "\(tally.quantity)")
                }
            }

            Section("Conditions") {
                if let t = survey.temperatureC {
                    LabeledContent("Temperature", value: "\(t.formatted()) °C")
                }
                if let sky = survey.skyCondition {
                    LabeledContent("Sky", value: sky.displayName)
                }
                LabeledContent("Dry", value: survey.isDry ? "Yes" : "No")
            }

            Section("Recording") {
                TextField("Recorder", text: Binding(
                    get: { survey.recorderName ?? "" },
                    set: { survey.recorderName = $0.isEmpty ? nil : $0 }
                ))
                TextField("Grid reference", text: Binding(
                    get: { survey.gridReference ?? "" },
                    set: { survey.gridReference = $0.isEmpty ? nil : $0 }
                ))
                Toggle("Submitted", isOn: $survey.submitted)
            }

            if !survey.validationProblems.isEmpty {
                Section("Not ready to submit") {
                    ForEach(survey.validationProblems, id: \.self) { problem in
                        Label(problem, systemImage: "exclamationmark.circle")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .navigationTitle("Survey")
        .paperScreen()
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    NavigationStack {
        SurveyListView()
    }
    .modelContainer(for: [Survey.self, SurveyTally.self, WildlifeObservation.self],
                    inMemory: true)
}
