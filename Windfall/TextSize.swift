//
//  TextSize.swift
//  Windfall
//
//  The sizes a page can be shown at on a Mac, and the sum for stepping
//  between them with Command and plus or minus.
//
//  Nothing here draws anything, so it can be tested without a screen.
//  The drawing is in PageZoom.swift.
//

import Foundation

enum TextSize {

    /// The sizes on offer, as a multiple of the normal size.
    static let steps: [Double] = [0.85, 1, 1.15, 1.3, 1.5, 1.75]

    /// The normal size.
    static let normal = 1.0

    /// The size one step up (+1) or down (-1) from `size`, stopping at
    /// either end. A size that is not one of the steps, which a later
    /// version of the app might leave behind, moves to the nearest step
    /// in the direction asked.
    static func stepped(from size: Double, by amount: Int) -> Double {
        guard amount != 0 else { return size }
        if amount > 0 {
            return steps.first { $0 > size + 0.001 } ?? steps[steps.count - 1]
        }
        return steps.last { $0 < size - 0.001 } ?? steps[0]
    }

    /// "115%", for the menu.
    static func percent(_ size: Double) -> String {
        "\(Int((size * 100).rounded()))%"
    }
}
