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
//  And when the words tell of something seen but not named ("an
//  insect"), Eira offers to pin it down with a photo or a few details
//  (JournalPinDown.swift).
//
//  An entry already written is changed in its own sheet
//  (JournalEntryEditor.swift), opened by the pencil under the entry or
//  by pressing and holding it.
//
//  Not built yet: names becoming links.
//
//  Where it is drawn (14 November 2026). Opened from Eira's bar, on a
//  Mac, an iPad or an iPhone, the conversation is drawn in the panel
//  that grows out of the bar (EiraPanel.swift) and is handed that
//  panel's controls. Opened any other way, such as from Today's Note
//  button, it is a sheet, as before. The conversation itself is
//  the same in both: only its heading and the surface under the box to
//  write in differ.
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import CoreLocation

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

    // Eira's offer to pin down something seen but not named.
    @State private var pinDown: PinDownRequest?
    /// True once Photo or Describe has been used on the current offer.
    @State private var pinDownWasUsed = false
    /// How many finds in a row have gone by without the offer being
    /// used. Kept between launches, so that Eira asks less often once
    /// it is clear the offer is not wanted (JournalChat.shouldOfferPinDown).
    @AppStorage("journalPinDownSkips") private var pinDownSkips = 0

    // A photo sent with words that ask what it is ("What is this?").
    // Eira answers it in a card, and no entry is written. See
    // JournalNaming.swift.
    @State private var naming: NamingRequest?
    /// True when the photos in the box have already been named and
    /// were put back to be written about. The next thing sent is then
    /// an entry whatever its words say, so "Not sure what this is" can
    /// still be written down.
    @State private var photosAreForAnEntry = false

    // Small things that come and go.
    @State private var showsWhen = false
    @State private var showsConditions = false
    @State private var isDropTarget = false
    @State private var lastSent: UUID?
    /// The entries whose offer to add a new plant was turned down.
    @State private var newPlantRefused: Set<UUID> = []
    @State private var renaming: DiaryEntry?
    @State private var newTitle = ""
    @State private var editing: DiaryEntry?
    @State private var voice = VoiceInput()
    // @FocusState says whether the box to write in has the keyboard,
    // and setting it to true hands the keyboard over.
    @FocusState private var boxHasFocus: Bool

    /// True when the words came from Eira's bar, so she says why the
    /// journal has opened.
    private let cameFromEirasBar: Bool
    /// Hands the words back to Eira's ordinary chat, if they were a
    /// question after all. Nil where there is no bar to go back to.
    private let askEiraInstead: ((String) -> Void)?
    /// Set when this is drawn in the panel that grows out of Eira's
    /// bar, and nil when it is in a sheet. See EiraPanel.swift.
    private let panel: EiraPanelControls?

    /// - `draft`: words to start with, such as Today's list of what has
    ///   been logged.
    /// - `photos`: photos to start with, each as its file's own bytes.
    /// - `panel`: the panel's controls, when this is drawn in the panel
    ///   that grows out of Eira's bar. Left out, this is a sheet.
    init(draft: String = "", photos: [Data] = [], cameFromEirasBar: Bool = false,
         panel: EiraPanelControls? = nil,
         askEiraInstead: ((String) -> Void)? = nil) {
        // `_words` is the storage behind `@State var words`. This is how
        // a starting value is handed to it from outside.
        _words = State(initialValue: draft)
        self.startingPhotos = photos
        self.cameFromEirasBar = cameFromEirasBar
        self.panel = panel
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

    /// True when what is in the box is a photo and words that ask what
    /// it is. That is a question for Eira, not an entry, so the
    /// questions about when it happened are not put (see `send`).
    private var asksForAName: Bool {
        !waitingPhotos.isEmpty && !photosAreForAnEntry && JournalChat.asksForAName(words)
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

    /// True while a chosen photo has not arrived yet. Sending waits for
    /// it, so that a photo cannot be left behind by a quick press.
    private var photosAreComing: Bool {
        waitingPhotos.contains { $0.data == nil }
    }

    private var canSend: Bool {
        guard !photosAreComing else { return false }
        return !words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !waitingPhotos.isEmpty
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

        page {
            VStack(spacing: 0) {
                thread(lines)
                // A photo with "What is this?" is not going to be an
                // entry, so there is no time to ask about and the card
                // is left out. (Until 15 November 2026 it was shown, and
                // send would not go until it was answered.)
                //
                // Otherwise the photos' own day is asked about first. It
                // is firmer evidence of when this happened than the
                // words are.
                if asksForAName {
                    EmptyView()
                } else if let photoCheck {
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
            // A checking aid: `-demoJournalSend YES` presses send a
            // moment after the conversation opens. See DemoGarden.
            if DemoGarden.sendsJournalDraft {
                try? await Task.sleep(for: .seconds(1))
                send()
            }
            await askServiceIfMissing()
        }
        // In the panel, typing carries on from Eira's bar: this box
        // takes the keyboard from the bar's. The short wait is because
        // the box has to be on screen before it can be handed anything.
        .task {
            guard panel?.takesKeyboard == true else { return }
            try? await Task.sleep(for: .milliseconds(60))
            boxHasFocus = true
        }
        .onChange(of: chosenWhen) { _, _ in
            suggested = conditions(at: stampDate)
            Task { await askServiceIfMissing() }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            loadPicked(items)
        }
        // Once the box has no photos in it, whether they were sent or
        // taken off with their crosses, the next photo starts afresh
        // and can be asked about again.
        .onChange(of: waitingPhotos.isEmpty) { _, boxIsEmpty in
            if boxIsEmpty { photosAreForAnEntry = false }
        }
        .alert("Rename", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Title", text: $newTitle)
            Button("Save") {
                renaming?.title = newTitle.isEmpty ? nil : newTitle
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
        // The editor, for changing anything about something already
        // written (JournalEntryEditor.swift). Until 14 November 2026
        // this opened the old diary form.
        .sheet(item: $editing) { entry in
            JournalEntrySheet(entry: entry)
        }
    }

    /// The heading and frame round the conversation: the panel's own
    /// when this is drawn in the panel, a sheet's when it is not.
    ///
    /// `@ViewBuilder` lets a function hand back one kind of view or
    /// another depending on an `if`. `Inside` stands for "whatever view
    /// is put inside", here the conversation.
    @ViewBuilder
    private func page<Inside: View>(@ViewBuilder _ inside: @escaping () -> Inside) -> some View {
        if let panel {
            PanelPage("Journal", detail: dayWords, controls: panel, content: inside)
        } else {
            SheetPage("Journal", detail: dayWords, dismissTitle: "Done", content: inside)
        }
    }

    // MARK: The day so far

    private func thread(_ lines: [DayLine]) -> some View {
        // `ScrollViewReader` hands over a `proxy`: a handle that can
        // move the list so that a named line is in view. It is used
        // once, to show the top of Eira's answer to a photo (see
        // `showTop`).
        ScrollViewReader { proxy in
            threadLines(lines, proxy: proxy)
        }
    }

    private func threadLines(_ lines: [DayLine], proxy: ScrollViewProxy) -> some View {
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
                            .font(.footnote.weight(.semibold))
                            .buttonStyle(QuietGlassButton())
                            .tint(Theme.leaf)
                            .padding(.leading, 36)
                    }
                }

                // Photos dropped to start this are waiting there too.
                // The line goes once the box holds no photos: they were
                // sent, asked about or taken off.
                if !startingPhotos.isEmpty && !cameFromEirasBar && lastSent == nil && !waitingPhotos.isEmpty {
                    eiraSays(startingPhotos.count == 1
                             ? "Your photo is waiting in the box below. Add a few words about it and send, or ask me what it is."
                             : "Your \(startingPhotos.count) photos are waiting in the box below. Add a few words about them and send, or ask me what they are.")
                }

                if let sent = diary.first(where: { $0.id == lastSent }) {
                    eiraSays(acknowledgement(of: sent))

                    // An entry that says you have planted, sown or
                    // bought a plant the library does not have: Eira
                    // offers to add it and look it up. See
                    // NewPlantMention in PlantFillIn.swift.
                    if !newPlantRefused.contains(sent.id),
                       let newName = NewPlantMention.name(in: sent.body, known: plants.map(\.commonName)) {
                        NewPlantOfferCard(name: newName) { newPlantRefused.insert(sent.id) }
                    }
                }

                // What Eira thinks could go on record from it, each as a
                // card to accept or turn down.
                ForEach(offers) { offer in
                    offerCard(offer)
                }
                ForEach(addedNotes, id: \.self) { note in
                    eiraSays(note)
                }

                // "Want to pin it down?", for something seen but not named.
                if let pinDown {
                    PinDownCard(request: pinDown,
                                onUsed: {
                                    pinDownWasUsed = true
                                    pinDownSkips = 0
                                },
                                onSkip: {
                                    pinDownSkips += 1
                                    self.pinDown = nil
                                },
                                onFinish: { note in
                                    self.pinDown = nil
                                    if let note { addedNotes.append(note) }
                                })
                    // A new card for each find, not the old one reused.
                    .id(pinDown.id)
                }

                // A photo sent with "What is this?": your question and
                // Eira's answer to it. See JournalNaming.swift.
                if let naming {
                    NamingCard(request: naming,
                               onAnswered: { showTop(of: naming.id, with: proxy) },
                               onJournal: { writeAbout(naming) },
                               onFinish: { self.naming = nil })
                    // A new card for each question.
                    .id(naming.id)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        // Opens at the newest line and stays there as lines are added,
        // as a chat does.
        .defaultScrollAnchor(.bottom)
        // The panel can be shorter than a sheet in a small window, so
        // the day so far is allowed to shrink further there.
        .frame(minHeight: panel == nil ? 200 : 80)
    }

    /// Something Eira says: her snowdrop and a pale bubble, on the left.
    private func eiraSays(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            EiraSymbol(size: 28)
            Text(text)
                .font(.body)
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
                        .font(.body.weight(.semibold))
                }
                if !entry.body.isEmpty {
                    Text(entry.body)
                        .font(.body)
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
                Button("Change this entry") { editing = entry }
                Button("Rename") {
                    newTitle = heading
                    renaming = entry
                }
                Button("Delete", role: .destructive) { context.delete(entry) }
            }

            // The stamp, and a pencil that opens the entry to be
            // changed. The pencil is there because press and hold is
            // easy to miss: nothing on screen says it can be done.
            HStack(spacing: 6) {
                Text(stampLine(of: entry))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                Button {
                    editing = entry
                } label: {
                    Image(systemName: "pencil")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                        // A larger area to press than the pencil itself.
                        .frame(width: 30, height: 26)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Change this entry")
                .help("Change this entry")
            }
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
            .font(.footnote)
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
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.ink)
            if checkWasSkipped {
                Text("Choose one and it will be sent.")
                    .font(.footnote)
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
                    .font(.body)
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
    /// to that time and its weather, or to now if `date` is nil. If send
    /// had already been pressed, the entry now goes (see `answer`).
    private func answerPhotoCheck(_ check: JournalChat.PhotoCheck, with date: Date?) {
        let sendWasPressed = checkWasSkipped
        chosenWhen = date
        hasOwnConditions = false
        suggested = conditions(at: stampDate)
        answeredPhotoCheck = check
        // A time has now been chosen by hand, so the words' own question
        // is not put as well.
        checkIsAnswered = true
        checkWasSkipped = false
        if sendWasPressed { send() }
    }

    /// One of the check's buttons was pressed. The stamp is set to that
    /// time and its weather.
    ///
    /// If send had already been pressed, and this question was all that
    /// held the entry back, the entry is sent now. (William, 14 November
    /// 2026: "When I press send, it should send." Until then send had to
    /// be pressed a second time after choosing.) If send has not been
    /// pressed yet, nothing is sent: the answer only sets the stamp.
    private func answer(_ moment: JournalChat.Moment) {
        // `checkWasSkipped` is true only if send was pressed while the
        // question was unanswered. It is read before it is cleared below.
        let sendWasPressed = checkWasSkipped
        chosenWhen = moment == .now ? nil : JournalChat.date(for: moment, now: .now)
        hasOwnConditions = false
        suggested = conditions(at: stampDate)
        checkIsAnswered = true
        checkWasSkipped = false
        if sendWasPressed { send() }
    }

    // MARK: The box to write in

    private var composer: some View {
        composerSurface(VStack(alignment: .leading, spacing: 10) {
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
                        ForEach(waitingPhotos) { waitingPhoto in
                            WaitingPhotoTile(thumbnail: waitingPhoto.thumbnail) {
                                waitingPhotos.removeAll { $0.id == waitingPhoto.id }
                            }
                        }
                    }
                }
            }

            if voice.isListening {
                Text(voice.transcript.isEmpty ? "Listening…" : voice.transcript)
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)
            }

            HStack(alignment: .bottom, spacing: 8) {
                // `.current` asks for each photo as it is stored. Left to
                // itself the chooser may first convert a photo to another
                // format, which takes a moment for each one.
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images,
                             preferredItemEncoding: .current) {
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
                    .focused($boxHasFocus)
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
        })
    }

    /// What the box to write in sits on.
    ///
    /// In a sheet it has a card of glass to itself. In the panel the
    /// panel is already glass, and glass laid on glass turns murky, so
    /// there the box sits straight on the panel's foot with a fine line
    /// above it. That is also where Eira's bar was before it grew, so
    /// the bar seems to have become the box.
    @ViewBuilder
    private func composerSurface<Box: View>(_ box: Box) -> some View {
        if panel == nil {
            box
                .padding(12)
                .glassEffect(.regular.tint(Theme.card.opacity(0.55)), in: .rect(cornerRadius: 24))
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        } else {
            VStack(spacing: 10) {
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(height: 1)
                box
                    .padding(.horizontal, 14)
            }
            .padding(.bottom, 12)
        }
    }

    /// The look of a chip: a small symbol and a few words in a capsule.
    private func chip(_ text: String, symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.footnote)
            Text(text)
                .font(.footnote.weight(.medium))
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
                    .font(.footnote)
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

    // A photo chosen or dropped and not yet sent is a `WaitingPhoto`,
    // drawn as a `WaitingPhotoTile`. Both are in PhotoDrop.swift, since
    // the editor for an entry already written uses them too
    // (JournalEntryEditor.swift).
    //
    // A photo is put in the box the moment it is chosen, as a grey tile
    // with a spinner, and filled in as its parts arrive: first the
    // photo's own bytes, then the small copy to draw. (Until 14
    // November 2026 nothing was shown until both were ready, and the
    // small copy was made on the main thread, so the whole app stood
    // still while it was. See PhotoShrink.swift.)

    /// Takes in a photo whose bytes are already to hand: one dropped
    /// here, or handed over when the conversation opened. Its tile
    /// appears at once and its small copy follows.
    private func addPhoto(_ data: Data) {
        let waitingPhoto = WaitingPhoto()
        waitingPhotos.append(waitingPhoto)
        fill(waitingPhoto.id, with: data)
    }

    /// Puts a photo's bytes into its tile, then has its small copy made
    /// in the background.
    ///
    /// `Task { }` starts a piece of work that runs alongside this
    /// function, which returns straight away. Inside it, `await` is
    /// where the task steps aside while the workshop makes the copy.
    /// When the copy comes back the tile is looked up again by its
    /// label, because it may have been removed with its cross
    /// meanwhile, or sent.
    private func fill(_ id: UUID, with data: Data) {
        guard let slot = waitingPhotos.firstIndex(where: { $0.id == id }) else { return }
        waitingPhotos[slot].data = data
        // The camera's notes are read without opening the picture, so
        // this is quick enough to do here.
        waitingPhotos[slot].facts = PhotoFacts.read(from: data)
        lookUpPhotoWeather()
        Task {
            let small = await PhotoWorkshop.shared.jpeg(from: data, longestSide: PhotoShrink.tileSide)
            guard let slot = waitingPhotos.firstIndex(where: { $0.id == id }) else { return }
            // `??` means "or, if there is none". An empty `Data` marks
            // "tried, and no small copy could be made", so the spinner
            // stops. The photo itself is kept either way.
            waitingPhotos[slot].thumbnail = small ?? Data()
        }
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

    /// Photos chosen with the button.
    ///
    /// A grey tile goes in the box for each one straight away, in the
    /// order chosen. The photos themselves are then fetched all at the
    /// same time, each in a task of its own, and each fills its own
    /// tile when it arrives. Fetching can take a while: a photo kept
    /// in iCloud has to be downloaded first.
    private func loadPicked(_ items: [PhotosPickerItem]) {
        pickerItems = []
        let coming = items.map { _ in WaitingPhoto() }
        waitingPhotos.append(contentsOf: coming)
        // `zip` pairs the two lists up: first with first, and so on.
        for (item, waitingPhoto) in zip(items, coming) {
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    fill(waitingPhoto.id, with: data)
                } else {
                    // It could not be fetched. Its tile goes.
                    waitingPhotos.removeAll { $0.id == waitingPhoto.id }
                }
            }
        }
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
    ///
    /// The same is done when a garden does have a location but the
    /// weather diary has no figures for that hour yet, as for earlier
    /// today, since the diary is filled a day at a time. Before 14
    /// November 2026 this case was left blank: "The weather service has
    /// no figures for this time" for ten o'clock the same morning.
    private func askServiceIfMissing() async {
        let near: CLLocationCoordinate2D
        if let place {
            near = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        } else if let last = WeatherService.shared.lastPlace {
            near = last
        } else {
            return
        }
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
        // A photo still on its way would be left behind. The send
        // button is greyed out meanwhile. This catches the Return key.
        guard !photosAreComing else { return }

        // On an iPhone or iPad, pressing send puts the keyboard away at
        // once, whatever happens next. (William, 14 November 2026, on the
        // iPad: "it could be resolved by when you press send the keyboard
        // goes".) The keyboard covers the lower half of the screen there,
        // and what send leads to is drawn exactly where it sits: the new
        // entry, or the question below about when this was, which has to
        // be seen to be answered.
        //
        // `boxHasFocus` is the @FocusState declared at the top of this
        // view. Setting it to false takes the cursor out of the box, and
        // iOS lowers the keyboard when no box has the cursor.
        //
        // `#if os(iOS)` means the lines are only compiled for an iPhone
        // or iPad. A Mac has no keyboard on the screen, and there the
        // cursor should stay in the box ready for the next entry.
        #if os(iOS)
        boxHasFocus = false
        #endif

        // A photo with words that ask what it is ("What is this?") is a
        // question for Eira and not an entry. She looks at the photo and
        // answers in a card. Nothing is written in the journal, so
        // nobody is asked when it was. (William, 15 November 2026:
        // "Weird that I can't say what is this without selecting the
        // time it was sent?")
        //
        // This comes before the check below on purpose: that check is
        // what used to hold such a question back.
        if asksForAName {
            askForAName(text)
            return
        }

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
            guard let data = waiting.data else { continue }
            // The photo keeps the time it was taken, whichever time the
            // entry is stamped with.
            let photo = Photo.record(of: data, facts: waiting.facts, thumbnail: waiting.thumbnailToKeep,
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

        // Something seen but not named: offer to pin it down. An offer
        // still waiting from the last entry, never used, counts as a
        // skip. So does a find that is not offered while Eira is asking
        // less often, or the count would never move on to the next time
        // she asks.
        if pinDown != nil, !pinDownWasUsed { pinDownSkips += 1 }
        pinDown = nil
        pinDownWasUsed = false
        if let find = JournalChat.unnamedFind(in: text) {
            if JournalChat.shouldOfferPinDown(skipsInARow: pinDownSkips) {
                pinDown = PinDownRequest(find: find, date: entry.date, bed: aboutBed,
                                         photo: waitingPhotos.first?.data)
            } else {
                pinDownSkips += 1
            }
        }

        // An answer about a photo left under the last thing said is
        // finished with once something new is written.
        naming = nil
        photosAreForAnEntry = false

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

        // In the panel that grows out of Eira's bar, an entry Eira has
        // nothing to ask about puts the panel away by itself, so the
        // Journal page is showing again with the entry on it. (William,
        // 14 November 2026: "I shouldnt then need to press done.")
        //
        // The panel stays up only when she has put a card under the
        // entry that needs an answer: a harvest or sowing to add
        // (`offers`), something seen to pin down (`pinDown`), or a plant
        // the library does not have. Closing then would throw the card
        // away unseen.
        //
        // `if let panel` runs only when this is drawn in the panel. In
        // a sheet `panel` is nil and nothing here happens.
        if let panel, offers.isEmpty, pinDown == nil,
           NewPlantMention.name(in: text, known: plants.map(\.commonName)) == nil {
            // Lets go of the keyboard, so it does not cover the page.
            boxHasFocus = false
            // The same thing Done does: EiraFloatingBar's `lowerPanel`.
            panel.close()
        }
    }

    // MARK: Asking what a photo is

    /// Hands the photos in the box to Eira with the question, and
    /// empties the box. Nothing is saved: the card that answers has its
    /// own buttons for that (JournalNaming.swift).
    private func askForAName(_ text: String) {
        // Only photos whose bytes have arrived. Send is held back while
        // one is still on its way (`photosAreComing`), so this is all
        // of them.
        let ready = waitingPhotos.filter { $0.data != nil }
        naming = NamingRequest(words: text,
                               originals: ready.compactMap(\.data),
                               facts: ready.map(\.facts),
                               tiles: ready.map(\.thumbnailToKeep),
                               bed: aboutBed)

        // The box is cleared as it is after an entry, and the stamp put
        // back to now, so that nothing chosen for this photo is carried
        // over to the next thing written.
        words = ""
        waitingPhotos = []
        chosenWhen = nil
        hasOwnConditions = false
        checkIsAnswered = false
        checkWasSkipped = false
        answeredPhotoCheck = nil
        suggested = conditions(at: .now)
    }

    /// Brings the top of Eira's answer to a photo into view.
    ///
    /// The conversation keeps itself at its newest line, the bottom. Her
    /// answer is a tall card, taller than an iPhone's screen, so left
    /// alone only its foot would show and the name she gives, which is
    /// at its top, would be out of sight above. `scrollTo` moves the
    /// list so the card's top (your question and the photo) sits at the
    /// top instead. Where the whole card fits anyway, nothing moves.
    ///
    /// The short wait lets the card be laid out at its new height
    /// first: asked too soon, the list would move to where the top of
    /// the small "Looking…" card had been.
    private func showTop(of id: UUID, with proxy: ScrollViewProxy) {
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(id, anchor: .top)
            }
        }
    }

    /// "Write a journal entry with it" on Eira's answer: the photos go
    /// back in the box, to be written about and sent as an entry.
    ///
    /// The question itself is not put back. `photosAreForAnEntry` makes
    /// the next thing sent an entry whatever its words say, so that the
    /// same photos are not asked about a second time.
    private func writeAbout(_ request: NamingRequest) {
        naming = nil
        photosAreForAnEntry = true
        for original in request.originals { addPhoto(original) }
        boxHasFocus = true
    }
}
