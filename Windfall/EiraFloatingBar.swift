//
//  EiraFloatingBar.swift
//  Windfall
//
//  Eira's button, which floats in the bottom right corner of every screen.
//
//  Closed, it is her snowdrop in a small glass bubble. Tap it and it
//  travels to the left, drawing a bar out behind it: "Ask Eira, search or
//  open anything". Tap the snowdrop again to put it away.
//
//  As it travels the snowdrop bends and sways, as if a gust of wind were
//  carrying it. When it reaches the sidebar it bumps against it and
//  settles.
//
//  An earlier version could also roll along like a coin. That is kept in
//  Design/Archive, "Eira opens by rolling along".
//
//  If "Reduce Motion" is switched on in the device's accessibility
//  settings, it does none of this and simply opens.
//
//  Photos (14 November 2026). Eira can be given a photo: with the "+"
//  beside her snowdrop, or by dragging one on to the bar. On the Journal
//  page the photo starts a journal entry. Anywhere else a card asks what
//  to do with it: say what it is, write about it or record a sighting
//  (PhotoOffer.swift).
//
//  On the Journal page the bar is also where the journal is written. It
//  stays open there, its grey words read "Tell Eira what happened in the
//  garden", and a book button at its right-hand end opens the journal's
//  conversation. Until 14 November the Journal page had a second bar of
//  its own at the top for this, so Eira appeared twice on one page.
//

import SwiftUI
import SwiftData
import PhotosUI

struct EiraFloatingBar: View {

    // @AppStorage keeps a small setting on the device, so the choice is
    // remembered the next time the app opens.
    @AppStorage("eiraBarStaysOpen") private var staysOpen = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Which screen is on top, if the screens have said. The question mark
    // means "if there is one": without it the bar still works.
    @Environment(EiraScreen.self) private var screen: EiraScreen?

    @State private var isOpen = false
    @State private var question = ""
    /// When the last gust began, which way it blew and how long the
    /// snowdrop was carried.
    @State private var gustStart: Date?
    @State private var gustDirection = -1.0
    @State private var gustTravel = SnowdropWind.travel
    /// How far the bar has sprung back after bumping into the sidebar.
    @State private var rebound: CGFloat = 0

    /// Set to open Eira's chat or the search screen. Each carries the
    /// words that were typed, so the sheet always gets the latest ones.
    @State private var eiraRequest: BarRequest?
    @State private var searchRequest: BarRequest?
    /// Set when what was typed reads as something for the journal.
    @State private var journalRequest: BarRequest?

    /// Set when a photo is given to Eira anywhere but the Journal page.
    /// It opens the card that asks what to do with it.
    @State private var photoRequest: BarRequest?
    // The two ways of choosing a photo from the "+" button.
    @State private var isChoosingFromPhotos = false
    @State private var isChoosingFile = false
    /// What was chosen in the Photos chooser. It hands over opaque
    /// items, and the pictures are loaded from them a moment later.
    @State private var pickedItems: [PhotosPickerItem] = []
    /// True while photos are being held over the bar.
    @State private var isDropTarget = false

    // @FocusState says whether the text box has the keyboard.
    @FocusState private var fieldHasFocus: Bool

    private let symbolSize: CGFloat = 50
    private let rim: CGFloat = 5
    private var closedSize: CGFloat { symbolSize + rim * 2 }

    /// True on the Journal page, where the bar is for telling Eira what
    /// happened. See `EiraSight.isJournal`.
    private var onJournal: Bool { screen?.current?.isJournal == true }

    /// On the Journal page the bar is always open.
    private var expanded: Bool { isOpen || staysOpen || onJournal }

    /// The grey words in the empty text box. When a plant, a bed or
    /// another single thing is open, they name it.
    ///
    /// - `isNarrow`: true on an iPhone, where the long words would be
    ///   cut short, so shorter ones are used.
    private func hint(isNarrow: Bool) -> String {
        if isDropTarget {
            return onJournal ? "Drop photos to start an entry" : "Drop a photo for Eira"
        }
        if onJournal { return isNarrow ? "Tell Eira" : "Tell Eira what happened in the garden" }
        if let short = screen?.current?.short {
            return "Ask Eira about \(short)"
        }
        return "Ask Eira, search or open anything"
    }

    var body: some View {
        // GeometryReader reports how much room there is, so the bar can be
        // as wide as the screen allows, up to a sensible limit.
        GeometryReader { geometry in
            // The bar runs the full width, so the snowdrop travels all
            // the way across to the sidebar.
            let barWidth = geometry.size.width

            HStack(spacing: 10) {
                symbolButton(travel: barWidth - closedSize)

                if expanded {
                    photoButton

                    TextField(hint(isNarrow: barWidth < 430), text: $question)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Theme.ink)
                        .focused($fieldHasFocus)
                        .onSubmit(ask)
                        .onKeyPress(.escape) {
                            close()
                            return .handled
                        }
                        .transition(.opacity)

                    // On the Journal page of an iPhone there is not room
                    // for every button and the words as well, so search
                    // gives way. Return still searches or asks.
                    if !(onJournal && barWidth < 430) {
                        barButton(.search, label: "Search everything") { search() }
                    }
                    barButton(.microphone, label: "Open Eira to talk or type") { openEira(with: nil) }
                    if onJournal {
                        barButton(.journalEntry, label: "Write in the journal") { openJournal() }
                    }
                }
            }
            .padding(.leading, rim)
            .padding(.trailing, expanded ? 14 : rim)
            // The frame grows from the snowdrop's width to the bar's width.
            // It is pinned to the right, so the left edge, and the snowdrop
            // with it, travels left as it grows.
            .frame(width: expanded ? max(barWidth - rebound, closedSize) : closedSize,
                   height: closedSize, alignment: .leading)
            .glassEffect(.regular.interactive(), in: .capsule)
            // While photos are held over the bar, a dashed line round it
            // shows that it will take them.
            .overlay {
                if isDropTarget {
                    Capsule()
                        .strokeBorder(Theme.leaf, style: StrokeStyle(lineWidth: 2.5, dash: [8, 6]))
                        .allowsHitTesting(false)
                }
            }
            // Photos dragged on to the bar. The bar itself is the target,
            // not the empty strip beside it, which has to go on letting
            // taps through to the page underneath.
            .onDrop(of: PhotoDrop.kinds, isTargeted: $isDropTarget) { providers in
                guard PhotoDrop.mayHold(providers) else { return false }
                Task { takePhotos(await PhotoDrop.pictures(from: providers)) }
                return true
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: closedSize)
        // The two choosers behind the "+" button.
        .photosPicker(isPresented: $isChoosingFromPhotos, selection: $pickedItems,
                      maxSelectionCount: 10, matching: .images)
        .onChange(of: pickedItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var pictures: [Data] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) { pictures.append(data) }
                }
                pickedItems = []
                takePhotos(pictures)
            }
        }
        .fileImporter(isPresented: $isChoosingFile, allowedContentTypes: [.image],
                      allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            var pictures: [Data] = []
            for url in urls {
                // Leave to read a file chosen in a file window lasts
                // only between these two calls.
                let hasLeave = url.startAccessingSecurityScopedResource()
                if let data = try? Data(contentsOf: url) { pictures.append(data) }
                if hasLeave { url.stopAccessingSecurityScopedResource() }
            }
            takePhotos(pictures)
        }
        // A photo given to Eira away from the Journal page: she asks
        // what to do with it.
        .sheet(item: $photoRequest) { request in
            PhotoOfferSheet(photos: request.photos)
        }
        .sheet(item: $eiraRequest) { request in
            NavigationStack {
                EiraChatView(openingQuestion: request.text.isEmpty ? nil : request.text,
                             lookingAt: request.lookingAt)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { eiraRequest = nil }
                        }
                    }
            }
            .macSheetSize(width: 580, height: 660)
        }
        // Something told to Eira, and not asked of her, goes to the
        // journal's conversation with the words ready to send.
        .sheet(item: $journalRequest) { request in
            // Eira only says "that reads like one for the journal" when
            // words were typed and no photos came with them.
            JournalChatView(draft: request.text, photos: request.photos,
                            cameFromEirasBar: !request.text.isEmpty && request.photos.isEmpty) { asked in
                // "Ask Eira instead": hand the same words to her chat.
                // One sheet has to be gone before the next can open, so
                // her chat follows a moment after the journal closes.
                journalRequest = nil
                let looking = request.lookingAt
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    eiraRequest = BarRequest(text: asked, lookingAt: looking)
                }
            }
        }
        .sheet(item: $searchRequest) { request in
            NavigationStack {
                UniversalSearchView(initialQuery: request.text)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { searchRequest = nil }
                        }
                    }
            }
            .macSheetSize(width: 580, height: 660)
        }
        // A checking aid: `-demoOpen eira` and `-demoOpen corrections`
        // open her chat as soon as the bar appears, once. See
        // DemoGarden.opens.
        .onAppear {
            guard !Self.hasOpenedForChecking,
                  DemoGarden.opens == "eira" || DemoGarden.opens == "corrections" else { return }
            Self.hasOpenedForChecking = true
            eiraRequest = BarRequest(text: "")
        }
    }

    /// True once the checking aid above has opened the chat. `static`
    /// means one value shared by every copy of the bar, so that moving
    /// to another page does not open the chat a second time.
    private static var hasOpenedForChecking = false

    // MARK: The snowdrop

    private func symbolButton(travel: CGFloat) -> some View {
        Button {
            toggle(travel: travel)
        } label: {
            // TimelineView redraws many times a second while a gust is
            // blowing, and not at all once it has died away.
            TimelineView(.animation(paused: gustStart == nil)) { timeline in
                let seconds = gustStart.map { timeline.date.timeIntervalSince($0) } ?? 60
                EiraSymbol(size: symbolSize,
                           lean: SnowdropWind.lean(at: seconds, direction: gustDirection, travel: gustTravel),
                           nod: SnowdropWind.nod(at: seconds, direction: gustDirection, travel: gustTravel))
            }
        }
        .buttonStyle(.plain)
        // Command and K opens the bar from the keyboard, on a Mac or an
        // iPad with a keyboard attached.
        .keyboardShortcut("k", modifiers: .command)
        .accessibilityLabel(expanded ? "Close Eira's bar" : "Ask Eira")
        .contextMenu {
            Toggle("Keep the bar open", isOn: $staysOpen)
        }
    }

    /// The "+" beside the snowdrop: give Eira a photo.
    ///
    /// A `Menu` is a button that opens a short list of choices. Here
    /// there are two, because photos live in two places: the Photos
    /// library, and ordinary files, which on a Mac is often where they
    /// are.
    private var photoButton: some View {
        Menu {
            Button {
                isChoosingFromPhotos = true
            } label: {
                Label("From Photos", systemImage: "photo.on.rectangle")
            }
            Button {
                isChoosingFile = true
            } label: {
                Label("From a file", systemImage: "folder")
            }
        } label: {
            WIconView(.add, size: 20)
                .foregroundStyle(Theme.leaf)
                .frame(width: 30, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // No little arrow beside it. The plus says enough.
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(onJournal ? "Add photos to the journal" : "Give Eira a photo")
        .help(onJournal ? "Add photos to the journal" : "Give Eira a photo")
        .transition(.opacity)
    }

    private func barButton(_ icon: WIcon, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            WIconView(icon, size: 22)
                .foregroundStyle(Theme.leaf)
                .frame(width: 40, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
        .transition(.opacity)
    }

    // MARK: Opening and closing

    private func toggle(travel: CGFloat) {
        if staysOpen || onJournal {
            // The bar is pinned open, or is on the Journal page where it
            // is always open, so the snowdrop just hands the keyboard to
            // the text box.
            fieldHasFocus = true
            return
        }
        if isOpen {
            close(travel: travel)
        } else {
            open(travel: travel)
        }
    }

    private func open(travel: CGFloat) {
        move(opening: true, travel: travel)
        // Hand the keyboard to the text box straight away, so typing can
        // begin while the snowdrop is still on its way across. Nobody has
        // to wait for the animation, and nobody has to miss it.
        //
        // The text box only exists once the bar has begun to open, which
        // is why this waits a twenty-fifth of a second before asking.
        Task {
            try? await Task.sleep(for: .milliseconds(40))
            if isOpen { fieldHasFocus = true }
        }
    }

    private func close(travel: CGFloat = 0) {
        fieldHasFocus = false
        guard isOpen else { return }
        move(opening: false, travel: travel)
    }

    /// How long the journey takes. A longer bar takes a little longer,
    /// within limits, so it never crawls and never flashes past.
    private func travelTime(for travel: CGFloat) -> Double {
        min(0.9, max(SnowdropWind.travel, Double(travel) / 1400))
    }

    /// Opens or closes the bar.
    ///
    /// Opening has two parts. First the snowdrop is blown to the left,
    /// gathering speed, until it reaches the sidebar. Then it bumps: it
    /// springs back a little way and settles. `withAnimation` can be given
    /// a `completion`, a piece of code to run when the movement finishes,
    /// which is how the bump follows the journey.
    private func move(opening: Bool, travel: CGFloat) {
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.2)) { isOpen = opening }
            return
        }

        // Start the gust. The snowdrop's lean and sway are worked out
        // from how long ago this was (see SnowdropWind).
        let seconds = travelTime(for: travel)
        gustDirection = opening ? -1 : 1
        gustTravel = seconds
        let started = Date.now
        gustStart = started

        if opening {
            // easeIn starts slowly and speeds up, so it is moving fast
            // when it hits the sidebar.
            withAnimation(.easeIn(duration: seconds)) {
                isOpen = true
            } completion: {
                bump()
            }
        } else {
            withAnimation(.spring(duration: seconds, bounce: 0.2)) {
                isOpen = false
                rebound = 0
            }
        }

        // Stop redrawing once the swaying has died away, unless a newer
        // gust has started in the meantime.
        Task {
            try? await Task.sleep(for: .seconds(seconds + SnowdropWind.settled))
            if gustStart == started { gustStart = nil }
        }
    }

    /// The little bounce off the sidebar: back a short way, quickly, then
    /// forward again on a springy return.
    private func bump() {
        guard isOpen else { return }
        withAnimation(.easeOut(duration: 0.14)) {
            rebound = 18
        } completion: {
            withAnimation(.spring(duration: 0.5, bounce: 0.6)) {
                rebound = 0
            }
        }
    }

    // MARK: What the bar does

    /// Return was pressed. On a device that can run Eira the words go to
    /// her. On one that cannot, they go to the search screen instead.
    private func ask() {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        // "Today I planted beans" is not a question. It belongs in the
        // journal, where Eira notes the time and weather and offers to
        // put the sowing on record. The rule is in JournalChat.swift.
        // (Until 13 November 2026 it went to her ordinary chat, which
        // looked for a record of it and found none.)
        //
        // On the Journal page the doubt runs the other way. The bar says
        // "Tell Eira what happened", so whatever is typed is an entry
        // unless it plainly asks something.
        let isForJournal = onJournal ? !JournalChat.readsAsAsking(text) : JournalChat.readsAsTelling(text)
        if isForJournal {
            journalRequest = BarRequest(text: text, lookingAt: screen?.current?.full)
            question = ""
            return
        }
        if DeviceCapability.canRunEira() {
            openEira(with: text)
        } else {
            search()
        }
    }

    private func openEira(with text: String?) {
        // Note what is on screen at this moment, to pass on with the words.
        eiraRequest = BarRequest(text: text ?? "", lookingAt: screen?.current?.full)
        question = ""
    }

    private func search() {
        searchRequest = BarRequest(text: question.trimmingCharacters(in: .whitespacesAndNewlines))
        question = ""
    }

    /// The book button on the Journal page: opens the journal's
    /// conversation, with whatever has been typed so far in its box.
    private func openJournal() {
        journalRequest = BarRequest(text: question.trimmingCharacters(in: .whitespacesAndNewlines),
                                    lookingAt: screen?.current?.full)
        question = ""
    }

    /// Photos have been given to Eira: chosen with the "+" or dropped on
    /// the bar. Every way in ends here, so they all behave alike.
    private func takePhotos(_ pictures: [Data]) {
        guard !pictures.isEmpty else { return }
        if onJournal {
            // Straight into an entry, with any words already typed.
            journalRequest = BarRequest(text: question.trimmingCharacters(in: .whitespacesAndNewlines),
                                        lookingAt: screen?.current?.full, photos: pictures)
            question = ""
        } else {
            photoRequest = BarRequest(text: "", photos: pictures)
        }
    }
}

/// What was typed into the bar, handed to the sheet that opens.
/// `Identifiable` lets SwiftUI tell one request from the next.
struct BarRequest: Identifiable {
    let id = UUID()
    let text: String
    /// What was open on screen when the words were sent. Only Eira's chat
    /// uses it. See EiraScreen.
    var lookingAt: String? = nil
    /// Photos given with the words, each as its file's own bytes.
    var photos: [Data] = []
}

// MARK: - Telling Eira what is on screen

extension View {

    /// Says what this screen is showing, for Eira.
    ///
    /// `full` is the phrase she is given: "the plant Apple, Spartan".
    /// `short`, when there is one, also goes in the hint in her bar:
    /// "Ask Eira about Apple, Spartan".
    ///
    /// `isJournal` is true only for the Journal page, where the bar is
    /// for telling Eira what happened.
    func eiraLooksAt(_ full: String, short: String? = nil, isJournal: Bool = false) -> some View {
        modifier(EiraLooksAt(sight: EiraSight(short: short, full: full, isJournal: isJournal)))
    }
}

/// Registers a screen with the tracker when it appears and removes it
/// when it goes. See EiraScreen.
private struct EiraLooksAt: ViewModifier {

    let sight: EiraSight

    // "If there is one": a preview, or a sheet shown without the tracker,
    // simply does nothing.
    @Environment(EiraScreen.self) private var screen: EiraScreen?
    // A label belonging to this one screen. @State keeps it the same for
    // as long as the screen lives.
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { screen?.show(sight, id: id) }
            .onDisappear { screen?.hide(id: id) }
            // The same screen can change what it shows, for example when
            // a plant is renamed.
            .onChange(of: sight) { _, changed in screen?.show(changed, id: id) }
    }
}
