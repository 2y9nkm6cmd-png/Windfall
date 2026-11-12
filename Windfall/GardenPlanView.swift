//
//  GardenPlanView.swift
//  Windfall
//
//  A garden drawn to scale from its measurements.
//
//  Nothing here is a picture. Every bed, shed and tree is drawn from the
//  numbers on its record: where it is, how big it is and how far it is
//  turned. Change a number and the plan redraws.
//
//  Two views:
//
//    GardenPlanView   only the drawing
//    GardenPlanCard   the drawing with its title, size and compass
//

import SwiftUI
import SwiftData

// MARK: - The drawing

struct GardenPlanView: View {

    let garden: Garden
    let beds: [Bed]
    let features: [GardenFeature]
    /// Turns the whole plan, in degrees, when it is following the compass.
    var turn: Double = 0

    /// A bed with the place it is drawn at. For a bed that has never been
    /// positioned this is a stand-in place, so beds do not pile up.
    private struct PlacedBed {
        let bed: Bed
        let x: Double
        let y: Double

        var length: Double { bed.lengthMetres ?? Bed.unmeasuredLength }
        var width: Double { bed.widthMetres ?? Bed.unmeasuredWidth }

        var outline: [PlanPoint] {
            PlanGeometry.rectangle(x: x, y: y, length: length, width: width,
                                   rotation: bed.rotationDegrees)
        }

        /// A point inside the bed, measured along and across it.
        func point(along: Double, across: Double) -> PlanPoint {
            PlanGeometry.rectangle(x: x, y: y, length: along, width: across,
                                   rotation: bed.rotationDegrees)[2]
        }
    }

    /// True when two or more beds still sit in the starting corner.
    static func hasUnplacedBeds(_ beds: [Bed]) -> Bool {
        beds.filter { $0.originX == 0 && $0.originY == 0 }.count > 1
    }

    private var placedBeds: [PlacedBed] {
        let unplaced = beds.filter { $0.originX == 0 && $0.originY == 0 }
        guard unplaced.count > 1 else {
            return beds.map { PlacedBed(bed: $0, x: $0.originX, y: $0.originY) }
        }
        // Stack the unplaced beds down the plan, for show only. Nothing
        // is saved: the records keep their real positions.
        let spots = PlanGeometry.stackedPositions(sizes: unplaced.map {
            (length: $0.lengthMetres ?? Bed.unmeasuredLength, width: $0.widthMetres ?? Bed.unmeasuredWidth)
        })
        return beds.map { bed in
            if let index = unplaced.firstIndex(where: { $0.id == bed.id }) {
                return PlacedBed(bed: bed, x: spots[index].x, y: spots[index].y)
            }
            return PlacedBed(bed: bed, x: bed.originX, y: bed.originY)
        }
    }

    private var shownFeatures: [GardenFeature] { features.filter(\.isPresent) }

    /// The smallest box, in metres, that holds everything to be drawn.
    private var bounds: (minX: Double, minY: Double, maxX: Double, maxY: Double) {
        var points: [PlanPoint] = placedBeds.flatMap(\.outline) + shownFeatures.flatMap(\.outline)
        if let width = garden.widthMetres, let depth = garden.depthMetres {
            points += [PlanPoint(x: 0, y: 0), PlanPoint(x: width, y: depth)]
        }
        guard !points.isEmpty else { return (0, 0, 10, 6) }
        let xs = points.map(\.x), ys = points.map(\.y)
        return (xs.min() ?? 0, ys.min() ?? 0, max(xs.max() ?? 1, (xs.min() ?? 0) + 1), max(ys.max() ?? 1, (ys.min() ?? 0) + 1))
    }

    var body: some View {
        let box = bounds
        let hasSize = garden.widthMetres != nil && garden.depthMetres != nil
        // Room round the drawing for the measurement lines, in points.
        let left: CGFloat = hasSize ? 44 : 6
        let bottom: CGFloat = hasSize ? 26 : 6

        Canvas { context, size in
            let metresWide = box.maxX - box.minX
            let metresDeep = box.maxY - box.minY
            // One number turns metres into points on the screen.
            let scale = min((size.width - left - 6) / metresWide, (size.height - bottom - 6) / metresDeep)
            let originX = left + ((size.width - left - 6) - metresWide * scale) / 2
            let originY: CGFloat = 6 + ((size.height - bottom - 6) - metresDeep * scale) / 2

            func place(_ spot: PlanPoint) -> CGPoint {
                CGPoint(x: originX + (spot.x - box.minX) * scale, y: originY + (spot.y - box.minY) * scale)
            }
            func outline(_ points: [PlanPoint]) -> Path {
                var path = Path()
                guard let first = points.first else { return path }
                path.move(to: place(first))
                for spot in points.dropFirst() { path.addLine(to: place(spot)) }
                path.closeSubpath()
                return path
            }
            func middle(of points: [PlanPoint]) -> CGPoint {
                let x = points.map(\.x).reduce(0, +) / Double(max(points.count, 1))
                let y = points.map(\.y).reduce(0, +) / Double(max(points.count, 1))
                return place(PlanPoint(x: x, y: y))
            }
            func label(_ text: String, at point: CGPoint, soft: Bool = false) {
                context.draw(Text(text).font(.caption2).foregroundStyle(soft ? Theme.inkSoft : Theme.ink), at: point)
            }

            // 1. The edge of the plot.
            if let width = garden.widthMetres, let depth = garden.depthMetres {
                let plot = outline(PlanGeometry.rectangle(x: 0, y: 0, length: width, width: depth))
                context.stroke(plot, with: .color(Theme.inkSoft), lineWidth: 1)
            }

            // 2. Sheds, paths, ponds, trees and the rest.
            for feature in shownFeatures {
                let points = feature.outline
                let isOutside = feature.isOutside(garden)
                let shape = feature.kind == .tree
                    ? Self.scallopedOutline(centre: middle(of: points),
                                            radiusX: feature.lengthMetres * scale / 2,
                                            radiusY: feature.widthMetres * scale / 2)
                    : outline(points)
                let paint: Color
                switch feature.kind {
                case .water: paint = Theme.water
                case .tree, .hedge: paint = Theme.leafFill
                case .path: paint = Theme.hairline.opacity(0.6)
                default: paint = Theme.card
                }
                context.fill(shape, with: .color(paint.opacity(isOutside ? 0.45 : 1)))
                // Things beyond the boundary are drawn with a dashed edge.
                context.stroke(shape, with: .color(Theme.inkSoft),
                               style: StrokeStyle(lineWidth: 1, dash: isOutside ? [4, 3] : []))
                if feature.lengthMetres * scale > 40, feature.kind != .path, !feature.name.isEmpty {
                    label(feature.name, at: middle(of: points), soft: true)
                }
            }

            // 3. Beds, with planted sections filled in green.
            for placed in placedBeds {
                let bedShape = outline(placed.outline)
                context.fill(bedShape, with: .color(Theme.card))

                let sections = placed.bed.orderedSections
                let total = sections.map(\.lengthMetres).reduce(0, +)
                var start = 0.0
                for section in sections where total > 0 {
                    // Sections share out the bed's length in proportion.
                    let share = section.lengthMetres / total * placed.length
                    let corners = [placed.point(along: start, across: 0), placed.point(along: start + share, across: 0),
                                   placed.point(along: start + share, across: placed.width), placed.point(along: start, across: placed.width)]
                    let isPlanted = (section.plantings ?? []).contains { $0.status != .finished && $0.status != .failed }
                    if isPlanted {
                        context.fill(outline(corners), with: .color(Theme.leafFill))
                        if share * scale > 14 { label(section.label, at: middle(of: corners)) }
                    }
                    if start > 0 {
                        var divider = Path()
                        divider.move(to: place(corners[0]))
                        divider.addLine(to: place(corners[3]))
                        context.stroke(divider, with: .color(Theme.hairline), lineWidth: 0.8)
                    }
                    start += share
                }

                context.stroke(bedShape, with: .color(Theme.ink.opacity(0.8)), lineWidth: 1)
                let hasPlanting = sections.contains { ($0.plantings ?? []).contains { $0.status != .finished && $0.status != .failed } }
                if !hasPlanting, placed.length * scale > 36 {
                    label(placed.bed.name, at: middle(of: placed.outline))
                }
            }

            // 4. Measurement lines along the bottom and down the left.
            if let width = garden.widthMetres, let depth = garden.depthMetres {
                let bottomLeft = place(PlanPoint(x: 0, y: depth))
                let bottomRight = place(PlanPoint(x: width, y: depth))
                let topLeft = place(PlanPoint(x: 0, y: 0))
                Self.measure(in: &context, from: CGPoint(x: bottomLeft.x, y: bottomLeft.y + 14),
                             to: CGPoint(x: bottomRight.x, y: bottomRight.y + 14),
                             text: Self.metres(width))
                Self.measure(in: &context, from: CGPoint(x: topLeft.x - 22, y: topLeft.y),
                             to: CGPoint(x: bottomLeft.x - 22, y: bottomLeft.y),
                             text: Self.metres(depth))
            }
        }
        // Gives the drawing the same proportions as the garden, so a
        // long thin plot gets a long thin space and no empty bands.
        .aspectRatio(CGFloat((box.maxX - box.minX) * 12) / CGFloat((box.maxY - box.minY) * 12 + 20), contentMode: .fit)
        .rotationEffect(.degrees(turn))
        .animation(.spring(duration: 0.5, bounce: 0.15), value: turn)
        .accessibilityElement()
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var parts = ["Plan of \(garden.name)"]
        if let width = garden.widthMetres, let depth = garden.depthMetres {
            parts.append("\(Self.metres(width)) by \(Self.metres(depth))")
        }
        parts.append("\(beds.count) beds")
        if !shownFeatures.isEmpty { parts.append(shownFeatures.map(\.name).filter { !$0.isEmpty }.joined(separator: ", ")) }
        return parts.joined(separator: ". ")
    }

    // MARK: Drawing helpers

    static func metres(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1))) + " m"
    }

    /// A line with an arrowhead at each end and its length written in the
    /// middle, like a dimension on a building plan.
    private static func measure(in context: inout GraphicsContext, from: CGPoint, to: CGPoint, text: String) {
        var line = Path()
        line.move(to: from)
        line.addLine(to: to)
        let dx = to.x - from.x, dy = to.y - from.y
        let length = max(sqrt(dx * dx + dy * dy), 1)
        let ux = dx / length, uy = dy / length
        // Two short strokes make each arrowhead.
        for (tip, sign) in [(from, 1.0), (to, -1.0)] {
            for side in [-1.0, 1.0] {
                line.move(to: tip)
                line.addLine(to: CGPoint(x: tip.x + (ux * 5 * sign) - uy * 3 * side,
                                         y: tip.y + (uy * 5 * sign) + ux * 3 * side))
            }
        }
        context.stroke(line, with: .color(Theme.inkSoft), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))

        // The number sits on a patch of paper so the line does not run
        // through it.
        let centre = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
        let resolved = context.resolve(Text(text).font(.caption2).foregroundStyle(Theme.inkSoft))
        let textSize = resolved.measure(in: CGSize(width: 200, height: 40))
        let patch = CGRect(x: centre.x - textSize.width / 2 - 3, y: centre.y - textSize.height / 2,
                           width: textSize.width + 6, height: textSize.height)
        context.fill(Path(patch), with: .color(Theme.card))
        context.draw(resolved, at: centre)
    }

    /// A tree seen from above: a circle with a wavy edge.
    private static func scallopedOutline(centre: CGPoint, radiusX: CGFloat, radiusY: CGFloat) -> Path {
        var path = Path()
        let steps = 96
        for step in 0...steps {
            let angle = Double(step) / Double(steps) * 2 * .pi
            // abs(sin) makes a row of bumps round the edge.
            let wobble = 0.86 + 0.14 * abs(sin(angle * 4.5))
            let point = CGPoint(x: centre.x + cos(angle) * radiusX * wobble,
                                y: centre.y + sin(angle) * radiusY * wobble)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - The card

/// A garden's plan with its name, its size and a compass.
///
/// On an iPhone or iPad, tapping the compass makes the plan follow the
/// device: it turns as you turn, so it lines up with the garden in front
/// of you. Tapping again sets it upright.
struct GardenPlanCard: View {

    let garden: Garden
    let beds: [Bed]
    let features: [GardenFeature]

    @State private var compass = CompassHeading()
    @State private var followsCompass = false

    /// Where north lies on the screen, clockwise from straight up.
    private var north: Double {
        if followsCompass, let heading = compass.degrees {
            // Holding the device flat and facing a bearing, north is that
            // many degrees round to the left.
            return -heading
        }
        // The top of the plan faces a bearing, so north is that far
        // round to the left of straight up.
        return -garden.topFacesDegrees
    }

    /// How far to turn the plan so it matches the ground.
    private var turn: Double {
        guard followsCompass, let heading = compass.degrees else { return 0 }
        return garden.topFacesDegrees - heading
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(garden.name)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text(sizeLine)
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                compassButton
            }

            GardenPlanView(garden: garden, beds: beds, features: features, turn: turn)
                .frame(maxWidth: .infinity, maxHeight: 320)

            HStack {
                if GardenPlanView.hasUnplacedBeds(beds) {
                    Text("Beds not placed yet")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                NavigationLink {
                    GardenEditorView(garden: garden)
                } label: {
                    HStack(spacing: 4) {
                        Text(garden.widthMetres == nil ? "Draw this garden" : "Edit layout")
                        WIconView(.arrowRight, size: 14)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.leaf)
                }
                .buttonStyle(.plain)
            }
        }
        .glassCard()
        .onDisappear {
            if followsCompass { compass.stop() }
        }
    }

    private var sizeLine: String {
        if let width = garden.widthMetres, let depth = garden.depthMetres {
            return "\(width.formatted(.number.precision(.fractionLength(1)))) × \(GardenPlanView.metres(depth))"
        }
        return "Not measured yet"
    }

    @ViewBuilder
    private var compassButton: some View {
        if compass.isAvailable {
            Button {
                followsCompass.toggle()
                if followsCompass { compass.start() } else { compass.stop() }
            } label: {
                CompassRose(north: north, isLive: followsCompass)
            }
            .buttonStyle(.plain)
            .accessibilityHint(followsCompass ? "Stops the plan turning" : "Turns the plan to match the way you are facing")
        } else {
            CompassRose(north: north)
        }
    }
}
