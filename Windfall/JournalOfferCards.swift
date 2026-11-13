//
//  JournalOfferCards.swift
//  Windfall
//
//  Eira's offers in the journal's conversation: "Add a harvest?" and
//  "Add a sowing?".
//
//  JournalOffers.swift reads what was written and decides what it might
//  describe. Each offer is shown here as a card with what was understood
//  already filled in. Anything on the card can be changed first.
//
//  Nothing is saved until Add is pressed. Pressing the other button
//  takes the card away and saves nothing.
//

import SwiftUI
import SwiftData

// MARK: - The frame

/// What both cards share: Eira's snowdrop beside a card with a heading,
/// the card's own rows and two buttons.
private struct OfferFrame<Content: View>: View {

    private let heading: String
    private let refuseTitle: String
    private let canAdd: Bool
    private let onAdd: () -> Void
    private let onRefuse: () -> Void
    private let content: () -> Content

    init(_ heading: String,
         refuseTitle: String,
         canAdd: Bool,
         onAdd: @escaping () -> Void,
         onRefuse: @escaping () -> Void,
         @ViewBuilder content: @escaping () -> Content) {
        self.heading = heading
        self.refuseTitle = refuseTitle
        self.canAdd = canAdd
        self.onAdd = onAdd
        self.onRefuse = onRefuse
        self.content = content
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            EiraSymbol(size: 28)

            VStack(alignment: .leading, spacing: 10) {
                Text(heading)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)

                content()
                    .font(.subheadline)

                HStack(spacing: 8) {
                    Button("Add") { onAdd() }
                        .buttonStyle(.glassProminent)
                        .tint(Theme.leaf)
                        .foregroundStyle(Theme.onLeaf)
                        .disabled(!canAdd)
                    Button(refuseTitle) { onRefuse() }
                        .buttonStyle(.glass)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card.opacity(0.85), in: .rect(cornerRadius: 16))
            // A green edge marks it out as something to answer.
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Theme.leaf.opacity(0.6))
            }
        }
    }
}

/// A number as it would be typed: "50", not "50.0".
private func plainNumber(_ value: Double) -> String {
    value == value.rounded() ? String(Int(value)) : String(value)
}

// MARK: - A harvest

/// "Add a harvest?"
struct HarvestOfferCard: View {

    private let candidates: [Plant]
    private let date: Date
    private let onAdd: (String) -> Void
    private let onDismiss: () -> Void

    @Environment(\.modelContext) private var context

    @State private var plant: Plant
    /// The sowing or planting the harvest came from. Nil when the plant
    /// has none on record, in which case one is made.
    @State private var planting: Planting?
    @State private var amount: String
    @State private var unit: HarvestUnit
    @State private var destination: HarvestDestination

    /// - `candidates`: the plants it might be, likeliest first. There
    ///   must be at least one.
    /// - `date`: when the journal entry was stamped.
    /// - `onAdd`: called once the harvest is saved, with a line for Eira
    ///   to say.
    init(offer: RecordOffer, candidates: [Plant], date: Date,
         onAdd: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
        self.candidates = candidates
        self.date = date
        self.onAdd = onAdd
        self.onDismiss = onDismiss
        let likeliest = candidates[0]
        // `_plant` is the storage behind `@State var plant`. This is how
        // a starting value is handed to it.
        _plant = State(initialValue: likeliest)
        _planting = State(initialValue: Self.growing(of: likeliest).first)
        _amount = State(initialValue: offer.quantity.map { plainNumber($0) } ?? "")
        _unit = State(initialValue: offer.unit ?? .kilograms)
        _destination = State(initialValue: offer.destination ?? .eaten)
    }

    /// A plant's sowings and plantings that could be giving a crop,
    /// newest first.
    private static func growing(of plant: Plant) -> [Planting] {
        (plant.plantings ?? [])
            .filter { $0.status != .finished && $0.status != .failed && $0.status != .planned }
            .sorted { ($0.dateSown ?? .distantPast) > ($1.dateSown ?? .distantPast) }
    }

    /// "Sown 9 November, Bed 3"
    private static func words(for planting: Planting) -> String {
        var text = planting.dateSown.map { "Sown \($0.formatted(.dateTime.day().month(.wide)))" } ?? "On record"
        if !planting.bedNames.isEmpty { text += ", \(planting.bedNames)" }
        return text
    }

    var body: some View {
        let sources = Self.growing(of: plant)

        OfferFrame("Add a harvest?",
                   refuseTitle: "Not a harvest",
                   canAdd: Double(amount) != nil,
                   onAdd: add,
                   onRefuse: onDismiss) {
            SettingRow("What") {
                if candidates.count > 1 {
                    // Only a common name was written, such as "apples",
                    // and more than one plant has it.
                    Picker("Plant", selection: $plant) {
                        ForEach(candidates) { candidate in
                            Text(candidate.displayName).tag(candidate)
                        }
                    }
                    .labelsHidden()
                } else {
                    Text(plant.displayName)
                        .foregroundStyle(Theme.ink)
                }
            }

            SettingRow("How much") {
                FieldBox {
                    TextField("0", text: $amount)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
                Picker("Unit", selection: $unit) {
                    ForEach(HarvestUnit.allCases) { measure in
                        Text(measure.displayName).tag(measure)
                    }
                }
                .labelsHidden()
            }

            SettingRow("Where it went") {
                Picker("Where it went", selection: $destination) {
                    ForEach(HarvestDestination.allCases) { place in
                        Text(place.words).tag(place)
                    }
                }
                .labelsHidden()
            }

            // A harvest is always recorded against a sowing or planting.
            if sources.isEmpty {
                Text("Nothing is on record as sown or planted for it. Adding this will put it on record as growing, so the harvest has somewhere to go.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            } else if sources.count == 1, let only = sources.first {
                Text("From: \(Self.words(for: only)).")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            } else {
                SettingRow("From") {
                    Picker("From", selection: $planting) {
                        ForEach(sources) { source in
                            Text(Self.words(for: source)).tag(Planting?.some(source))
                        }
                    }
                    .labelsHidden()
                }
            }
        }
        .onChange(of: plant) { _, chosen in
            planting = Self.growing(of: chosen).first
        }
    }

    private func add() {
        guard let value = Double(amount) else { return }

        var source = planting
        if source == nil {
            // No sowing or planting on record, as with a tree that was
            // here before the app. One is made, marked as cropping, with
            // a note saying where it came from.
            let freshPlanting = Planting()
            freshPlanting.plant = plant
            freshPlanting.status = .harvesting
            freshPlanting.notes = "Put on record from the journal when its first harvest was added. When it was sown or planted is not known."
            context.insert(freshPlanting)
            source = freshPlanting
        }
        guard let source else { return }

        let harvest = Harvest()
        harvest.date = date
        harvest.quantity = value
        harvest.unit = unit
        harvest.destination = destination
        harvest.planting = source
        source.harvests?.append(harvest)
        if source.status == .growing || source.status == .plantedOut {
            source.status = .harvesting
        }

        onAdd("Added a harvest: \(plainNumber(value)) \(unit.displayName) of \(plant.displayName).")
    }
}

// MARK: - A sowing

/// "Add a sowing?"
struct SowingOfferCard: View {

    private let candidates: [Plant]
    private let beds: [Bed]
    private let date: Date
    private let onAdd: (String) -> Void
    private let onDismiss: () -> Void

    @Environment(\.modelContext) private var context

    @State private var plant: Plant
    @State private var bed: Bed?
    @State private var sownWhere: SowingLocation
    @State private var quantity: String

    /// As for the harvest card. `beds` are the beds to choose from.
    init(offer: RecordOffer, candidates: [Plant], beds: [Bed], date: Date,
         onAdd: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
        self.candidates = candidates
        self.beds = beds
        self.date = date
        self.onAdd = onAdd
        self.onDismiss = onDismiss
        _plant = State(initialValue: candidates[0])
        _bed = State(initialValue: beds.first { $0.id.uuidString == offer.bedKey })
        _sownWhere = State(initialValue: offer.sownWhere ?? .outdoors)
        _quantity = State(initialValue: offer.quantity.map { plainNumber($0) } ?? "")
    }

    var body: some View {
        OfferFrame("Add a sowing?",
                   refuseTitle: "Not a sowing",
                   canAdd: true,
                   onAdd: add,
                   onRefuse: onDismiss) {
            SettingRow("What") {
                if candidates.count > 1 {
                    Picker("Plant", selection: $plant) {
                        ForEach(candidates) { candidate in
                            Text(candidate.displayName).tag(candidate)
                        }
                    }
                    .labelsHidden()
                } else {
                    Text(plant.displayName)
                        .foregroundStyle(Theme.ink)
                }
            }

            SettingRow("Where") {
                Picker("Bed", selection: $bed) {
                    Text("Not placed").tag(Bed?.none)
                    ForEach(beds) { wholeBed in
                        // The words do not say which part of a bed, so
                        // the whole bed is offered. The sections can be
                        // put right from the sowing's own page.
                        Text("All of \(wholeBed.name)").tag(Bed?.some(wholeBed))
                    }
                }
                .labelsHidden()
            }

            SettingRow("Sown") {
                Picker("Sown", selection: $sownWhere) {
                    ForEach(SowingLocation.allCases) { place in
                        Text(place.words).tag(place)
                    }
                }
                .labelsHidden()
            }

            SettingRow("How many") {
                FieldBox {
                    TextField("seeds", text: $quantity)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }
            }
        }
    }

    private func add() {
        let planting = Planting()
        planting.plant = plant
        planting.dateSown = date
        planting.sowingLocation = sownWhere
        planting.status = .sown
        planting.quantitySown = Int(quantity)

        // If it has been sown before this year, this is the next round,
        // as it would be from the sowing form.
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let sownThisYear = (plant.plantings ?? []).filter { earlier in
            earlier.dateSown.map { calendar.component(.year, from: $0) == year } ?? false
        }
        planting.successionRound = sownThisYear.isEmpty ? nil : sownThisYear.count + 1

        if let bed {
            planting.sections = bed.orderedSections
        }
        context.insert(planting)

        onAdd("Added a sowing: \(plant.displayName)\(bed.map { " in \($0.name)" } ?? "").")
    }
}
