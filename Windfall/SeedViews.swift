//
//  SeedViews.swift
//  Windfall
//
//  Seed stock and viability.
//
//  The point of this screen is the germination test. A packet three years
//  old might be at 90% or at 20%, and the difference decides whether you
//  sow one seed per station or four. Guessing wastes either seed or a
//  season; a ten-seed test on damp kitchen roll settles it in a fortnight.
//

import SwiftUI
import SwiftData

// MARK: - List

struct SeedListView: View {

    @Query private var packets: [SeedPacket]
    @Query(sort: [SortDescriptor(\Plant.commonName)]) private var plants: [Plant]

    @Environment(\.modelContext) private var context

    /// Which way of adding a packet is open, if any. `nil` means none.
    ///
    /// One value drives one sheet, further down in `.sheet(item:)`.
    /// Before 15 November 2026 this was a true-or-false, because there
    /// was only one way in: the typed form.
    @State private var adding: SeedPacketStart?
    @State private var search = ""

    /// The ways in that this device can offer. See SeedPacketStart.swift.
    private var choices: [SeedPacketStart] {
        SeedPacketStart.choices(hasCamera: CameraPhoto.isAvailable)
    }

    private var sorted: [SeedPacket] {
        packets
            .filter {
                search.isEmpty ||
                ($0.plant?.commonName.lowercased().contains(search.lowercased()) ?? false)
            }
            .sorted { a, b in
                // Problems first — expired or poor germination.
                let aBad = a.isExpired || (a.viabilityRate.map { $0 < 0.5 } ?? false)
                let bBad = b.isExpired || (b.viabilityRate.map { $0 < 0.5 } ?? false)
                if aBad != bBad { return aBad }
                return (a.plant?.commonName ?? "") < (b.plant?.commonName ?? "")
            }
    }

    var body: some View {
        List {
            if packets.isEmpty {
                ContentUnavailableView {
                    Label("No seed recorded", systemImage: "bag")
                } description: {
                    Text("Track packets and their germination rates so you know how thickly to sow.")
                } actions: {
                    // One button for each way in. The first is the one
                    // this device does best (the camera where there is
                    // one), so it is the filled, green one. The others
                    // are quieter, so the eye is led to the first.
                    //
                    // The buttons sit in a `VStack`, a column, ending in
                    // `.fixedSize()`, which tells it to take only the
                    // room its buttons need. Without that (as first
                    // built, 15 November 2026) the empty page stretched
                    // each button into a tall green bar with its words
                    // squeezed out.
                    VStack(spacing: 10) {
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
            }

            ForEach(sorted) { packet in
                NavigationLink(value: packet) {
                    SeedRow(packet: packet)
                }
            }
            .onDelete { offsets in
                for i in offsets { context.delete(sorted[i]) }
            }
        }
        .searchable(text: $search, prompt: "Search seed")
        .navigationTitle("Seed")
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
        // `.sheet(item:)` shows a sheet whenever `adding` holds a value
        // and hands that value in, here called `start`. Closing the
        // sheet sets `adding` back to nil. Using one sheet for all three
        // ways means two can never try to open at once.
        // A checking aid: `-demoSeed -demoSeedAdd library` opens that
        // way of adding a packet as soon as the page appears, so a still
        // picture can be taken of it. See DemoGarden.swift. `.task`
        // runs once, when the page first shows.
        .task {
            if let way = DemoGarden.seedAdds { adding = way }
        }
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

    /// The button for one way of adding a packet. It is written once
    /// and used twice, in the empty page and in the "+" menu.
    private func addButton(_ choice: SeedPacketStart) -> some View {
        Button {
            adding = choice
        } label: {
            Label(choice.title, systemImage: choice.symbol)
        }
    }
}

private struct SeedRow: View {

    let packet: SeedPacket

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(packet.plant?.displayName ?? "Unknown")
                    .font(.title3.weight(.semibold))
                Spacer()
                if let year = packet.packetYear {
                    Text(String(year))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let supplier = packet.supplier {
                Text(supplier).font(.footnote).foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                if packet.isExpired {
                    Label("Past use-by", systemImage: "clock.badge.exclamationmark")
                        .foregroundStyle(.orange)
                }

                if let rate = packet.viabilityRate {
                    Label("\(Int(rate * 100))% germination",
                          systemImage: rate < 0.5 ? "exclamationmark.triangle" : "checkmark.circle")
                        .foregroundStyle(rate < 0.5 ? .orange : .green)
                }

                if let remaining = packet.quantityRemaining {
                    Label("\(remaining) left", systemImage: "number")
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 2)
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

    private var matching: [Plant] {
        guard !search.isEmpty else { return plants }
        return plants.filter { $0.commonName.lowercased().contains(search.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            Form {
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
    }

    private func save() {
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

struct SeedDetailView: View {

    @Bindable var packet: SeedPacket

    @State private var showingTest = false

    var body: some View {
        Form {
            Section("Packet") {
                LabeledContent("Plant", value: packet.plant?.displayName ?? "—")

                TextField("Supplier", text: Binding(
                    get: { packet.supplier ?? "" },
                    set: { packet.supplier = $0.isEmpty ? nil : $0 }
                ))

                LabeledContent("Seeds remaining") {
                    TextField("0", value: $packet.quantityRemaining, format: .number)
                        .multilineTextAlignment(.trailing)
                }

                TextField("Stored where", text: Binding(
                    get: { packet.storageLocation ?? "" },
                    set: { packet.storageLocation = $0.isEmpty ? nil : $0 }
                ))

                Toggle("Home saved", isOn: $packet.isHomeSaved)
            }

            Section {
                if let testDate = packet.testDate,
                   let sown = packet.testSeedsSown,
                   let germinated = packet.testSeedsGerminated {

                    LabeledContent("Tested", value: testDate.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("Result", value: "\(germinated) of \(sown)")

                    if let rate = packet.viabilityRate {
                        LabeledContent("Viability", value: "\(Int(rate * 100))%")

                        if let multiplier = packet.suggestedSowingMultiplier(), multiplier > 1.2 {
                            Label("Sow about \(String(format: "%.1f", multiplier))× as thickly to allow for it",
                                  systemImage: "arrow.up.circle")
                                .font(.body)
                                .foregroundStyle(.orange)
                        }
                    }
                } else if let rate = packet.viabilityRate {
                    LabeledContent("Inferred viability", value: "\(Int(rate * 100))%")
                    Text("From how your actual sowings performed, rather than a deliberate test.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No test recorded.")
                        .foregroundStyle(.secondary)
                }

                Button {
                    showingTest = true
                } label: {
                    Label("Record a germination test", systemImage: "testtube.2")
                }
            } header: {
                Text("Viability")
            } footer: {
                Text("Count out ten seeds onto damp kitchen roll in a sealed bag somewhere warm. Count how many sprout after a fortnight.")
            }

            Section("Notes") {
                TextField("Notes", text: Binding(
                    get: { packet.notes ?? "" },
                    set: { packet.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
            }
        }
        .navigationTitle(packet.plant?.commonName ?? "Seed")
        .paperScreen()
        // Tells Eira which seed packet is open. See EiraScreen.
        .eiraLooksAt("a seed packet of \(packet.plant?.commonName ?? "an unnamed plant")",
                     short: packet.plant.map { "this packet of \($0.commonName)" })
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingTest) {
            GerminationTestView(packet: packet)
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
