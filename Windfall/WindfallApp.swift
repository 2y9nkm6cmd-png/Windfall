import SwiftUI
import SwiftData

@main
struct WindfallApp: App {

    // @State makes the app the owner of this shared object, so it is
    // created once and lives for as long as the app runs.
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

        // Everything is stored on this device only. `cloudKitDatabase: .none`
        // is what keeps it local: nothing is sent to iCloud or anywhere else.
        // Switching iCloud sync on later is a change to this one line plus the
        // capability in Signing & Capabilities. It needs Apple Developer
        // Programme membership. The models are already written to suit it.
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
            // The app opens straight into the garden. There is no sign-in:
            // your records live on the device.
            MainTabView()
                // .environment hands the object down to every screen.
                // A screen picks it up with @Environment, naming the type it wants.
                .environment(locationManager)
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .defaultSize(width: 1100, height: 750)
        #endif
    }
}
