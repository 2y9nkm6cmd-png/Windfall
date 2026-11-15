//
//  JournalViews.swift
//  Windfall
//
//  The Journal page, a day to a card, and the diary form.
//  The sums for the page (which day, which words) are in JournalPage.swift.
//
//  New entries are written in JournalChatView.swift, as a conversation.
//  An entry already written is changed in JournalEntryEditor.swift,
//  which opens when the entry is tapped on this page.
//
//  The form here (DiaryEntryEditor) is the old way of changing an
//  entry. Since 14 November 2026 nothing opens it. It is kept because
//  the function that makes a small copy of a photo lives in it and is
//  used all over the app.
//
//  New things here:
//
//  PhotosPicker    Apple's photo chooser. Gives back an opaque item that
//                  you load data from asynchronously — the picture is not
//                  handed over immediately.
//
//  .task           runs async work tied to a view's lifetime. Cancelled
//                  automatically when the view goes away, which is what
//                  stops a half-loaded photo writing into a dead view.
//
//  Multiple @Query properties in one view. The timeline needs seven,
//  because SwiftData can't query across a protocol.
//

import SwiftUI
import SwiftData
import PhotosUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Timeline

/// Photos dropped on the Journal page, on their way to the journal's
/// conversation. `Identifiable` lets SwiftUI tell one drop from the next.
private struct JournalStart: Identifiable {
    let id = UUID()
    let photos: [Data]
}

/// The Journal page: every day that has anything in it, newest first,
/// each as a card. A day's card holds what was written that day and
/// what was recorded: sowings, harvests, sightings and counts.
///
/// It is drawn like Today, Gardens and Wildlife: the serif title, glass
/// cards and the app's own icons. Until 13 November 2026 it was a plain
/// list with Apple's symbols in seven colours, which William said
/// "doesn't tie in with the overall design".
struct JournalTimelineView: View {

    // One query per record type. They all update independently.
    @Query(sort: [SortDescriptor(\DiaryEntry.date, order: .reverse)])
    private var diary: [DiaryEntry]

    @Query private var plantings: [Planting]
    @Query private var phenology: [PhenologyEvent]
    @Query private var harvests: [Harvest]
    @Query private var problems: [PestDiseaseEvent]
    @Query private var surveys: [Survey]
    @Query private var sightings: [WildlifeObservation]
    /// The weather diary, for the line of weather on each day's card.
    @Query(sort: [SortDescriptor(\WeatherDay.dayKey, order: .reverse)])
    private var weatherDays: [WeatherDay]

    @State private var kinds: Set<TimelineKind> = Set(TimelineKind.allCases)
    /// Set when photos are dropped on the page. It opens the journal's
    /// conversation with those photos in its box.
    @State private var droppedStart: JournalStart?
    /// True while photos are being held over the page.
    @State private var isDropTarget = false
    /// The entry that was tapped, while its editor is open. Nil when
    /// none is. `.sheet(item:)` below shows the editor whenever this
    /// holds an entry.
    @State private var entryToChange: DiaryEntry?
    /// The tracker Eira's bar watches. Dropped photos are handed to
    /// the bar through it, and the bar's panel grows up with them in
    /// it. The question mark means "if there is one". See EiraScreen.
    @Environment(EiraScreen.self) private var eiraScreen: EiraScreen?

    /// Everything of every kind, whatever the filter says. The counts
    /// beside each kind are made from this.
    private var everything: [TimelineItem] {
        TimelineBuilder.build(diary: diary, plantings: plantings, phenology: phenology,
                              harvests: harvests, problems: problems, surveys: surveys,
                              sightings: sightings)
    }

    var body: some View {
        // Worked out once for the whole redraw.
        let everything = self.everything
        let shown = everything.filter { kinds.contains($0.kind) }
        let months = JournalPage.months(of: shown)

        return GeometryReader { geometry in
            let isWide = geometry.size.width >= 840
            let isNarrow = geometry.size.width < 600
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(title: "Journal", detail: summary(of: everything))

                    if isWide {
                        // Days on the left, what to show on the right.
                        HStack(alignment: .top, spacing: 14) {
                            dayCards(months, isEmpty: everything.isEmpty)
                            filterCard(counting: everything)
                                .frame(width: min(geometry.size.width * 0.265, 300))
                        }
                    } else {
                        filterChips(counting: everything)
                        dayCards(months, isEmpty: everything.isEmpty)
                    }
                }
                .padding(.leading, isNarrow ? 16 : 14)
                .padding(.trailing, isNarrow ? 16 : 24)
                .padding(.top, 12)
                // 20 points of air under the last card, and as much
                // again as Eira's bar covers, so that the last entry
                // can be scrolled up clear of it.
                .padding(.bottom, 20 + hiddenByBar(geometry))
            }
            // A checking aid (`-demoJournalEnd YES`): start at the foot
            // of the page. Otherwise at the top, as any page does.
            .defaultScrollAnchor(DemoGarden.journalStartsAtEnd ? .bottom : .top)
        }
        .paperScreen()
        .navigationTitle("Journal")
        #if os(iOS)
        // The page has its own title, as Today does.
        .toolbar(.hidden, for: .navigationBar)
        #endif
        // Photos dragged on to the page start an entry. `isTargeted`
        // is switched on by SwiftUI while something is held over the
        // page, which is when the dashed outline is drawn.
        .onDrop(of: PhotoDrop.kinds, isTargeted: $isDropTarget) { providers in
            guard PhotoDrop.mayHold(providers) else { return false }
            Task {
                let pictures = await PhotoDrop.pictures(from: providers)
                guard !pictures.isEmpty else { return }
                if let eiraScreen {
                    // Eira's bar is at the foot of this page. It takes
                    // the photos and opens the conversation in its
                    // panel, so no second window comes up.
                    eiraScreen.handToBar(pictures)
                } else {
                    droppedStart = JournalStart(photos: pictures)
                }
            }
            return true
        }
        .overlay {
            if isDropTarget {
                PhotoDropOutline(words: "Drop to start a journal entry")
            }
        }
        // Writing is a conversation with Eira (JournalChatView.swift).
        // It is opened from her bar at the foot of the page, which on
        // this page reads "Tell Eira what happened in the garden", or
        // by dropping photos here. Either way it grows out of the bar.
        // This sheet is only for a Journal page shown where there is
        // no bar, such as a preview.
        .sheet(item: $droppedStart) { start in
            JournalChatView(photos: start.photos)
        }
        // An entry that was tapped, opened to be changed or deleted
        // (JournalEntryEditor.swift).
        .sheet(item: $entryToChange) { entry in
            JournalEntrySheet(entry: entry)
        }
    }

    // MARK: Room for Eira's bar

    /// How much of the foot of this page lies under Eira's bar, in
    /// points. Nothing, where the page already stops above the bar.
    ///
    /// Why it is needed. MainTabView keeps a strip clear along the
    /// bottom of every page for the bar (`safeAreaInset`), and a
    /// scrolling page is meant to stop above that strip. On an iPad the
    /// strip was found not to reach this page (William's picture, 15
    /// November 2026: the last entry sat behind the bar and would not
    /// scroll clear). The strip is put round the NavigationStack, and
    /// the page inside the stack was not told about it.
    ///
    /// So the page checks for itself. `geometry.frame(in: .global)` is
    /// where this page sits in the window, and its `maxY` is the page's
    /// bottom edge. `barLine` is where the strip begins. If the page's
    /// bottom edge is lower than that line, the difference is how much
    /// the bar hides, and that much is added under the last card. If
    /// the strip did reach the page, the two are the same, the answer
    /// is nothing and no room is added twice.
    private func hiddenByBar(_ geometry: GeometryProxy) -> CGFloat {
        // `guard let` stops here with 0 if there is no tracker or the
        // line has not been measured yet.
        guard let line = eiraScreen?.barLine else { return 0 }
        let hidden = geometry.frame(in: .global).maxY - line
        // Never less than nothing, and never more than 120 points,
        // in case a measurement is taken part-way through a change of
        // layout.
        return min(max(hidden, 0), 120)
    }

    // MARK: The line above the title

    /// "3 entries and 14 records this year".
    private func summary(of everything: [TimelineItem]) -> String {
        let year = Calendar.current.component(.year, from: .now)
        let thisYear = everything.filter { Calendar.current.component(.year, from: $0.date) == year }
        let entries = thisYear.filter { $0.kind == .diary }.count
        let records = thisYear.count - entries
        return "\(entries) \(entries == 1 ? "entry" : "entries") and \(records) \(records == 1 ? "record" : "records") this year"
    }

    // MARK: Choosing what is shown

    private func count(of kind: TimelineKind, in everything: [TimelineItem]) -> Int {
        everything.filter { $0.kind == kind }.count
    }

    private func toggle(_ kind: TimelineKind) {
        if kinds.contains(kind) { kinds.remove(kind) } else { kinds.insert(kind) }
    }

    /// On a wide screen: a card down the right with a tick for each kind.
    private func filterCard(counting everything: [TimelineItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Show")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)

            ForEach(TimelineKind.allCases) { kind in
                Button {
                    toggle(kind)
                } label: {
                    HStack(spacing: 10) {
                        TickBox(isOn: kinds.contains(kind))
                        JournalIcon(kind: kind, title: "", size: 20)
                        Text(kind.displayName)
                            .font(.body)
                            .foregroundStyle(Theme.ink)
                        Spacer(minLength: 4)
                        Text("\(count(of: kind, in: everything))")
                            .font(.footnote)
                            .monospacedDigit()
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(kinds.contains(kind) ? .isSelected : [])
            }

            if kinds.count < TimelineKind.allCases.count {
                Button("Show everything") { kinds = Set(TimelineKind.allCases) }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(QuietGlassButton())
                    .tint(Theme.leaf)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    /// On a narrower screen: the same choices as a row of buttons that
    /// scrolls sideways.
    private func filterChips(counting everything: [TimelineItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TimelineKind.allCases) { kind in
                    let isOn = kinds.contains(kind)
                    Button {
                        toggle(kind)
                    } label: {
                        HStack(spacing: 6) {
                            JournalIcon(kind: kind, title: "", size: 16)
                            Text(kind.displayName)
                            Text("\(count(of: kind, in: everything))")
                                .foregroundStyle(Theme.inkSoft)
                        }
                        .font(.footnote)
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint((isOn ? Theme.leafFill : Theme.card).opacity(isOn ? 0.9 : 0.5)), in: .capsule)
                    .opacity(isOn ? 1 : 0.6)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: The days

    @ViewBuilder
    private func dayCards(_ months: [JournalPage.Month], isEmpty: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if months.isEmpty {
                Text(isEmpty
                     ? "Nothing recorded yet. Tell Eira what happened in the bar below, or drop photos on this page. Entries, sowings, harvests and sightings all appear here together, a day to a card."
                     : "Nothing of the kinds chosen. Tick more under Show.")
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
            }
            ForEach(months) { month in
                HubSectionTitle(month.start.formatted(.dateTime.month(.wide).year()))
                ForEach(month.days) { day in
                    dayCard(day)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dayCard(_ day: JournalPage.Day) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(JournalPage.title(for: day.start))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                if let words = weatherWords(for: day.start) {
                    Text(words)
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            ForEach(day.items) { item in
                row(for: item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    /// One line of a day's card. Something you wrote is a button: a
    /// tap opens it to be changed. (William, 14 November 2026: "There's
    /// also no way to edit journal entries".) The other records, such
    /// as sowings and sightings, are changed on their own pages and are
    /// drawn as they were.
    ///
    /// A row only knows the entry's label, its `id`. The entry itself
    /// is found by looking for that label among the diary's entries.
    @ViewBuilder
    private func row(for item: TimelineItem) -> some View {
        if item.kind == .diary, let entry = diary.first(where: { $0.id == item.id }) {
            Button {
                entryToChange = entry
            } label: {
                JournalRow(item: item, canBeChanged: true)
                    // Makes the whole row take the tap, gaps included.
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the entry so you can change it")
        } else {
            JournalRow(item: item)
        }
    }

    /// "3 to 9°C · 2.4 mm of rain", from the weather diary, if it has
    /// that day.
    private func weatherWords(for day: Date) -> String? {
        let key = JournalPage.dayKey(for: day)
        guard let record = weatherDays.first(where: { $0.dayKey == key }) else { return nil }
        return JournalPage.weatherWords(low: record.minTemperatureC, high: record.maxTemperatureC,
                                        rainMM: record.rainfallMM)
    }
}

// MARK: - Timeline row

/// One thing on a day's card: its icon, what it is, when, and any words
/// or photos that go with it.
private struct JournalRow: View {

    let item: TimelineItem
    /// True for something that opens to be changed when tapped. A small
    /// pencil is drawn at the end of the row to say so.
    var canBeChanged = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            JournalIcon(kind: item.kind, title: item.title, size: 26)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(JournalPage.caption(kind: item.kind.rowName, at: item.date))
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)

                if let detail = item.detail, !detail.isEmpty {
                    // What was written is the point of a diary entry, so
                    // it gets room and the ordinary ink. For a record it
                    // is a note, and stays small.
                    Text(detail)
                        .font(item.kind == .diary ? .body : .footnote)
                        .foregroundStyle(item.kind == .diary ? Theme.ink : Theme.inkSoft)
                        .lineLimit(item.kind == .diary ? 8 : 3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, item.kind == .diary ? 2 : 0)
                }

                if !item.photos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(item.photos) { photo in
                                PhotoThumbnail(photo: photo, size: 72)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if canBeChanged {
                Image(systemName: "pencil")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 3)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// The picture for a kind of record, from the app's own set where it
/// has one. A sighting gets a butterfly, a bee or a ladybird if its name
/// says so.
private struct JournalIcon: View {

    let kind: TimelineKind
    let title: String
    let size: CGFloat

    var body: some View {
        switch kind {
        case .diary:
            WIconView(.journalEntry, size: size).foregroundStyle(Theme.leaf)
        case .planting:
            WIconView(.sowing, size: size).foregroundStyle(Theme.leaf)
        case .phenology:
            WIconView(.sprig, size: size).foregroundStyle(Theme.leaf)
        case .harvest:
            WIconView(.harvest, size: size).foregroundStyle(Theme.leaf)
        case .survey:
            WIconView(.fitCount, size: size).foregroundStyle(Theme.leaf)
        case .sighting:
            WIconView(title.isEmpty ? .sighting : RecentRecord.picture(forSighting: title, group: nil), size: size)
                .foregroundStyle(Theme.leaf)
        case .problem:
            // No drawing of our own for this one yet.
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: size * 0.75))
                .foregroundStyle(Theme.amber)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Photo thumbnail

struct PhotoThumbnail: View {

    let photo: Photo
    var size: CGFloat = 72

    var body: some View {
        Group {
            if let image = loadedImage {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.secondary.opacity(0.15))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    /// Prefers the thumbnail. Decoding full-size images in a scrolling
    /// list is the classic cause of stutter.
    private var loadedImage: Image? {
        (photo.thumbnailData ?? photo.imageData).flatMap { Self.image(from: $0) }
    }

    /// Turns stored picture data into something SwiftUI can draw. An
    /// iPhone and a Mac each have their own kind of picture, which is
    /// why there are two ways round. Also used for photos waiting to be
    /// sent in the journal's conversation.
    static func image(from data: Data) -> Image? {
        #if os(iOS)
        guard let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
        #elseif os(macOS)
        guard let ns = NSImage(data: data) else { return nil }
        return Image(nsImage: ns)
        #endif
    }
}

// MARK: - Diary editor

struct DiaryEntryEditor: View {

    @Bindable var entry: DiaryEntry

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Bed.displayOrder)]) private var beds: [Bed]

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $entry.date, displayedComponents: .date)

                    TextField("Title (optional)", text: Binding(
                        get: { entry.title ?? "" },
                        set: { entry.title = $0.isEmpty ? nil : $0 }
                    ))
                } footer: {
                    if entry.titleIsGenerated {
                        Label("Heading written by Eira", systemImage: "sparkles")
                            .font(.footnote)
                    }
                }

                Section("Entry") {
                    TextField("What happened in the garden?",
                              text: $entry.body, axis: .vertical)
                        .lineLimit(6...20)
                }

                Section("About") {
                    Picker("Scope", selection: Binding(
                        get: { entry.scope },
                        set: { entry.scope = $0 }
                    )) {
                        Text("The garden").tag(DiaryScope.garden)
                        Text("A bed").tag(DiaryScope.bed)
                        Text("A sowing").tag(DiaryScope.planting)
                        Text("A plant").tag(DiaryScope.plant)
                    }

                    if entry.scope == .bed {
                        Picker("Bed", selection: $entry.bed) {
                            Text("None").tag(Bed?.none)
                            ForEach(beds) { bed in
                                Text(bed.name).tag(Bed?.some(bed))
                            }
                        }
                    }
                }

                Section("Weather") {
                    Picker("Conditions", selection: Binding(
                        get: { entry.weather ?? .mild },
                        set: { entry.weather = $0 }
                    )) {
                        ForEach(Weather.allCases) { w in
                            Label(w.displayName, systemImage: w.symbolName).tag(w)
                        }
                    }

                    LabeledContent("Temperature") {
                        TextField("°C", value: $entry.temperatureC, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }
                }

                Section("Photos") {
                    if let photos = entry.photos, !photos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(photos) { photo in
                                    PhotoThumbnail(photo: photo, size: 88)
                                        .contextMenu {
                                            Button("Remove", role: .destructive) {
                                                context.delete(photo)
                                            }
                                        }
                                }
                            }
                        }
                    }

                    PhotosPicker(selection: $pickerItems,
                                 maxSelectionCount: 10,
                                 matching: .images) {
                        Label("Add photos", systemImage: "photo.badge.plus")
                    }

                    if isLoadingPhotos {
                        HStack {
                            ProgressView()
                            Text("Loading…").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Diary entry")
            .paperScreen()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if entry.body.isEmpty && (entry.photos ?? []).isEmpty {
                            context.delete(entry)
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        entry.modifiedAt = .now
                        dismiss()
                    }
                    .disabled(entry.body.isEmpty && (entry.photos ?? []).isEmpty)
                }
            }
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await load(items) }
            }
        }
    }

    /// Loads each picked image, makes a thumbnail, attaches it to the entry.
    @MainActor
    private func load(_ items: [PhotosPickerItem]) async {
        isLoadingPhotos = true
        defer {
            isLoadingPhotos = false
            pickerItems = []
        }

        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }

            let photo = Photo()
            photo.imageData = data
            photo.thumbnailData = Self.thumbnail(from: data)
            photo.sourceLocalIdentifier = item.itemIdentifier
            photo.diaryEntry = entry
            entry.photos?.append(photo)
        }
    }

    /// A small JPEG copy of a photo, for lists. `maxDimension` is the
    /// longer side in points, and the copy is made at two pixels to a
    /// point.
    ///
    /// The work is done in PhotoShrink.swift, which reads the photo
    /// straight down to the size wanted. Until 14 November 2026 this
    /// opened the whole photo and drew it again smaller, which was slow
    /// and could only be done on the main thread. `nonisolated` says it
    /// may now be called from any thread.
    ///
    /// Where a screen is waiting on the answer, ask `PhotoWorkshop`
    /// instead, which does the same in the background.
    nonisolated static func thumbnail(from data: Data, maxDimension: CGFloat = 300) -> Data? {
        PhotoShrink.jpeg(from: data, longestSide: PhotoShrink.pixels(forPoints: Double(maxDimension)))
    }
}

#Preview {
    NavigationStack {
        JournalTimelineView()
    }
    .modelContainer(for: [DiaryEntry.self, Photo.self, Bed.self, BedSection.self,
                          Plant.self, Planting.self, Harvest.self,
                          PhenologyEvent.self, PestDiseaseEvent.self,
                          Survey.self, SurveyTally.self, WildlifeObservation.self],
                    inMemory: true)
}
