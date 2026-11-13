// swift-tools-version: 6.0
//
//  WindfallCoreAI
//
//  A small go-between that exists for one reason: to bring Apple's
//  coreai-models package into Windfall on a Mac and nowhere else.
//
//  Why it is needed. Apple's package runs converted models (Qwen and the
//  like) through Core AI. Core AI is on the Mac and on a real iPhone or
//  iPad, but it is missing from the iOS Simulator, so the package cannot
//  be compiled there and the whole simulator build fails. Xcode will not
//  leave a package out for one platform when the app depends on it
//  directly. A package can do that for its own dependencies though, with
//  `condition: .when(platforms:)` below. So Windfall depends on this
//  package, and this package depends on Apple's only on macOS.
//
//  When an iPad is here to test on, add `.iOS` to the list below. The
//  simulator will then need another answer, because a package cannot
//  tell a real iPad from a simulated one.

import PackageDescription

let package = Package(
    name: "WindfallCoreAI",
    // The lowest systems this go-between itself will build for. They
    // must not be higher than the app's own, or Xcode refuses to link it.
    platforms: [.macOS("27.0"), .iOS("26.0")],
    products: [
        .library(name: "WindfallCoreAI", targets: ["WindfallCoreAI"])
    ],
    dependencies: [
        // Pinned to one exact revision, so a change on Apple's side
        // cannot alter the app until we choose to move.
        .package(
            url: "https://github.com/apple/coreai-models",
            revision: "60e8605b9c09f39767234ea31cee2da7d0a11029"
        )
    ],
    targets: [
        .target(
            name: "WindfallCoreAI",
            dependencies: [
                .product(
                    name: "CoreAILM",
                    package: "coreai-models",
                    condition: .when(platforms: [.macOS])
                )
            ]
        )
    ]
)
