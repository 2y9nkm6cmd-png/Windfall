//
//  SpeciesEye.swift
//  Windfall
//
//  Naming what is in a photo: the parts that need Apple's frameworks.
//
//  SpeciesTable.swift has the arithmetic and explains the three steps.
//  This file does the two jobs that cannot be done without the system:
//
//    - reading a photo and drawing it small (Core Graphics and ImageIO,
//      which are on every Apple device)
//    - running BioCLIP 2's image model (Core AI, which is on a Mac and
//      on a real iPhone or iPad from version 27, and is missing from
//      the iOS Simulator)
//
//  Three files have to be in Windfall's Models folder, in a folder
//  called "bioclip2":
//
//    bioclip2_image_f16.aimodel   the model, 580MB
//    uk_species.json              the list of species
//    uk_species_rows_f16.bin      one row of numbers for each
//
//  Nothing is sent anywhere. The photo never leaves the device.
//

import Foundation
import CoreGraphics
import ImageIO

// Core AI is only brought in where it exists. `arch(arm64)` means
// "Apple's own chips": the model's numbers use a type, Float16, that
// Swift does not have on older Intel Macs.
#if canImport(CoreAI) && arch(arm64)
import CoreAI
#endif

// MARK: - Where the pieces are

enum SpeciesEyeFiles {
    nonisolated static let folderName = "bioclip2"
    nonisolated static let modelName = "bioclip2_image_f16.aimodel"
    nonisolated static let listName = "uk_species.json"
    nonisolated static let rowsName = "uk_species_rows_f16.bin"

    nonisolated static func folder() -> URL {
        EiraModelLibrary.modelsFolderPath()
            .appendingPathComponent(folderName, isDirectory: true)
    }

    /// The names of any of the three pieces that are not there yet.
    nonisolated static func missing(fileManager: FileManager = .default) -> [String] {
        [modelName, listName, rowsName].filter {
            !fileManager.fileExists(atPath: folder().appendingPathComponent($0).path)
        }
    }
}

enum SpeciesEyeError: LocalizedError {
    case notInstalled([String])
    case needsNewerSystem
    case photoUnreadable
    case modelFailed(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled(let names):
            return "Photo identification is not set up on this device yet. Missing from the Models folder: \(names.joined(separator: ", ")). You can still save the photo as a sighting and identify it yourself."
        case .needsNewerSystem:
            return "Photo identification needs iOS 27, iPadOS 27 or macOS 27 on one of Apple's own chips. It cannot run in the iOS Simulator."
        case .photoUnreadable:
            return "That photo could not be read."
        case .modelFailed(let why):
            return "The identification model could not be used: \(why)"
        }
    }
}

// MARK: - The eye

/// Looks at a photo and says which species it most resembles.
///
/// One shared copy, so the model is loaded once and kept. `unload()`
/// lets go of it when memory is wanted for something else.
@MainActor
final class SpeciesEye {

    static let shared = SpeciesEye()

    private(set) var table: SpeciesTable?
    /// Turns a prepared photo into the model's 768 numbers. It is made
    /// when the model is first loaded, by whichever code knows how.
    private var describe: (([Float]) async throws -> [Float])?

    /// The whole job: photo in, guess out.
    func guess(forPhoto data: Data) async throws -> SpeciesGuess {
        guard let picture = SpeciesEye.picture(from: data),
              let prepared = SpeciesEye.prepared(picture) else {
            throw SpeciesEyeError.photoUnreadable
        }
        try await loadIfNeeded()
        guard let describe, let table else { throw SpeciesEyeError.needsNewerSystem }
        let photoNumbers = try await describe(prepared)
        return table.guess(for: photoNumbers)
    }

    /// Frees the memory the model and the table are using.
    func unload() {
        describe = nil
        table = nil
    }

    private func loadIfNeeded() async throws {
        if describe != nil, table != nil { return }

        let absent = SpeciesEyeFiles.missing()
        guard absent.isEmpty else { throw SpeciesEyeError.notInstalled(absent) }

        let folder = SpeciesEyeFiles.folder()
        let listing = try Data(contentsOf: folder.appendingPathComponent(SpeciesEyeFiles.listName))
        let rowBytes = try Data(contentsOf: folder.appendingPathComponent(SpeciesEyeFiles.rowsName))
        table = try SpeciesTable(listing: listing, rowBytes: rowBytes)

        #if canImport(CoreAI) && arch(arm64)
        if #available(iOS 27.0, macOS 27.0, *) {
            describe = try await SpeciesEye.loadModel(
                at: folder.appendingPathComponent(SpeciesEyeFiles.modelName))
            return
        }
        #endif
        throw SpeciesEyeError.needsNewerSystem
    }

    // MARK: Reading and shrinking a photo

    /// Opens a photo from its file bytes, the right way up.
    ///
    /// A phone stores a photo as the camera saw it, with a note saying
    /// which way up to show it. `WithTransform` applies that note. It is
    /// also read at no more than `longestSide` pixels, because a full
    /// 12 megapixel photo is slow to open and is about to be shrunk to
    /// 224 anyway.
    nonisolated static func picture(from data: Data, longestSide: Int = 1024) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: longestSide
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Cuts out the middle square, draws it at 224 by 224 and hands the
    /// pixels to PhotoArithmetic to be laid out for the model.
    nonisolated static func prepared(_ picture: CGImage) -> [Float]? {
        let side = PhotoArithmetic.side
        let square = PhotoArithmetic.middleSquare(width: picture.width, height: picture.height)
        guard square.side > 0,
              let cropped = picture.cropping(
                to: CGRect(x: square.x, y: square.y, width: square.side, height: square.side)),
              let colours = CGColorSpace(name: CGColorSpace.sRGB),
              // A blank picture in memory: 224 by 224, four bytes a pixel
              // (red, green, blue and one spare).
              let bitmap = CGContext(
                data: nil, width: side, height: side,
                bitsPerComponent: 8, bytesPerRow: side * 4,
                space: colours,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }

        bitmap.interpolationQuality = .high
        bitmap.draw(cropped, in: CGRect(x: 0, y: 0, width: side, height: side))

        guard let memory = bitmap.data else { return nil }
        let byteCount = side * side * 4
        let bytes = [UInt8](UnsafeBufferPointer(
            start: memory.bindMemory(to: UInt8.self, capacity: byteCount), count: byteCount))
        return PhotoArithmetic.planar(fromRGBA: bytes, side: side)
    }

    // MARK: Running the model

    #if canImport(CoreAI) && arch(arm64)

    /// Loads the model and returns a piece of code that runs it.
    ///
    /// A converted model holds one or more "functions". BioCLIP 2's
    /// image half has one, called "main": it takes an array called
    /// "image" (1 photo, 3 colours, 224 by 224) and gives back one
    /// called "embedding" (768 numbers).
    @available(iOS 27.0, macOS 27.0, *)
    private static func loadModel(at url: URL) async throws -> (([Float]) async throws -> [Float]) {
        let model = try await AIModel(contentsOf: url)
        guard let function = try model.loadFunction(named: "main") else {
            throw SpeciesEyeError.modelFailed("it has no function called main")
        }
        // The names are read from the model, with ours as the fallback.
        let inputName = function.descriptor.inputNames.first ?? "image"
        let outputName = function.descriptor.outputNames.first ?? "embedding"

        return { prepared in
            let side = PhotoArithmetic.side
            // NDArray is Core AI's block of numbers with a shape. This
            // model was converted at half precision, so it wants Float16.
            let input = NDArray(scalars: prepared.map { Float16($0) }, shape: [1, 3, side, side])
            var outputs = try await function.run(inputs: [inputName: input])
            guard let result = outputs.remove(outputName)?.ndArray else {
                throw SpeciesEyeError.modelFailed("it gave nothing back")
            }
            let found = floats(from: result)
            guard !found.isEmpty else {
                throw SpeciesEyeError.modelFailed("its answer was not in a form Windfall reads")
            }
            return found
        }
    }

    /// Copies a one-row result out of Core AI's array as plain Floats.
    ///
    /// `strides` says how far apart neighbouring numbers sit in memory,
    /// which is not always 1, so each is fetched by its own position.
    @available(iOS 27.0, macOS 27.0, *)
    private static func floats(from array: NDArray) -> [Float] {
        let count = array.shape.reduce(1, *)
        let step = array.strides.last ?? 1
        var result = [Float](repeating: 0, count: count)

        switch array.scalarType {
        case .float16:
            array.view(as: Float16.self).withUnsafePointer { pointer, _, _ in
                for index in 0..<count { result[index] = Float(pointer[index * step]) }
            }
        case .float32:
            array.view(as: Float.self).withUnsafePointer { pointer, _, _ in
                for index in 0..<count { result[index] = pointer[index * step] }
            }
        default:
            return []
        }
        return result
    }

    #endif
}
