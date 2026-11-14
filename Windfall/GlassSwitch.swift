//
//  GlassSwitch.swift
//  Windfall
//
//  The sliding switch: a row of choices on a glass track, with a lens
//  that sits on the chosen one.
//
//  THE RULE (William, 13 November 2026): every bar of choices in the app
//  is one of these, and they all behave the same way.
//
//    Tap a choice        the lens lifts, stretches across and settles.
//    Press and slide     the lens lifts and follows the finger.
//    Two fingers (Mac)   swipe sideways on the trackpad with the pointer
//                        over the bar, and the lens follows.
//
//  While it is lifted the lens is clear glass, a little larger than the
//  track. The words under it are magnified and bent at its rim, and it
//  stretches in the direction it is travelling, like a drop of liquid.
//  That is how Apple's own switches and sliders behave: Apple's guidance
//  for developers says their knobs turn to Liquid Glass while touched.
//
//  Why not Apple's own joined buttons (a "segmented picker")? On a Mac
//  they have squarer corners than the cards, cannot be dragged and will
//  not shrink below the width of their words.
//
//  The bending is done by the same small graphics program as the
//  sidebar's lens (Lens.metal). `LensBend`, below, is how any view asks
//  for it.
//
//  Checking aid: start the app with `-switchLensHeld 0.4` and every
//  switch is drawn lifted, moved along by that share of one choice, so
//  a still picture can show the lifted look.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

/// `Value: Hashable` means the choices can be anything Swift can tell
/// apart and look up: a garden's key, true and false, a kind of sky.
struct GlassSwitch<Value: Hashable>: View {

    private let choices: [Value]
    @Binding private var selection: Value
    private let title: (Value) -> String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Some people ask their device for less see-through. For them the
    // lens stays solid green and is never clear.
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    /// True while the card this switch sits on is painted flat.
    @Environment(\.paintsGlassFlat) private var paintsFlat

    // The lens's left and right edges, counted in choices: 0 is the left
    // edge of the first choice, 1 the left edge of the second. They are
    // kept apart so that one edge can race ahead and the other catch up.
    // Counting in choices, not points, means they stay right when the
    // window changes width.
    @State private var lensLeft: CGFloat
    @State private var lensRight: CGFloat
    /// True while the lens is off the surface: larger and clear.
    @State private var isLifted = false
    /// True while a finger, the pointer or the trackpad is carrying it.
    @State private var isCarried = false
    /// Counts the moves, so an older move never finishes on top of a newer one.
    @State private var moveNumber = 0
    /// Where the lens was carried to last, and when. Two of these give
    /// its speed, which sets how far it stretches.
    @State private var lastPlace: CGFloat?
    @State private var lastTime: TimeInterval = 0
    /// How wide the switch has been made, for the trackpad.
    @State private var trackWidth: CGFloat = 0

    #if os(macOS)
    /// The Mac's handle on the scroll watcher, kept so it can be removed.
    @State private var scrollWatcher: Any?
    /// Where the middle of the lens has been scrolled to, in points.
    @State private var scrollMiddle: CGFloat = 0
    @State private var scrollTravel: CGFloat = 0
    /// Whether the scroll under way is a sideways one, and so ours.
    /// Nil until the fingers have moved far enough to tell.
    @State private var scrollIsSideways: Bool?
    @State private var lastWheelStep = Date.distantPast
    #endif

    private let height: CGFloat = 40
    /// The gap between the track's edge and the lens.
    private let rim: CGFloat = 3
    /// How much larger the lens is while lifted. Taller than the track,
    /// so it stands proud of it.
    private let liftAcross: CGFloat = 1.06
    private let liftUp: CGFloat = 1.3

    /// - `title`: gives the words to show for each choice.
    init(choices: [Value], selection: Binding<Value>, title: @escaping (Value) -> String) {
        self.choices = choices
        self._selection = selection
        self.title = title
        // The lens starts on the chosen one.
        let chosen = CGFloat(choices.firstIndex(of: selection.wrappedValue) ?? 0)
        _lensLeft = State(initialValue: chosen)
        _lensRight = State(initialValue: chosen + 1)
    }

    /// True when the lens is lifted and allowed to be see-through.
    private var bends: Bool { LensRefraction.isBuilt && isLifted && !reduceTransparency }

    /// The width of one choice.
    private func share(of width: CGFloat) -> CGFloat {
        max((width - rim * 2) / CGFloat(max(choices.count, 1)), 0)
    }

    var body: some View {
        // GeometryReader says how wide the switch has been made, so each
        // choice can be given an equal share.
        GeometryReader { geometry in
            let each = share(of: geometry.size.width)
            // How much longer than one choice the lens is just now. A
            // stretched lens is also a flatter one.
            let stretch = max(lensRight - lensLeft - 1, 0)
            let across = bends ? liftAcross : (isLifted ? 1.04 : 1)
            let up = bends ? max(liftUp - stretch * 0.45, 1.05) : (isLifted ? 1.06 : 1)
            let lensWidth = max((lensRight - lensLeft) * each, 8)
            let lensHeight = height - rim * 2

            ZStack(alignment: .leading) {
                // 1. The lens's body, under the words.
                lensBody
                    .frame(width: lensWidth, height: lensHeight)
                    .scaleEffect(x: across, y: up)
                    .offset(x: rim + lensLeft * each)

                // 2. The words. Each is a real button, so a tap, the
                //    keyboard and VoiceOver all work. While the lens is
                //    lifted, the part of them under it is magnified.
                words(each: each)
                    .modifier(LensBend(midX: rim + (lensLeft + lensRight) / 2 * each,
                                       midY: height / 2,
                                       halfWidth: lensWidth / 2 * across,
                                       halfHeight: lensHeight / 2 * up,
                                       strength: bends ? 1 : 0))

                // 3. The lens's bright rim, over the words, as the edge
                //    of a real lens would be.
                lensRim
                    .frame(width: lensWidth, height: lensHeight)
                    .scaleEffect(x: across, y: up)
                    .offset(x: rim + lensLeft * each)
            }
            // Press and slide to carry the lens. "Simultaneous" means
            // the buttons underneath still get their taps.
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { drag in
                        // Only a sideways slide picks the lens up. A
                        // finger passing over on its way up or down the
                        // page is scrolling, and must not change the choice.
                        let isSideways = abs(drag.translation.width) > abs(drag.translation.height)
                        if isCarried || isSideways {
                            carry(toMiddle: drag.location.x, each: each)
                        }
                    }
                    .onEnded { drag in drop(atMiddle: drag.location.x, each: each) }
            )
        }
        .frame(height: height)
        // Through `cardGlass`, so the track is painted flat when the
        // card the switch sits on is. See `CardGlass` in Theme.swift.
        .cardGlass(Theme.card.opacity(0.5), in: .capsule)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { trackWidth = $0 }
        // The choice can be changed from outside too, for example when
        // the weather is filled in. The lens follows whoever changed it.
        .onChange(of: selection) { _, _ in
            settle(animated: true)
        }
        .onAppear { holdForChecking() }
        #if os(macOS)
        // Watch the trackpad only while the pointer is over this switch.
        .onHover { isOver in
            if isOver { watchScrolling() } else { stopWatchingScrolling() }
        }
        .onDisappear { stopWatchingScrolling() }
        #endif
    }

    // MARK: What it is made of

    private func words(each: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(choices, id: \.self) { option in
                Button {
                    choose(option)
                } label: {
                    Text(title(option))
                        .font(.subheadline.weight(option == selection ? .semibold : .regular))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        // Long words shrink a little before they are cut short.
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 6)
                        .frame(width: each, height: height)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(option == selection ? .isSelected : [])
            }
        }
        .padding(.horizontal, rim)
    }

    /// The lens has two looks and fades between them. At rest it is
    /// Apple's glass, tinted green and nearly solid. Lifted, it is a
    /// breath of tint over a soft shadow, with the bending done by
    /// LensBend and the bright edge drawn by `lensRim`.
    private var lensBody: some View {
        ZStack {
            Color.clear
                // `.identity` means "no glass", and is how glass is
                // switched off without the view being rebuilt.
                .glassEffect(bends || paintsFlat ? .identity : .regular.tint(Theme.leafFill.opacity(0.9)), in: .capsule)
            // The lens painted flat, for when the switch is on a card
            // that is being rearranged. Left as glass there, the switch
            // was the one piece of glass on a painted, rocking card
            // (William, 14 November 2026: "the allotment/permaculture
            // bar looks strange").
            Capsule()
                .fill(Theme.leafFill.opacity(0.9))
                .opacity(paintsFlat && !bends ? 1 : 0)
            ZStack {
                // A soft dark edge underneath, standing in for a shadow.
                Capsule()
                    .stroke(.black.opacity(0.30), lineWidth: 4)
                    .blur(radius: 5)
                    .offset(y: 3)
                Capsule()
                    .fill(Theme.leafFill.opacity(0.22))
            }
            .opacity(bends ? 1 : 0)
        }
        // Touches pass through to the words underneath.
        .allowsHitTesting(false)
    }

    /// Bright where the light catches it at the top left, fading round
    /// to a fainter glint at the bottom right.
    private var lensRim: some View {
        Capsule()
            .strokeBorder(
                LinearGradient(colors: [.white.opacity(0.75), .white.opacity(0.10), .white.opacity(0.40)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 1.3)
            .opacity(bends ? 1 : 0)
            .allowsHitTesting(false)
    }

    // MARK: Moving the lens

    /// A tap on one of the words.
    private func choose(_ option: Value) {
        guard option != selection else { return }
        if reduceMotion {
            selection = option
        } else {
            // Changing the choice moves the lens too (see onChange above).
            withAnimation(.smooth(duration: 0.3)) { selection = option }
        }
    }

    /// Puts the lens on the chosen one.
    ///
    /// It lifts off, and the edge nearer the new choice sets off first
    /// and quickly. A moment later the other edge follows on a bouncier
    /// spring, so in between the lens is stretched across both. Then it
    /// sets itself back down. The sidebar's lens moves the same way.
    private func settle(animated: Bool) {
        let chosen = CGFloat(choices.firstIndex(of: selection) ?? 0)
        isCarried = false
        lastPlace = nil

        guard animated, !reduceMotion else {
            lensLeft = chosen
            lensRight = chosen + 1
            isLifted = false
            return
        }

        moveNumber += 1
        let thisMove = moveNumber
        let goingRight = chosen > lensLeft

        withAnimation(.spring(duration: 0.26, bounce: 0.15)) {
            isLifted = true
            if goingRight { lensRight = chosen + 1 } else { lensLeft = chosen }
        }
        Task {
            try? await Task.sleep(for: .milliseconds(90))
            // If another choice was made in the meantime, leave it to that move.
            guard thisMove == moveNumber else { return }
            withAnimation(.spring(duration: 0.5, bounce: 0.4)) {
                lensLeft = chosen
                lensRight = chosen + 1
            }
            // Once it has arrived, set it back down.
            try? await Task.sleep(for: .milliseconds(280))
            guard thisMove == moveNumber else { return }
            withAnimation(.smooth(duration: 0.3)) { isLifted = false }
        }
    }

    /// The lens is being carried, with its middle at `x`. With Reduce
    /// Motion on it is not carried at all: tapping still works.
    private func carry(toMiddle x: CGFloat, each: CGFloat) {
        guard !reduceMotion, each > 0, !choices.isEmpty else { return }
        // Cancels a slide that is still finishing.
        moveNumber += 1
        let thisMove = moveNumber

        // Where its left edge belongs, counted in choices, on the track.
        let spot = min(max((x - rim) / each - 0.5, 0), CGFloat(choices.count - 1))

        // How fast it is going, in points a second, from where it was
        // last time. The faster it goes, the more it stretches, and the
        // stretch trails behind it.
        let now = Date.now.timeIntervalSinceReferenceDate
        var stretch: CGFloat = 0
        var goingRight = true
        if let before = lastPlace {
            let gap = max(now - lastTime, 1.0 / 240)
            let speed = (spot - before) * each / gap
            goingRight = speed >= 0
            stretch = min(abs(speed) / 2600, 0.32)
        }
        lastPlace = spot
        lastTime = now

        withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.72)) {
            isLifted = true
            isCarried = true
            lensLeft = spot - (goingRight ? stretch : 0)
            lensRight = spot + 1 + (goingRight ? 0 : stretch)
        }

        // When the finger stops, no more of these arrive. A moment
        // later the lens draws itself back to its own length.
        Task {
            try? await Task.sleep(for: .milliseconds(90))
            guard thisMove == moveNumber, isCarried else { return }
            withAnimation(.spring(duration: 0.35, bounce: 0.45)) {
                lensLeft = spot
                lensRight = spot + 1
            }
        }
    }

    /// The lens has been let go. It settles on the nearest choice. If it
    /// was never picked up, nothing changes.
    private func drop(atMiddle x: CGFloat, each: CGFloat) {
        guard isCarried, each > 0, !choices.isEmpty else { return }
        let nearest = Int(((x - rim) / each - 0.5).rounded())
        let landed = choices[min(max(nearest, 0), choices.count - 1)]
        if landed == selection {
            // The same choice as before: set the lens back down on it.
            settle(animated: true)
        } else {
            isCarried = false
            withAnimation(.smooth(duration: 0.3)) { selection = landed }
        }
    }

    /// Chooses the one before (-1) or after (+1) the chosen one.
    private func stepSelection(by amount: Int) {
        let now = choices.firstIndex(of: selection) ?? 0
        let next = min(max(now + amount, 0), choices.count - 1)
        guard next != now else { return }
        withAnimation(.smooth(duration: 0.3)) { selection = choices[next] }
    }

    /// The checking aid described at the top of this file.
    private func holdForChecking() {
        guard UserDefaults.standard.object(forKey: "switchLensHeld") != nil else { return }
        let nudge = CGFloat(UserDefaults.standard.double(forKey: "switchLensHeld"))
        isLifted = true
        lensLeft += nudge
        lensRight += nudge + 0.18
    }

    // MARK: Two fingers on a Mac's trackpad

    #if os(macOS)
    /// Starts watching for scrolling.
    ///
    /// SwiftUI has no "this view was scrolled over" for a view that is
    /// not a scrolling list. So this asks the Mac itself to pass every
    /// scroll in the app through here first, for as long as the pointer
    /// is over this switch. A sideways scroll moves the lens and goes no
    /// further. Anything else is handed straight back, untouched, so the
    /// page under the switch still scrolls up and down.
    private func watchScrolling() {
        guard scrollWatcher == nil else { return }
        PointerClaims.isOverSwitch = true
        scrollWatcher = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { scroll in
            lensScrolled(by: scroll) ? nil : scroll
        }
    }

    private func stopWatchingScrolling() {
        if let scrollWatcher { NSEvent.removeMonitor(scrollWatcher) }
        scrollWatcher = nil
        PointerClaims.isOverSwitch = false
        // The pointer left in the middle of a scroll: settle where it is.
        if scrollIsSideways == true {
            drop(atMiddle: scrollMiddle, each: share(of: trackWidth))
        }
        scrollIsSideways = nil
    }

    /// Uses one piece of a scroll. Returns true if it was used up here.
    private func lensScrolled(by scroll: NSEvent) -> Bool {
        // After the fingers lift, a trackpad keeps sending a glide that
        // dies away. The lens has already settled, so that is ignored.
        guard scroll.momentumPhase.isEmpty else { return false }

        let each = share(of: trackWidth)
        guard each > 0, choices.count > 1 else { return false }

        // Which way the fingers went. With "natural scrolling" switched
        // off in System Settings the Mac reports the opposite sign, so
        // it is turned back here. Either way, fingers moving right carry
        // the lens right.
        let sideways = scroll.isDirectionInvertedFromDevice ? scroll.scrollingDeltaX : -scroll.scrollingDeltaX
        let upOrDown = scroll.scrollingDeltaY

        // A mouse wheel has no beginning or end, only clicks. A sideways
        // click moves one choice. An ordinary wheel is left to the page.
        if scroll.phase.isEmpty {
            guard abs(sideways) > abs(upOrDown) else { return false }
            if Date.now.timeIntervalSince(lastWheelStep) > 0.15 {
                lastWheelStep = .now
                stepSelection(by: sideways > 0 ? 1 : -1)
            }
            return true
        }

        if scroll.phase.contains(.began) || scroll.phase.contains(.mayBegin) {
            scrollIsSideways = nil
        }
        // Decide once, from the first real movement, whether this scroll
        // is sideways (ours) or up and down (the page's).
        if scrollIsSideways == nil {
            guard abs(sideways) + abs(upOrDown) >= 0.5 else { return false }
            scrollIsSideways = abs(sideways) > abs(upOrDown)
            if scrollIsSideways == true {
                let chosen = CGFloat(choices.firstIndex(of: selection) ?? 0)
                scrollMiddle = rim + (chosen + 0.5) * each
                scrollTravel = 0
            }
        }
        guard scrollIsSideways == true else { return false }

        scrollTravel += sideways
        scrollMiddle = min(max(scrollMiddle + sideways * 0.8, rim + each / 2),
                           rim + each * (CGFloat(choices.count) - 0.5))

        if scroll.phase.contains(.ended) || scroll.phase.contains(.cancelled) {
            if reduceMotion {
                // No sliding lens. A scroll of any size is one step.
                if abs(scrollTravel) > 12 { stepSelection(by: scrollTravel > 0 ? 1 : -1) }
            } else {
                drop(atMiddle: scrollMiddle, each: each)
            }
            scrollIsSideways = nil
            // The page is allowed to see that the scroll has ended.
            return false
        }
        carry(toMiddle: scrollMiddle, each: each)
        return true
    }
    #endif
}

/// Notes shared between the pieces of the app that watch the Mac's
/// trackpad, so that two of them never act on the same swipe.
enum PointerClaims {
    /// True while the pointer is over a sliding switch, which then owns
    /// any sideways swipe. The swipe that goes back a page stands aside.
    static var isOverSwitch = false
}

// MARK: - The bend

/// Magnifies and bends whatever lies under a lens.
///
/// The bending is done by the small graphics program in Lens.metal. This
/// passes it where the lens is, how big and how strong.
///
/// `Animatable` matters here. SwiftUI can glide a colour or a position
/// from one value to another by itself, but it knows nothing about the
/// numbers handed to a graphics program. `animatableData` names the
/// numbers to glide, and SwiftUI then calls `body` afresh for every
/// frame with the in-between values, so the bend keeps exact step with
/// the lens drawn on top of it.
struct LensBend: ViewModifier, Animatable {

    /// The middle of the lens, in the view's own points.
    var midX: CGFloat
    var midY: CGFloat
    /// Half its width and half its height, as it is drawn.
    var halfWidth: CGFloat
    var halfHeight: CGFloat
    /// 0 for no bending, 1 for the full effect.
    var strength: CGFloat

    // Five numbers, paired up, because `AnimatablePair` holds two.
    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>,
                                       AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat>> {
        get { AnimatablePair(AnimatablePair(midX, midY), AnimatablePair(AnimatablePair(halfWidth, halfHeight), strength)) }
        set {
            midX = newValue.first.first
            midY = newValue.first.second
            halfWidth = newValue.second.first.first
            halfHeight = newValue.second.first.second
            strength = newValue.second.second
        }
    }

    func body(content: Content) -> some View {
        if LensRefraction.isBuilt {
            content.layerEffect(
                ShaderLibrary.lensRefraction(
                    .float2(midX, midY),
                    .float2(halfWidth, halfHeight),
                    // Fully round ends, like a capsule.
                    .float(min(halfWidth, halfHeight)),
                    .float(strength)),
                // The furthest the program may reach for a dot's colour.
                maxSampleOffset: CGSize(width: 44, height: 44),
                isEnabled: strength > 0.001)
        } else {
            content
        }
    }
}
