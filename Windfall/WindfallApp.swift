import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct WindfallApp: App {

    @StateObject private var authManager = AuthenticationManager()

    /// Everything SwiftData needs to know about. Add new @Model types here
    /// or they simply won't be persisted — a quiet failure worth remembering.
    private let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            // Garden structure
            Bed.self,
            BedSection.self,
            FrostRecord.self,
            WeatherSnapshot.self,
            // Plants and growing
            Plant.self,
            Planting.self,
            Harvest.self,
            PhenologyEvent.self,
            PestDiseaseEvent.self,
            SeedPacket.self,
            // Wildlife
            Survey.self,
            SurveyTally.self,
            Observation.self
        ])

        // CloudKit stays off until the Developer Programme membership is active.
        // Switching it on later is a change to this one line plus the capability
        // in Signing & Capabilities — the models are already written to suit it.
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .defaultSize(width: 1100, height: 750)
        #endif
    }
}
