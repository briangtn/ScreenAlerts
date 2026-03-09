// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ScreenAlert",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ScreenAlert",
            path: "Sources",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ],
            linkerSettings: [
                .linkedFramework("EventKit"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
