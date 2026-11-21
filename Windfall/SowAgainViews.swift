//
//  SowAgainViews.swift
//  Windfall
//
//  The sheet a sowing job's tick opens (knowledge base docs 148 and 152).
//
//  Before 21 November 2026 ticking "Sow lettuce" only struck the line
//  through for the month. It recorded nothing. Now the tick opens this
//  sheet, in two steps:
//
//    1. The sowing. Which variety (when the crop has more than one),
//       indoors or out, and how many, both optional. Save records it,
//       dated today, and ticks the job.
//    2. What next. "Lettuce sown. Sow again around Saturday 12
//       December?" with Yes, Change date and Not this time. And, when
//       the variety has a seed packet, "Seed left in the packet?" with
//       Plenty left, Running low and Used it up.
//
//  The rules (which varieties, the gap, when the chain ends) are in
//  SowAgain.swift and SeedStock.swift, where they are tested. This file
//  only draws them and saves what is chosen.
//

import SwiftUI
import SwiftData

/// What a tick on a sowing job is about. `Identifiable` so a sheet can
/// be shown for it with `.sheet(item:)`.
struct SowingTick: Identifiable {
    /// The crop, as `SowAgain.cropKey`: "lettuce".
    let cropKey: String
    /// The plant the line was about, for a worked-out "Sow Lettuce
    /// 'Little Gem'". Nil for a sow-again job, which is for the crop.
    let plant: Plant?

    var id: String { cropKey + (plant?.id.uuidString ?? "") }
}

struct SowNowSheet: View {

    let tick: SowingTick
    /// Ticks the job off once the sowing is saved.
    let onSowed: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Plant.commonName)]) private var plants: [Plant]
    @Query private var plantings: [Planting]
    @Query private var packets: [SeedPacket]

    // Step 1
    @State private var chosen: Plant?
    @State private var sownWhere: SowingLocation = .outdoors
    @State private var quantity = ""
    @State private var isSearching = false
    @State private var search = ""

    // Step 2
    /// The sowing just saved. Its being there is what shows step 2.
    @State private var justSown: Planting?
    /// The round that sowing was, for the crop this year.
    @State private var sownRound = 1
    @State private var offer: SowAgain.Offer?
    @State private var nextDay = Date.now
    @State private var isChangingDate = false
    /// What was answered to "Sow again?": the job saved, or nothing.
    @State private var answer: AgainAnswer?
    /// The packet the seed came from, if the variety has one.
    @State private var packet: SeedPacket?
    @State private var seedLeft: SeedLeft = .plenty
    /// A gap typed in for a crop that had none.
    @State private var gapTyped = ""

    private enum AgainAnswer: Equatable {
        case saved(String, Date)
        case notThisTime
    }

    private var month: Int { Calendar.current.component(.month, from: .now) }

    /// The last sowing of any variety of the crop.
    private var lastSown: Plant? {
        let ids = Set(SowAgain.varieties(ofCrop: tick.cropKey, in: plants).map(\.id))
        return plantings
            .filter { $0.startedFrom != .plant && $0.plant.map { ids.contains($0.id) } ?? false }
            .max { ($0.dateSown ?? .distantPast) < ($1.dateSown ?? .distantPast) }?
            .plant
    }

    private var offered: [Plant] {
        SowAgain.offeredVarieties(ofCrop: tick.cropKey, plants: plants, packets: packets,
                                  lastSown: lastSown, month: month)
    }

    /// The packet to take seed from for a variety: one with seed left,
    /// not past its date if there is such a one.
    private func packet(for plant: Plant) -> SeedPacket? {
        let mine = packets.filter { $0.plant?.id == plant.id && SeedStock.hasSeed($0) }
        return mine.first { !$0.isExpired } ?? mine.first
    }

    private var cropTitle: String {
        chosen.map { SowAgain.cropName(of: $0) } ?? tick.plant.map { SowAgain.cropName(of: $0) }
            ?? offered.first.map { SowAgain.cropName(of: $0) } ?? tick.cropKey.capitalized
    }

    var body: some View {
        Group {
            if let justSown {
                afterSowing(justSown)
            } else {
                sowing
            }
        }
        .onAppear {
            guard chosen == nil else { return }
            // A worked-out line is about one variety, so it starts
            // chosen. A sow-again job starts with the first offered.
            chosen = tick.plant ?? offered.first
            setLocation()
        }
    }

    // MARK: Step 1: the sowing

    private var sowing: some View {
        SheetPage("Sow \(cropTitle.lowercased())", detail: "Today, \(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))",
                  confirmTitle: "Save", canConfirm: chosen != nil, onConfirm: save) {
            SheetScroll {
                SheetCard(offered.count > 1 || isSearching ? "Which variety?" : "Variety") {
                    if isSearching {
                        searchList
                    } else {
                        ForEach(offered) { plant in
                            varietyRow(plant)
                        }
                        Button {
                            isSearching = true
                        } label: {
                            Label("Something else", systemImage: "magnifyingglass")
                        }
                        .buttonStyle(QuietGlassButton())
                    }
                }

                SheetCard("Where and how many") {
                    GlassSwitch(choices: SowingLocation.allCases, selection: $sownWhere) { $0.words }
                    SettingRow("Seeds sown") {
                        FieldBox {
                            TextField("optional", text: $quantity)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                        }
                    }
                    Text("Both can be left as they are.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
    }

    private func varietyRow(_ plant: Plant) -> some View {
        Button {
            chosen = plant
            setLocation()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: chosen?.id == plant.id ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(Theme.leaf)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(plant.displayName)
                        .foregroundStyle(Theme.ink)
                    if let words = varietyNote(plant) {
                        Text(words)
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// "Sown last time · seed in Large tray - middle"
    private func varietyNote(_ plant: Plant) -> String? {
        var parts: [String] = []
        if plant.id == lastSown?.id { parts.append("Sown last time") }
        if let packet = packet(for: plant) {
            parts.append(packet.storageLocation.map { "Seed in \($0)" } ?? "Seed in stock")
        }
        if !SowAgain.canSow(plant, inMonth: month) { parts.append("Not its sowing month") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var searchList: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldBox {
                TextField("Search the library", text: $search)
            }
            let needle = search.lowercased()
            let matches = needle.isEmpty ? [] : plants.filter { $0.displayName.lowercased().contains(needle) }
            ForEach(matches.prefix(8)) { plant in
                Button {
                    chosen = plant
                    isSearching = false
                    search = ""
                    setLocation()
                } label: {
                    Text(plant.displayName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 5)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            Button("Back to the list") { isSearching = false }
                .buttonStyle(QuietGlassButton())
        }
    }

    /// Indoors when only indoor sowing is open this month, otherwise
    /// outdoors.
    private func setLocation() {
        guard let chosen else { return }
        let indoors = MonthParser.months(in: chosen.sowIndoorsMonthsText).contains(month)
        let outdoors = MonthParser.months(in: chosen.sowOutdoorsMonthsText).contains(month)
        sownWhere = indoors && !outdoors ? .indoors : .outdoors
    }

    private func save() {
        guard let chosen else { return }
        let now = Date.now
        // The crop's round, counted before this sowing is added.
        sownRound = SowAgain.nextRound(ofCrop: SowAgain.cropKey(of: chosen), plants: plants,
                                       plantings: plantings, on: now)
        let planting = Planting()
        planting.plant = chosen
        planting.dateSown = now
        planting.status = .sown
        planting.sowingLocation = sownWhere
        planting.quantitySown = Int(quantity.trimmingCharacters(in: .whitespaces))
        planting.successionRound = Planting.nextRound(for: chosen, on: now)
        let from = packet(for: chosen)
        planting.seedPacket = from
        context.insert(planting)
        onSowed()

        packet = from
        seedLeft = from.map { SeedLeft.of($0) } ?? .plenty
        let made = SowAgain.offer(after: chosen, sown: now, plants: plants, packets: packets)
        offer = made
        nextDay = made.next ?? now
        justSown = planting
    }

    // MARK: Step 2: what next

    private func afterSowing(_ planting: Planting) -> some View {
        SheetPage("\(cropTitle) sown", detail: planting.plant?.displayName,
                  dismissTitle: nil, confirmTitle: "Done", onConfirm: { dismiss() }) {
            SheetScroll {
                againCard
                if let packet {
                    SheetCard("Seed left in the packet?") {
                        GlassSwitch(choices: SeedLeft.allCases, selection: $seedLeft) { $0.words }
                            .onChange(of: seedLeft) { _, newAnswer in newAnswer.apply(to: packet) }
                        Text(seedLeft == .plenty ? "Running low or used up puts it on Seeds to buy, on the Seed page."
                                                 : "On Seeds to buy, on the Seed page.")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var againCard: some View {
        if let offer {
            SheetCard("Sow again?") {
                switch answer {
                case .saved(let title, let day)?:
                    Label("\(title), from \(day.formatted(.dateTime.weekday(.wide).day().month(.wide))). It will be under This week when it is due.",
                          systemImage: "checkmark.circle")
                        .foregroundStyle(Theme.ink)
                case .notThisTime?:
                    Text("No next sowing saved.")
                        .foregroundStyle(Theme.inkSoft)
                case nil:
                    question(offer)
                }
            }
        }
    }

    @ViewBuilder
    private func question(_ offer: SowAgain.Offer) -> some View {
        if let question = offer.question {
            Text(isChangingDate ? "\(offer.crop) sown. Sow again on:" : question)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let days = offer.gapDays {
                Text(gapWords(days, offer.gapSource))
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
            if isChangingDate {
                DatePicker("Next sowing", selection: $nextDay, in: Date.now..., displayedComponents: .date)
                    .labelsHidden()
            }
            HStack(spacing: 10) {
                Button("Yes") { saveNext() }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.leaf)
                    .foregroundStyle(Theme.onLeaf)
                if !isChangingDate {
                    Button("Change date") { isChangingDate = true }
                        .buttonStyle(QuietGlassButton())
                }
                Button("Not this time") { answer = .notThisTime }
                    .buttonStyle(QuietGlassButton())
            }
        } else if offer.isLast {
            Text("That was the last sowing of \(offer.crop.lowercased()) for this year: no variety can be sown \(offer.gapDays.map { "in \(SowAgain.words(forDays: $0))" } ?? "then").")
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            // No gap for this crop: parsnips, leeks and the like.
            Text("\(offer.crop) has no gap set for sowing again, so nothing is offered.")
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            SettingRow("Sow again every") {
                FieldBox {
                    TextField("3 weeks", text: $gapTyped)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 110)
                }
            }
            Button("Set the gap") { setGap() }
                .buttonStyle(QuietGlassButton())
                .disabled(SowAgain.days(in: gapTyped) == nil)
            Text("It is kept on the plant's page, under Sowing from Seed, where it can be changed.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    /// "Every 2 weeks, Claude's starting figure: change it on the plant's page."
    private func gapWords(_ days: Int, _ gapFrom: SowAgain.GapSource?) -> String {
        let every = "Every \(SowAgain.words(forDays: days))"
        switch gapFrom {
        case .typed?: return "\(every), as set on the plant's page."
        case .spreadsheet?: return "\(every), from your spreadsheet's next sowing days."
        case .packet?: return "\(every), from the seed packet."
        case .starting?, nil: return "\(every), Claude's starting figure ⚠️ CHECK. Change it on the plant's page."
        }
    }

    private func setGap() {
        guard let plant = justSown?.plant, let days = SowAgain.days(in: gapTyped) else { return }
        PlantFacts.write(SowAgain.words(forDays: days), forKey: "sowAgainEvery", to: plant)
        let made = SowAgain.offer(after: plant, sown: justSown?.dateSown ?? .now, plants: plants, packets: packets)
        offer = made
        nextDay = made.next ?? .now
    }

    private func saveNext() {
        guard let offer, let planting = justSown else { return }
        let title = SowAgain.jobTitle(crop: offer.crop, round: sownRound + 1)
        let job = GardenJob(title: title)
        let span = SowAgain.span(from: nextDay)
        job.dueFrom = span.from
        job.dueBy = span.by
        job.cropName = offer.crop
        job.afterSowingID = planting.id
        context.insert(job)
        answer = .saved(title, nextDay)
    }
}
