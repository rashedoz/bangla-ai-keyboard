// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BanglaKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "BanglaKit", targets: ["BanglaKit"]),
    ],
    targets: [
        .target(name: "BanglaKit"),
        .testTarget(name: "BanglaKitTests", dependencies: ["BanglaKit"]),
    ]
)
