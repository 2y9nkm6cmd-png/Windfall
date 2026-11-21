//
//  FormDraft.swift
//  Windfall
//
//  WHAT WAS TYPED, KEPT UNTIL SAVE OR CLEAR
//
//  William, 21 November 2026, from the iPhone's Harvest page: "I want to
//  be able to swipe back from screens like this." Asked what a swipe
//  should do to something typed but not saved, he chose to keep it
//  ("This sounds good", card d-swipe-unsaved-144, project doc 144):
//
//    - a swipe down, Back or Cancel closes the form at once, with no
//      question
//    - what was typed is kept, photos too
//    - opening the same form for the same thing again fills it back in,
//      with "Carried on from earlier" and a Clear button
//    - Save clears the kept copy
//
//  A kept copy is NOT a record. It lives in the app's settings on this
//  device (`UserDefaults`), never in the records, so it is never counted
//  in a harvest total, shown in a list, put in a backup or sent in an
//  export. Its photos are plain files in a folder of their own.
//
//  How long: the words until Save or Clear, however long that is; the
//  photos 30 days, because they take room. A kept copy outlives the
//  app being closed, because the settings are kept on the device.
//  (⚠️ CHECK: Claude's choices, project doc 145.)
//
//  This file is only the keeping, so the logic tests can try it. The
//  forms decide what to keep, and FormDraftViews.swift has the "Carried
//  on from earlier" line and the small piece of SwiftUI that keeps a
//  form's copy up to date as it is typed in.
//

import Foundation

enum FormDraft {

    /// Every kept copy's name in the settings starts with this, so they
    /// can be found and told apart from every other setting.
    static let prefix = "formDraft."

    /// How long a kept copy's photos stay, in days.
    static let photoDays: Double = 30

    /// Where the kept copies are written: the app's own settings. The
    /// logic tests hand in a settings store of their own.
    /// `nonisolated(unsafe)` tells Swift that this shared value may be
    /// read from anywhere; only the tests ever change it.
    nonisolated(unsafe) static var settings: UserDefaults = .standard

    /// The folder that holds each kept copy's photos, one folder a copy,
    /// in the app's own Application Support folder.
    nonisolated(unsafe) static var photoFolder: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Form drafts", isDirectory: true)

    /// What is written: the form's own values and when they were kept.
    /// `Value` is whatever the form says it keeps: each form has a small
    /// struct of its own.
    private struct Kept<Value: Codable>: Codable {
        var keptAt: Date
        var value: Value
    }

    /// Only the date, for tidying without knowing which form it was.
    private struct Stamp: Decodable {
        var keptAt: Date
    }

    // MARK: Names

    /// The name for one form's kept copy, and what it is about.
    /// `key("harvest", planting.id)` keeps a harvest for one sowing apart
    /// from a harvest for another. A form about nothing in particular (a
    /// new seed packet) leaves `about` out.
    static func key(_ form: String, _ about: UUID? = nil) -> String {
        guard let about else { return form }
        return "\(form).\(about.uuidString)"
    }

    // MARK: Keeping, reading, clearing

    /// Keeps (or replaces) the copy under this name.
    static func keep<Value: Codable>(_ value: Value, key: String, now: Date = .now) {
        guard let data = try? JSONEncoder().encode(Kept(keptAt: now, value: value)) else { return }
        settings.set(data, forKey: prefix + key)
    }

    /// The copy kept under this name, or nil if there is none, or if it
    /// can no longer be read (a form that has since changed what it keeps).
    static func load<Value: Codable>(_ type: Value.Type, key: String) -> Value? {
        guard let data = settings.data(forKey: prefix + key) else { return nil }
        return (try? JSONDecoder().decode(Kept<Value>.self, from: data))?.value
    }

    /// True when a copy is kept under this name.
    static func isKept(_ key: String) -> Bool {
        settings.data(forKey: prefix + key) != nil
    }

    /// Takes away the copy and its photos. Save and Clear call this.
    static func clear(key: String) {
        settings.removeObject(forKey: prefix + key)
        try? FileManager.default.removeItem(at: folder(for: key))
    }

    /// The names of every copy kept, without the prefix, in order.
    static func keptKeys() -> [String] {
        settings.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
            .sorted()
    }

    // MARK: Photos

    private static func folder(for key: String) -> URL {
        // A name is letters, figures, dots and dashes (a form's name and
        // a UUID), so it is safe as a folder name as it is.
        photoFolder.appendingPathComponent(key, isDirectory: true)
    }

    /// Keeps these photos with the copy, in place of any kept before.
    /// An empty list takes the folder away.
    static func keepPhotos(_ photos: [Data], key: String) {
        let place = folder(for: key)
        try? FileManager.default.removeItem(at: place)
        guard !photos.isEmpty else { return }
        try? FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
        for (number, picture) in photos.enumerated() {
            // Numbered from 1000, so that sorting the names by their
            // letters keeps the photos in the order they came.
            try? picture.write(to: place.appendingPathComponent("\(1000 + number).photo"))
        }
    }

    /// The photos kept with the copy, in the order they were added.
    static func photos(key: String) -> [Data] {
        let place = folder(for: key)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: place.path)) ?? []
        return names.filter { $0.hasSuffix(".photo") }.sorted()
            .compactMap { try? Data(contentsOf: place.appendingPathComponent($0)) }
    }

    // MARK: Tidying

    /// Takes away photos kept more than 30 days, and any photo folder
    /// whose copy has gone. The words stay. Run when a form opens.
    static func tidy(now: Date = .now) {
        let fresh = Set(keptKeys().filter { key in
            guard let data = settings.data(forKey: prefix + key),
                  let stamp = try? JSONDecoder().decode(Stamp.self, from: data) else { return false }
            return now.timeIntervalSince(stamp.keptAt) < photoDays * 86_400
        })
        let folders = (try? FileManager.default.contentsOfDirectory(atPath: photoFolder.path)) ?? []
        for name in folders where !fresh.contains(name) {
            try? FileManager.default.removeItem(at: photoFolder.appendingPathComponent(name, isDirectory: true))
        }
    }
}
