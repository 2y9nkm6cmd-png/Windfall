//
//  WidgetViews.swift
//  WindfallShared
//
//  How each widget is drawn.
//
//  These are ordinary SwiftUI views that know nothing about widgets.
//  The widget program wraps each one in what iOS needs (see
//  WindfallWidgets.swift), and the app can show the very same views on
//  a checking page, which is how they are looked at without a phone.
//
//  The drawings they follow are row 5 of the "Windfall redesign" canvas.
//

import Foundation
import SwiftUI
import ImageIO

// MARK: - The two looks

/// Both looks stand on the app icon's own background, so a widget sits
/// on the Home Screen like a piece of the icon. Paper follows light and
/// dark mode as the icon does: cream in light, the icon's green in dark.
/// Garden green is the icon's green with cream text, the same in both.
nonisolated enum WidgetLook: String, CaseIterable {
    case paper, green
}

/// One set of colours for a widget. A view asks for `palette.leaf`
/// and never names a colour value itself, as with `Theme` in the app.
struct WidgetPalette: Sendable {
    let ground, inset, ink, soft, leaf, onLeaf, fill, amber, line: Color
    /// Which drawing of Eira's snowdrop suits this background. `nil`
    /// means the one for light or dark mode, whichever is showing.
    let snowdrop: SnowdropStyle?

    /// The app's own named colours, from the asset catalogue.
    static let paper = WidgetPalette(
        ground: Color("Colours/IconGround"), inset: Color("Colours/Card"), ink: Color("Colours/Ink"),
        soft: Color("Colours/InkSoft"), leaf: Color("Colours/Leaf"), onLeaf: Color("Colours/OnLeaf"),
        fill: Color("Colours/LeafFill"), amber: Color("Colours/Amber"), line: Color("Colours/Hairline"),
        snowdrop: nil)

    static let green = WidgetPalette(
        ground: Color(hex: 0x06421B), inset: Color(hex: 0x0E4F25), ink: Color(hex: 0xF8F1E5),
        soft: Color(hex: 0xB9C9B4), leaf: Color(hex: 0xC4DC7C), onLeaf: Color(hex: 0x06421B),
        fill: Color(hex: 0x1F6234), amber: Color(hex: 0x5A4520), line: Color(hex: 0x2B5F3A),
        snowdrop: .onCream)

    static func of(_ look: WidgetLook) -> WidgetPalette { look == .green ? .green : .paper }
}

extension Color {
    /// A colour from its six-figure code, such as 0x0C2C14.
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

enum WidgetSize {
    case small, medium, large
}

// MARK: - Small pieces

/// One of the app's own icons, painted in whatever colour is asked for.
struct WidgetIcon: View {
    let name: String
    var size: CGFloat = 20

    var body: some View {
        Image("Icons/\(name)")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    /// The icon for a kind of job.
    static func name(forJob kind: String) -> String {
        switch kind {
        case "frost": return "clear-night"
        case "wind": return "windy"
        case "dry": return "sunny"
        case "harvest": return "harvest"
        default: return "sowing"
        }
    }
}

/// A small rounded label, such as "Last chance".
struct WidgetTag: View {
    let text: String
    let background: Color
    let ink: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background, in: .rect(cornerRadius: 9))
            .foregroundStyle(ink)
    }
}

/// Eira's snowdrop on its circle, as in the app. The drawing is in
/// SnowdropDrawing.swift, shared with the app, so the two cannot differ.
///
/// The Paper look follows light and dark mode, as the app's symbol
/// does. The Garden green look is always green, so it names the style
/// that stands on a cream circle (`palette.snowdrop`).
struct WidgetEiraDisc: View {
    let palette: WidgetPalette
    var size: CGFloat = 44

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SnowdropOnDisc(style: palette.snowdrop ?? .following(colorScheme), size: size)
    }
}

/// "-1°", with a proper minus sign.
nonisolated func widgetDegrees(_ celsius: Double) -> String {
    let whole = Int(celsius.rounded())
    return (whole < 0 ? "−\(-whole)" : "\(whole)") + "°"
}

private func serif(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .serif) }

/// The small green heading at the top of a widget.
private struct WidgetHeading: View {
    let text: String
    var right: String?
    let palette: WidgetPalette

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(palette.leaf)
            Spacer(minLength: 4)
            if let right { Text(right).font(.system(size: 12)).foregroundStyle(palette.soft) }
        }
    }
}

/// Shown when the shared file has nothing for today.
private struct WidgetStale: View {
    let palette: WidgetPalette
    var body: some View {
        Text("Open Windfall to bring this up to date.")
            .font(.system(size: 13))
            .foregroundStyle(palette.soft)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - This week

struct WeekWidgetView: View {
    /// Nil when the shared file has nothing for today.
    let jobs: [WidgetJob]?
    let ticked: Set<String>
    let size: WidgetSize
    let palette: WidgetPalette
    /// Turns a tick ring into a button. The widget supplies this, as
    /// only a widget can press a button without opening the app.
    var tickControl: ((WidgetJob, AnyView) -> AnyView)?

    private var toDo: [WidgetJob] { (jobs ?? []).filter { !ticked.contains($0.id) } }

    var body: some View {
        switch size {
        case .small: small
        case .medium: medium
        case .large: large
        }
    }

    private var countWords: String { toDo.count == 1 ? "1 job" : "\(toDo.count) jobs" }

    @ViewBuilder private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeading(text: "This week", right: jobs == nil ? nil : countWords, palette: palette)
            if jobs == nil {
                WidgetStale(palette: palette)
            } else if let job = toDo.first {
                Spacer(minLength: 4)
                WidgetIcon(name: WidgetIcon.name(forJob: job.kind), size: 26).foregroundStyle(palette.leaf)
                Text(job.title).font(serif(19)).lineLimit(2).minimumScaleFactor(0.8).padding(.top, 5)
                Text(job.detail).font(.system(size: 12.5)).foregroundStyle(palette.soft).lineLimit(3).padding(.top, 3)
            } else {
                nothing
            }
        }
        .foregroundStyle(palette.ink)
    }

    private var nothing: some View {
        Text("Nothing pressing this week.")
            .font(serif(18))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    @ViewBuilder private var medium: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetHeading(text: "This week", right: toDo.count > 3 ? "\(toDo.count - 3) more" : nil, palette: palette)
            if jobs == nil {
                WidgetStale(palette: palette)
            } else if toDo.isEmpty {
                nothing
            } else {
                ForEach(toDo.prefix(3)) { job in
                    HStack(spacing: 10) {
                        WidgetIcon(name: WidgetIcon.name(forJob: job.kind)).foregroundStyle(palette.leaf)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(job.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                            Text(job.detail).font(.system(size: 12)).foregroundStyle(palette.soft).lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(palette.ink)
    }

    @ViewBuilder private var large: some View {
        let all = jobs ?? []
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week").font(serif(22))
                Spacer()
                if jobs != nil {
                    Text("\(toDo.count) of \(all.count) to do").font(.system(size: 12)).foregroundStyle(palette.soft)
                }
            }
            if jobs == nil {
                WidgetStale(palette: palette)
            } else if all.isEmpty {
                nothing
            } else {
                ForEach(all.prefix(5)) { job in
                    let done = ticked.contains(job.id)
                    HStack(spacing: 8) {
                        tick(job, done: done)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(job.title).font(.system(size: 15, weight: .semibold)).strikethrough(done).lineLimit(1)
                            Text(job.detail).font(.system(size: 12.5)).foregroundStyle(palette.soft).lineLimit(2)
                        }
                        Spacer(minLength: 4)
                        WidgetIcon(name: WidgetIcon.name(forJob: job.kind)).foregroundStyle(palette.leaf)
                    }
                    .frame(minHeight: 50)
                }
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(palette.ink)
    }

    /// The ring beside a job: empty to do, filled with a tick when done.
    private func tick(_ job: WidgetJob, done: Bool) -> some View {
        let ring = AnyView(
            ZStack {
                if done {
                    Circle().fill(palette.leaf)
                    WidgetIcon(name: "check", size: 13).foregroundStyle(palette.onLeaf)
                } else {
                    Circle().strokeBorder(palette.leaf, lineWidth: 1.6)
                }
            }
            .frame(width: 22, height: 22)
            // The ring is small, so the space round it counts as part of it.
            .frame(width: 40, height: 44)
            .contentShape(.rect)
            .accessibilityLabel(done ? "Untick \(job.title)" : "Tick off \(job.title)")
        )
        return tickControl?(job, ring) ?? ring
    }
}

// MARK: - This month

struct MonthWidgetView: View {
    let month: WidgetMonth?
    let size: WidgetSize
    let palette: WidgetPalette

    private var name: String {
        guard let month, (1...12).contains(month.month) else { return "This month" }
        return Calendar.current.monthSymbols[month.month - 1]
    }

    var body: some View {
        Group {
            if let month {
                if size == .small {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(name).font(serif(22))
                        counts(month, short: false).padding(.top, 9)
                        Spacer(minLength: 4)
                        if month.lastChances > 0 {
                            WidgetTag(text: month.lastChances == 1 ? "1 last chance" : "\(month.lastChances) last chances",
                                      background: palette.amber, ink: palette.ink)
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(name).font(serif(22)).lineLimit(1).minimumScaleFactor(0.7)
                            counts(month, short: true).padding(.top, 9)
                            Spacer(minLength: 0)
                        }
                        .frame(width: 112, alignment: .leading)
                        Rectangle().fill(palette.line).frame(width: 1)
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(month.lines.prefix(3)) { line in
                                HStack(spacing: 6) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(line.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                                        Text(line.job).font(.system(size: 12)).foregroundStyle(palette.soft).lineLimit(1)
                                    }
                                    Spacer(minLength: 4)
                                    if let tag = line.tag {
                                        WidgetTag(text: tag, background: line.isPressing ? palette.amber : palette.fill, ink: palette.ink)
                                    } else if let wait = line.wait {
                                        Text(wait).font(.system(size: 12)).foregroundStyle(palette.soft).lineLimit(1)
                                    }
                                }
                            }
                            if month.lines.isEmpty {
                                Text("Nothing to sow, plant or pick this month.").font(.system(size: 13)).foregroundStyle(palette.soft)
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .center)
                    }
                }
            } else {
                VStack(alignment: .leading) {
                    Text("This month").font(serif(22))
                    WidgetStale(palette: palette)
                }
            }
        }
        .foregroundStyle(palette.ink)
    }

    private func counts(_ month: WidgetMonth, short: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            countLine(palette.leaf, "\(month.toSowOrPlant) \(short ? "sow or plant" : "to sow or plant")")
            countLine(Color("Colours/Sun"), "\(month.toHarvest) \(short ? "harvest" : "to harvest")")
            countLine(Color("Colours/Petal"), "\(month.inFlower) in flower")
        }
    }

    private func countLine(_ dot: Color, _ text: String) -> some View {
        HStack(spacing: 7) {
            Circle().fill(dot).frame(width: 8, height: 8).accessibilityHidden(true)
            Text(text).font(.system(size: 13)).lineLimit(1).minimumScaleFactor(0.8)
        }
    }
}

// MARK: - Frost and weather

struct FrostWidgetView: View {
    /// Tonight's lowest temperature. Nil when there is no forecast.
    let tonightC: Double?
    let nights: [(name: String, lowC: Double)]
    let rain: String?
    let size: WidgetSize
    let palette: WidgetPalette

    // ⚠️ CHECK: the same two levels as "This week" uses, 0 and 2 degrees.
    private static let frostC = 0.0
    private static let nearFrostC = 2.0

    /// What tonight's temperature means, in a few words.
    static func words(for low: Double) -> String {
        if low <= frostC { return "Frost. Cover anything tender before dark." }
        if low <= nearFrostC { return "Close to freezing. Frost on the ground is possible." }
        return "No frost expected."
    }

    private var heading: some View {
        HStack(spacing: 6) {
            WidgetIcon(name: "clear-night", size: 18)
            Text("Tonight").font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(palette.leaf)
    }

    var body: some View {
        Group {
            if let tonightC {
                if size == .small {
                    VStack(alignment: .leading, spacing: 0) {
                        heading
                        Text(widgetDegrees(tonightC)).font(serif(48))
                        Spacer(minLength: 2)
                        Text(Self.words(for: tonightC)).font(.system(size: 12.5)).foregroundStyle(palette.soft).lineLimit(3)
                    }
                } else {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 0) {
                            heading
                            Text(widgetDegrees(tonightC)).font(serif(44))
                            Spacer(minLength: 0)
                            if tonightC <= Self.nearFrostC {
                                WidgetTag(text: tonightC <= Self.frostC ? "Frost" : "Near frost", background: palette.fill, ink: palette.ink)
                            }
                        }
                        .frame(width: 104, alignment: .leading)
                        Rectangle().fill(palette.line).frame(width: 1)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Lowest each night").font(.system(size: 12, weight: .semibold)).foregroundStyle(palette.leaf)
                            Spacer(minLength: 0)
                            HStack(spacing: 0) {
                                ForEach(nights, id: \.name) { night in
                                    VStack(spacing: 5) {
                                        Text(night.name).font(.system(size: 12)).foregroundStyle(palette.soft)
                                        mark(for: night.lowC)
                                        Text(widgetDegrees(night.lowC))
                                            .font(.system(size: 15, weight: night.lowC <= Self.frostC ? .semibold : .regular))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .accessibilityElement(children: .combine)
                                }
                            }
                            Spacer(minLength: 0)
                            Text(rain ?? "No rain to speak of in the next five days")
                                .font(.system(size: 12)).foregroundStyle(palette.soft).lineLimit(1).minimumScaleFactor(0.8)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading) {
                    heading
                    WidgetStale(palette: palette)
                }
            }
        }
        .foregroundStyle(palette.ink)
    }

    /// A snowflake for a frost and a ring for close to freezing, so the
    /// nights can be told apart without relying on colour.
    @ViewBuilder private func mark(for low: Double) -> some View {
        if low <= Self.frostC {
            Image(systemName: "snowflake").font(.system(size: 12, weight: .semibold)).foregroundStyle(palette.leaf)
                .accessibilityLabel("Frost").frame(height: 14)
        } else if low <= Self.nearFrostC {
            Image(systemName: "circle").font(.system(size: 10, weight: .semibold)).foregroundStyle(palette.leaf)
                .accessibilityLabel("Close to freezing").frame(height: 14)
        } else {
            Color.clear.frame(width: 14, height: 14)
        }
    }
}

// MARK: - Identify

struct IdentifyWidgetView: View {

    enum Style {
        /// The button alone (small).
        case button
        /// The button with Eira's last answer beside it (medium).
        case withAnswer
        /// The last answer alone, under its photo (small).
        case answerOnly
    }

    let answer: WidgetAnswer?
    let photo: CGImage?
    let style: Style
    let palette: WidgetPalette

    var body: some View {
        Group {
            switch style {
            case .button:
                button(circle: 72, text: 19, sub: "Give Eira a photo")
            case .withAnswer:
                HStack(spacing: 12) {
                    Link(destination: WidgetLink.identify) { button(circle: 56, text: 15, sub: nil) }
                        .frame(width: 104)
                    Rectangle().fill(palette.line).frame(width: 1)
                    answerSide.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            case .answerOnly:
                answerOnly
            }
        }
        .foregroundStyle(palette.ink)
    }

    private func button(circle: CGFloat, text: CGFloat, sub: String?) -> some View {
        VStack(spacing: 5) {
            Circle().fill(palette.leaf)
                .overlay(WidgetIcon(name: "photo", size: circle * 0.48).foregroundStyle(palette.onLeaf))
                .frame(width: circle, height: circle)
                .padding(.bottom, 3)
            Text("What is this?").font(serif(text)).foregroundStyle(palette.ink).lineLimit(1).minimumScaleFactor(0.8)
            if let sub { Text(sub).font(.system(size: 12.5)).foregroundStyle(palette.soft) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The photo, or a plain square where there is none.
    private func picture(corner: CGFloat) -> some View {
        Group {
            if let photo {
                Image(decorative: photo, scale: 1).resizable().scaledToFill()
            } else {
                palette.inset.overlay(WidgetIcon(name: "photo", size: 22).foregroundStyle(palette.soft))
            }
        }
        .clipShape(.rect(cornerRadius: corner))
    }

    private func whenWords(_ answer: WidgetAnswer) -> String {
        let style = Date.FormatStyle(date: .abbreviated, time: .shortened)
        return Calendar.current.isDateInToday(answer.when)
            ? "today, \(answer.when.formatted(date: .omitted, time: .shortened))" : answer.when.formatted(style)
    }

    @ViewBuilder private var answerSide: some View {
        if let answer {
            VStack(alignment: .leading, spacing: 6) {
                Text("Last answer · \(whenWords(answer))").font(.system(size: 12)).foregroundStyle(palette.soft).lineLimit(1)
                if let warning = answer.warning {
                    // A plant that could hurt someone: the warning takes
                    // the photo's place, so it cannot be missed.
                    Text(answer.headline).font(.system(size: 15, weight: .semibold)).lineLimit(2)
                    Text(warning).font(.system(size: 12)).lineLimit(4).minimumScaleFactor(0.85)
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(palette.amber, in: .rect(cornerRadius: 10))
                } else {
                    HStack(spacing: 10) {
                        picture(corner: 12).frame(width: 56, height: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(answer.headline).font(.system(size: 16, weight: .semibold)).lineLimit(2).minimumScaleFactor(0.85)
                            if let sub = answer.subheading {
                                Text(sub).font(.system(size: 12.5)).italic().foregroundStyle(palette.soft).lineLimit(1)
                            }
                        }
                    }
                    if let confidence = answer.confidence {
                        WidgetTag(text: confidence, background: palette.fill, ink: palette.ink)
                    }
                }
            }
        } else {
            Text("Eira's last answer to a photo will show here.").font(.system(size: 13)).foregroundStyle(palette.soft)
        }
    }

    @ViewBuilder private var answerOnly: some View {
        if let answer {
            VStack(alignment: .leading, spacing: 0) {
                if answer.warning == nil {
                    picture(corner: 0).frame(maxWidth: .infinity).frame(height: 84).clipped()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(answer.headline).font(.system(size: 15, weight: .semibold)).lineLimit(2).minimumScaleFactor(0.85)
                    if let warning = answer.warning {
                        Text(warning).font(.system(size: 11.5)).lineLimit(6).minimumScaleFactor(0.8)
                            .padding(6).background(palette.amber, in: .rect(cornerRadius: 8))
                    } else {
                        if let sub = answer.subheading {
                            Text(sub).font(.system(size: 12.5)).italic().foregroundStyle(palette.soft).lineLimit(1)
                        }
                        if let confidence = answer.confidence {
                            Text(confidence).font(.system(size: 12)).foregroundStyle(palette.soft)
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        } else {
            button(circle: 60, text: 16, sub: "No answer yet").padding(14)
        }
    }
}

/// Reads the small copy of the last photo from the shared folder.
nonisolated func widgetLastPhoto() -> CGImage? {
    guard let url = WidgetSummaryStore.photoURL,
          let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

// MARK: - Capture

struct CaptureWidgetView: View {
    let palette: WidgetPalette

    /// The six buttons of the Today screen, in the same order.
    private static let buttons: [(title: String, icon: String, kind: String)] = [
        ("Sowing", "sowing", "sowing"), ("Harvest", "harvest", "harvest"), ("Sighting", "sighting", "sighting"),
        ("FIT Count", "fit-count", "fit"), ("Note", "note", "note"), ("Photo", "photo", "photo")
    ]

    var body: some View {
        // A grid of three columns. Each button is a Link: a tap opens
        // the app with that button's address.
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(Self.buttons, id: \.kind) { button in
                Link(destination: WidgetLink.capture(button.kind)) {
                    VStack(spacing: 4) {
                        WidgetIcon(name: button.icon, size: 22).foregroundStyle(palette.leaf)
                        Text(button.title).font(.system(size: 12.5)).foregroundStyle(palette.ink).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(palette.inset, in: .rect(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(palette.line, lineWidth: 1))
                }
            }
        }
    }
}

// MARK: - Ask Eira

struct EiraWidgetView: View {
    let palette: WidgetPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                WidgetEiraDisc(palette: palette, size: 44)
                Spacer()
                Circle().strokeBorder(palette.line, lineWidth: 1)
                    .overlay(WidgetIcon(name: "microphone", size: 22).foregroundStyle(palette.leaf))
                    .frame(width: 44, height: 44)
            }
            Spacer(minLength: 4)
            Text("Ask Eira").font(serif(20))
            Text("Opens her chat").font(.system(size: 13)).foregroundStyle(palette.soft).padding(.top, 3)
        }
        .foregroundStyle(palette.ink)
    }
}
