// swift-tools-version:5.10
import PackageDescription

/// FeatureHome : page d'accueil — grille adaptative des quatre entrées
/// principales (Acquérir, Capitaliser, Exploiter, Gérer).
let package = Package(
    name: "FeatureHome",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "FeatureHome", targets: ["FeatureHome"])
    ],
    dependencies: [
        .package(path: "../../PackageDomain")
    ],
    targets: [
        .target(
            name: "FeatureHome",
            dependencies: [.product(name: "PackageDomain", package: "PackageDomain")]
        )
    ]
)
