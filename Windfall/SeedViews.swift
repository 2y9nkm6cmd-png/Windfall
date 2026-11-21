//
//  SeedViews.swift
//  Windfall
//
//  Seed stock and viability: the seed catalogue.
//
//  Since 21 November 2026 the page is built from glass cards (Seeds to
//  buy, Sow this month, Use soon, All seed) and the spreadsheet's seed
//  stock comes in as packets (SheetExtras.swift). The sums behind the
//  cards are in SeedStock.swift.
//
//  The point of this screen is the germination test. A packet three years
//  old might be at 90% or at 20%, and the difference decides whether you
//  sow one seed per station or four. Guessing wastes either seed or a
//  season; a ten-seed test on damp kitchen roll settles it in a fortnight.
//

import SwiftUI
import SwiftData

// MARK: - List

/// The Seed page: the seed catalogue.
///
/// Rebuilt as glass cards on 21 November 2026 (knowledge base doc 153),
/// when the spreadsheet's seed stock came in (SheetExtras.swift). It was
/// a plain list with problems first. Top to bottom:
///
///   Seeds to buy    packets running low or used up, each with a tick
///                   for "Bought". Hidden when there are none.
///   Sow this month  packets with seed whose plant can be sown this
///                   month, with where each is kept: a pick list.
///   Use soon        past their sow-by date, near it, or germinating
///                   poorly.
///   All seed        every packet, by family or by where it is kept.
///
/// The sums are in SeedStock.swift, where they are tested.
struct SeedListView: View {

    @Query private var packets: [SeedPacket]

    @Environment(\.modelContext) private var context

    /// Which way of adding a packet is open, if any. `nil` means none.
    ///
    /// One value drives one sheet, further down in `.sheet(item:)`.
    /// Before 15 November 2026 this was a true-or-false, because there
    /// was only one way in: the typed form.
    @State private var adding: SeedPacketStart?
    @State private var search = ""
    /// How All seed is grouped. Kept on the device between visits.
    @AppStorage("seedGrouping") private var groupingRaw = SeedStock.Grouping.family.rawValue

    /// The ways in that this device can offer. See SeedPacketStart.swift.
    private var choices: [SeedPacketStart] {
        SeedPacketStart.choices(hasCamera: CameraPhoto.isAvailable)
    }

    private var grouping: Binding<SeedStock.Grouping> {
        Binding(get: { SeedStock.Grouping(rawValue: groupingRaw) ?? .family },
                set: { groupingRaw = $0.rawValue })
    }

    /// The packets the search leaves, or all of them.
    private var shown: [SeedPacket] {
        let needle = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return packets }
        return packets.filter { packet in
            [packet.plant?.commonName, packet.variety, packet.plant?.variety, packet.supplier, packet.storageLocation]
                .compactMap { $0?.lowercased() }
                .contains { $0.contains(needle) }
        }
    }

    private var month: Int { Calendar.current.component(.month, from: .now) }

    private var monthName: String {
        Calendar.current.monthSymbols[month - 1]
    }

    var body: some View {
        // Worked out once for this drawing of the page.
        let list = shown
        let toBuy = SeedStock.toBuy(list)
        let sowNow = SeedStock.sowThisMonth(list, month: month)
        let useSoon = SeedStock.useSoon(list)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: "Seed", detail: countLine)

                if packets.isEmpty {
                    emptyCard
                } else if list.isEmpty {
                    Text("No packet matches that.")
                        .font(.body)
                        .foregroundStyle(Theme.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()
                }

                if !toBuy.isEmpty {
                    card("Seeds to buy", detail: "Running low or used up. Tick one once it is bought.") {
                        ForEach(toBuy) { packet in
                            buyRow(packet)
                        }
                    }
                }

                if !sowNow.isEmpty {
                    card("Sow in \(monthName)", detail: "\(counted(sowNow.count, "packet")) with seed that can be sown this month.") {
                        ForEach(sowNow) { packet in
                            NavigationLink(value: packet) {
                                SeedRow(packet: packet, extra: placeWords(packet))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !useSoon.isEmpty {
                    card("Use soon", detail: nil) {
                        ForEach(useSoon) { packet in
                            NavigationLink(value: packet) {
                                SeedRow(packet: packet, extra: SeedStock.useSoonReason(packet), warns: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !list.isEmpty {
                    allSeed(list)
                }
            }
            // Not wider than is comfortable to read on a Mac or an iPad.
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // The search rests as a magnifying glass on an iPhone and iPad
        // and opens when tapped. See `tuckedSearch` in CollapsingSearch.swift.
        .tuckedSearch(text: $search, prompt: "Search seed")
        .navigationTitle("Seed")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .paperScreen()
        .navigationDestination(for: SeedPacket.self) { SeedDetailView(packet: $0) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // A `Menu` is a button that opens a short list of
                // buttons. The "+" used to open the typed form straight
                // away. Now it asks which way first.
                Menu {
                    ForEach(choices) { choice in
                        addButton(choice)
                    }
                } label: {
                    Label("Add packet", systemImage: "plus")
                }
            }
        }
        // A checking aid: `-demoSeed -demoSeedAdd library` opens that
        // way of adding a packet as soon as the page appears, so a still
        // picture can be taken of it. See DemoGarden.swift. `.task`
        // runs once, when the page first shows.
        .task {
            if let way = DemoGarden.seedAdds { adding = way }
        }
        // `.sheet(item:)` shows a sheet whenever `adding` holds a value
        // and hands that value in, here called `start`. Closing the
        // sheet sets `adding` back to nil. Using one sheet for all three
        // ways means two can never try to open at once.
        .sheet(item: $adding) { start in
            if start.readsAPhoto {
                // The scanner saves a packet of its own when Save is
                // pressed there, so the new packet appears in this list
                // with nothing more to do here.
                SeedPacketScanView(startsWith: start)
            } else {
                NewSeedPacketView()
            }
        }
    }

    /// "146 packets · 12 to buy"
    private var countLine: String {
        guard !packets.isEmpty else { return "No packets yet" }
        let buying = packets.filter(\.toBuy).count
        let saved = packets.filter(\.isHomeSaved).count
        var parts = [counted(packets.count, "packet")]
        if saved > 0 { parts.append("\(saved) saved") }
        if buying > 0 { parts.append("\(buying) to buy") }
        return parts.joined(separator: " · ")
    }

    private func counted(_ number: Int, _ word: String) -> String {
        number == 1 ? "1 \(word)" : "\(number) \(word)s"
    }

    private func placeWords(_ packet: SeedPacket) -> String {
        packet.storageLocation.map { "Kept in \($0)" } ?? "Not given a place"
    }

    /// One glass card with a heading and a quieter line under it.
    private func card<Content: View>(_ title: String, detail: String?,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    /// A packet to buy, with its tick. Ticking it says there is plenty
    /// again, which takes it off the list.
    private func buyRow(_ packet: SeedPacket) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                SeedLeft.plenty.apply(to: packet)
            } label: {
                TickBox(isOn: false)
                    .frame(width: 30, height: 30)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Bought: \(SeedStock.title(of: packet))")

            NavigationLink(value: packet) {
                SeedRow(packet: packet, extra: SeedLeft.of(packet).words)
            }
            .buttonStyle(.plain)
        }
    }

    /// Every packet, under the family's or the place's headings.
    private func allSeed(_ list: [SeedPacket]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All seed")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            GlassSwitch(choices: SeedStock.Grouping.allCases, selection: grouping) { $0.words }
            ForEach(SeedStock.grouped(list, by: grouping.wrappedValue)) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(group.title) (\(group.packets.count))")
                        .font(.headline)
                        .foregroundStyle(Theme.leaf)
                        .padding(.top, 4)
                    ForEach(group.packets) { packet in
                        NavigationLink(value: packet) {
                            SeedRow(packet: packet, extra: grouping.wrappedValue == .family ? packet.storageLocation : packet.plant?.group)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                context.delete(packet)
                            } label: {
                                Label("Delete packet", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    /// The empty page's card, with a button for each way in.
    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No seed recorded")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("Track packets and their germination rates so you know how thickly to sow.")
                .font(.body)
                .foregroundStyle(Theme.inkSoft)
            // The first way in is the one this device does best (the
            // camera where there is one), so it is the filled, green one.
            VStack(alignment: .leading, spacing: 10) {
                ForEach(choices) { choice in
                    if choice == choices.first {
                        addButton(choice)
                            .buttonStyle(.borderedProminent)
                    } else {
                        addButton(choice)
                            .buttonStyle(.bordered)
                    }
                }
            }
            .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    /// The button for one way of adding a packet. It is written once
    /// and used twice, in the empty page and in the "+" menu.
    private func addButton(_ choice: SeedPacketStart) -> some View {
        Button {
            adding = choice
        } label: {
            // Built by hand as a row (`HStack`) of the symbol and the
            // words, not as a `Label`, so the words are never squeezed
            // out (seen in the simulator, 15 November 2026).
            HStack(spacing: 8) {
                Image(systemName: choice.symbol)
                Text(choice.title)
                    .lineLimit(1)
            }
            .fixedSize()
        }
    }
}

/// One packet as a line: its plant and variety, then the supplier and
/// year, and one more line the card chooses.
private struct SeedRow: View {

    let packet: SeedPacket
    /// "Kept in Small tray", "Running low", "Past its sow-by date".
    var extra: String? = nil
    /// True to show `extra` in the warning colour.
    var warns = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(SeedStock.title(of: packet))
                        .font(.body)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if packet.isHomeSaved { tag("Saved") }
                    if packet.quantityRemaining == 0 { tag("Used up") }
                }
                let facts = [packet.supplier, packet.packetYear.map { String($0) }].compactMap { $0 }
                if !facts.isEmpty {
                    Text(facts.joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }
                if let extra, !extra.isEmpty {
                    Text(extra)
                        .font(.footnote)
                        .foregroundStyle(warns ? Color.orange : Theme.inkSoft)
                }
            }
            Spacer(minLength: 0)
            WIconView(.arrowRight, size: 13)
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 4)
        }
        .padding(.vertical, 3)
        .contentShape(.rect)
    }

    private func tag(_ words: String) -> some View {
        Text(words)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.leaf)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Capsule().strokeBorder(Theme.leaf, lineWidth: 1))
    }
}

// MARK: - New packet

struct NewSeedPacketView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Plant.commonName)]) private var plants: [Plant]

    @State private var selectedPlant: Plant?
    @State private var supplier = ""
    @State private var year = Calendar.current.component(.year, from: .now)
    @State private var useBy = Date.now.addingTimeInterval(365 * 86_400 * 2)
    @State private var hasUseBy = true
    @State private var quantity = ""
    @State private var storage = ""
    @State private var isHomeSaved = false
    @State private var search = ""
    @State private var carriedOn = false

    /// What is kept if the form is closed without Save (review pass, 21
    /// November 2026, doc 145). See FormDraft.swift.
    struct Draft: Codable, Equatable {
        var plantID: UUID?
        var supplier = ""
        var year = Calendar.current.component(.year, from: .now)
        var useBy = Date.now.addingTimeInterval(365 * 86_400 * 2)
        var hasUseBy = true
        var quantity = ""
        var storage = ""
        var isHomeSaved = false
    }

    private var draft: Draft {
        Draft(plantID: selectedPlant?.id, supplier: supplier, year: year, useBy: useBy, hasUseBy: hasUseBy,
              quantity: quantity, storage: storage, isHomeSaved: isHomeSaved)
    }
    private let draftKey = "new-seed-packet"
    private var draftIsEmpty: Bool {
        selectedPlant == nil && supplier.isEmpty && quantity.isEmpty && storage.isEmpty && !isHomeSaved
    }

    private func use(_ typedBefore: Draft) {
        selectedPlant = typedBefore.plantID.flatMap { id in plants.first { $0.id == id } }
        supplier = typedBefore.supplier
        year = typedBefore.year
        useBy = typedBefore.useBy
        hasUseBy = typedBefore.hasUseBy
        quantity = typedBefore.quantity
        storage = typedBefore.storage
        isHomeSaved = typedBefore.isHomeSaved
    }

    private var matching: [Plant] {
        guard !search.isEmpty else { return plants }
        return plants.filter { $0.commonName.lowercased().contains(search.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            Form {
                if carriedOn {
                    Section {
                        DraftNotice {
                            use(Draft())
                            FormDraft.clear(key: draftKey)
                            carriedOn = false
                        }
                    }
                }
                Section("Plant") {
                    if let selectedPlant {
                        HStack {
                            Text(selectedPlant.displayName)
                            Spacer()
                            Button("Change") { self.selectedPlant = nil }.font(.footnote)
                        }
                    } else {
                        TextField("Search plants", text: $search)
                        ForEach(matching.prefix(8)) { plant in
                            Button(plant.displayName) {
                                selectedPlant = plant
                                search = ""
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Packet") {
                    TextField("Supplier", text: $supplier)

                    Stepper("Year: \(String(year))", value: $year, in: 2000...2100)

                    Toggle("Has a use-by date", isOn: $hasUseBy)
                    if hasUseBy {
                        DatePicker("Use by", selection: $useBy, displayedComponents: .date)
                    }

                    LabeledContent("Seeds") {
                        TextField("approx", text: $quantity)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                    }

                    Toggle("Home saved", isOn: $isHomeSaved)
                    TextField("Stored where", text: $storage)
                }
            }
            .navigationTitle("New packet")
            .paperScreen()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(selectedPlant == nil)
                }
            }
        }
        .keepsDraft(draftKey, draft, isEmpty: draftIsEmpty, carriedOn: $carriedOn, restore: use)
    }

    private func save() {
        FormDraft.clear(key: draftKey)
        let packet = SeedPacket()
        packet.plant = selectedPlant
        packet.supplier = supplier.isEmpty ? nil : supplier
        packet.packetYear = year
        packet.useByDate = hasUseBy ? useBy : nil
        packet.dateAcquired = .now
        packet.quantityRemaining = Int(quantity)
        packet.storageLocation = storage.isEmpty ? nil : storage
        packet.isHomeSaved = isHomeSaved
        context.insert(packet)
        dismiss()
    }
}

// MARK: - Detail

/// A packet's page, rebuilt as glass cards on 21 November 2026 (doc 153).
struct SeedDetailView: View {

    @Bindable var packet: SeedPacket

    @State private var showingTest = false

    /// Seed left, read from and written to the packet. See SeedStock.swift.
    private var seedLeft: Binding<SeedLeft> {
        Binding(get: { SeedLeft.of(packet) }, set: { $0.apply(to: packet) })
    }

    /// Whether the packet has a sow-by date, as a switch.
    private var hasUseBy: Binding<Bool> {
        Binding(get: { packet.useByDate != nil },
                set: { packet.useByDate = $0 ? (packet.useByDate ?? Date.now.addingTimeInterval(365 * 86_400)) : nil })
    }

    var body: some View {
        let heading = SeedStock.title(of: packet)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: heading,
                             detail: packet.isHomeSaved ? "Saved seed" : (packet.supplier ?? "Seed packet"))

                SheetCard("Seed left") {
                    GlassSwitch(choices: SeedLeft.allCases, selection: seedLeft) { $0.words }
                    Text(packet.toBuy ? "On Seeds to buy, at the top of the Seed page." : "Running low or used up puts it on Seeds to buy.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                    SettingRow("Seeds counted") {
                        FieldBox {
                            TextField("not counted", value: $packet.quantityRemaining, format: .number)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 110)
                        }
                    }
                }

                SheetCard("The packet") {
                    SettingRow("Variety") {
                        FieldBox {
                            TextField(packet.plant?.variety ?? "variety", text: text(\.variety))
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    SettingRow(packet.isHomeSaved ? "Where from" : "Supplier") {
                        FieldBox {
                            TextField("Suttons", text: text(\.supplier))
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    SettingRow("Year") {
                        FieldBox {
                            TextField("2026", value: $packet.packetYear, format: .number.grouping(.never))
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }
                    Toggle("Has a sow-by date", isOn: hasUseBy)
                    if let useBy = packet.useByDate {
                        SettingRow("Sow by") {
                            DatePicker("Sow by", selection: Binding(get: { useBy }, set: { packet.useByDate = $0 }),
                                       displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                    SettingRow("Where it's kept") {
                        FieldBox {
                            TextField("Large tray - middle", text: text(\.storageLocation))
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    Toggle("Saved seed", isOn: $packet.isHomeSaved)
                }

                SheetCard("Germination") {
                    viability
                    Button {
                        showingTest = true
                    } label: {
                        Label("Record a germination test", systemImage: "testtube.2")
                    }
                    .buttonStyle(QuietGlassButton())
                    Text("Count out ten seeds onto damp kitchen roll in a sealed bag somewhere warm. Count how many sprout after a fortnight.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }

                SheetCard("Notes") {
                    FieldBox {
                        TextField("Notes", text: text(\.notes), axis: .vertical)
                            .lineLimit(2...8)
                    }
                }

                if let plant = packet.plant {
                    NavigationLink {
                        PlantDetailView(plant: plant)
                    } label: {
                        HStack(spacing: 6) {
                            Text("\(plant.displayName)'s page")
                            WIconView(.arrowRight, size: 13)
                        }
                        .font(.body)
                        .foregroundStyle(Theme.leaf)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(packet.plant?.commonName ?? "Seed")
        .paperScreen()
        // Tells Eira which seed packet is open. See EiraScreen.
        .eiraLooksAt(.seedPacket(of: packet.plant?.commonName))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingTest) {
            GerminationTestView(packet: packet)
        }
    }

    /// A box of words on the packet, where an empty box clears it.
    private func text(_ place: ReferenceWritableKeyPath<SeedPacket, String?>) -> Binding<String> {
        Binding(get: { packet[keyPath: place] ?? "" },
                set: { packet[keyPath: place] = $0.isEmpty ? nil : $0 })
    }

    @ViewBuilder
    private var viability: some View {
        if let testDate = packet.testDate,
           let sown = packet.testSeedsSown,
           let germinated = packet.testSeedsGerminated {
            SettingRow("Tested") { Text(testDate.formatted(date: .abbreviated, time: .omitted)).foregroundStyle(Theme.inkSoft) }
            SettingRow("Result") { Text("\(germinated) of \(sown)").foregroundStyle(Theme.inkSoft) }
            if let rate = packet.viabilityRate {
                SettingRow("Viability") { Text("\(Int(rate * 100))%").foregroundStyle(Theme.inkSoft) }
                if let multiplier = packet.suggestedSowingMultiplier(), multiplier > 1.2 {
                    Label("Sow about \(String(format: "%.1f", multiplier))× as thickly to allow for it",
                          systemImage: "arrow.up.circle")
                        .font(.body)
                        .foregroundStyle(.orange)
                }
            }
        } else if let rate = packet.viabilityRate {
            SettingRow("Worked out from your sowings") { Text("\(Int(rate * 100))%").foregroundStyle(Theme.inkSoft) }
        } else {
            Text("No test recorded.")
                .foregroundStyle(Theme.inkSoft)
        }
    }
}

// MARK: - Germination test

struct GerminationTestView: View {

    @Bindable var packet: SeedPacket

    @Environment(\.dismiss) private var dismiss

    @State private var sown = 10
    @State private var germinated = 0
    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Stepper("Seeds sown: \(sown)", value: $sown, in: 1...100)
                Stepper("Germinated: \(germinated)", value: $germinated, in: 0...sown)

                Section {
                    let rate = Double(germinated) / Double(max(sown, 1))
                    LabeledContent("Viability", value: "\(Int(rate * 100))%")

                    if rate < 0.3 {
                        Label("Very low — probably worth replacing", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    } else if rate < 0.6 {
                        Label("Usable, but sow thickly", systemImage: "exclamationmark.circle")
                            .foregroundStyle(.orange)
                    } else {
                        Label("Good", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Germination test")
            .paperScreen()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        packet.testDate = date
                        packet.testSeedsSown = sown
                        packet.testSeedsGerminated = germinated
                        dismiss()
                    }
                }
            }
        }
    }
}
