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

import SwiftUI

#if os(iOS)
import UIKit
import ImageIO
import UniformTypeIdentifiers
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
    /// The photo just taken, held for the moment between "Use Photo"
    /// and the camera having slid away.
    @State private var taken: Data?

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
                CameraScreen(onTaken: { taken = $0 }, close: { isPresented = false })
                    // Let the camera run under the clock and the home
                    // bar, as it does in Apple's own Camera app.
                    .ignoresSafeArea()
            }
        #else
        content
        #endif
    }

    private func handOver() {
        guard let photo = taken else { return }
        taken = nil
        onTaken(photo)
    }
}

#if os(iOS)

/// Apple's camera screen, wrapped for SwiftUI.
private struct CameraScreen: UIViewControllerRepresentable {

    /// Called with the photo when "Use Photo" is pressed.
    let onTaken: (Data) -> Void
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

        let onTaken: (Data) -> Void
        let close: () -> Void

        init(onTaken: @escaping (Data) -> Void, close: @escaping () -> Void) {
            self.onTaken = onTaken
            self.close = close
        }

        /// "Use Photo" was pressed. `info` is a bag of named things: the
        /// picture, and the notes the camera made about it.
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let picture = info[.originalImage] as? UIImage
            let notes = info[.mediaMetadata] as? [String: Any]
            if let picture, let data = CameraFile.jpeg(from: picture, notes: notes) {
                onTaken(data)
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
/// together here, as a JPEG.
private enum CameraFile {

    static func jpeg(from picture: UIImage, notes: [String: Any]?) -> Data? {
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

        let properties: [String: Any] = [
            // Which way up the phone was held. The pixels are always
            // stored the same way round and this note says how to turn
            // them. Without it a portrait photo would lie on its side.
            kCGImagePropertyOrientation as String: turn(picture.imageOrientation),
            kCGImagePropertyExifDictionary as String: exif,
            // How hard to squeeze the file. 1 is largest and best.
            kCGImageDestinationLossyCompressionQuality as String: 0.9
        ]
        CGImageDestinationAddImage(destination, pixels, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return plain }
        return file as Data
    }

    /// A date as EXIF writes one: "2026:11:14 21:44:05".
    private static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        // A fixed locale stops the phone's own settings, such as a
        // 12-hour clock, from changing the form.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
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
