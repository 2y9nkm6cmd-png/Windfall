//
//  PhotoShrink.swift
//  Windfall
//
//  Making a smaller copy of a photo, quickly and without holding up
//  the screen.
//
//  Why this file exists (William, 14 November 2026: "When you add
//  photos to Eira, it's really slow to actually show them"). Until
//  then every small copy in the app was made like this:
//
//    1. Open the whole photo. A phone's photo is 12 to 48 million
//       dots, and opened out in memory that is 50 to 190MB.
//    2. Draw it again, smaller.
//    3. Save the drawing as a JPEG.
//
//  and all three were done on the "main thread". A thread is one line
//  of work the device is getting on with. The main thread is the one
//  that draws the screen and answers touches, so while it was busy
//  opening a photo nothing on screen could change: no spinner, no
//  photo, no response to a tap. Each photo was also opened two or
//  three times over, once for each place that wanted a copy.
//
//  Two things are different here.
//
//  The copy is made by ImageIO, Apple's reader for picture files,
//  which can read a photo straight down to the size wanted. It never
//  holds the full-size picture as a drawing, so it is several times
//  quicker and uses a fraction of the memory. (SpeciesEye.swift
//  already read photos this way for the image model.)
//
//  And the work can be done away from the main thread, by
//  `PhotoWorkshop` below, so the screen stays free to show a grey
//  tile with a spinner at once and swap the photo in when it is ready.
//
//  Sizes here are in pixels, the dots a picture is made of, counted
//  along its longer side.
//
//  New things here:
//
//  nonisolated     "May be run from any thread." This project treats
//                  everything as belonging to the main thread unless
//                  told otherwise (a build setting, Default Actor
//                  Isolation). The functions below touch nothing on
//                  screen, so they are marked as free to run anywhere.
//
//  actor           A kind of object that does one job at a time and
//                  never on the main thread. Anything asked of it
//                  joins a queue, and the asker `await`s the answer.
//                  Here that means photos are shrunk one after
//                  another, in the background. One at a time matters:
//                  ten large photos opened at once could use more
//                  memory than a phone will give an app.
//

import Foundation
#if canImport(ImageIO)
import ImageIO
import UniformTypeIdentifiers
#endif

enum PhotoShrink {

    // The sizes the app uses, in pixels along the longer side.

    /// The small copy for lists and tiles. A tile is at most 88 points
    /// wide, and the sharpest screens draw three pixels to a point, so
    /// 264 would do. 600 leaves room for a larger tile later.
    nonisolated static let tileSide = 600

    /// The copy on the card that asks what to do with a photo, which is
    /// drawn 170 points tall.
    nonisolated static let cardSide = 1200

    /// The copy Eira looks at and a sighting keeps: plenty to name
    /// something from, and a fraction of the size of the original.
    nonisolated static let lookSide = 2048

    /// How many pixels to use for a size given in points.
    ///
    /// The older function this replaces was asked for sizes in points
    /// and drew at the screen's own scale, two or three pixels to a
    /// point. Two is used everywhere now, so a copy is the same size
    /// whichever device made it.
    nonisolated static func pixels(forPoints points: Double) -> Int {
        max(1, Int((points * 2).rounded()))
    }

    /// A JPEG copy of a photo, no more than `longestSide` pixels along
    /// its longer side, the right way up. A photo already smaller than
    /// that is not made larger. Nil if the bytes are not a picture.
    ///
    /// - `quality`: how hard the JPEG is squeezed, from 0 (small file,
    ///   rough picture) to 1 (large file, exact picture).
    ///
    /// The copy carries none of the camera's notes, so read those from
    /// the original first (PhotoFacts.swift).
    nonisolated static func jpeg(from data: Data, longestSide: Int, quality: Double = 0.7) -> Data? {
        #if canImport(ImageIO)
        // An image source is ImageIO's handle on a picture file.
        // Making one reads only the start of the file.
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let reading: [CFString: Any] = [
            // Make the small picture from the photo itself, not from
            // the tiny preview a camera tucks into the file, which is
            // often only 160 pixels wide.
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // A phone stores a photo as the camera saw it, with a note
            // saying which way up to show it. This applies the note.
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, longestSide),
            // Do the reading now, on this thread, and not later when
            // the picture is first drawn, which would be the main one.
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let small = CGImageSourceCreateThumbnailAtIndex(source, 0, reading as CFDictionary) else { return nil }

        // An image destination is the other end: it writes a picture
        // out as a file's bytes, here into `written`.
        let written = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            written as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        let writing: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(destination, small, writing as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return written as Data
        #else
        return nil
        #endif
    }
}

/// Where photos are made smaller, away from the main thread and one at
/// a time. There is one workshop for the whole app, `PhotoWorkshop.shared`.
///
/// Used like this, from anything that can wait:
///
///     let small = await PhotoWorkshop.shared.jpeg(from: data, longestSide: PhotoShrink.tileSide)
///
/// `await` marks the place where the caller steps aside until the
/// answer comes. The screen carries on being drawn meanwhile.
actor PhotoWorkshop {

    static let shared = PhotoWorkshop()

    /// The same as `PhotoShrink.jpeg`, done in the background.
    func jpeg(from data: Data, longestSide: Int, quality: Double = 0.7) -> Data? {
        PhotoShrink.jpeg(from: data, longestSide: longestSide, quality: quality)
    }
}
