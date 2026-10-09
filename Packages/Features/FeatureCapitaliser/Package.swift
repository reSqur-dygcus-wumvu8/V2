// swift-tools-version:5.10
import PackageDescription

/// FeatureCapitaliser : traitement des veilles, regroupement par événements,
/// base de connaissance, NER et cotation assistée.
let package = Package(
    name: "FeatureCapitaliser",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "FeatureCapitaliser", targets: ["FeatureCapitaliser"])
    ],
    dependencies: [
        .package(path: "../../PackageDomain"),
        .package(path: "../../PackagePersistence"),
        .package(path: "../../PackageIntelligence")
    ],
    targets: [
        .target(
            name: "FeatureCapitaliser",
            dependencies: [
                .product(name: "PackageDomain", package: "PackageDomain"),
                .product(name: "PackagePersistence", package: "PackagePersistence"),
                .product(name: "PackageIntelligence", package: "PackageIntelligence")
            ]
        )
    ]
)
