// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BetterTouch",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "BetterTouch",
            path: "Sources/BetterTouch",
            swiftSettings: [
                // Keep Swift 5 semantics so CGEventTap C-callbacks and AppKit
                // interop stay ergonomic (no strict-concurrency errors).
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
