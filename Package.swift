// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "AppCarol",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "AppCarol"),
    ]
)
