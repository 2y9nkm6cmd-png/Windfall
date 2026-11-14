//
//  PlantLibraryView.swift
//  Windfall
//
//  The Plants screen: search, a row of filter buttons, the plants as
//  cards, and the plant detail with the eight category groups from the
//  spreadsheet. The cards themselves are in PlantLibraryCards.swift.
//
//  The sums behind the filters are in PlantFilter.swift.
//

import SwiftUI
import SwiftData

// MARK: - Library

struct PlantLibraryView: View {

    // A to Z by name, then by variety, so the apples always come in the
    // same order. Sorted by name alone, plants that share a name could
    // swap places each time the page was opened.
    @Query(sort: [SortDescriptor(\Plant.commonName), SortDescriptor(\Plant.variety)])
    private var plants: [Plant]

    @Environment(\.modelContext) private var context

    /// Everything chosen with the buttons along the top, and the search.
    /// One value, so "Clear" can put it all back in one go.
    @State private var filter = PlantFilter.fromLaunchArguments()
    @State private var showingImport = false

    /// This month, 1 to 12.
    private var today: Int { Calendar.current.component(.month, from: .now) }

    var body: some View {
        let shown = filter.filter(plants, today: today)

        // GeometryReader measures the room there is, so the page can
        // leave the same space at its edges as Today and Gardens do.
        GeometryReader { geometry in
            let narrow = geometry.size.width < 600

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenHeader(title: "Plants", detail: summary(shown: shown.count))

                    if plants.isEmpty {
                        emptyLibrary
                    } else {
                        filterButtons
                        if shown.isEmpty {
                            noMatches
                        } else {
                            cards(shown)
                        }
                    }
                }
                .padding(.leading, narrow ? 16 : 14)
                .padding(.trailing, narrow ? 16 : 24)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        #if os(iOS)
        // On an iPhone and iPad the search is Apple's own. On a Mac it is
        // the magnifying glass in the toolbar below.
        .searchable(text: $filter.search, prompt: "Search plants")
        #endif
        .navigationTitle("Plants")
        #if os(iOS)
        // The big "Plants" on the page is the title. The bar stays, small,
        // because on an iPhone it holds the way back and the search.
        .navigationBarTitleDisplayMode(.inline)
        // Leaves the bar's own small "Plants" out, so the name is not
        // written twice.
        .toolbar(removing: .title)
        #endif
        .paperScreen()
        .navigationDestination(for: Plant.self) { PlantDetailView(plant: $0) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingImport = true
                } label: {
                    Label("Garden data", systemImage: "tray.and.arrow.down")
                }
            }
            #if os(macOS)
            // A gap, so the search has its own piece of glass and does
            // not share one with the Garden data button.
            ToolbarSpacer(.fixed)
            // The search rests as a magnifying glass and opens when
            // clicked, or with Command-F. See CollapsingSearch.swift.
            ToolbarItem(placement: .primaryAction) {
                CollapsingSearchField(text: $filter.search, prompt: "Search plants")
            }
            #endif
        }
        .sheet(isPresented: $showingImport) {
            NavigationStack {
                GardenDataView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingImport = false }
                        }
                    }
            }
            .macSheetSize(width: 520, height: 560)
        }
    }

    // MARK: The line above the title

    /// "335 plants", or "48 of 335 plants" when the list is narrowed.
    /// It used to float over the foot of the list, where it sat under
    /// Eira's button.
    private func summary(shown: Int) -> String {
        let all = plants.count
        if all == 0 { return "Nothing in the library yet" }
        let word = all == 1 ? "plant" : "plants"
        return shown == all ? "\(all) \(word)" : "\(shown) of \(all) \(word)"
    }

    // MARK: The cards

    /// The plants as cards, a group for each letter. "Lazy" means a card
    /// is only built when it is about to scroll into view, which keeps a
    /// library of several hundred plants quick.
    private func cards(_ shown: [Plant]) -> some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            ForEach(PlantCards.byLetter(shown)) { group in
                VStack(alignment: .leading, spacing: 10) {
                    Text(group.letter)
                        .font(.system(.title3, design: .serif, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.leading, 4)
                        .accessibilityAddTraits(.isHeader)

                    // As many columns as fit, each at least 250 points wide.
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 250, maximum: 440), spacing: 12, alignment: .top)],
                              alignment: .leading, spacing: 12) {
                        ForEach(group.plants) { plant in
                            NavigationLink(value: plant) {
                                PlantCardView(plant: plant, month: today)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var emptyLibrary: some View {
        ContentUnavailableView {
            Label("No plants yet", systemImage: "leaf")
        } description: {
            Text("Load the starter data, or import a file of your own.")
        } actions: {
            Button("Add garden data") { showingImport = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .glassCard(padding: 24)
    }

    private var noMatches: some View {
        ContentUnavailableView {
            Label("No plants match", systemImage: "line.3.horizontal.decrease.circle")
        } description: {
            Text("Nothing in the library fits everything chosen above.")
        } actions: {
            Button("Clear filters") { clearFilters() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .glassCard(padding: 24)
    }

    // MARK: The buttons along the top

    /// One button for each way of narrowing the list. Each opens a menu.
    /// The numbers in a menu say how many plants each option would show,
    /// with the other buttons' choices still applied.
    private var filterButtons: some View {
        // Sideways scrolling, so the buttons never squash on an iPhone.
        ScrollView(.horizontal, showsIndicators: false) {
            // Lets neighbouring pieces of glass share one layer.
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    statusButton
                    kindButton
                    layerButton
                    familyButton
                    seasonButton
                    roleButton
                    if filter.isNarrowed {
                        clearButton
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
        // Lets the glass draw past the scrolling strip's edge, so the
        // buttons' soft shadows are not cut off.
        .scrollClipDisabled()
    }

    private var statusButton: some View {
        Menu {
            Picker("Show", selection: $filter.status) {
                Text("Growing").tag(PlantStatus?.some(.growing))
                Text("To buy").tag(PlantStatus?.some(.wanted))
                Text("Previously owned").tag(PlantStatus?.some(.previouslyOwned))
                Text("All plants").tag(PlantStatus?.none)
            }
            .pickerStyle(.inline)
        } label: {
            FilterButtonLabel(title: statusTitle)
        }
        .filterButton(isChosen: filter.status != PlantFilter.standard.status)
    }

    private var statusTitle: String {
        switch filter.status {
        case .growing: return "Growing"
        case .wanted: return "To buy"
        case .previouslyOwned: return "Previously owned"
        case nil: return "All plants"
        }
    }

    private var kindButton: some View {
        Menu {
            Picker("Kind", selection: $filter.kind) {
                Text("Any kind").tag(PlantKind?.none)
                ForEach(filter.kindChoices(plants, today: today)) { option in
                    Text(option.menuText).tag(PlantKind(rawValue: option.key))
                }
            }
            .pickerStyle(.inline)
        } label: {
            FilterButtonLabel(title: filter.kind?.rawValue ?? "Fruit, veg…")
        }
        .filterButton(isChosen: filter.kind != nil)
    }

    private var layerButton: some View {
        Menu {
            Picker("Permaculture layer", selection: $filter.layer) {
                Text("Any layer").tag(String?.none)
                ForEach(filter.layerChoices(plants, today: today)) { option in
                    Text(option.menuText).tag(String?.some(option.key))
                }
            }
            .pickerStyle(.inline)
        } label: {
            FilterButtonLabel(title: filter.layer ?? "Layer")
        }
        .filterButton(isChosen: filter.layer != nil)
    }

    private var familyButton: some View {
        let choices = filter.familyChoices(plants, today: today)
        return Menu {
            Picker("Family", selection: $filter.family) {
                Text("Any family").tag(String?.none)
                ForEach(choices) { option in
                    Text(option.menuText).tag(String?.some(option.key))
                }
            }
            .pickerStyle(.inline)
        } label: {
            // The family's name as the records spell it, such as "Brassicas".
            FilterButtonLabel(title: filter.family.map { key in
                choices.first { $0.key == key }?.title ?? key.capitalized
            } ?? "Family")
        }
        .filterButton(isChosen: filter.family != nil)
    }

    private var seasonButton: some View {
        Menu {
            Picker("What", selection: $filter.season) {
                Text("Any time of year").tag(PlantSeason?.none)
                ForEach(filter.seasonChoices(plants, today: today)) { option in
                    Text(option.menuText).tag(PlantSeason(rawValue: option.key))
                }
            }
            .pickerStyle(.inline)

            // `.menu` inside a menu becomes a second menu that opens to
            // the side, which keeps the twelve months out of the way.
            Picker("When", selection: $filter.seasonMonth) {
                Text("This month (\(PlantFilter.monthName(today)))").tag(Int?.none)
                ForEach(1...12, id: \.self) { month in
                    Text(PlantFilter.monthName(month)).tag(Int?.some(month))
                }
            }
            .pickerStyle(.menu)
        } label: {
            FilterButtonLabel(title: seasonTitle)
        }
        .filterButton(isChosen: filter.season != nil)
    }

    /// "Season" with nothing chosen, "Sowing now" for this month, and
    /// "Flowering in June" for another.
    private var seasonTitle: String {
        guard let season = filter.season else { return "Season" }
        guard let month = filter.seasonMonth else { return "\(season.rawValue) now" }
        return season.phrase(month: month)
    }

    private var roleButton: some View {
        Menu {
            Section("Plants that are all of these") {
                ForEach(filter.roleChoices(plants, today: today)) { option in
                    if let role = PlantRole(rawValue: option.key) {
                        // A switch for each role: more than one can be on.
                        Toggle(option.menuText, isOn: Binding(
                            get: { filter.roles.contains(role) },
                            set: { isOn in
                                if isOn { filter.roles.insert(role) } else { filter.roles.remove(role) }
                            }))
                    }
                }
            }
        } label: {
            FilterButtonLabel(title: roleTitle)
        }
        .filterButton(isChosen: !filter.roles.isEmpty)
    }

    /// "Role", or the role chosen, or the first and how many more.
    private var roleTitle: String {
        let chosen = PlantRole.allCases.filter { filter.roles.contains($0) }
        guard let first = chosen.first else { return "Role" }
        return chosen.count == 1 ? first.rawValue : "\(first.rawValue) +\(chosen.count - 1)"
    }

    private var clearButton: some View {
        Button {
            clearFilters()
        } label: {
            HStack(spacing: 6) {
                WIconView(.close, size: 12)
                Text("Clear")
                    .font(.subheadline)
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Theme.card.opacity(0.4)).interactive(), in: .capsule)
    }

    /// Puts every button back as it was. What is typed in the search box
    /// stays.
    private func clearFilters() {
        withAnimation(.smooth(duration: 0.25)) {
            let typed = filter.search
            filter = .standard
            filter.search = typed
        }
    }
}

// MARK: - Filter buttons

/// The words on a filter button, with a small arrow to say it opens a menu.
private struct FilterButtonLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.subheadline)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.semibold))
                .accessibilityHidden(true)
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 14)
        .frame(height: 40)
        .contentShape(.capsule)
    }
}

private extension View {
    /// The look shared by every filter button: a capsule of glass, filled
    /// with pale green when something is chosen on it, as on the Year page.
    func filterButton(isChosen: Bool) -> some View {
        self
            // Show the label as it is, rather than as Apple's own pop-up
            // button, which would draw a second frame around it.
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .fontWeight(isChosen ? .semibold : .regular)
            .glassEffect(.regular.tint((isChosen ? Theme.leafFill : Theme.card).opacity(isChosen ? 0.8 : 0.4)).interactive(),
                         in: .capsule)
            .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}

private extension PlantFilter.Choice {
    /// How a option reads in a menu: "Brassicas (14)".
    var menuText: String { "\(title) (\(count))" }
}

// MARK: - Detail

/// One plant's page, as cards.
///
/// What goes on each card is decided in PlantPage.swift, which follows
/// the groups of columns in the spreadsheet the library came from. This
/// draws them: in two columns where there is room, in one where there
/// is not.
struct PlantDetailView: View {

    @Bindable var plant: Plant

    /// The two forms the "Sowings and plantings" card can open.
    ///
    /// `Identifiable` lets `.sheet(item:)` below use it: the sheet is
    /// up whenever `adding` holds one of these, and gone when it is nil.
    private enum AddingToGarden: String, Identifiable {
        case sowing, planting
        var id: String { rawValue }
    }

    /// Which of the two forms is open. Nil when neither is.
    @State private var adding: AddingToGarden?

    var body: some View {
        // Worked out once for this redraw.
        let cards = PlantPage.cards(for: plant)

        // GeometryReader says how wide the page is.
        GeometryReader { geometry in
            let isWide = geometry.size.width >= 720

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if isWide {
                        let sides = PlantPage.twoColumns(cards)
                        HStack(alignment: .top, spacing: 14) {
                            VStack(spacing: 14) {
                                ForEach(sides.left) { PlantFactCardView(factCard: $0) }
                                companionsLink
                                pestsCard
                            }
                            VStack(spacing: 14) {
                                ForEach(sides.right) { PlantFactCardView(factCard: $0) }
                                plantingsCard
                            }
                        }
                    } else {
                        ForEach(cards) { PlantFactCardView(factCard: $0) }
                        companionsLink
                        pestsCard
                        plantingsCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle(plant.commonName)
        .paperScreen()
        // Tells Eira which plant is open. See EiraScreen.
        .eiraLooksAt("the plant \(EiraSight.name(plant.commonName, variety: plant.variety))",
                     short: EiraSight.name(plant.commonName, variety: plant.variety))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        // Leaves the bar's own small "Plants" out, so the name is not
        // written twice.
        .toolbar(removing: .title)
        #endif
        // The large name below is the title. The bar keeps the name for
        // the back button and VoiceOver, but shows no words of its own.
        .toolbar { ToolbarItem(placement: .principal) { Text("") } }
        // The sowing form, opened with this plant already chosen.
        // `asPlanting` starts it on "Plants" in place of seed.
        .sheet(item: $adding) { which in
            NewPlantingView(plant: plant, asPlanting: which == .planting)
        }
        // A checking aid: `-demoOpen plantSowing` and `-demoOpen
        // plantPlanting` open the form at once, so a still picture can
        // be taken of it. See DemoGarden.opens.
        .onAppear {
            if DemoGarden.opens == "plantSowing" { adding = .sowing }
            if DemoGarden.opens == "plantPlanting" { adding = .planting }
        }
    }

    // MARK: The top of the page

    private var header: some View {
        let summary = PlantPage.summary(for: plant)
        return VStack(alignment: .leading, spacing: 4) {
            if !summary.isEmpty {
                // "softneck · Alliums · Perennial"
                Text(summary.map(\.value).joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
            Text(plant.commonName)
                .font(.screenTitle)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            if let latin = plant.latinName, !latin.isEmpty {
                Text(latin)
                    .font(.title3)
                    .italic()
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: The two cards that are not from the spreadsheet

    /// Opens the plant's friends and enemies.
    private var companionsLink: some View {
        NavigationLink {
            CompanionView(plantName: plant.commonName)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Companion planting")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("What it grows well with, and what to keep apart from it.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                WIconView(.arrowRight, size: 16)
                    .foregroundStyle(Theme.leaf)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassCard()
    }

    /// The plant's known pests that the companion matrix has an answer
    /// for, each a chip that opens the plants recorded as helping
    /// against it. Left out if there are none.
    @ViewBuilder
    private var pestsCard: some View {
        let pests = CompanionPests.named(in: plant.knownPests ?? "")
        if !pests.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Plants that help with its pests")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8, alignment: .leading)],
                          alignment: .leading, spacing: 8) {
                    ForEach(pests, id: \.self) { pest in
                        NavigationLink {
                            PestHelpersView(startingWith: pest)
                        } label: {
                            HStack(spacing: 6) {
                                Text(pest)
                                WIconView(.arrowRight, size: 12)
                            }
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Theme.leafFill, in: .capsule)
                            .contentShape(.capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
    }

    /// Each time this plant has been sown or planted, newest first,
    /// and two buttons to add another.
    ///
    /// The card is always there, even with nothing to list, because it
    /// is where a sowing or a planting of this plant is added. Before 14
    /// November 2026 it was left out until the plant had been sown, and
    /// a sowing could only be started from Today or the Sowings list,
    /// by finding the plant again.
    private var plantingsCard: some View {
        // What each row says is worked out in PlantPage.swift, where it
        // is tested.
        let lines = PlantPage.plantingLines(for: plant)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Sowings and plantings")
                .font(.headline)
                .foregroundStyle(Theme.ink)

            if lines.isEmpty {
                Text("Nothing recorded for this plant yet.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }

            ForEach(lines) { line in
                // The row only knows the record's id. This finds the
                // record itself, to hand to the page the row opens.
                if let planting = (plant.plantings ?? []).first(where: { $0.id == line.id }) {
                    NavigationLink {
                        PlantingDetailView(planting: planting)
                    } label: {
                        HStack(alignment: .center, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                // "Planted 24 Oct 2026", or just "On
                                // record" where there is no date.
                                Text(line.date.map { "\(line.verb) \($0.formatted(.dateTime.day().month().year()))" } ?? line.verb)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Theme.ink)
                                Text(line.detail)
                                    .font(.caption)
                                    .foregroundStyle(Theme.inkSoft)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 8)
                            Text(line.status)
                                .font(.caption)
                                .foregroundStyle(Theme.inkSoft)
                            WIconView(.arrowRight, size: 12)
                                .foregroundStyle(Theme.leaf)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Setting `adding` is all a button does. The `.sheet(item:)`
            // on the page sees the change and puts the form up.
            HStack(spacing: 10) {
                Button("Add a sowing") { adding = .sowing }
                    .buttonStyle(QuietGlassButton())
                Button("Add a planting") { adding = .planting }
                    .buttonStyle(QuietGlassButton())
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

/// A checking aid. Starting the app with `-demoGarden -demoPlant Garlic`
/// opens that plant's page in place of the Gardens page, so a still
/// picture can be taken of it.
struct DemoPlantPage: View {

    let name: String

    @Query(sort: [SortDescriptor(\Plant.commonName)]) private var plants: [Plant]

    var body: some View {
        if let plant = plants.first(where: { $0.commonName.lowercased() == name.lowercased() }) {
            PlantDetailView(plant: plant)
        } else {
            Text("No plant called \(name).")
        }
    }
}

// MARK: - One card of a plant's page

/// A glass card for one group of facts: rows of months first, then
/// short facts side by side, then long ones full width, then chips.
private struct PlantFactCardView: View {

    let factCard: PlantPage.FactCard

    /// How wide the names beside the rows of months are.
    private let nameWidth: CGFloat = 92

    var body: some View {
        let shortFacts = factCard.facts.filter { !$0.isLong }
        let longFacts = factCard.facts.filter(\.isLong)

        VStack(alignment: .leading, spacing: 12) {
            Text(factCard.title)
                .font(.headline)
                .foregroundStyle(Theme.ink)

            if !factCard.monthRows.isEmpty {
                monthTable
            }

            if !shortFacts.isEmpty {
                // As many across as will fit, each at least 120 points
                // wide. A card in a narrow column gets two across and a
                // wide one three or four.
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12, alignment: .topLeading)],
                          alignment: .leading, spacing: 10) {
                    ForEach(shortFacts) { fact in
                        factView(fact)
                    }
                }
            }

            ForEach(longFacts) { fact in
                factView(fact)
            }

            if !factCard.tags.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8, alignment: .leading)],
                          alignment: .leading, spacing: 8) {
                    ForEach(factCard.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.leafFill, in: .capsule)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    /// A name in small soft letters with its value underneath.
    private func factView(_ fact: PlantPage.Fact) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(fact.label)
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
            Text(fact.value)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                // Lets a long value run on to more lines.
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // VoiceOver reads the two as one: "Spacing, 0.15 m".
        .accessibilityElement(children: .combine)
    }

    /// The rows of months: the months' first letters across the top,
    /// then a strip for each row with its months filled in.
    private var monthTable: some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                Color.clear
                    .frame(width: nameWidth, height: 1)
                HStack(spacing: 3) {
                    ForEach(Array("JFMAMJJASOND".enumerated()), id: \.offset) { _, letter in
                        Text(String(letter))
                            .font(.caption2)
                            .foregroundStyle(Theme.inkSoft)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .accessibilityHidden(true)

            ForEach(factCard.monthRows) { monthRow in
                HStack(spacing: 8) {
                    Text(monthRow.label)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: nameWidth, alignment: .leading)
                    MonthStrip(months: monthRow.months, fill: tint(for: monthRow.kind))
                }
                // VoiceOver reads the months out by name.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(monthRow.label): \(MonthParser.describe(monthRow.months))")
            }
        }
    }

    /// The same colours as the Year page uses for the same things.
    private func tint(for kind: PlantPage.MonthKind) -> Color {
        switch kind {
        case .flowering: return Theme.flowering
        case .growth: return Theme.leaf
        case .fruiting, .harvest: return Theme.harvest
        case .sowIndoors: return Theme.sowIndoors
        case .sowOutdoors: return Theme.sowOutdoors
        case .plantOut: return Theme.plantOut
        }
    }
}

/// Twelve small blocks, January to December, coloured for the months
/// that apply. This month has a ring round it.
private struct MonthStrip: View {

    let months: [Int]
    let fill: Color

    var body: some View {
        let thisMonth = Calendar.current.component(.month, from: .now)
        HStack(spacing: 3) {
            ForEach(1...12, id: \.self) { month in
                RoundedRectangle(cornerRadius: 4)
                    .fill(months.contains(month) ? fill : Theme.hairline.opacity(0.7))
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        if month == thisMonth {
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Theme.ink.opacity(0.75), lineWidth: 1.2)
                        }
                    }
            }
        }
    }
}
