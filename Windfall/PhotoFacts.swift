//
//  PhotoFacts.swift
//  Windfall
//
//  What a photo says about itself: when it was taken and where.
//
//  A camera writes notes into each photo's file, in a part called EXIF.
//  Among them are the moment the shutter was pressed and, on a phone,
//  the place. Windfall reads those two, so that a photo taken on
//  Wednesday and brought in on Saturday can be filed under Wednesday.
//
//  A screenshot, a scan or a picture saved from a web page has no such
//  notes. Then there is nothing to read and nothing is guessed.
//
//  The file has two halves. The first turns the camera's own way of
//  writing a date and a position into ordinary values. It needs nothing
//  from Apple, so it can be tested without a Mac. The second opens the
//  photo with ImageIO, Apple's reader for picture files, and is only
//  compiled where ImageIO exists.
//

import Foundation
#if canImport(ImageIO)
import ImageIO
#endif

/// When and where a photo was taken, as far as its file says.
/// Each part is nil where the file does not say.
struct PhotoFacts: Equatable {
    var taken: Date?
    var latitude: Double?
    var longitude: Double?
}

extension PhotoFacts {

    // MARK: Reading the camera's notes

    /// Turns the camera's date, written as "2026:11:11 14:02:33", into
    /// a date.
    ///
    /// - `offset`: how far the camera's clock was from Greenwich, as
    ///   "+01:00". Phones write it. Older cameras do not, and then the
    ///   time is taken to be in `zone`, the device's own time zone.
    ///
    /// Nil if it is not a date, or is from before 1990, which is what a
    /// camera whose clock was never set writes.
    static func date(written: String, offset: String? = nil, zone: TimeZone = .current) -> Date? {
        // Pull out the runs of digits: year, month, day, hour, minute,
        // second. Anything after those, such as parts of a second, is
        // left alone.
        let numbers = written.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard numbers.count >= 6 else { return nil }
        let (year, month, day, hour, minute, second) = (numbers[0], numbers[1], numbers[2], numbers[3], numbers[4], numbers[5])
        guard year >= 1990, (1...12).contains(month), (1...31).contains(day),
              (0...23).contains(hour), (0...59).contains(minute), (0...60).contains(second) else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = offset.flatMap { self.zone(fromOffset: $0) } ?? zone
        return calendar.date(from: DateComponents(year: year, month: month, day: day,
                                                  hour: hour, minute: minute, second: second))
    }

    /// Turns "+01:00", "-0530" or "Z" into a time zone.
    static func zone(fromOffset offset: String) -> TimeZone? {
        let text = offset.trimmingCharacters(in: .whitespaces)
        if text == "Z" { return TimeZone(secondsFromGMT: 0) }
        guard let sign = text.first, sign == "+" || sign == "-" else { return nil }
        let digits = text.dropFirst().filter(\.isNumber)
        guard digits.count == 4, let hours = Int(digits.prefix(2)), let minutes = Int(digits.suffix(2)),
              hours <= 14, minutes <= 59 else { return nil }
        let seconds = (hours * 3600 + minutes * 60) * (sign == "-" ? -1 : 1)
        return TimeZone(secondsFromGMT: seconds)
    }

    /// Turns the camera's way of writing a position into a signed
    /// number. A camera writes how far, always above zero, and a letter
    /// for which way: N or S, E or W. South and west are below zero.
    ///
    /// - `limit`: 90 for a latitude, 180 for a longitude. Anything
    ///   beyond it is not a position and comes back nil.
    static func coordinate(_ value: Double?, reference: String?, limit: Double) -> Double? {
        guard let value, value.isFinite, abs(value) <= limit else { return nil }
        let way = reference?.trimmingCharacters(in: .whitespaces).uppercased() ?? ""
        return way == "S" || way == "W" ? -abs(value) : value
    }

    /// The facts from the three notes a photo's file can hold, as text
    /// and numbers. Split out from `read(from:)` so it can be tested
    /// without a real photo.
    static func facts(original: String?, originalOffset: String?,
                      digitised: String?, digitisedOffset: String?,
                      latitude: Double?, latitudeReference: String?,
                      longitude: Double?, longitudeReference: String?,
                      zone: TimeZone = .current) -> PhotoFacts {
        var facts = PhotoFacts()
        // "Original" is when the shutter was pressed. "Digitised" is
        // when the picture was stored, which for a phone is the same
        // moment. It is the fallback.
        if let original, let date = date(written: original, offset: originalOffset, zone: zone) {
            facts.taken = date
        } else if let digitised, let date = date(written: digitised, offset: digitisedOffset, zone: zone) {
            facts.taken = date
        }
        // A position is only kept whole. Nought north and nought east,
        // a spot in the sea off west Africa, is what an unset GPS writes.
        if let north = coordinate(latitude, reference: latitudeReference, limit: 90),
           let east = coordinate(longitude, reference: longitudeReference, limit: 180),
           !(north == 0 && east == 0) {
            facts.latitude = north
            facts.longitude = east
        }
        return facts
    }

    /// True if the photo was taken long enough before `now` to be worth
    /// mentioning: more than an hour ago, and not in the future, which
    /// would mean a camera with the wrong date.
    func wasTakenEarlier(than now: Date) -> Bool {
        guard let taken else { return false }
        return taken <= now.addingTimeInterval(300) && now.timeIntervalSince(taken) >= 3600
    }
}

#if canImport(ImageIO)
extension PhotoFacts {

    // MARK: Opening the photo

    /// Reads a photo's own notes. The picture itself is not decoded, so
    /// this is quick even for a large photo.
    static func read(from data: Data) -> PhotoFacts {
        // An image source is ImageIO's handle on a picture file. Asking
        // it for its properties gives back the notes as a dictionary: a
        // set of named values, some of them dictionaries in turn.
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let notes = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return PhotoFacts()
        }
        let exif = notes[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        let gps = notes[kCGImagePropertyGPSDictionary as String] as? [String: Any] ?? [:]

        return facts(
            original: exif[kCGImagePropertyExifDateTimeOriginal as String] as? String,
            originalOffset: exif[kCGImagePropertyExifOffsetTimeOriginal as String] as? String,
            digitised: exif[kCGImagePropertyExifDateTimeDigitized as String] as? String,
            digitisedOffset: exif[kCGImagePropertyExifOffsetTimeDigitized as String] as? String,
            latitude: gps[kCGImagePropertyGPSLatitude as String] as? Double,
            latitudeReference: gps[kCGImagePropertyGPSLatitudeRef as String] as? String,
            longitude: gps[kCGImagePropertyGPSLongitude as String] as? Double,
            longitudeReference: gps[kCGImagePropertyGPSLongitudeRef as String] as? String)
    }
}
#endif
