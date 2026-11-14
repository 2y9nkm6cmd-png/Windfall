//
//  PhotoDrop.swift
//  Windfall
//
//  Taking photos that are dragged on to the app.
//
//  On a Mac a photo is dragged from Finder or from Photos. On an iPad it
//  is dragged from another app shown beside Windfall. Either way SwiftUI
//  hands over a list of "item providers": one for each thing dropped,
//  each a promise to supply the thing itself a moment later.
//
//  Three places take a drop: the Journal page, Eira's bar and the
//  Identify screen. They all read what was dropped with the one function
//  here, so a photo that works in one place works in all of them.
//
//  New things here:
//
//  UTType            Apple's name for a kind of file, such as "image" or
//                    "a file's address". A drop target says which kinds
//                    it will take.
//
//  withCheckedContinuation
//                    A bridge between two styles of waiting. The item
//                    provider answers by calling a piece of code later.
//                    The rest of the app waits with `await`. This turns
//                    the first into the second.
//
//  withTaskGroup     Starts several pieces of work at the same time and
//                    collects their answers as each finishes. Used at
//                    the foot of `PhotoDrop` to fetch every photo chosen
//                    in the Photos chooser at once, where they used to
//                    be fetched one after another.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

enum PhotoDrop {

    /// What a drop target takes: pictures, and files, since a photo
    /// dragged from Finder arrives as the file's address.
    static let kinds: [UTType] = [.image, .fileURL]

    /// True if any of what was dropped could be a photo. This is all
    /// that can be said at the moment of the drop. Whether a file really
    /// is a picture is only known once it has been read.
    static func mayHold(_ providers: [NSItemProvider]) -> Bool {
        providers.contains { provider in
            kinds.contains { provider.hasItemConformingToTypeIdentifier($0.identifier) }
        }
    }

    /// Reads the photos out of what was dropped, in the order they were
    /// dropped. Anything that is not a picture is left out.
    ///
    /// Each photo comes back as its file's own bytes, unaltered, so the
    /// date and place the camera wrote into it can still be read
    /// (PhotoFacts.swift).
    static func pictures(from providers: [NSItemProvider]) async -> [Data] {
        var pictures: [Data] = []
        // One at a time, so they stay in order.
        for provider in providers {
            if let data = await picture(from: provider) { pictures.append(data) }
        }
        return pictures
    }

    private static func picture(from provider: NSItemProvider) async -> Data? {
        // A file first. Reading the file itself is the surest way to get
        // the photo exactly as the camera saved it.
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            let url = await withCheckedContinuation { (waiting: CheckedContinuation<URL?, Never>) in
                _ = provider.loadObject(ofClass: URL.self) { url, _ in waiting.resume(returning: url) }
            }
            if let url, isPicture(url) {
                // Leave to read a dropped file lasts only between these
                // two calls.
                let hasLeave = url.startAccessingSecurityScopedResource()
                defer { if hasLeave { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) { return data }
            }
        }
        // Otherwise the picture itself, as Photos hands it over.
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            return await withCheckedContinuation { (waiting: CheckedContinuation<Data?, Never>) in
                _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    waiting.resume(returning: data)
                }
            }
        }
        return nil
    }

    /// True if the file's ending says it is a picture: jpg, heic, png
    /// and so on.
    private static func isPicture(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) ?? false
    }

    /// Reads the photos chosen in Apple's Photos chooser, in the order
    /// they were chosen. Any that cannot be fetched is left out.
    ///
    /// The chooser hands over a list of items, each a promise of a
    /// photo. Fetching one can take a while, most of all when iCloud
    /// holds the original and it has to be downloaded. So they are all
    /// asked for at the same time: each `addTask` starts one fetch
    /// without waiting for the one before, and the `for await` loop
    /// collects the answers as they come in. They can finish in any
    /// order, so each answer carries its place in the list and the
    /// photos are put back in that order at the end.
    static func pictures(from items: [PhotosPickerItem]) async -> [Data] {
        await withTaskGroup(of: (Int, Data?).self) { group in
            for (place, item) in items.enumerated() {
                group.addTask {
                    (place, try? await item.loadTransferable(type: Data.self))
                }
            }
            var found: [Int: Data] = [:]
            for await (place, data) in group {
                if let data { found[place] = data }
            }
            return items.indices.compactMap { found[$0] }
        }
    }
}

/// A dashed outline with a few words in the middle, drawn over a place
/// while photos are held above it, to show that letting go there will
/// do something and what.
struct PhotoDropOutline: View {

    let words: String
    var cornerRadius: CGFloat = 22

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Theme.leaf.opacity(0.08))
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Theme.leaf, style: StrokeStyle(lineWidth: 2.5, dash: [8, 6]))
            HStack(spacing: 8) {
                WIconView(.photo, size: 22)
                Text(words)
                    .font(.title3.weight(.semibold))
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .capsule)
        }
        .padding(8)
        // The outline is only a picture. The drop goes to what is under it.
        .allowsHitTesting(false)
    }
}

// MARK: - A photo that is on its way

/// A photo chosen or dropped, and not yet kept with a record.
///
/// It is shown the moment it is chosen, as a grey tile with a spinner,
/// and filled in as its parts arrive: first the photo's own bytes,
/// then the small copy to draw. Used by the journal's conversation
/// (JournalChatView.swift) and by the editor for an entry already
/// written (JournalEntryEditor.swift).
struct WaitingPhoto: Identifiable {
    let id = UUID()
    /// The photo's file, as it came. Nil while it is being fetched
    /// from the Photos library.
    var data: Data?
    /// The small copy to draw. Nil while it is being made.
    var thumbnail: Data?
    /// When and where it was taken, read from the file.
    var facts = PhotoFacts()
}

/// The tile for a photo that is on its way: the small copy once there
/// is one, a spinner until then, and a cross in the corner to take the
/// photo off again.
struct WaitingPhotoTile: View {

    /// The small copy to draw. Nil shows the spinner.
    let thumbnail: Data?
    var size: CGFloat = 64
    /// What the cross does.
    let onRemove: () -> Void

    var body: some View {
        ZStack {
            Theme.card
            if let thumbnail, let picture = PhotoThumbnail.image(from: thumbnail) {
                picture
                    .resizable()
                    .scaledToFill()
            } else {
                // Still being fetched or made smaller.
                ProgressView().controlSize(.small)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: 10))
        .accessibilityLabel(thumbnail == nil ? "Photo, loading" : "Photo")
        .overlay(alignment: .topTrailing) {
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 20, height: 20)
                    .background(Theme.card, in: .circle)
            }
            .buttonStyle(.plain)
            .padding(3)
            .accessibilityLabel("Remove photo")
        }
    }
}

extension Photo {

    /// Makes the record for a photo that has just come in.
    ///
    /// - `facts`: what the photo's file says about itself, if that has
    ///   already been read. Left out, it is read here.
    /// - `thumbnail`: the small copy for lists, if one has already been
    ///   made. Left out, it is made here.
    /// - `smallerCopy`: a copy already made smaller, to keep in the app
    ///   in place of the original where there is no photo folder for the
    ///   original to go to. The Identify screen has one.
    /// - `otherwiseAt`: the time to note if the photo does not say when
    ///   it was taken.
    ///
    /// Every place that keeps a photo goes through here, so that they
    /// all keep the same things about it.
    static func record(of data: Data, facts: PhotoFacts? = nil, thumbnail: Data? = nil,
                       smallerCopy: Data? = nil, otherwiseAt fallback: Date = .now) -> Photo {
        let facts = facts ?? PhotoFacts.read(from: data)
        let photo = Photo()
        photo.thumbnailData = thumbnail ?? DiaryEntryEditor.thumbnail(from: data)
        photo.capturedAt = facts.taken ?? fallback
        photo.latitude = facts.latitude
        photo.longitude = facts.longitude

        // The original goes to the photo folder, if one has been chosen
        // in Settings and the file is safely written there. The app then
        // keeps a smaller copy. Otherwise the app keeps the original
        // itself, as it always did. See PhotoStore.swift.
        if PhotoStore.keep(original: data, taken: photo.capturedAt, id: photo.id) {
            photo.imageData = PhotoShrink.jpeg(from: data, longestSide: PhotoStore.keptCopySide) ?? data
        } else {
            photo.imageData = smallerCopy ?? data
        }
        return photo
    }
}
