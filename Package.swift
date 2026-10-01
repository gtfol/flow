// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FlowCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "FlowCore", targets: ["FlowCore"])],
    targets: [
        .target(name: "FlowCore", path: "Flow/Core"),
        .testTarget(name: "FlowCoreTests", dependencies: ["FlowCore"], path: "FlowTests")
    ],
    swiftLanguageModes: [.v5]
)
