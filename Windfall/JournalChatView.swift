//
//  JournalChatView.swift
//  Windfall
//
//  Writing in the journal as a conversation with Eira.
//
//  It replaces the diary form for new entries. The form had a box for
//  each thing: date, title, entry, scope, conditions, temperature,
//  photos. Here there is one box to write in and a send button, as in a
//  chat, and everything else is worked out or sits in a small chip
//  above the box:
//
//  - When        "Now", unless changed.
//  - Conditions  filled in from the weather service for that time.
//  - About       the garden, or one bed.
//  - Photos      chosen with the button, dragged on to the sheet, or
//                handed over by the Journal page or Eira's bar when a
//                photo was dropped there.
//  - Title       written from the entry's own first words.
//
//  Above the box is the day so far: what has been written, each with
//  its stamp of time and weather, and that day's sowings, harvests,
//  counts and sightings in between.
//
//  If an entry is written after dark, or says "this morning", a card
//  asks when it was about before it can be sent, so that it is stamped
//  with the right weather. The same card asks when the photos with an
//  entry were taken on another day, or earlier today: a photo's file
//  says when it was taken (PhotoFacts.swift).
//
//  Each thing sent is saved as an ordinary diary entry. Nothing about
//  how entries are stored has changed.
//
//  The rules for the stamp, the title and the time check are in
//  JournalChat.swift. Eira's lines here are fixed wording, not written
//  by the AI model.
//
//  When something is sent, Eira also looks for a harvest or a sowing in
//  the words and offers to put it on record, as a card to accept or
//  turn down (JournalOffers.swift reads the words, JournalOfferCards.swift
//  draws the cards).
//
//  Not built yet: names becoming links.
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct JournalChatView: View {

    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\DiaryEntry.date)]) private var diary: [DiaryEntry]
    @Query(filter: #Predicate<Bed> { $0.retiredAt == nil },
           sort: [SortDescriptor(\Bed.displayOrder)]) private var beds: [Bed]
    @Query(sort: [SortDescriptor(\Garden.displayOrder)]) private var gardens: [Garden]
    /// The plant library, for spotting a harvest or sowing in the words.
    @Query(sort: [SortDescriptor(\Plant.commonName)]) private var plants: [Plant]
    // The day's other records, shown between the entries.
    @Query private var plantings: [Planting]
    @Query private var harvests: [Harvest]
    @Query private var surveys: [Survey]
    @Query private var sightings: [WildlifeObservation]

    // What is being written.
    @State private var words: String
    @State private var waitingPhotos: [WaitingPhoto] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    /// Photos handed over when the conversation was opened, because
    /// they were dropped on the Journal page or on Eira's bar.
    private let startingPhotos: [Data]
    /// True once those have been put in the box, so that it happens once.
    @State private var hasTakenStartingPhotos = false

    // The stamp. Nil for `chosenWhen` means "now".
    @State private var chosenWhen: Date?
    @State private var aboutBed: Bed?
    /// The weather service's figures for the stamp's time, if it has any.
    @State private var suggested: CurrentConditions?
    /// True once the conditions have been changed by hand. The two
    /// values after it are then used in place of `suggested`.
    @State private var hasOwnConditions = false
    @State private var ownWeather: Weather?
    @State private var ownTemperature: Double?

    // The time check.
    @State private var checkIsAnswered = false
    /// True if Send was pressed while the check was waiting.
    @State private var checkWasSkipped = false
    /// The weather at each time the check can offer, looked up once.
    @State private var weatherAtMoment: [JournalChat.Moment: CurrentConditions] = [:]
    /// True while the weather service is being asked about the stamp's time.
    @State private var isAskingWeather = false

    // The photos' own day.
    /// The question about the photos that has been answered, so that
    /// it is not put twice.
    @State private var answeredPhotoCheck: JournalChat.PhotoCheck?
    /// The weather at each time that question can offer.
    @State private var weatherAtPhotoTime: [Date: CurrentConditions] = [:]

    // Eira's offers to put what was just written on record.
    @State private var offers: [RecordOffer] = []
    /// When the entry the offers came from was stamped.
    @State private var offerDate = Date.now
    /// What Eira says once an offer has been taken up.
    @State private var addedNotes: [String] = []

    // Small things that come and go.
    @State private var showsWhen = false
    @State private var showsConditions = false
    @State private var isDropTarget = false
    @State private var lastSent: UUID?
    @State private var renaming: DiaryEntry?
    @State private var newTitle = ""
    @State private var editing: DiaryEntry?
    @State private var voice = VoiceInput()

    /// True when the words came from Eira's bar, so she says why the
    /// journal has opened.
    private let cameFromEirasBar: Bool
    /// Hands the words back to Eira's ordinary chat, if they were a
    /// question after all. Nil where there is no bar to go back to.
    private let askEiraInstead: ((String) -> Void)?

    /// - `draft`: words to start with, such as Today's list of what has
    ///   been logged.
    /// - `photos`: photos to start with, each as its file's own bytes.
    init(draft: String = "", photos: [Data] = [], cameFromEirasBar: Bool = false,
         askEiraInstead: ((String) -> Void)? = nil) {
        // `_words` is the storage behind `@State var words`. This is how
        // a starting value is handed to it from outside.
        _words = State(initialValue: draft)
        self.startingPhotos = photos
        self.cameFromEirasBar = cameFromEirasBar
        self.askEiraInstead = askEiraInstead
    }

    // MARK: Worked out from the above

    /// The time the next entry will be stamped with.
    private var stampDate: Date { chosenWhen ?? .now }

    /// The garden the weather is for: the first with a location.
    private var place: WeatherDiary.Place? { WeatherDiary.places(for: gardens).first }

    /// Whether the sun is down at the garden. Nil if its place is unknown.
    private var isDark: Bool? {
        place.map { Sun.position(latitude: $0.latitude, longitude: $0.longitude, at: .now).altitude < 0 }
    }

    /// The question to ask before sending, if there is one.
    private var timeCheck: JournalChat.TimeCheck? {
        checkIsAnswered ? nil : JournalChat.timeCheck(for: words, at: .now, isDark: isDark)
    }

    /// The question the photos raise, if they were not taken just now
    /// and it has not already been answered.
    private var photoCheck: JournalChat.PhotoCheck? {
        let check = JournalChat.photoCheck(taken: waitingPhotos.compactMap(\.facts.taken), at: .now)
        return check == answeredPhotoCheck ? nil : check
    }

    private var stampWeather: Weather? {
        hasOwnConditions ? ownWeather : suggested.map { JournalChat.weatherWord(for: $0) }
    }

    private var stampTemperature: Double? {
        // One decimal place is as exact as the figure is.
        hasOwnConditions ? ownTemperature : suggested.map { ($0.temperatureC * 10).rounded() / 10 }
    }

    private var canSend: Bool {
        !words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !waitingPhotos.isEmpty
    }

    /// One line of the day: something written, or another record.
    private enum DayLine: Identifiable {
        case entry(DiaryEntry)
        case record(TimelineItem)

        var id: UUID {
            switch self {
            case .entry(let entry): return entry.id
            case .record(let item): return item.id
            }
        }

        var date: Date {
            switch self {
            case .entry(let entry): return entry.date
            case .record(let item): return item.date
            }
        }
    }

    /// Everything from the stamp's day, oldest first.
    private var dayLines: [DayLine] {
        let calendar = Calendar.current
        let day = stampDate
        func isThatDay(_ date: Date) -> Bool { calendar.isDate(date, inSameDayAs: day) }

        let written = diary.filter { isThatDay($0.date) }.map { DayLine.entry($0) }
        // Only that day's records are handed to the timeline builder, so
        // it is not asked to go through every record ever made.
        let records = TimelineBuilder.build(
            plantings: plantings.filter { isThatDay($0.timelineDate) },
            harvests: harvests.filter { isThatDay($0.timelineDate) },
            surveys: surveys.filter { isThatDay($0.timelineDate) },
            sightings: sightings.filter { isThatDay($0.timelineDate) }
        ).map { DayLine.record($0) }
        return (written + records).sorted { $0.date < $1.date }
    }

    /// "Friday 13 November", for the line under the title.
    private var dayWords: String {
        let day = stampDate.formatted(.dateTime.weekday(.wide).day().month(.wide))
        if Calendar.current.isDateInToday(stampDate) { return "Today, \(day)" }
        if Calendar.current.isDateInYesterday(stampDate) { return "Yesterday, \(day)" }
        return day
    }

    // MARK: Body

    var body: some View {
        // Worked out once for this redraw.
        let lines = dayLines

        SheetPage("Journal", detail: dayWords, dismissTitle: "Done") {
            VStack(spacing: 0) {
                thread(lines)
                // The photos' own day is asked about first. It is firmer
                // evidence of when this happened than the words are.
                if let photoCheck {
                    checkCard(question: photoCheck.question, choices: choices(for: photoCheck))
                } else if let timeCheck {
                    checkCard(question: timeCheck.question, choices: choices(for: timeCheck))
                }
                composer
            }
        }
        // Photos can be dragged on to any part of the sheet.
        .onDrop(of: PhotoDrop.kinds, isTargeted: $isDropTarget) { providers in
            takeDropped(providers)
        }
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Theme.leaf, style: StrokeStyle(lineWidth: 2.5, dash: [8, 6]))
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .task {
            voice.checkExistingPermission()
            lookUpWeather()
            takeStartingPhotos()
            await askServiceIfMissing()
        }
        .onChange(of: chosenWhen) { _, _ in
            suggested = conditions(at: stampDate)
            Task { await askServiceIfMissing() }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await loadPicked(items) }
        }
        .alert("Rename", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Title", text: $newTitle)
            Button("Save") {
                renaming?.title = newTitle.isEmpty ? nil : newTitle
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
        // The old form, for changing every detail of something already
        // written.
        .sheet(item: $editing) { entry in
            DiaryEntryEditor(entry: entry).macSheetSize(width: 520, height: 640)
        }
    }

    // MARK: The day so far

    private func thread(_ lines: [DayLine]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                eiraSays(lines.isEmpty
                         ? "Tell me what happened in the garden. I will note the time and the weather with it."
                         : "Here is the day so far. Anything to add?")

                ForEach(lines) { line in
                    switch line {
                    case .entry(let entry): bubble(entry)
                    case .record(let item): recordLine(item)
                    }
                }

                // Words that came from Eira's bar are waiting in the box
                // below. She says why, and offers the way back.
                if cameFromEirasBar && lastSent == nil {
                    eiraSays("That reads like one for the journal, so it is waiting in the box below. Check the time and the weather under it, then send.")
                    if let askEiraInstead, !words.isEmpty {
                        Button("It was a question. Ask Eira instead") { askEiraInstead(words) }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(QuietGlassButton())
                            .tint(Theme.leaf)
                            .padding(.leading, 36)
                    }
                }

                // Photos dropped to start this are waiting there too.
                if !startingPhotos.isEmpty && !cameFromEirasBar && lastSent == nil {
                    eiraSays(startingPhotos.count == 1
                             ? "Your photo is waiting in the box below. Add a few words about it if you like, then send."
                             : "Your \(startingPhotos.count) photos are waiting in the box below. Add a few words about them if you like, then send.")
                }

                if let sent = diary.first(where: { $0.id == lastSent }) {
                    eiraSays(acknowledgement(of: sent))
                }

                // What Eira thinks could go on record from it, each as a
                // card to accept or turn down.
                ForEach(offers) { offer in
                    offerCard(offer)
                }
                ForEach(addedNotes, id: \.self) { note in
                    eiraSays(note)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        // Opens at the newest line and stays there as lines are added,
        // as a chat does.
        .defaultScrollAnchor(.bottom)
        .frame(minHeight: 200)
    }

    /// Something Eira says: her snowdrop and a pale bubble, on the left.
    private func eiraSays(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            EiraSymbol(size: 28)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Theme.card.opacity(0.85), in: .rect(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Theme.hairline)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 36)
    }

    /// Something written: a green bubble on the right with its stamp
    /// underneath.
    private func bubble(_ entry: DiaryEntry) -> some View {
        // The title is shown only where there is one and it says
        // something the words underneath do not.
        let heading = (entry.title?.isEmpty == false ? entry.title : entry.generatedSummary) ?? ""
        let showsHeading = !heading.isEmpty && heading != entry.body

        return VStack(alignment: .trailing, spacing: 4) {
            VStack(alignment: .leading, spacing: 6) {
                if showsHeading {
                    Text(heading)
                        .font(.subheadline.weight(.semibold))
                }
                if !entry.body.isEmpty {
                    Text(entry.body)
                        .font(.subheadline)
                }
                if let photos = entry.photos, !photos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(photos) { PhotoThumbnail(photo: $0, size: 84) }
                        }
                    }
                }
            }
            .foregroundStyle(Theme.ink)
            .padding(12)
            .background(Theme.leafFill, in: .rect(cornerRadius: 18))
            // Press and hold, or right-click on a Mac.
            .contextMenu {
                Button("Rename") {
                    newTitle = heading
                    renaming = entry
                }
                Button("Change the details") { editing = entry }
                Button("Delete", role: .destructive) { context.delete(entry) }
            }

            Text(stampLine(of: entry))
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 44)
    }

    /// "15:36 · 9°C, overcast · Bed 3"
    private func stampLine(of entry: DiaryEntry) -> String {
        var parts = [entry.date.formatted(date: .omitted, time: .shortened)]
        if let weather = JournalChat.stampWords(weather: entry.weather, temperatureC: entry.temperatureC) {
            parts.append(weather)
        }
        if let bed = entry.bed { parts.append(bed.name) }
        return parts.joined(separator: " · ")
    }

    /// A sowing, harvest, count or sighting from the same day: a quiet
    /// line in the middle.
    private func recordLine(_ item: TimelineItem) -> some View {
        Text("\(item.title) · \(item.date.formatted(date: .omitted, time: .shortened))")
            .font(.caption)
            .foregroundStyle(Theme.inkSoft)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Theme.card.opacity(0.6), in: .capsule)
            .frame(maxWidth: .infinity)
    }

    /// What Eira says about the entry just sent.
    private func acknowledgement(of entry: DiaryEntry) -> String {
        let time = entry.date.formatted(date: .omitted, time: .shortened)
        var when = "at \(time)"
        if !Calendar.current.isDateInToday(entry.date) {
            when = "for \(entry.date.formatted(.dateTime.weekday(.wide))) at \(time)"
        }
        var text = "Noted \(when)"
        if let weather = JournalChat.stampWords(weather: entry.weather, temperatureC: entry.temperatureC) {
            text += ", \(weather.lowercased())"
        }
        text += "."
        if let heading = entry.generatedSummary, !heading.isEmpty {
            text += " I have called it “\(heading)”."
        }
        text += " Press and hold it to rename or change it."
        if !offers.isEmpty {
            text += offers.count == 1 ? " There may be a record in it to add:" : " There may be records in it to add:"
        }
        return text
    }

    /// One offer as its card. The card is left out if its plant has
    /// gone from the library in the meantime.
    @ViewBuilder
    private func offerCard(_ offer: RecordOffer) -> some View {
        let candidates = offer.plantKeys.compactMap { key in plants.first { $0.id.uuidString == key } }
        if !candidates.isEmpty {
            switch offer.kind {
            case .harvest:
                HarvestOfferCard(offer: offer, candidates: candidates, date: offerDate,
                                 onAdd: { note in settle(offer, saying: note) },
                                 onDismiss: { settle(offer, saying: nil) })
            case .sowing:
                SowingOfferCard(offer: offer, candidates: candidates, beds: beds, date: offerDate,
                                onAdd: { note in settle(offer, saying: note) },
                                onDismiss: { settle(offer, saying: nil) })
            }
        }
    }

    /// An offer has been taken up or turned down. Its card goes, and if
    /// something was added Eira says so.
    private func settle(_ offer: RecordOffer, saying note: String?) {
        offers.removeAll { $0.id == offer.id }
        if let note { addedNotes.append(note) }
    }

    // MARK: The time check

    /// One button on the check's card: a time, the weather then if it
    /// is known, and what pressing it does.
    private struct CheckChoice: Identifiable {
        let id: String
        let name: String
        let weather: CurrentConditions?
        let choose: () -> Void
    }

    /// The buttons for a question raised by the words or the hour.
    private func choices(for check: JournalChat.TimeCheck) -> [CheckChoice] {
        check.moments.map { moment in
            let label = JournalChat.name(of: moment)
            return CheckChoice(id: moment.rawValue, name: label,
                               weather: weatherAtMoment[moment]) { answer(moment) }
        }
    }

    /// The buttons for a question raised by when the photos were taken:
    /// each day they point to, then "Now".
    private func choices(for check: JournalChat.PhotoCheck) -> [CheckChoice] {
        let days = check.moments.map { moment in
            CheckChoice(id: moment.name, name: moment.name,
                        weather: weatherAtPhotoTime[moment.date]) { answerPhotoCheck(check, with: moment.date) }
        }
        let nowLabel = JournalChat.name(of: .now)
        let nowChoice = CheckChoice(id: "now", name: nowLabel,
                                    weather: weatherAtMoment[.now]) { answerPhotoCheck(check, with: nil) }
        return days + [nowChoice]
    }

    /// The card that asks when an entry was about. Until 14 November
    /// 2026 it could only be drawn from the words' own question. Now it
    /// is drawn from any question and list of choices, so the photos'
    /// question looks and works the same.
    private func checkCard(question: String, choices: [CheckChoice]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.ink)
            if checkWasSkipped {
                Text("Choose one, then send.")
                    .font(.caption)
                    .foregroundStyle(Theme.amber)
            }
            ForEach(choices) { checkChoice in
                Button {
                    checkChoice.choose()
                } label: {
                    HStack {
                        Text(checkChoice.name)
                            .fontWeight(.medium)
                        Spacer(minLength: 8)
                        if let weather = checkChoice.weather {
                            Text(JournalChat.stampWords(weather: JournalChat.weatherWord(for: weather),
                                                        temperatureC: weather.temperatureC) ?? "")
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Theme.card.opacity(0.85), in: .rect(cornerRadius: 12))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .glassEffect(.regular.tint(Theme.card.opacity(0.55)), in: .rect(cornerRadius: 18))
        .overlay {
            if checkWasSkipped {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Theme.amber, lineWidth: 1.5)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    /// One of the photo question's buttons was pressed. The stamp is set
    /// to that time and its weather, or to now if `date` is nil. Nothing
    /// is sent yet.
    private func answerPhotoCheck(_ check: JournalChat.PhotoCheck, with date: Date?) {
        chosenWhen = date
        hasOwnConditions = false
        suggested = conditions(at: stampDate)
        answeredPhotoCheck = check
        // A time has now been chosen by hand, so the words' own question
        // is not put as well.
        checkIsAnswered = true
        checkWasSkipped = false
    }

    /// One of the check's buttons was pressed. The stamp is set to that
    /// time and its weather. Nothing is sent yet.
    private func answer(_ moment: JournalChat.Moment) {
        chosenWhen = moment == .now ? nil : JournalChat.date(for: moment, now: .now)
        hasOwnConditions = false
        suggested = conditions(at: stampDate)
        checkIsAnswered = true
        checkWasSkipped = false
    }

    // MARK: The box to write in

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            // The stamp, as three chips. They scroll sideways if the
            // sheet is too narrow to show all three.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    whenChip
                    conditionsChip
                    aboutChip
                }
            }

            if !waitingPhotos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(waitingPhotos) { photo in
                            waitingThumbnail(photo)
                        }
                    }
                }
            }

            if voice.isListening {
                Text(voice.transcript.isEmpty ? "Listening…" : voice.transcript)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }

            HStack(alignment: .bottom, spacing: 8) {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                    roundSymbol("photo.badge.plus")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add photos")

                microphone

                TextField("Tell Eira about the garden", text: $words, axis: .vertical)
                    // Grows from one line to six, then scrolls.
                    .lineLimit(1...6)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.card.opacity(0.85), in: .rect(cornerRadius: 20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Theme.hairline)
                    }
                    // Return sends. Shift-Return or Option-Return starts a
                    // new line. `.ignored` hands the key back to the box.
                    .onKeyPress(.return, phases: .down) { press in
                        if press.modifiers.contains(.shift) || press.modifiers.contains(.option) {
                            return .ignored
                        }
                        send()
                        return .handled
                    }

                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.onLeaf)
                        .frame(width: 40, height: 40)
                        .background(Theme.leaf, in: .circle)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .opacity(canSend ? 1 : 0.4)
                .accessibilityLabel("Send")
            }
        }
        .padding(12)
        .glassEffect(.regular.tint(Theme.card.opacity(0.55)), in: .rect(cornerRadius: 24))
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }

    /// The look of a chip: a small symbol and a few words in a capsule.
    private func chip(_ text: String, symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.caption)
            Text(text)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.card.opacity(0.85), in: .capsule)
        .overlay {
            Capsule().strokeBorder(Theme.hairline)
        }
        .contentShape(.capsule)
    }

    /// A round button face for the photo and microphone buttons.
    private func roundSymbol(_ symbol: String, isOn: Bool = false) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 16))
            .foregroundStyle(isOn ? Theme.onLeaf : Theme.ink)
            .frame(width: 40, height: 40)
            .background(isOn ? Theme.leaf : Theme.card.opacity(0.85), in: .circle)
            .overlay {
                Circle().strokeBorder(Theme.hairline)
            }
            .contentShape(.circle)
    }

    // MARK: The chips

    private var whenWords: String {
        guard let chosenWhen else { return "Now" }
        let time = chosenWhen.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(chosenWhen) { return "Today, \(time)" }
        if Calendar.current.isDateInYesterday(chosenWhen) { return "Yesterday, \(time)" }
        return chosenWhen.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }

    private var whenChip: some View {
        Button {
            showsWhen = true
        } label: {
            chip(whenWords, symbol: "clock")
        }
        .buttonStyle(.plain)
        // A popover is a small panel that points at what opened it.
        .popover(isPresented: $showsWhen) {
            VStack(alignment: .leading, spacing: 12) {
                DatePicker("When", selection: Binding(
                    get: { chosenWhen ?? .now },
                    set: {
                        chosenWhen = $0
                        // Choosing a time by hand answers the time check.
                        checkIsAnswered = true
                        checkWasSkipped = false
                    }
                ), in: ...Date.now)
                Button("Back to now") {
                    chosenWhen = nil
                    showsWhen = false
                }
                .buttonStyle(QuietGlassButton())
            }
            .padding(16)
            .frame(minWidth: 260)
            // Keeps it a small panel on an iPhone, where it would
            // otherwise take over the screen.
            .presentationCompactAdaptation(.popover)
        }
    }

    private var conditionsChip: some View {
        Button {
            showsConditions = true
        } label: {
            chip(JournalChat.stampWords(weather: stampWeather, temperatureC: stampTemperature) ?? "Add the weather",
                 symbol: (stampWeather ?? .mild).symbolName)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showsConditions) {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Conditions", selection: Binding(
                    get: { stampWeather ?? .mild },
                    set: {
                        keepConditionsAsOwn()
                        ownWeather = $0
                    }
                )) {
                    ForEach(Weather.allCases) { weather in
                        Text(weather.displayName).tag(weather)
                    }
                }

                HStack(spacing: 6) {
                    Text("Temperature")
                    Spacer(minLength: 8)
                    TextField("", value: Binding(
                        get: { stampTemperature },
                        set: {
                            keepConditionsAsOwn()
                            ownTemperature = $0
                        }
                    ), format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    Text("°C")
                }

                Text(conditionsSource)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)

                if hasOwnConditions {
                    Button("Use the weather service's figures") { hasOwnConditions = false }
                        .buttonStyle(QuietGlassButton())
                }
            }
            .padding(16)
            .frame(minWidth: 280)
            .presentationCompactAdaptation(.popover)
        }
    }

    /// Says where the conditions on the chip came from.
    private var conditionsSource: String {
        if hasOwnConditions { return "Your own figures." }
        if suggested == nil, isAskingWeather { return "Asking the weather service about this time…" }
        if suggested == nil { return "The weather service has no figures for this time. Add your own." }
        return "From the weather service, for your garden at this time. Change anything that was different."
    }

    /// Called just before a condition is changed by hand. The first
    /// time, it copies the weather service's figures across, so that
    /// changing one of them does not blank the other.
    private func keepConditionsAsOwn() {
        guard !hasOwnConditions else { return }
        ownWeather = stampWeather
        ownTemperature = stampTemperature
        hasOwnConditions = true
    }

    private var aboutChip: some View {
        Menu {
            Button("The garden") { aboutBed = nil }
            if !beds.isEmpty {
                Section("One bed") {
                    ForEach(beds) { bed in
                        Button(bed.name) { aboutBed = bed }
                    }
                }
            }
        } label: {
            chip(aboutBed?.name ?? "The garden", symbol: "square.grid.2x2")
        }
        // Show the chip as it is, without the frame Apple draws round a
        // menu's button.
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    // MARK: Voice

    /// Hold to speak. What is heard is added to the box when let go, to
    /// be read over before it is sent.
    @ViewBuilder
    private var microphone: some View {
        if voice.isAuthorised {
            roundSymbol(voice.isListening ? "mic.fill" : "mic", isOn: voice.isListening)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !voice.isListening { voice.startListening() }
                        }
                        .onEnded { _ in
                            let heard = voice.transcript
                            voice.stopListening()
                            guard !heard.isEmpty else { return }
                            words = words.isEmpty ? heard : "\(words) \(heard)"
                        }
                )
                .accessibilityLabel("Hold to speak")
        } else {
            // Voice stays off until asked for. Pressing this is what
            // brings up Apple's microphone and speech permission boxes.
            Button {
                Task { await voice.requestPermission() }
            } label: {
                roundSymbol("mic.slash")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Turn on voice input")
        }
    }

    // MARK: Photos

    /// A photo chosen or dropped, not yet sent.
    private struct WaitingPhoto: Identifiable {
        let id = UUID()
        let data: Data
        let thumbnail: Data?
        /// When and where it was taken, read from the file.
        let facts: PhotoFacts
    }

    private func waitingThumbnail(_ photo: WaitingPhoto) -> some View {
        ZStack {
            if let picture = PhotoThumbnail.image(from: photo.thumbnail ?? photo.data) {
                picture
                    .resizable()
                    .scaledToFill()
            } else {
                Theme.card
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(.rect(cornerRadius: 10))
        .overlay(alignment: .topTrailing) {
            Button {
                waitingPhotos.removeAll { $0.id == photo.id }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 20, height: 20)
                    .background(Theme.card, in: .circle)
            }
            .buttonStyle(.plain)
            .padding(3)
            .accessibilityLabel("Remove photo")
        }
    }

    private func addPhoto(_ data: Data) {
        waitingPhotos.append(WaitingPhoto(data: data, thumbnail: DiaryEntryEditor.thumbnail(from: data),
                                          facts: PhotoFacts.read(from: data)))
        lookUpPhotoWeather()
    }

    /// Puts the photos the conversation was opened with into the box.
    private func takeStartingPhotos() {
        guard !hasTakenStartingPhotos else { return }
        hasTakenStartingPhotos = true
        for data in startingPhotos { addPhoto(data) }
    }

    /// Looks up the weather at each time the photos' question offers,
    /// to show beside its buttons. From the weather diary where a
    /// garden has a place, otherwise asked of the weather service.
    private func lookUpPhotoWeather() {
        let moments = JournalChat.photoCheck(taken: waitingPhotos.compactMap(\.facts.taken), at: .now)?.moments ?? []
        for moment in moments where weatherAtPhotoTime[moment.date] == nil {
            let date = moment.date
            if let found = conditions(at: date) {
                weatherAtPhotoTime[date] = found
            } else if place == nil, let near = WeatherService.shared.lastPlace {
                Task { weatherAtPhotoTime[date] = await WeatherService.shared.conditions(at: date, near: near) }
            }
        }
    }

    /// Photos chosen with the button. They arrive one at a time, a
    /// moment after being chosen.
    private func loadPicked(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                addPhoto(data)
            }
        }
        pickerItems = []
    }

    /// Photos dragged on to the sheet. Returns true if any of what was
    /// dropped could be a picture. They are read a moment later, by the
    /// reader every drop in the app shares (PhotoDrop.swift).
    private func takeDropped(_ providers: [NSItemProvider]) -> Bool {
        guard PhotoDrop.mayHold(providers) else { return false }
        Task {
            for data in await PhotoDrop.pictures(from: providers) { addPhoto(data) }
        }
        return true
    }

    // MARK: Weather for the stamp

    /// Looks up the weather for now and for each time the check can
    /// offer. Done once, when the sheet opens, and not on every key
    /// press.
    private func lookUpWeather() {
        suggested = conditions(at: stampDate)
        for moment in JournalChat.Moment.allCases where moment != .now {
            weatherAtMoment[moment] = conditions(at: JournalChat.date(for: moment, now: .now))
        }
        weatherAtMoment[.now] = conditions(at: .now)
    }

    /// When no garden has a location there is no weather diary to look in,
    /// so the stamp's hour, and the hours the time check offers, are asked
    /// of the weather service at the place the Today screen used: usually
    /// the device's own location. Before 13 November 2026 this step was
    /// missing, and any time but the last half hour came up blank.
    private func askServiceIfMissing() async {
        guard place == nil, let near = WeatherService.shared.lastPlace else { return }
        let service = WeatherService.shared
        if suggested == nil {
            isAskingWeather = true
            let askedWhen = chosenWhen
            let found = await service.conditions(at: stampDate, near: near)
            isAskingWeather = false
            // Only use it if the time has not been changed again meanwhile.
            if askedWhen == chosenWhen, suggested == nil { suggested = found }
        }
        for moment in JournalChat.Moment.allCases where moment != .now && weatherAtMoment[moment] == nil {
            weatherAtMoment[moment] = await service.conditions(at: JournalChat.date(for: moment, now: .now), near: near)
        }
    }

    /// The weather at a time. For the last half hour it is the figures
    /// the Today screen fetched, if they are under an hour old. For any
    /// other time it is that hour from the weather diary.
    private func conditions(at date: Date) -> CurrentConditions? {
        let service = WeatherService.shared
        if abs(date.timeIntervalSinceNow) < 1800,
           let live = service.current,
           let fetched = service.lastFetched, Date.now.timeIntervalSince(fetched) < 3600 {
            return live
        }
        guard let place else { return nil }
        let key = WeatherDiary.dayKey(for: date)
        let site = place.site
        var find = FetchDescriptor<WeatherDay>(predicate: #Predicate { $0.dayKey == key && $0.siteRaw == site })
        find.fetchLimit = 1
        guard let day = try? context.fetch(find).first,
              let hours = WeatherDiary.hours(of: day) else { return nil }
        return hours.conditions(atHour: Calendar.current.component(.hour, from: date))
    }

    // MARK: Sending

    private func send() {
        let text = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !waitingPhotos.isEmpty else { return }

        // A question about when this was has to be answered first. Its
        // card turns amber.
        if photoCheck != nil || timeCheck != nil {
            checkWasSkipped = true
            return
        }

        let entry = DiaryEntry(body: text)
        entry.date = stampDate
        entry.weather = stampWeather
        entry.temperatureC = stampTemperature
        if let aboutBed {
            entry.scope = .bed
            entry.bed = aboutBed
        }
        // A title from the entry's own words, marked as written for
        // you. The whole entry is read, and sentences that name a plant
        // or bed from the garden count for more. It is left off where
        // it would only repeat the entry.
        let gardenNames = Set(plants.flatMap { JournalChat.roots(in: $0.commonName) + JournalChat.roots(in: $0.variety ?? "") }
                              + beds.flatMap { JournalChat.roots(in: $0.name) })
        if let heading = JournalChat.title(for: text, known: gardenNames), heading != text {
            entry.generatedSummary = heading
            entry.summaryGeneratedAt = .now
        }
        context.insert(entry)

        for waiting in waitingPhotos {
            // The photo keeps the time it was taken, whichever time the
            // entry is stamped with.
            let photo = Photo.record(of: waiting.data, facts: waiting.facts, thumbnail: waiting.thumbnail,
                                     otherwiseAt: entry.date)
            photo.diaryEntry = entry
            entry.photos?.append(photo)
        }

        // See whether the words describe a harvest or a sowing. Plants
        // being grown are listed first, so that where several share a
        // name the likeliest is offered first.
        let growing = plants.filter { $0.status == .growing } + plants.filter { $0.status != .growing }
        offers = JournalOffers.offers(
            in: text,
            plants: growing.map { OfferPlant(key: $0.id.uuidString, commonName: $0.commonName, variety: $0.variety) },
            beds: beds.map { OfferBed(key: $0.id.uuidString, name: $0.name) })
        offerDate = entry.date
        addedNotes = []

        // Ready for the next thing to be said.
        lastSent = entry.id
        words = ""
        waitingPhotos = []
        chosenWhen = nil
        hasOwnConditions = false
        checkIsAnswered = false
        checkWasSkipped = false
        answeredPhotoCheck = nil
        suggested = conditions(at: .now)
    }
}
