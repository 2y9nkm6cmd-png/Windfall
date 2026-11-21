//
//  FormDraftViews.swift
//  Windfall
//
//  The parts of the review pass of 21 November 2026 (project docs 144
//  and 145) that go on a screen:
//
//    keepsDraft(...)      keeps a form's kept copy up to date as it is
//                         typed in, and fills the form back in from it
//                         when the form opens again. See FormDraft.swift.
//    DraftNotice          the "Carried on from typedBefore" line with Clear.
//    edgeSwipeBack(...)   a swipe from the left edge for a "Back" that is
//                         a step inside one sheet, which iOS's own swipe
//                         back does not reach.
//
//  WHY A SWIPE FROM THE LEFT DID NOTHING ON THE HARVEST PAGE
//  iOS gives a page its swipe back only when it was pushed on to a
//  navigation stack. The Harvest sheet from Today is one sheet whose
//  list is swapped for the form when a plant is chosen ("What did you
//  harvest?" then "Harvest"), so its Back is a button that swaps them
//  back. Nothing was pushed, so there was nothing for iOS to swipe back
//  from. `edgeSwipeBack` adds the swipe to such steps.
//

import SwiftUI

// MARK: - Keeping what was typed

extension View {

    /// Keeps `value` under `key` whenever it changes, and when the form
    /// first appears hands any copy kept typedBefore to `restore` and sets
    /// `carriedOn`, so the form can show `DraftNotice`.
    ///
    /// - `value`: a small struct of everything the form keeps. It must
    ///   be `Codable` (so it can be written down) and `Equatable` (so
    ///   SwiftUI can tell when it has changed).
    /// - `isEmpty`: true when nothing worth keeping has been typed. The
    ///   kept copy is then taken away rather than written.
    func keepsDraft<Value: Codable & Equatable>(_ key: String,
                                                 _ value: Value,
                                                 isEmpty: Bool,
                                                 carriedOn: Binding<Bool>,
                                                 restore: @escaping (Value) -> Void) -> some View {
        modifier(KeepsDraft(key: key, value: value, isEmpty: isEmpty, carriedOn: carriedOn, restore: restore))
    }
}

/// See `keepsDraft` above. A `ViewModifier` is a reusable change that
/// can be put on any view; `content` is the form it was put on.
private struct KeepsDraft<Value: Codable & Equatable>: ViewModifier {

    let key: String
    let value: Value
    let isEmpty: Bool
    @Binding var carriedOn: Bool
    let restore: (Value) -> Void

    /// False until the form has appeared and been filled back in, so
    /// the form's own starting values are never written over a copy
    /// that is waiting to be read.
    @State private var started = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !started else { return }
                started = true
                FormDraft.tidy()
                if let typedBefore = FormDraft.load(Value.self, key: key) {
                    restore(typedBefore)
                    carriedOn = true
                }
            }
            // Runs after every change to what the form keeps. Writing
            // the copy at once, rather than when the form closes, means
            // nothing is lost however it closes: a swipe, Back, Cancel,
            // another app, or the app being stopped.
            .onChange(of: value) { _, now in
                guard started else { return }
                if isEmpty {
                    FormDraft.clear(key: key)
                } else {
                    FormDraft.keep(now, key: key)
                }
            }
    }
}

/// "Carried on from typedBefore", with Clear, at the top of a form that was
/// filled back in from a kept copy.
struct DraftNotice: View {

    /// What Clear does: the form empties itself and takes the copy away.
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(Theme.leaf)
                .accessibilityHidden(true)
            Text("Carried on from typedBefore")
                .font(.body)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Clear", action: onClear)
                .buttonStyle(QuietGlassButton())
                .accessibilityHint("Empties the form and forgets what was typed before")
        }
    }
}

// MARK: - A swipe from the left edge

extension View {

    /// On an iPhone or iPad, a swipe from this view's left edge does
    /// `back`, with the view following the finger. For a step inside a
    /// sheet, where iOS's own swipe back has nothing to go back to.
    /// `isOn` false leaves the view as it is. On a Mac nothing changes:
    /// Esc presses the Back button there.
    func edgeSwipeBack(_ isOn: Bool = true, perform back: @escaping () -> Void) -> some View {
        modifier(EdgeSwipeBack(isOn: isOn, back: back))
    }
}

private struct EdgeSwipeBack: ViewModifier {

    let isOn: Bool
    let back: () -> Void

    /// How far the finger has dragged the view to the right.
    @State private var across: CGFloat = 0

    /// How far the finger must travel to go back, in points, unless it
    /// is flicked.
    private let needed: CGFloat = 90

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            // `offset` draws the view somewhere else without moving
            // anything around it, so it slides with the finger.
            .offset(x: across)
            .overlay(alignment: .leading) {
                if isOn {
                    // A strip down the left edge, as wide as a fingertip
                    // and clear, that only a drag starting there reaches.
                    // Taps and scrolls everywhere else are left alone.
                    Color.clear
                        .frame(width: 22)
                        .frame(maxHeight: .infinity)
                        .contentShape(.rect)
                        .gesture(drag)
                        .accessibilityHidden(true)
                }
            }
        #else
        content
        #endif
    }

    #if os(iOS)
    private var drag: some Gesture {
        // `.global` measures in the screen's own points, which do not
        // move when the view itself is slid along.
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { drag in
                // Only a drag more across than down moves the view.
                guard abs(drag.translation.width) > abs(drag.translation.height) else { return }
                across = max(0, drag.translation.width)
            }
            .onEnded { drag in
                // A flick counts even if it was short: the predicted end
                // is where the finger was heading.
                let goes = drag.translation.width > needed || drag.predictedEndTranslation.width > needed * 2.5
                if goes {
                    // Back at once, and the view put straight without
                    // sliding, since what it showed is being replaced.
                    var noSlide = Transaction()
                    noSlide.disablesAnimations = true
                    withTransaction(noSlide) { across = 0 }
                    withAnimation(.smooth(duration: 0.25)) { back() }
                } else {
                    withAnimation(.spring(duration: 0.25)) { across = 0 }
                }
            }
    }
    #endif
}
