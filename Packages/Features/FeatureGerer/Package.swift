// swift-tools-version:5.10
import PackageDescription

/// FeatureGerer : doublons (validation explicite, fusion assistée) et paramètres.
let package = Package(
    name: "FeatureGerer",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "FeatureGerer", targets: ["FeatureGerer"])
    ],
    dependencies: [
        .package(path: "../../PackageDomain"),
        .package(path: "../../PackagePersistence"),
        .package(path: "../../PackageTor")
    ],
    targets: [
        .target(
            name: "FeatureGerer",
            dependencies: [
                .product(name: "PackageDomain", package: "PackageDomain"),
                .product(name: "PackagePersistence", package: "PackagePersistence"),
                .product(name: "PackageTor", package: "PackageTor")
            ]
        ),
        .testTarget(
            name: "FeatureGererTests",
            dependencies: ["FeatureGerer"],
            path: "Tests/FeatureGererTests"
        )
    ]
)
