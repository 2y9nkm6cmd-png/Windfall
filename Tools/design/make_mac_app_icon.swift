// make_mac_app_icon.swift
//
// Makes the Mac's app icon from the square picture the iPhone and iPad use.
//
// WHY THE MAC NEEDS ITS OWN
// An iPhone is given a plain square picture and rounds the corners itself.
// A Mac does not: it shows the picture as it is given. So a Mac icon has to
// arrive already cut to a rounded square, with clear space left all round it,
// which is why every Mac icon in the Dock looks a little smaller than its tile.
// A Mac also wants the picture at ten sizes, from 16 dots (a list in Finder)
// up to 1024 (the Dock on a sharp screen), where an iPhone wants one.
//
// HOW TO RUN IT, from the top of the repository:
//
//   swift Tools/design/make_mac_app_icon.swift \
//     Windfall/Assets.xcassets/AppIcon.appiconset/windfall-app-icon-light-1024.png \
//     Windfall/Assets.xcassets/AppIcon.appiconset
//
// It writes windfall-app-icon-mac-16.png, -32, -64, -128, -256, -512 and -1024
// into the folder named second. Contents.json in that folder says which
// picture fills which slot.

import SwiftUI
import ImageIO
import UniformTypeIdentifiers

// Apple's measurements for a Mac icon, on a 1024 dot canvas:
// the rounded square is 824 dots across, so 100 dots are left clear each side.
let canvas: CGFloat = 1024
let tile: CGFloat = 824
let cornerRadius: CGFloat = 185.4

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    print("usage: swift make_mac_app_icon.swift <square picture.png> <folder to write into>")
    exit(1)
}
let sourceURL = URL(fileURLWithPath: arguments[1])
let folder = URL(fileURLWithPath: arguments[2])

// Read the square picture.
guard let reader = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let square = CGImageSourceCreateImageAtIndex(reader, 0, nil) else {
    print("Could not read \(sourceURL.path)")
    exit(1)
}

/// Draws the icon `side` dots across: clear all over, then the square picture
/// shrunk into the middle and cut to a rounded square.
func macIcon(side: Int) -> CGImage? {
    guard let page = CGContext(
        data: nil, width: side, height: side,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        // "premultipliedLast" gives the picture a see-through layer,
        // which the clear margin needs.
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    page.interpolationQuality = .high

    // Every measurement is scaled from the 1024 canvas down to this size.
    let scale = CGFloat(side) / canvas
    let margin = (canvas - tile) / 2 * scale
    let box = CGRect(x: margin, y: margin, width: tile * scale, height: tile * scale)

    // ".continuous" is Apple's own corner: it eases into the straight edge,
    // where a plain rounded corner is a quarter circle.
    let shape = RoundedRectangle(cornerRadius: cornerRadius * scale, style: .continuous)
        .path(in: box).cgPath
    page.addPath(shape)
    page.clip()                 // nothing is drawn outside the shape from here on
    page.draw(square, in: box)
    return page.makeImage()
}

for side in [16, 32, 64, 128, 256, 512, 1024] {
    let file = folder.appendingPathComponent("windfall-app-icon-mac-\(side).png")
    guard let picture = macIcon(side: side),
          let writer = CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        print("Could not make the \(side) dot picture")
        exit(1)
    }
    CGImageDestinationAddImage(writer, picture, nil)
    guard CGImageDestinationFinalize(writer) else {
        print("Could not write \(file.path)")
        exit(1)
    }
    print("wrote \(file.lastPathComponent)")
}
