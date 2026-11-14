//
//  PhotoStore.swift
//  Windfall
//
//  Where the original of each photo is kept.
//
//  A photo from a phone is large: three of them came to 24.6 MB on 14
//  November 2026. Kept inside the app they would swell its store of
//  records, and they would stay on the one device.
//
//  So, until the app syncs through CloudKit, the originals are kept as
//  ordinary files in a folder of your choosing, which is meant to be one
//  in iCloud Drive. iCloud Drive then carries them to your other devices
//  and they can be seen in Finder or the Files app. (William, 14 November
//  2026: "Store the photos on icloud for now until we get cloudkit up
//  and running.")
//
//  What stays in the app with each photo's record is a smaller copy, at
//  most 2048 points on its longer side, and the small one for lists. So
//  every photo can still be shown when the original has not been fetched
//  from iCloud, or the folder has been moved.
//
//  If no folder has been chosen, nothing here does anything and the
//  original stays in the app, as it did before.
//
//  How an original is found again: by its name. Each file is named with
//  the time the photo was taken and the first eight characters of the
//  photo record's own label, for example
//
//      2026/2026-11-11 14.02.33 3F2A9C1E.heic
//
//  The record holds both, so nothing new has to be stored in it to find
//  the file. That matters: changing what a record holds means changing
//  the database, which is not to be done lightly.
//
//  New things here:
//
//  Bookmark        A saved pointer to a folder that keeps working when
//                  the app is closed and opened again, and that carries
//                  your permission for the app to use that folder. You
//                  give the permission by choosing the folder yourself.
//

import Foundation
import UniformTypeIdentifiers
#if canImport(ImageIO)
import ImageIO
#endif

enum PhotoStore {

    // The names the two settings are saved under.
    private static let bookmarkKey = "photoFolderBookmark"
    private static let nameKey = "photoFolderName"

    /// The longer side of the copy kept in the app, in points.
    static let keptCopySide: CGFloat = 2048

    // MARK: The folder

    /// The chosen folder's name, to show in Settings. Nil if none has
    /// been chosen.
    static var folderName: String? {
        UserDefaults.standard.data(forKey: bookmarkKey) == nil ? nil : UserDefaults.standard.string(forKey: nameKey)
    }

    /// Remembers a folder chosen in a file window. Returns false if the
    /// system would not give a bookmark for it.
    @discardableResult
    static func choose(_ url: URL) -> Bool {
        // Leave to use a folder chosen in a file window lasts only
        // between these two calls. The bookmark made inside them is
        // what carries it forward.
        let hasLeave = url.startAccessingSecurityScopedResource()
        defer { if hasLeave { url.stopAccessingSecurityScopedResource() } }
        guard let bookmark = try? url.bookmarkData() else { return false }
        UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
        UserDefaults.standard.set(url.lastPathComponent, forKey: nameKey)
        return true
    }

    /// Forgets the folder. Files already in it are left where they are.
    static func forget() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        UserDefaults.standard.removeObject(forKey: nameKey)
    }

    /// Runs `work` with the folder open for use. Returns nil, without
    /// running it, if no folder is chosen or it can no longer be found.
    private static func withFolder<Result>(_ work: (URL) -> Result?) -> Result? {
        guard let bookmark = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var isStale = false
        guard let folder = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale) else { return nil }
        let hasLeave = folder.startAccessingSecurityScopedResource()
        defer { if hasLeave { folder.stopAccessingSecurityScopedResource() } }
        // A bookmark goes stale if the folder is moved or renamed. It
        // still points to the right place, and is renewed here.
        if isStale, let fresh = try? folder.bookmarkData() {
            UserDefaults.standard.set(fresh, forKey: bookmarkKey)
            UserDefaults.standard.set(folder.lastPathComponent, forKey: nameKey)
        }
        return work(folder)
    }

    // MARK: Names

    /// The year folder and the start of the file name for a photo:
    /// ("2026", "2026-11-11 14.02.33 3F2A9C1E"). The file's ending is
    /// added when it is written, since it depends on the kind of photo.
    ///
    /// The time is written in Greenwich time whatever the device's own
    /// zone, so that the same photo gets the same name on every device.
    static func place(taken: Date, id: UUID) -> (year: String, stem: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: taken)
        let year = String(format: "%04d", parts.year ?? 0)
        let stamp = String(format: "%04d-%02d-%02d %02d.%02d.%02d",
                           parts.year ?? 0, parts.month ?? 0, parts.day ?? 0,
                           parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0)
        return (year, "\(stamp) \(id.uuidString.prefix(8))")
    }

    // MARK: Keeping and finding

    /// Writes a photo's original into the folder. Returns true if it is
    /// safely there.
    ///
    /// Nothing is written while the example garden is showing, because
    /// example data never touches real records.
    static func keep(original data: Data, taken: Date, id: UUID) -> Bool {
        guard !DemoGarden.isRequested else { return false }
        return withFolder { folder -> Bool? in
            let (year, stem) = place(taken: taken, id: id)
            let yearFolder = folder.appendingPathComponent(year, isDirectory: true)
            let file = yearFolder.appendingPathComponent("\(stem).\(ending(of: data))")
            do {
                try FileManager.default.createDirectory(at: yearFolder, withIntermediateDirectories: true)
                // "Atomic" writes the whole file under another name and
                // then swaps it in, so a half-written photo is never left.
                try data.write(to: file, options: .atomic)
                return true
            } catch {
                return false
            }
        } ?? false
    }

    /// Reads a photo's original back from the folder. Nil if no folder
    /// is chosen, the file is not there, or iCloud has not fetched it to
    /// this device yet.
    static func original(taken: Date, id: UUID) -> Data? {
        withFolder { folder -> Data? in
            let (year, stem) = place(taken: taken, id: id)
            let yearFolder = folder.appendingPathComponent(year, isDirectory: true)
            let names = (try? FileManager.default.contentsOfDirectory(atPath: yearFolder.path)) ?? []
            guard let name = names.first(where: { $0.hasPrefix(stem + ".") }) else { return nil }
            return try? Data(contentsOf: yearFolder.appendingPathComponent(name))
        }
    }

    /// The ending for a photo's file, such as "heic" or "jpg", worked
    /// out from the photo itself. "jpg" if it cannot be told.
    private static func ending(of data: Data) -> String {
        #if canImport(ImageIO)
        if let source = CGImageSourceCreateWithData(data as CFData, nil),
           let kind = CGImageSourceGetType(source),
           let ending = UTType(kind as String)?.preferredFilenameExtension {
            return ending == "jpeg" ? "jpg" : ending
        }
        #endif
        return "jpg"
    }
}
