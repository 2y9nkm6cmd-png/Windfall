//
//  TodayLayout.swift
//  Windfall
//
//  Where each card sits on the Today screen, and the sums for moving
//  them about.
//
//  The screen is made of "panels": the conditions card, the six capture
//  buttons, this week's urgent jobs, this month's jobs, the garden plans,
//  the recent records and the journal offer. Pressing and holding one
//  lets them be rearranged.
//
//  The page has "zones" that panels sit in. On a wide screen there are
//  five: a full-width stack at the top, three columns, and a full-width
//  stack at the bottom. A narrower iPad has two columns. An iPhone has
//  one list. Any panel can go in any zone.
//
//  Each width keeps its own arrangement, because a layout that suits
//  three columns does not suit one. Arrangements are kept on the device,
//  so a Mac and an iPhone can differ.
//
//  Nothing in this file draws anything, so it can be tested without a
//  screen. The drawing and the dragging are in TodayView.swift.
//

import Foundation

// MARK: - The panels

/// One movable panel of the Today screen.
enum TodayPanel: String, CaseIterable, Identifiable {
    case conditions, capture, week, jobs, plans, recent, journal

    var id: String { rawValue }

    /// The panel's name, for the label that follows the finger while it
    /// is dragged and for VoiceOver.
    var title: String {
        switch self {
        case .conditions: return "Conditions"
        case .capture: return "Capture buttons"
        case .week: return "This week"
        case .jobs: return "This month"
        case .plans: return "Garden plans"
        case .recent: return "Recent records"
        case .journal: return "Journal offer"
        }
    }
}

// MARK: - The arrangement

/// Which panels are in which zone, and in what order, at one width.
///
/// It is a struct, a bundle of plain values. Moving a panel makes a
/// changed copy, which the screen then saves and redraws from.
struct TodayArrangement: Equatable {

    /// How many columns this arrangement is for: 1, 2 or 3.
    let columns: Int
    /// The zones in reading order. With one column there is a single
    /// zone. Otherwise: the top stack, each column, then the bottom stack.
    private(set) var zones: [[TodayPanel]]

    // MARK: Which arrangement

    /// How many columns suit a screen this wide, in points. The same
    /// widths the Today screen has always changed at.
    static func columns(forWidth width: Double) -> Int {
        width >= 840 ? 3 : (width >= 600 ? 2 : 1)
    }

    /// How many zones an arrangement with this many columns has.
    static func zoneCount(columns: Int) -> Int {
        columns <= 1 ? 1 : columns + 2
    }

    /// The arrangement the app starts with. Each is how Today was laid
    /// out before it could be rearranged, with "This week" added above
    /// "This month".
    static func standard(columns: Int) -> TodayArrangement {
        switch columns {
        case 3:
            return TodayArrangement(columns: 3, zones: [[.conditions, .capture],
                                                        [.week, .jobs], [.plans], [.recent, .journal],
                                                        []])
        case 2:
            return TodayArrangement(columns: 2, zones: [[.conditions, .capture],
                                                        [.week, .jobs, .recent], [.plans, .journal],
                                                        []])
        default:
            return TodayArrangement(columns: 1, zones: [[.conditions, .capture, .week, .jobs, .plans, .recent, .journal]])
        }
    }

    private init(columns: Int, zones: [[TodayPanel]]) {
        self.columns = columns
        self.zones = zones
    }

    // MARK: Saving and reading back

    /// The arrangement as one line of text, for keeping in the app's
    /// settings: zones divided by "|" and panels by ",". The standard
    /// three-column one reads "conditions,capture|week,jobs|plans|recent,journal|".
    var stored: String {
        zones.map { $0.map(\.rawValue).joined(separator: ",") }.joined(separator: "|")
    }

    /// Reads an arrangement back from its line of text.
    ///
    /// It is forgiving, so an arrangement saved by an older or newer
    /// version of the app still works:
    /// - text with the wrong number of zones gives the standard arrangement
    /// - a name it does not know is skipped
    /// - a panel listed twice is kept once
    /// - a panel not listed at all is put back in its standard zone, as
    ///   near its standard place as that zone allows. So a panel added in
    ///   a later version appears where it was meant to, and nothing can
    ///   be lost.
    init(columns: Int, stored text: String) {
        let fallback = TodayArrangement.standard(columns: columns)
        let parts = text.split(separator: "|", omittingEmptySubsequences: false)
        guard !text.isEmpty, parts.count == TodayArrangement.zoneCount(columns: fallback.columns) else {
            self = fallback
            return
        }

        var seen = Set<TodayPanel>()
        var read: [[TodayPanel]] = parts.map { part in
            part.split(separator: ",").compactMap { name -> TodayPanel? in
                guard let panel = TodayPanel(rawValue: String(name)), !seen.contains(panel) else { return nil }
                seen.insert(panel)
                return panel
            }
        }
        for (index, zone) in fallback.zones.enumerated() {
            for (place, panel) in zone.enumerated() where !seen.contains(panel) {
                read[index].insert(panel, at: min(place, read[index].count))
            }
        }
        self.columns = fallback.columns
        self.zones = read
    }

    var isStandard: Bool { self == TodayArrangement.standard(columns: columns) }

    // MARK: Looking things up

    /// The zones that are columns. Empty when there is one column, since
    /// then the single zone is simply the page.
    var columnZones: Range<Int> {
        columns <= 1 ? 0..<0 : 1..<(zones.count - 1)
    }

    /// The zone at the foot of the page, when there is one.
    var bottomZone: Int? {
        columns <= 1 ? nil : zones.count - 1
    }

    /// Every panel from the top of the page to the bottom, zone by zone.
    var readingOrder: [TodayPanel] { zones.flatMap { $0 } }

    /// Where a panel is: which zone, and how far down it.
    func position(of panel: TodayPanel) -> (zone: Int, index: Int)? {
        for (zone, panels) in zones.enumerated() {
            if let index = panels.firstIndex(of: panel) { return (zone, index) }
        }
        return nil
    }

    /// The column zones worth drawing. While rearranging, every column is
    /// drawn so an empty one can be dropped into. Otherwise a column with
    /// nothing showing is left out, and its neighbours take the room.
    func shownColumns(includingEmpty: Bool, isShowing: (TodayPanel) -> Bool) -> [Int] {
        columnZones.filter { includingEmpty || zones[$0].contains(where: isShowing) }
    }

    /// The column that should be given the most room: the one holding the
    /// garden plans, which are drawn to scale and need the width.
    func roomiestColumn(isShowing: (TodayPanel) -> Bool) -> Int? {
        columnZones.first { zones[$0].contains(.plans) && isShowing(.plans) }
    }

    // MARK: Moving panels

    /// Puts a panel where another one is. The other, and anything after
    /// it, moves along by one. This is what dropping one card onto
    /// another does.
    mutating func move(_ panel: TodayPanel, onto target: TodayPanel) {
        guard panel != target, let from = position(of: panel), let to = position(of: target) else { return }
        zones[from.zone].remove(at: from.index)
        // `to.index` was read before the panel was taken out. Putting the
        // panel back at that same number lands it in the target's old
        // place whichever direction it came from.
        zones[to.zone].insert(panel, at: min(to.index, zones[to.zone].count))
    }

    /// Puts a panel at the end of a zone. This is what dropping a card
    /// into the space at the foot of a column does.
    mutating func move(_ panel: TodayPanel, toEndOf zone: Int) {
        guard zones.indices.contains(zone), let from = position(of: panel) else { return }
        zones[from.zone].remove(at: from.index)
        zones[zone].append(panel)
    }

    /// Whether a panel has anywhere to go one step earlier (-1) or one
    /// step later (+1). False for the very first and very last places.
    func canNudge(_ panel: TodayPanel, by step: Int) -> Bool {
        guard let place = position(of: panel) else { return false }
        if step < 0 { return place.index > 0 || place.zone > 0 }
        return place.index < zones[place.zone].count - 1 || place.zone < zones.count - 1
    }

    /// Moves a panel one step earlier (-1) or later (+1) in reading
    /// order. Within a zone it swaps with its neighbour. At the edge of a
    /// zone it steps into the next zone along. This is what the two arrow
    /// buttons on each card do, so every place can be reached without
    /// dragging.
    mutating func nudge(_ panel: TodayPanel, by step: Int) {
        guard step != 0, canNudge(panel, by: step), let place = position(of: panel) else { return }
        if step < 0 {
            if place.index > 0 {
                zones[place.zone].swapAt(place.index, place.index - 1)
            } else {
                zones[place.zone].remove(at: place.index)
                zones[place.zone - 1].append(panel)
            }
        } else {
            if place.index < zones[place.zone].count - 1 {
                zones[place.zone].swapAt(place.index, place.index + 1)
            } else {
                zones[place.zone].remove(at: place.index)
                zones[place.zone + 1].insert(panel, at: 0)
            }
        }
    }
}

/// What a dragged card is being held over: another card, or the space at
/// the foot of a zone.
enum TodayDropTarget: Equatable {
    case panel(TodayPanel)
    case endOfZone(Int)
}
