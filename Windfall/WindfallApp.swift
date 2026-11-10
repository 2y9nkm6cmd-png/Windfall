import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct WindfallApp: App {

    // @State makes the app the owner of these two shared objects, so they
    // are created once and live for as long as the app runs.
    @State private var authManager = AuthenticationManager()
    @State private var locationManager = LocationManager()

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
            WildlifeObservation.self,
            // Reference data
            Fauna.self,
            PlantFaunaLink.self,
            FlowerShape.self,
            Cascade.self,
            CompanionPair.self,
            // Journal
            DiaryEntry.self,
            Photo.self,
            // Knowledge base
            KnowledgeDocument.self,
            KnowledgeChunk.self,
            // Eira: saved conversations and corrections
            EiraChat.self,
            EiraChatMessage.self,
            EiraCorrection.self
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
                // .environment hands each object down to every screen.
                // A screen picks one up with @Environment, naming the type it wants.
                .environment(authManager)
                .environment(locationManager)
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
