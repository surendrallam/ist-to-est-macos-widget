// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TimeConversionKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TimeConversionKit", targets: ["TimeConversionKit"]),
    ],
    targets: [
        .target(name: "TimeConversionKit"),
        .testTarget(name: "TimeConversionKitTests", dependencies: ["TimeConversionKit"]),
    ]
)
