//
//  PlantingGuideCard.swift
//  Windfall
//
//  "How to grow": the planting guide, the first card on a plant's page,
//  the full width of the page. What goes on it is worked out in
//  PlantingGuide.swift; Eira's reading of the notes is asked for in
//  PlantingGuideMaker.swift. (William, 21 November 2026: his partner
//  wants the notes for planting "front and centre", with the full notes
//  still there to read and change. Project doc 150.)
//

import SwiftUI

struct PlantingGuideCard: View {

    /// The plant. A SwiftData record redraws whatever reads it when it
    /// changes, so the card fills in by itself once Eira has read.
    let plant: Plant
    /// Opens the full notes (the same sheet as the Notes button).
    let onOpenNotes: () -> Void

    /// The notes' fingerprint when Eira last tried to read them on this
    /// page. If she tried and kept nothing (a failure), the card stops
    /// saying she is reading.
    @State private var triedKey: String?

    var body: some View {
        let key = PlantingGuide.notesKey(plant.notes)
        let notesGuide = PlantingGuide.stored(on: plant)
        let guide = PlantingGuide.guide(for: plant, reading: notesGuide)
        let hasNotes = !(plant.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let canRead = PlantingGuideMaker.canRead
        let isReading = PlantingGuide.needsReading(plant) && canRead && triedKey != key

        // Left out altogether for a plant with no sowing facts and no notes.
        if !guide.isEmpty || hasNotes {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("How to grow")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 8)
                    if hasNotes {
                        Button(action: onOpenNotes) {
                            Label("Full notes", systemImage: "note.text")
                        }
                        .buttonStyle(QuietGlassButton())
                    }
                }

                if !guide.lines.isEmpty {
                    // Two columns that line up down the card: the name of
                    // each line, then what it says. `Grid` sizes the first
                    // column to its longest name.
                    Grid(alignment: .topLeading, horizontalSpacing: 14, verticalSpacing: 8) {
                        ForEach(guide.lines) { line in
                            GridRow {
                                HStack(spacing: 4) {
                                    Text(line.label)
                                        .font(.callout)
                                        .foregroundStyle(Theme.inkSoft)
                                    if line.fromNotes { eiraMark }
                                }
                                Text(line.text)
                                    .font(.body)
                                    .foregroundStyle(Theme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                if !guide.tips.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text("Tips from the notes")
                                .font(.callout)
                                .foregroundStyle(Theme.inkSoft)
                            eiraMark
                        }
                        ForEach(guide.tips, id: \.self) { tip in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: "leaf")
                                    .font(.caption)
                                    .foregroundStyle(Theme.leaf)
                                    .accessibilityHidden(true)
                                Text(tip)
                                    .font(.body)
                                    .foregroundStyle(Theme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                if isReading {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Eira is reading the notes…")
                            .font(.callout)
                            .foregroundStyle(Theme.inkSoft)
                    }
                } else if hasNotes && notesGuide == nil {
                    Text(canRead
                         ? "Eira could not read the notes this time. She will try again next time this page opens."
                         : "On a device with Apple Intelligence, Eira reads the notes into this guide. Until then, the full notes are under Full notes.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if guide.hasEiraLines {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        eiraMark
                        Text("Read from the notes by Eira. Check anything important against the full notes.")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
            // Runs when the card appears, and again whenever the notes
            // change (`id:` is the notes' fingerprint). Eira reads only
            // if these notes have not been read before.
            .task(id: key) {
                await PlantingGuideMaker.readNotes(of: plant)
                triedKey = key
            }
        }
    }

    /// The small mark on whatever Eira read from the notes.
    private var eiraMark: some View {
        Image(systemName: "sparkle")
            .font(.caption2)
            .foregroundStyle(Theme.leaf)
            .accessibilityLabel("Read by Eira")
    }
}
