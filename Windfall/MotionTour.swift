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
//      -demoGarden YES -motionTour measure   every place twice over, then
//                                            the bar and the panel, with
//                                            every frame timed (see below)
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

//  Measuring (15 November 2026). A film of the simulator shows the
//  order things happen in, but the simulator draws glass slowly, so it
//  cannot say how long the real iPad stands still when a place is
//  chosen. The "measure" tour times that on the device itself. See
//  `FrameWatch` at the foot of this file. Its report is printed, each
//  line beginning MOTION, and is read on the Mac with
//  `devicectl device process launch --console`.
//

import Foundation
#if os(iOS)
import QuartzCore
#endif

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
        case "measure": await measureTour()
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

    /// Every place twice over, each time from Today and back, then the
    /// bar and the panel, with every frame timed. The second round
    /// shows whether a place is quicker once it has been seen.
    private static func measureTour() async {
        FrameWatch.shared.start()
        await pause(1.0)
        for round in 1...2 {
            for place in ["journal", "gardens", "year", "plants", "wildlife", "identify", "more"] {
                FrameWatch.shared.mark("round \(round) today>\(place)")
                go(to: place); await pause(2.4)
                FrameWatch.shared.mark("round \(round) \(place)>today")
                go(to: "today"); await pause(2.4)
            }
        }
        FrameWatch.shared.mark("bar opens"); press("toggle"); await pause(2.6)
        FrameWatch.shared.mark("panel rises"); press("eira"); await pause(3.0)
        FrameWatch.shared.mark("panel sinks"); press("done"); await pause(2.0)
        FrameWatch.shared.mark("bar closes"); press("toggle"); await pause(2.4)
        FrameWatch.shared.mark("end")
        for line in FrameWatch.shared.report() { print(line) }
        // What an app prints is saved up and sent in batches. `fflush`
        // sends it now, so the Mac that is listening gets the report
        // while the app is still open.
        fflush(stdout)
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

// MARK: - Timing every frame

/// Notes when each frame of the screen is due, so that a stall can be
/// measured: a stretch in which the app was too busy to draw.
///
/// How it works. A `CADisplayLink` is a timer that the screen itself
/// drives: it calls `tick` once for every frame the screen is about to
/// show, 60 times a second on an iPad mini. It calls on the app's main
/// thread, the one thread that builds and lays out every screen. While
/// that thread is busy building a page, `tick` cannot be called, so a
/// long wait between two ticks is a stall, and its length is how long
/// the picture stood still.
///
/// What it cannot see: time the graphics chip spends on blur and glass
/// after the app has handed a frame over. That would show as a slow or
/// jerky melt with no stall recorded here.
///
/// It runs only for the "measure" tour, on an iPhone or iPad. On a Mac
/// it does nothing: a Mac's screen timer is reached a different way,
/// and the question was about the iPad.
final class FrameWatch: NSObject {

    static let shared = FrameWatch()

    /// A moment worth timing from: "round 1 today>journal".
    private var marks: [(label: String, at: Double)] = []
    /// Every wait between two ticks that was longer than a frame and a
    /// half: when it began and how long it lasted, in seconds.
    private var stalls: [(began: Double, lasted: Double)] = []
    /// When the last tick came.
    private var lastTick: Double = 0
    /// How long one frame lasts on this screen, in seconds.
    private var frame: Double = 1.0 / 60

    #if os(iOS)
    private var link: CADisplayLink?

    func start() {
        guard link == nil else { return }
        let made = CADisplayLink(target: self, selector: #selector(tick(_:)))
        // `.common` keeps it ticking while a list is being scrolled.
        made.add(to: .main, forMode: .common)
        link = made
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = CACurrentMediaTime()
        frame = max(link.targetTimestamp - link.timestamp, 1.0 / 120)
        if lastTick > 0, now - lastTick > frame * 1.5 {
            stalls.append((began: lastTick, lasted: now - lastTick))
        }
        lastTick = now
    }

    func mark(_ label: String) {
        marks.append((label: label, at: CACurrentMediaTime()))
    }
    #else
    func start() {}
    func mark(_ label: String) {}
    #endif

    /// One line for each mark, saying what happened between it and the
    /// next one:
    ///
    /// - `first`: the stall that was under way when the mark was made
    ///   or began within two frames of it. For a change of place this
    ///   is the new page being built.
    /// - `longest`: the longest stall of all in that stretch.
    /// - `lost`: every stall added up, less the one frame each would
    ///   have taken anyway.
    /// - `stalls`: how many there were, then each one as "+when:length"
    ///   in thousandths of a second, counted from the mark.
    ///
    /// A stall is given to the mark it began after. The stall a mark
    /// sets off begins at the tick just before the mark, which is why
    /// the sum reaches back a frame and a half.
    func report() -> [String] {
        func ms(_ seconds: Double) -> String { String(Int((seconds * 1000).rounded())) }
        var lines = ["MOTION REPORT one frame is \(ms(frame))ms, a stall is any wait over \(ms(frame * 1.5))ms"]
        for (index, moment) in marks.enumerated() where index + 1 < marks.count {
            // (Named `moment`, not `mark`: the cross-file check took
            // `mark` for a mark on the garden drawing.)
            let until = marks[index + 1].at
            let mine = stalls.filter { $0.began >= moment.at - frame * 1.5 && $0.began < until - frame * 1.5 }
            let first = mine.first(where: { $0.began <= moment.at + frame * 2 })?.lasted ?? 0
            let longest = mine.map(\.lasted).max() ?? 0
            let lost = mine.reduce(0) { $0 + $1.lasted - frame }
            let each = mine.map { "+\(ms(max($0.began - moment.at, 0))):\(ms($0.lasted))" }.joined(separator: " ")
            lines.append("MOTION \(moment.label): first \(ms(first))ms, longest \(ms(longest))ms, lost \(ms(lost))ms, stalls \(mine.count) [\(each)]")
        }
        lines.append("MOTION END")
        return lines
    }
}
