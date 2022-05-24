// swift-tools-version: 5.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-libp2p-mplex",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "LibP2PMPLEX",
            targets: ["LibP2PMPLEX"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        
        // LibP2P Core Modules
        .package(url: "https://github.com/swift-libp2p/swift-libp2p.git", .upToNextMinor(from: "0.1.0")),
        
        // NIO Test Utils
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "LibP2PMPLEX",
            dependencies: [
                .product(name: "LibP2P", package: "swift-libp2p"),
            ]),
        .testTarget(
            name: "LibP2PMPLEXTests",
            dependencies: [
                "LibP2PMPLEX",
                .product(name: "NIOTestUtils", package: "swift-nio"),
            ]),
    ]
)
