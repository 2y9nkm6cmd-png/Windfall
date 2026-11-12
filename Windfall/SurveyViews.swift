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
//                  our own timeline in Journal.swift — unfortunate name clash,
//                  which is why ours is called TimelineItem.)
//
//  @State + .task  for work that runs while a view is on screen.
//
//  The counting UI is deliberately large-buttoned and single-screen. You
//  will be using it one-handed, outdoors, watching a flower rather than
//  the phone.
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

struct RunSurveyView: View {

    @Bindable var survey: Survey

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var phase: Phase = .setup
    @State private var startTime: Date?
    @State private var elapsed: TimeInterval = 0

    enum Phase { case setup, counting, finished }

    private var duration: TimeInterval {
        TimeInterval(survey.durationSeconds ?? 600)
    }

    private var remaining: TimeInterval {
        max(0, duration - elapsed)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .setup:    setupView
                case .counting: countingView
                case .finished: finishedView
                }
            }
            .navigationTitle(survey.scheme.displayName)
            .paperScreen()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(phase == .counting ? "Abandon" : "Close") {
                        if phase == .setup { context.delete(survey) }
                        dismiss()
                    }
                }
            }
        }
        #if os(iOS)
        .interactiveDismissDisabled(phase == .counting)
        #endif
    }

    // MARK: Setup

    private var setupView: some View {
        Form {
            if survey.scheme == .fitCount {
                Section {
                    TextField("Plant name", text: Binding(
                        get: { survey.targetPlantName ?? "" },
                        set: { survey.targetPlantName = $0.isEmpty ? nil : $0 }
                    ))

                    Stepper(
                        "Floral units: \(survey.floralUnitCount ?? 0)",
                        value: Binding(
                            get: { survey.floralUnitCount ?? 0 },
                            set: { survey.floralUnitCount = $0 }
                        ),
                        in: 0...500
                    )

                    Toggle("On the PoMS target list", isOn: $survey.isSchemeTargetFlower)
                } header: {
                    Text("Target flower")
                } footer: {
                    Text("Count the floral units in a 50 × 50 cm patch before starting the timer.")
                }
            }

            if survey.scheme == .earthwormCount {
                Section {
                    Stepper(
                        "Pit number: \(survey.pitNumber ?? 1)",
                        value: Binding(
                            get: { survey.pitNumber ?? 1 },
                            set: { survey.pitNumber = $0 }
                        ),
                        in: 1...20
                    )
                } header: {
                    Text("Pit")
                } footer: {
                    Text("A 20 × 20 × 20 cm pit. Hand-sort the soil for five minutes.")
                }
            }

            Section("Conditions") {
                LabeledContent("Temperature") {
                    TextField("°C", value: $survey.temperatureC, format: .number)
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }

                Picker("Sky", selection: Binding(
                    get: { survey.skyCondition ?? .sunny },
                    set: { survey.skyCondition = $0 }
                )) {
                    ForEach(SkyCondition.allCases) { sky in
                        Text(sky.displayName).tag(sky)
                    }
                }

                Toggle("Dry", isOn: $survey.isDry)
                Toggle("Windy", isOn: $survey.isWindy)
            }

            if !survey.meetsProtocolConditions || !survey.isInSeason {
                Section {
                    ForEach(survey.validationProblems.filter {
                        $0.contains("season") || $0.contains("Conditions")
                    }, id: \.self) { problem in
                        Label(problem, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.callout)
                    }
                } footer: {
                    Text("You can still record this. It just won't be submitted to the scheme.")
                }
            }

            Section {
                Button {
                    begin()
                } label: {
                    Label("Start the \(Int(duration / 60))-minute count",
                          systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    // MARK: Counting

    private var countingView: some View {
        VStack(spacing: 0) {

            // Big clock. TimelineView redraws every second on its own.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let _ = updateElapsed(now: context.date)

                VStack(spacing: 4) {
                    Text(timeString(remaining))
                        .font(.system(size: 56, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(remaining < 60 ? .orange : .primary)

                    Text("\(survey.totalCount) recorded")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 20)
            }

            Divider()

            // One row per group, with a big tap target.
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(survey.scheme.groups, id: \.self) { group in
                        TallyRow(
                            title: group,
                            count: survey.total(forGroup: group),
                            increment: { add(to: group, 1) },
                            decrement: { add(to: group, -1) }
                        )
                    }
                }
                .padding()
            }

            Divider()

            Button {
                finish()
            } label: {
                Label("Finish count", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
        }
    }

    // MARK: Finished

    private var finishedView: some View {
        Form {
            Section("Result") {
                LabeledContent("Total recorded", value: "\(survey.totalCount)")
                LabeledContent("Duration",
                               value: "\(Int(elapsed / 60)) min \(Int(elapsed) % 60) s")

                ForEach(survey.scheme.groups, id: \.self) { group in
                    let n = survey.total(forGroup: group)
                    if n > 0 {
                        LabeledContent(group, value: "\(n)")
                    }
                }
            }

            if survey.totalCount == 0 {
                Section {
                    Label("A count of zero is a real result — absence is data.",
                          systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Notes") {
                TextField("Anything worth recording", text: Binding(
                    get: { survey.notes ?? "" },
                    set: { survey.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(3...6)
            }

            if !survey.validationProblems.isEmpty {
                Section("Before submitting") {
                    ForEach(survey.validationProblems, id: \.self) { problem in
                        Label(problem, systemImage: "exclamationmark.circle")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section {
                Button("Done") { dismiss() }
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Actions

    private func begin() {
        survey.startedAt = .now
        startTime = .now
        phase = .counting
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = true   // don't sleep mid-count
        #endif
    }

    private func finish() {
        survey.durationSeconds = Int(elapsed)
        phase = .finished
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = false
        #endif
    }

    private func updateElapsed(now: Date) {
        guard let startTime else { return }
        elapsed = now.timeIntervalSince(startTime)
        if elapsed >= duration && phase == .counting {
            finish()
        }
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
        let total = Int(interval)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Tally row

private struct TallyRow: View {

    let title: String
    let count: Int
    let increment: () -> Void
    let decrement: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: decrement) {
                Image(systemName: "minus")
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.bordered)
            .disabled(count == 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text("\(count)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: increment) {
                Image(systemName: "plus")
                    .frame(width: 56, height: 44)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(count > 0 ? Color.green.opacity(0.12) : Color.secondary.opacity(0.08))
        )
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
