//
//  GardenPlaceSheet.swift
//  Windfall
//
//  The sheet for saying where a garden is.
//
//  A garden's place on the map is what its weather is fetched for, what
//  starts its weather diary, and what says how high the sun climbs over
//  its beds. Until 15 November 2026 the only ways to set one were a
//  button five taps deep that needed the device's own position, or
//  typing latitude and longitude as numbers. William: "This is still
//  too complex to set up."
//
//  This sheet offers three ways, the plainest first:
//
//    1. Type a town, a village or a postcode and pick it from a list.
//       This needs no permission and works from an armchair.
//    2. Use where the device is now, for when you are standing in the
//       garden. If the device will not say, the sheet says so and says
//       what to do. (The old buttons said nothing.)
//    3. Take the same place as another garden that already has one.
//
//  Nothing is kept until Save is pressed.
//
//  It is opened from Today's weather card when there is no weather,
//  from a garden's plan card while that garden has no place, from
//  Settings, and from the garden's form of numbers. The rules it uses
//  (what counts as a postcode, the words for each case) are in
//  GardenPlace.swift, where they can be tested.
//

import SwiftUI
import SwiftData
import CoreLocation
import MapKit

// MARK: - Finding a place by name

/// Looks a typed name or postcode up on Apple's map.
///
/// This is the one thing in this file that goes out over the internet.
/// The words typed are sent to Apple Maps, which sends back the places
/// they could mean. (The weather service, Open-Meteo, has a search of
/// its own. It was tried from William's Mac on 15 November 2026 and
/// found towns and villages but no UK postcode at all, so Apple's is
/// used.)
enum PlaceFinder {

    /// The most answers shown. More than this is a list to wade through.
    static let mostShown = 6

    /// Roughly Britain and Ireland. Handed to the map as a hint about
    /// where to look first, so that "Frenchay" finds the one near
    /// Bristol and not a namesake on another continent.
    private static let home = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 54.5, longitude: -3.5),
        span: MKCoordinateSpan(latitudeDelta: 12, longitudeDelta: 14))

    /// The places the words could mean, the likeliest first. An empty
    /// list means nothing was found.
    ///
    /// `async` means this takes a while and the app carries on meanwhile.
    /// `throws` means it can fail, here when there is no internet, and
    /// whoever calls it must say what to do then.
    @MainActor
    static func find(_ words: String) async throws -> [FoundPlace] {
        guard let request = MKGeocodingRequest(addressString: words) else { return [] }
        request.region = home
        request.preferredLocale = Locale(identifier: "en_GB")

        let items: [MKMapItem]
        do {
            items = try await request.mapItems
        } catch let problem as MKError where problem.code == .placemarkNotFound {
            // The map's way of saying "no such place". That is an
            // answer, not a failure.
            return []
        }

        var places: [FoundPlace] = []
        for mapItem in items {
            let whereItIs = mapItem.location.coordinate
            // The address can come on several lines. One line reads
            // better in a list.
            let address = (mapItem.address?.shortAddress ?? mapItem.address?.fullAddress ?? "")
                .replacingOccurrences(of: "\n", with: ", ")
            let name = mapItem.name ?? words
            let place = FoundPlace(name: name,
                                   detail: address == name ? "" : address,
                                   latitude: whereItIs.latitude,
                                   longitude: whereItIs.longitude)
            // The same spot is not listed twice.
            if !places.contains(where: { $0.id == place.id }) { places.append(place) }
        }
        return Array(places.prefix(mostShown))
    }
}

// MARK: - The sheet

struct GardenPlaceSheet: View {

    /// The garden being placed, when the sheet was opened for one.
    /// Nil when it was opened from the weather card, and then the sheet
    /// asks which garden if there is more than one.
    private let fixedGarden: Garden?

    @Query(sort: [SortDescriptor(\Garden.displayOrder)]) private var allGardens: [Garden]
    @Environment(LocationManager.self) private var locationManager
    @Environment(\.dismiss) private var dismiss

    /// Which garden is chosen in the switch at the top, by its key.
    @State private var gardenKey: String?

    /// What has been typed in the search box.
    @State private var typed: String
    /// What the last search found.
    @State private var found: [FoundPlace] = []
    @State private var isSearching = false
    /// Said under the search box when a search found nothing or failed.
    @State private var searchProblem: String?

    /// True while the device is being asked where it is.
    @State private var isFinding = false
    /// Said under that button when the device would not say.
    @State private var hereProblem: String?

    /// The place picked so far, waiting for Save. Nil until one is.
    @State private var chosen: Choice?

    /// True while the search box has the keyboard.
    @FocusState private var isTyping: Bool

    /// A place picked in the sheet, with the words to show for it.
    private struct Choice: Equatable {
        let label: String
        let latitude: Double
        let longitude: Double
    }

    init(garden: Garden? = nil) {
        fixedGarden = garden
        // A checking aid can start the sheet with words already typed.
        // See `DemoGarden.placeSearch`.
        _typed = State(initialValue: DemoGarden.placeSearch ?? "")
    }

    // MARK: Which garden

    private var gardens: [Garden] { allGardens.filter(\.isActive) }

    /// The garden the sheet is about: the one it was opened for, or the
    /// one chosen in the switch, or the first with no place yet.
    private var garden: Garden? {
        if let fixedGarden { return fixedGarden }
        if let gardenKey, let picked = gardens.first(where: { $0.siteKey == gardenKey }) { return picked }
        return gardens.first { $0.latitude == nil || $0.longitude == nil } ?? gardens.first
    }

    /// Other gardens that already have a place, to offer theirs.
    private var placedNeighbours: [Garden] {
        gardens.filter { neighbour in
            neighbour.siteKey != garden?.siteKey && neighbour.latitude != nil && neighbour.longitude != nil
        }
    }

    // MARK: The page

    var body: some View {
        SheetPage(garden?.name ?? "Your garden",
                  detail: "Where is it? Its place decides its weather, and how high the sun climbs over it.",
                  confirmTitle: "Save",
                  canConfirm: chosen != nil && garden != nil,
                  onConfirm: save) {
            SheetScroll {
                if fixedGarden == nil, gardens.count > 1, let garden {
                    GlassSwitch(choices: gardens.map(\.siteKey), selection: Binding(
                        get: { garden.siteKey },
                        set: { gardenKey = $0 }
                    )) { key in
                        gardens.first { $0.siteKey == key }?.name ?? key
                    }
                }

                nowCard
                searchCard
                hereCard
                if !placedNeighbours.isEmpty { neighbourCard }

                Text("A name or postcode you search for is sent to Apple Maps to find it. The place you save stays on this device. The weather service is sent it rounded to about a hundred metres.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task {
            // The checking aid's search runs by itself.
            if DemoGarden.placeSearch != nil { search() }
        }
    }

    /// Where the garden is now, and where it will be after Save.
    private var nowCard: some View {
        SheetCard {
            SettingRow("Now") {
                Text(GardenPlace.line(latitude: garden?.latitude, longitude: garden?.longitude))
                    .foregroundStyle(Theme.inkSoft)
            }
            if let chosen {
                SettingRow("After Save") {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(chosen.label)
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.trailing)
                        Text(GardenPlace.coordinateLine(latitude: GardenPlace.rounded(chosen.latitude),
                                                        longitude: GardenPlace.rounded(chosen.longitude)))
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
        }
    }

    // MARK: By name

    private var searchCard: some View {
        SheetCard("Find it by name") {
            HStack(spacing: 8) {
                FieldBox {
                    TextField("Town, village or postcode", text: $typed)
                        .focused($isTyping)
                        // A place name is not a word to be "corrected".
                        .autocorrectionDisabled()
                        // Return on the keyboard searches.
                        .submitLabel(.search)
                        .onSubmit { search() }
                }
                Button("Search") { search() }
                    .buttonStyle(QuietGlassButton())
                    .disabled(GardenPlace.searchText(for: typed) == nil || isSearching)
            }

            if isSearching {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Looking it up…")
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            if let searchProblem {
                Text(searchProblem)
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(found) { place in
                Button {
                    chosen = Choice(label: place.name, latitude: place.latitude, longitude: place.longitude)
                } label: {
                    foundRow(place)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// One answer to a search: a ring that fills when it is the one
    /// picked, its name and its address.
    private func foundRow(_ place: FoundPlace) -> some View {
        let isChosen = chosen?.latitude == place.latitude && chosen?.longitude == place.longitude
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: isChosen ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isChosen ? Theme.leaf : Theme.inkSoft)
            VStack(alignment: .leading, spacing: 1) {
                Text(place.name)
                    .foregroundStyle(Theme.ink)
                if !place.detail.isEmpty {
                    Text(place.detail)
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        // Makes the whole row answer a tap, not only its words.
        .contentShape(.rect)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    private func search() {
        guard let words = GardenPlace.searchText(for: typed) else { return }
        // Put the keyboard away so the answers can be seen.
        isTyping = false
        isSearching = true
        searchProblem = nil
        // `Task` starts a piece of work that takes a while, here a
        // question over the internet, without freezing the sheet.
        Task {
            do {
                found = try await PlaceFinder.find(words)
                if found.isEmpty {
                    searchProblem = "Nothing found for \u{201C}\(words)\u{201D}. Try the nearest town, or the whole postcode."
                }
            } catch {
                found = []
                searchProblem = "The search could not be made. It needs the internet. Try again in a moment."
            }
            isSearching = false
        }
    }

    // MARK: Where the device is

    private var hereCard: some View {
        SheetCard("Or use where you are") {
            if locationManager.answer == .refused {
                // Apple shows its question once. After a No, only the
                // Settings app can change the answer.
                Text("Location is switched off for Windfall on this device.")
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Settings") { LocationManager.openSettings() }
                    .buttonStyle(QuietGlassButton())
            } else {
                Button {
                    useHere()
                } label: {
                    HStack(spacing: 8) {
                        Text("Use where I am now")
                        if isFinding { ProgressView().controlSize(.small) }
                    }
                }
                .buttonStyle(QuietGlassButton())
                .disabled(isFinding)
                Text("For when you are standing in the garden.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
            if let hereProblem {
                Text(hereProblem)
                    .font(.footnote)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func useHere() {
        isFinding = true
        hereProblem = nil
        Task {
            // If the device has never been asked, this is where Apple's
            // question appears.
            if let fix = await locationManager.currentLocation() {
                chosen = Choice(label: "Where you are now",
                                latitude: fix.coordinate.latitude,
                                longitude: fix.coordinate.longitude)
            } else {
                hereProblem = GardenPlace.noFixWords(answer: locationManager.answer)
            }
            isFinding = false
        }
    }

    // MARK: Another garden's place

    private var neighbourCard: some View {
        SheetCard("Or the same place as another garden") {
            ForEach(placedNeighbours) { neighbour in
                if let latitude = neighbour.latitude, let longitude = neighbour.longitude {
                    Button("The same as \(neighbour.name)") {
                        chosen = Choice(label: "The same as \(neighbour.name)", latitude: latitude, longitude: longitude)
                    }
                    .buttonStyle(QuietGlassButton())
                }
            }
            Text("Gardens within about a mile of each other share one weather diary.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Saving

    /// Keeps the picked place as the garden's and closes the sheet.
    ///
    /// Setting the place is all it does. MainTabView watches for a
    /// garden's place changing and fetches the weather and the weather
    /// diary for it at once.
    private func save() {
        guard let garden, let chosen else { return }
        // Four decimal places is about ten metres.
        garden.latitude = GardenPlace.rounded(chosen.latitude)
        garden.longitude = GardenPlace.rounded(chosen.longitude)
        dismiss()
    }
}

// MARK: - A line that leads to the sheet

/// One garden's place as a row with a button, for a list of gardens:
/// the garden's name, where it is, and Set or Change. Used on the
/// Settings page.
struct GardenPlaceRow: View {

    let garden: Garden
    @State private var isPlacing = false

    var body: some View {
        let hasPlace = garden.latitude != nil && garden.longitude != nil
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(garden.name)
                Text(GardenPlace.line(latitude: garden.latitude, longitude: garden.longitude))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button(hasPlace ? "Change" : "Set") { isPlacing = true }
        }
        .sheet(isPresented: $isPlacing) {
            GardenPlaceSheet(garden: garden)
        }
    }
}
