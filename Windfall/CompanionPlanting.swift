//
//  CompanionPlanting.swift
//  Windfall
//
//  The 2,777-row companion matrix, finally doing something.
//
//  As a spreadsheet it's a lookup table you have to remember to consult.
//  In the app it can watch what you're actually planting and speak up —
//  which is the difference between having the data and using it.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Model

enum CompanionEffect: String, Codable, CaseIterable, Identifiable {
    case beneficial
    case detrimental
    case neutral

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beneficial:  return "Good together"
        case .detrimental: return "Keep apart"
        case .neutral:     return "No strong effect"
        }
    }

    var colour: Color {
        switch self {
        case .beneficial:  return .green
        case .detrimental: return .red
        case .neutral:     return .secondary
        }
    }

    var symbolName: String {
        switch self {
        case .beneficial:  return "checkmark.circle"
        case .detrimental: return "xmark.circle"
        case .neutral:     return "minus.circle"
        }
    }

    /// The sheet marks these with + and −.
    static func parse(_ text: String?) -> CompanionEffect {
        guard let text = text?.trimmingCharacters(in: .whitespaces) else { return .neutral }
        if text.hasPrefix("+") || text.lowercased().contains("benefi") { return .beneficial }
        if text.hasPrefix("-") || text.hasPrefix("−")
            || text.lowercased().contains("detri") || text.lowercased().contains("avoid") {
            return .detrimental
        }
        return .neutral
    }
}

@Model
final class CompanionPair {

    var id: UUID = UUID()

    var plantOneName: String = ""
    var plantTwoName: String = ""
    var effectRaw: String = CompanionEffect.neutral.rawValue
    var mechanism: String?      // how it impacts
    var notes: String?

    var lastSyncedAt: Date?

    init() {}

    var effect: CompanionEffect {
        get { CompanionEffect(rawValue: effectRaw) ?? .neutral }
        set { effectRaw = newValue.rawValue }
    }

    /// The relationship is symmetric, so a lookup must check both columns.
    func involves(_ name: String) -> Bool {
        let needle = name.lowercased()
        return plantOneName.lowercased() == needle || plantTwoName.lowercased() == needle
    }

    func partner(of name: String) -> String? {
        let needle = name.lowercased()
        if plantOneName.lowercased() == needle { return plantTwoName }
        if plantTwoName.lowercased() == needle { return plantOneName }
        return nil
    }
}

// MARK: - Checking a bed

enum CompanionChecker {

    struct Finding: Identifiable {
        let id = UUID()
        let plantA: String
        let plantB: String
        let effect: CompanionEffect
        let mechanism: String?
    }

    /// Every meaningful relationship among the plants currently in a bed.
    static func check(bed: Bed, against pairs: [CompanionPair]) -> [Finding] {
        let growing = bed.orderedSections
            .flatMap { $0.plantings ?? [] }
            .filter { $0.status != .finished && $0.status != .failed }
            .compactMap { $0.plant?.commonName }

        let unique = Array(Set(growing))
        guard unique.count > 1 else { return [] }

        var findings: [Finding] = []

        for i in 0..<unique.count {
            for j in (i + 1)..<unique.count {
                let a = unique[i], b = unique[j]
                guard let pair = pairs.first(where: {
                    ($0.plantOneName.lowercased() == a.lowercased()
                        && $0.plantTwoName.lowercased() == b.lowercased())
                    || ($0.plantOneName.lowercased() == b.lowercased()
                        && $0.plantTwoName.lowercased() == a.lowercased())
                }) else { continue }

                findings.append(Finding(plantA: a, plantB: b,
                                        effect: pair.effect, mechanism: pair.mechanism))
            }
        }

        // Problems first.
        return findings.sorted { $0.effect == .detrimental && $1.effect != .detrimental }
    }
}

// MARK: - Companion view

struct CompanionView: View {

    let plantName: String

    @Query private var pairs: [CompanionPair]

    private var relevant: [CompanionPair] {
        pairs.filter { $0.involves(plantName) }
    }

    private var good: [CompanionPair] { relevant.filter { $0.effect == .beneficial } }
    private var bad: [CompanionPair] { relevant.filter { $0.effect == .detrimental } }

    var body: some View {
        List {
            if relevant.isEmpty {
                ContentUnavailableView {
                    Label("Nothing recorded", systemImage: "square.on.square.dashed")
                } description: {
                    Text("No companion relationships for \(plantName) in your matrix.")
                }
            }

            if !good.isEmpty {
                Section("Grows well with") {
                    ForEach(good) { pair in
                        companionRow(pair)
                    }
                }
            }

            if !bad.isEmpty {
                Section("Keep apart from") {
                    ForEach(bad) { pair in
                        companionRow(pair)
                    }
                }
            }
        }
        .navigationTitle("Companions")
        .paperScreen()
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private func companionRow(_ pair: CompanionPair) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Image(systemName: pair.effect.symbolName)
                    .foregroundStyle(pair.effect.colour)
                Text(pair.partner(of: plantName) ?? "—")
                    .font(.subheadline)
            }
            if let mechanism = pair.mechanism, !mechanism.isEmpty {
                Text(mechanism)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 24)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Bed check view

struct BedCompanionCheckView: View {

    let bed: Bed

    @Query private var pairs: [CompanionPair]

    private var findings: [CompanionChecker.Finding] {
        CompanionChecker.check(bed: bed, against: pairs)
    }

    var body: some View {
        List {
            if findings.isEmpty {
                ContentUnavailableView {
                    Label("Nothing to flag", systemImage: "checkmark.circle")
                } description: {
                    Text("No known conflicts among what's growing in \(bed.name).")
                }
            }

            ForEach(findings) { finding in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: finding.effect.symbolName)
                            .foregroundStyle(finding.effect.colour)
                        Text("\(finding.plantA) and \(finding.plantB)")
                            .font(.subheadline)
                    }
                    if let mechanism = finding.mechanism {
                        Text(mechanism)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 24)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("\(bed.name) companions")
        .paperScreen()
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
