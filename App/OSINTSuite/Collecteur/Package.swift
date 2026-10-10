// swift-tools-version:5.10
import PackageDescription

/// Collecteur Mac hub : exécutable CLI exécuté périodiquement par le
/// LaunchAgent (com.osintsuite.collecteur.plist) — veilles complètes côté
/// Mac, les appareils iOS recevant les résultats par synchronisation.
let package = Package(
    name: "Collecteur",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../../Packages/PackageDomain"),
        .package(path: "../../Packages/PackageNetworking"),
        .package(path: "../../Packages/PackagePersistence"),
        .package(path: "../../Packages/PackageTor")
    ],
    targets: [
        .executableTarget(
            name: "Collecteur",
            dependencies: [
                .product(name: "PackageDomain", package: "PackageDomain"),
                .product(name: "PackageNetworking", package: "PackageNetworking"),
                .product(name: "PackagePersistence", package: "PackagePersistence"),
                .product(name: "PackageTor", package: "PackageTor")
            ]
        )
    ]
)
