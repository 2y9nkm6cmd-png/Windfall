//
//  FungusKeyView.swift
//  Windfall
//
//  The fungus key on screen: one question at a time, with a diagram
//  beside each choice, ending at a group you can add as a sighting.
//
//  This file is only what you see. The rules are in FungusKey.swift,
//  where they are tested, and the words are in FungusKey.json.
//
//    FungusKeyView     the page: its heading, the trail and whatever
//                      the walk has reached
//    FungusChoiceRow   one choice at a step: its diagram and its words
//    FungusAnswerCard  where a walk ends: what to check, the common
//                      kinds, any danger and what it means in a garden
//
//  Any key of the FungusKey shape can be shown: Windfall's own, John
//  Wright's if his file is in the app, or the sample (FungusKeys).
//
//  Reached from Identify in the sidebar on a Mac or an iPad, and from
//  Wildlife, Fungus keys on an iPhone (IdentifyViews.swift).
//

import SwiftUI
import SwiftData

struct FungusKeyView: View {

    /// The database, so that "Add a sighting" has somewhere to put it.
    @Environment(\.modelContext) private var context

    /// `@State` is a value the screen owns. When it changes, SwiftUI
    /// draws the screen again. Every tap changes `walk`, which is how
    /// the next question appears.
    @State private var walk: FungusWalk

    /// The key being stepped through.
    let key: FungusKey?

    /// William's switch on the Identify page. Off unless he turns it on,
    /// and it only ever matters for a key whose author allowed verdicts.
    @AppStorage("showsKeyVerdicts") private var showsVerdicts = false

    /// `openingAt` is for the checking aid `-demoFungus` (DemoGarden),
    /// which opens the key at one step or answer for a still picture.
    /// Left out, the key opens at its first question.
    ///
    /// A `@State` value is given its first value through the name with
    /// an underscore, `_walk`, because `walk` itself is only the value
    /// and the underscore name is the box that holds it.
    ///
    /// `key` is Windfall's own unless another is given.
    init(key: FungusKey? = FungusKey.shared, openingAt place: String? = nil) {
        self.key = key
        let start = key?.start ?? "start"
        let isKnown = place.map { key?.step($0) != nil || key?.answer($0) != nil } ?? false
        _walk = State(initialValue: isKnown ? FungusWalk(start: start, openingAt: place ?? start) : FungusWalk(start: start))
    }

    /// The answer a sighting has already been added for, so that the
    /// button cannot add the same one twice.
    @State private var addedFor: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: key?.displayTitle ?? FungusKeys.ownTitle, detail: headerDetail)
                if let key {
                    if key.isSample { sampleNotice } else if !key.isChecked { toCheck(key) }
                    trail
                    // `step(_:)` gives a step if `here` is one, and
                    // `answer(_:)` an answer if it is one of those.
                    if let step = key.step(walk.here) {
                        stepView(step, in: key)
                    } else if let answer = key.answer(walk.here) {
                        answerView(answer, in: key)
                    }
                    if let credit = key.credit, !key.isSample { creditLine(credit) }
                } else {
                    Text("The fungus key could not be read.")
                        .font(.body)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            // Reads best in a column, not across a wide window.
            .frame(maxWidth: 640, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(key?.displayTitle ?? FungusKeys.ownTitle)
        // Tells Eira what is open (piece 1, project doc 119). See EiraScreen.swift.
        .eiraLooksAt("the fungus key called \(key?.displayTitle ?? FungusKeys.ownTitle), which asks about a fungus one question at a time",
                     short: key?.displayTitle ?? FungusKeys.ownTitle)
        .paperScreen()
    }

    // MARK: The pieces of the page

    /// The line under the title.
    private var headerDetail: String {
        guard let key, let credit = key.credit else { return "Step by step to a group, for a record" }
        if key.isSample { return "A sample, to try a key that goes to species" }
        return "By \(credit.author), from \(credit.work)"
    }

    /// Shown until the key's file says "checked": true.
    private func toCheck(_ key: FungusKey) -> some View {
        Label(key.isOwn
              ? "To check: Claude wrote this key from memory. Read each answer against a field guide before relying on it."
              : "To check: this copy has not yet been read against the author's own key.",
              systemImage: "exclamationmark.triangle")
            .font(.footnote)
            .foregroundStyle(Theme.inkSoft)
    }

    /// Shown on the sample, always, so it is never taken for a real key.
    private var sampleNotice: some View {
        Label("Sample: Claude wrote this to show how a key that goes to species would work. It is nobody's real key and has not been checked.",
              systemImage: "exclamationmark.triangle")
            .font(.footnote.weight(.medium))
            .foregroundStyle(Theme.ink)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.10), in: .rect(cornerRadius: 12))
    }

    /// Whose key it is, at the foot of every step. `Link` opens a web
    /// address in the browser.
    private func creditLine(_ credit: FungusKey.Credit) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Key by \(credit.author), from \(credit.work), with his permission.")
            if let terms = credit.terms { Text(terms) }
            if let link = credit.link, let url = URL(string: link) {
                Link("See the original", destination: url)
                    .tint(Theme.leaf)
            }
        }
        .font(.footnote)
        .foregroundStyle(Theme.inkSoft)
        .padding(.top, 6)
    }

    /// The choices taken so far, as small buttons. Pressing one goes
    /// back to that step.
    @ViewBuilder
    private var trail: some View {
        if !walk.isAtStart {
            ChipFlow(spacing: 6) {
                // `enumerated()` hands back each item with its place in
                // the list, which is what `back(to:)` needs.
                ForEach(Array(walk.taken.enumerated()), id: \.offset) { place, taken in
                    Button {
                        move { walk.back(to: place) }
                    } label: {
                        Text(taken.choice)
                            .font(.footnote)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.leafFill, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to: \(taken.choice)")
                }
            }
        }
    }

    private func stepView(_ step: FungusKey.Step, in key: FungusKey) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
                Text(step.question)
                    .font(.system(.title2, design: .serif))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            if let help = step.help {
                Text(help)
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 16, padding: 12)
            }
            // Only leave room for diagrams at a step that has some.
            let drawn = step.choices.contains { $0.picture != nil }
            ForEach(step.choices, id: \.self) { choice in
                Button {
                    move { walk.choose(choice, at: step.id) }
                } label: {
                    FungusChoiceRow(choice: choice, leavesRoomForPicture: drawn)
                }
                .buttonStyle(.plain)
            }
            Button {
                move { walk.noneFit(at: step.id, in: key) }
            } label: {
                HStack {
                    Text("None of these fit")
                        .font(.body)
                        .foregroundStyle(Theme.inkSoft)
                    Spacer()
                    WIconView(.chevronRight, size: 16)
                        .foregroundStyle(Theme.inkSoft)
                }
                .padding(14)
                .contentShape(.rect)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Theme.hairline, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
            }
            .buttonStyle(.plain)
            if !walk.isAtStart { backButtons }
        }
    }

    private func answerView(_ answer: FungusKey.Answer, in key: FungusKey) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            FungusAnswerCard(answer: answer, footer: key.footer,
                             verdictHeading: key.mayShowVerdicts && showsVerdicts ? verdictHeading(for: key) : nil,
                             from: key.isSample ? nil : key.credit?.work)
            if let name = key.sightingName(for: answer) {
                if addedFor == answer.id {
                    Label("Added to your sightings as \"\(name)\", not confirmed.", systemImage: "checkmark.circle")
                        .font(.body)
                        .foregroundStyle(Theme.ink)
                } else {
                    Button {
                        addSighting(of: answer, named: name, in: key)
                    } label: {
                        Text("Add a sighting")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .tint(Theme.leaf)
                    .foregroundStyle(Theme.onLeaf)
                }
            }
            backButtons
        }
    }

    /// "John Wright's verdict", or a plain heading on the sample.
    private func verdictHeading(for key: FungusKey) -> String {
        guard let author = key.credit?.author, !key.isSample else { return "The author's verdict" }
        return "\(author)'s verdict"
    }

    private var backButtons: some View {
        HStack(spacing: 10) {
            Button("Back") { move { walk.back() } }
            Button("Start again") { move { walk.startAgain() } }
        }
        .buttonStyle(QuietGlassButton())
    }

    // MARK: What the buttons do

    /// Changes the walk with a short fade, and forgets any "Added"
    /// line, which belonged to the answer being left.
    private func move(_ change: () -> Void) {
        withAnimation(.easeInOut(duration: 0.18)) {
            change()
            addedFor = nil
        }
    }

    /// Starts an unconfirmed sighting from an answer. The name goes
    /// into `provisionalID`, never `confirmedID`, as with a photo match
    /// (EiraIdentify.startSighting), and the steps taken go into the
    /// notes so the record shows how the name was reached.
    private func addSighting(of answer: FungusKey.Answer, named name: String, in key: FungusKey) {
        let observation = WildlifeObservation()
        observation.recorderName = UserDefaults.standard.string(forKey: "recorderName")
        observation.taxonGroup = key.taxonGroup(for: answer)
        observation.provisionalID = name
        observation.provisionalSource = .key
        observation.provisionalConfidence = .possible
        observation.notes = walk.note(reaching: answer, keyName: key.displayTitle)
        context.insert(observation)
        withAnimation { addedFor = answer.id }
    }
}

// MARK: - One choice

/// One choice at a step: its diagram, its words and an arrow.
private struct FungusChoiceRow: View {

    let choice: FungusKey.Choice
    /// True when any choice at this step has a diagram, so that the
    /// words of all of them line up.
    let leavesRoomForPicture: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if leavesRoomForPicture {
                Group {
                    if let picture = choice.picture {
                        // The build script made this picture from
                        // Design/Icons/fungus-<name>.svg. It is a colour
                        // drawing, shown as drawn, with a pale outline
                        // of its own for dark mode.
                        Image("Icons/fungus-\(picture)")
                            .resizable()
                            .scaledToFit()
                            // The words beside it say what it shows.
                            .accessibilityHidden(true)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 76, height: 76)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(choice.text)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                if let detail = choice.detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            WIconView(.chevronRight, size: 16)
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .glassCard(cornerRadius: 18, padding: 12)
    }
}

// MARK: - An answer

/// Where a walk ends.
private struct FungusAnswerCard: View {

    let answer: FungusKey.Answer
    let footer: String
    /// The heading over the author's verdict when it is to be shown,
    /// otherwise nil.
    let verdictHeading: String?
    /// Where his key comes from, for the line under his verdict.
    let from: String?

    /// The heading over the list of features, which is a list of steps
    /// for "Take a spore print first".
    private var listHeading: String {
        switch answer.rank {
        case "How to":    return "Steps"
        case "No answer": return "What to do"
        default:          return "Check that it fits"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(answer.rank)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
                Text(answer.name)
                    .font(.system(.title, design: .serif))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                if !answer.latin.isEmpty {
                    Text(answer.latin)
                        .font(.body)
                        .italic()
                        .foregroundStyle(Theme.inkSoft)
                }
            }

            section(listHeading) {
                ForEach(answer.confirm, id: \.self) { line in bullet(line) }
            }

            if let examples = answer.examples, !examples.isEmpty {
                section("Common kinds") {
                    ForEach(examples, id: \.self) { line in bullet(line) }
                }
            }

            if let notes = answer.notes {
                Text(notes)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
            }

            // In plain sight: the same orange box as the carrot-family
            // warning on a photo match (IdentifyCards.swift).
            if let danger = answer.danger {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(danger)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.ink)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.14), in: .rect(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.orange.opacity(0.55))
                }
                .accessibilityElement(children: .combine)
            }

            if let garden = answer.garden {
                VStack(alignment: .leading, spacing: 4) {
                    Text("In the garden")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(garden)
                        .font(.body)
                        .foregroundStyle(Theme.ink)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.leafFill.opacity(0.6), in: .rect(cornerRadius: 12))
            }

            // Kept apart from everything else, grey, and always with the
            // reminder beneath it: the words are his, not Windfall's.
            if let heading = verdictHeading, let verdict = answer.verdict {
                VStack(alignment: .leading, spacing: 4) {
                    Text(heading)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(verdict)
                        .font(.body)
                        .foregroundStyle(Theme.ink)
                    Text("His words\(from.map { ", from \($0)" } ?? ""). Windfall never says whether a fungus can be eaten. Never eat one on a key's word alone.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Theme.hairline)
                }
                .accessibilityElement(children: .combine)
            }

            Text(footer)
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    /// A small heading with whatever is put beneath it. `@ViewBuilder`
    /// lets the caller write views inside the braces, as with a VStack.
    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
            content()
        }
    }

    private func bullet(_ line: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(Theme.leaf)
                .frame(width: 5, height: 5)
                // Lifts the dot to the middle of the first line.
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] + 4 }
            Text(line)
                .font(.body)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
