// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Geotagger",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Geotagger",
            targets: ["Geotagger"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vincentneo/CoreGPX", .upToNextMinor(from: "0.9.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(name: "CLI",
                          dependencies: ["Geotagger"]),
        .target(
            name: "Geotagger",
            dependencies: [
                "CoreGPX"
            ]),
        .testTarget(
            name: "GeotaggerTests",
            dependencies: ["Geotagger"]),
    ]
)
