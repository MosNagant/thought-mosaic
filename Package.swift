// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MosaicCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "MosaicCore", targets: ["MosaicCore"])],
    targets: [
        .target(name: "MosaicCore"),
        .testTarget(name: "MosaicCoreTests", dependencies: ["MosaicCore"])
    ]
)
