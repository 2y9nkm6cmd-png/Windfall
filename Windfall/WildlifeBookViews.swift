//
//  WildlifeBookViews.swift
//  Windfall
//
//  The UK wildlife pages: every kind of animal as a tile with its drawing,
//  the animals of one kind as a list, and a page for each animal.
//
//  Asked for by William on 15 November 2026: "It would be good if you
//  could create a sheet with all wildlife that you could encounter in the
//  uk in it. With drawings." WildlifeReference.swift says what he chose
//  and where the list and the drawings come from.
//
//  THREE PAGES
//    WildlifeBookView     the kinds, under headings ("Bees, wasps and ants"),
//                         each a tile that grows into its own page. A
//                         search box looks through every animal.
//    WildlifeKindPage     one kind: its drawing, then its animals, the
//                         most recorded first.
//    WildlifeAnimalPage   one animal: its names, where it belongs, the
//                         months it is recorded in, and a link to
//                         William's own notes when he has it in his list.
//
//  WHERE THE SUMS ARE
//  Everything that can be worked out without drawing (which kind, which
//  months, the search) is in WildlifeReference.swift, so that it can be
//  tested without a Mac. This file only lays things out.
//
//  EVERY LINK CARRIES ITS OWN PAGE
//  Each link here is `NavigationLink { page } label: { row }`. None relies
//  on a separate `.navigationDestination` line to say which page opens.
//  That is the kind of link that failed on the Species list on William's
//  iPad the same day (FaunaViews.swift).
//
//  ⚠️ Not built in Xcode when written: made in a cloud workspace, where
//  screens can be checked for spelling but not run.
//

import SwiftUI
import SwiftData

// MARK: - The drawing

/// One kind's drawing, at a size. The drawing is in colour and is shown as
/// drawn, with a light and a dark version, like the plant drawings.
struct WildlifeKindPicture: View {
    /// The kind's short name, such as "bumblebee".
    let slug: String
    var size: CGFloat = 56

    var body: some View {
        Image("Wildlife/wild-\(slug)")
            // `resizable` lets the picture be drawn at any size, and
            // `scaledToFit` keeps its proportions when it is.
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            // The picture is decoration. The words beside it say what it
            // is, so VoiceOver skips it.
            .accessibilityHidden(true)
    }
}

/// One animal's drawing: its own if it has one, otherwise its kind's.
struct WildlifeAnimalPicture: View {
    let creature: WildlifeAnimal
    var size: CGFloat = 56

    var body: some View {
        Image(creature.pictureName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// "1 animal" and "24 animals".
private func animalsCounted(_ count: Int) -> String {
    count == 1 ? "1 animal" : "\(count) animals"
}

/// This month as a number, 1 for January.
private func monthNow() -> Int {
    Calendar.current.component(.month, from: .now)
}

// MARK: - Every kind

struct WildlifeBookView: View {

    /// The list that ships inside the app. It is read once and never
    /// changes while the app is open, so it is a plain `let`.
    private let book = WildlifeReference.shared

    // `@State` is a value the page owns. When it changes, SwiftUI draws
    // the page again.
    @State private var search = ""

    var body: some View {
        ScrollView {
            // "Lazy" means a row of tiles is only made when it is about
            // to scroll into view.
            LazyVStack(alignment: .leading, spacing: 14) {
                if book.animals.isEmpty {
                    missingCard
                } else if !search.trimmingCharacters(in: .whitespaces).isEmpty {
                    results
                } else {
                    summaryCard
                    ForEach(book.groups) { group in
                        HubSectionTitle(group.name)
                        tiles(for: group.kinds)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .searchable(text: $search, prompt: "Search UK wildlife")
        .navigationTitle("UK wildlife")
        .paperScreen()
        // Tells Eira which page is open. See EiraScreen.
        .eiraLooksAt("the UK wildlife reference, a list of UK animals by kind", short: "UK wildlife")
    }

    /// How many animals and kinds, and where the list came from.
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(book.animals.count) animals in \(book.groups.reduce(0) { $0 + $1.kinds.count }) kinds")
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.ink)
            Text("Every animal with 20 or more confirmed UK records on iNaturalist. These are the animals Eira can name from a photo. Each kind has one drawing, shared by all its animals.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
            Text("Not yet checked: the names are iNaturalist's and the kinds are Claude's.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 16)
    }

    /// Shown only if the list's file is not inside the app.
    private var missingCard: some View {
        Text("The UK wildlife list is not in this copy of Windfall.")
            .font(.body)
            .foregroundStyle(Theme.inkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(padding: 16)
    }

    /// A grid of tiles, as many across as fit. Tapping a tile grows that
    /// kind's page out of it (GrowFromTile.swift).
    private func tiles(for kinds: [WildlifeKind]) -> some View {
        // `.adaptive(minimum: 150)` asks for as many columns as will fit
        // with each at least 150 points wide: two on an iPhone, more on
        // an iPad or a Mac.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
            ForEach(kinds) { kind in
                GrowingLink {
                    WildlifeKindPage(kind: kind)
                } label: {
                    WildlifeKindTile(kind: kind, count: book.count(ofKind: kind.slug))
                }
                // Without this a link tints all its words blue.
                .buttonStyle(.plain)
            }
        }
    }

    /// What the search found, across every kind.
    @ViewBuilder
    private var results: some View {
        let found = book.search(search)
        if found.isEmpty {
            Text("No animal in the list matches \u{201C}\(search)\u{201D}.")
                .font(.body)
                .foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(padding: 16)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(found) { creature in
                    NavigationLink {
                        WildlifeAnimalPage(creature: creature)
                    } label: {
                        WildlifeAnimalRow(creature: creature, showsPicture: true)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    if creature.id != found.last?.id {
                        Divider()
                    }
                }
            }
            .glassCard(padding: 14)
            if found.count == 60 {
                Text("The first 60 are shown. Type more to narrow it down.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }
}

/// One kind as a tile: its drawing, its name and how many animals it holds.
struct WildlifeKindTile: View {
    let kind: WildlifeKind
    let count: Int

    var body: some View {
        // `VStack` sets things one above another.
        VStack(spacing: 6) {
            WildlifeKindPicture(slug: kind.slug, size: 84)
            Text(kind.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                // Room for two lines whether or not the name needs
                // them, so that every tile in a row is the same height.
                .lineLimit(2, reservesSpace: true)
            Text(animalsCounted(count))
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .glassCard(padding: 12)
        // Makes the whole tile take the tap, not only its words.
        .contentShape(.rect)
        // VoiceOver reads the tile as one thing.
        .accessibilityElement(children: .combine)
    }
}

/// One animal as a row: its name, its scientific name and when it is
/// about. With `showsPicture` its kind's drawing sits to the left.
struct WildlifeAnimalRow: View {
    let creature: WildlifeAnimal
    var showsPicture = false

    var body: some View {
        HStack(spacing: 12) {
            if showsPicture {
                WildlifeAnimalPicture(creature: creature, size: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(creature.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    // A scientific name standing in for a common one
                    // is set in italics, as it is everywhere else.
                    .italic(creature.commonName == nil)
                if creature.commonName != nil {
                    Text(creature.scientificName)
                        .font(.footnote)
                        .italic()
                        .foregroundStyle(Theme.inkSoft)
                }
                if let season = creature.seasonWords {
                    Text(season)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            WIconView(.chevronRight, size: 14)
                .foregroundStyle(Theme.inkSoft)
        }
        .contentShape(.rect)
    }
}

// MARK: - One kind

struct WildlifeKindPage: View {

    let kind: WildlifeKind

    private let book = WildlifeReference.shared

    /// True shows only the animals recorded in this month.
    @State private var aboutNowOnly = false

    var body: some View {
        let month = monthNow()
        let monthName = WildlifeReference.monthNames[month - 1]
        let all = book.animals(ofKind: kind.slug)
        let shown = aboutNowOnly ? book.animals(ofKind: kind.slug, aboutInMonth: month) : all

        // A `List` makes its rows only as they scroll into view, which
        // matters here: the larger moths alone are several hundred rows.
        List {
            Section {
                VStack(spacing: 8) {
                    WildlifeKindPicture(slug: kind.slug, size: 180)
                    Text(kind.name)
                        .font(.screenTitle)
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(kind.group) · \(animalsCounted(all.count))")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)

                // A switch. `$aboutNowOnly` hands the switch the value
                // itself, so that it can change it.
                Toggle("Only those recorded in \(monthName)", isOn: $aboutNowOnly)
            } footer: {
                Text("This drawing stands for the whole kind. The animals seen most often have a drawing of their own, shown beside their name.")
            }

            Section {
                ForEach(shown) { creature in
                    NavigationLink {
                        WildlifeAnimalPage(creature: creature)
                    } label: {
                        HStack(spacing: 12) {
                            // An animal with a drawing of its own shows
                            // it. The rest would only repeat the kind's
                            // drawing from the top of the page, so they
                            // show none.
                            if creature.hasOwnPicture {
                                WildlifeAnimalPicture(creature: creature, size: 48)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(creature.title)
                                    .font(.body.weight(.medium))
                                    .italic(creature.commonName == nil)
                                if creature.commonName != nil {
                                    Text(creature.scientificName)
                                        .font(.footnote)
                                        .italic()
                                        .foregroundStyle(.secondary)
                                }
                                if let season = creature.seasonWords {
                                    Text(season)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text(aboutNowOnly ? "\(animalsCounted(shown.count)) in \(monthName)" : "Most recorded first")
            } footer: {
                Text("From iNaturalist's confirmed UK records. Not yet checked.")
            }
        }
        .navigationTitle(kind.name)
        #if os(iOS)
        // The small title in the bar. The large one is on the page itself.
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .paperScreen()
        .eiraLooksAt("the UK wildlife list of \(kind.name.lowercased())", short: kind.name)
    }
}

// MARK: - One animal

struct WildlifeAnimalPage: View {

    let creature: WildlifeAnimal

    private let book = WildlifeReference.shared

    // William's own species list, to see whether this animal is in it.
    // `@Query` asks the database for every record of a kind.
    @Query private var ownSpecies: [Fauna]

    /// His own record of this animal, matched by scientific name.
    private var ownRecord: Fauna? {
        let wanted = WildlifeReference.plain(creature.scientificName)
        return ownSpecies.first { WildlifeReference.plain($0.scientificName ?? "") == wanted }
    }

    var body: some View {
        let kind = book.kind(slug: creature.kindSlug)

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                picture(kindName: kind?.name)
                heading(kind: kind)
                if let counts = creature.monthCounts, counts.count == 12, counts.contains(where: { $0 > 0 }) {
                    monthsCard(counts)
                }
                aboutCard
                if let faunaRecord = ownRecord {
                    ownCard(faunaRecord)
                }
                sourceCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .navigationTitle(creature.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .paperScreen()
        .eiraLooksAt("the UK wildlife page for \(creature.title) (\(creature.scientificName))", short: creature.title)
    }

    // MARK: The pieces

    /// The drawing, large. An animal without a drawing of its own shows
    /// its kind's, with a line saying so.
    private func picture(kindName: String?) -> some View {
        VStack(spacing: 8) {
            WildlifeAnimalPicture(creature: creature, size: 200)
            if !creature.hasOwnPicture, let kindName {
                Text("A drawing of the kind (\(kindName.lowercased())), not of this animal.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .glassCard(padding: 20)
    }

    /// The name in the serif used for page titles, the scientific name
    /// under it, and small tags.
    private func heading(kind: WildlifeKind?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(creature.title)
                .font(.screenTitle)
                .italic(creature.commonName == nil)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            if creature.commonName != nil {
                Text(creature.scientificName)
                    .font(.body)
                    .italic()
                    .foregroundStyle(Theme.inkSoft)
            }
            // Small labels that wrap on to a new row when they run out
            // of room (PlantLibraryCards.swift).
            ChipFlow(spacing: 6) {
                if let kind {
                    StatusTag(text: kind.name, fill: Theme.leafFill)
                }
                if creature.introduced == true {
                    StatusTag(text: "Brought to the UK by people", fill: Theme.amber)
                }
                if ownRecord != nil {
                    StatusTag(text: "In your species list", fill: Theme.journalCard)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Twelve bars, one for each month, as tall as that month's share of
    /// the animal's records. This month's bar is the darker one.
    private func monthsCard(_ counts: [Int]) -> some View {
        let month = monthNow()
        // The tallest bar sets the scale. `max(..., 1)` guards against
        // dividing by nought.
        let tallest = max(counts.max() ?? 1, 1)
        return card("When it is recorded") {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<12, id: \.self) { place in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(place + 1 == month ? Theme.leaf : Theme.leafFill)
                            .frame(height: max(3, 64 * CGFloat(counts[place]) / CGFloat(tallest)))
                        Text(String(WildlifeReference.monthNames[place].prefix(1)))
                            .font(.caption2)
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 86, alignment: .bottom)
            // VoiceOver is given the months in words, not twelve bars.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Recorded \(creature.seasonWords ?? "in months not known")")

            if let season = creature.seasonWords {
                Text(season)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
            }
            Text("Each bar is one month's share of its confirmed UK records, January first. The darker bar is \(WildlifeReference.monthNames[month - 1]). Records follow where and when people look, so a short bar can mean few watchers as well as few animals.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    /// Where it belongs, and how often it is recorded.
    private var aboutCard: some View {
        card("Where it belongs") {
            if let family = creature.family {
                line("Family", family)
            }
            if let order = creature.order {
                line("Order", order)
            }
            line("Confirmed UK records", "\(creature.ukRecords)")
        }
    }

    /// A link to William's own notes on this animal.
    private func ownCard(_ faunaRecord: Fauna) -> some View {
        card("In your species list") {
            NavigationLink {
                FaunaDetailView(fauna: faunaRecord)
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(faunaRecord.commonName)
                            .font(.body)
                            .foregroundStyle(Theme.ink)
                        Text("Your notes, and the plants it uses")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Spacer()
                    WIconView(.chevronRight, size: 14)
                        .foregroundStyle(Theme.inkSoft)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    /// Where the page's facts came from, and that they are unchecked.
    private var sourceCard: some View {
        card("Where this comes from") {
            Text("iNaturalist's confirmed records in the United Kingdom, fetched on \(book.fetched). The names are iNaturalist's, so some are not the usual British ones. The drawing is Claude's, made from memory of the animal's markings.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
            Text("Not yet checked.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    /// A label on the left and its value on the right.
    private func line(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.body)
                .foregroundStyle(Theme.inkSoft)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
        }
    }

    /// A glass card with a heading. `Content` in the angle brackets stands
    /// for "whatever views are handed in", which is what lets one function
    /// make every card on the page.
    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 16)
    }
}

// MARK: - A checking aid

/// One of the wildlife or plant disease pages by name, for
/// `-demoWildlife`. It lets a still picture be taken of a page without
/// tapping through to it. What can follow `-demoWildlife`:
///
/// - `species`: the Species page, with William's own list
/// - `book`: All UK wildlife, the kinds as tiles
/// - `kind:tit`: one kind's page (the word after the colon is the kind's
///   short name in WildlifeReference.json)
/// - `animal:Erithacus rubecula`: one animal's page, by scientific name
/// - `diseases`: the plant diseases
/// - `disease:rust`: one disease's page (its short name in
///   PlantDiseases.json)
struct DemoWildlifePage: View {

    let page: String

    var body: some View {
        // "kind:tit" is cut at its first colon into "kind" and "tit".
        let pieces = page.split(separator: ":", maxSplits: 1).map(String.init)
        let wanted = pieces.count > 1 ? pieces[1] : ""
        switch pieces.first ?? "" {
        case "species":
            FaunaListView()
        case "book":
            WildlifeBookView()
        case "diseases":
            PlantDiseaseListView()
        case "kind":
            if let found = WildlifeReference.shared.kind(slug: wanted) {
                WildlifeKindPage(kind: found)
            } else {
                Text("No kind of animal called \(wanted).")
            }
        case "animal":
            if let found = WildlifeReference.shared.animal(scientificName: wanted) {
                WildlifeAnimalPage(creature: found)
            } else {
                Text("No animal called \(wanted).")
            }
        case "disease":
            if let found = PlantDiseases.shared.disease(slug: wanted) {
                PlantDiseasePage(disease: found)
            } else {
                Text("No plant disease called \(wanted).")
            }
        default:
            Text("-demoWildlife takes species, book, diseases, kind:, animal: or disease:.")
        }
    }
}
