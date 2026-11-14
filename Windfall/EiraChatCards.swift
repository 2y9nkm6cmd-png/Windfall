//
//  EiraChatCards.swift
//  Windfall
//
//  Three pieces of Eira's chat screen (14 November 2026).
//
//    ThinkingBubble    everything she did on the way to a reply, in one
//                      small closed bubble. Tap it to see each lookup,
//                      and tap a lookup to see what came back.
//    ChatPlantLinks    a card for each plant from your library that her
//                      lookups found. Tap one to open the plant's page.
//    EiraChatText      shows **bold** and *italic* as bold and italic,
//                      where the screen used to show the asterisks.
//
//  What goes in the bubble and which plants get a card is worked out in
//  EiraChatLayout.swift, which has no screen code and is tested.
//

import SwiftUI
import SwiftData

// MARK: - The bubble

/// What Eira did before answering: her lookups, and her reasoning if
/// the model gives any. Closed until tapped.
///
/// William, 14 November 2026: "The searches that it does to present me
/// with an answer should be in a closed 'thinking' bubble, unless you
/// tap it to see what it's doing."
struct ThinkingBubble: View {

    /// The lookups, oldest first.
    let lookups: [ChatMessage]
    /// The model's own thinking. Apple's built-in model gives none.
    var reasoning: String? = nil
    /// True while the reply is still being written.
    var isLive = false

    // `@State` is a value the view keeps for itself between redraws.
    // `private` means nothing outside this view can change it.
    /// Whether the bubble is open. It starts closed. The one exception
    /// is a checking aid, `-demoOpen eira-lookups-open`, which starts it
    /// open, because a script cannot tap it for a still picture.
    @State private var isOpen = DemoGarden.opens == "eira-lookups-open"
    /// Which lookups inside it are open, by id.
    @State private var openLookups: Set<UUID> = []

    private var hasReasoning: Bool {
        !(reasoning ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The words on the closed bubble.
    private var heading: String {
        if isLive { return "Thinking…" }
        return EiraChatLayout.summary(lookups: lookups.count, hasReasoning: hasReasoning)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                // `withAnimation` makes the change that follows slide
                // open, where it would otherwise jump.
                withAnimation(.snappy(duration: 0.25)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 8) {
                    if isLive {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.caption)
                    }
                    Text(heading)
                        .font(.caption.weight(.medium))
                    // While she works, the newest lookup is named beside
                    // "Thinking…", so the bubble shows progress closed.
                    if isLive, !isOpen, let newest = lookups.last {
                        Text(EiraChatLayout.title(forLookup: newest.toolName))
                            .font(.caption)
                            .lineLimit(1)
                    }
                    // Open, the bubble is as wide as the chat. Closed,
                    // it is only as wide as its words.
                    if isOpen { Spacer(minLength: 0) }
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .foregroundStyle(Theme.inkSoft)
                // Makes the whole row take the tap, gaps included.
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(heading)
            .accessibilityHint(isOpen ? "Hides what Eira did" : "Shows what Eira did")

            if isOpen {
                ForEach(lookups) { lookup in
                    lookupRow(lookup)
                }
                if hasReasoning, let reasoning {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Her reasoning")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.ink)
                        Text(reasoning)
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.card.opacity(0.55), in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.hairline, lineWidth: 1)
        }
        // The same checking aid also opens the first lookup, so the
        // picture shows what a lookup brought back.
        .onAppear {
            if DemoGarden.opens == "eira-lookups-open", let first = lookups.first {
                openLookups.insert(first.id)
            }
        }
    }

    /// One lookup inside the open bubble: what it was and where it
    /// looked. Tapped, it shows what came back.
    private func lookupRow(_ lookup: ChatMessage) -> some View {
        let result = EiraChatLayout.parts(ofResult: lookup.content)
        let showsResult = openLookups.contains(lookup.id)

        return VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    // A Set holds each id once. This adds it if it is
                    // missing and takes it out if it is there.
                    if showsResult { openLookups.remove(lookup.id) } else { openLookups.insert(lookup.id) }
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption2)
                        .foregroundStyle(Theme.leaf)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(EiraChatLayout.title(forLookup: lookup.toolName))
                            .font(.caption)
                            .foregroundStyle(Theme.ink)
                        if let source = result.source {
                            Text(source)
                                .font(.caption2)
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSoft)
                        .rotationEffect(.degrees(showsResult ? 90 : 0))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if showsResult {
                // Monospaced, because results are lines of plain data.
                // The lookup's code name is given last, for when a
                // lookup needs chasing in the code.
                Text(result.found + (lookup.toolName.map { "\n\n(\($0))" } ?? ""))
                    .font(.caption.monospaced())
                    .foregroundStyle(Theme.inkSoft)
                    .textSelection(.enabled)
                    .padding(.leading, 22)
            }
        }
    }
}

// MARK: - Plant cards

/// A card for each plant from your library that a reply's lookups
/// found. Tapping one opens the plant's own page.
///
/// William, 14 November 2026: "This kind of search should also present
/// you to a link to the database information you have as a little card."
///
/// The card is the one the Plants page uses (PlantCardView), so a plant
/// looks the same in both places, and anything added to that card later
/// (a drawing of the plant, say) appears here too.
///
/// This view does not open the page itself. It calls `onOpen` with the
/// plant, and the chat screen opens the page as a sheet. That works
/// wherever the chat is drawn: as a sheet on an iPhone, and in the panel
/// that grows out of Eira's bar on a Mac or an iPad, where there is no
/// stack of pages for a plant's page to be pushed on to.
struct ChatPlantLinks: View {

    let lookups: [ChatMessage]
    /// Called with the plant whose card was tapped. A closure is a
    /// piece of code handed in from outside, here by the chat screen.
    let onOpen: (Plant) -> Void

    /// No more cards than this under one reply. A search for "apple"
    /// can find six plants, which would bury the answer.
    private let mostCards = 3

    // `@Query` reads every plant from the database and keeps the list
    // up to date.
    @Query(sort: \Plant.commonName) private var library: [Plant]

    var body: some View {
        let names = EiraChatLayout.plantNames(foundBy: lookups, among: library.map(\.displayName))
        // `compactMap` turns each name back into its plant, dropping
        // any name that somehow finds none.
        let found = names.compactMap { name in library.first { $0.displayName == name } }
        let month = Calendar.current.component(.month, from: .now)

        if !found.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("In your plant library")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)

                ForEach(Array(found.prefix(mostCards))) { plant in
                    Button {
                        onOpen(plant)
                    } label: {
                        PlantCardView(plant: plant, month: month)
                    }
                    // `.plain` stops the button tinting the card blue.
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens this plant's page")
                }

                if found.count > mostCards {
                    Text("and \(found.count - mostCards) more, on the Plants page")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
    }
}

// MARK: - Bold and italic

enum EiraChatText {

    /// A reply ready to show, with its bold and italic marks obeyed.
    ///
    /// Models write `**bold**` and `*italic*`, a notation called
    /// Markdown. Shown as plain text, the asterisks appear on screen.
    /// `AttributedString` is text that carries its own styling, and
    /// Apple's reader turns the marks into that styling.
    ///
    /// `inlineOnlyPreservingWhitespace` reads bold, italic and links
    /// and leaves line breaks and everything else exactly as written.
    /// If the reader cannot make sense of the text, it is shown as it
    /// came.
    static func styled(_ reply: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: reply, options: options)) ?? AttributedString(reply)
    }
}
