//
//  JournalEntryEditor.swift
//  Windfall
//
//  Changing a journal entry that has already been written.
//
//  Why this file exists (William, 14 November 2026: "There's also no
//  way to edit journal entries"). There was one way: pressing and
//  holding an entry in the journal's conversation, which nothing on
//  screen gave away, and which only reached the entries of the day
//  the conversation was showing. An entry on the Journal page could
//  not be opened at all. And what press and hold led to was the old
//  diary form, a standard `Form` in the system's look.
//
//  Now an entry opens in this sheet:
//
//  - from the Journal page, by tapping the entry (JournalViews.swift)
//  - from the journal's conversation, by the pencil under an entry or
//    by pressing and holding it (JournalChatView.swift)
//
//  Everything about the entry can be changed here: its words, its
//  heading, when it was, the weather, which bed it is about and its
//  photos. It can also be deleted.
//
//  How it works. The sheet does not change the entry as you type. It
//  keeps its own copy of each thing, the "draft", in `@State`, and
//  only writes the draft into the entry when Save is pressed. So
//  Cancel really does leave the entry as it was. (The old form wrote
//  every key press straight into the entry, so its Cancel could not
//  undo anything.)
//
//  The sheet is built from the shared pieces in SheetParts.swift, so
//  it looks like the rest of the app.
//
//  The rule for what happens to the heading is in JournalChat.swift
//  (`JournalChat.heading`), apart from the screen, so that it can be
//  tested without one.
//
//  New things here:
//
//  confirmationDialog   A small "Are you sure?" that slides up from
//                       the button that was pressed. Used before
//                       deleting, because a deleted entry cannot be
//                       brought back.
//

import SwiftUI
import SwiftData
import PhotosUI

struct JournalEntrySheet: View {

    /// The entry being changed.
    private let entry: DiaryEntry

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Bed> { $0.retiredAt == nil },
           sort: [SortDescriptor(\Bed.displayOrder)]) private var beds: [Bed]
    @Query(sort: [SortDescriptor(\Garden.displayOrder)]) private var gardens: [Garden]
    /// The plant library, for writing a heading that favours a sentence
    /// naming something in the garden.
    @Query(sort: [SortDescriptor(\Plant.commonName)]) private var plants: [Plant]

    // The draft: a copy of each thing that can be changed.
    @State private var words: String
    @State private var heading: String
    @State private var when: Date
    @State private var weather: Weather?
    @State private var temperature: Double?
    @State private var aboutBed: Bed?

    // The photos.
    /// Photos already with the entry that are to be taken off when Save
    /// is pressed, by each photo's own label.
    @State private var removedPhotos: Set<UUID> = []
    /// Photos added here, not yet kept. See PhotoDrop.swift.
    @State private var newPhotos: [WaitingPhoto] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isDropTarget = false

    /// The weather diary's figures for the time now chosen, if the time
    /// has been changed and the diary has that hour.
    @State private var weatherThen: CurrentConditions?
    @State private var isAskingToDelete = false
    /// True once the entry has been deleted from here. The sheet then
    /// draws nothing in the moment before it closes, so that it does
    /// not read from a record that is no longer there.
    @State private var isGone = false

    init(entry: DiaryEntry) {
        self.entry = entry
        // `_words` is the storage behind `@State var words`. This is how
        // a starting value is handed to it.
        _words = State(initialValue: entry.body)
        // The heading box opens holding whichever heading the entry
        // shows: your own if there is one, otherwise the one written
        // from its words.
        let own = entry.title ?? ""
        _heading = State(initialValue: own.isEmpty ? (entry.generatedSummary ?? "") : own)
        _when = State(initialValue: entry.date)
        _weather = State(initialValue: entry.weather)
        _temperature = State(initialValue: entry.temperatureC)
        _aboutBed = State(initialValue: entry.scope == .bed ? entry.bed : nil)
    }

    // MARK: Worked out from the above

    private var trimmedWords: String {
        words.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The entry's photos that are staying.
    private var keptPhotos: [Photo] {
        (entry.photos ?? []).filter { !removedPhotos.contains($0.id) }
    }

    /// An entry needs words or a photo, and Save waits for any photo
    /// that is still being fetched.
    private var canSave: Bool {
        guard !newPhotos.contains(where: { $0.data == nil }) else { return false }
        return !trimmedWords.isEmpty || !keptPhotos.isEmpty || !newPhotos.isEmpty
    }

    /// True where the entry is about the garden or one bed, which is
    /// all the journal's conversation ever sets. An entry tied to a
    /// sowing or a plant some other way is left as it is.
    private var showsAbout: Bool {
        (entry.scope == .garden || entry.scope == .bed) && !bedChoices.isEmpty
    }

    /// The beds to choose from: those in use, and the entry's own bed
    /// if that one has since been retired.
    private var bedChoices: [Bed] {
        if let aboutBed, !beds.contains(where: { $0.id == aboutBed.id }) { return beds + [aboutBed] }
        return beds
    }

    /// "First written Saturday 14 November at 15:36".
    private var writtenLine: String {
        "First written \(entry.createdAt.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()))"
    }

    /// The weather diary's figures for the chosen time as the journal's
    /// own word and a rounded temperature, where they differ from what
    /// the draft holds. Nil when there is nothing to offer.
    private var offeredWeather: (weather: Weather, temperatureC: Double, says: String)? {
        guard let weatherThen else { return nil }
        let sky = JournalChat.weatherWord(for: weatherThen)
        // One decimal place is as exact as the figure is.
        let degrees = (weatherThen.temperatureC * 10).rounded() / 10
        guard sky != weather || degrees != temperature,
              let says = JournalChat.stampWords(weather: sky, temperatureC: degrees) else { return nil }
        return (sky, degrees, says)
    }

    // MARK: Body

    var body: some View {
        if isGone {
            Color.clear
        } else {
            page
        }
    }

    private var page: some View {
        SheetPage("Journal entry", detail: writtenLine,
                  confirmTitle: "Save", canConfirm: canSave, onConfirm: save) {
            SheetScroll {
                wordsCard
                whenCard
                if showsAbout { aboutCard }
                photosCard
                deleteCard
            }
        }
        // The weather diary is asked about a time only once that time
        // has been changed. `onChange` runs its closure whenever the
        // value it names changes.
        .onChange(of: when) { _, chosen in
            weatherThen = diaryConditions(at: chosen)
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            loadPicked(items)
        }
        // Photos can be dragged on to any part of the sheet.
        .onDrop(of: PhotoDrop.kinds, isTargeted: $isDropTarget) { providers in
            guard PhotoDrop.mayHold(providers) else { return false }
            Task {
                for data in await PhotoDrop.pictures(from: providers) { addPhoto(data) }
            }
            return true
        }
        .overlay {
            if isDropTarget {
                PhotoDropOutline(words: "Drop photos to add them")
            }
        }
        .confirmationDialog("Delete this entry?", isPresented: $isAskingToDelete, titleVisibility: .visible) {
            // `role: .destructive` tells the system this button removes
            // something, and it is drawn red.
            Button("Delete", role: .destructive) { deleteEntry() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its photos go with it. This cannot be undone.")
        }
    }

    // MARK: The cards

    private var wordsCard: some View {
        SheetCard("What you wrote") {
            FieldBox {
                // `axis: .vertical` lets the box grow downwards as the
                // words run on: from three lines to fourteen, then it
                // scrolls.
                TextField("What happened in the garden?", text: $words, axis: .vertical)
                    .lineLimit(3...14)
            }
            FieldBox {
                TextField("Heading", text: $heading)
            }
            Text((entry.title ?? "").isEmpty
                 ? "The heading is written from your words, and written again if you change them. Type over it to give the entry a heading of your own."
                 : "This heading is your own. Empty the box to have one written from your words.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var whenCard: some View {
        SheetCard("When and weather") {
            SettingRow("When") {
                // `...Date.now` means "any time up to now": an entry
                // cannot be about the future.
                DatePicker("When", selection: $when, in: ...Date.now)
                    .labelsHidden()
            }

            SettingRow("Weather") {
                Picker("Weather", selection: $weather) {
                    // `Weather?.none` is "no weather noted". The tags
                    // must be the same type as `weather`, which is
                    // optional.
                    Text("Not noted").tag(Weather?.none)
                    ForEach(Weather.allCases) { kind in
                        Text(kind.displayName).tag(Weather?.some(kind))
                    }
                }
                .labelsHidden()
            }

            SettingRow("Temperature, °C") {
                FieldBox {
                    TextField("°C", value: $temperature, format: .number)
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        // The keyboard with numbers and a minus sign,
                        // for a frost. The plain number pad has no minus.
                        .keyboardType(.numbersAndPunctuation)
                        #endif
                }
                .frame(width: 96)
            }

            // The weather does not follow the time by itself, because
            // what is there may be what you noted yourself. Where the
            // weather diary has the new time, it is offered.
            if let offered = offeredWeather {
                Button("Use the weather diary's figures for then: \(offered.says)") {
                    weather = offered.weather
                    temperature = offered.temperatureC
                }
                .buttonStyle(QuietGlassButton())
            }
        }
    }

    private var aboutCard: some View {
        SheetCard {
            SettingRow("About") {
                Picker("About", selection: $aboutBed) {
                    Text("The garden").tag(Bed?.none)
                    ForEach(bedChoices) { bed in
                        Text(bed.name).tag(Bed?.some(bed))
                    }
                }
                .labelsHidden()
            }
        }
    }

    private var photosCard: some View {
        SheetCard("Photos") {
            if !keptPhotos.isEmpty || !newPhotos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(keptPhotos) { keptPhoto in
                            keptTile(keptPhoto)
                        }
                        ForEach(newPhotos) { waitingPhoto in
                            WaitingPhotoTile(thumbnail: waitingPhoto.thumbnail, size: 72) {
                                newPhotos.removeAll { $0.id == waitingPhoto.id }
                            }
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                // `.current` asks for each photo as it is stored, without
                // the chooser converting it to another format first.
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images,
                             preferredItemEncoding: .current) {
                    Label("Add photos", systemImage: "photo.badge.plus")
                }
                .buttonStyle(QuietGlassButton())

                if !removedPhotos.isEmpty {
                    Button("Put back \(removedPhotos.count == 1 ? "the photo" : "the \(removedPhotos.count) photos") taken off") {
                        removedPhotos = []
                    }
                    .buttonStyle(QuietGlassButton())
                }
            }
        }
    }

    /// A photo already with the entry, with a cross to take it off.
    /// Nothing is removed until Save is pressed.
    private func keptTile(_ keptPhoto: Photo) -> some View {
        PhotoThumbnail(photo: keptPhoto, size: 72)
            .overlay(alignment: .topTrailing) {
                Button {
                    removedPhotos.insert(keptPhoto.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 20, height: 20)
                        .background(Theme.card, in: .circle)
                }
                .buttonStyle(.plain)
                .padding(3)
                .accessibilityLabel("Take this photo off")
            }
    }

    private var deleteCard: some View {
        SheetCard {
            Button("Delete this entry", role: .destructive) {
                isAskingToDelete = true
            }
            .buttonStyle(QuietGlassButton())
        }
    }

    // MARK: Photos

    /// Takes in a photo whose bytes are already to hand: one dropped
    /// here. Its tile appears at once and its small copy follows.
    private func addPhoto(_ data: Data) {
        let waitingPhoto = WaitingPhoto()
        newPhotos.append(waitingPhoto)
        fill(waitingPhoto.id, with: data)
    }

    /// Puts a photo's bytes into its tile, then has its small copy made
    /// in the background (PhotoShrink.swift). The tile is looked up
    /// again by its label when the copy comes back, because it may have
    /// been taken off with its cross meanwhile.
    private func fill(_ id: UUID, with data: Data) {
        guard let slot = newPhotos.firstIndex(where: { $0.id == id }) else { return }
        newPhotos[slot].data = data
        newPhotos[slot].facts = PhotoFacts.read(from: data)
        Task {
            let small = await PhotoWorkshop.shared.jpeg(from: data, longestSide: PhotoShrink.tileSide)
            guard let slot = newPhotos.firstIndex(where: { $0.id == id }) else { return }
            // `??` means "or, if there is none". An empty `Data` marks
            // "tried, and no small copy could be made", so the spinner
            // stops. The photo itself is kept either way.
            newPhotos[slot].thumbnail = small ?? Data()
        }
    }

    /// Photos chosen with the button: a grey tile for each at once, then
    /// each is fetched in a task of its own and fills its tile when it
    /// arrives. The same way as the journal's conversation.
    private func loadPicked(_ items: [PhotosPickerItem]) {
        pickerItems = []
        let coming = items.map { _ in WaitingPhoto() }
        newPhotos.append(contentsOf: coming)
        for (item, waitingPhoto) in zip(items, coming) {
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    fill(waitingPhoto.id, with: data)
                } else {
                    newPhotos.removeAll { $0.id == waitingPhoto.id }
                }
            }
        }
    }

    // MARK: The weather for another time

    /// That hour from the weather diary, for the first garden that has
    /// a place. Nil if no garden has one or the diary has no figures
    /// for that day. The same lookup as the journal's conversation
    /// makes for a time other than now.
    private func diaryConditions(at date: Date) -> CurrentConditions? {
        guard let place = WeatherDiary.places(for: gardens).first else { return nil }
        let key = WeatherDiary.dayKey(for: date)
        let site = place.site
        // A FetchDescriptor is a question put to the records: here, the
        // weather day with that date for that garden. One is enough.
        var find = FetchDescriptor<WeatherDay>(predicate: #Predicate { $0.dayKey == key && $0.siteRaw == site })
        find.fetchLimit = 1
        guard let day = try? context.fetch(find).first,
              let hours = WeatherDiary.hours(of: day) else { return nil }
        return hours.conditions(atHour: Calendar.current.component(.hour, from: date))
    }

    // MARK: Saving and deleting

    /// Writes the draft into the entry.
    private func save() {
        // The heading. Names from the garden count for more when one is
        // written from the words, as when an entry is first sent.
        let gardenNames = Set(plants.flatMap { JournalChat.roots(in: $0.commonName) + JournalChat.roots(in: $0.variety ?? "") }
                              + beds.flatMap { JournalChat.roots(in: $0.name) })
        let headings = JournalChat.heading(own: entry.title, written: entry.generatedSummary, typed: heading,
                                           oldWords: entry.body, newWords: trimmedWords, known: gardenNames)
        entry.title = headings.own
        if headings.writtenIsNew {
            entry.generatedSummary = headings.written
            entry.summaryGeneratedAt = headings.written == nil ? nil : .now
        }

        entry.body = trimmedWords
        entry.date = when
        entry.weather = weather
        entry.temperatureC = temperature
        if showsAbout {
            entry.scope = aboutBed == nil ? .garden : .bed
            entry.bed = aboutBed
        }

        // Photos taken off. Each is unhooked from the entry first and
        // then deleted from the records.
        let leaving = (entry.photos ?? []).filter { removedPhotos.contains($0.id) }
        entry.photos?.removeAll { removedPhotos.contains($0.id) }
        for photo in leaving { context.delete(photo) }

        // Photos added. Every place that keeps a photo goes through
        // Photo.record (PhotoDrop.swift), so that each keeps its own
        // date and its original.
        for waitingPhoto in newPhotos {
            guard let data = waitingPhoto.data else { continue }
            let photo = Photo.record(of: data, facts: waitingPhoto.facts, thumbnail: waitingPhoto.thumbnailToKeep,
                                     otherwiseAt: when)
            photo.diaryEntry = entry
            entry.photos?.append(photo)
        }

        entry.modifiedAt = .now
        dismiss()
    }

    private func deleteEntry() {
        isGone = true
        // Deleting the entry deletes its photos with it: the record
        // says so (`deleteRule: .cascade` in Journal.swift).
        context.delete(entry)
        dismiss()
    }
}
