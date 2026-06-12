// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WhoopProtocol",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "WhoopProtocol", targets: ["WhoopProtocol"])
    ],
    targets: [
        .target(name: "WhoopProtocol"),
        .testTarget(name: "WhoopProtocolTests", dependencies: ["WhoopProtocol"])
    ]
)
