//
//  WeatherNow.swift
//  Windfall
//
//  Keeps the weather up to date by itself, for the whole app.
//
//  Why this file exists. Until 14 November 2026 the weather was fetched
//  by the Today page, once, when it was drawn. Three things followed:
//
//  - Anything else that shows the weather had to hope Today had been
//    looked at first: the widgets, and the drawing in Today's corner.
//  - A window left open, or an app brought back from the background,
//    went on showing the weather from when it was opened.
//  - On a device where no garden has a place on the map, nothing was
//    fetched at all until "Check now" was tapped, because the app never
//    asked where it was unless a button had been pressed.
//
//  Now the app asks for the weather itself: when it opens, each time it
//  comes back to the front, every quarter of an hour while it is open,
//  and whenever a garden's place is set or moved. MainTabView calls
//  `refresh` at each of those moments.
//
//  Where it asks about, in order:
//    1. The first garden that has a place on the map.
//    2. Otherwise wherever the device is. The first time, that means
//       Apple's "may Windfall use your location?" question appears when
//       the app opens (William, 14 November 2026: "Ask once on opening").
//       Apple shows that question once only. After a No, the app stays
//       quiet and Today's card says what to do.
//
//  The sums are in WeatherService.swift (`refresh` and `WeatherPlace`),
//  where they can be tested. This file is the glue between them and the
//  parts that only exist on a real device: the records, the GPS and the
//  widgets.
//

import Foundation
import CoreLocation
import SwiftData

@MainActor
enum WeatherNow {

    /// How long to wait between looks while the app stays open. The same
    /// quarter of an hour that `WeatherService` keeps a reading for.
    static let lookEvery: Duration = .seconds(900)

    /// Brings the conditions and the forecast up to date, then hands the
    /// widgets a fresh file.
    ///
    /// - `mayAsk`: whether Apple's location question may be shown if it
    ///   has never been answered. It makes no difference once it has.
    /// - `force`: fetch even if the reading held is under a quarter of
    ///   an hour old. Used by the "Check now" button.
    static func refresh(context: ModelContext, locationManager: LocationManager,
                        mayAsk: Bool, force: Bool = false) async {
        let gardens = (try? context.fetch(FetchDescriptor<Garden>())) ?? []
        // The example garden is used for unattended test runs, some of
        // them hidden. A question on screen with nobody there to answer
        // it would leave the run waiting, so it is never asked there.
        let mayAskHere = mayAsk && !DemoGarden.isRequested
        await WeatherService.shared.refresh(
            gardenAt: WeatherPlace.garden(among: gardens),
            deviceLocation: { await locationManager.currentLocation(mayAsk: mayAskHere)?.coordinate },
            force: force)
        // The forecast is in, or could not be had: either way the
        // widgets' file is brought up to date from the records.
        WidgetShare.refresh(context: context)
    }

    /// Saves where the device is now as a garden's place on the map.
    /// Used by the offer on Today's card when the weather came from the
    /// device because no garden was placed. Returns false if the device
    /// could not say where it is.
    ///
    /// Setting the place is all it does. MainTabView watches for a
    /// garden's place changing and fetches the weather and the weather
    /// diary for it at once.
    @discardableResult
    static func savePlace(for garden: Garden, locationManager: LocationManager) async -> Bool {
        guard let fix = await locationManager.currentLocation() else { return false }
        // Four decimal places is about ten metres, as in the garden editor.
        garden.latitude = WeatherPlace.rounded(fix.coordinate.latitude)
        garden.longitude = WeatherPlace.rounded(fix.coordinate.longitude)
        return true
    }
}
