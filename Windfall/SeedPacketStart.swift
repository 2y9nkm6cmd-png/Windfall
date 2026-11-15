//
//  SeedPacketStart.swift
//  Windfall
//
//  The ways to put a seed packet on record.
//
//  Until 15 November 2026 the Seed page could only add a packet by
//  typing it in, and reading a packet from a photo lived on a tile of
//  its own on the Gardens page. William, of the Seed page: "Why doesn't
//  this page let you take a photo to get the information?" Now the Seed
//  page offers every way in, and this file is the list of them.
//
//  It is kept apart from the screens so that it can be tested without a
//  Mac (see Tools/checks). It has no `import SwiftUI`: it knows the
//  words and the symbol for each choice, and nothing about drawing them.
//
//  New things here:
//
//  enum              A type that is exactly one of a fixed list of
//                    cases. A packet is started in one of three ways,
//                    and never in two at once, so an enum fits.
//
//  Identifiable      A promise that each value has an `id` that tells
//                    it from the others. SwiftUI asks for it wherever
//                    it has to keep track of things: a `ForEach` making
//                    a button for each choice, and a `.sheet(item:)`
//                    deciding which sheet is open.
//

import Foundation

/// One way of adding a seed packet.
///
/// `: String` gives each case a text form, its "raw value", which for
/// `.camera` is simply "camera". That is what `id` hands back.
enum SeedPacketStart: String, Identifiable, CaseIterable {

    /// Open the camera, photograph the packet and read it.
    case camera
    /// Pick a photo already in the Photos library and read it.
    case library
    /// Fill the form in by hand.
    case typed

    var id: String { rawValue }

    /// The words on the button.
    var title: String {
        switch self {
        case .camera:  return "Photograph the packet"
        case .library: return "Choose a photo of the packet"
        case .typed:   return "Type it in"
        }
    }

    /// The name of Apple's symbol drawn beside the words.
    var symbol: String {
        switch self {
        case .camera:  return "camera"
        case .library: return "photo.on.rectangle"
        case .typed:   return "square.and.pencil"
        }
    }

    /// True for the two ways that read a photo. Those open the packet
    /// scanner. Typing opens the plain form.
    var readsAPhoto: Bool { self != .typed }

    /// The choices to offer, best first.
    ///
    /// A Mac has no camera Windfall can open, and nor does the
    /// simulator, so there the camera is left out and choosing a photo
    /// comes first. `hasCamera` is handed in, not looked up here, so
    /// that a test can ask about both kinds of device.
    static func choices(hasCamera: Bool) -> [SeedPacketStart] {
        hasCamera ? [.camera, .library, .typed] : [.library, .typed]
    }
}
