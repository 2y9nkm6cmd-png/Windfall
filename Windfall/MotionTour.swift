//
//  MotionTour.swift
//  Windfall
//
//  A checking aid for anything that moves.
//
//  A still picture cannot show whether an animation is steady. This
//  presses Eira's snowdrop and changes place by itself, on a fixed
//  timetable, so that a film of the simulator can be taken and looked
//  at one frame at a time. (William, 15 November 2026: "a bit of
//  instability in the animations of the Eira movements, search bar
//  appearing and transitioning between screens".)
//
//  It does nothing unless the app is started with the example garden
//  and a tour is named:
//
//      -demoGarden YES -motionTour bar       Eira's bar opens and closes
//      -demoGarden YES -motionTour places    one place after another
//      -demoGarden YES -motionTour panel     her chat rises and sinks
//      -demoGarden YES -motionTour all       all three, in that order
//
//  `-motionTourWait 8` changes how many seconds pass before it begins
//  (5 unless told).
//
//  How it reaches the screens: it posts a notification, a message that
//  any part of the app can listen for. Eira's bar listens for
//  `MotionTour.bar` and MainTabView for `MotionTour.place`. Each then
//  runs the very code a tap would run, so the film shows what a finger
//  would see.
//

import Foundation

enum MotionTour {

    /// Sent to Eira's bar. Its `object` is one word: "toggle" presses
    /// the snowdrop, "eira" opens her chat and "done" lowers the panel.
    static let bar = Notification.Name("windfallMotionTourBar")
    /// Sent to MainTabView. Its `object` is the place to go to, by its
    /// raw name: "today", "journal" and so on.
    static let place = Notification.Name("windfallMotionTourPlace")

    /// The tour asked for, if any. (Named `tourAsked`, not `name`: the
    /// project's cross-file check goes by names, and read every other
    /// `name` in the app as this one.)
    static var tourAsked: String? {
        DemoGarden.isRequested ? UserDefaults.standard.string(forKey: "motionTour") : nil
    }

    /// Runs the tour that was asked for. MainTabView calls this once,
    /// when the example garden has been filled.
    static func runIfAsked() async {
        guard let tour = tourAsked else { return }
        let wait = UserDefaults.standard.double(forKey: "motionTourWait")
        await pause(wait > 0 ? wait : 5)
        switch tour {
        case "bar": await barTour()
        case "places": await placesTour()
        case "panel": await panelTour()
        default:
            await barTour()
            await placesTour()
            await panelTour()
        }
    }

    // MARK: The tours

    /// Open, wait for the sway to die away, close. Then twice more with
    /// the close pressed early: once while the snowdrop is still on its
    /// way across, and once during the bump against the sidebar.
    private static func barTour() async {
        press("toggle"); await pause(4.2)
        press("toggle"); await pause(2.5)
        press("toggle"); await pause(0.25)
        press("toggle"); await pause(2.5)
        press("toggle"); await pause(1.0)
        press("toggle"); await pause(2.5)
    }

    /// To the Journal and back (the bar opens by itself there), then
    /// through some other places, the last two in quick succession.
    private static func placesTour() async {
        for (place, seconds) in [("journal", 2.2), ("today", 2.2), ("gardens", 2.0), ("wildlife", 2.0),
                                 ("journal", 2.0), ("gardens", 0.12), ("today", 2.2)] {
            go(to: place); await pause(seconds)
        }
    }

    /// The bar opens, her chat rises out of it, "Done" lowers it and
    /// the bar closes.
    private static func panelTour() async {
        press("toggle"); await pause(1.8)
        press("eira"); await pause(3.0)
        press("done"); await pause(1.6)
        press("toggle"); await pause(2.5)
    }

    // MARK: The small pieces

    private static func press(_ what: String) {
        NotificationCenter.default.post(name: bar, object: what)
    }

    private static func go(to place: String) {
        // The message is named on a line of its own because the
        // project's cross-file check, which goes by names, took
        // "name:" followed by "MotionTour" for a value of this type.
        let message = MotionTour.place
        NotificationCenter.default.post(name: message, object: place)
    }

    private static func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }
}
