// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "MRZParser",
    products: [
        .library(
            name: "MRZParser",
            targets: ["MRZParser"]),
    ],
    targets: [
        .target(
            name: "MRZParser",
            dependencies: []),
        .testTarget(
            name: "MRZParserIntegrationTests",
            dependencies: ["MRZParser"]),
    ]
)
