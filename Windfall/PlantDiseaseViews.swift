//
//  PlantDiseaseViews.swift
//  Windfall
//
//  The plant disease pages: a list of the common diseases, each with a
//  diagram, and a page for each one.
//
//  Asked for by William on 15 November 2026: "Include diagrams of the
//  diseases too." PlantDiseases.swift says where the words and the
//  diagrams come from, and that none of it has been checked.
//
//  ⚠️ Not built in Xcode when written: made in a cloud workspace, where
//  screens can be checked for spelling but not run.
//

import SwiftUI

/// One disease's diagram, at a size.
struct PlantDiseasePicture: View {
    /// The disease's short name, such as "rust".
    let slug: String
    var size: CGFloat = 56

    var body: some View {
        Image("Diseases/disease-\(slug)")
            // `resizable` lets the picture be drawn at any size, and
            // `scaledToFit` keeps its proportions when it is.
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            // The words beside it say what it is, so VoiceOver skips it.
            .accessibilityHidden(true)
    }
}

// MARK: - The list

struct PlantDiseaseListView: View {

    private let book = PlantDiseases.shared

    var body: some View {
        ScrollView {
            // "Lazy" means a tile is only made when it is about to scroll
            // into view.
            LazyVStack(alignment: .leading, spacing: 10) {
                Text("What each looks like on the plant. Written and drawn by Claude from memory, and not yet checked.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(padding: 14)

                ForEach(book.list) { disease in
                    // Tapping a tile grows that disease's page out of it
                    // (GrowFromTile.swift).
                    GrowingLink {
                        PlantDiseasePage(disease: disease)
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            PlantDiseasePicture(slug: disease.slug, size: 64)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(disease.name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Theme.ink)
                                Text(disease.seen)
                                    .font(.footnote)
                                    .foregroundStyle(Theme.inkSoft)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .glassCard(padding: 14)
                        // Makes the whole tile take the tap.
                        .contentShape(.rect)
                    }
                    // Without this a link tints all its words blue.
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .navigationTitle("Plant diseases")
        .paperScreen()
        .eiraLooksAt("the list of common plant diseases", short: "Plant diseases")
    }
}

// MARK: - One disease

struct PlantDiseasePage: View {

    let disease: PlantDisease

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PlantDiseasePicture(slug: disease.slug, size: 220)
                    .frame(maxWidth: .infinity)
                    .glassCard(padding: 20)

                VStack(alignment: .leading, spacing: 6) {
                    Text(disease.name)
                        .font(.screenTitle)
                        .foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                    StatusTag(text: disease.cause, fill: Theme.leafFill)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                card("What you see", disease.seen)
                card("Plants it is found on", disease.plants)
                card("When", disease.season)
                card("What helps", disease.helps)
                if let note = disease.note {
                    card("Take care", note)
                }
                Text("Written and drawn by Claude from memory. Not yet checked against a reference.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .navigationTitle(disease.name)
        #if os(iOS)
        // The small title in the bar. The large one is on the page itself.
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .paperScreen()
        .eiraLooksAt("the plant disease page for \(disease.name)", short: disease.name)
    }

    /// A glass card with a heading and a paragraph.
    private func card(_ title: String, _ words: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text(words)
                .font(.body)
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 16)
    }
}
