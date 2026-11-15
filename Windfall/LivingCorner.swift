//
//  LivingCorner.swift
//  Windfall
//
//  The drawing in the top corner of Today, alive: it grows in when the
//  screen opens, sways with the wind, and the bee from the app icon
//  comes to feed. Tapping it calls the bee and pushes the sprig.
//
//  Three pieces:
//
//    - CornerEngine keeps track of what is going on from one moment to
//      the next (where the bee is, what is falling) and draws a frame.
//    - LivingCorner is the view. It asks the engine for a new frame
//      about thirty times a second.
//    - CornerPreviewView is the page in Settings for looking at every
//      month and every kind of weather.
//
//  What to show is decided in CornerScene.swift. The drawings
//  themselves are in CornerSprigs.swift.
//

import SwiftUI

// MARK: - The engine

/// Something small drifting down: a petal, a leaf or a snowflake.
private struct CornerDrift {
    enum Kind { case petal, leaf, snow }
    var kind: Kind
    var startsAt: Double
    var x: Double
    var y: Double
    var phase: Double
    var fill: CornerInk
}

/// Where a part ended up in the frame being drawn.
private struct CornerPlacing {
    var x = 0.0
    var y = 0.0
    var turn = 0.0
    var scaleNow = 0.0
    var isShown = false
}

/// What the bee is doing.
private enum CornerBeeMode {
    case away, arriving, feeding, hopping, leaving
}

/// Remembers what is happening in one corner drawing and draws it.
///
/// It is a class, not a struct, so that the one engine lives on while
/// the view around it is redrawn again and again.
final class CornerEngine {

    private var shownScene: CornerScene?
    private var sprig = CornerSprig()
    private var placings: [CornerPlacing] = []
    /// When the drawing started to grow in.
    private var bornAt: Double?
    private var lastFrameAt = 0.0
    private var isStill = false
    /// True in the Settings preview, where things happen sooner so
    /// there is something to see.
    private var isQuick = false

    private var drifts: [CornerDrift] = []
    private var rainDrops: [(startsAt: Double, x: Double)] = []
    private var rainOwed = 0.0
    private var snowOwed = 0.0
    private var fallAt: Double?
    private var hasFallen = false
    private var gustAt = -99.0
    private var nudgeAt = -99.0
    private var nudgeSize = 0.0
    private var nextMomentAt = 0.0

    private var beeMode = CornerBeeMode.away
    private var beeNextAt = 0.0
    private var beePartIndex: Int?
    private var beeQueue: [Int] = []
    private var beeFrom = CGPoint.zero
    private var beeTo = CGPoint.zero
    private var beeSince = 0.0
    private var beeFor = 1.0
    private var beeIsAsleep = false
    private var beePlace: CGPoint?

    private static let gridWidth = 150.0
    private static let gridHeight = 96.0
    /// For this many seconds after the drawing opens it counts as
    /// "just opened": a bee that is asleep is there from the start.
    private static let openingSeconds = 3.0
    /// In great heat the whole plant hangs over by this many degrees.
    private static let wiltDegrees = 5.0
    /// And each leaf turns this share of the way to hanging straight down.
    private static let leafDroopShare = 0.22

    private func random(_ low: Double, _ high: Double) -> Double { Double.random(in: low...high) }

    // MARK: Starting again

    private func replay(at time: Double) {
        bornAt = time
        drifts = []
        fallAt = nil
        hasFallen = false
        beeMode = .away
        beeIsAsleep = false
        beePartIndex = nil
        beeNextAt = time + (isQuick ? 2.4 : 4)
        nextMomentAt = time + (isQuick ? 3.2 : 6)
    }

    private func rebuild(for wantedScene: CornerScene) {
        sprig = CornerSprig.make(monthNumber: wantedScene.monthNumber, monthProgress: wantedScene.monthProgress)
        placings = Array(repeating: CornerPlacing(), count: sprig.parts.count)
    }

    // MARK: The wind

    /// How far the sprig leans at a moment, in degrees. Three slow waves
    /// of different lengths added together, so it never quite repeats.
    private func sway(_ time: Double) -> Double {
        guard !isStill, let showing = shownScene else { return 0 }
        let strength: Double
        switch showing.breeze {
        case .calm: strength = 0.7
        case .breeze: strength = 1.9
        case .gusty: strength = 4.0
        }
        var wave = 0.62 * sin(2 * .pi * time / 5.3) + 0.28 * sin(2 * .pi * time / 3.07 + 1.3) + 0.1 * sin(2 * .pi * time / 1.37 + 0.5)
        let gusts = showing.breeze == .gusty ? 1 + 0.9 * pow(max(0, sin(2 * .pi * time / 7.3)), 3) : 1
        let sinceGust = time - gustAt
        if sinceGust > 0 && sinceGust < 2.6 {
            wave += 1.6 * sin(.pi * sinceGust / 2.6) * (0.7 + 0.3 * sin(sinceGust * 5))
        }
        // A tap pushes the sprig, which swings back and settles: a wave
        // that dies away.
        let sinceTap = time - nudgeAt
        let push = sinceTap > 0 && sinceTap < 4 ? nudgeSize * exp(-1.7 * sinceTap) * sin(7.2 * sinceTap) : 0
        // In great heat the air is heavy and the plant hardly stirs.
        let stillness = showing.isWilting ? 0.45 : 1.0
        return strength * wave * gusts * stillness + (showing.breeze == .gusty ? 1.2 : 0) + push
    }

    /// Tapping the drawing. `across` is where the finger landed: 0 at
    /// the left edge, 1 at the right.
    func tap(across: Double) {
        let now = Date.now.timeIntervalSinceReferenceDate
        guard !isStill, let showing = shownScene, let bornAt, now - bornAt >= 1.6 else { return }
        nudgeAt = now
        nudgeSize = 3 + 2.5 * CornerMath.clamp(across) // a tap nearer the tip pushes harder
        if showing.beeIsAbout && beeMode == .away { beeNextAt = now + 0.35 }
        // A shake brings down the apple in October and a petal in spring.
        switch showing.moment {
        case .windfall where fallAt == nil && !hasFallen:
            fallAt = now
            hasFallen = true
        case .petal:
            nextMomentAt = now
        default:
            break
        }
    }

    // MARK: One frame

    func draw(in context: inout GraphicsContext, canvasSize: CGSize, time: Double,
              cornerScene: CornerScene, inks: CornerInks, isStill still: Bool, isQuick quick: Bool) {
        isStill = still
        isQuick = quick
        if shownScene?.monthNumber != cornerScene.monthNumber || bornAt == nil {
            rebuild(for: cornerScene)
            replay(at: time)
        } else if shownScene?.monthProgress != cornerScene.monthProgress {
            // The day changed: the same plant, a little further on.
            rebuild(for: cornerScene)
            if beeIsAsleep {
                // Asleep, it stays asleep. Its flower is found again
                // below, because the parts were all made afresh.
                beePartIndex = nil
            } else if beeMode != .away {
                beeMode = .away; beeNextAt = time + 1.2
            }
        }
        shownScene = cornerScene
        let frameGap = min(max(time - lastFrameAt, 0), 0.1)
        lastFrameAt = time

        let fit = min(canvasSize.width / CornerEngine.gridWidth, canvasSize.height / CornerEngine.gridHeight)
        context.scaleBy(x: fit, y: fit)
        let grown = still ? 99 : time - (bornAt ?? time)
        // The wind's lean, and in great heat a steady droop on top of
        // it. The droop is added here and not inside sway(), so that it
        // is there with Reduce Motion on, and so that hanging fruit,
        // which uses sway() to swing, still hangs straight down.
        let lean = sway(time) + (cornerScene.isWilting ? CornerEngine.wiltDegrees : 0)

        /// Where a point moves to when the wind bends the plant about
        /// its foot, and by how much it turned. Points further from the
        /// foot turn more, which is what makes it a bend and not a tilt.
        func bent(_ point: CGPoint, about foot: CGPoint) -> (point: CGPoint, turn: Double) {
            let dx = point.x - foot.x, dy = point.y - foot.y
            let turn = lean * CornerMath.degree * pow(hypot(dx, dy) / 80, 1.3)
            return (CGPoint(x: foot.x + dx * cos(turn) - dy * sin(turn), y: foot.y + dx * sin(turn) + dy * cos(turn)), turn)
        }

        // Stems, drawn from the base outwards as the screen opens.
        var bentStems: [(start: CGPoint, bend: CGPoint, end: CGPoint)] = []
        for stem in sprig.stems {
            let line = (bent(stem.start, about: stem.foot).point, bent(stem.bend, about: stem.foot).point, bent(stem.end, about: stem.foot).point)
            bentStems.append(line)
            let share = CornerMath.smooth((grown - stem.startsAt) / stem.takes)
            if share <= 0 || stem.isHidden { continue }
            var path = Path()
            path.move(to: line.0)
            path.addQuadCurve(to: CornerMath.point(line.0, line.1, line.2, share),
                              control: CGPoint(x: CornerMath.lerp(line.0.x, line.1.x, share), y: CornerMath.lerp(line.0.y, line.1.y, share)))
            context.stroke(path, with: .color(inks.lineInk.color(0.75)),
                           style: StrokeStyle(lineWidth: stem.lineWidth, lineCap: .round, lineJoin: .round))
        }

        // Parts.
        var shedders: [Int] = []
        /// Flowers open and fully grown: where the bee can land.
        var perches: [Int] = []
        /// The same flowers from the moment they first show, however
        /// small: where a sleeping bee already is as the drawing opens.
        var roosts: [Int] = []
        var beeIsDrawn = false
        for index in sprig.parts.indices {
            let sprigPart = sprig.parts[index]
            let stem = sprig.stems[sprigPart.stemIndex], line = bentStems[sprigPart.stemIndex]
            let base = CornerMath.point(line.start, line.bend, line.end, sprigPart.along)
            let grownSize = CornerMath.back((grown - sprigPart.startsAt) / 0.45)
            if grownSize <= 0.001 { placings[index].isShown = false; continue }

            let flutter = sway(time - 0.25 - sprigPart.along * 0.3) * 1.3 * sprigPart.flutter
            var degrees: Double
            if sprigPart.hangs {
                degrees = 90 + sprigPart.fan - sway(time - 0.45) * 1.7 * sprigPart.swing
            } else if sprigPart.turnsWithTip {
                degrees = sprigPart.angle + bent(stem.end, about: stem.foot).turn / CornerMath.degree
            } else if let relativeAngle = sprigPart.relativeAngle {
                degrees = CornerMath.heading(line.start, line.bend, line.end, sprigPart.along) / CornerMath.degree + relativeAngle + flutter
            } else {
                degrees = sprigPart.angle + bent(base, about: stem.foot).turn / CornerMath.degree + flutter
            }
            if cornerScene.isWilting && sprigPart.isLeaf {
                // A wilting leaf turns part of the way to pointing straight
                // down, which is 90 degrees here. The two loops find the
                // short way round, so it never swings over the top.
                var toDown = 90 - degrees
                while toDown > 180 { toDown -= 360 }
                while toDown < -180 { toDown += 360 }
                degrees += toDown * CornerEngine.leafDroopShare
            }
            placings[index] = CornerPlacing(x: base.x, y: base.y, turn: degrees * CornerMath.degree, scaleNow: grownSize, isShown: true)
            if sprigPart.sheds { shedders.append(index) }
            if sprigPart.perch != nil && sprigPart.isOpenEnoughForBee {
                roosts.append(index)
                if grownSize > 0.95 { perches.append(index) }
            }

            // The apple that drops: it falls faster and faster, turning,
            // and fades before the foot of the frame.
            var dropBy = 0.0, opacity = 1.0, spin = 0.0
            if sprigPart.isWindfall, let fallAt {
                let falling = time - fallAt
                dropBy = 0.5 * 190 * falling * falling
                spin = falling * 0.9
                opacity = CornerMath.clamp(1 - (base.y + dropBy - 62) / 26)
                if falling > 5.5 { self.fallAt = nil; sprig.parts[index].startsAt = grown }
                if opacity <= 0 { continue }
            } else if sprigPart.isWindfall && hasFallen && !isQuick {
                continue
            }

            // The bee goes behind a foxglove bell when it climbs in.
            if beeMode == .feeding && beePartIndex == index && sprigPart.beeClimbsIn {
                drawBee(in: &context, inks, time)
                beeIsDrawn = true
            }
            var g = context
            g.opacity = opacity
            g.translateBy(x: base.x, y: base.y + dropBy)
            g.rotate(by: .radians(degrees * CornerMath.degree + spin))
            g.scaleBy(x: grownSize, y: grownSize)
            CornerDraw.sprigPart(sprigPart, in: &g, inks)
        }

        // Frost: small stars that come and go along the sprig.
        if cornerScene.cornerSky == .frost {
            for index in stride(from: 0, to: placings.count, by: 2) where placings[index].isShown {
                let placing = placings[index]
                let twinkle = still ? 0.7 : pow(max(0, sin(time * 1.1 + Double(index) * 1.7)), 2)
                let x = placing.x + cos(placing.turn) * 4, y = placing.y + sin(placing.turn) * 4, reach = 3.1 * twinkle
                var star = Path()
                star.move(to: CGPoint(x: x - reach, y: y)); star.addLine(to: CGPoint(x: x + reach, y: y))
                star.move(to: CGPoint(x: x, y: y - reach)); star.addLine(to: CGPoint(x: x, y: y + reach))
                context.stroke(star, with: .color(inks.frost.color(0.95 * twinkle)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
            }
        }

        // With Reduce Motion on, that is the whole picture: the bee
        // sits on the flower and nothing drifts or falls.
        if still {
            if cornerScene.beeIsAbout, let first = perches.first {
                beePartIndex = first; beeMode = .feeding; beeSince = time; beeFor = .greatestFiniteMagnitude; beeIsAsleep = true
                drawBee(in: &context, inks, time)
            } else {
                beeMode = .away
            }
            return
        }

        drawDrifts(in: &context, inks, time, shedders: shedders, frameGap: frameGap)
        moveBee(time, perches: perches, roosts: roosts, grown: grown)
        if !beeIsDrawn { drawBee(in: &context, inks, time) }
    }

    // MARK: Petals, leaves, snow and rain

    private func drawDrifts(in context: inout GraphicsContext, _ inks: CornerInks, _ time: Double, shedders: [Int], frameGap: Double) {
        guard let showing = shownScene, let bornAt else { return }

        if time > nextMomentAt && time - bornAt > 2.2 {
            var wait = isQuick ? random(4.5, 7.5) : random(11, 20)
            switch showing.moment {
            case .petal where !shedders.isEmpty:
                for number in 0..<(showing.monthProgress > 0.7 ? 3 : 1) {
                    guard let from = shedders.randomElement() else { break }
                    var fill: CornerInk = \.petal
                    if case .flower(_, let flowerFill, _, _, _, _) = sprig.parts[from].cornerShape { fill = flowerFill }
                    drifts.append(CornerDrift(kind: .petal, startsAt: time + Double(number) * 0.5,
                                              x: placings[from].x + random(-5, 5), y: placings[from].y + random(-3, 3),
                                              phase: random(0, 6), fill: fill))
                }
            case .windfall:
                if fallAt == nil && !hasFallen {
                    fallAt = time
                    hasFallen = true
                    wait = 3
                } else if let from = shedders.randomElement() {
                    let leafInk: CornerInk = Bool.random() ? \CornerInks.amber : \CornerInks.rust
                    drifts.append(CornerDrift(kind: .leaf, startsAt: time, x: placings[from].x + 6, y: placings[from].y,
                                              phase: random(0, 6), fill: leafInk))
                    if isQuick { hasFallen = false }
                }
            // January's and December's flurry. Not in rain or great
            // heat, and not when it is really snowing, which has a
            // steady fall of its own below.
            case .snow where showing.cornerSky != .rain && showing.cornerSky != .snow && showing.cornerSky != .heat:
                for number in 0..<4 {
                    drifts.append(CornerDrift(kind: .snow, startsAt: time + Double(number) * 0.7, x: random(20, 145), y: -3,
                                              phase: random(0, 6), fill: \.frost))
                }
                wait = isQuick ? 3 : 8
            default:
                break
            }
            if showing.breeze != .calm && Double.random(in: 0...1) < 0.4 { gustAt = time + 0.4 }
            nextMomentAt = time + wait
        }

        if showing.cornerSky == .snow {
            // Real snow: about four new flakes a second, right across
            // the frame, however fast the screen is being redrawn. They
            // start a little to the left because the wind carries them
            // to the right as they fall.
            snowOwed += frameGap * 4
            while snowOwed >= 1 {
                snowOwed -= 1
                drifts.append(CornerDrift(kind: .snow, startsAt: time, x: random(-35, 150), y: -3, phase: random(0, 6), fill: \.frost))
            }
        }

        let carried: Double
        switch showing.breeze {
        case .calm: carried = 2
        case .breeze: carried = 7
        case .gusty: carried = 18
        }
        drifts.removeAll { time - $0.startsAt > ($0.kind == .snow ? 8 : 3.6) }
        for drift in drifts {
            let age = time - drift.startsAt
            if age < 0 { continue }
            let life = drift.kind == .snow ? 8.0 : 3.6
            let opacity = CornerMath.clamp(age * 4) * CornerMath.clamp((life - age) / 1.1)
            if drift.kind == .snow {
                let flake = CornerPaths.dot(drift.x + sin(age * 1.3 + drift.phase) * 4 + carried * age * 0.5, drift.y + age * 13, 1.15)
                context.fill(flake, with: .color(inks.frost.color(0.95 * opacity)))
                context.stroke(flake, with: .color(inks.lineInk.color(0.18 * opacity)), lineWidth: 0.4)
            } else {
                var g = context
                g.opacity = opacity
                g.translateBy(x: drift.x + sin(age * 2.2 + drift.phase) * 6 + carried * age, y: drift.y + age * 15 + age * age * 1.6)
                g.rotate(by: .radians(sin(age * 2.2 + drift.phase) * 1.1 + drift.phase))
                if drift.kind == .petal {
                    CornerDraw.paint(CornerPaths.oval(0, 0, 3.1, 2.3), in: &g, inks, fill: inks[keyPath: drift.fill], lineOpacity: 0.45, lineWidth: 0.7)
                } else {
                    CornerDraw.paint(CornerPaths.leaf(9, 0.3), in: &g, inks, fill: inks[keyPath: drift.fill], lineOpacity: 0.6, lineWidth: 0.8)
                }
            }
        }

        if showing.cornerSky == .heat {
            // Heat haze: five short wavy lines that rise slowly and fade.
            // Nothing is remembered from frame to frame. Where each line
            // is comes straight from the clock.
            for number in 0..<5 {
                let numbered = Double(number)
                /// 0 as a line starts at the foot of the frame, 1 as it ends.
                let risen = (time / 6 + numbered / 5).truncatingRemainder(dividingBy: 1)
                let x = 18 + numbered * 29 + sin(numbered * 2.4) * 6
                let y = 88 - risen * 62
                var haze = Path()
                for step in 0...6 {
                    let stepped = Double(step)
                    let point = CGPoint(x: x + sin(stepped * 1.05 + time * 1.8 + numbered) * 1.7, y: y - stepped * 2.6)
                    if step == 0 { haze.move(to: point) } else { haze.addLine(to: point) }
                }
                context.stroke(haze, with: .color(inks.amber.color(0.4 * sin(.pi * risen))),
                               style: StrokeStyle(lineWidth: 0.8, lineCap: .round, lineJoin: .round))
            }
        }

        if showing.cornerSky == .rain {
            // About thirty new drops a second, however fast the screen
            // is being redrawn.
            rainOwed += frameGap * 33
            while rainOwed >= 1 { rainOwed -= 1; rainDrops.append((time, random(-20, 150))) }
            rainDrops.removeAll { -6 + (time - $0.startsAt) * 150 > CornerEngine.gridHeight + 6 }
            var streaks = Path()
            for drop in rainDrops {
                let age = time - drop.startsAt, x = drop.x + age * 26, y = -6 + age * 150
                streaks.move(to: CGPoint(x: x, y: y)); streaks.addLine(to: CGPoint(x: x + 1.1, y: y + 5.5))
            }
            context.stroke(streaks, with: .color(inks.frost.color(inks.isDark ? 0.7 : 0.95)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
        } else {
            rainDrops.removeAll()
        }
    }

    // MARK: The bee

    /// Where the bee sits on a part, and which way it then faces.
    private func perchPlace(_ index: Int) -> (x: Double, y: Double, turn: Double) {
        let placing = placings[index]
        guard let perch = sprig.parts[index].perch else { return (placing.x, placing.y, placing.turn) }
        let x = perch.x * placing.scaleNow, y = perch.y * placing.scaleNow
        return (placing.x + x * cos(placing.turn) - y * sin(placing.turn),
                placing.y + x * sin(placing.turn) + y * cos(placing.turn),
                placing.turn + perch.headingDegrees * CornerMath.degree)
    }

    /// Decides the bee's next move. Its route is William's: in from the
    /// left, to each flower in turn from left to right, out to the
    /// right, and back in from the left after a wait.
    private func moveBee(_ time: Double, perches: [Int], roosts: [Int], grown: Double) {
        guard let showing = shownScene else { return }

        // Night: the bee is asleep in its flower, whatever the weather.
        if showing.beeSleeps {
            putBeeToBed(time, perches: perches, roosts: roosts, grown: grown)
            return
        }
        // Morning: it wakes where it slept and feeds for a moment. From
        // there the rules below carry on as on any day, so it flies off
        // properly and is never simply switched off.
        if beeIsAsleep {
            beeIsAsleep = false
            if beePartIndex != nil {
                beeMode = .feeding; beeSince = time; beeFor = random(2.4, 3.6); beeQueue = []
            } else {
                beeMode = .away; beeNextAt = time + 1
            }
        }

        let isAbout = showing.beeIsAbout
        if !isAbout || perches.isEmpty {
            if beeMode == .arriving || beeMode == .feeding { beeLeaves(time) }
            if beeMode == .away { return }
        }

        switch beeMode {
        case .away:
            if time < beeNextAt || grown < 2.2 || perches.isEmpty { return }
            var queue = perches.sorted { placings[$0].x < placings[$1].x }
            while queue.count > 3 { queue.remove(at: Int.random(in: 0..<queue.count)) }
            beePartIndex = queue.removeFirst()
            beeQueue = queue
            beeFrom = CGPoint(x: -8, y: random(10, 44))
            beeMode = .arriving; beeSince = time; beeFor = 2.1
        case .arriving, .hopping:
            if time - beeSince >= beeFor {
                let lingers = beePartIndex.map { sprig.parts[$0].beeLingers } ?? false
                beeMode = .feeding; beeSince = time; beeFor = lingers ? random(5.5, 8) : random(2.4, 3.6)
            }
        case .feeding:
            if time - beeSince >= beeFor {
                let waiting = beeQueue.filter { perches.contains($0) }
                if let next = waiting.first, let current = beePartIndex {
                    let here = perchPlace(current)
                    beeFrom = CGPoint(x: here.x, y: here.y)
                    beePartIndex = next
                    beeQueue = Array(waiting.dropFirst())
                    beeMode = .hopping; beeSince = time; beeFor = 1.0
                } else {
                    beeLeaves(time)
                }
            }
        case .leaving:
            if time - beeSince >= beeFor {
                beeMode = .away
                // William, 14 November: a random wait of 10 to 20 seconds.
                beeNextAt = time + (isQuick ? random(2.5, 5) : Double.random(in: CornerScene.beeWaitSeconds))
            }
        }
    }

    /// Night. Sees that the bee ends up asleep in its flower.
    ///
    /// When the drawing has only just opened, the bee is there already
    /// and grows in with its flower. If night falls while the drawing
    /// is open, the bee lands or stays where it is, and then sleeps. It
    /// is never simply switched on.
    private func putBeeToBed(_ time: Double, perches: [Int], roosts: [Int], grown: Double) {
        if beeIsAsleep {
            // Already asleep. If the drawing was made afresh for a new
            // day, find its flower again.
            if beePartIndex == nil { beePartIndex = roosts.first }
            return
        }
        switch beeMode {
        case .away:
            if grown < CornerEngine.openingSeconds {
                if let roost = roosts.first { beeBedsDown(on: roost, at: time) }
            } else if let landing = perches.first {
                // Night fell with the bee away: it flies in to bed.
                beePartIndex = landing
                beeQueue = []
                beeFrom = CGPoint(x: -8, y: random(10, 44))
                beeMode = .arriving; beeSince = time; beeFor = 2.1
            }
        case .arriving, .hopping:
            // In the air: it lands first.
            if time - beeSince >= beeFor, let index = beePartIndex { beeBedsDown(on: index, at: time) }
        case .feeding:
            // On a flower: it nods off where it is.
            if let index = beePartIndex { beeBedsDown(on: index, at: time) }
        case .leaving:
            // On its way out: it goes, and then flies in to bed.
            if time - beeSince >= beeFor { beeMode = .away }
        }
    }

    /// Puts the bee to sleep on a flower. `greatestFiniteMagnitude` is
    /// the largest number there is, so "sleep for this long" never ends
    /// by itself: only morning wakes it.
    private func beeBedsDown(on index: Int, at time: Double) {
        beePartIndex = index
        beeQueue = []
        beeMode = .feeding; beeSince = time; beeFor = .greatestFiniteMagnitude; beeIsAsleep = true
    }

    private func beeLeaves(_ time: Double) {
        if let beePlace {
            beeFrom = beePlace
        } else if let index = beePartIndex, placings.indices.contains(index) {
            let here = perchPlace(index)
            beeFrom = CGPoint(x: here.x, y: here.y)
        }
        beeTo = CGPoint(x: CornerEngine.gridWidth + 9, y: random(4, 34))
        beeMode = .leaving; beeSince = time; beeFor = 1.7
    }

    /// Turns from one direction to another the short way round.
    private func turned(from: Double, to: Double, by share: Double) -> Double {
        var gap = to - from
        while gap > .pi { gap -= 2 * .pi }
        while gap < -.pi { gap += 2 * .pi }
        return from + gap * CornerMath.smooth(share)
    }

    private func drawBee(in context: inout GraphicsContext, _ inks: CornerInks, _ time: Double) {
        guard beeMode != .away, let index = beePartIndex, placings.indices.contains(index), placings[index].isShown else { return }
        let sprigPart = sprig.parts[index]
        /// How far its flower has grown in: 1 once the drawing is open.
        let flowerSize = placings[index].scaleNow
        var seat = perchPlace(index)
        if !sprigPart.perchIsExact { // its front, not its middle, meets the flower
            seat.x -= cos(seat.turn) * 3.5 * flowerSize
            seat.y -= sin(seat.turn) * 3.5 * flowerSize
        }
        let share = CornerMath.clamp((time - beeSince) / beeFor)
        var x = seat.x, y = seat.y, turn = seat.turn, isFlying = true
        if beeMode == .feeding {
            isFlying = false
            if sprigPart.beeClimbsIn {
                // Feeding, it climbs into the bell and backs out again.
                // Asleep, it stays tucked half way in, its back end showing.
                let reach = sprigPart.bellLength * 0.75 + 4
                let inside = beeIsAsleep ? reach * 0.5 * flowerSize : sin(.pi * share) * reach
                x += cos(seat.turn) * inside; y += sin(seat.turn) * inside
            } else if !beeIsAsleep { // a small bob as it feeds
                x += cos(seat.turn) * sin(time * 7) * 0.3; y += sin(seat.turn) * sin(time * 7) * 0.3
            }
        } else {
            let leaving = beeMode == .leaving, hopping = beeMode == .hopping
            let to = leaving ? beeTo : CGPoint(x: seat.x, y: seat.y)
            // Leaving it gathers speed. Arriving it slows down.
            let eased = leaving ? share * share : 1 - (1 - share) * (1 - share)
            let over = CGPoint(x: (beeFrom.x + to.x) / 2, y: min(beeFrom.y, to.y) - (hopping ? 9 : 12))
            let onPath = CornerMath.point(beeFrom, over, to, eased)
            let wobble = beeMode == .arriving ? 1 - eased : (leaving ? eased : 0.4)
            x = onPath.x + sin(time * 9) * 2 * wobble
            y = onPath.y + cos(time * 11) * 1.6 * wobble
            // It points the way it is flying, and turns to the way it
            // will sit as it lands.
            turn = CornerMath.heading(beeFrom, over, to, min(max(eased, 0.02), 0.98))
            if !leaving && eased > 0.7 { turn = turned(from: turn, to: seat.turn, by: (eased - 0.7) / 0.3) }
        }
        beePlace = CGPoint(x: x, y: y)
        var g = context
        // It fades at the frame's edges so it does not pop in or out.
        g.opacity = isFlying ? CornerMath.clamp(min(x + 8, CornerEngine.gridWidth + 8 - x) / 12) : 1
        g.translateBy(x: x, y: y)
        g.rotate(by: .radians(turn))
        // Asleep as the drawing opens, it grows in with its flower.
        if beeIsAsleep { g.scaleBy(x: flowerSize, y: flowerSize) }
        CornerDraw.bee(in: &g, inks, isFlying: isFlying, time: time)
    }
}

// MARK: - The view

extension EnvironmentValues {
    /// True while something is drawn over the page the corner drawing
    /// is on, such as a sheet. Today sets it. The drawing then rests,
    /// because nobody can see it move.
    ///
    /// `@Entry` makes a new setting that a view can hand down to
    /// everything inside it with `.environment(\.cornerIsCovered, true)`.
    @Entry var cornerIsCovered = false
}

/// The living drawing. Give it a scene and a frame to fill. It keeps the
/// drawing's shape of 150 wide to 96 high inside whatever it is given.
///
/// When it rests. Drawing a new picture thirty times a second is the
/// most costly thing Windfall does while nobody is touching it. On
/// 15 November 2026 a Mac with a web browser in front of Windfall was
/// measured spending a sixth to a quarter of one processor core on this
/// drawing alone. So it holds still whenever it cannot be seen moving:
/// see `isResting`. It picks up again by itself the moment it can.
struct LivingCorner: View {

    let cornerScene: CornerScene
    /// True in the Settings preview: the bee and the falling things come
    /// sooner, and the apple grows back.
    var isQuick = false

    /// @State keeps the one engine alive while this view is redrawn.
    @State private var engine = CornerEngine()
    /// False once the page this drawing is on has left the screen: when
    /// another page slides over it, or another tab is chosen. SwiftUI
    /// says so through `onAppear` and `onDisappear` below.
    @State private var isOnScreen = true
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.cornerIsCovered) private var isCovered
    #if os(macOS)
    // On a Mac a window stays "active" in `scenePhase` for as long as it
    // is open, even with another app in front of it. `appearsActive` is
    // the Mac's own word for "this is the window in use": it turns
    // false when another app, or another of Windfall's windows, is in
    // front.
    @Environment(\.appearsActive) private var appearsActive
    #endif

    /// True whenever the drawing should hold still: Reduce Motion is on,
    /// the app has been put away, its page is off the screen or covered,
    /// or (on a Mac) its window is not the one in use.
    private var isResting: Bool {
        if reduceMotion || scenePhase != .active || !isOnScreen || isCovered { return true }
        #if os(macOS)
        if !appearsActive { return true }
        #endif
        return false
    }

    var body: some View {
        let inks = colorScheme == .dark ? CornerInks.dark : CornerInks.light
        GeometryReader { geometry in
            // TimelineView redraws what is inside it again and again:
            // here up to thirty times a second, and not at all while
            // the drawing is resting. A paused TimelineView keeps the
            // last picture it drew on screen.
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: isResting)) { timeline in
                Canvas { context, size in
                    CornerMeter.shared.tick()
                    engine.draw(in: &context, canvasSize: size, time: timeline.date.timeIntervalSinceReferenceDate,
                                cornerScene: cornerScene, inks: inks, isStill: reduceMotion, isQuick: isQuick)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in
                engine.tap(across: location.x / max(geometry.size.width, 1))
            }
        }
        .aspectRatio(150.0 / 96.0, contentMode: .fit)
        // It is decoration: VoiceOver passes over it.
        .accessibilityHidden(true)
        .onAppear { isOnScreen = true }
        .onDisappear { isOnScreen = false }
    }
}

// MARK: - A checking aid

/// Counts how many times a second the corner is drawn, and writes the
/// count to a file. Switched on by starting the app with
/// `-cornerMeter YES`. It is how the resting above is proved: a second
/// in which nothing was drawn writes no line, so a gap in the file's
/// times is a rest. The file is `windfall-corner-meter.txt` in the
/// app's temporary folder. With the switch off it does nothing.
final class CornerMeter {
    static let shared = CornerMeter()
    private let isOn = UserDefaults.standard.bool(forKey: "cornerMeter")
    private var draws = 0
    private var since = Date.now
    private let file = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("windfall-corner-meter.txt")

    func tick() {
        guard isOn else { return }
        let now = Date.now
        let passed = now.timeIntervalSince(since)
        // After a rest, start counting afresh, so the long gap is not
        // averaged into the first second back.
        if passed > 2 { draws = 0; since = now; return }
        draws += 1
        guard passed >= 1 else { return }
        let line = "\(now.formatted(date: .omitted, time: .standard)): \(draws) draws in the last second\n"
        if let handle = try? FileHandle(forWritingTo: file) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? Data(line.utf8).write(to: file)
        }
        draws = 0
        since = now
    }
}

extension CornerScene {

    /// Checking aids, for taking pictures of the corner in a state the
    /// day does not offer. Launch arguments, each optional:
    /// `-cornerMonth 2 -cornerDay 20 -cornerWind gusty -cornerSky rain`.
    /// `-cornerNight YES` makes it night under whatever the sky is, for
    /// a wet or frosty night. With none given the scene comes back
    /// unchanged.
    func withCheckingAids() -> CornerScene {
        let defaults = UserDefaults.standard
        var changed = self
        let month = defaults.integer(forKey: "cornerMonth")
        if (1...12).contains(month) { changed.monthNumber = month }
        let day = defaults.integer(forKey: "cornerDay")
        if (1...31).contains(day) { changed.monthProgress = CornerScene.progress(day: day, daysInMonth: 30) }
        if let wind = defaults.string(forKey: "cornerWind").flatMap(CornerWind.init(rawValue:)) { changed.breeze = wind }
        if let chosenSky = defaults.string(forKey: "cornerSky").flatMap(CornerWeather.init(rawValue:)) { changed.cornerSky = chosenSky }
        if defaults.object(forKey: "cornerNight") != nil { changed.isNight = defaults.bool(forKey: "cornerNight") }
        return changed
    }
}

// MARK: - The preview in Settings

/// A page for seeing every month's drawing and trying the wind and the
/// weather. Nothing chosen here changes Today, which always reads the
/// real date and the real weather.
struct CornerPreviewView: View {

    @State private var monthNumber: Int
    @State private var dayOfMonth: Double
    @State private var breeze: CornerWind
    @State private var cornerSky: CornerWeather
    /// Counts presses of "Open it again". Changing it makes SwiftUI
    /// throw the drawing away and make a new one, which grows in afresh.
    @State private var timesOpened = 0

    private static let monthNames = ["January", "February", "March", "April", "May", "June",
                                     "July", "August", "September", "October", "November", "December"]
    private static let monthLengths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    init() {
        let nowParts = Calendar.current.dateComponents([.month, .day], from: .now)
        let firstScene = CornerScene(monthNumber: nowParts.month ?? 1, monthProgress: 0.5).withCheckingAids()
        _monthNumber = State(initialValue: firstScene.monthNumber)
        let chosenDay = UserDefaults.standard.integer(forKey: "cornerDay")
        _dayOfMonth = State(initialValue: Double((1...31).contains(chosenDay) ? chosenDay : (nowParts.day ?? 15)))
        _breeze = State(initialValue: firstScene.breeze)
        _cornerSky = State(initialValue: firstScene.cornerSky)
    }

    private var daysInMonth: Int { CornerPreviewView.monthLengths[monthNumber - 1] }
    private var shownDay: Int { min(Int(dayOfMonth), daysInMonth) }

    private var shownScene: CornerScene {
        CornerScene(monthNumber: monthNumber,
                    monthProgress: CornerScene.progress(day: shownDay, daysInMonth: daysInMonth),
                    breeze: breeze, cornerSky: cornerSky)
    }

    /// One line on what the bee is doing and why.
    private var beeLine: String {
        let showing = shownScene
        if !showing.hasBee { return monthNumber == 10 ? "No bee this month. The falling apple is October's moment." : "The bee is asleep underground." }
        if showing.beeSleeps { return "At night the bee sleeps in its flower, whatever the weather. A tap does not wake it." }
        if cornerSky == .rain { return "It is raining, so the bee stays away." }
        if cornerSky == .snow { return "It is snowing, so the bee stays away." }
        if cornerSky == .frost { return "It is frosty, so the bee stays away." }
        if cornerSky == .heat { return "It is too hot for the bee to fly. The plant wilts." }
        if breeze == .gusty { return "It is too windy for the bee to fly." }
        return "The bee comes in from the left and leaves to the right. Tap the drawing to call it."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Corner drawing", detail: "Every month and every kind of weather")

                VStack(alignment: .leading, spacing: 6) {
                    LivingCorner(cornerScene: shownScene, isQuick: true)
                        .id(timesOpened)
                        .frame(maxWidth: 480)
                        .frame(maxWidth: .infinity)
                    Text("\(CornerPreviewView.monthNames[monthNumber - 1]): \(shownScene.plantName.lowercased())")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(shownScene.plantNote)
                        .font(.body)
                        .foregroundStyle(Theme.inkSoft)
                    Text(beeLine)
                        .font(.body)
                        .foregroundStyle(Theme.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Month")
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Picker("Month", selection: $monthNumber) {
                            ForEach(1...12, id: \.self) { number in
                                Text(CornerPreviewView.monthNames[number - 1]).tag(number)
                            }
                        }
                        .labelsHidden()
                        .tint(Theme.leaf)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Day \(shownDay) of \(daysInMonth)")
                            .foregroundStyle(Theme.ink)
                        Slider(value: $dayOfMonth, in: 1...31, step: 1)
                            .tint(Theme.leaf)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Wind")
                            .foregroundStyle(Theme.ink)
                        GlassSwitch(choices: CornerWind.allCases, selection: $breeze) { $0.label }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Weather")
                            .foregroundStyle(Theme.ink)
                        GlassSwitch(choices: CornerWeather.allCases, selection: $cornerSky) { $0.label }
                    }
                    Button("Open it again") { timesOpened += 1 }
                        .buttonStyle(.bordered)
                        .tint(Theme.leaf)
                }
                .glassCard()

                Text("All twelve")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                    ForEach(1...12, id: \.self) { number in
                        Button {
                            monthNumber = number
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                LivingCorner(cornerScene: CornerScene(monthNumber: number, monthProgress: 0.5, breeze: breeze, cornerSky: cornerSky),
                                             isQuick: true)
                                    // A tap on a tile chooses its month, so
                                    // the drawing inside does not take it.
                                    .allowsHitTesting(false)
                                Text(CornerPreviewView.monthNames[number - 1])
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                Text(CornerScene.plantNames[number - 1])
                                    .font(.footnote)
                                    .foregroundStyle(Theme.inkSoft)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard(padding: 12)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(CornerPreviewView.monthNames[number - 1]), \(CornerScene.plantNames[number - 1])")
                    }
                }

                Text("This page is only for looking. On Today the drawing follows the real date and the weather for your garden, with nothing to set up. With no weather to go on it shows a light breeze on a fine day. Here things happen sooner than on Today, where the bee waits 10 to 20 seconds between visits.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .paperScreen()
        .navigationTitle("Corner drawing")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .eiraLooksAt("a preview of the drawing in Today's corner", short: "the corner drawing")
    }
}
