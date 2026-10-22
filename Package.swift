// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SideA",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "SideA", targets: ["SideA"])],
    targets: [
        .executableTarget(name: "SideA"),
        .testTarget(name: "SideATests", dependencies: ["SideA"])
    ]
)
