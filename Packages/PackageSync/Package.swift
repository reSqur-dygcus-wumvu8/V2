// swift-tools-version:5.10
import PackageDescription

/// PackageSync : synchronisation inter-appareils via dépôt GitHub privé,
/// relevé exclusivement via Tor. Deltas CRDT (Automerge) chiffrés ;
/// désactivable — l'application reste entièrement utilisable sans.
/// CloudKit est exclu (trafic iCloud non routable via Tor).
let package = Package(
    name: "PackageSync",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PackageSync", targets: ["PackageSync"])
    ],
    dependencies: [
        .package(path: "../PackageDomain"),
        .package(path: "../PackageMLA"),
        .package(path: "../PackageTor"),
        .package(url: "https://github.com/automerge/automerge-swift", from: "0.5.0")
    ],
    targets: [
        .target(
            name: "PackageSync",
            dependencies: [
                .product(name: "PackageDomain", package: "PackageDomain"),
                .product(name: "PackageMLA", package: "PackageMLA"),
                .product(name: "PackageTor", package: "PackageTor"),
                .product(name: "Automerge", package: "automerge-swift")
            ]
        ),
        .testTarget(
            name: "PackageSyncTests",
            dependencies: ["PackageSync"],
            path: "Tests/PackageSyncTests"
        )
    ]
)
