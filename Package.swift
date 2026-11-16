// swift-tools-version: 5.9
//
// MenuBarManager is an executable Swift package so it builds with
// `swift build` / `scripts/build-app.sh` and does not need an Xcode project.
// Open Package.swift in Xcode if you want the graphical debugger.

import PackageDescription

let package = Package(
    name: "MenuBarManager",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MenuBarManager", targets: ["MenuBarManager"])
    ],
    targets: [
        .executableTarget(
            name: "MenuBarManager",
            path: "Sources/MenuBarManager",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
