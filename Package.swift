// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftXMLRPC",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "SwiftXMLRPC",
            targets: ["SwiftXMLRPC"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/davedufresne/SwiftParsec", from: "4.0.1"),
        // Dev deps
        .package(url: "https://github.com/typelift/SwiftCheck", from: "0.12.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "SwiftXMLRPC",
            dependencies: [
                "SwiftParsec",
            ]
        ),
        .testTarget(
            name: "SwiftXMLRPCTests",
            dependencies: [
                "SwiftXMLRPC",
                "SwiftCheck",
            ]
        ),
    ]
)
