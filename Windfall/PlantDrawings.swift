import Foundation

// Which drawing goes with which plant.
//
// The drawings live in the app's store of pictures under "Plants/", one
// for each kind of plant at each stage of its life: "Plants/plant-carrot-crop".
// They are made by Tools/design/plants_all.py, which also writes the list
// this file reads (PlantDrawings.json): every kind, its stages in order,
// and the names in the plant library that share its drawings. "Leek" and
// "Leeks" are one kind. So are every variety of apple.
//
// Nothing here draws. This file only answers two questions: "which kind
// is this plant?" and "which stage should its card show this month?".

struct PlantDrawings {

    /// One stage of a plant's life: "crop", with the words to show under
    /// it, "Ready to pull".
    struct Stage: Decodable, Identifiable, Equatable {
        let stage: String
        let label: String
        var id: String { stage }
    }

    /// One kind of plant and the stages it is drawn at, youngest first.
    struct Kind: Decodable, Identifiable, Equatable {
        let slug: String
        let name: String
        let stages: [Stage]
        let libraryNames: [String]
        var id: String { slug }
    }

    let kinds: [Kind]
    /// From a library name in small letters to its place in `kinds`, so
    /// that finding a plant's kind is one look-up and not a search.
    private let placeByName: [String: Int]

    init(kinds: [Kind]) {
        self.kinds = kinds
        var places: [String: Int] = [:]
        for (place, kind) in kinds.enumerated() {
            for name in kind.libraryNames {
                places[PlantDrawings.plain(name)] = place
            }
        }
        placeByName = places
    }

    /// The shape of PlantDrawings.json. Only "kinds" is read.
    private struct File: Decodable { let kinds: [Kind] }

    /// Reads the list from the file's contents.
    static func decode(_ data: Data) throws -> PlantDrawings {
        PlantDrawings(kinds: try JSONDecoder().decode(File.self, from: data).kinds)
    }

    /// The list that ships inside the app, read once. If the file is
    /// missing the list is empty and no plant shows a drawing.
    static let shared: PlantDrawings = {
        guard let url = Bundle.main.url(forResource: "PlantDrawings", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? decode(data) else { return PlantDrawings(kinds: []) }
        return list
    }()

    /// A name as it is compared: small letters, no spaces at the ends.
    static func plain(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// The kind whose drawings a plant uses, or nil when it has none.
    func kind(forPlantNamed name: String) -> Kind? {
        placeByName[PlantDrawings.plain(name)].map { kinds[$0] }
    }

    /// The name of one drawing in the app's store of pictures.
    static func pictureName(kind: String, stage: String) -> String {
        "Plants/plant-\(kind)-\(stage)"
    }

    /// The stages a card falls back on, best first, when the month gives
    /// no reason to choose one.
    static let cardOrder = ["crop", "flower", "growing", "young"]

    /// The one stage to show on a plant's card.
    ///
    /// In a month the plant is harvested it shows the crop. In a month it
    /// flowers it shows the flower. Otherwise it shows the plant at its
    /// best: the crop if it has one, then the flower, and so on.
    static func cardStage(of kind: Kind, month: Int, harvestMonths: [Int], floweringMonths: [Int]) -> Stage? {
        func find(_ wanted: String) -> Stage? { kind.stages.first { $0.stage == wanted } }
        if harvestMonths.contains(month), let crop = find("crop") { return crop }
        if floweringMonths.contains(month), let flower = find("flower") { return flower }
        for wanted in cardOrder {
            if let stage = find(wanted) { return stage }
        }
        return kind.stages.last
    }
}
