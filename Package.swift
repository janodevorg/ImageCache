// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "ImageCache",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "ImageCache", type: .dynamic, targets: ["ImageCache"]),
        .library(name: "ImageCacheStatic", type: .static, targets: ["ImageCache"])
    ],
    dependencies: [
        .package(url: "git@github.com:apple/swift-docc-plugin.git", from: "1.4.3")
    ],
    targets: [
        .target(
            name: "ImageCache",
            dependencies: [],
            path: "Sources/Main",
            swiftSettings: [
                 .swiftLanguageMode(.v6)
             ]
        ),
        .testTarget(
            name: "ImageCacheTests",
            dependencies: ["ImageCache"],
            path: "Sources/Tests",
            swiftSettings: [
                 .swiftLanguageMode(.v6)
             ]
        )
    ]
)
