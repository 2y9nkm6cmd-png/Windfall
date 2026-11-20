//
//  SafetyCopy.swift
//  Windfall
//
//  Makes, lists, saves and puts back safety copies: the whole of this
//  device's records, photos included, in a dated folder. The rules
//  (names, when one is due, which to keep) are in SafetyCopyPlan.swift.
//  Built 20 November 2026 (knowledge base doc 138).
//
//  Where things are. SwiftData keeps the records in one SQLite database
//  file, `default.store`, with two working files beside it (`-wal` and
//  `-shm`). Photos and other large pieces are not inside it: they sit
//  as separate files in a hidden folder beside it, `.default_SUPPORT`.
//  A copy has to take both, or the photos would be lost.
//
//  How a whole copy is made while Windfall is running. Copying the
//  database file the ordinary way while it is open can catch it half
//  written. SQLite has its own routine for this, the backup API: it
//  reads the database as one consistent moment, recent changes still
//  in the `-wal` file included, and writes a single tidy file. That is
//  what `copyDatabase` uses. Then SQLite checks the copy
//  (`PRAGMA quick_check`) and the plants and photos in it are counted,
//  so the list can say "376 plants, 11 photos" and "whole".
//
//  Putting a copy back cannot happen while the records are open. So it
//  is asked for (a small file, `put-back.txt`, naming the copy) and
//  done the next time Windfall opens, before the records are opened
//  (`finishPuttingBackIfAsked`, called from WindfallApp.swift). Before
//  anything is replaced, a copy of the records as they stand is made,
//  so a put-back can be undone the same way.
//
//  New things here:
//
//  import SQLite3   SQLite's own C functions, which come with every Apple
//                   system. Their names start `sqlite3_`.
//  OpaquePointer    A handle to something in C code that Swift cannot
//                   look inside: here, an open database.
//  defer            Code that runs when the function is left, however it
//                   is left. Used to close what was opened.
//  nonisolated      May run away from the main thread (see
//                   SafetyCopyPlan.swift). The copying is started with
//                   `Task.detached`, so the screen carries on meanwhile.
//

import Foundation
import SQLite3

nonisolated enum SafetyCopy {

    /// Where the records are, set by WindfallApp when it opens them.
    /// Nil when there is no file to copy: the example garden lives in
    /// memory only.
    nonisolated(unsafe) static var storeURL: URL?

    enum Problem: LocalizedError {
        case noRecords
        case sqlite(String)
        case notFound(String)

        var errorDescription: String? {
            switch self {
            case .noRecords: return "There are no records on this device to copy."
            case .sqlite(let words): return "The database could not be copied: \(words)"
            case .notFound(let name): return "That copy could not be found: \(name)"
            }
        }
    }

    /// One copy, as the list shows it.
    struct Copy: Identifiable, Equatable {
        var id: String { name }
        let name: String
        let folder: URL
        let about: SafetyCopyNote
    }

    // MARK: Where

    /// The folder all copies live in, beside the records.
    static func copiesFolder(for store: URL) -> URL {
        store.deletingLastPathComponent().appendingPathComponent("Safety copies", isDirectory: true)
    }

    /// The hidden folder of photos and other large pieces beside a
    /// store: `.default_SUPPORT` for `default.store`.
    static func supportFolder(for store: URL) -> URL {
        let stem = store.deletingPathExtension().lastPathComponent
        return store.deletingLastPathComponent().appendingPathComponent(".\(stem)_SUPPORT", isDirectory: true)
    }

    // MARK: Making a copy

    /// Makes a copy now and returns it. Old copies beyond the seven kept
    /// are let go afterwards.
    @discardableResult
    static func make(_ kind: SafetyCopyKind, store: URL? = storeURL, now: Date = .now) throws -> Copy {
        guard let store, FileManager.default.fileExists(atPath: store.path) else { throw Problem.noRecords }
        let files = FileManager.default
        let home = copiesFolder(for: store)
        let name = SafetyCopyPlan.folderName(made: now)
        let folder = home.appendingPathComponent(name, isDirectory: true)
        try files.createDirectory(at: folder, withIntermediateDirectories: true)

        // If anything below fails, the half-made folder is removed, so
        // the list never shows a copy that is not whole.
        do {
            let copiedStore = folder.appendingPathComponent(store.lastPathComponent)
            try copyDatabase(from: store, to: copiedStore)
            let support = supportFolder(for: store)
            if files.fileExists(atPath: support.path) {
                try files.copyItem(at: support, to: supportFolder(for: copiedStore))
            }
            let checked = check(copiedStore)
            let aboutThis = SafetyCopyNote(made: now, kind: kind, plants: checked.plants, photos: checked.photos,
                                      bytes: size(of: folder), checkedWhole: checked.whole)
            try JSONEncoder().encode(aboutThis).write(to: folder.appendingPathComponent("about.json"))
            letGoOfOld(in: store)
            return Copy(name: name, folder: folder, about: aboutThis)
        } catch {
            try? files.removeItem(at: folder)
            throw error
        }
    }

    /// Today's copy, if none has been made yet today. Called when
    /// Windfall opens, away from the screen's own work. Quietly does
    /// nothing if it cannot: a missing copy must never stop the app.
    static func makeDailyIfDue(now: Date = .now) {
        guard let store = storeURL else { return }
        let newest = list(store: store).first?.about.made
        guard SafetyCopyPlan.isDailyDue(newest: newest, now: now) else { return }
        _ = try? make(.daily, store: store, now: now)
    }

    /// The copies on this device, newest first.
    static func list(store: URL? = storeURL) -> [Copy] {
        guard let store else { return [] }
        let home = copiesFolder(for: store)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: home.path)) ?? []
        let copies: [Copy] = names.compactMap { name in
            let folder = home.appendingPathComponent(name, isDirectory: true)
            guard let data = try? Data(contentsOf: folder.appendingPathComponent("about.json")),
                  let about = try? JSONDecoder().decode(SafetyCopyNote.self, from: data) else { return nil }
            return Copy(name: name, folder: folder, about: about)
        }
        return copies.sorted { $0.about.made > $1.about.made }
    }

    private static func letGoOfOld(in store: URL) {
        let copies = list(store: store)
        for name in SafetyCopyPlan.toLetGo(copies.map { ($0.name, $0.about) }) {
            try? FileManager.default.removeItem(at: copiesFolder(for: store).appendingPathComponent(name))
        }
    }

    // MARK: The database

    /// Copies an SQLite database with SQLite's backup routine, which
    /// takes it as one consistent moment even while it is open and in
    /// use. 256 pages at a time (about a megabyte), so the database is
    /// never held for long; if it is busy, it waits a twentieth of a
    /// second and tries again.
    static func copyDatabase(from source: URL, to destination: URL) throws {
        var from: OpaquePointer?
        var into: OpaquePointer?
        guard sqlite3_open_v2(source.path, &from, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            defer { sqlite3_close(from) }
            throw Problem.sqlite(String(cString: sqlite3_errmsg(from)))
        }
        defer { sqlite3_close(from) }
        guard sqlite3_open(destination.path, &into) == SQLITE_OK else {
            defer { sqlite3_close(into) }
            throw Problem.sqlite(String(cString: sqlite3_errmsg(into)))
        }
        defer { sqlite3_close(into) }
        guard let backup = sqlite3_backup_init(into, "main", from, "main") else {
            throw Problem.sqlite(String(cString: sqlite3_errmsg(into)))
        }
        var result: Int32
        repeat {
            result = sqlite3_backup_step(backup, 256)
            if result == SQLITE_BUSY || result == SQLITE_LOCKED { sqlite3_sleep(50) }
        } while result == SQLITE_OK || result == SQLITE_BUSY || result == SQLITE_LOCKED
        sqlite3_backup_finish(backup)
        guard result == SQLITE_DONE else { throw Problem.sqlite(String(cString: sqlite3_errstr(result))) }
    }

    /// Asks SQLite whether a copied database is whole, and counts the
    /// plants and photos in it. SwiftData names its tables after the
    /// record types with a Z in front: `ZPLANT`, `ZPHOTO`.
    ///
    /// The copy is opened as unchangeable (`immutable=1`). SwiftData's
    /// databases use SQLite's "write-ahead log" way of working, and a
    /// copy made by the backup routine says so in its first page; opened
    /// plainly read-only, SQLite would want the log's working files,
    /// which a copy does not have, and every question would fail.
    static func check(_ database: URL) -> (whole: Bool, plants: Int?, photos: Int?) {
        var handle: OpaquePointer?
        let address = database.absoluteString + "?immutable=1"
        guard sqlite3_open_v2(address, &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
            sqlite3_close(handle)
            return (false, nil, nil)
        }
        defer { sqlite3_close(handle) }
        func firstWord(_ sql: String) -> String? {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW, let text = sqlite3_column_text(statement, 0) else { return nil }
            return String(cString: text)
        }
        let whole = firstWord("PRAGMA quick_check") == "ok"
        return (whole, firstWord("SELECT count(*) FROM ZPLANT").flatMap(Int.init),
                firstWord("SELECT count(*) FROM ZPHOTO").flatMap(Int.init))
    }

    /// The size of everything in a folder, in bytes.
    private static func size(of folder: URL) -> Int64 {
        guard let walk = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let piece as URL in walk {
            total += Int64((try? piece.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    // MARK: Saving a copy elsewhere

    /// One file holding a whole copy, for saving to Files or iCloud
    /// Drive: the copy's folder packed as a .zip. Apple's file
    /// coordinator does the packing (the `.forUploading` reading option
    /// hands back a zipped form of a folder); the result is put in the
    /// app's temporary folder for the share sheet to take.
    static func zipped(_ copy: Copy) throws -> URL {
        var packed: URL?
        var inner: Error?
        var coordinatorError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: copy.folder, options: .forUploading,
                                       error: &coordinatorError) { zip in
            let out = FileManager.default.temporaryDirectory
                .appendingPathComponent("Windfall " + copy.name.lowercased() + ".zip")
            try? FileManager.default.removeItem(at: out)
            do {
                try FileManager.default.copyItem(at: zip, to: out)
                packed = out
            } catch {
                inner = error
            }
        }
        if let problem = coordinatorError ?? inner { throw problem }
        guard let packed else { throw Problem.notFound(copy.name) }
        return packed
    }

    // MARK: Putting a copy back

    /// The small file that asks for a copy to be put back next time.
    private static func putBackRequest(for store: URL) -> URL {
        copiesFolder(for: store).appendingPathComponent("put-back.txt")
    }

    /// Asks for a copy to be put back the next time Windfall opens.
    static func askToPutBack(_ copy: Copy, store: URL? = storeURL) throws {
        guard let store else { throw Problem.noRecords }
        try copy.name.write(to: putBackRequest(for: store), atomically: true, encoding: .utf8)
    }

    /// The copy waiting to be put back, if one has been asked for.
    static func waitingToPutBack(store: URL? = storeURL) -> String? {
        guard let store,
              let name = try? String(contentsOf: putBackRequest(for: store), encoding: .utf8) else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Calls off a put-back that has been asked for.
    static func callOffPutBack(store: URL? = storeURL) {
        guard let store else { return }
        try? FileManager.default.removeItem(at: putBackRequest(for: store))
    }

    /// Done when Windfall opens, before the records are opened. If a
    /// copy has been asked for: copy the records as they stand (so this
    /// can be undone), then put the asked-for copy in their place.
    ///
    /// The request is removed first of all, so that if anything goes
    /// wrong Windfall does not try again on every opening.
    static func finishPuttingBackIfAsked(store: URL) {
        guard let name = waitingToPutBack(store: store) else { return }
        callOffPutBack(store: store)
        let files = FileManager.default
        let chosen = copiesFolder(for: store).appendingPathComponent(name, isDirectory: true)
        let chosenStore = chosen.appendingPathComponent(store.lastPathComponent)
        guard files.fileExists(atPath: chosenStore.path) else { return }
        // The records as they stand. If this copy cannot be made, nothing
        // is replaced: never put a copy back without a way back.
        guard (try? make(.beforePuttingBack, store: store)) != nil else { return }

        let support = supportFolder(for: store)
        for working in [store, URL(fileURLWithPath: store.path + "-wal"), URL(fileURLWithPath: store.path + "-shm"), support] {
            try? files.removeItem(at: working)
        }
        try? files.copyItem(at: chosenStore, to: store)
        let chosenSupport = supportFolder(for: chosenStore)
        if files.fileExists(atPath: chosenSupport.path) {
            try? files.copyItem(at: chosenSupport, to: support)
        }
    }
}
