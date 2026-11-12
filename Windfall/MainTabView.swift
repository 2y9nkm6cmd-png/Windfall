//
//  MainTabView.swift
//  Windfall
//
//  The frame every screen sits in.
//
//  On a Mac or an iPad there is a sidebar down the left, made of dark
//  green glass. On an iPhone, where there is no room for one, the same
//  places are tabs along the bottom.
//
//  Eira is not in the list. She floats in the bottom right corner of
//  every screen as her snowdrop (see EiraFloatingBar).
//

import SwiftUI
import SwiftData

/// The places in the app. This one list drives both the sidebar and the
/// tabs, so they can never disagree.
enum AppSection: String, CaseIterable, Identifiable {
    case today, gardens, year, plants, wildlife, journal, more

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .gardens: return "Gardens"
        case .year: return "Year"
        case .plants: return "Plants"
        case .wildlife: return "Wildlife"
        case .journal: return "Journal"
        case .more: return "Settings"
        }
    }

    var icon: WIcon {
        switch self {
        case .today: return .today
        case .gardens: return .gardens
        case .year: return .year
        case .plants: return .plants
        case .wildlife: return .wildlife
        case .journal: return .journal
        case .more: return .settings
        }
    }

    /// An iPhone has room for five tabs. Year and Plants are reached from
    /// Gardens there.
    static let phoneTabs: [AppSection] = [.today, .gardens, .wildlife, .journal, .more]
}

struct MainTabView: View {

    @Environment(\.modelContext) private var context
    // The size class says whether the screen is wide (a Mac, an iPad) or
    // narrow (an iPhone, or an iPad sharing its screen with another app).
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// The place shown first. Normally Today. Starting the app with the
    /// launch argument `-startSection gardens` (or any other place) opens
    /// there instead, which is handy when checking one screen repeatedly.
    @State private var selection: AppSection =
        UserDefaults.standard.string(forKey: "startSection").flatMap(AppSection.init(rawValue:)) ?? .today

    var body: some View {
        Group {
            if sizeClass == .compact {
                phoneTabs
            } else {
                sidebarLayout
            }
        }
        .background { PaperBackground() }
        // Apple's own controls, such as switches, use this colour.
        .tint(Theme.leaf)
        // The first time the app runs, fill the plant library from the
        // starter data that ships inside it. After that this does nothing.
        .task {
            if DemoGarden.isRequested {
                // The example garden: see DemoGarden. It loads the plant
                // library into memory and adds made-up beds and records.
                DemoGarden.fill(context)
            } else {
                GardenDataImporter().loadStarterDataIfNeeded(into: context)
                // Make sure the allotment and the permaculture garden
                // exist as records. It only adds what is missing.
                GardenPlan.ensureStartingGardens(in: context)
            }
        }
    }

    // MARK: Mac and iPad

    private var sidebarLayout: some View {
        HStack(spacing: 0) {
            SidebarView(selection: $selection)

            // Each place gets its own NavigationStack, which is what lets
            // a screen push another on top and offer a way back.
            NavigationStack {
                screen(for: selection)
            }
            // A new identity for each place gives it a fresh stack, so
            // the "back" trail from one never leaks into another.
            .id(selection)
            // When the place changes, the old screen melts away and the
            // new one comes into focus, in step with the sidebar.
            .transition(.blurReplace)
            // A little air between the sidebar and a screen's title.
            .padding(.leading, 10)
            // safeAreaInset places Eira's button along the bottom and tells
            // every screen that the strip is taken, so a long list can
            // always be scrolled clear of it.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Only a sliver of room on the left, so that when the bar
                // opens the snowdrop runs right up to the sidebar.
                EiraFloatingBar()
                    .padding(.leading, 5)
                    .padding(.trailing, 20)
                    .padding(.bottom, 14)
            }
        }
        #if os(macOS)
        // Lets the paper show through the strip at the top of the window.
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        #endif
    }

    // MARK: iPhone

    private var phoneTabs: some View {
        TabView(selection: phoneSelection) {
            ForEach(AppSection.phoneTabs) { section in
                Tab(section.title, image: "Icons/\(section.icon.rawValue)", value: section) {
                    NavigationStack {
                        screen(for: section)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        EiraFloatingBar()
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }
                }
            }
        }
    }

    /// Year and Plants have no tab on an iPhone. If one of them was chosen
    /// on a wide screen that then became narrow, Gardens is shown.
    private var phoneSelection: Binding<AppSection> {
        Binding(
            get: { AppSection.phoneTabs.contains(selection) ? selection : .gardens },
            set: { selection = $0 }
        )
    }

    // MARK: Which screen

    @ViewBuilder
    private func screen(for section: AppSection) -> some View {
        switch section {
        case .today: TodayView()
        case .gardens:
            if DemoGarden.opensEditor { DemoGardenEditor() } else { GardenTab() }
        case .year: SowingCalendarView()
        case .plants: PlantLibraryView()
        case .wildlife: WildlifeTab()
        case .journal: JournalTimelineView()
        case .more: MoreTab()
        }
    }
}

// MARK: - Sidebar

/// The list of places down the left of a Mac or iPad screen: a floating
/// panel of dark green glass.
struct SidebarView: View {

    @Binding var selection: AppSection

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let rowHeight: CGFloat = 44
    private let rowGap: CGFloat = 4

    // The highlight is one shape that slides between rows. Its top and
    // bottom edges are kept separately, measured down from the first row,
    // so one edge can race ahead and the other catch up. That stretch and
    // snap is what makes it move like a drop of liquid.
    @State private var highlightTop: CGFloat = 0
    @State private var highlightBottom: CGFloat = 44
    /// Counts the moves, so an older move never finishes on top of a newer one.
    @State private var moveNumber = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                WIconView(.sprig, size: 28)
                Text("Windfall")
                    .font(.wordmark)
            }
            .foregroundStyle(Theme.sidebarInk)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 20)

            VStack(spacing: rowGap) {
                ForEach(AppSection.allCases) { section in
                    let isChosen = section == selection
                    Button {
                        withAnimation(.smooth(duration: 0.3)) { selection = section }
                    } label: {
                        HStack(spacing: 12) {
                            WIconView(section.icon, size: 22)
                            Text(section.title)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: rowHeight)
                        .foregroundStyle(isChosen ? Theme.sidebarSelectedInk : Theme.sidebarInk)
                        // Makes the whole row tappable, not only its words.
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isChosen ? .isSelected : [])
                }
            }
            // The highlight sits behind the rows, so the words stay on top.
            .background(alignment: .top) {
                RoundedRectangle(cornerRadius: 13)
                    .fill(Theme.sidebarSelected)
                    // A soft line of light along the top edge, like the
                    // rim of a drop of water.
                    .overlay {
                        RoundedRectangle(cornerRadius: 13)
                            .strokeBorder(
                                LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.05)],
                                               startPoint: .top, endPoint: .bottom),
                                lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
                    .frame(height: max(highlightBottom - highlightTop, 8))
                    .offset(y: highlightTop)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 212)
        .frame(maxHeight: .infinity)
        // Glass tinted dark green. The tint is nearly solid so the cream
        // words stay easy to read over whatever is behind.
        .glassEffect(.regular.tint(Theme.sidebar.opacity(0.9)), in: .rect(cornerRadius: 26))
        .padding(.leading, 12)
        .padding(.vertical, 12)
        .onAppear { moveHighlight(to: selection, animated: false) }
        .onChange(of: selection) { _, section in
            moveHighlight(to: section, animated: true)
        }
    }

    /// Slides the highlight to a row.
    ///
    /// The edge nearer the new row sets off first and quickly. A moment
    /// later the other edge follows on a bouncier spring. In between, the
    /// highlight is stretched across both rows, then it gathers itself.
    private func moveHighlight(to section: AppSection, animated: Bool) {
        let index = CGFloat(AppSection.allCases.firstIndex(of: section) ?? 0)
        let top = index * (rowHeight + rowGap)
        let bottom = top + rowHeight

        guard animated, !reduceMotion else {
            highlightTop = top
            highlightBottom = bottom
            return
        }

        moveNumber += 1
        let thisMove = moveNumber
        let goingDown = top > highlightTop

        withAnimation(.spring(duration: 0.28, bounce: 0.15)) {
            if goingDown { highlightBottom = bottom } else { highlightTop = top }
        }
        Task {
            try? await Task.sleep(for: .milliseconds(90))
            // If another row was chosen in the meantime, leave it to that move.
            guard thisMove == moveNumber else { return }
            withAnimation(.spring(duration: 0.55, bounce: 0.42)) {
                highlightTop = top
                highlightBottom = bottom
            }
        }
    }
}

// MARK: - Garden

/// Grouped rather than given a tab each — seven tabs is too many on a
/// phone, and iOS collapses the overflow into an unhelpful "More" list.
struct GardenTab: View {

    @Query(sort: [SortDescriptor(\Garden.displayOrder)]) private var gardens: [Garden]

    var body: some View {
        List {
            Section("Draw and measure") {
                ForEach(gardens.filter(\.isActive)) { garden in
                    NavigationLink { GardenEditorView(garden: garden) } label: {
                        Label { Text(garden.name) } icon: { WIconView(.gardens, size: 22) }
                    }
                }
            }
            NavigationLink { PlantLibraryView() } label: {
                Label("Plant library", systemImage: "leaf")
            }
            NavigationLink { PlantingListView() } label: {
                Label("Sowings", systemImage: "leaf.arrow.circlepath")
            }
            NavigationLink { BedListView() } label: {
                Label("Beds", systemImage: "square.grid.3x3")
            }
            NavigationLink { GardenMapView() } label: {
                Label("Garden map", systemImage: "map")
            }
            NavigationLink { SowingCalendarView() } label: {
                Label("Sowing calendar", systemImage: "calendar")
            }
            NavigationLink { SeedListView() } label: {
                Label("Seed", systemImage: "bag")
            }
            NavigationLink { SeedPacketScanView() } label: {
                Label("Scan a seed packet", systemImage: "text.viewfinder")
            }
            NavigationLink { FrostRecordsView() } label: {
                Label("Frost & weather", systemImage: "snowflake")
            }
        }
        .navigationTitle("Gardens")
        .paperScreen()
    }
}

// MARK: - Wildlife

struct WildlifeTab: View {
    var body: some View {
        List {
            NavigationLink { SurveyListView() } label: {
                Label("Surveys", systemImage: "list.clipboard")
            }
            NavigationLink { ObservationListView() } label: {
                Label("Sightings", systemImage: "ant")
            }
            NavigationLink { FaunaListView() } label: {
                Label("Species reference", systemImage: "books.vertical")
            }
            NavigationLink { IdentifyView() } label: {
                Label("Identify from a photo", systemImage: "viewfinder")
            }
        }
        .navigationTitle("Wildlife")
        .paperScreen()
    }
}

// MARK: - More

struct MoreTab: View {
    var body: some View {
        List {
            NavigationLink { UniversalSearchView() } label: {
                Label("Search everything", systemImage: "magnifyingglass")
            }
            NavigationLink { KnowledgeBaseView() } label: {
                Label("Knowledge base", systemImage: "brain")
            }
            NavigationLink { ChartsView() } label: {
                Label("Charts", systemImage: "chart.xyaxis.line")
            }
            NavigationLink { ExportView() } label: {
                Label("Export records", systemImage: "square.and.arrow.up")
            }
            NavigationLink { NotificationSettingsView() } label: {
                Label("Reminders", systemImage: "bell")
            }
            NavigationLink { VoiceSettingsView() } label: {
                Label("Voice", systemImage: "mic")
            }
            NavigationLink { BackupView() } label: {
                Label("Backup", systemImage: "externaldrive")
            }
            NavigationLink { SettingsView() } label: {
                Label("Settings", systemImage: "gear")
            }
        }
        .navigationTitle("Settings and tools")
        .paperScreen()
    }
}

// MARK: - Settings

struct SettingsView: View {

    @AppStorage("recorderName") private var recorderName = ""
    @AppStorage("gridPrecision") private var gridPrecision = 100
    @AppStorage("eiraBarStaysOpen") private var eiraBarStaysOpen = false

    var body: some View {
        Form {
            Section {
                TextField("Your name", text: $recorderName)

                Picker("Grid precision", selection: $gridPrecision) {
                    Text("10 m").tag(10)
                    Text("100 m").tag(100)
                    Text("1 km").tag(1000)
                }
            } header: {
                Text("Recording")
            } footer: {
                Text("iRecord needs a recorder name on every record. Coarser grid precision publishes a garden record without pinpointing the house.")
            }

            Section {
                Toggle("Keep her bar open", isOn: $eiraBarStaysOpen)
            } header: {
                Text("Eira's button")
            } footer: {
                Text("Eira's snowdrop floats in the bottom right corner. Tap it to ask, search or open anything. With this on, her bar is always there to type into.")
            }

            Section {
                NavigationLink {
                    GardenDataView()
                } label: {
                    Label("Garden data", systemImage: "tray.and.arrow.down")
                }
            } header: {
                Text("Data")
            } footer: {
                Text("Everything is stored on this device. Nothing is sent anywhere.")
            }
        }
        .navigationTitle("Settings")
        .paperScreen()
    }
}
