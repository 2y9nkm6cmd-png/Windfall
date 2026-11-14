//
//  CameraPhoto.swift
//  Windfall
//
//  Taking a photo with the camera, on an iPhone or iPad.
//
//  Until now a photo could reach Windfall three ways: chosen from the
//  Photos library, chosen as a file, or dragged in. This adds a fourth:
//  open the camera, take the picture and hand it straight over.
//
//  The camera screen is Apple's own, the same one other apps show. It is
//  an older, UIKit screen (`UIImagePickerController`), and Windfall's
//  screens are SwiftUI, so most of this file is the bridge between the
//  two.
//
//  A Mac has no such screen. Everything that touches it is fenced in
//  `#if os(iOS)`, which means "only build this for an iPhone or iPad".
//  On a Mac `CameraPhoto.isAvailable` is false, so the "Take a photo"
//  choice is never drawn, and `.cameraPhoto` does nothing.
//
//  New things here:
//
//  UIViewControllerRepresentable
//                    SwiftUI's wrapper for a UIKit screen. It asks two
//                    things: how to make the screen, and how to bring it
//                    up to date. The second is empty here.
//
//  Coordinator       UIKit screens report back by calling a "delegate":
//                    an object that promises to have certain functions.
//                    SwiftUI views are not objects that can do that, so
//                    the wrapper makes a small helper that can.
//
//  ViewModifier      A reusable piece of ".something(...)" that can be
//                    added to any view. This one adds the camera.
//
//  How to use it, from any screen:
//
//      @State private var isTakingPhoto = false
//      ...
//      if CameraPhoto.isAvailable {
//          Button { isTakingPhoto = true } label: {
//              Label("Take a photo", systemImage: "camera")
//          }
//      }
//      ...
//      .cameraPhoto(isPresented: $isTakingPhoto) { data in
//          // `data` is the photo as a JPEG file's bytes.
//      }
//
//  The app must also say why it wants the camera, or iOS closes it the
//  moment the camera is asked for. That sentence is in Info.plist, under
//  NSCameraUsageDescription. iOS shows it the first time, with Allow and
//  Don't Allow.
//
//  Two more things happen to a photo taken here (William, 14 November
//  2026):
//
//  Where it was taken   Apple's camera screen does not say where the
//                    phone was. So while the camera is open Windfall
//                    asks the phone for its position, once, and writes
//                    it into the photo's file the way a camera would.
//                    If location is switched off for Windfall, or no
//                    position arrives in time, the photo is kept
//                    without one.
//
//  A copy in Photos   The photo is also added to the Photos library,
//                    unless "Save camera photos to Photos" is switched
//                    off in Settings. See `CameraRoll` below.
//

import SwiftUI

import CoreLocation

#if os(iOS)
import UIKit
import ImageIO
import UniformTypeIdentifiers
import Photos
#endif

enum CameraPhoto {

    /// True if this device has a camera Windfall can open. False on a
    /// Mac, and in the simulator, which has no camera.
    static var isAvailable: Bool {
        #if os(iOS)
        return UIImagePickerController.isSourceTypeAvailable(.camera)
        #else
        return false
        #endif
    }
}

/// Adding a camera photo to the Photos library.
enum CameraRoll {

    /// The name the on-or-off choice is stored under. Settings and this
    /// file both use it, so it is written once, here.
    static let settingKey = "cameraSavesToPhotos"

    /// True unless it has been switched off in Settings. A choice that
    /// has never been made reads as nothing at all, and `?? true` means
    /// "in that case, on".
    static var isOn: Bool {
        UserDefaults.standard.object(forKey: settingKey) as? Bool ?? true
    }

    #if os(iOS)
    /// Adds the photo to the Photos library, exactly as the file is, so
    /// its date and position go with it. Answers true if it was added.
    ///
    /// The first time, iOS asks whether Windfall may add to Photos.
    /// `.addOnly` asks for the least: leave to put photos in, and none
    /// to look at what is already there.
    @discardableResult
    static func save(_ photo: Data) async -> Bool {
        let answer = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard answer == .authorized || answer == .limited else { return false }
        do {
            // Every change to the Photos library is made inside a
            // "performChanges" block, which Photos runs when it is
            // ready. `@Sendable` says the block is safe to run away
            // from the main thread, which is where Photos runs it.
            try await PHPhotoLibrary.shared().performChanges { @Sendable in
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: photo, options: nil)
            }
            return true
        } catch {
            return false
        }
    }
    #endif
}

extension View {

    /// Adds the camera to a screen. When `isPresented` becomes true the
    /// camera covers the whole screen. If a photo is taken and "Use
    /// Photo" is pressed, `onTaken` is given the photo. If the camera is
    /// cancelled, nothing is called.
    ///
    /// - `isPresented`: a `Binding`, written with a `$`. That is a
    ///   two-way link to a true-or-false value the screen owns: the
    ///   screen sets it true to open the camera, and the camera sets it
    ///   false again when it closes.
    /// - `onTaken`: what to do with the photo. `Data` is the bytes of a
    ///   JPEG file, the same as every other way in gives.
    func cameraPhoto(isPresented: Binding<Bool>, onTaken: @escaping (Data) -> Void) -> some View {
        modifier(CameraPhotoModifier(isPresented: isPresented, onTaken: onTaken))
    }
}

private struct CameraPhotoModifier: ViewModifier {

    @Binding var isPresented: Bool
    let onTaken: (Data) -> Void

    #if os(iOS)
    /// The app's one location helper, shared by every screen. The
    /// question mark means "if there is one": a screen shown without it
    /// still works, and its photos simply have no position.
    @Environment(LocationManager.self) private var locationManager: LocationManager?
    /// What the camera handed over, held for the moment between "Use
    /// Photo" and the camera having slid away.
    @State private var shot: CameraShot?
    /// Where the phone is, once it has answered.
    @State private var place: CLLocation?
    /// True once the phone has answered, with a position or without.
    @State private var placeIsIn = false
    #endif

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            // A "full screen cover" is a sheet that covers everything.
            // Apple's camera screen has to be shown that way.
            //
            // `onDismiss` runs once the camera has gone. The photo is
            // handed over then and not sooner, because what receives it
            // usually opens a sheet of its own, and iOS will not open
            // one sheet while another is still closing.
            .fullScreenCover(isPresented: $isPresented, onDismiss: handOver) {
                CameraScreen(onTaken: { shot = $0 }, close: { isPresented = false })
                    // Let the camera run under the clock and the home
                    // bar, as it does in Apple's own Camera app.
                    .ignoresSafeArea()
                    // `.task` runs when the camera appears. Finding a
                    // position takes a few seconds, so it is started
                    // now, while the photo is being framed.
                    .task { await findPlace() }
            }
        #else
        content
        #endif
    }

    #if os(iOS)
    /// Asks the phone where it is, once.
    private func findPlace() async {
        place = nil
        placeIsIn = false
        let found = await locationManager?.currentLocation()
        // A position with an accuracy below zero is the phone's way of
        // saying it does not really know.
        if let found, found.horizontalAccuracy >= 0 { place = found }
        placeIsIn = true
    }

    /// The camera has closed. If a photo was taken, make its file, hand
    /// it on and add it to Photos.
    private func handOver() {
        guard let taken = shot else { return }
        shot = nil
        Task {
            // If the phone has not yet said where it is, give it up to
            // two seconds more, looking every fifth of a second.
            var waited = 0.0
            while !placeIsIn && waited < 2 {
                try? await Task.sleep(for: .milliseconds(200))
                waited += 0.2
            }
            guard let photo = CameraFile.jpeg(from: taken.picture, notes: taken.notes, place: place) else { return }
            onTaken(photo)
            if CameraRoll.isOn { await CameraRoll.save(photo) }
        }
    }
    #endif
}

#if os(iOS)

/// What the camera hands over: the picture, and apart from it the notes
/// the camera made, such as when it was taken.
private struct CameraShot {
    let picture: UIImage
    let notes: [String: Any]?
}

/// Apple's camera screen, wrapped for SwiftUI.
private struct CameraScreen: UIViewControllerRepresentable {

    /// Called with the photo when "Use Photo" is pressed.
    let onTaken: (CameraShot) -> Void
    /// Called to take the camera off the screen, photo or no photo.
    let close: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let camera = UIImagePickerController()
        camera.sourceType = .camera
        // The helper below is told when a photo is taken or the camera
        // is cancelled.
        camera.delegate = context.coordinator
        return camera
    }

    /// Nothing about the camera changes once it is open.
    func updateUIViewController(_ camera: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onTaken: onTaken, close: close)
    }

    /// The helper UIKit reports to. `NSObject` and the two delegate
    /// names are what UIKit requires of it.
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

        let onTaken: (CameraShot) -> Void
        let close: () -> Void

        init(onTaken: @escaping (CameraShot) -> Void, close: @escaping () -> Void) {
            self.onTaken = onTaken
            self.close = close
        }

        /// "Use Photo" was pressed. `info` is a bag of named things: the
        /// picture, and the notes the camera made about it.
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let picture = info[.originalImage] as? UIImage {
                onTaken(CameraShot(picture: picture, notes: info[.mediaMetadata] as? [String: Any]))
            }
            close()
        }

        /// "Cancel" was pressed.
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            close()
        }
    }
}

/// Turns what the camera hands over into a photo file.
///
/// The camera gives a picture in memory and, apart from it, its notes:
/// when it was taken, the lens and so on. The rest of Windfall expects a
/// file's bytes with the notes inside, because that is where
/// PhotoFacts.swift reads a photo's date from. So the two are put back
/// together here, as a JPEG, with the phone's position added if it is
/// known.
private enum CameraFile {

    static func jpeg(from picture: UIImage, notes: [String: Any]?, place: CLLocation?) -> Data? {
        // The plain way, with no notes. Used if anything below fails.
        let plain = picture.jpegData(compressionQuality: 0.9)

        // ImageIO is Apple's library for reading and writing picture
        // files. A "destination" is a file being written, here into
        // memory (`file`) and not on to the disk.
        let file = NSMutableData()
        guard let pixels = picture.cgImage,
              let destination = CGImageDestinationCreateWithData(
                file, UTType.jpeg.identifier as CFString, 1, nil) else {
            return plain
        }

        // The camera's notes about the moment: EXIF is the name of the
        // standard for them. If it left out when the photo was taken,
        // write in now, in the form EXIF uses.
        var exif = notes?[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        if exif[kCGImagePropertyExifDateTimeOriginal as String] == nil {
            exif[kCGImagePropertyExifDateTimeOriginal as String] = stamp(.now)
        }

        var properties: [String: Any] = [
            // Which way up the phone was held. The pixels are always
            // stored the same way round and this note says how to turn
            // them. Without it a portrait photo would lie on its side.
            kCGImagePropertyOrientation as String: turn(picture.imageOrientation),
            kCGImagePropertyExifDictionary as String: exif,
            // How hard to squeeze the file. 1 is largest and best.
            kCGImageDestinationLossyCompressionQuality as String: 0.9
        ]
        if let place {
            properties[kCGImagePropertyGPSDictionary as String] = gps(place)
        }
        CGImageDestinationAddImage(destination, pixels, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return plain }
        return file as Data
    }

    /// A position as a camera writes one. Each of latitude and
    /// longitude is how far, always above zero, with a letter for which
    /// way (PhotoFacts.written). PhotoFacts.swift reads the same notes
    /// back.
    private static func gps(_ place: CLLocation) -> [String: Any] {
        let north = PhotoFacts.written(place.coordinate.latitude, positive: "N", negative: "S")
        let east = PhotoFacts.written(place.coordinate.longitude, positive: "E", negative: "W")
        var gps: [String: Any] = [
            kCGImagePropertyGPSLatitude as String: north.size,
            kCGImagePropertyGPSLatitudeRef as String: north.way,
            kCGImagePropertyGPSLongitude as String: east.size,
            kCGImagePropertyGPSLongitudeRef as String: east.way,
            // How far out the position may be, in metres.
            kCGImagePropertyGPSHPositioningError as String: place.horizontalAccuracy,
            // When the position was found. GPS times are always written
            // in Greenwich time, whatever the season.
            kCGImagePropertyGPSDateStamp as String: stamp(place.timestamp, as: "yyyy:MM:dd", zone: TimeZone(secondsFromGMT: 0)),
            kCGImagePropertyGPSTimeStamp as String: stamp(place.timestamp, as: "HH:mm:ss", zone: TimeZone(secondsFromGMT: 0))
        ]
        // Height above sea level, where the phone knows it. The second
        // note is 0 for above and 1 for below.
        if place.verticalAccuracy >= 0 {
            gps[kCGImagePropertyGPSAltitude as String] = abs(place.altitude)
            gps[kCGImagePropertyGPSAltitudeRef as String] = place.altitude < 0 ? 1 : 0
        }
        return gps
    }

    /// A date as EXIF writes one: "2026:11:14 21:44:05".
    ///
    /// - `form`: the pattern to write it in. Left out, date and time.
    /// - `zone`: whose clock to read. Left out, the phone's own.
    private static func stamp(_ date: Date, as form: String = "yyyy:MM:dd HH:mm:ss",
                              zone: TimeZone? = nil) -> String {
        let formatter = DateFormatter()
        // A fixed locale stops the phone's own settings, such as a
        // 12-hour clock, from changing the form.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = form
        if let zone { formatter.timeZone = zone }
        return formatter.string(from: date)
    }

    /// UIKit and EXIF number the eight ways a picture can be turned
    /// differently. This goes from UIKit's name to EXIF's number.
    private static func turn(_ orientation: UIImage.Orientation) -> Int {
        switch orientation {
        case .up: return 1
        case .upMirrored: return 2
        case .down: return 3
        case .downMirrored: return 4
        case .leftMirrored: return 5
        case .right: return 6
        case .rightMirrored: return 7
        case .left: return 8
        @unknown default: return 1
        }
    }
}

#endif
