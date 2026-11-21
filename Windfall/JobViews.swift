//
//  JobViews.swift
//  Windfall
//
//  The screens for jobs of your own. GardenJobs.swift holds the record
//  and the rules. This file only draws.
//
//  - `JobOfferCard`: Eira's "Add a job?" card, with what she understood
//    already filled in. Shown under a message in her chat, and in a
//    sheet when the words were typed into her bar.
//  - `JobOfferSheet`: that card in a sheet of its own, for her bar.
//  - `JobSheet`: a job added by hand, or an existing one opened to be
//    changed or deleted.
//  - `OwnJobsView`: every job of your own on one page.
//  - `JobFields`: the three things a job has, shared by the card and
//    the sheet so that both ask the same questions the same way.
//
//  Nothing is saved until Add or Save is pressed. That is the rule for
//  everything Eira offers (doc 00 of the knowledge base).
//

import SwiftUI
import SwiftData

// MARK: - A job's facts

extension GardenJob {

    /// The days it is for, in the form the rules use.
    var span: JobDays {
        get { JobDays(from: dueFrom, by: dueBy) }
        set {
            dueFrom = newValue.from
            dueBy = newValue.by
        }
    }

    /// The plain facts the lists need (GardenJobs.thisWeek and the
    /// rest). `gardens` is every garden on record, to put a name to the
    /// job's `siteKey`.
    func facts(gardens: [Garden]) -> JobFacts {
        JobFacts(key: id.uuidString, title: title, span: span,
                 place: gardens.first { $0.siteKey == siteKey }?.name, doneAt: doneAt)
    }
}

// MARK: - The three things a job has

/// What it is, when it is for and where. Used inside the offer card and
/// inside the sheet.
///
/// `@Binding` means the value is owned by whoever shows these fields.
/// Typing here changes their copy, which is how the card and the sheet
/// each get the answers back.
struct JobFields: View {

    @Binding var title: String
    @Binding var span: JobDays
    @Binding var siteKey: String?
    let gardens: [Garden]
    /// The day the choices are worked out from.
    let today: Date

    /// The days on offer: no date, today, tomorrow and so on, and the
    /// job's own days as well if they are none of those ("March", or a
    /// day chosen from the calendar below).
    private var choices: [JobDays] {
        var all = GardenJobs.choices(today: today)
        if !all.contains(span) { all.insert(span, at: 1) }
        return all
    }

    /// The calendar's day. Choosing one makes the job a one-day job.
    /// A Binding made by hand like this is two small functions: one to
    /// read the value and one to store it.
    private var chosenDay: Binding<Date> {
        Binding(
            get: { span.from ?? span.by ?? Calendar.current.startOfDay(for: today) },
            set: { span = .day(Calendar.current.startOfDay(for: $0)) })
    }

    var body: some View {
        FieldBox {
            // `axis: .vertical` lets a long job run on to a second line.
            TextField("What needs doing", text: $title, axis: .vertical)
                .lineLimit(1...3)
        }

        SettingRow("When") {
            Picker("When", selection: $span) {
                ForEach(choices, id: \.self) { choice in
                    Text(GardenJobs.whenLine(choice, today: today) ?? "No date").tag(choice)
                }
            }
            .labelsHidden()
        }

        SettingRow("Or pick a day") {
            DatePicker("Day", selection: chosenDay, displayedComponents: .date)
                .labelsHidden()
        }

        // Asked only when there is a choice to make.
        if gardens.count > 1 {
            SettingRow("Where") {
                Picker("Where", selection: $siteKey) {
                    // `String?.none` is "no garden". The tags must be
                    // the same type as `siteKey`, which is optional.
                    Text("Anywhere").tag(String?.none)
                    ForEach(gardens) { garden in
                        Text(garden.name).tag(String?.some(garden.siteKey))
                    }
                }
                .labelsHidden()
            }
        }
    }
}

// MARK: - Eira's offer

/// "Add a job?" Eira's card for a sentence that reads as something to
/// do. GardenJobs.offer decides which sentences those are and fills the
/// card in.
struct JobOfferCard: View {

    private let said: String
    private let today: Date
    private let gardens: [Garden]
    private let onAdd: (_ title: String, _ line: String) -> Void
    private let onDismiss: () -> Void

    @Environment(\.modelContext) private var context

    @State private var title: String
    @State private var span: JobDays
    @State private var siteKey: String?

    /// - `said`: the sentence as it was typed or spoken.
    /// - `today`: when it was said.
    /// - `gardens`: the gardens on record, so that "in the allotment"
    ///   can be understood.
    /// - `onAdd`: called once the job is saved, with its title and a
    ///   line for Eira to say.
    /// - `onDismiss`: called when "Not a job" is pressed.
    init(said: String, today: Date, gardens: [Garden],
         onAdd: @escaping (_ title: String, _ line: String) -> Void,
         onDismiss: @escaping () -> Void) {
        self.said = said
        self.today = today
        self.gardens = gardens
        self.onAdd = onAdd
        self.onDismiss = onDismiss
        let places = gardens.map { JobPlace(key: $0.siteKey, name: $0.name) }
        let offer = GardenJobs.offer(in: said, today: today, places: places)
        // `_title` is the storage behind `@State var title`. This is how
        // a starting value is handed to it.
        _title = State(initialValue: offer?.title ?? said)
        _span = State(initialValue: offer?.span ?? .whenever)
        _siteKey = State(initialValue: offer?.siteKey)
    }

    private var trimmed: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        OfferFrame("Add a job?",
                   refuseTitle: "Not a job",
                   canAdd: !trimmed.isEmpty,
                   onAdd: add,
                   onRefuse: onDismiss) {
            JobFields(title: $title, span: $span, siteKey: $siteKey, gardens: gardens, today: today)
            Text("It goes on Today's lists until you tick it. Nothing is added unless you press Add.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private func add() {
        // The record is made in CardAdds.swift, which Eira's test run
        // uses too, so the two always make the same job.
        let fromCard = CardAdd.job(title: trimmed, from: span.from, by: span.by, siteKey: siteKey,
                                said: said, into: context)
        onAdd(trimmed, fromCard.line)
    }
}

/// The offer in a sheet of its own. Opened by Eira's bar when what was
/// typed there reads as a job, so the card comes up at once, on any
/// device, without waiting for a model to load.
struct JobOfferSheet: View {

    let said: String
    /// "Not a job": hands the words on to Eira's chat. Nil on a device
    /// that cannot run her, where the sheet simply closes.
    var onAskEira: ((String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Garden.displayOrder)]) private var gardens: [Garden]

    /// What Eira says once the job is added. Nil until then.
    @State private var addedLine: String?
    /// When the sheet opened, so the card and its days do not shift if
    /// midnight passes while it is up.
    @State private var opened = Date.now

    var body: some View {
        SheetPage("A job for the list",
                  detail: "\u{201C}\(said)\u{201D}",
                  dismissTitle: addedLine == nil ? "Cancel" : "Done") {
            SheetScroll {
                if let addedLine {
                    HStack(alignment: .top, spacing: 8) {
                        EiraSymbol(size: 28)
                        Text(addedLine)
                            .font(.body)
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    JobOfferCard(said: said, today: opened, gardens: gardens.filter(\.isActive),
                                 onAdd: { _, line in addedLine = line },
                                 onDismiss: {
                                     if let onAskEira { onAskEira(said) } else { dismiss() }
                                 })
                }
            }
        }
    }
}

// MARK: - By hand

/// A job added by hand, or an existing job opened to change it.
struct JobSheet: View {

    /// The job being changed. Nil for a new one.
    private let job: GardenJob?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Garden.displayOrder)]) private var gardens: [Garden]

    @State private var title: String
    @State private var span: JobDays
    @State private var siteKey: String?
    @State private var opened = Date.now
    @State private var carriedOn = false

    /// What is kept if the sheet is closed without Add or Save (review
    /// pass, 21 November 2026, doc 145). See FormDraft.swift.
    struct Draft: Codable, Equatable {
        var title = ""
        var from: Date?
        var by: Date?
        var siteKey: String?
    }

    private var draft: Draft { Draft(title: title, from: span.from, by: span.by, siteKey: siteKey) }

    /// One kept copy for a new job, and one for each job being changed.
    private var draftKey: String { FormDraft.key(job == nil ? "new-job" : "job", job?.id) }

    /// Nothing worth keeping: the sheet as it opened.
    private var draftIsEmpty: Bool {
        draft == Draft(title: job?.title ?? "", from: job?.span.from, by: job?.span.by, siteKey: job?.siteKey)
    }

    private func use(_ typedBefore: Draft) {
        title = typedBefore.title
        span = JobDays(from: typedBefore.from, by: typedBefore.by)
        siteKey = typedBefore.siteKey
    }

    init(job: GardenJob? = nil) {
        self.job = job
        _title = State(initialValue: job?.title ?? "")
        _span = State(initialValue: job?.span ?? .whenever)
        _siteKey = State(initialValue: job?.siteKey)
    }

    private var trimmed: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        SheetPage(job == nil ? "New job" : "Job",
                  detail: job == nil ? "Something to do that no season would suggest." : nil,
                  confirmTitle: job == nil ? "Add" : "Save",
                  canConfirm: !trimmed.isEmpty,
                  onConfirm: save) {
            SheetScroll {
                if carriedOn {
                    DraftNotice {
                        use(Draft(title: job?.title ?? "", from: job?.span.from, by: job?.span.by, siteKey: job?.siteKey))
                        FormDraft.clear(key: draftKey)
                        carriedOn = false
                    }
                }
                SheetCard {
                    JobFields(title: $title, span: $span, siteKey: $siteKey,
                              gardens: gardens.filter(\.isActive), today: opened)
                }

                if let job {
                    SheetCard {
                        if let said = job.saidAs, !said.isEmpty {
                            Text("Read from: \u{201C}\(said)\u{201D}")
                                .font(.footnote)
                                .foregroundStyle(Theme.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        // `role: .destructive` tells the system this
                        // button removes something, and it is drawn red.
                        Button("Delete this job", role: .destructive) {
                            FormDraft.clear(key: draftKey)
                            context.delete(job)
                            dismiss()
                        }
                        .buttonStyle(QuietGlassButton())
                    }
                }
            }
        }
        // Tells Eira which job is open, or that a new one is being
        // written (piece 1, project doc 119). The saved title, not the
        // words being typed.
        .eiraLooksAt(EiraPagePhrase.job(title: job?.title), short: job?.title)
        .keepsDraft(draftKey, draft, isEmpty: draftIsEmpty, carriedOn: $carriedOn, restore: use)
    }

    private func save() {
        FormDraft.clear(key: draftKey)
        // An existing job is changed in place. A new one is made.
        let theJob = job ?? GardenJob()
        theJob.title = trimmed
        theJob.span = span
        theJob.siteKey = siteKey
        if job == nil { context.insert(theJob) }
        dismiss()
    }
}

// MARK: - Every job

/// One job of your own with its tick box. Ticking it marks the record
/// as done. Tapping its words opens it to be changed.
struct OwnJobRow: View {

    let job: GardenJob
    let gardens: [Garden]

    @State private var isEditing = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                // Ticked now, or unticked if it was ticked already.
                job.doneAt = job.isDone ? nil : .now
            } label: {
                TickBox(isOn: job.isDone)
                    .frame(width: 30, height: 30)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(job.isDone ? "Done: \(job.title)" : "Mark as done: \(job.title)")

            Button {
                isEditing = true
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(job.title)
                        .font(.body)
                        .strikethrough(job.isDone)
                        .foregroundStyle(job.isDone ? Theme.inkSoft : Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail = GardenJobs.detail(for: job.facts(gardens: gardens), today: .now) {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 5)
                .multilineTextAlignment(.leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the job to change it")

            Spacer(minLength: 0)
        }
        .sheet(isPresented: $isEditing) {
            JobSheet(job: job)
        }
    }
}

/// Every job of your own: those still to do, soonest first, then those
/// with no date, then the ones ticked in the last month.
struct OwnJobsView: View {

    // `@Query` reads these from the database and keeps the list up to
    // date as jobs are added, ticked and deleted.
    @Query(sort: [SortDescriptor(\GardenJob.createdAt)]) private var jobs: [GardenJob]
    @Query(sort: [SortDescriptor(\Garden.displayOrder)]) private var gardens: [Garden]

    @State private var isAdding = false

    /// Still to do and with a day, the soonest first.
    private var dated: [GardenJob] {
        jobs.filter { !$0.isDone && ($0.dueFrom ?? $0.dueBy) != nil }
            .sorted { ($0.dueFrom ?? $0.dueBy ?? .distantFuture) < ($1.dueFrom ?? $1.dueBy ?? .distantFuture) }
    }

    /// Still to do and with no day, the oldest first.
    private var undated: [GardenJob] {
        jobs.filter { !$0.isDone && ($0.dueFrom ?? $0.dueBy) == nil }
    }

    /// Ticked in the last thirty days, the newest first.
    private var done: [GardenJob] {
        let monthAgo = Date.now.addingTimeInterval(-30 * 86_400)
        return jobs.filter { ($0.doneAt ?? .distantPast) > monthAgo }
            .sorted { ($0.doneAt ?? .distantPast) > ($1.doneAt ?? .distantPast) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Your jobs",
                             detail: "The ones you have added yourself")

                Button {
                    isAdding = true
                } label: {
                    Label("Add a job", systemImage: "plus")
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.leaf)
                .foregroundStyle(Theme.onLeaf)

                if jobs.isEmpty {
                    Text("None yet. Tell Eira what needs doing, such as \u{201C}I need to build the wigwam at the weekend\u{201D}, or add one here.")
                        .font(.body)
                        .foregroundStyle(Theme.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()
                }

                section("With a day", dated)
                section("Whenever", undated)
                section("Done in the last month", done)
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Your jobs")
        // Tells Eira what is open (piece 1, project doc 119). See EiraScreen.swift.
        .eiraLooksAt("the list of your own jobs, the ones no season would suggest", short: "Your jobs")
        .paperScreen()
        .sheet(isPresented: $isAdding) {
            JobSheet()
        }
    }

    /// One glass card of jobs under a heading. Nothing is drawn for an
    /// empty list. `@ViewBuilder` lets the function hand back either a
    /// card or nothing.
    @ViewBuilder
    private func section(_ heading: String, _ list: [GardenJob]) -> some View {
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(heading)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                ForEach(list) { job in
                    OwnJobRow(job: job, gardens: gardens)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
    }
}
