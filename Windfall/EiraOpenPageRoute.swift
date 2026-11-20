//
//  EiraOpenPageRoute.swift
//  Windfall
//
//  The other half of "show me bed 3" (piece 4 of project doc 119,
//  20 November 2026). EiraOpenPage.swift reads the words. This file
//  turns what it found into a page, and carries it from Eira's bar to
//  the window, which does the opening.
//
//  Three pieces:
//    EiraPageRoute        a page Eira can put on top of a place
//    EiraOpenRequest      where to go, and what to put on top
//    EiraNavigator        the hand-over between the bar and MainTabView
//    EiraPageDestination  the screen each route shows
//

import Foundation
import Observation
import SwiftData
import SwiftUI

/// A page Eira can put on top of a place.
///
/// `Hashable` is what lets a value be put on a NavigationStack's path,
/// the list of pages piled on a place. A record (a Bed, a Plant) is
/// hashable already: SwiftData gives every record an identity of its
/// own. The last three are places that have no tab on an iPhone, and so
/// are opened there as a page on the tab that holds them.
enum EiraPageRoute: Hashable {
    case bed(Bed)
    case plant(Plant)
    case species(Fauna)
    case plantLibrary
    case year
}

/// What Eira has been asked to open.
struct EiraOpenRequest: Equatable {
    /// A label of its own, so that asking for the same page twice still
    /// counts as a new request.
    var id = UUID()
    /// The place to go to.
    var place: EiraOpenPlace
    /// The page to put on top of it, if any.
    var page: EiraPageRoute?
    /// For a garden: the garden whose plan the Gardens place should
    /// show, by its `siteKey`.
    var gardenKey: String?
}

extension EiraOpenRequest {

    /// Reads a sentence typed in Eira's bar against the records, and
    /// says what to open. Nil when it is not a request to open anything
    /// the rule knows, and the words should go on as before.
    ///
    /// The records are fetched here, when the words are sent, rather
    /// than watched all the time by the bar, which would draw the bar
    /// again whenever any plant changed.
    @MainActor
    static func read(_ text: String, context: ModelContext) -> EiraOpenRequest? {
        // A quick look first: most sentences are not requests to open
        // anything, and need no records fetched at all.
        guard EiraOpenRule.asked(in: text) != nil else { return nil }

        let bedList = (try? context.fetch(FetchDescriptor<Bed>(predicate: #Predicate { $0.retiredAt == nil }))) ?? []
        let plantList = (try? context.fetch(FetchDescriptor<Plant>())) ?? []
        let gardenList = ((try? context.fetch(FetchDescriptor<Garden>())) ?? []).filter(\.isActive)
        let faunaList = (try? context.fetch(FetchDescriptor<Fauna>())) ?? []

        // Each record becomes a candidate: its kind, where it is in its
        // own list, and the names it goes by.
        var candidates: [EiraOpenCandidate] = []
        candidates += bedList.enumerated().map { EiraOpenCandidate(kind: .bed, index: $0.offset, names: [$0.element.name]) }
        candidates += plantList.enumerated().map {
            EiraOpenCandidate.forPlant(index: $0.offset, common: $0.element.commonName, variety: $0.element.variety)
        }
        candidates += gardenList.enumerated().map { EiraOpenCandidate(kind: .garden, index: $0.offset, names: [$0.element.name]) }
        candidates += faunaList.enumerated().map {
            EiraOpenCandidate(kind: .species, index: $0.offset,
                              names: [$0.element.commonName, $0.element.scientificName ?? ""])
        }

        switch EiraOpenRule.read(text, candidates: candidates) {
        case nil:
            return nil
        case .place(let place):
            return EiraOpenRequest(place: place)
        case .record(.bed, let index):
            return EiraOpenRequest(place: .gardens, page: .bed(bedList[index]))
        case .record(.plant, let index):
            return EiraOpenRequest(place: .plants, page: .plant(plantList[index]))
        case .record(.species, let index):
            return EiraOpenRequest(place: .wildlife, page: .species(faunaList[index]))
        case .record(.garden, let index):
            return EiraOpenRequest(place: .gardens, gardenKey: gardenList[index].siteKey)
        // Several of one kind: the place where they are all listed.
        case .several(.plant, _):
            return EiraOpenRequest(place: .plants)
        case .several(.species, _):
            return EiraOpenRequest(place: .wildlife)
        case .several(.bed, _), .several(.garden, _):
            return EiraOpenRequest(place: .gardens)
        }
    }
}

extension EiraOpenRequest {

    /// The same request in the form Eira's conversation keeps it
    /// (`EiraConversation.PageRequest`, made by the lane B chat, doc
    /// 136), so Eira's test run can write down which page a question
    /// opened. The words are the ones the page itself hands Eira once
    /// open (`EiraSight` and `AppSection.eiraPhrase`), so the answers
    /// file shows exactly what Eira would then be told.
    var pageRequest: EiraConversation.PageRequest {
        switch page {
        case .bed(let bed)?:
            return .init(kind: .bed, key: String(describing: bed.persistentModelID), phrase: EiraSight.bed(bed.name).full)
        case .plant(let plant)?:
            return .init(kind: .plant, key: String(describing: plant.persistentModelID),
                         phrase: EiraSight.plant(plant.commonName, variety: plant.variety).full)
        case .species(let fauna)?:
            return .init(kind: .species, key: String(describing: fauna.persistentModelID),
                         phrase: EiraSight.species(fauna.commonName).full)
        case .plantLibrary?, .year?, nil:
            let section = AppSection(rawValue: place.rawValue)
            if let gardenKey {
                return .init(kind: .garden, key: gardenKey,
                             phrase: "the Gardens screen, showing the plan of the garden \(gardenKey)")
            }
            return .init(kind: .place, key: place.rawValue, phrase: section?.eiraPhrase ?? place.spoken)
        }
    }
}

/// The hand-over between Eira's bar and the window.
///
/// The bar knows what was asked for, but the window (MainTabView) owns
/// which place is showing and the pile of pages on it. So the bar leaves
/// a request here and the window picks it up. `@Observable` means the
/// window is told the moment a request arrives. The same pattern as the
/// questions and photos a page hands to the bar (EiraScreen.swift).
@Observable
final class EiraNavigator {

    /// A request waiting for the window. `private(set)`: anything may
    /// read it, only the functions below change it.
    private(set) var request: EiraOpenRequest?

    /// The bar asks for a page.
    func open(_ request: EiraOpenRequest) {
        self.request = request
    }

    /// The window takes it. Handed over once and then gone.
    func take() -> EiraOpenRequest? {
        let waiting = request
        request = nil
        return waiting
    }

    /// The garden whose plan the Gardens place should show, waiting for
    /// that page to pick it up. An iPhone shows one garden's plan at a
    /// time; a wider screen shows them all and needs no telling.
    private(set) var gardenToShow: String?

    func showGarden(_ key: String) {
        gardenToShow = key
    }

    func takeGardenToShow() -> String? {
        let waiting = gardenToShow
        gardenToShow = nil
        return waiting
    }
}

/// The screen each route shows when Eira puts it on top of a place.
struct EiraPageDestination: View {
    let route: EiraPageRoute

    var body: some View {
        switch route {
        case .bed(let bed): BedDetailView(bed: bed)
        case .plant(let plant): PlantDetailView(plant: plant)
        case .species(let fauna): FaunaDetailView(fauna: fauna)
        case .plantLibrary: PlantLibraryView()
        case .year: YearView()
        }
    }
}
