//
//  Theme.swift
//  Windfall
//
//  How Windfall looks: its colours, its text, its icons and its glass.
//
//  Everything about the look is named here once. A screen never writes
//  a colour value of its own. It asks for `Theme.paper` or `Theme.leaf`,
//  so changing the look later means changing one place.
//
//  Where the values live:
//    Colours   Design/colours.json, built into the asset catalogue
//    Icons     Design/Icons/*.svg, built into the asset catalogue
//  Both are built by Tools/design/build_design_assets.py.
//
//  "Liquid glass" is Apple's name for the see-through, light-bending
//  material in iOS 26 and macOS 26. The `.glassEffect` modifier below is
//  Apple's own. Glass needs something behind it to bend, which is why the
//  paper background has soft washes of colour.
//

import SwiftUI

// MARK: - Colours

enum Theme {

    // Each colour has a light and a dark value in the asset catalogue.
    // The app picks the right one by itself when dark mode is switched on.
    static let paper = Color("Colours/Paper")
    static let card = Color("Colours/Card")
    static let hairline = Color("Colours/Hairline")
    static let ink = Color("Colours/Ink")
    static let inkSoft = Color("Colours/InkSoft")

    /// The one green: the main button, icons and links.
    static let leaf = Color("Colours/Leaf")
    static let onLeaf = Color("Colours/OnLeaf")
    static let leafFill = Color("Colours/LeafFill")
    static let amber = Color("Colours/Amber")
    static let sun = Color("Colours/Sun")
    static let journalCard = Color("Colours/JournalCard")
    static let water = Color("Colours/Water")
    static let petal = Color("Colours/Petal")

    static let sidebar = Color("Colours/Sidebar")
    static let sidebarInk = Color("Colours/SidebarInk")
    static let sidebarSelected = Color("Colours/SidebarSelected")
    static let sidebarSelectedInk = Color("Colours/SidebarSelectedInk")

    /// The five jobs on the Year page. Chosen as a set that people who
    /// are colour-blind can tell apart, so change them together.
    static let sowIndoors = Color("Colours/SowIndoors")
    static let sowOutdoors = Color("Colours/SowOutdoors")
    static let plantOut = Color("Colours/PlantOut")
    static let harvest = Color("Colours/Harvest")
    static let flowering = Color("Colours/Flowering")

    /// Eira's circle and her snowdrop. They swap over in dark mode.
    static let eiraDisc = Color("Colours/EiraDisc")
    static let eiraFlower = Color("Colours/EiraFlower")

    static let cardRadius: CGFloat = 22
}

// MARK: - Text

extension Font {
    /// The large serif title at the top of a screen, such as "Today".
    /// Medium weight, not bold, so it stays light on the page.
    static let screenTitle = Font.system(.largeTitle, design: .serif, weight: .medium)
    /// The "Windfall" name beside the sprig.
    static let wordmark = Font.system(.title2, design: .serif, weight: .regular)
}

// MARK: - Icons

/// Every icon the app draws, by name. The raw value is the icon's name in
/// the asset catalogue, which is its file name in Design/Icons.
///
/// To change an icon, replace its SVG file and run the build script. No
/// code changes are needed.
enum WIcon: String {
    case today, gardens, year, plans, plants, wildlife, journal, settings
    case search, saved
    case sowing, harvest, sighting, note, photo
    case fitCount = "fit-count"
    case journalEntry = "journal-entry"
    case microphone, add, check, close, north
    case arrowRight = "arrow-right"
    case chevronRight = "chevron-right"
    case sunny, cloudy, rain, windy, temperature
    case partlyCloudy = "partly-cloudy"
    case clearNight = "clear-night"
    case butterfly, bee, ladybird
    case sprig
}

/// Draws one icon at a size. Outline icons take the colour of the text
/// around them. Colour icons are shown as drawn.
struct WIconView: View {
    let icon: WIcon
    var size: CGFloat = 24

    init(_ icon: WIcon, size: CGFloat = 24) {
        self.icon = icon
        self.size = size
    }

    var body: some View {
        Image("Icons/\(icon.rawValue)")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            // The picture is decoration. Whatever holds it says what it is.
            .accessibilityHidden(true)
    }
}

// MARK: - Glass and paper

extension View {

    /// Turns a view into a panel of frosted glass with rounded corners.
    /// The slight cream tint keeps text on it easy to read.
    func glassCard(cornerRadius: CGFloat = Theme.cardRadius, padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .glassEffect(.regular.tint(Theme.card.opacity(0.55)),
                         in: .rect(cornerRadius: cornerRadius))
    }

    /// Gives a screen the cream paper background. Lists and forms have a
    /// grey background of their own, which is hidden first.
    ///
    /// On a Mac it also asks any Form on the screen to use the "grouped"
    /// look: boxed sections that scroll and fill the window, as on an
    /// iPhone. Left alone, a Mac lays a Form out in two columns that
    /// stop where the rows stop, which left bare bands above and below.
    func paperScreen() -> some View {
        self
            #if os(macOS)
            .formStyle(.grouped)
            // On a Mac, lets a two-finger swipe go back from this page
            // if it was opened on top of another. See PageZoom.swift.
            .background { BackSwipeMarker() }
            #endif
            .scrollContentBackground(.hidden)
            .background { PaperBackground(followsWindow: true) }
    }
}

/// The cream paper behind every screen, with two soft washes of colour so
/// that glass panels have something to bend.
struct PaperBackground: View {

    /// True for a page in the main window. Its washes of colour are then
    /// drawn where the window's own are, not afresh inside the page.
    ///
    /// Why it matters: the window has this background, and so does each
    /// page in it. Each used to work its washes out from its own edges.
    /// A page starts to the right of the sidebar, so its yellow wash sat
    /// in a different place from the window's, and the join showed as a
    /// rectangle behind the sidebar (William's picture, 13 November
    /// 2026). Drawn from the window's edges, the two match and the
    /// sidebar floats on one unbroken background.
    var followsWindow = false

    @Environment(\.colorScheme) private var colorScheme
    /// A speed check, switched in Settings. With it on, the two washes of
    /// colour are left out. They are large and heavily blurred, which is
    /// work for the graphics chip, so this shows whether they are what
    /// makes the app feel slow.
    @AppStorage("plainBackground") private var isPlain = false

    var body: some View {
        if isPlain {
            Theme.paper.ignoresSafeArea()
        } else {
            washes
        }
    }

    private var washes: some View {
        GeometryReader { geometry in
            let own = geometry.size
            // Where this view is in the window.
            let placed = geometry.frame(in: .global)
            let window = PaperCanvas.shared.frame
            let follows = followsWindow && window.width > 0 && own.width > 0
            // The space the washes are worked out for.
            let width = follows ? window.width : own.width
            let height = follows ? window.height : own.height
            // If the page has been enlarged (Command and plus on a Mac),
            // what is drawn here comes out that much bigger, so it is
            // drawn that much smaller to land in the same place.
            let zoom = follows ? max(placed.width / own.width, 0.1) : 1
            // How far the window's middle is from this view's middle.
            let acrossShift = follows ? window.midX - placed.midX : 0
            let downShift = follows ? window.midY - placed.midY : 0
            ZStack {
                Theme.paper
                Circle()
                    .fill(Theme.leafFill.opacity(colorScheme == .dark ? 0.30 : 0.45))
                    .frame(width: width * 0.7 / zoom)
                    .blur(radius: 110 / zoom)
                    .offset(x: (width * 0.38 + acrossShift) / zoom, y: (-height * 0.42 + downShift) / zoom)
                Circle()
                    .fill(Theme.sun.opacity(colorScheme == .dark ? 0.08 : 0.16))
                    .frame(width: width * 0.6 / zoom)
                    .blur(radius: 120 / zoom)
                    .offset(x: (-width * 0.36 + acrossShift) / zoom, y: (height * 0.44 + downShift) / zoom)
            }
        }
        .ignoresSafeArea()
    }
}

/// Where the main window's background is and how big, so that every
/// page can draw the same washes. Set by the window's own background
/// (MainTabView).
@Observable
final class PaperCanvas {
    static let shared = PaperCanvas()
    var frame: CGRect = .zero
}

// MARK: - Small parts used on several screens

extension ToolbarItemPlacement {

    /// Where a screen's second button goes, such as a filter beside
    /// "New entry".
    ///
    /// SwiftUI's own name for this is `.secondaryAction`. On an iPhone or
    /// iPad that tucks the button into the "more" menu, which is right.
    /// On a Mac it puts the button in the middle of the bar at the top
    /// of the window, on its own, a long way from the button it belongs
    /// with. So on a Mac this asks for `.primaryAction`, which is the
    /// right-hand end, beside the main button.
    static var besideMain: ToolbarItemPlacement {
        #if os(macOS)
        return .primaryAction
        #else
        return .secondaryAction
        #endif
    }
}

/// A small coloured label, such as "Confirmed" or "Provisional".
struct StatusTag: View {
    let text: String
    let fill: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(fill, in: .capsule)
    }
}

/// A tick box. Empty it is an outline. Ticked it fills with green.
struct TickBox: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(isOn ? Theme.leaf : Color.clear)
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(Theme.leaf, lineWidth: 1.6)
            if isOn {
                WIconView(.check, size: 14)
                    .foregroundStyle(Theme.onLeaf)
            }
        }
        .frame(width: 20, height: 20)
    }
}

/// The small drawing in the top corner of a screen: a spray of leaves and
/// one open flower. It is drawn in code, so it has no picture file.
struct BotanicalCorner: View {

    var body: some View {
        Canvas { context, size in
            // The drawing is designed on a 150 by 96 grid and scaled to fit.
            let scale = min(size.width / 150, size.height / 96)
            context.scaleBy(x: scale, y: scale)

            // The stem: a gentle curve from bottom left to the flower.
            var stem = Path()
            stem.move(to: CGPoint(x: 6, y: 90))
            stem.addQuadCurve(to: CGPoint(x: 108, y: 40), control: CGPoint(x: 62, y: 86))
            context.stroke(stem, with: .color(Theme.leaf.opacity(0.75)),
                           style: StrokeStyle(lineWidth: 1.3, lineCap: .round))

            // Leaves: where each starts, which way it points and how long.
            let leaves: [(x: CGFloat, y: CGFloat, angle: CGFloat, length: CGFloat)] = [
                (24, 86, -55, 24), (40, 81, 20, 22), (56, 73, -62, 28),
                (72, 64, 12, 24), (88, 54, -70, 24), (60, 72, -120, 18)
            ]
            for spray in leaves {
                let shape = Self.leaf(from: CGPoint(x: spray.x, y: spray.y),
                                      angle: spray.angle, length: spray.length)
                context.fill(shape, with: .color(Theme.leafFill))
                context.stroke(shape, with: .color(Theme.leaf.opacity(0.7)), lineWidth: 1)
            }

            // The flower: five petals round a yellow centre.
            let centre = CGPoint(x: 116, y: 30)
            for index in 0..<5 {
                let angle = CGFloat(index) * 72 - 90
                let petal = Path(ellipseIn: CGRect(x: -9, y: -21, width: 18, height: 20))
                    .applying(CGAffineTransform(translationX: centre.x, y: centre.y)
                        .rotated(by: angle * .pi / 180))
                context.fill(petal, with: .color(Theme.petal))
                context.stroke(petal, with: .color(Theme.leaf.opacity(0.45)), lineWidth: 0.8)
            }
            let middle = Path(ellipseIn: CGRect(x: centre.x - 5, y: centre.y - 5, width: 10, height: 10))
            context.fill(middle, with: .color(Theme.sun))
        }
        .accessibilityHidden(true)
    }

    /// A pointed leaf: two curves from its base to its tip and back.
    private static func leaf(from base: CGPoint, angle: CGFloat, length: CGFloat) -> Path {
        let radians = angle * .pi / 180
        let along = CGPoint(x: cos(radians), y: sin(radians))
        let across = CGPoint(x: -along.y, y: along.x)
        let tip = CGPoint(x: base.x + along.x * length, y: base.y + along.y * length)
        let bulge = length * 0.26
        let middle = CGPoint(x: base.x + along.x * length * 0.45, y: base.y + along.y * length * 0.45)
        var path = Path()
        path.move(to: base)
        path.addQuadCurve(to: tip, control: CGPoint(x: middle.x + across.x * bulge, y: middle.y + across.y * bulge))
        path.addQuadCurve(to: base, control: CGPoint(x: middle.x - across.x * bulge, y: middle.y - across.y * bulge))
        return path
    }
}
