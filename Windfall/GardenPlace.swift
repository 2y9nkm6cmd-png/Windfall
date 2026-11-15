//
//  GardenPlace.swift
//  Windfall
//
//  The rules behind giving a garden its place on the map, and behind
//  what Today's weather card says while there is no weather to show.
//  Nothing here draws anything or touches the GPS or the network, so all
//  of it can be tested. The sheet that uses it is in
//  GardenPlaceSheet.swift.
//
//  WHY THIS FILE EXISTS (15 November 2026)
//  William reported four things on the checklist:
//
//    "It's not working."                       (the weather)
//    "It's not asking me this, no location     (Apple's location
//     services seem to be working."             question)
//    "This is still too complex to set up."    (a garden's place)
//
//  What was found. The weather is fetched for a garden's place, and
//  failing that for wherever the device is. On his iPhone no garden had
//  a place and the device's position never arrived, so nothing was ever
//  fetched: no reading, and not one day in the weather diary. The only
//  ways to give a garden a place were to stand in it and press a button
//  five taps deep, or to type its latitude and longitude as numbers. And
//  every "Use where I am now" button did nothing at all, without a word,
//  when the device would not say where it was.
//
//  What changed. A garden can now be placed by typing its town, village
//  or postcode, which needs no permission from anyone. Every place that
//  asks the device where it is now says what happened when it cannot.
//  And the weather card says why it has no weather and offers the one
//  button that puts it right.
//

import Foundation

// MARK: - The location question

/// What this device has said to "May Windfall use your location?".
///
/// Apple has five answers. For deciding what to say and which button to
/// offer, three are enough. LocationManager.swift turns Apple's into
/// these (`LocationManager.answer`).
enum LocationAnswer: Equatable {
    /// The question has never been put, or was answered "Allow Once"
    /// and that once is over.
    case notAsked
    /// Windfall may ask the device where it is.
    case allowed
    /// The answer was No, or Location Services are off for the whole
    /// device, or a parent or an employer has locked them. Apple puts
    /// the question once only, so from here the app can never ask
    /// again: the person has to change it in the Settings app.
    case refused

    /// A few words for the Settings page.
    var words: String {
        switch self {
        case .notAsked: return "Not asked yet"
        case .allowed: return "Allowed"
        case .refused: return "Switched off"
        }
    }
}

// MARK: - A place found by name

/// One answer to a search for a town, a village or a postcode.
///
/// `Identifiable` lets SwiftUI tell the rows of a list apart, and
/// `Equatable` lets two be compared with `==`.
struct FoundPlace: Identifiable, Equatable {
    /// The name in large letters, such as "Frenchay".
    let name: String
    /// A quieter line under it, such as "Bristol, England". May be empty.
    let detail: String
    let latitude: Double
    let longitude: Double

    /// Made from the place itself, so the same spot found twice is one
    /// row and not two.
    var id: String { "\(name)|\(GardenPlace.coordinateLine(latitude: latitude, longitude: longitude))" }
}

// MARK: - The rules

enum GardenPlace {

    // MARK: What was typed

    /// The fewest letters worth searching for.
    static let fewestLetters = 3

    /// What was typed, made ready to search for: the spaces at each end
    /// taken off, runs of spaces made one, and a postcode put into its
    /// usual form. Nil when there is too little to search for.
    static func searchText(for typed: String) -> String? {
        // `split` cuts the text at its spaces and drops the empty pieces
        // a double space would leave. `joined` puts it back together
        // with one space between each piece.
        let tidy = typed.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).joined(separator: " ")
        guard tidy.count >= fewestLetters else { return nil }
        if let postcode = postcode(in: tidy) { return postcode }
        return tidy
    }

    /// A UK postcode in its usual form ("BS16 1QY"), if that is what the
    /// text is. Typed in small letters or with no space, it is still a
    /// postcode: "bs161qy" comes back as "BS16 1QY".
    ///
    /// The shape checked for: one or two letters, a digit, perhaps one
    /// more digit or letter, then a digit and two letters. That is every
    /// form a UK postcode takes. It is a check of the shape only. Whether
    /// such a postcode exists is for the map to say.
    static func postcode(in text: String) -> String? {
        let letters = Array(text.uppercased().filter { !$0.isWhitespace })
        // The shortest is "M1 1AA" (five) and the longest "SW1A 1AA"
        // (seven).
        guard (5...7).contains(letters.count) else { return nil }
        // The last three are always a digit and two letters.
        let inward = letters.suffix(3)
        let outward = Array(letters.dropLast(3))
        guard let first = inward.first, first.isNumber,
              inward.dropFirst().allSatisfy({ $0.isLetter && $0.isASCII }) else { return nil }
        // The part before starts with one or two letters, then a digit.
        let leading = outward.prefix { $0.isLetter && $0.isASCII }.count
        guard (1...2).contains(leading), outward.count > leading, outward[leading].isNumber else { return nil }
        // Anything after that digit is one more digit or letter.
        let rest = outward.dropFirst(leading + 1)
        guard rest.count <= 1, rest.allSatisfy({ ($0.isNumber || $0.isLetter) && $0.isASCII }) else { return nil }
        return String(outward) + " " + String(inward)
    }

    // MARK: Showing a place

    /// A position rounded for keeping: four decimal places, which is
    /// about ten metres. The same rounding the garden editor has always
    /// used (`WeatherPlace.rounded`).
    static func rounded(_ value: Double) -> Double {
        (value * 10_000).rounded() / 10_000
    }

    /// A place as a person would read it: "51.4905° N, 2.4926° W".
    static func coordinateLine(latitude: Double, longitude: Double) -> String {
        // `abs` drops the minus sign. North or south, east or west say
        // which side instead.
        let northSouth = latitude < 0 ? "S" : "N"
        let eastWest = longitude < 0 ? "W" : "E"
        // `%.4f` writes a number with four figures after the point.
        let up = String(format: "%.4f", abs(latitude))
        let across = String(format: "%.4f", abs(longitude))
        return "\(up)° \(northSouth), \(across)° \(eastWest)"
    }

    /// The line for a garden in a list of gardens: where it is, or that
    /// it has no place yet.
    static func line(latitude: Double?, longitude: Double?) -> String {
        guard let latitude, let longitude else { return "Not set" }
        return coordinateLine(latitude: latitude, longitude: longitude)
    }

    /// How far apart two places are, in kilometres, as the crow flies.
    ///
    /// This is the "haversine" sum, the usual one for distance over a
    /// globe. It is good to well under one part in a hundred, which is
    /// plenty for saying "about 3 km from the Allotment".
    static func kilometres(fromLatitude lat1: Double, longitude lon1: Double,
                           toLatitude lat2: Double, longitude lon2: Double) -> Double {
        let earthRadius = 6_371.0
        // The sums want angles in radians, not degrees.
        func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
        let dLat = radians(lat2 - lat1)
        let dLon = radians(lon2 - lon1)
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(radians(lat1)) * cos(radians(lat2)) * sin(dLon / 2) * sin(dLon / 2)
        return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    /// "about 3 km away", "under 1 km away" or "about 250 km away": a
    /// distance in words, for the line that offers one garden the place
    /// of another.
    static func distanceWords(kilometres: Double) -> String {
        if kilometres < 1 { return "under 1 km away" }
        return "about \(Int(kilometres.rounded())) km away"
    }

    // MARK: When the device will not say where it is

    /// What to say when "Use where I am now" came back with nothing.
    /// Until 15 November 2026 nothing was said at all.
    ///
    /// `answer` is what the device has said to the location question.
    /// (The device's own words for what went wrong are not used: they
    /// read like "kCLErrorDomain error 0", which helps nobody.)
    static func noFixWords(answer: LocationAnswer) -> String {
        switch answer {
        case .refused:
            return "Location is switched off for Windfall on this device. Search by name instead, or switch it on in Settings."
        case .notAsked:
            return "This device has not let Windfall use its location. Search by name instead."
        case .allowed:
            // Indoors, or with no signal: an ordinary thing, not a fault.
            return "This device could not say where it is just now. Try again outdoors, or search by name."
        }
    }
}

// MARK: - Today's weather card with no weather

/// Why Today's weather card has nothing to show, and what to do about
/// it. Until 15 November 2026 the card said "Conditions not checked
/// yet" whatever the reason, with a "Check now" button that could do
/// nothing when the trouble was that no garden had a place.
enum WeatherGap: Equatable {

    /// The weather is being asked for at this moment.
    case fetching
    /// Nothing says where to ask about: no garden has a place on the
    /// map and the device has not said where it is.
    case noPlace(LocationAnswer)
    /// There is a place to ask about, and asking failed. Usually no
    /// signal. The words are the system's own.
    case failed(String)
    /// There is a place, nothing has gone wrong and nothing has been
    /// asked yet: the moment just after the app opens.
    case waiting

    /// Which of the four it is.
    ///
    /// - `isLoading`: a question is on its way to the weather service.
    /// - `lastError`: what went wrong last time, if anything did.
    /// - `aGardenHasPlace`: whether any garden in use has a place.
    /// - `answer`: what the device has said to the location question.
    static func reason(isLoading: Bool, lastError: String?,
                       aGardenHasPlace: Bool, answer: LocationAnswer) -> WeatherGap {
        if isLoading { return .fetching }
        if let lastError, !lastError.isEmpty { return .failed(lastError) }
        if !aGardenHasPlace { return .noPlace(answer) }
        return .waiting
    }

    /// The card's larger line.
    var headline: String {
        switch self {
        case .fetching: return "Checking conditions…"
        case .noPlace: return "No weather yet"
        case .failed: return "The weather could not be fetched"
        case .waiting: return "Conditions not checked yet"
        }
    }

    /// The card's smaller line: why, in plain words.
    var detail: String {
        switch self {
        case .fetching:
            return "Asking the weather service, Open-Meteo."
        case .noPlace(.refused):
            return "Windfall does not know where your garden is, and location is switched off for it on this device. Tell it the garden's town or postcode."
        case .noPlace:
            return "Windfall does not know where your garden is. Tell it the garden's town or postcode, or use where you are now."
        case .failed(let problem):
            return problem + " Windfall will try again by itself."
        case .waiting:
            return "Weather comes from Open-Meteo, using your garden's place."
        }
    }

    /// What the card's button says. Nil for no button.
    var buttonTitle: String? {
        switch self {
        case .fetching: return nil
        case .noPlace: return "Set the garden's place"
        case .failed, .waiting: return "Check now"
        }
    }

    /// True when the button should open the sheet for placing a garden,
    /// false when it should ask the weather service again.
    var buttonSetsPlace: Bool {
        if case .noPlace = self { return true }
        return false
    }
}
