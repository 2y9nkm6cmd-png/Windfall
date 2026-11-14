//
//  TodayBoard.swift
//  Windfall
//
//  The parts of the Today screen that let its cards be rearranged the
//  way icons are on an iPhone or iPad Home Screen:
//
//    press and hold a card      they all start to jiggle, and the card
//                               under the finger lifts
//    carry it about             it stays under the finger, and the other
//                               cards step aside to show where it would go
//    let go                     it settles into the space that opened
//
//  Until 14 November 2026 this was done with the system's "drag and
//  drop", the thing that carries a photo from one app to another. That
//  moves a small label, not the card, and nothing happens on the page
//  until the label is let go. William: "the rearranging doesn't feel as
//  natural as rearranging an iPad or iPhone home screen, which is more
//  the feel I was after." So the carrying is now done here, by hand.
//
//  Four pieces:
//
//    ArrangeSession      what is going on right now: which card is in
//                        the hand and where the finger is
//    TodayBoardLayout    puts every card where the arrangement says,
//                        except the one in the hand
//    BoardCard           wraps one card: the press and hold, the lift
//                        and the jiggle
//    Jiggle              the rocking
//
//  The sums for where things go are in TodayLayout.swift
//  (`TodayBoardPlan`), away from the drawing, so they can be tested
//  without a screen.
//

import SwiftUI

// MARK: - Names and timings

enum TodayBoard {
    /// The name of the page's own set of coordinates. The finger's
    /// position is measured in these: points from the top left corner of
    /// the part of the window that Today fills.
    static let pageSpace = "todayPage"

    /// How long a press must be held before the cards start to jiggle.
    /// The Home Screen's is about half a second.
    static let holdToBegin = 0.45

    /// Once they are jiggling, how long before a touched card lifts. A
    /// finger needs a moment, so that a quick swipe still scrolls the
    /// page. A mouse pointer needs none.
    #if os(macOS)
    static let holdToLift = 0.01
    #else
    static let holdToLift = 0.15
    #endif

    /// How long the finger must rest over a new place before the other
    /// cards make room. Without it they would shuffle about as a card
    /// is carried quickly across the page.
    static let dwell = Duration.milliseconds(110)

    /// How the other cards move aside, and how a card settles when it is
    /// let go. A spring is an animation that moves like a weight on a
    /// spring: `response` is roughly how long it takes, and a
    /// `dampingFraction` under 1 lets it overshoot a touch and come back.
    static let shuffle = Animation.spring(response: 0.42, dampingFraction: 0.86)
    static let settle = Animation.spring(response: 0.36, dampingFraction: 0.78)
    static let lift = Animation.spring(response: 0.28, dampingFraction: 0.68)

    /// Whether the cards swap their glass for a painted surface while
    /// they jiggle. See `CardGlass` in Theme.swift for why they might.
    /// `-jiggleGlass YES` keeps the glass, for comparing the two.
    static var paintsFlatWhileArranging: Bool {
        !UserDefaults.standard.bool(forKey: "jiggleGlass")
    }
}

// MARK: - What is going on

/// The state of a rearranging session, shared by the page and its cards.
///
/// `@Observable` lets SwiftUI see which views read which property, and
/// redraw only those when it changes. That matters here: the finger's
/// position changes many times a second while a card is carried, and
/// only the one card in the hand reads it, so only that card is redrawn.
/// Had it been kept in the page's own `@State`, every card would have
/// been worked out again on every movement.
@Observable
final class ArrangeSession {

    /// The card that has been pressed for long enough to lift. It may
    /// not have moved yet.
    var pressed: TodayPanel?
    /// The card being carried, once the finger has started to move.
    var held: TodayPanel?
    /// Where on the board the finger was when the card was picked up.
    var anchor = CGPoint.zero
    /// Which part of the card was taken hold of: (0, 0) is its top left
    /// corner and (1, 1) its bottom right. The card stays under the
    /// finger by this same part even if it changes size as it is carried
    /// from a column to the full width of the page.
    var grab = UnitPoint.center
    /// Where the finger is now, in the page's coordinates.
    var fingerOnPage = CGPoint.zero
    /// Where the board's top left corner is in the page's coordinates.
    /// It changes as the page scrolls.
    var boardOrigin = CGPoint.zero

    /// Where the finger is on the board.
    var fingerOnBoard: CGPoint {
        CGPoint(x: fingerOnPage.x - boardOrigin.x, y: fingerOnPage.y - boardOrigin.y)
    }

    // `@ObservationIgnored` marks things no view needs redrawing for.

    /// The latest places worked out by the layout. The dragging reads
    /// this to learn what is under the finger.
    @ObservationIgnored var plan: TodayBoardPlan?
    /// How far the page is scrolled, and the least and most it can be.
    @ObservationIgnored var scrollY = 0.0
    @ObservationIgnored var scrollRange = 0.0...0.0
    /// The height of the part of the window that Today fills.
    @ObservationIgnored var pageHeight = 0.0
    /// The place the finger is resting over, waiting out the dwell.
    @ObservationIgnored var waitingFor: Place?
    @ObservationIgnored var waiting: Task<Void, Never>?
    /// Scrolls the page while a card is held near its top or bottom.
    @ObservationIgnored var edgeScrolling: Task<Void, Never>?

    /// A place a card can go: a zone, and how many of the zone's other
    /// cards are above it.
    struct Place: Equatable {
        var zone: Int
        var place: Int
    }

    /// Forgets everything about the card in the hand.
    func letGo() {
        waiting?.cancel()
        edgeScrolling?.cancel()
        waiting = nil
        edgeScrolling = nil
        waitingFor = nil
        pressed = nil
        held = nil
    }
}

// MARK: - The layout

/// What a view on the board is, so the layout knows where to put it.
enum BoardRole: Equatable {
    /// One of the cards.
    case card(TodayPanel)
    /// The soft shape shown in the space waiting for the card in the hand.
    case gap
    /// The outline of a zone with nothing in it.
    case emptyZone(Int)
    case other
}

/// A `LayoutValueKey` is a label a view can wear that its layout can
/// read. This one carries the view's `BoardRole`.
private struct BoardRoleKey: LayoutValueKey {
    static let defaultValue = BoardRole.other
}

extension View {
    /// Tells the board's layout what this view is.
    func boardRole(_ role: BoardRole) -> some View {
        layoutValue(key: BoardRoleKey.self, value: role)
    }
}

/// Puts the cards where the arrangement says.
///
/// A `Layout` is SwiftUI's way of writing a container with rules of its
/// own, as `VStack` has the rule "one under another". This one's rule is
/// "full-width cards, then columns, then full-width cards".
///
/// WHY NOT STACKS, AS BEFORE
/// The page used to be a VStack holding an HStack of VStacks. A card
/// moved from one column to another was then, to SwiftUI, one card
/// vanishing and a different one appearing, so it faded out and in. With
/// every card a child of this one layout, a moved card is the same card
/// in a new place, and SwiftUI slides it there.
///
/// The card in the hand is the exception. Its place in the arrangement
/// is kept open as a gap, and the card itself is left where it was
/// picked up. `BoardCard` then shifts it by however far the finger has
/// moved, which costs nothing to draw.
struct TodayBoardLayout: Layout {

    /// Which cards are in which zone. The width is filled in from the
    /// room the layout is given.
    var page: TodayBoardPlan.Page
    /// The card in the hand, if there is one.
    var held: Held?
    /// Where the places worked out are written down for the dragging.
    let session: ArrangeSession

    struct Held: Equatable {
        var panel: TodayPanel
        var anchor: CGPoint
        var grab: UnitPoint
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = usable(proposal.width)
        return CGSize(width: width, height: plan(width: width, subviews: subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let plan = plan(width: bounds.width, subviews: subviews)
        session.plan = plan

        for subview in subviews {
            var slot: CGRect?
            var isInHand = false
            switch subview[BoardRoleKey.self] {
            case .card(let panel):
                slot = plan.slots[panel]
                isInHand = held?.panel == panel
            case .gap:
                slot = held.flatMap { plan.slots[$0.panel] }
            case .emptyZone(let zone):
                slot = plan.emptyZones[zone]
            case .other:
                break
            }
            guard let slot else {
                // Nowhere to go: given no room, out of the way.
                subview.place(at: bounds.origin, proposal: .zero)
                continue
            }
            var corner = slot.origin
            if isInHand, let held {
                // Left where it was picked up, by the part that was
                // taken hold of.
                corner = CGPoint(x: held.anchor.x - held.grab.x * slot.width,
                                 y: held.anchor.y - held.grab.y * slot.height)
            }
            subview.place(at: CGPoint(x: bounds.minX + corner.x, y: bounds.minY + corner.y),
                          proposal: ProposedViewSize(width: slot.width, height: slot.height))
        }
    }

    /// The places, for a board this wide. Each card is asked how tall
    /// it wants to be at the width its zone gives it.
    private func plan(width: CGFloat, subviews: Subviews) -> TodayBoardPlan {
        var cards: [TodayPanel: LayoutSubview] = [:]
        for subview in subviews {
            if case .card(let panel) = subview[BoardRoleKey.self] { cards[panel] = subview }
        }
        var page = page
        page.width = width
        return TodayBoardPlan(page: page) { panel, cardWidth in
            cards[panel]?.sizeThatFits(ProposedViewSize(width: CGFloat(cardWidth), height: nil)).height ?? 0
        }
    }

    /// A layout can be asked what it would do with no width, or with
    /// endless width. Neither means anything here, so a middling width
    /// stands in.
    private func usable(_ width: CGFloat?) -> CGFloat {
        guard let width, width.isFinite, width > 0 else { return 600 }
        return width
    }
}

// MARK: - One card

/// What a card tells the page as it is pressed, carried and let go.
struct BoardActions {
    /// The press has been held long enough.
    var pressed: (TodayPanel) -> Void
    /// The finger has moved to this point on the page.
    var carried: (TodayPanel, CGPoint) -> Void
    /// The finger has lifted, or the system has called the touch off.
    var ended: (TodayPanel) -> Void
}

/// One card on the board, with everything that lets it be picked up.
struct BoardCard<Content: View>: View {
    let panel: TodayPanel
    let isArranging: Bool
    let session: ArrangeSession
    let actions: BoardActions
    /// The card itself. It is built by the page and handed in whole, so
    /// redrawing this wrapper as the finger moves does not build it again.
    let content: Content

    /// True from the moment the press is long enough until the finger
    /// lifts. `@GestureState` puts itself back to false when a touch
    /// ends for any reason, including the system calling it off, which
    /// an ordinary "ended" message does not cover.
    @GestureState private var isTouching = false
    /// The card's size, for how far to rock and how much to lift.
    @State private var size = CGSize(width: 320, height: 200)

    var body: some View {
        let isHeld = session.held == panel
        let isLifted = isHeld || session.pressed == panel

        content
            // While rearranging, the buttons inside a card are switched
            // off, so a press moves the card and does not press them.
            .allowsHitTesting(!isArranging)
            // The whole card can be pressed, its empty parts included.
            .contentShape(.rect)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            // The card in the hand does not jiggle, as on the Home Screen.
            .modifier(Jiggle(isOn: isArranging && !isLifted, width: size.width))
            .background {
                // A shadow under a lifted card.
                if isLifted {
                    RoundedRectangle(cornerRadius: Theme.cardRadius)
                        .fill(.black.opacity(0.3))
                        .blur(radius: 18)
                        .offset(y: 12)
                        .padding(.horizontal, 6)
                        .transition(.opacity)
                }
            }
            .scaleEffect(isLifted ? liftScale : 1)
            .offset(isHeld ? carriedBy : .zero)
            // Drawn above the other cards while it is lifted.
            .zIndex(isLifted ? 10 : 0)
            .simultaneousGesture(holdThenCarry)
            // Tidies up however the touch ended.
            .onChange(of: isTouching) { _, touching in
                if !touching { actions.ended(panel) }
            }
            .boardRole(.card(panel))
    }

    /// How far the card has been carried: from where the finger picked
    /// it up to where the finger is now.
    private var carriedBy: CGSize {
        let finger = session.fingerOnBoard
        return CGSize(width: finger.x - session.anchor.x, height: finger.y - session.anchor.y)
    }

    /// A lifted card grows a little, by about the same number of points
    /// whatever its size. A small card grows by a twentieth. A card as
    /// wide as the page barely grows at all, or its ends would leave
    /// the window.
    private var liftScale: CGFloat {
        1 + min(0.05, 14 / max(size.width, 1))
    }

    /// Press and hold, then carry. Two gestures in a row: the second
    /// only begins once the first has finished.
    private var holdThenCarry: some Gesture {
        LongPressGesture(minimumDuration: isArranging ? TodayBoard.holdToLift : TodayBoard.holdToBegin,
                         maximumDistance: isArranging ? 40 : 10)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(TodayBoard.pageSpace)))
            .updating($isTouching) { value, touching, _ in
                if case .second = value { touching = true }
            }
            .onChanged { value in
                // `.second` means the press has been held long enough.
                // It carries the drag once the finger has moved.
                guard case .second(true, let drag) = value else { return }
                if let drag {
                    actions.carried(panel, drag.location)
                } else {
                    actions.pressed(panel)
                }
            }
            .onEnded { _ in actions.ended(panel) }
    }
}

// MARK: - The jiggle

/// The jiggle. A card rocks from side to side and drifts a little, over
/// and over, while `isOn` is true.
///
/// Apple publishes no figures for the Home Screen's jiggle. The ones
/// here are those usually quoted by people who have taken it apart
/// (looked up 14 November 2026): a full rock four times a second, about
/// two degrees each way for an icon, and a drift of about a point.
/// ⚠️ CHECK against an iPad by eye.
///
/// What makes it a jiggle and not a sway is that it does not ease: the
/// card turns at a steady speed and reverses at once, like something
/// shivering. The versions of 13 November all slowed at each end of the
/// swing, which is how a pendulum moves. William: "the wrong kind of
/// motion", and of the last, "still wrong".
///
/// A card turns less the wider it is, so that the ends of every card
/// travel about the same distance. An icon turning two degrees moves its
/// corners a point or two. A card as wide as the page turning two
/// degrees would move its ends by half a finger's width.
///
/// To try other figures without changing the code, start the app with
/// `-jiggleSeconds 0.3` (the time for one full rock), `-jiggleTravel 3`
/// (how many points the ends of a card move) or `-jiggleDrift 0`.
///
/// History, 13 November 2026: every card at one pace (read as a
/// machine); a bob added ("too much, too fast"); a slow eased rock
/// ("still wrong").
struct Jiggle: ViewModifier {
    let isOn: Bool
    /// How wide the card is, which sets how far it may turn.
    let width: CGFloat

    // Set in the system's Accessibility settings by people for whom
    // movement on screen is unpleasant.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Where in its rock this card starts, and where in its drift, each
    /// chosen once when the card is made. No two cards keep time.
    @State private var rockStart = Double.random(in: 0..<1)
    @State private var driftStart = Double.random(in: 0..<1)

    func body(content: Content) -> some View {
        let isMoving = isOn && !reduceMotion
        // A TimelineView redraws what is inside it on a timetable. This
        // one's timetable is "every frame the screen shows", and it is
        // paused whenever the cards are not jiggling, so it costs
        // nothing the rest of the time.
        TimelineView(.animation(paused: !isMoving)) { timeline in
            let pose = isMoving
                ? JigglePose(at: timeline.date.timeIntervalSinceReferenceDate,
                             width: width, rockStart: rockStart, driftStart: driftStart)
                : JigglePose.still
            content
                .rotationEffect(.degrees(pose.degrees))
                .offset(x: pose.x, y: pose.y)
        }
        // Coming to rest takes a moment, so the cards do not snap upright.
        .animation(.easeOut(duration: 0.16), value: isMoving)
        .overlay {
            // With Reduce Motion on, a dashed outline says "this can be
            // moved" in place of the jiggle.
            if isOn && reduceMotion {
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .strokeBorder(Theme.inkSoft, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
        }
    }
}

/// How a jiggling card is leaning and where it has drifted to at one
/// moment.
struct JigglePose: Equatable {
    var degrees = 0.0
    var x = 0.0
    var y = 0.0

    static let still = JigglePose()

    /// The time for one full rock, there and back, in seconds.
    static let seconds = setting("jiggleSeconds", standard: 0.25, atLeast: 0.05)
    /// How far the ends of a card move each way, in points.
    static let travel = setting("jiggleTravel", standard: 2.0, atLeast: 0)
    /// How far a card drifts from its place, in points.
    static let drift = setting("jiggleDrift", standard: 1.0, atLeast: 0)
    /// The most any card turns, in degrees. This is an icon's turn.
    static let mostDegrees = 2.0

    /// Reads a figure given when the app was started, such as
    /// `-jiggleSeconds 0.3`, or uses the standard one.
    private static func setting(_ name: String, standard: Double, atLeast: Double) -> Double {
        guard UserDefaults.standard.object(forKey: name) != nil else { return standard }
        return max(atLeast, UserDefaults.standard.double(forKey: name))
    }

    init() {}

    /// The pose at a moment in time. `time` is in seconds from any fixed
    /// starting point. `rockStart` and `driftStart` are how far through
    /// its rock and its drift the card began, from 0 to 1.
    init(at time: Double, width: Double, rockStart: Double, driftStart: Double) {
        // How far through one rock we are, from 0 to 1, over and over.
        let turns = time / Self.seconds
        let rock = (turns + rockStart).truncatingRemainder(dividingBy: 1)
        let wander = (turns + driftStart).truncatingRemainder(dividingBy: 1)

        // The angle that moves the card's ends by `travel` points.
        let radians = Self.travel / max(width / 2, 20)
        let most = min(Self.mostDegrees, radians * 180 / .pi)
        // A zigzag: from one side straight across to the other and
        // straight back, with no slowing at the ends.
        degrees = most * (1 - 4 * abs(rock - 0.5))

        // The drift goes round four points, a step for each quarter of
        // the rock, in a bow-tie shape.
        let corners: [(x: Double, y: Double)] = [(-0.5, -0.5), (0.5, 0.5), (-0.5, 0.5), (0.5, -0.5)]
        let step = wander * 4
        let from = corners[Int(step) % 4], to = corners[(Int(step) + 1) % 4]
        let part = step - step.rounded(.down)
        x = Self.drift * (from.x + (to.x - from.x) * part)
        y = Self.drift * (from.y + (to.y - from.y) * part)
    }
}

// MARK: - Two quiet shapes

/// Shown in the space that is waiting for the card in the hand.
struct BoardGap: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Theme.cardRadius)
            .fill(Theme.ink.opacity(0.06))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .strokeBorder(Theme.ink.opacity(0.14), lineWidth: 1)
            }
    }
}

/// The outline of a zone with nothing in it, shown while rearranging so
/// there is somewhere to carry a card to.
struct EmptyZoneOutline: View {
    let words: String

    var body: some View {
        Text(words)
            .font(.caption)
            .foregroundStyle(Theme.inkSoft)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Theme.inkSoft.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
            }
    }
}

// MARK: - A checking aid

/// Counts how many times a second the screen is drawn while the cards
/// jiggle, and writes the count to a file. Switched on by starting the
/// app with `-jiggleMeter YES`. Used to find out whether a Mac can rock
/// glass smoothly (see `CardGlass` in Theme.swift).
struct JiggleMeter: View {
    static let isOn = UserDefaults.standard.bool(forKey: "jiggleMeter")

    var body: some View {
        TimelineView(.animation) { timeline in
            // Nothing is drawn. Being asked to draw is what is counted.
            Color.clear.onChange(of: timeline.date) { _, now in JiggleCount.shared.tick(at: now) }
        }
        .frame(width: 1, height: 1)
        .allowsHitTesting(false)
    }
}

/// The count itself, kept outside any view.
final class JiggleCount {
    static let shared = JiggleCount()
    private var frames = 0
    private var since = Date.now
    private let file = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("windfall-jiggle-meter.txt")

    func tick(at now: Date) {
        frames += 1
        let passed = now.timeIntervalSince(since)
        guard passed >= 1 else { return }
        let line = String(format: "%.0f frames a second\n", Double(frames) / passed)
        if let handle = try? FileHandle(forWritingTo: file) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? Data(line.utf8).write(to: file)
        }
        frames = 0
        since = now
    }
}
