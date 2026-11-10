import SwiftUI

struct MainTabView: View {

    var body: some View {
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
            NavigationLink { SyncView() } label: {
                Label("Sync with Sheets", systemImage: "arrow.triangle.2.circlepath")
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

    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.modelContext) private var context

    @AppStorage("recorderName") private var recorderName = ""
    @AppStorage("gridPrecision") private var gridPrecision = 100

    @State private var sheets: SheetsService?

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

            Section("Data") {
                if let service = sheets {
                    NavigationLink {
                        ImportView(service: service)
                    } label: {
                        Label("Import plants from Sheets", systemImage: "arrow.down.doc")
                    }

                    Button {
                        Task { await service.importCompanions(into: context) }
                    } label: {
                        Label("Import companion planting", systemImage: "square.on.square")
                    }

                    Button {
                        Task { await service.importReferenceData(into: context) }
                    } label: {
                        if service.isImporting {
                            HStack { ProgressView(); Text(service.progressMessage) }
                        } else {
                            Label("Import reference data", systemImage: "books.vertical")
                        }
                    }
                }
            }

            Section("Account") {
                if !authManager.userEmail.isEmpty {
                    LabeledContent("Signed in as", value: authManager.userEmail)
                }
                Button("Sign out", role: .destructive) {
                    authManager.signOut()
                }
            }
        }
        .navigationTitle("Settings")
        .task {
            if sheets == nil { sheets = SheetsService(auth: authManager) }
        }
    }
}
