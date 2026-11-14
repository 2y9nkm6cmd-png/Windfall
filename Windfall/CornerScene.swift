//
//  CornerScene.swift
//  Windfall
//
//  What the drawing in Today's corner should show: which month's plant,
//  how far through the month it is, how hard the wind blows and what
//  the weather is doing.
//
//  This file holds only the deciding. It has no drawing in it, so the
//  sums can be tested without the app (Tools/checks/LogicTests.swift).
//  The drawing is in CornerSprigs.swift and LivingCorner.swift.
//
//  Nothing here needs setting up by the person using the app. The month
//  and day come from the device's calendar and the rest from the weather
//  the app already fetches for the garden.
//

import Foundation

/// How hard the wind is blowing, as far as the drawing cares.
enum CornerWind: String, CaseIterable, Hashable {
    case calm, breeze, gusty

    var label: String {
        switch self {
        case .calm: return "Calm"
        case .breeze: return "Breeze"
        case .gusty: return "Gusty"
        }
    }
}

/// The weather, as far as the drawing cares. Only one at a time: snow
/// wins over rain, rain over frost, frost over night, and night over
/// great heat.
enum CornerWeather: String, CaseIterable, Hashable {
    case fine, rain, snow, frost, heat, night

    var label: String {
        switch self {
        case .fine: return "Fine"
        case .rain: return "Rain"
        case .snow: return "Snow"
        case .frost: return "Frost"
        case .heat: return "Heat"
        case .night: return "Night"
        }
    }
}

/// Everything the corner drawing needs to know to draw itself.
struct CornerScene: Equatable {

    /// 1 for January to 12 for December.
    var monthNumber: Int
    /// 0 on the first day of the month, 1 on the last.
    var monthProgress: Double
    var breeze: CornerWind = .breeze
    var cornerSky: CornerWeather = .fine
    /// False when it is too cold for a bumblebee to fly.
    var isWarmEnoughForBee = true
    /// True after dark. Kept apart from `cornerSky`, which can only say
    /// one thing at a time: on a wet night it says rain, and the drawing
    /// still needs to know that it is night.
    var isNight = false

    // MARK: The limits

    /// Below this many kilometres an hour the air counts as calm.
    static let calmBelowKMH = 8.0
    /// Above this it is gusty. The same line the app uses for "too windy
    /// for a count" (CurrentConditions.isWindy).
    static let gustyAboveKMH = 20.0
    /// A bumblebee does not fly when it is colder than this.
    static let beeMinimumC = 5.0
    /// At or below this the drawing sparkles with frost.
    static let frostAtOrBelowC = 0.0
    /// At or above this, by day, it is great heat: the plant wilts and
    /// the air shimmers.
    static let heatFromC = 30.0
    /// Rain lighter than this is not drawn. The same line as
    /// CurrentConditions.isDry.
    static let rainFromMM = 0.1
    /// How long the bee stays away between visits, in seconds. The app
    /// picks a different wait inside this range each time.
    static let beeWaitSeconds: ClosedRange<Double> = 10...20

    /// The months that have a bee: every month with a flower to feed
    /// from. In January and December it is asleep underground, and
    /// October's moment is the falling apple.
    static let beeMonths: Set<Int> = [2, 3, 4, 5, 6, 7, 8, 9, 11]

    /// What is drawn each month, January first.
    static let plantNames = ["Hazel catkins", "Snowdrop", "Daffodil", "Pear blossom", "Apple blossom", "Foxglove",
                             "Lavender", "Blackberry", "Pear", "Apple", "Ivy in flower", "Mistletoe"]

    /// One line on what each month's drawing does, January first.
    static let plantNotes = [
        "Catkins lengthen and swing. Snow drifts by. The bee is asleep.",
        "The app icon. The bee drinks, leaves to the right and returns from the left.",
        "One flower opens, then the second. The bee visits each trumpet.",
        "Buds open, then petals fall. The bee goes flower to flower.",
        "Deep pink buds open to pale pink. A petal drifts down.",
        "Bells open from the bottom up. The bee climbs inside.",
        "Spikes colour up from the bottom. The bee goes spike to spike.",
        "Flower and fruit together. Berries ripen green, red, black.",
        "The fruit swells and yellows. The bee rests on a leaf.",
        "Leaves turn and fall. Once each visit an apple drops.",
        "The last flowers of the year and the bee's last feed.",
        "On a bare apple bough. Berries gather. Snow drifts by."
    ]

    var plantName: String { CornerScene.plantNames[min(max(monthNumber, 1), 12) - 1] }
    var plantNote: String { CornerScene.plantNotes[min(max(monthNumber, 1), 12) - 1] }

    // MARK: Deciding

    /// How far through a month a day is: 0 on the 1st, 1 on the last day.
    static func progress(day: Int, daysInMonth: Int) -> Double {
        guard daysInMonth > 1 else { return 0.5 }
        return min(max(Double(day - 1) / Double(daysInMonth - 1), 0), 1)
    }

    /// Calm, a breeze or gusty, from the wind's speed. With no reading
    /// it is a breeze, so the drawing still moves.
    static func wind(forKMH speed: Double?) -> CornerWind {
        guard let speed else { return .breeze }
        if speed < calmBelowKMH { return .calm }
        if speed > gustyAboveKMH { return .gusty }
        return .breeze
    }

    /// The one kind of weather to draw. With no reading it is fine.
    /// `isSnowing` comes from the weather service's own word for the
    /// weather. Left out, it is false.
    static func weather(temperatureC: Double?, precipitationMM: Double?, isNight: Bool, isSnowing: Bool = false) -> CornerWeather {
        if isSnowing { return .snow }
        if let precipitationMM, precipitationMM >= rainFromMM { return .rain }
        if let temperatureC, temperatureC <= frostAtOrBelowC { return .frost }
        if isNight { return .night }
        if let temperatureC, temperatureC >= heatFromC { return .heat }
        return .fine
    }

    /// The scene for a moment in time, from whatever weather is known.
    /// Every weather value may be missing: before the first reading, or
    /// with no garden placed, the scene is a light breeze on a fine day.
    static func make(date: Date, calendar: Calendar,
                     temperatureC: Double?, precipitationMM: Double?, windSpeedKMH: Double?,
                     isSnowing: Bool = false, isNight: Bool) -> CornerScene {
        let parts = calendar.dateComponents([.month, .day], from: date)
        let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
        return CornerScene(monthNumber: parts.month ?? 1,
                           monthProgress: progress(day: parts.day ?? 15, daysInMonth: daysInMonth),
                           breeze: wind(forKMH: windSpeedKMH),
                           cornerSky: weather(temperatureC: temperatureC, precipitationMM: precipitationMM, isNight: isNight, isSnowing: isSnowing),
                           isWarmEnoughForBee: temperatureC.map { $0 >= beeMinimumC } ?? true,
                           isNight: isNight)
    }

    /// True in a month with flowers. Says nothing about the weather.
    var hasBee: Bool { CornerScene.beeMonths.contains(monthNumber) }

    /// True after dark, whichever of the two ways it was said: the
    /// weather drawn is night, or it is night under rain or frost.
    var isAfterDark: Bool { isNight || cornerSky == .night }

    /// True when the weather would let a bumblebee fly: not raining,
    /// snowing, frosty, gusty, too cold or too hot.
    var isBeeWeather: Bool {
        cornerSky != .rain && cornerSky != .snow && cornerSky != .frost && cornerSky != .heat
            && breeze != .gusty && isWarmEnoughForBee
    }

    /// True in great heat, when the plant hangs over and its leaves droop.
    var isWilting: Bool { cornerSky == .heat }

    /// True when the bee is in the picture: out and about by day in bee
    /// weather, or asleep in its flower at night.
    var beeIsAbout: Bool { hasBee && (isAfterDark || isBeeWeather) }

    /// True when the bee is asleep in its flower and not flying: every
    /// night in a month with flowers, whatever the weather (William,
    /// 14 November 2026). Rain, frost, wind and cold keep it from
    /// flying. They do not send it away from where it sleeps.
    var beeSleeps: Bool { hasBee && isAfterDark }

    /// What happens now and then in this month besides the bee.
    var moment: CornerMoment {
        switch monthNumber {
        case 1, 12: return .snow
        case 4, 5: return .petal
        case 10: return .windfall
        default: return .nothing
        }
    }
}

/// The small event of a month: something drifting down, or the apple.
enum CornerMoment: Equatable {
    case nothing, snow, petal, windfall
}
