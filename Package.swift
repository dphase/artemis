// swift-tools-version: 6.0
// This Package.swift exists solely to run unit tests via `swift test`
// on macOS when the iOS simulator runtime doesn't match the Xcode SDK version.
// The actual app is built via project.yml + xcodegen.

import PackageDescription

let package = Package(
    name: "Artemis",
    platforms: [.macOS(.v14), .iOS(.v17)],
    targets: [
        .target(
            name: "Artemis",
            path: "Artemis",
            exclude: ["Info.plist"],
            sources: ["Data/MissionTimeline.swift",
                       "Data/TrajectoryInterpolator.swift",
                       "Data/EphemerisProvider.swift"]
        ),
        .testTarget(
            name: "ArtemisLogicTests",
            dependencies: ["Artemis"],
            path: "ArtemisLogicTests"
        ),
    ]
)
