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

    /// A checking aid: `-demoSeed` opens the Seed page in place of the
    /// Gardens page, so a still picture can be taken of it. The example
    /// garden has no seed packets, so it is the empty page that shows.
    static var opensSeed: Bool {
        isRequested && ProcessInfo.processInfo.arguments.contains("-demoSeed")
    }

    /// A checking aid, used with `-demoSeed`: `-demoSeedAdd library`
    /// (or `typed`, or `camera`) also opens that way of adding a packet
    /// as soon as the page appears. The simulator has no camera, so
    /// `camera` falls back to the Photos library there.
    static var seedAdds: SeedPacketStart? {
        guard isRequested, let way = UserDefaults.standard.string(forKey: "demoSeedAdd") else { return nil }
        return SeedPacketStart(rawValue: way)
    }

    /// A checking aid for the packet reader: `-demoPacketPhoto` and the
    /// path of a picture file. The scan sheet then reads that picture
    /// as the back of a packet as soon as it opens, with no tap. Used
    /// with `-demoSeed -demoSeedAdd library`. In the simulator the path
    /// is a path on the Mac, such as the test packet's `back.jpg`.
    static var packetPhoto: Data? {
        guard isRequested, let path = UserDefaults.standard.string(forKey: "demoPacketPhoto") else { return nil }
        return FileManager.default.contents(atPath: path)
    }

    /// True when the app was also started with `-demoWeatherDay`, which
    /// opens one day of weather in place of the Gardens page.
    static var opensWeatherDay: Bool {
        isRequested && ProcessInfo.processInfo.arguments.contains("-demoWeatherDay")
    }

    /// A checking aid: `-demoOpen sowing` opens the sowing form as soon
    /// as Today appears, so a still picture can be taken of it. Also
    /// `harvest`, `worms`, `fit`, `sighting`, `identify`, `photo` and `journal`.
    /// `sighting-eira` opens the sighting form as it arrives from Eira's
    /// made-up answer to a photo, with a made-up place.
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

    /// A checking aid: `-demoOpen place -demoPlaceSearch Frenchay` opens
    /// the sheet for giving a garden its place with those words typed
    /// and the search already made. See GardenPlaceSheet.swift.
    static var placeSearch: String? {
        isRequested ? UserDefaults.standard.string(forKey: "demoPlaceSearch") : nil
    }

    /// A checking aid: `-demoNoPlace YES` leaves the example allotment
    /// without a place on the map, so Today's weather card can be seen
    /// as it is on a device where no garden has been placed.
    static var hasNoPlace: Bool {
        isRequested && UserDefaults.standard.bool(forKey: "demoNoPlace")
    }

    /// A checking aid: `-demoOpen harvest -demoHarvestSearch apple`
    /// opens the Harvest sheet with those words already in its search
    /// box, so a still picture can be taken of what it finds.
    static var harvestSearch: String? {
        isRequested ? UserDefaults.standard.string(forKey: "demoHarvestSearch") : nil
    }

    /// A checking aid: `-demoOpen harvest -demoNothingGrowing YES`
    /// shows the Harvest sheet as it is for a garden with nothing sown
    /// or planted. The example garden's own sowings are left alone.
    static var nothingGrowing: Bool {
        isRequested && UserDefaults.standard.bool(forKey: "demoNothingGrowing")
    }

    /// A checking aid: `-demoOpen harvest -demoHarvestChoose YES` goes
    /// straight to the harvest form for the first plant the sheet
    /// offers. With `-demoHarvestSearch`, that is the first match.
    static var harvestChoosesFirst: Bool {
        isRequested && UserDefaults.standard.bool(forKey: "demoHarvestChoose")
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

    /// A checking aid: `-demoJournalSend YES` presses send in the
    /// journal's conversation a moment after it opens, so a still
    /// picture can show what sending leads to. Used with `-demoOpen
    /// journal`, `-demoDraft "What is this?"` and `-demoPhoto`, it shows
    /// Eira's answer to a photo that was asked about (JournalNaming.swift).
    static var sendsJournalDraft: Bool {
        isRequested && UserDefaults.standard.bool(forKey: "demoJournalSend")
    }

    /// A checking aid: `-demoPhotoCopies 3` makes the Identify screen
    /// bring the `-demoPhoto` in three times over, so the row that
    /// several photos make can be looked at in a still picture. 1 when
    /// not asked for.
    static var photoCopies: Int {
        guard isRequested else { return 1 }
        return min(max(1, UserDefaults.standard.integer(forKey: "demoPhotoCopies")), IdentifyView.mostPhotos)
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
    /// With `-demoPlant Garlic`, `-demoPlantDrawing crop` opens one of
    /// the plant's drawings large (a life stage, or "leaf" or "bloom").
    static var opensPlantDrawing: String? {
        isRequested ? UserDefaults.standard.string(forKey: "demoPlantDrawing") : nil
    }
    /// A checking aid: `-startSection journal -demoJournalEnd YES` opens
    /// the Journal page already scrolled to its foot, to see whether the
    /// last entry comes clear of Eira's bar.
    static var journalStartsAtEnd: Bool {
        isRequested && UserDefaults.standard.bool(forKey: "demoJournalEnd")
    }
    static var opensCompanions: String? {
        isRequested ? UserDefaults.standard.string(forKey: "demoCompanions") : nil
    }
    static var opensPests: Bool {
        isRequested && UserDefaults.standard.bool(forKey: "demoPests")
    }

    /// A checking aid: `-demoFlowerShapes YES` opens the Flower shapes
    /// page in place of the Gardens page, and `-demoFlowerShape Bilabiate`
    /// opens that one shape's page, so still pictures can be taken.
    static var opensFlowerShapes: Bool {
        isRequested && UserDefaults.standard.bool(forKey: "demoFlowerShapes")
    }
    static var opensFlowerShape: String? {
        isRequested ? UserDefaults.standard.string(forKey: "demoFlowerShape") : nil
    }

    /// A checking aid: `-startSection gardens -demoWildlife book` opens
    /// the UK wildlife pages in place of the Gardens page, so still
    /// pictures can be taken without tapping through to them.
    /// DemoWildlifePage lists what can follow `-demoWildlife`.
    static var opensWildlife: String? {
        isRequested ? UserDefaults.standard.string(forKey: "demoWildlife") : nil
    }

    /// A checking aid: `-startSection gardens -demoFungus start` opens
    /// the fungus key in place of the Gardens list, and `-demoFungus
    /// r-honey` opens it at that step or answer (the ids are in
    /// FungusKey.json), so a still picture can be taken of any of them.
    static var opensFungusKey: String? {
        isRequested ? UserDefaults.standard.string(forKey: "demoFungus") : nil
    }

    /// With `-demoFungus`, `-demoFungusKey SampleFungusKey` opens that
    /// key in place of Windfall's own (FungusKeys).
    static var fungusKeyFile: String {
        UserDefaults.standard.string(forKey: "demoFungusKey") ?? FungusKeys.ownFile
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

    /// A checking aid: `-demoOpen fit -demoFITName lav` opens a FIT
    /// Count with "lav" already in the name box, so a still picture can
    /// show the suggestions under it. Nil when it was not asked for.
    static var fitName: String? {
        guard isRequested, let typed = UserDefaults.standard.string(forKey: "demoFITName"),
              !typed.isEmpty else { return nil }
        return typed
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
            if !hasNoPlace {
                allotment.latitude = 51.5
                allotment.longitude = -2.55
            }
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
            // `-demoDraw` picks one of the newer drawing screens, for
            // taking pictures of them: drag, steps, ring, point, map or
            // chooser. Without it, the form of numbers.
            switch UserDefaults.standard.string(forKey: "demoDraw") {
            case "drag": GardenDrawView(garden: garden)
            case "steps": GardenDrawSteps(garden: garden)
            case "ring": NorthRingSetter(garden: garden)
            case "point": NorthByPointing(garden: garden)
            case "map": NorthByMap(garden: garden)
            case "chooser": GardenDrawChooser(garden: garden)
            default: GardenEditorView(garden: garden)
            }
        } else {
            Text("Loading the example garden…")
        }
    }
}
