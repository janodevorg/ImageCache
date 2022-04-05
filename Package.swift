// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "ImageCache",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "ImageCache", type: .dynamic, targets: ["ImageCache"]),
        .library(name: "ImageCacheStatic", type: .static, targets: ["ImageCache"])
    ],
    dependencies: [
        .package(url: "git@github.com:apple/swift-docc-plugin.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "ImageCache",
            dependencies: [],
            path: "sources/main"
        ),
        .testTarget(
            name: "ImageCacheTests",
            dependencies: ["ImageCache"],
            path: "sources/tests"
        )
    ]
)
