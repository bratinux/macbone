// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "macbone",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "macbone"
        ),
    ],
    swiftLanguageModes: [.v6]
)
