//
//  DemoGarden.swift
//  Windfall
//
//  An example garden, for looking at the design with something in it.
//
//  It only appears when the app is started with the launch argument
//  `-demoGarden`. A launch argument is a word handed to the app as it
//  starts. In Xcode it is set under Product, Scheme, Edit Scheme, Run,
//  Arguments.
//
//  With the argument, the app keeps everything in memory and never opens
//  your real records. Close the app and the example is gone. Without the
//  argument, none of this runs.
//
//  Every bed, plant, date and sighting below is made up.
//

import SwiftUI
import SwiftData

enum DemoGarden {

    /// True when the app was started with `-demoGarden`, or when the
    /// setting "demoGarden" has been switched on for this copy of the app.
    /// The setting is how a simulator is told to show the example garden
    /// every time, including when its icon is tapped.
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-demoGarden")
            || UserDefaults.standard.bool(forKey: "demoGarden")
    }

    /// True when the app was also started with `-demoEditor`, which
    /// opens the garden editor in place of the Gardens list.
    static var opensEditor: Bool {
        isRequested && ProcessInfo.processInfo.arguments.contains("-demoEditor")
    }

    /// True when the app was also started with `-demoYear`, which opens
    /// the Year page in place of the Gardens list. On an iPhone the Year
    /// page has no tab of its own, so this is how it is checked there.
    static var opensYear: Bool {
        isRequested && ProcessInfo.processInfo.arguments.contains("-demoYear")
    }

    /// True when the app was also started with `-demoWeather`, which opens
    /// the Weather page in place of the Gardens page, for checking it.
    static var opensWeather: Bool {
        isRequested && ProcessInfo.processInfo.arguments.contains("-demoWeather")
    }

    /// True when the app was also started with `-demoWeatherDay`, which
    /// opens one day of weather in place of the Gardens page.
    static var opensWeatherDay: Bool {
        isRequested && ProcessInfo.processInfo.arguments.contains("-demoWeatherDay")
    }

    /// A checking aid: `-demoOpen sowing` opens the sowing form as soon
    /// as Today appears, so a still picture can be taken of it. Also
    /// `harvest`, `worms`, `fit`, `sighting`, `identify` and `journal`.
    /// With `journal`, `-demoDraft "some words"` starts the box off with
    /// those words.
    ///
    /// `eira` opens her chat on an example exchange in which she is put
    /// right, with the card that offers to keep the correction.
    /// `corrections` does the same and then opens the list of them.
    static var opens: String? {
        isRequested ? UserDefaults.standard.string(forKey: "demoOpen") : nil
    }

    /// A checking aid: `-demoMatch YES` makes the Identify screen show a
    /// made-up answer, so its cards can be looked at in the simulator,
    /// where the identification model cannot run.
    static var showsExampleMatch: Bool {
        isRequested && (UserDefaults.standard.bool(forKey: "demoMatch") || showsCarrotFamilyMatch)
    }

    /// `-demoMatch hemlock` makes that made-up answer one with a
    /// carrot-family plant in it, to look at the warning it brings up.
    static var showsCarrotFamilyMatch: Bool {
        isRequested && UserDefaults.standard.string(forKey: "demoMatch") == "hemlock"
    }

    /// Checking aids that open one page in place of the Gardens page:
    /// `-demoPlant Garlic` a plant's page, `-demoCompanions Garlic` its
    /// companions and `-demoPests YES` the pest helpers.
    static var opensPlant: String? {
        isRequested ? UserDefaults.standard.string(forKey: "demoPlant") : nil
    }
    static var opensCompanions: String? {
        isRequested ? UserDefaults.standard.string(forKey: "demoCompanions") : nil
    }
    static var opensPests: Bool {
        isRequested && UserDefaults.standard.bool(forKey: "demoPests")
    }

    /// Fills the empty in-memory store with an example garden. Does
    /// nothing if it has already been filled.
    static func fill(_ context: ModelContext) {
        guard isRequested else { return }
        let existingBeds = (try? context.fetch(FetchDescriptor<Bed>())) ?? []
        guard existingBeds.isEmpty else { return }

        // The plant library is loaded fresh into memory. It uses its own
        // settings store, so the note that says "the starter data has been
        // loaded" is never written into the real app's settings.
        let demoSettings = UserDefaults(suiteName: "WindfallDemoGarden") ?? .standard
        demoSettings.removeObject(forKey: GardenDataImporter.starterLoadedKey)
        GardenDataImporter().loadStarterData(into: context, defaults: demoSettings)
        GardenPlan.ensureStartingGardens(in: context)

        let gardens = (try? context.fetch(FetchDescriptor<Garden>())) ?? []
        let plants = (try? context.fetch(FetchDescriptor<Plant>())) ?? []

        // The allotment: 25 by 10 metres with north at the top.
        if let allotment = gardens.first(where: { $0.siteKey == GardenSite.allotment.rawValue }) {
            allotment.widthMetres = 25
            allotment.depthMetres = 10
            allotment.topFacesDegrees = 0
            allotment.latitude = 51.5
            allotment.longitude = -2.55
            allotment.soil = .clay
        }
        var allotmentBeds: [Bed] = []
        let places: [(String, Double, Double)] = [
            ("Bed 1", 1.5, 1.2), ("Bed 2", 1.5, 3.2), ("Bed 3", 1.5, 5.2), ("Bed 4", 1.5, 7.2),
            ("Bed 5", 8.5, 1.2), ("Bed 6", 8.5, 3.2)
        ]
        for (index, place) in places.enumerated() {
            let bed = Bed(name: place.0, site: .allotment)
            bed.displayOrder = index
            bed.originX = place.1
            bed.originY = place.2
            bed.lengthMetres = 6
            bed.widthMetres = 1.4
            bed.heightMetres = 0.3
            bed.addSections(count: 5, lengthMetres: 1.2)
            context.insert(bed)
            allotmentBeds.append(bed)
        }
        addFeature("Shed", .shed, GardenSite.allotment, x: 19.5, y: 1, length: 3.2, width: 2.2, to: context)
        addFeature("Neighbour's tree", .tree, GardenSite.allotment, x: 19.5, y: 10.6, length: 3.4, width: 3.4, to: context)

        // The permaculture garden: 14 by 9 metres.
        if let permaculture = gardens.first(where: { $0.siteKey == GardenSite.permaculture.rawValue }) {
            permaculture.widthMetres = 14
            permaculture.depthMetres = 9
            permaculture.topFacesDegrees = 0
            permaculture.slopeDownDegrees = 180
            permaculture.slopeSteepness = .gentle
            permaculture.soil = .clay
        }
        let lowerBeds: [(String, Double, Double)] = [("Herb bed", 1, 3.2), ("Rockery", 1, 5.6), ("Fruit bed", 5, 3.2), ("Bog bed", 5, 5.6)]
        for (index, place) in lowerBeds.enumerated() {
            let bed = Bed(name: place.0, site: .permaculture)
            bed.displayOrder = index
            bed.originX = place.1
            bed.originY = place.2
            bed.lengthMetres = 3.2
            bed.widthMetres = 1.4
            bed.addSections(count: 2, lengthMetres: 1.6)
            context.insert(bed)
        }
        addFeature("Apple", .tree, GardenSite.permaculture, x: 1.6, y: 0.4, length: 2.2, width: 2.2, to: context)
        addFeature("Pear", .tree, GardenSite.permaculture, x: 6.2, y: 0.4, length: 2.2, width: 2.2, to: context)
        addFeature("Plum", .tree, GardenSite.permaculture, x: 9.4, y: 0.4, length: 2.2, width: 2.2, to: context)
        addFeature("Pond", .water, GardenSite.permaculture, x: 9.6, y: 4.2, length: 3.4, width: 2.2, to: context)

        // One sowing, into sections A and B of Bed 3.
        let beans = plants.first { $0.commonName.lowercased().contains("bean") } ?? plants.first
        let sowing = Planting()
        sowing.plant = beans
        sowing.dateSown = Calendar.current.date(byAdding: .day, value: -4, to: .now)
        sowing.status = .growing
        sowing.quantitySown = 24
        sowing.sections = Array(allotmentBeds[2].orderedSections.prefix(2))
        context.insert(sowing)

        // Two sightings: one confirmed, one waiting to be confirmed.
        let butterfly = WildlifeObservation()
        butterfly.commonName = "Small tortoiseshell"
        butterfly.confirmedID = "Small tortoiseshell"
        butterfly.observedAt = Calendar.current.date(bySettingHour: 9, minute: 14, second: 0, of: .now) ?? .now
        context.insert(butterfly)

        let bee = WildlifeObservation()
        bee.commonName = "Tree bumblebee"
        bee.provisionalID = "Tree bumblebee"
        bee.observedAt = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        bee.associatedPlantName = "Marjoram"
        context.insert(bee)

        try? context.save()
    }

    private static func addFeature(_ name: String, _ kind: FeatureKind, _ site: GardenSite,
                                   x: Double, y: Double, length: Double, width: Double,
                                   to context: ModelContext) {
        let feature = GardenFeature(name: name, kind: kind, siteKey: site.rawValue)
        feature.originX = x
        feature.originY = y
        feature.lengthMetres = length
        feature.widthMetres = width
        context.insert(feature)
    }
}

/// The garden editor for the example allotment, shown when the app is
/// started with `-demoGarden -demoEditor`.
struct DemoGardenEditor: View {

    @Query(sort: [SortDescriptor(\Garden.displayOrder)]) private var gardens: [Garden]

    var body: some View {
        if let garden = gardens.first {
            GardenEditorView(garden: garden)
        } else {
            Text("Loading the example garden…")
        }
    }
}
