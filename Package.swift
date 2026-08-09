// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "LidGuard",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "LidGuardCore", targets: ["LidGuardCore"]),
        .executable(name: "LidGuardHelper", targets: ["LidGuardHelper"]),
        .executable(name: "lidguard", targets: ["LidGuardCLI"]),
        .executable(name: "LidGuardApp", targets: ["LidGuardApp"]),
        .executable(name: "lidguard-tests", targets: ["LidGuardTests"]),
    ],
    targets: [
        .target(
            name: "LidGuardCore"
        ),
        .target(
            name: "LidGuardHelperKit",
            dependencies: ["LidGuardCore"],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("Security"),
            ]
        ),
        .executableTarget(
            name: "LidGuardHelper",
            dependencies: ["LidGuardHelperKit"]
        ),
        .executableTarget(
            name: "LidGuardCLI",
            dependencies: ["LidGuardCore"]
        ),
        .executableTarget(
            name: "LidGuardApp",
            dependencies: ["LidGuardCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("UserNotifications"),
            ]
        ),
        .executableTarget(
            name: "LidGuardTests",
            dependencies: ["LidGuardCore", "LidGuardHelperKit"]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
