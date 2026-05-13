// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Orchestra",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Orchestra", targets: ["Orchestra"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.13.0")
    ],
    targets: [
        .executableTarget(
            name: "Orchestra",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            resources: [
                .copy("Resources/AppIcon.png"),
                .copy("Resources/AppIcon.svg")
            ]
        ),
        .testTarget(
            name: "OrchestraTests",
            dependencies: ["Orchestra"]
        )
    ]
)
