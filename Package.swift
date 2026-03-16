// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MusicAppSwift",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "MusicAppSwift",
            targets: ["MusicAppSwift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "MusicAppSwift",
            dependencies: [
                "SwiftSoup"
            ],
            path: "MusicAppSwift")
    ]
)
