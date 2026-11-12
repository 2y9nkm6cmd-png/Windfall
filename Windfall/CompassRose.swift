//
//  CompassRose.swift
//  Windfall
//
//  A small, simple compass, and the device's own compass behind it.
//
//  Two parts:
//
//    CompassHeading   asks the iPhone or iPad which way it is pointing
//    CompassRose      draws the compass: a ring, four marks and a needle
//
//  A Mac has no compass. There the rose still shows where north is on a
//  garden plan, and stays still.
//
//  ⚠️ CHECK: the live compass cannot be tried on a Mac or in the
//  simulator, because neither has one. It was written from Apple's
//  documentation and needs testing on a real iPhone or iPad.
//

import SwiftUI
import CoreLocation
import Observation

// MARK: - The device's compass

@Observable
@MainActor
final class CompassHeading: NSObject {

    /// The compass bearing the top of the device is pointing at, in
    /// degrees: 0 north, 90 east. Nil until the first reading arrives, and
    /// always nil on a device with no compass.
    private(set) var degrees: Double?

    // Everything between #if os(iOS) and #endif is only built for iPhone
    // and iPad. The Mac version of the app never sees it, because Apple
    // does not offer these compass calls on the Mac.
    #if os(iOS)

    /// True on a device that has a compass.
    var isAvailable: Bool { CLLocationManager.headingAvailable() }

    private let manager = CLLocationManager()
    private var listeners = 0

    override init() {
        super.init()
        manager.delegate = self
        // Only report a change of two degrees or more, to save battery
        // and stop the needle trembling.
        manager.headingFilter = 2
    }

    /// Starts the compass. Each `start` must be matched by a `stop`, so
    /// the compass is switched off when no screen is using it.
    func start() {
        guard isAvailable else { return }
        listeners += 1
        if listeners == 1 {
            matchScreenTurn()
            manager.startUpdatingHeading()
        }
    }

    func stop() {
        guard listeners > 0 else { return }
        listeners -= 1
        if listeners == 0 {
            manager.stopUpdatingHeading()
            degrees = nil
        }
    }

    /// The compass measures from the top of the device as held upright.
    /// If the screen is turned on its side, this tells it so, or every
    /// reading would be a quarter turn out.
    private func matchScreenTurn() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        switch scene?.effectiveGeometry.interfaceOrientation {
        case .landscapeLeft: manager.headingOrientation = .landscapeRight
        case .landscapeRight: manager.headingOrientation = .landscapeLeft
        case .portraitUpsideDown: manager.headingOrientation = .portraitUpsideDown
        default: manager.headingOrientation = .portrait
        }
    }

    fileprivate func received(_ heading: Double) {
        matchScreenTurn()
        degrees = heading
    }

    #else

    /// A Mac has no compass, so there is nothing to start or stop.
    var isAvailable: Bool { false }
    func start() {}
    func stop() {}

    #endif
}

#if os(iOS)
extension CompassHeading: CLLocationManagerDelegate {

    // nonisolated because CoreLocation calls this from its own context.
    // It hops back to the main actor before touching anything on screen.
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // True north needs to know where you are. Without that the
        // reading is below zero, and magnetic north is used instead. In
        // Britain the two are within a couple of degrees of each other.
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in
            self.received(heading)
        }
    }
}
#endif

// MARK: - The drawing

/// A simple compass: a ring, a mark at each quarter and a needle whose
/// coloured end points north.
///
/// `north` is where north lies on the screen, in degrees clockwise from
/// straight up. 0 draws the needle pointing up.
struct CompassRose: View {

    var north: Double
    var size: CGFloat = 34
    /// True while the rose is following the device's compass.
    var isLive = false

    /// The angle actually drawn. It is allowed to run past 360, so that
    /// going from 350 degrees to 10 turns the needle 20 degrees forwards
    /// and not 340 degrees backwards.
    @State private var drawn: Double?

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isLive ? Theme.leaf : Theme.hairline, lineWidth: isLive ? 1.6 : 1.2)

            // Everything inside the ring turns together.
            ZStack {
                // A short mark at east, south and west.
                ForEach([90.0, 180.0, 270.0], id: \.self) { angle in
                    Capsule()
                        .fill(Theme.inkSoft)
                        .frame(width: 1.2, height: size * 0.10)
                        .offset(y: -size * 0.36)
                        .rotationEffect(.degrees(angle))
                }
                // The needle: a slim diamond, coloured at the north end.
                NeedleHalf()
                    .fill(Theme.leaf)
                    .frame(width: size * 0.20, height: size * 0.36)
                    .offset(y: -size * 0.18)
                NeedleHalf()
                    .fill(Theme.hairline)
                    .frame(width: size * 0.20, height: size * 0.36)
                    .rotationEffect(.degrees(180))
                    .offset(y: size * 0.18)
                Text("N")
                    .font(.system(size: size * 0.24, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .offset(y: -size * 0.66)
            }
            .rotationEffect(.degrees(drawn ?? north))
        }
        .frame(width: size, height: size)
        // Leaves room above the ring for the letter N as it goes round.
        .padding(size * 0.34)
        // A real needle swings a little past and settles. This spring
        // does the same each time the bearing changes.
        .animation(.spring(duration: 0.5, bounce: 0.35), value: drawn)
        .onAppear { drawn = north }
        .onChange(of: north) { _, new in
            let from = drawn ?? new
            // The shortest way round from where the needle is now.
            var step = (new - from).truncatingRemainder(dividingBy: 360)
            if step > 180 { step -= 360 }
            if step < -180 { step += 360 }
            drawn = from + step
        }
        .accessibilityElement()
        .accessibilityLabel("Compass")
        .accessibilityValue(isLive ? "Following the device. North is \(Self.words(for: north))."
                                   : "North is \(Self.words(for: north)) on the plan.")
    }

    /// "up", "to the right" and so on, for VoiceOver.
    private static func words(for north: Double) -> String {
        switch Compass.name(forBearing: north) {
        case "north": return "up"
        case "north-east": return "up and to the right"
        case "east": return "to the right"
        case "south-east": return "down and to the right"
        case "south": return "down"
        case "south-west": return "down and to the left"
        case "west": return "to the left"
        default: return "up and to the left"
        }
    }
}

/// One half of the compass needle: a tall, thin triangle.
private struct NeedleHalf: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
