import SwiftUI
import SwiftData

struct MainTabView: View {

    @Environment(\.modelContext) private var context

    var body: some View {
        tabs
            // The first time the app runs, fill the plant library from the
            // starter data that ships inside it. After that this does nothing.
            .task {
                GardenDataImporter().loadStarterDataIfNeeded(into: context)
            }
    }

    private var tabs: some View {
        TabView {
            // Each tab gets its own NavigationStack. One stack wrapped around
            // the whole TabView means pushing a view in one tab disturbs the
            // others — a common early mistake.

            NavigationStack {
                DashboardView()
            }
            .tabItem { Label("Today", systemImage: "sun.horizon") }

            NavigationStack {
                GardenTab()
            }
            .tabItem { Label("Garden", systemImage: "square.grid.3x3") }

            NavigationStack {
                WildlifeTab()
            }
            .tabItem { Label("Wildlife", systemImage: "ant") }

            NavigationStack {
                JournalTimelineView()
            }
            .tabItem { Label("Journal", systemImage: "book.closed") }

            NavigationStack {
                EiraChatView()
            }
            .tabItem { Label("Eira", systemImage: "sparkles") }

            NavigationStack {
                MoreTab()
            }
            .tabItem { Label("More", systemImage: "ellipsis.circle") }
        }
    }
}

// MARK: - Garden

/// Grouped rather than given a tab each — seven tabs is too many on a
/// phone, and iOS collapses the overflow into an unhelpful "More" list.
struct GardenTab: View {
    var body: some View {
        List {
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
        .navigationTitle("Garden")
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
        .navigationTitle("More")
    }
}

// MARK: - Settings

struct SettingsView: View {

    @AppStorage("recorderName") private var recorderName = ""
    @AppStorage("gridPrecision") private var gridPrecision = 100

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
    }
}
