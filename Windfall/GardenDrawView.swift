//
//  GardenDrawView.swift
//  Windfall
//
//  Drawing a garden on the plan itself: "drag it, then type the number".
//
//  The older editor (GardenEditorView.swift) is a long form of numbers
//  with the plan at the top, which scrolls away as you type. Here the
//  plan stays put and you work on it directly:
//
//    drag a bed            to move it
//    pull the ring         at its far corner, to change its size
//    twist the green knob  to turn it
//    tap a number          underneath, to type it exactly from the tape
//
//  Dragging gets a thing roughly right. The typed number is always the
//  last word, so the plan is still drawn from measurements.
//
//  Three parts:
//
//    DrawScale        turns metres on the ground into points on screen
//    GardenDrawBoard  the plan you can touch (also used, switched off,
//                     as the picture in the step-by-step screens)
//    GardenDrawView   the page: the board, and the chosen thing's numbers
//
//  The sums are in GardenDrawing.swift.
//
//  (William, 14 November 2026: "Put them all in for now so I can test
//  them out", of storyboards E, F and G on the design canvas.)
//

import SwiftUI
import SwiftData

// MARK: - Metres to points

/// The piece of ground a drawing shows, in metres: the plot, anything
/// drawn outside it (a neighbour's tree), and a margin all round so
/// things can be dragged out past the edge.
struct DrawBox: Equatable {

    static let margin = 1.5

    var minX: Double, minY: Double, maxX: Double, maxY: Double

    var across: Double { maxX - minX }
    var down: Double { maxY - minY }

    /// The box round a plot and a list of outlines, with the margin added.
    init(width: Double, depth: Double, outlines: [[PlanPoint]]) {
        let spots = outlines.flatMap { $0 } + [PlanPoint(x: 0, y: 0), PlanPoint(x: width, y: depth)]
        minX = (spots.map(\.x).min() ?? 0) - Self.margin
        minY = (spots.map(\.y).min() ?? 0) - Self.margin
        maxX = (spots.map(\.x).max() ?? width) + Self.margin
        maxY = (spots.map(\.y).max() ?? depth) + Self.margin
    }
}

/// One drawing's scale: how many points on the screen stand for a metre,
/// and where the plot's top-left corner sits.
struct DrawScale {

    /// Points for one metre.
    let scale: CGFloat
    /// Where the plot's top-left corner is, in points.
    let origin: CGPoint

    init(size: CGSize, ground: DrawBox) {
        let fit = max(min(size.width / CGFloat(ground.across), size.height / CGFloat(ground.down)), 1)
        scale = fit
        // Centre the box in the space, then step back from the box's
        // corner to the plot's corner, which is at 0, 0 on the plan.
        origin = CGPoint(x: (size.width - CGFloat(ground.across) * fit) / 2 - CGFloat(ground.minX) * fit,
                         y: (size.height - CGFloat(ground.down) * fit) / 2 - CGFloat(ground.minY) * fit)
    }

    /// A place on the plan, as a point on the screen.
    func place(_ spot: PlanPoint) -> CGPoint {
        CGPoint(x: origin.x + CGFloat(spot.x) * scale, y: origin.y + CGFloat(spot.y) * scale)
    }

    /// A point on the screen, as a place on the plan.
    func spot(_ point: CGPoint) -> PlanPoint {
        PlanPoint(x: Double((point.x - origin.x) / scale), y: Double((point.y - origin.y) / scale))
    }
}

/// The measuring lines the board can show for the chosen thing.
enum DrawMark: String {
    case fromLeft, fromTop, length, width
}

// MARK: - The board

/// The plan, drawn on one-metre squares, that can be touched.
struct GardenDrawBoard: View {

    let garden: Garden
    let beds: [Bed]
    let features: [GardenFeature]

    /// Which bed or feature is chosen. A Binding is a two-way link: the
    /// board can read the choice and change it, and the page that owns it
    /// sees the change.
    @Binding var chosenID: UUID?

    /// Switched off, the board is only a picture: nothing can be dragged.
    var isLive = true
    /// Which measuring lines to draw for the chosen thing.
    var marks: Set<DrawMark> = [.fromLeft, .fromTop]

    /// What a finger or pointer has hold of during a drag.
    private enum Grab {
        /// No drag is under way.
        case idle
        /// A drag began on bare ground, so it moves nothing.
        case nothing
        /// Moving a thing. The numbers are where it was when taken hold of.
        case move(id: UUID, startX: Double, startY: Double)
        /// Pulling the ring at the far corner.
        case size(id: UUID, startLength: Double, startWidth: Double)
        /// Twisting the green knob.
        case twist(id: UUID)
    }

    @State private var grab: Grab = .idle

    /// The ground shown while a drag is under way. Without this the
    /// drawing would rescale under the finger whenever a thing was
    /// dragged past the edge, and seem to slide away.
    @State private var heldBox: DrawBox?

    /// How far the knob stands off the end of a thing, in points.
    private let knobReach: CGFloat = 26

    private var plotWidth: Double { garden.widthMetres ?? 10 }
    private var plotDepth: Double { garden.depthMetres ?? 10 }

    /// Everything that can be drawn and dragged, features first so that
    /// beds are drawn on top of paths.
    private var things: [any PlanPlaceable] {
        features.map { $0 as any PlanPlaceable } + beds.map { $0 as any PlanPlaceable }
    }

    /// One thing as the drawing needs it. Making these in `body` matters:
    /// SwiftUI redraws a view when a record it READ while building `body`
    /// changes, and the Canvas below does its drawing later, where reads
    /// are not noticed.
    private struct Drawn {
        let id: UUID
        let name: String
        let outline: [PlanPoint]
        let x: Double, y: Double, length: Double, width: Double, rotation: Double
        let isBed: Bool
        let paint: Color
        /// Where a bed's sections divide, as shares of its length.
        let dividers: [Double]
    }

    private func outline(of thing: any PlanPlaceable) -> [PlanPoint] {
        thing.planIsRound
            ? PlanGeometry.ellipse(x: thing.originX, y: thing.originY, length: thing.planLength,
                                   width: thing.planWidth, rotation: thing.rotationDegrees)
            : PlanGeometry.rectangle(x: thing.originX, y: thing.originY, length: thing.planLength,
                                     width: thing.planWidth, rotation: thing.rotationDegrees)
    }

    private var drawn: [Drawn] {
        things.map { thing in
            var paint = Theme.card
            var dividers: [Double] = []
            if let feature = thing as? GardenFeature {
                switch feature.kind {
                case .water: paint = Theme.water
                case .tree, .hedge: paint = Theme.leafFill
                case .path: paint = Theme.hairline
                default: paint = Theme.paper
                }
            } else if let bed = thing as? Bed {
                let lengths = bed.orderedSections.map(\.lengthMetres)
                let total = lengths.reduce(0, +)
                var along = 0.0
                for length in lengths.dropLast() where total > 0 {
                    along += length / total
                    dividers.append(along)
                }
            }
            return Drawn(id: thing.planID, name: thing.planName, outline: outline(of: thing),
                         x: thing.originX, y: thing.originY, length: thing.planLength, width: thing.planWidth,
                         rotation: thing.rotationDegrees, isBed: thing is Bed, paint: paint, dividers: dividers)
        }
    }

    var body: some View {
        let shapes = drawn
        let width = plotWidth, depth = plotDepth
        let ground = heldBox ?? DrawBox(width: width, depth: depth, outlines: shapes.map(\.outline))
        GeometryReader { geometry in
            let fit = DrawScale(size: geometry.size, ground: ground)
            Canvas { context, _ in
                draw(shapes, in: &context, fit: fit, width: width, depth: depth)
            }
            .contentShape(.rect)
            .onTapGesture { point in
                chosenID = thing(at: point, fit: fit)?.planID
            }
            .gesture(dragging(fit, ground: ground))
            .allowsHitTesting(isLive)
        }
        // The same proportions as the ground shown, so there are no
        // empty bands beside a long thin garden.
        .aspectRatio(CGFloat(ground.across / ground.down), contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Plan of \(garden.name), \(beds.count) beds")
    }

    // MARK: Touching

    /// Where the ring for sizing sits: the corner opposite the first one.
    private func ringPoint(_ shape: Drawn, fit: DrawScale) -> CGPoint {
        fit.place(PlanGeometry.rectangle(x: shape.x, y: shape.y, length: shape.length, width: shape.width,
                                         rotation: shape.rotation)[2])
    }

    /// Where the green knob sits: off the far end, level with the middle.
    private func knobPoint(_ shape: Drawn, fit: DrawScale) -> CGPoint {
        let reach = shape.length + Double(knobReach / fit.scale)
        return fit.place(PlanGeometry.rectangle(x: shape.x, y: shape.y, length: reach, width: shape.width / 2,
                                                rotation: shape.rotation)[2])
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    /// The thing under a point. Beds are looked at before features, since
    /// they are drawn on top. A near miss still counts, because a path
    /// may be only a finger's width across.
    private func thing(at point: CGPoint, fit: DrawScale) -> (any PlanPlaceable)? {
        let spot = fit.spot(point)
        let topFirst = Array(things.reversed())
        if let hit = topFirst.first(where: { PlanGeometry.contains(spot, in: outline(of: $0)) }) { return hit }
        let near = topFirst.map { thing -> (thing: any PlanPlaceable, gap: CGFloat) in
            let middle = GardenDrawing.middle(x: thing.originX, y: thing.originY, length: thing.planLength,
                                              width: thing.planWidth, rotation: thing.rotationDegrees)
            return (thing, distance(fit.place(middle), point))
        }
        return near.filter { $0.gap < 22 }.min { $0.gap < $1.gap }?.thing
    }

    private func dragging(_ fit: DrawScale, ground: DrawBox) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                if case .idle = grab {
                    grab = takeHold(at: value.startLocation, fit: fit)
                    heldBox = ground
                }
                let dx = Double(value.translation.width / fit.scale)
                let dy = Double(value.translation.height / fit.scale)
                switch grab {
                case .idle, .nothing:
                    break
                case .move(let id, let startX, let startY):
                    guard let thing = things.first(where: { $0.planID == id }) else { return }
                    thing.originX = GardenDrawing.snapped(startX + dx)
                    thing.originY = GardenDrawing.snapped(startY + dy)
                case .size(let id, let startLength, let startWidth):
                    guard let thing = things.first(where: { $0.planID == id }) else { return }
                    let pull = GardenDrawing.alongAcross(dx: dx, dy: dy, rotation: thing.rotationDegrees)
                    thing.planLength = max(GardenDrawing.smallestSize, GardenDrawing.snapped(startLength + pull.along))
                    thing.planWidth = max(GardenDrawing.smallestSize, GardenDrawing.snapped(startWidth + pull.across))
                case .twist(let id):
                    guard let thing = things.first(where: { $0.planID == id }) else { return }
                    let here = fit.spot(value.location)
                    // The angle from the first corner to the finger,
                    // measured from "straight across the plan".
                    let toFinger = GardenDrawing.angle(dx: here.x - thing.originX, dy: here.y - thing.originY) - 90
                    // The knob is not on the bed's long edge but level
                    // with its middle, so it starts a little way round.
                    let reach = thing.planLength + Double(knobReach / fit.scale)
                    let knobStarts = atan2(thing.planWidth / 2, reach) * 180 / .pi
                    thing.rotationDegrees = GardenDrawing.snappedTurn(toFinger - knobStarts)
                }
            }
            .onEnded { _ in
                grab = .idle
                // Letting go lets the drawing take in the new layout.
                withAnimation(.smooth(duration: 0.25)) { heldBox = nil }
            }
    }

    /// Decides what a drag has hold of, from where it began.
    private func takeHold(at point: CGPoint, fit: DrawScale) -> Grab {
        if let shape = drawn.first(where: { $0.id == chosenID }) {
            if distance(point, ringPoint(shape, fit: fit)) < 24 {
                return .size(id: shape.id, startLength: shape.length, startWidth: shape.width)
            }
            if distance(point, knobPoint(shape, fit: fit)) < 24 {
                return .twist(id: shape.id)
            }
        }
        guard let thing = thing(at: point, fit: fit) else { return .nothing }
        chosenID = thing.planID
        return .move(id: thing.planID, startX: thing.originX, startY: thing.originY)
    }

    // MARK: Drawing

    private func path(_ points: [PlanPoint], fit: DrawScale) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: fit.place(first))
        for spot in points.dropFirst() { path.addLine(to: fit.place(spot)) }
        path.closeSubpath()
        return path
    }

    private func draw(_ shapes: [Drawn], in context: inout GraphicsContext, fit: DrawScale, width: Double, depth: Double) {
        // 1. The plot, on one-metre squares.
        let plot = path(PlanGeometry.rectangle(x: 0, y: 0, length: width, width: depth), fit: fit)
        context.fill(plot, with: .color(Theme.card))
        var squares = Path()
        for across in stride(from: 1.0, to: width, by: 1) {
            squares.move(to: fit.place(PlanPoint(x: across, y: 0)))
            squares.addLine(to: fit.place(PlanPoint(x: across, y: depth)))
        }
        for down in stride(from: 1.0, to: depth, by: 1) {
            squares.move(to: fit.place(PlanPoint(x: 0, y: down)))
            squares.addLine(to: fit.place(PlanPoint(x: width, y: down)))
        }
        context.stroke(squares, with: .color(Theme.hairline), lineWidth: 0.6)
        context.stroke(plot, with: .color(Theme.inkSoft), lineWidth: 1.4)

        // 2. Everything on it.
        for shape in shapes {
            let isChosen = shape.id == chosenID
            let outline = path(shape.outline, fit: fit)
            context.fill(outline, with: .color(isChosen && shape.isBed ? Theme.leafFill : shape.paint))
            // Lines between a bed's sections.
            for share in shape.dividers {
                let ends = PlanGeometry.rectangle(x: shape.x, y: shape.y, length: shape.length * share,
                                                  width: shape.width, rotation: shape.rotation)
                var divider = Path()
                divider.move(to: fit.place(ends[1]))
                divider.addLine(to: fit.place(ends[2]))
                context.stroke(divider, with: .color(Theme.hairline), lineWidth: 0.8)
            }
            context.stroke(outline, with: .color(isChosen ? Theme.leaf : Theme.ink.opacity(0.75)),
                           lineWidth: isChosen ? 2.2 : 1)
            if CGFloat(max(shape.length, shape.width)) * fit.scale > 38 {
                let middle = GardenDrawing.middle(x: shape.x, y: shape.y, length: shape.length, width: shape.width,
                                                  rotation: shape.rotation)
                context.draw(Text(shape.name).font(.caption).foregroundStyle(shape.isBed ? Theme.ink : Theme.inkSoft),
                             at: fit.place(middle))
            }
        }

        // 3. The chosen thing's measuring lines and handles.
        guard let chosen = shapes.first(where: { $0.id == chosenID }) else { return }
        let corner = PlanPoint(x: chosen.x, y: chosen.y)
        if marks.contains(.fromLeft) {
            measure(between: PlanPoint(x: 0, y: chosen.y), and: corner, saying: GardenDrawing.metres(chosen.x), in: &context, fit: fit)
        }
        if marks.contains(.fromTop) {
            measure(between: PlanPoint(x: chosen.x, y: 0), and: corner, saying: GardenDrawing.metres(chosen.y), in: &context, fit: fit)
        }
        let corners = PlanGeometry.rectangle(x: chosen.x, y: chosen.y, length: chosen.length, width: chosen.width,
                                             rotation: chosen.rotation)
        if marks.contains(.length) {
            measure(between: corners[0], and: corners[1], saying: GardenDrawing.metres(chosen.length), in: &context, fit: fit, bold: true)
        }
        if marks.contains(.width) {
            measure(between: corners[0], and: corners[3], saying: GardenDrawing.metres(chosen.width), in: &context, fit: fit, bold: true)
        }
        guard isLive else { return }
        // A dot on the corner every measurement is taken from.
        let cornerDot = fit.place(corner)
        context.fill(Path(ellipseIn: CGRect(x: cornerDot.x - 4, y: cornerDot.y - 4, width: 8, height: 8)), with: .color(Theme.leaf))
        // The ring, for size.
        let ring = ringPoint(chosen, fit: fit)
        let ringShape = Path(ellipseIn: CGRect(x: ring.x - 8, y: ring.y - 8, width: 16, height: 16))
        context.fill(ringShape, with: .color(Theme.card))
        context.stroke(ringShape, with: .color(Theme.leaf), lineWidth: 2.5)
        // The knob, for turning, on a short stalk.
        let knob = knobPoint(chosen, fit: fit)
        var stalk = Path()
        stalk.move(to: fit.place(GardenDrawing.middle(x: chosen.x, y: chosen.y, length: chosen.length * 2,
                                                      width: chosen.width, rotation: chosen.rotation)))
        stalk.addLine(to: knob)
        context.stroke(stalk, with: .color(Theme.leaf), lineWidth: 1.5)
        context.fill(Path(ellipseIn: CGRect(x: knob.x - 13, y: knob.y - 13, width: 26, height: 26)), with: .color(Theme.leaf))
        context.draw(Text(Image(systemName: "arrow.clockwise")).font(.footnote.weight(.bold)).foregroundStyle(Theme.onLeaf),
                     at: knob)
    }

    /// A green line between two places on the plan, with its length
    /// written on a patch of paper in the middle.
    private func measure(between oneEnd: PlanPoint, and otherEnd: PlanPoint, saying words: String, in context: inout GraphicsContext,
                         fit: DrawScale, bold: Bool = false) {
        let start = fit.place(oneEnd), end = fit.place(otherEnd)
        var line = Path()
        line.move(to: start)
        line.addLine(to: end)
        context.stroke(line, with: .color(Theme.leaf), style: StrokeStyle(lineWidth: bold ? 3 : 1.6, lineCap: .round))
        // Two short lines meeting at a corner would have their numbers
        // on top of each other, so a short line goes without. The
        // numbers are always written beneath the plan as well.
        guard marks.count == 1 || hypot(end.x - start.x, end.y - start.y) >= 44 else { return }
        let label = context.resolve(Text(words).font(.caption.weight(.semibold)).foregroundStyle(Theme.leaf))
        let size = label.measure(in: CGSize(width: 200, height: 40))
        let centre = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let patch = CGRect(x: centre.x - size.width / 2 - 4, y: centre.y - size.height / 2 - 1,
                           width: size.width + 8, height: size.height + 2)
        context.fill(Path(roundedRect: patch, cornerRadius: 5), with: .color(Theme.card))
        context.draw(label, at: centre)
    }
}

// MARK: - Typing a number

/// One measurement in a box, with "m" after it.
struct DrawNumberField: View {

    let title: String
    @Binding var value: Double
    var unit = "m"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
            FieldBox {
                HStack(spacing: 6) {
                    TextField(title, value: $value, format: .number.precision(.fractionLength(0...2)))
                        .font(.title3)
                        #if os(iOS)
                        .keyboardType(.numbersAndPunctuation)
                        #endif
                    Text(unit)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
    }
}

/// Bindings for a thing's numbers.
///
/// A Binding is made here by hand, from a "how to read it" and a "how to
/// write it", because a bed and a feature keep their sizes differently
/// and the fields should not have to know which they have.
enum DrawBindings {

    static func length(_ thing: any PlanPlaceable) -> Binding<Double> {
        Binding(get: { thing.planLength }, set: { thing.planLength = max(GardenDrawing.smallestSize, $0) })
    }

    static func width(_ thing: any PlanPlaceable) -> Binding<Double> {
        Binding(get: { thing.planWidth }, set: { thing.planWidth = max(GardenDrawing.smallestSize, $0) })
    }

    static func fromLeft(_ thing: any PlanPlaceable) -> Binding<Double> {
        Binding(get: { thing.originX }, set: { thing.originX = $0 })
    }

    static func fromTop(_ thing: any PlanPlaceable) -> Binding<Double> {
        Binding(get: { thing.originY }, set: { thing.originY = $0 })
    }

    static func turn(_ thing: any PlanPlaceable) -> Binding<Double> {
        Binding(get: { thing.rotationDegrees }, set: { thing.rotationDegrees = Compass.normalised($0) })
    }

    /// A plot's width or depth may be empty in the records. Typing
    /// nothing leaves it as it was.
    static func plot(_ value: Binding<Double?>, startingAt start: Double) -> Binding<Double> {
        Binding(get: { value.wrappedValue ?? start }, set: { value.wrappedValue = max(1, $0) })
    }
}

/// The four numbers of a bed or feature, side by side in two rows.
struct DrawFourNumbers: View {

    let thing: any PlanPlaceable

    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                DrawNumberField(title: "Length", value: DrawBindings.length(thing))
                DrawNumberField(title: "Width", value: DrawBindings.width(thing))
            }
            GridRow {
                DrawNumberField(title: "From the left edge", value: DrawBindings.fromLeft(thing))
                DrawNumberField(title: "From the top edge", value: DrawBindings.fromTop(thing))
            }
        }
    }
}

/// The sheet for typing a thing's numbers exactly.
private struct DrawNumbersSheet: View {

    let thing: any PlanPlaceable
    let garden: Garden
    let beds: [Bed]
    let features: [GardenFeature]
    let mark: DrawMark

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetPage(thing.planName, detail: "Measured from the top-left corner of the plot.",
                  dismissTitle: nil, confirmTitle: "Done", onConfirm: { dismiss() }) {
            SheetScroll {
                // The plan, as a picture, marking what is being typed.
                GardenDrawBoard(garden: garden, beds: beds, features: features,
                                chosenID: .constant(thing.planID), isLive: false, marks: [mark])
                    .frame(maxHeight: 240)
                    .frame(maxWidth: .infinity)
                SheetCard {
                    DrawFourNumbers(thing: thing)
                }
                SheetCard("More") {
                    DrawNumberField(title: "Turned clockwise", value: DrawBindings.turn(thing), unit: "°")
                    if let bed = thing as? Bed {
                        DrawNumberField(title: "Height, for a raised bed", value: Binding(
                            get: { bed.heightMetres ?? 0 }, set: { bed.heightMetres = $0 > 0 ? $0 : nil }))
                    } else if let feature = thing as? GardenFeature {
                        DrawNumberField(title: "Height, for its shade", value: Binding(
                            get: { feature.heightMetres }, set: { feature.heightMetres = max(0, $0) }))
                    }
                }
            }
        }
    }
}

// MARK: - Adding and repeating

/// Makes beds and features for a garden. Kept in one place so that the
/// drag screen and the step-by-step screens add things the same way.
enum DrawMaker {

    /// A new bed, with its sections, added to the records.
    @discardableResult
    static func addBed(named name: String, sections: Int, length: Double, width: Double, at spot: PlanPoint,
                       rotation: Double = 0, height: Double? = nil, to garden: Garden, after beds: [Bed],
                       in context: ModelContext) -> Bed {
        let bed = Bed(name: name)
        // Beds find their garden by this piece of text. See GardenLayout.swift.
        bed.siteRaw = garden.siteKey
        bed.displayOrder = (beds.map(\.displayOrder).max() ?? -1) + 1
        bed.lengthMetres = length
        bed.widthMetres = width
        bed.originX = spot.x
        bed.originY = spot.y
        bed.rotationDegrees = rotation
        bed.heightMetres = height
        let count = max(sections, 1)
        bed.addSections(count: count, lengthMetres: length / Double(count))
        context.insert(bed)
        return bed
    }

    /// A new shed, path, tree or other feature, at a starting size.
    @discardableResult
    static func addFeature(_ kind: FeatureKind, at spot: PlanPoint, to garden: Garden, in context: ModelContext) -> GardenFeature {
        let feature = GardenFeature(name: kind.displayName, kind: kind, siteKey: garden.siteKey)
        feature.originX = spot.x
        feature.originY = spot.y
        feature.lengthMetres = kind == .path ? 4 : 2
        feature.widthMetres = kind == .path ? 0.6 : 2
        context.insert(feature)
        return feature
    }

    /// A clear place for something new.
    static func freeSpot(beds: [Bed], features: [GardenFeature]) -> PlanPoint {
        GardenDrawing.freeSpot(below: beds.map(\.outline) + features.map(\.outline))
    }

    /// Copies of a bed in a row. Returns the new beds.
    @discardableResult
    static func repeatBed(_ bed: Bed, count: Int, gap: Double, goingDown: Bool, in garden: Garden,
                          beds: [Bed], context: ModelContext) -> [Bed] {
        let spots = GardenDrawing.repeatPositions(x: bed.originX, y: bed.originY, length: bed.planLength,
                                                  width: bed.planWidth, rotation: bed.rotationDegrees,
                                                  count: count, gap: gap, goingDown: goingDown)
        let names = GardenDrawing.nextBedNames(existing: beds.map(\.name), count: count)
        var made: [Bed] = []
        for (spot, name) in zip(spots, names) {
            made.append(addBed(named: name, sections: bed.orderedSections.count, length: bed.planLength,
                               width: bed.planWidth, at: spot, rotation: bed.rotationDegrees,
                               height: bed.heightMetres, to: garden, after: beds + made, in: context))
        }
        return made
    }
}

/// "Repeat": a row of beds that match the chosen one.
struct DrawRepeatSheet: View {

    let bed: Bed
    let garden: Garden
    let beds: [Bed]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var howMany = 3
    @State private var path = 0.6
    @State private var goingDown = true

    var body: some View {
        SheetPage("Repeat \(bed.planName)", detail: "A row of beds the same size.") {
            SheetScroll {
                SheetCard {
                    SettingRow("How many more") {
                        NumberStepper(value: $howMany, range: 1...12)
                    }
                    DrawNumberField(title: "Path between them", value: $path)
                    GlassSwitch(choices: [true, false], selection: $goingDown) { $0 ? "Going down" : "Going across" }
                    Text("Each will be \(GardenDrawing.metres(bed.planLength)) by \(GardenDrawing.metres(bed.planWidth)), with \(bed.orderedSections.count) sections.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            SheetMainButton(howMany == 1 ? "Add 1 bed" : "Add \(howMany) beds") {
                DrawMaker.repeatBed(bed, count: howMany, gap: max(0, path), goingDown: goingDown,
                                    in: garden, beds: beds, context: context)
                dismiss()
            }
        }
    }
}

/// "New bed": its name, how many sections and its size.
struct DrawNewBedSheet: View {

    let garden: Garden
    let beds: [Bed]
    let features: [GardenFeature]
    /// Told which bed was made, so the page can choose it.
    let made: (Bed) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var sections = 6
    @State private var length = 4.8
    @State private var width = 1.2

    var body: some View {
        SheetPage("New bed", detail: "It lands on the plan below the others. Drag it from there.") {
            SheetScroll {
                SheetCard {
                    FieldBox { TextField("Name", text: $name) }
                    SettingRow("Sections") {
                        NumberStepper(value: $sections, range: 1...12)
                    }
                    Grid(horizontalSpacing: 10) {
                        GridRow {
                            DrawNumberField(title: "Length", value: $length)
                            DrawNumberField(title: "Width", value: $width)
                        }
                    }
                }
            }
            SheetMainButton("Add the bed") {
                let bed = DrawMaker.addBed(named: name.trimmingCharacters(in: .whitespaces), sections: sections,
                                           length: max(GardenDrawing.smallestSize, length),
                                           width: max(GardenDrawing.smallestSize, width),
                                           at: DrawMaker.freeSpot(beds: beds, features: features),
                                           to: garden, after: beds, in: context)
                made(bed)
                dismiss()
            }
        }
        .onAppear {
            // Start from the next free name, and the last bed's size.
            name = GardenDrawing.nextBedNames(existing: beds.map(\.name), count: 1).first ?? "Bed"
            if let last = beds.last {
                length = last.planLength
                width = last.planWidth
                sections = max(last.orderedSections.count, 1)
            }
        }
    }
}

/// The plot's own two numbers.
struct DrawPlotSheet: View {

    @Bindable var garden: Garden
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetPage("The plot", detail: "Width is left to right. Depth is from the top of the plan to the bottom.",
                  dismissTitle: nil, confirmTitle: "Done", onConfirm: { dismiss() }) {
            SheetScroll {
                SheetCard {
                    Grid(horizontalSpacing: 10) {
                        GridRow {
                            DrawNumberField(title: "Width", value: DrawBindings.plot($garden.widthMetres, startingAt: 10))
                            DrawNumberField(title: "Depth", value: DrawBindings.plot($garden.depthMetres, startingAt: 10))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - The page

/// "Drag it, then type the number."
struct GardenDrawView: View {

    @Bindable var garden: Garden

    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Bed> { $0.retiredAt == nil },
           sort: [SortDescriptor(\Bed.displayOrder)]) private var allBeds: [Bed]
    @Query(sort: [SortDescriptor(\GardenFeature.createdAt)]) private var allFeatures: [GardenFeature]

    @State private var chosenID: UUID?
    @State private var sheet: Sheet?
    @State private var asksToRemove = false

    /// Which sheet is up. `Identifiable` lets SwiftUI tell them apart.
    private enum Sheet: Identifiable {
        case numbers(DrawMark), repeatBed, newBed, plot
        var id: String {
            switch self {
            case .numbers(let mark): return "numbers-\(mark.rawValue)"
            case .repeatBed: return "repeat"
            case .newBed: return "new"
            case .plot: return "plot"
            }
        }
    }

    private var beds: [Bed] { allBeds.filter { $0.siteRaw == garden.siteKey } }
    private var features: [GardenFeature] { allFeatures.filter { $0.siteRaw == garden.siteKey && $0.isPresent } }

    private var chosen: (any PlanPlaceable)? {
        if let bed = beds.first(where: { $0.id == chosenID }) { return bed }
        return features.first { $0.id == chosenID }
    }

    private var plotLine: String {
        guard let width = garden.widthMetres, let depth = garden.depthMetres else {
            return "\(garden.name) · not measured yet · a square is 1 m"
        }
        return "\(garden.name) · \(GardenDrawing.metres(width)) × \(GardenDrawing.metres(depth)) · a square is 1 m"
    }

    var body: some View {
        GeometryReader { geometry in
            // On a wide window the numbers sit beside the plan. On a
            // narrow one, beneath it.
            let isWide = geometry.size.width >= 760
            Group {
                if isWide {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) { heading; board }
                        ScrollView { panel.padding(.top, 62) }
                            .frame(width: 340)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        heading
                        board
                        ScrollView { panel.padding(.bottom, 90) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .paperScreen()
        .navigationTitle(garden.name.isEmpty ? "Garden" : garden.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Bed") { sheet = .newBed }
                    Divider()
                    ForEach(FeatureKind.allCases) { kind in
                        Button(kind.displayName) {
                            let feature = DrawMaker.addFeature(kind, at: DrawMaker.freeSpot(beds: beds, features: features),
                                                               to: garden, in: context)
                            chosenID = feature.id
                        }
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .numbers(let mark):
                if let chosen {
                    DrawNumbersSheet(thing: chosen, garden: garden, beds: beds, features: features, mark: mark)
                }
            case .repeatBed:
                if let bed = chosen as? Bed {
                    DrawRepeatSheet(bed: bed, garden: garden, beds: beds)
                }
            case .newBed:
                DrawNewBedSheet(garden: garden, beds: beds, features: features) { chosenID = $0.id }
            case .plot:
                DrawPlotSheet(garden: garden)
            }
        }
        .confirmationDialog("Take \(chosen?.planName ?? "this") off the plan?", isPresented: $asksToRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { removeChosen() }
        } message: {
            Text("Its records are kept. It is marked as no longer in use.")
        }
        .eiraLooksAt("the plan of \(garden.name.isEmpty ? "a garden" : "the garden called " + garden.name), being drawn",
                     short: garden.name.isEmpty ? nil : "the plan of \(garden.name)")
        .onAppear {
            // A checking aid: `-demoDrawChoose YES` starts with the first
            // bed chosen, so a still picture can show the handles.
            if UserDefaults.standard.bool(forKey: "demoDrawChoose") { chosenID = beds.first?.id }
        }
    }

    private var heading: some View {
        ScreenHeader(title: "Draw the plan", detail: plotLine)
    }

    private var board: some View {
        GardenDrawBoard(garden: garden, beds: beds, features: features, chosenID: $chosenID)
            .padding(4)
            .glassCard(cornerRadius: 18, padding: 4)
    }

    /// What sits under (or beside) the plan: the chosen thing's numbers,
    /// or the plot's when nothing is chosen.
    @ViewBuilder
    private var panel: some View {
        if let chosen {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(chosen.planName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    if let bed = chosen as? Bed {
                        Text(bed.orderedSections.count == 1 ? "1 section" : "\(bed.orderedSections.count) sections")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        tile("Length", GardenDrawing.metres(chosen.planLength)) { sheet = .numbers(.length) }
                        tile("Width", GardenDrawing.metres(chosen.planWidth)) { sheet = .numbers(.width) }
                    }
                    GridRow {
                        tile("From the left edge", GardenDrawing.metres(chosen.originX)) { sheet = .numbers(.fromLeft) }
                        tile("From the top edge", GardenDrawing.metres(chosen.originY)) { sheet = .numbers(.fromTop) }
                    }
                }
                HStack(spacing: 8) {
                    Button("Quarter turn") { quarterTurn(chosen) }
                    if chosen is Bed {
                        Button("Repeat") { sheet = .repeatBed }
                    }
                    Button("Remove") { asksToRemove = true }
                }
                .buttonStyle(QuietGlassButton())
            }
            .glassCard()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("The plot")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Grid(horizontalSpacing: 8) {
                    GridRow {
                        tile("Width", garden.widthMetres.map(GardenDrawing.metres) ?? "Not set") { sheet = .plot }
                        tile("Depth", garden.depthMetres.map(GardenDrawing.metres) ?? "Not set") { sheet = .plot }
                    }
                }
                NavigationLink {
                    NorthRingSetter(garden: garden)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("North")
                                .font(.footnote)
                                .foregroundStyle(Theme.inkSoft)
                            Text(GardenDrawing.facingWords(garden.topFacesDegrees))
                                .foregroundStyle(Theme.ink)
                        }
                        Spacer()
                        WIconView(.chevronRight, size: 14)
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                Text("Tap + to add a bed, a path, a shed or a tree. Drag it into place. Pull the ring at its corner to size it and twist the green knob to turn it. Tap any number to type it from the tape.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
            .glassCard()
        }
    }

    /// One number as a button: its name, then its value.
    private func tile(_ title: String, _ value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                Text(value)
                    .font(.title3)
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.card.opacity(0.7), in: .rect(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.hairline) }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func quarterTurn(_ thing: any PlanPlaceable) {
        let turned = GardenDrawing.quarterTurn(x: thing.originX, y: thing.originY, length: thing.planLength,
                                               width: thing.planWidth, rotation: thing.rotationDegrees)
        withAnimation(.snappy) {
            thing.originX = turned.x
            thing.originY = turned.y
            thing.rotationDegrees = turned.rotation
        }
    }

    /// Marks the chosen thing as no longer there. Nothing is deleted, so
    /// a bed's sowings and history survive.
    private func removeChosen() {
        if let bed = chosen as? Bed {
            bed.retiredAt = .now
        } else if let feature = chosen as? GardenFeature {
            feature.removedAt = .now
        }
        chosenID = nil
    }
}
