import Foundation

// The common plant diseases, each with a diagram of what it looks like.
//
// Asked for by William on 15 November 2026: "Are you including photos of
// the pests and diseases like rust etc." and then "Include diagrams of the
// diseases too."
//
// The words ship inside the app as PlantDiseases.json and the diagrams are
// in the app's store of pictures under "Diseases/", made by
// Tools/design/plant_diseases.py. Like the UK wildlife list, none of this
// is written into the database.
//
// ⚠️ Every word in the file was written by Claude from general knowledge,
// and every diagram drawn from memory. Nothing has been checked against a
// reference book. The advice is about growing conditions only: it names
// no sprays and no amounts.
//
// Nothing here draws. This file reads the list and answers questions about
// it, so that it can be tested without a Mac.

/// One disease, or one disorder that is mistaken for a disease.
struct PlantDisease: Decodable, Identifiable, Hashable {
    /// The short name used in file names: "powdery-mildew".
    let slug: String
    let name: String
    /// What causes it, in a few words: "A fungus".
    let cause: String
    /// What you see on the plant.
    let seen: String
    /// The plants it is most often found on, as a sentence.
    let plants: String
    /// The time of year and the weather it goes with.
    let season: String
    /// What helps, by way of growing conditions.
    let helps: String
    /// A caution, where there is one.
    let note: String?

    // The file calls the season "when". `CodingKeys` tells Swift which
    // name in the file fills which property.
    enum CodingKeys: String, CodingKey {
        case slug, name, cause, seen, plants, season = "when", helps, note
    }

    var id: String { slug }

    /// The name of its diagram in the app's store of pictures.
    var pictureName: String { "Diseases/disease-\(slug)" }
}

struct PlantDiseases {

    let list: [PlantDisease]

    /// The shape of PlantDiseases.json. Only "diseases" is read.
    private struct File: Decodable { let diseases: [PlantDisease] }

    /// Reads the list from the file's contents.
    static func decode(_ data: Data) throws -> PlantDiseases {
        PlantDiseases(list: try JSONDecoder().decode(File.self, from: data).diseases)
    }

    /// The list that ships inside the app, read once. If the file is
    /// missing the list is empty.
    static let shared: PlantDiseases = {
        guard let url = Bundle.main.url(forResource: "PlantDiseases", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let found = try? decode(data) else { return PlantDiseases(list: []) }
        return found
    }()

    func disease(slug: String) -> PlantDisease? {
        list.first { $0.slug == slug }
    }

    /// A word cut back to the form it is compared in: small letters, and a
    /// plural brought back to one. "Tomatoes" and "tomato" both become
    /// "tomato", "peaches" becomes "peach", "leeks" becomes "leek".
    static func stem(_ word: String) -> String {
        let small = word.lowercased()
        for ending in ["oes", "ches", "shes"] where small.hasSuffix(ending) && small.count > ending.count + 1 {
            return String(small.dropLast(2))
        }
        if small.hasSuffix("s") && !small.hasSuffix("ss") && small.count > 3 {
            return String(small.dropLast())
        }
        return small
    }

    /// The words of a piece of text, each cut back with `stem`.
    static func stems(in text: String) -> [String] {
        text.split { !$0.isLetter }.map { stem(String($0)) }
    }

    /// The diseases whose list of plants names this plant. The whole name
    /// has to appear, word for word, so "Pea" finds diseases of peas and
    /// not those of pears or peaches.
    func affecting(plantNamed name: String) -> [PlantDisease] {
        let wanted = PlantDiseases.stems(in: name)
        guard !wanted.isEmpty else { return [] }
        return list.filter { disease in
            let words = PlantDiseases.stems(in: disease.plants)
            guard words.count >= wanted.count else { return false }
            return (0...(words.count - wanted.count)).contains { start in
                Array(words[start..<(start + wanted.count)]) == wanted
            }
        }
    }
}
