//
//  LocationManager.swift
//  Windfall
//
//  A thin wrapper around CoreLocation.
//
//  CoreLocation is an old API with a delegate pattern from long before
//  Swift concurrency, so this class does the awkward bridging once and
//  presents something a SwiftUI view can just read.
//
//  Design choices worth knowing:
//
//  - "When in use" authorisation only. The app has no reason to know
//    where you are when it isn't open.
//  - One-shot requests rather than continuous tracking. Recording a
//    survey needs a position once; leaving GPS running flattens a
//    battery you may need later in the field.
//  - Accuracy is reported, not hidden. A fix good to 65 m is not good
//    enough for a 10 m grid reference, and the app should say so rather
//    than quietly writing something wrong.
//

import Foundation
import CoreLocation
import Observation

@Observable
@MainActor
final class LocationManager: NSObject {

    // MARK: Published state

    /// The most recent fix, if there is one.
    private(set) var location: CLLocation?

    /// Horizontal accuracy in metres. Lower is better.
    var accuracyMetres: Double? {
        guard let location, location.horizontalAccuracy >= 0 else { return nil }
        return location.horizontalAccuracy
    }

    private(set) var authorisationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var isRequesting = false
    private(set) var errorMessage: String?

    // MARK: Private

    private let manager = CLLocationManager()
    private var continuations: [CheckedContinuation<CLLocation?, Never>] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        authorisationStatus = manager.authorizationStatus
    }

    // MARK: Permission

    var isAuthorised: Bool {
        #if os(macOS)
        authorisationStatus == .authorizedAlways
        #else
        authorisationStatus == .authorizedWhenInUse || authorisationStatus == .authorizedAlways
        #endif
    }

    func requestPermission() {
        #if os(macOS)
        manager.requestWhenInUseAuthorization()
        #else
        manager.requestWhenInUseAuthorization()
        #endif
    }

    // MARK: Getting a fix

    /// Asks for a single position and waits for it.
    ///
    /// Returns nil if permission is refused or nothing arrives. The caller
    /// decides what to do about that — this doesn't throw, because "no
    /// signal in a hedge" is an ordinary situation rather than an error.
    @discardableResult
    func currentLocation() async -> CLLocation? {
        guard isAuthorised else {
            requestPermission()
            return nil
        }

        isRequesting = true
        errorMessage = nil

        let fix = await withCheckedContinuation { (continuation: CheckedContinuation<CLLocation?, Never>) in
            continuations.append(continuation)
            manager.requestLocation()
        }

        isRequesting = false
        return fix
    }

    /// Convenience: a grid reference at the precision you want, or nil.
    func gridReference(precisionMetres: Int = 100) async -> String? {
        guard let location = await currentLocation() else { return nil }
        return OSGridReference.from(location.coordinate, precisionMetres: precisionMetres)
    }

    /// Whether a fix is good enough for the precision being asked for.
    /// A 65 m fix cannot honestly produce a 10 m grid reference.
    func fixIsGoodEnough(for precisionMetres: Int) -> Bool {
        guard let accuracy = accuracyMetres else { return false }
        return accuracy <= Double(precisionMetres)
    }

    private func resume(with location: CLLocation?) {
        let waiting = continuations
        continuations.removeAll()
        for continuation in waiting {
            continuation.resume(returning: location)
        }
    }
}

// MARK: - CoreLocation delegate

extension LocationManager: CLLocationManagerDelegate {

    // nonisolated because CoreLocation calls these from its own context;
    // each hops back to the main actor before touching state.

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        let newest = locations.last
        Task { @MainActor in
            if let newest { self.location = newest }
            self.resume(with: newest)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
            self.resume(with: nil)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorisationStatus = status
            if status == .denied || status == .restricted {
                self.errorMessage = "Location access is turned off for Windfall."
                self.resume(with: nil)
            }
        }
    }
}

// MARK: - A reusable capture control

import SwiftUI

/// Drop-in row that fetches a grid reference and writes it into a binding.
/// Used by surveys, observations and diary entries.
struct GridReferenceField: View {

    @Binding var gridReference: String?
    @Binding var latitude: Double?
    @Binding var longitude: Double?

    var precisionMetres: Int = 100

    @Environment(LocationManager.self) private var locationManager
    @State private var warning: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Grid reference", text: Binding(
                    get: { gridReference ?? "" },
                    set: { gridReference = $0.isEmpty ? nil : $0 }
                ))

                Button {
                    Task { await capture() }
                } label: {
                    if locationManager.isRequesting {
                        ProgressView()
                    } else {
                        Image(systemName: "location.fill")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(locationManager.isRequesting)
            }

            if let accuracy = locationManager.accuracyMetres, gridReference != nil {
                Text("Fix accurate to about \(Int(accuracy)) m")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let warning {
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func capture() async {
        warning = nil

        guard locationManager.isAuthorised else {
            locationManager.requestPermission()
            warning = "Allow location access to capture a grid reference."
            return
        }

        guard let location = await locationManager.currentLocation() else {
            warning = locationManager.errorMessage ?? "No fix — try again with a clearer view of the sky."
            return
        }

        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        gridReference = OSGridReference.from(location.coordinate,
                                             precisionMetres: precisionMetres)

        if !locationManager.fixIsGoodEnough(for: precisionMetres) {
            let accuracy = Int(locationManager.accuracyMetres ?? 0)
            warning = "Fix is only accurate to \(accuracy) m, which is coarser than the \(precisionMetres) m precision you've asked for."
        }
    }
}
