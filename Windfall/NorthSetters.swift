//
//  NorthSetters.swift
//  Windfall
//
//  Three ways to say which way a garden faces.
//
//  The records keep one number for this: `topFacesDegrees`, the compass
//  bearing the top edge of the plan faces. The older editor asked for
//  that number more or less directly ("Top of the plan faces 0°"), which
//  means working out a bearing in your head.
//
//  Here the plan stays exactly as it was drawn and you show where north
//  is. The same number is stored, so nothing in the records changes.
//
//    NorthRingSetter   drag an N round a ring. Works on every device
//    NorthByPointing   stand at the bottom edge and point the device
//                      across the garden. iPhone and iPad only
//    NorthByMap        turn the plot's outline over a satellite picture.
//                      Works on a Mac. Asks Apple Maps for the picture
//
//  The sums are in GardenDrawing.swift.
//

import SwiftUI
import SwiftData
import MapKit

// MARK: - The ring

/// The plan, as drawn, inside a ring with an N that can be dragged round.
///
/// It is a piece, not a page, so the step-by-step screens can use it too.
struct NorthRing: View {

    @Bindable var garden: Garden
    let beds: [Bed]
    let features: [GardenFeature]
    /// The bearing the top faces while a finger is on the ring, or nil
    /// when it is not. The page owns this, so the words under the ring
    /// can follow the finger too. The garden itself is only changed when
    /// the finger lifts: saving on every tiny move made every screen that
    /// reads the records redraw 60 times a second, and the iPad froze
    /// (15 November 2026).
    @Binding var liveTop: Double?
    var size: CGFloat = 280

    /// Room round the ring for the N to sit half outside it.
    private let rim: CGFloat = 24

    var body: some View {
        // Where north is drawn, in degrees clockwise from straight up.
        let north = GardenDrawing.northAngle(whenTopFaces: liveTop ?? garden.topFacesDegrees)
        ZStack {
            Circle()
                .strokeBorder(Theme.inkSoft.opacity(0.55), lineWidth: 1.5)

            // East, south and west, a quarter turn apart from north.
            ForEach(1..<4, id: \.self) { quarter in
                let turn = north + Double(quarter) * 90
                Text(["E", "S", "W"][quarter - 1])
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                    // Turned back first so the letter stays upright, moved
                    // out to the ring, then swung round to its place.
                    .rotationEffect(.degrees(-turn))
                    .offset(y: -(size / 2 - 16))
                    .rotationEffect(.degrees(turn))
            }

            // The plan, the way it was drawn. It does not turn.
            GardenPlanView(garden: garden, beds: beds, features: features)
                .frame(width: size * 0.62, height: size * 0.62)
                .allowsHitTesting(false)

            Text("N")
                .font(.body.weight(.bold))
                .foregroundStyle(Theme.onLeaf)
                .frame(width: 44, height: 44)
                .background(Theme.leaf, in: .circle)
                .rotationEffect(.degrees(-north))
                .offset(y: -size / 2)
                .rotationEffect(.degrees(north))
        }
        .frame(width: size, height: size)
        .padding(rim)
        .contentShape(.rect)
        // A drag that starts at once (distance 0) also catches a plain
        // tap, so tapping the ring where north is works too.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let middle = size / 2 + rim
                    let dx = Double(value.location.x - middle), dy = Double(value.location.y - middle)
                    // Touches on the plan in the middle are ignored.
                    guard hypot(dx, dy) > Double(size) * 0.32 else { return }
                    var angle = GardenDrawing.angle(dx: dx, dy: dy).rounded()
                    // Settle on one of the eight compass points when close.
                    let point = (angle / 45).rounded() * 45
                    if abs(angle - point) <= 3 { angle = point }
                    // Only the ring moves while the finger is down, and
                    // only when the whole degree has actually changed.
                    let top = GardenDrawing.topFaces(whenNorthIsAt: angle)
                    if top != liveTop { liveTop = top }
                }
                .onEnded { _ in
                    // The finger has lifted: save it to the garden, once.
                    if let top = liveTop, top != garden.topFacesDegrees {
                        garden.topFacesDegrees = top
                    }
                    liveTop = nil
                }
        )
        .accessibilityElement()
        .accessibilityLabel("North. \(GardenDrawing.facingWords(garden.topFacesDegrees))")
        .accessibilityAdjustableAction { direction in
            let step: Double = direction == .increment ? -5 : 5
            garden.topFacesDegrees = Compass.normalised(garden.topFacesDegrees + step)
        }
    }
}

/// "The top of your plan faces north-east", with the degrees beneath.
struct NorthWords: View {

    let garden: Garden
    /// The ring's bearing while it is being dragged, so the words follow
    /// the finger before anything is saved.
    var liveTop: Double? = nil

    var body: some View {
        let top = liveTop ?? garden.topFacesDegrees
        VStack(spacing: 2) {
            Text(GardenDrawing.facingWords(top))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text("\(Int(top.rounded()))° · the plan stays as you drew it")
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }
}

/// The page for the ring.
struct NorthRingSetter: View {

    @Bindable var garden: Garden

    @Query(filter: #Predicate<Bed> { $0.retiredAt == nil }) private var allBeds: [Bed]
    @Query private var allFeatures: [GardenFeature]

    private var beds: [Bed] { allBeds.filter { $0.siteRaw == garden.siteKey } }
    private var features: [GardenFeature] { allFeatures.filter { $0.siteRaw == garden.siteKey && $0.isPresent } }

    /// Where the ring is while a finger is on it. See `NorthRing`.
    @State private var liveTop: Double?

    var body: some View {
        // No ScrollView here on purpose: a page that scrolls would fight
        // the finger for the drag round the ring.
        VStack(alignment: .leading, spacing: 12) {
            ScreenHeader(title: "Which way is north?", detail: garden.name)
            VStack(spacing: 10) {
                NorthRing(garden: garden, beds: beds, features: features, liveTop: $liveTop)
                NorthWords(garden: garden, liveTop: liveTop)
                HStack(spacing: 14) {
                    nudge("arrow.counterclockwise", by: 1, says: "Move north one degree anticlockwise")
                    Text("1° at a time")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                    nudge("arrow.clockwise", by: -1, says: "Move north one degree clockwise")
                }
            }
            .frame(maxWidth: .infinity)
            .glassCard()
            Text("Drag N round the ring, or tap the ring where north is. It is saved as you go.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .paperScreen()
        .navigationTitle("North")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// Moving north clockwise round the ring makes the bearing the top
    /// faces go DOWN, which is why the clockwise button takes one away.
    private func nudge(_ symbol: String, by amount: Double, says words: String) -> some View {
        Button {
            garden.topFacesDegrees = Compass.normalised((garden.topFacesDegrees + amount).rounded())
        } label: {
            Image(systemName: symbol)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(QuietGlassButton())
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(words)
    }
}

// MARK: - Stand and point

/// Sets north from the device's own compass, with a picture of where to
/// stand and which way to point.
struct NorthByPointing: View {

    @Bindable var garden: Garden

    @Query(filter: #Predicate<Bed> { $0.retiredAt == nil }) private var allBeds: [Bed]
    @Query private var allFeatures: [GardenFeature]

    @State private var compass = CompassHeading()
    @State private var wasSet = false

    private var beds: [Bed] { allBeds.filter { $0.siteRaw == garden.siteKey } }
    private var features: [GardenFeature] { allFeatures.filter { $0.siteRaw == garden.siteKey && $0.isPresent } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ScreenHeader(title: "Stand and point", detail: garden.name)
                picture
                reading
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .paperScreen()
        .navigationTitle("North")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { compass.start() }
        .onDisappear { compass.stop() }
    }

    /// The plan with "you" at the middle of its bottom edge and an arrow
    /// pointing up across it.
    private var picture: some View {
        VStack(spacing: 6) {
            Text("top of the plan")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.leaf)
            GardenPlanView(garden: garden, beds: beds, features: features)
                .frame(maxHeight: 170)
            Image(systemName: "arrow.up")
                .font(.title.weight(.semibold))
                .foregroundStyle(Theme.leaf)
            Text("You")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.onLeaf)
                .frame(width: 48, height: 48)
                .background(Theme.leaf, in: .circle)
            Text("at the middle of the bottom edge")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .glassCard()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var reading: some View {
        if !compass.isAvailable {
            Text("This device has no compass. A Mac does not have one. Use the ring or the map.")
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
        } else if let heading = compass.degrees {
            VStack(spacing: 10) {
                Text("You are facing \(Compass.name(forBearing: heading)), \(Int(heading.rounded()))°")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Text("Hold the device flat and point it straight across the garden, to the middle of the far edge.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                Button {
                    // Pointing from the bottom edge to the top edge, the
                    // way you face IS the way the top of the plan faces.
                    garden.topFacesDegrees = heading.rounded()
                    wasSet = true
                } label: {
                    Text("Set north from here")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .leafButton()
                .controlSize(.large)
                if wasSet {
                    Text("Saved. \(GardenDrawing.facingWords(garden.topFacesDegrees)).")
                        .font(.footnote)
                        .foregroundStyle(Theme.leaf)
                }
            }
            .frame(maxWidth: .infinity)
            .glassCard()
        } else {
            Text("Waiting for the compass. Move the device in a figure of eight if it does not settle.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
        }
    }
}

// MARK: - On the map

/// Sets north by turning the plot's outline over a satellite picture.
///
/// The outline is drawn by the map itself, at the plot's real size, so
/// it also shows at a glance whether the width and depth are right.
struct NorthByMap: View {

    @Bindable var garden: Garden

    @Environment(LocationManager.self) private var locationManager
    @Environment(\.dismiss) private var dismiss

    /// Where the map is looking.
    @State private var camera: MapCameraPosition = .automatic
    /// Where the middle of the outline is. Nil until the garden's place
    /// is known.
    @State private var outlineMiddle: CLLocationCoordinate2D?
    /// The middle of what the map shows, kept so the outline can be
    /// brought to it.
    @State private var mapMiddle: CLLocationCoordinate2D?
    /// The bearing the outline's top edge faces.
    @State private var turn = 0.0
    /// True while the sheet for giving the garden its place is up.
    @State private var isPlacing = false

    private var width: Double { garden.widthMetres ?? 10 }
    private var depth: Double { garden.depthMetres ?? 10 }

    /// The outline's four corners on the map.
    private func corners(round middle: CLLocationCoordinate2D) -> [CLLocationCoordinate2D] {
        GardenDrawing.plotCorners(latitude: middle.latitude, longitude: middle.longitude,
                                  width: width, depth: depth, topFaces: turn)
            .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ScreenHeader(title: "Line it up with the map", detail: garden.name)
                if let outlineMiddle {
                    map(round: outlineMiddle)
                    controls
                } else {
                    noPlace
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .paperScreen()
        .navigationTitle("North")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            turn = garden.topFacesDegrees
            if let latitude = garden.latitude, let longitude = garden.longitude {
                look(at: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
            }
        }
        // When the sheet below gives the garden a place, show the map
        // there at once. `onChange` runs its code whenever the value it
        // watches changes.
        .onChange(of: garden.latitude) {
            if outlineMiddle == nil, let latitude = garden.latitude, let longitude = garden.longitude {
                look(at: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
            }
        }
        .sheet(isPresented: $isPlacing) {
            GardenPlaceSheet(garden: garden)
        }
    }

    /// Puts the outline at a place and points the map at it, close in.
    private func look(at place: CLLocationCoordinate2D) {
        outlineMiddle = place
        let span = max(width, depth) * 4
        camera = .region(MKCoordinateRegion(center: place, latitudinalMeters: span, longitudinalMeters: span))
    }

    private func map(round middle: CLLocationCoordinate2D) -> some View {
        let outline = corners(round: middle)
        return Map(position: $camera) {
            MapPolygon(coordinates: outline)
                .foregroundStyle(Theme.leafFill.opacity(0.3))
                .stroke(Theme.leaf, lineWidth: 3)
            // A label on the middle of the top edge, so it can be told
            // from the other three.
            Annotation("", coordinate: CLLocationCoordinate2D(
                latitude: (outline[0].latitude + outline[1].latitude) / 2,
                longitude: (outline[0].longitude + outline[1].longitude) / 2)) {
                Text("top")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.leaf)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.white, in: .capsule)
            }
        }
        .mapStyle(.imagery)
        .onMapCameraChange(frequency: .continuous) { context in
            mapMiddle = context.region.center
        }
        .frame(height: 360)
        .clipShape(.rect(cornerRadius: 18))
        .accessibilityLabel("Satellite picture with the outline of the plot")
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Text(GardenDrawing.facingWords(turn))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("The edge marked \"top\" is the top of your plan. Turn the outline until it sits over your plot.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                turnButton("arrow.counterclockwise", by: -1, says: "Turn the outline one degree anticlockwise")
                Slider(value: $turn, in: 0...359, step: 1)
                    .tint(Theme.leaf)
                    .accessibilityLabel("Turn the outline")
                turnButton("arrow.clockwise", by: 1, says: "Turn the outline one degree clockwise")
            }
            Button("Bring the outline here") {
                if let mapMiddle { outlineMiddle = mapMiddle }
            }
            .buttonStyle(QuietGlassButton())
            Button {
                garden.topFacesDegrees = Compass.normalised(turn.rounded())
                dismiss()
            } label: {
                Text("Set north")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .leafButton()
            .controlSize(.large)
            Text("The picture comes from Apple Maps. Apple is sent the place the map is looking at.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private func turnButton(_ symbol: String, by amount: Double, says words: String) -> some View {
        Button {
            turn = Compass.normalised(turn + amount).rounded()
            if turn >= 360 { turn = 0 }
        } label: {
            Image(systemName: symbol)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(QuietGlassButton())
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(words)
    }

    /// Shown when the garden has no latitude and longitude yet.
    ///
    /// Until 15 November 2026 this had its own "Use where I am now"
    /// button, which did nothing and said nothing when the device would
    /// not give its position, and otherwise sent the reader off to type
    /// latitude and longitude. It now opens the one sheet that every
    /// page uses to place a garden (GardenPlaceSheet.swift).
    private var noPlace: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The map needs to know where this garden is.")
                .foregroundStyle(Theme.ink)
            Text("Type its town or postcode, or stand in the garden and use where you are.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
            Button("Set where it is") {
                isPlacing = true
            }
            .buttonStyle(QuietGlassButton())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}
