// swift-tools-version:5.10
import PackageDescription

/// Package Sync : synchronisation optionnelle CloudKit + fusion CRDT
/// (Automerge) pour les champs texte éditables. Désactivable ; l'app
/// fonctionne sans compte iCloud.
let package = Package(
    name: "PackageSync",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PackageSync", targets: ["PackageSync"])
    ],
    dependencies: [
        .package(path: "../PackageDomain"),
        // CRDT pour fusion sans conflit des champs texte.
        .package(url: "https://github.com/automerge/automerge-swift", from: "0.5.0")
    ],
    targets: [
        .target(
            name: "PackageSync",
            dependencies: [
                .product(name: "PackageDomain", package: "PackageDomain"),
                .product(name: "Automerge", package: "automerge-swift")
            ]
        )
    ]
}
