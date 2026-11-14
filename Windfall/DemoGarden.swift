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

    /// A checking aid: `-demoMonth 4`, with `-demoYear` or on the Year
    /// page, opens April's own page as soon as the Year page appears.
    /// Nil when it was not asked for or is not a month.
    static var opensMonth: Int? {
        guard isRequested else { return nil }
        let month = UserDefaults.standard.integer(forKey: "demoMonth")
        return (1...12).contains(month) ? month : nil
    }

    /// Checking aids for a month's page, used with `-demoMonth`. A
    /// moment after the page appears, `-demoMonthStep on` presses its
    /// forward arrow once and `-demoMonthStep back` its back arrow, and
    /// `-demoMonthThen 9` chooses September from the list under the
    /// month's name. A still picture then shows whether the page turned.
    /// (Words, not 1 and -1: a launch argument that starts with a minus
    /// sign is taken for the name of the next setting, not a value.)
    static var stepsMonth: Int {
        guard isRequested else { return 0 }
        switch UserDefaults.standard.string(forKey: "demoMonthStep") {
        case "on": return 1
        case "back": return -1
        default: return 0
        }
    }

    /// Checking aids for the way a Mac moves the row of months, which a
    /// simulator cannot otherwise show. `-demoMonthMacRow YES` gives an
    /// iPhone or iPad the Mac's row of three pages. With it,
    /// `-demoMonthDrag 300` holds the row 300 points to the right a
    /// moment after the page appears, as if two fingers had dragged it
    /// part of the way to the month before.
    static var usesMacMonthRow: Bool {
        isRequested && UserDefaults.standard.bool(forKey: "demoMonthMacRow")
    }

    static var dragsMonthRow: CGFloat? {
        guard isRequested else { return nil }
        let points = UserDefaults.standard.double(forKey: "demoMonthDrag")
        return points == 0 ? nil : CGFloat(points)
    }

    static var thenMonth: Int? {
        guard isRequested else { return nil }
        let month = UserDefaults.standard.integer(forKey: "demoMonthThen")
        return (1...12).contains(month) ? month : nil
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
    /// `harvest`, `worms`, `fit`, `sighting`, `identify`, `photo` and `journal`.
    /// With `journal`, `-demoDraft "some words"` starts the box off with
    /// those words.
    ///
    /// `eira` opens her chat on an example exchange in which she is put
    /// right, with the card that offers to keep the correction.
    /// `corrections` does the same and then opens the list of them.
    /// `eira-photo` opens her chat on an example answer to a photo.
    /// `eira-lookups` opens it on an example reply that made lookups,
    /// with its closed bubble and a card for the plant found.
    /// `eira-lookups-open` is the same with the bubble and its first
    /// lookup open.
    /// `eira-find` opens her chat on an example answer built on the
    /// RHS, with the card that offers to keep what she found, and
    /// `kept-facts` opens the list of kept facts. `keepFact`, with
    /// `-demoPlant Rhubarb`, opens the form for keeping a fact by hand,
    /// and `keptFacts` shows that plant's page with two example facts
    /// kept.
    ///
    /// `plantSowing` and `plantPlanting`, with `-demoPlant Achillea`,
    /// open the sowing form from that plant's page: the first on seed,
    /// the second on plants. `plantEdit` opens the sheet that edits the
    /// plant's facts, and `plantEditSowing` opens it at its sowing card.
    static var opens: String? {
        isRequested ? UserDefaults.standard.string(forKey: "demoOpen") : nil
    }

    /// A checking aid: `-demoEdit "spacingM=0.5|notes=Cut back in March"`
    /// types those into the sheet that edits a plant as it opens, so a
    /// still picture can show changes waiting to be saved. Each piece
    /// is a fact's key from PlantFacts.swift, an equals sign and the
    /// text. The example garden's records live in memory, so nothing
    /// real is changed.
    static var typedEdits: [String: String] {
        guard isRequested, let written = UserDefaults.standard.string(forKey: "demoEdit") else { return [:] }
        var found: [String: String] = [:]
        for piece in written.split(separator: "|") {
            // `maxSplits: 1` cuts at the first equals sign only, so the
            // text itself may hold one.
            let halves = piece.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            if halves.count == 2 { found[String(halves[0])] = String(halves[1]) }
        }
        return found
    }

    /// With `-demoEditSave YES` the changes above are saved at once and
    /// the sheet closes, so a still can show the page afterwards.
    static var savesTypedEdits: Bool {
        isRequested && UserDefaults.standard.bool(forKey: "demoEditSave")
    }

    /// A checking aid: `-demoPhoto /path/to/a/photo.jpg` hands that
    /// photo to whatever `-demoOpen` opens: with `journal` it waits in
    /// the conversation's box, with `identify` Eira looks at it, and
    /// with `photo` the card that asks what to do with a photo opens.
    /// It lets the photo's own date be checked in a still picture.
    static var photos: [Data] {
        guard isRequested, let path = UserDefaults.standard.string(forKey: "demoPhoto"),
              let data = FileManager.default.contents(atPath: path) else { return [] }
        return [data]
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

    /// A checking aid: `-demoOpen sighting -demoPlantLetter M` opens the
    /// sighting form, then its list of plants, already jumped to M, so a
    /// still picture can show the row of letters and where a jump lands.
    /// Nil when it was not asked for.
    static var jumpsToPlantLetter: String? {
        guard isRequested, let letter = UserDefaults.standard.string(forKey: "demoPlantLetter"),
              !letter.isEmpty else { return nil }
        return letter.uppercased()
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
        // Kept so that the example planting further down has a bed.
        var herbBed: Bed?
        for (index, place) in lowerBeds.enumerated() {
            let bed = Bed(name: place.0, site: .permaculture)
            if index == 0 { herbBed = bed }
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

        // An achillea raised from seed in spring, and three more bought
        // in pots and planted three weeks ago. They give a plant's page
        // one sowing and one planting to list. See PlantDetailView.
        if let achillea = plants.first(where: { $0.commonName.lowercased() == "achillea" }) {
            let raised = Planting()
            raised.plant = achillea
            raised.dateSown = Calendar.current.date(byAdding: .month, value: -8, to: .now)
            raised.sowingLocation = .indoors
            raised.status = .finished
            raised.quantitySown = 30
            context.insert(raised)

            let bought = Planting()
            bought.plant = achillea
            bought.dateSown = Calendar.current.date(byAdding: .day, value: -21, to: .now)
            bought.startedFrom = .plant
            bought.status = .growing
            bought.quantitySown = 3
            bought.sections = Array((herbBed?.orderedSections ?? []).prefix(1))
            context.insert(bought)
        }

        // Two jobs of your own, so that "This week" and "This month"
        // each have one to show. The first is read from a sentence, the
        // way Eira would read it. See GardenJobs.swift.
        let said = "I need to build the bean wigwam in the allotment at the weekend"
        let wigwam = GardenJob(title: "Build the bean wigwam")
        wigwam.span = GardenJobs.offer(in: said, today: .now)?.span ?? .whenever
        wigwam.siteKey = GardenSite.allotment.rawValue
        wigwam.saidAs = said
        context.insert(wigwam)
        context.insert(GardenJob(title: "Order seed potatoes"))

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
