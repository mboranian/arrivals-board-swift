// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ArrivalsBoard",
    dependencies: [.package(url: "https://github.com/apple/swift-protobuf.git", from: "1.39.0")],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "ArrivalsBoard",
            dependencies: [.product(name: "SwiftProtobuf", package: "swift-protobuf")]),
    ]
)
