// swift-tools-version:5.10
import PackageDescription

/// Package Networking : connecteurs de veille (RSS, Google News, réseaux
/// sociaux via SocialFeedProvider) et file d'attente des tâches différées.
let package = Package(
    name: "PackageNetworking",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PackageNetworking", targets: ["PackageNetworking"])
    ],
    dependencies: [
        .package(path: "../PackageDomain")
    ],
    targets: [
        .target(
            name: "PackageNetworking",
            dependencies: [.product(name: "PackageDomain", package: "PackageDomain")]
        ),
        .testTarget(
            name: "PackageNetworkingTests",
            dependencies: ["PackageNetworking"],
            path: "Tests/PackageNetworkingTests"
        )
    ]
)
