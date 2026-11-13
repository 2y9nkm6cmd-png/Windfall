//
//  CrossViews.swift
//  Windfall
//
//  The screens for crosses: the list, reached from Gardens, and the form
//  for writing one down. The record itself and its sums are in
//  Crosses.swift.
//
//  Both are built from the app's shared pieces (SheetParts.swift and the
//  page pieces in HubScreens.swift), so they look like the rest.
//

import SwiftUI
import SwiftData

// MARK: - The list

struct CrossListView: View {

    @Query(sort: [SortDescriptor(\PlantCross.date, order: .reverse)]) private var crosses: [PlantCross]
    @Query private var plantings: [Planting]
    @Environment(\.modelContext) private var context

    /// The cross being written, while its form is open.
    @State private var fresh: PlantCross?

    var body: some View {
        GeometryReader { geometry in
            let isNarrow = geometry.size.width < 600
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .bottom, spacing: 10) {
                        ScreenHeader(title: "Crosses",
                                     detail: crosses.isEmpty ? "None recorded yet"
                                        : "\(crosses.count) recorded")
                        Button {
                            let crossing = PlantCross()
                            context.insert(crossing)
                            fresh = crossing
                        } label: {
                            Label("New cross", systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.glassProminent)
                        .tint(Theme.leaf)
                        .foregroundStyle(Theme.onLeaf)
                    }

                    if crosses.isEmpty {
                        Text("Write a cross down on the day you make it: which plant carried the seed and whose pollen it had. When you sow the seed next year, the sowing form offers it, so the seedling's parents are on record.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard()
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
                                             count: geometry.size.width >= 840 ? 2 : 1),
                              spacing: 12) {
                        ForEach(crosses) { crossing in
                            NavigationLink {
                                CrossEditor(crossing: crossing)
                            } label: {
                                card(for: crossing)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete", role: .destructive) { context.delete(crossing) }
                            }
                        }
                    }
                }
                .padding(.leading, isNarrow ? 16 : 14)
                .padding(.trailing, isNarrow ? 16 : 24)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Crosses")
        .paperScreen()
        .sheet(item: $fresh) { crossing in
            CrossEditor(crossing: crossing, isNew: true)
        }
    }

    private func card(for crossing: PlantCross) -> some View {
        // How many sowings have been made of this cross's seed.
        let key = crossing.id.uuidString
        let sown = plantings.filter { $0.crossKey == key }.count
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.triangle.merge")
                .font(.system(size: 20))
                .foregroundStyle(Theme.leaf)
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(crossing.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(crossing.date, format: .dateTime.day().month(.wide).year())
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                Text(CrossBook.facts(byHand: crossing.wasByHand, bagged: crossing.wasBagged,
                                     flowers: crossing.flowersPollinated, seeds: crossing.seedsCollected))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                if sown > 0 {
                    StatusTag(text: sown == 1 ? "1 sowing of its seed" : "\(sown) sowings of its seed",
                              fill: Theme.leafFill)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 4)
            WIconView(.chevronRight, size: 14)
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 14)
        .contentShape(.rect)
    }
}

// MARK: - The form

struct CrossEditor: View {

    // @Bindable lets the form's fields write straight into the record.
    @Bindable var crossing: PlantCross
    var isNew = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Plant.commonName)]) private var plants: [Plant]

    /// True once seed has been gathered and there is a date to give.
    private var hasSeed: Bool { crossing.seedCollectedOn != nil }

    var body: some View {
        // A sheet for a new cross, a page for one already recorded.
        if isNew {
            SheetPage("New cross", detail: "Which plant carried the seed, and whose pollen.",
                      onDismiss: {
                          // Cancelling throws the unfinished record away.
                          context.delete(crossing)
                          dismiss()
                      },
                      confirmTitle: "Save",
                      canConfirm: !crossing.seedParentName.isEmpty,
                      onConfirm: { dismiss() }) {
                SheetScroll { cards }
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenHeader(title: crossing.title,
                                 detail: "Cross · " + crossing.date.formatted(.dateTime.day().month(.wide).year()))
                    cards
                }
                .frame(maxWidth: 640, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Cross")
            .paperScreen()
        }
    }

    @ViewBuilder
    private var cards: some View {
        SheetCard("Seed parent") {
            Text("The plant that carried the flower, and so the fruit and the seed.")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
            ParentPicker(plants: plants, alikeTo: nil, key: $crossing.seedParentKey,
                         name: $crossing.seedParentName)
        }

        SheetCard("Pollen parent") {
            Text("The plant the pollen came from. Leave it empty if the bees did the work and you do not know.")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
            ParentPicker(plants: plants, alikeTo: crossing.seedParentName,
                         key: $crossing.pollenParentKey,
                         name: Binding(get: { crossing.pollenParentName ?? "" },
                                       set: { crossing.pollenParentName = $0.isEmpty ? nil : $0 }))
        }

        SheetCard("The cross") {
            SettingRow("Date pollinated") {
                DatePicker("Date pollinated", selection: $crossing.date, displayedComponents: .date)
                    .labelsHidden()
            }
            tick("I put the pollen on by hand", isOn: $crossing.wasByHand)
            tick("The flowers were bagged, so nothing else could reach them", isOn: $crossing.wasBagged)
            SettingRow("Flowers pollinated") {
                NumberStepper(value: Binding(get: { crossing.flowersPollinated ?? 0 },
                                             set: { crossing.flowersPollinated = $0 == 0 ? nil : $0 }),
                              range: 0...500)
            }
        }

        SheetCard("The seed") {
            Text("Fill this in when the fruit is ripe.")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
            SettingRow("Seeds gathered") {
                NumberStepper(value: Binding(get: { crossing.seedsCollected ?? 0 },
                                             set: { crossing.seedsCollected = $0 == 0 ? nil : $0 }),
                              range: 0...5000)
            }
            tick("Seed has been gathered", isOn: Binding(
                get: { hasSeed },
                set: { crossing.seedCollectedOn = $0 ? .now : nil }))
            if hasSeed {
                SettingRow("Gathered on") {
                    DatePicker("Gathered on", selection: Binding(
                        get: { crossing.seedCollectedOn ?? .now },
                        set: { crossing.seedCollectedOn = $0 }), displayedComponents: .date)
                        .labelsHidden()
                }
            }
        }

        SheetCard("Notes") {
            FieldBox {
                TextField("Why these two, what you hope for", text: Binding(
                    get: { crossing.notes ?? "" },
                    set: { crossing.notes = $0.isEmpty ? nil : $0 }), axis: .vertical)
                    .lineLimit(2...6)
            }
        }
    }

    /// A line with a tick box, in the app's own look.
    private func tick(_ words: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                TickBox(isOn: isOn.wrappedValue)
                Text(words)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn.wrappedValue ? .isSelected : [])
    }
}

// MARK: - Choosing a parent

/// Chooses one parent of a cross: from the plant library, or by typing
/// the name of something that is not in it, such as a neighbour's tree.
///
/// `key` and `name` are Bindings: values that live in the record and can
/// be both read and changed from here.
struct ParentPicker: View {

    let plants: [Plant]
    /// The other parent's name, if there is one. Plants of its kind are
    /// offered first: an apple is most likely crossed with an apple.
    let alikeTo: String?
    @Binding var key: String?
    @Binding var name: String

    @State private var search = ""

    /// Up to six plants to offer: those that match what has been typed,
    /// or, with nothing typed, those of the same kind as the other parent.
    private var matches: [Plant] {
        let typed = search.trimmingCharacters(in: .whitespaces).lowercased()
        let wanted = alikeTo.map { CrossBook.kind(of: $0) } ?? ""
        let pool: [Plant]
        if typed.isEmpty {
            pool = wanted.isEmpty ? [] : plants.filter { CrossBook.kind(of: $0.commonName) == wanted }
        } else {
            pool = plants.filter { $0.displayName.lowercased().contains(typed) }
                // Same kind as the other parent first. `sorted` keeps
                // the rest in the order they were in.
                .sorted { CrossBook.kind(of: $0.commonName) == wanted && CrossBook.kind(of: $1.commonName) != wanted }
        }
        return Array(pool.prefix(6))
    }

    var body: some View {
        if !name.isEmpty {
            HStack {
                Text(name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Button("Choose another") {
                    name = ""
                    key = nil
                }
                .buttonStyle(QuietGlassButton())
            }
        } else {
            FieldBox { TextField("Search your plants, or type a name", text: $search) }

            ForEach(matches) { plant in
                Button {
                    name = plant.displayName
                    key = plant.id.uuidString
                    search = ""
                } label: {
                    Text(plant.displayName)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .background(Theme.leafFill.opacity(0.35), in: .rect(cornerRadius: 12))
            }

            // Something that is not in the library can still be named.
            let typed = search.trimmingCharacters(in: .whitespaces)
            if !typed.isEmpty {
                Button("Use \u{201C}\(typed)\u{201D} as typed") {
                    name = typed
                    key = nil
                    search = ""
                }
                .buttonStyle(QuietGlassButton())
            }
        }
    }
}
