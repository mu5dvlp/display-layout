// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DisplayLayout",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "DisplayLayout", path: "Sources/DisplayLayout")
    ]
)
