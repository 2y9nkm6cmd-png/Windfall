# Archived: Eira's button opening by rolling along

Archived on 12 November 2026 at William's request: "Keep the windblown version and save the other version to the archive in case I want to come back to it."

## What it was

Eira's floating button could open in two ways, chosen in Settings or by pressing and holding the snowdrop:

- **Roll along**: the whole symbol rolled like a coin across to the sidebar, bumped against it and settled.
- **Blown along by the wind**: it slid across while the snowdrop bent and swayed. This is the one that was kept.

## How to bring it back

The file below is `Windfall/EiraFloatingBar.swift` exactly as it stood with both styles working. To restore the choice:

1. Put back the `EiraOpeningStyle` list and the `styleRaw` setting.
2. Put back `rollDegrees`, the `.rotationEffect(.degrees(rollDegrees))` on the snowdrop and the `case .roll:` branch in `move`.
3. Put back the "How she opens" picker in `SettingsView` (in `MainTabView.swift`) and in the snowdrop's press-and-hold menu.

The key idea: a coin rolling without slipping turns once for every circumference it travels. The number of turns is rounded to a whole number so the snowdrop always finishes upright.

## The code

```swift
//
//  EiraFloatingBar.swift
//  Windfall
//
//  Eira's button, which floats in the bottom right corner of every screen.
//
//  Closed, it is her snowdrop in a small glass bubble. Tap it and it
//  travels to the left, drawing a bar out behind it: "Ask Eira, search or
//  open anything". Tap the snowdrop again to put it away.
//
//  There are two ways for it to travel, chosen in Settings or by pressing
//  and holding the snowdrop:
//
//    Roll along    the whole symbol rolls like a coin
//    Blown along   it slides, and the snowdrop bends and sways as if a
//                  gust of wind were carrying it
//
//  If "Reduce Motion" is switched on in the device's accessibility
//  settings, it does neither and simply opens.
//

import SwiftUI
import SwiftData

/// The two ways Eira's button can open.
enum EiraOpeningStyle: String, CaseIterable, Identifiable {
    case roll, wind

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .roll: return "Roll along"
        case .wind: return "Blown along by the wind"
        }
    }
}

struct EiraFloatingBar: View {

    // @AppStorage keeps a small setting on the device, so the choice is
    // remembered the next time the app opens.
    @AppStorage("eiraOpeningStyle") private var styleRaw = EiraOpeningStyle.roll.rawValue
    @AppStorage("eiraBarStaysOpen") private var staysOpen = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isOpen = false
    @State private var question = ""
    /// How far the symbol has turned, in degrees. Used by "roll along".
    @State private var rollDegrees = 0.0
    /// When the last gust began, and which way it blew. Used by "blown along".
    @State private var gustStart: Date?
    @State private var gustDirection = -1.0
    /// How far the bar has sprung back after bumping into the sidebar.
    @State private var rebound: CGFloat = 0

    /// Set to open Eira's chat or the search screen. Each carries the
    /// words that were typed, so the sheet always gets the latest ones.
    @State private var eiraRequest: BarRequest?
    @State private var searchRequest: BarRequest?

    // @FocusState says whether the text box has the keyboard.
    @FocusState private var fieldHasFocus: Bool

    private let symbolSize: CGFloat = 50
    private let rim: CGFloat = 5
    private var closedSize: CGFloat { symbolSize + rim * 2 }

    private var style: EiraOpeningStyle { EiraOpeningStyle(rawValue: styleRaw) ?? .roll }
    private var expanded: Bool { isOpen || staysOpen }

    var body: some View {
        // GeometryReader reports how much room there is, so the bar can be
        // as wide as the screen allows, up to a sensible limit.
        GeometryReader { geometry in
            // The bar runs the full width, so the snowdrop travels all
            // the way across to the sidebar.
            let barWidth = geometry.size.width

            HStack(spacing: 10) {
                symbolButton(travel: barWidth - closedSize)

                if expanded {
                    TextField("Ask Eira, search or open anything", text: $question)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Theme.ink)
                        .focused($fieldHasFocus)
                        .onSubmit(ask)
                        .onKeyPress(.escape) {
                            close()
                            return .handled
                        }
                        .transition(.opacity)

                    barButton(.search, label: "Search everything") { search() }
                    barButton(.microphone, label: "Open Eira to talk or type") { openEira(with: nil) }
                }
            }
            .padding(.leading, rim)
            .padding(.trailing, expanded ? 14 : rim)
            // The frame grows from the snowdrop's width to the bar's width.
            // It is pinned to the right, so the left edge, and the snowdrop
            // with it, travels left as it grows.
            .frame(width: expanded ? max(barWidth - rebound, closedSize) : closedSize,
                   height: closedSize, alignment: .leading)
            .glassEffect(.regular.interactive(), in: .capsule)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: closedSize)
        .sheet(item: $eiraRequest) { request in
            NavigationStack {
                EiraChatView(openingQuestion: request.text.isEmpty ? nil : request.text)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { eiraRequest = nil }
                        }
                    }
            }
            .macSheetSize(width: 580, height: 660)
        }
        .sheet(item: $searchRequest) { request in
            NavigationStack {
                UniversalSearchView(initialQuery: request.text)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { searchRequest = nil }
                        }
                    }
            }
            .macSheetSize(width: 580, height: 660)
        }
    }

    // MARK: The snowdrop

    private func symbolButton(travel: CGFloat) -> some View {
        Button {
            toggle(travel: travel)
        } label: {
            // TimelineView redraws many times a second while a gust is
            // blowing, and not at all once it has died away.
            TimelineView(.animation(paused: gustStart == nil)) { timeline in
                let seconds = gustStart.map { timeline.date.timeIntervalSince($0) } ?? SnowdropWind.settled
                EiraSymbol(size: symbolSize,
                           lean: SnowdropWind.lean(at: seconds, direction: gustDirection),
                           nod: SnowdropWind.nod(at: seconds, direction: gustDirection))
            }
            .rotationEffect(.degrees(rollDegrees))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(expanded ? "Close Eira's bar" : "Ask Eira")
        .contextMenu {
            Picker("How Eira opens", selection: $styleRaw) {
                ForEach(EiraOpeningStyle.allCases) { style in
                    Text(style.displayName).tag(style.rawValue)
                }
            }
            Toggle("Keep the bar open", isOn: $staysOpen)
        }
    }

    private func barButton(_ icon: WIcon, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            WIconView(icon, size: 22)
                .foregroundStyle(Theme.leaf)
                .frame(width: 40, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
        .transition(.opacity)
    }

    // MARK: Opening and closing

    private func toggle(travel: CGFloat) {
        if staysOpen {
            // The bar is pinned open, so the snowdrop just hands the
            // keyboard to the text box.
            fieldHasFocus = true
            return
        }
        if isOpen {
            close(travel: travel)
        } else {
            open(travel: travel)
        }
    }

    private func open(travel: CGFloat) {
        move(opening: true, travel: travel)
        // Give the bar time to arrive and settle before the keyboard appears.
        Task {
            try? await Task.sleep(for: .seconds(travelTime(for: travel) + 0.35))
            if isOpen { fieldHasFocus = true }
        }
    }

    private func close(travel: CGFloat = 0) {
        fieldHasFocus = false
        guard isOpen else { return }
        move(opening: false, travel: travel)
    }

    /// How long the journey takes. A longer bar takes a little longer,
    /// within limits, so it never crawls and never flashes past.
    private func travelTime(for travel: CGFloat) -> Double {
        min(1.0, max(0.5, Double(travel) / 1200))
    }

    /// Opens or closes the bar in the chosen style.
    ///
    /// Opening has two parts. First the snowdrop travels left, gathering
    /// speed, until it reaches the sidebar. Then it bumps: it springs back
    /// a little way and settles. `withAnimation` can be given a
    /// `completion`, a piece of code to run when the movement finishes,
    /// which is how the bump follows the journey.
    private func move(opening: Bool, travel: CGFloat) {
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.2)) { isOpen = opening }
            return
        }

        let circumference = Double.pi * Double(closedSize)
        // A coin rolling without slipping turns once for every
        // circumference it travels. The number of turns is rounded to a
        // whole number so the snowdrop always finishes upright.
        let turns = max(1, (Double(max(travel, closedSize)) / circumference).rounded())
        let seconds = travelTime(for: travel)

        switch style {
        case .roll:
            if opening {
                // easeIn starts slowly and speeds up, like something
                // rolling downhill, so it is moving fast when it hits.
                withAnimation(.easeIn(duration: seconds)) {
                    isOpen = true
                    // Rolling left is anticlockwise, which is a negative angle.
                    rollDegrees = -360 * turns
                } completion: {
                    bump(restingAt: -360 * turns, circumference: circumference)
                }
            } else {
                withAnimation(.easeInOut(duration: seconds)) {
                    isOpen = false
                    rollDegrees = 0
                    rebound = 0
                }
            }

        case .wind:
            // The snowdrop is not rolling in this style. Any turns left
            // over from the other style are whole ones, so setting them
            // back to nothing changes nothing you can see.
            var instantly = Transaction()
            instantly.disablesAnimations = true
            withTransaction(instantly) { rollDegrees = 0 }

            gustDirection = opening ? -1 : 1
            let started = Date.now
            gustStart = started
            if opening {
                withAnimation(.easeIn(duration: SnowdropWind.travel)) {
                    isOpen = true
                } completion: {
                    bump(restingAt: 0, circumference: nil)
                }
            } else {
                withAnimation(.spring(duration: SnowdropWind.travel, bounce: 0.2)) {
                    isOpen = false
                    rebound = 0
                }
            }
            // Stop redrawing once the swaying has died away, unless a
            // newer gust has started in the meantime.
            Task {
                try? await Task.sleep(for: .seconds(SnowdropWind.settled))
                if gustStart == started { gustStart = nil }
            }
        }
    }

    /// The little bounce off the sidebar: back a short way, quickly, then
    /// forward again on a springy return.
    ///
    /// When the snowdrop is rolling, it also turns back and forward by the
    /// matching amount, so it still looks like a wheel on the ground.
    private func bump(restingAt rest: Double, circumference: Double?) {
        guard isOpen else { return }
        let distance: CGFloat = 18
        let turnBack = circumference.map { Double(distance) / $0 * 360 } ?? 0

        withAnimation(.easeOut(duration: 0.14)) {
            rebound = distance
            rollDegrees = rest + turnBack
        } completion: {
            withAnimation(.spring(duration: 0.5, bounce: 0.6)) {
                rebound = 0
                rollDegrees = rest
            }
        }
    }

    // MARK: What the bar does

    /// Return was pressed. On a device that can run Eira the words go to
    /// her. On one that cannot, they go to the search screen instead.
    private func ask() {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if DeviceCapability.canRunEira() {
            openEira(with: text)
        } else {
            search()
        }
    }

    private func openEira(with text: String?) {
        eiraRequest = BarRequest(text: text ?? "")
        question = ""
    }

    private func search() {
        searchRequest = BarRequest(text: question.trimmingCharacters(in: .whitespacesAndNewlines))
        question = ""
    }
}

/// What was typed into the bar, handed to the sheet that opens.
/// `Identifiable` lets SwiftUI tell one request from the next.
struct BarRequest: Identifiable {
    let id = UUID()
    let text: String
}
```
