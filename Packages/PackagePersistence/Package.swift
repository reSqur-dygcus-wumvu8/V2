// swift-tools-version:5.10
import PackageDescription

/// Package Persistence : base GRDB chiffrée SQLCipher, migrations, FTS,
/// accès trousseau Keychain. Testable sans interface graphique.
let package = Package(
    name: "PackagePersistence",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PackagePersistence", targets: ["PackagePersistence"])
    ],
    dependencies: [
        // GRDB avec SQLCipher intégré : chiffrement de la base au repos.
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.29.0"),
        // Domain local (entités, cotations, règles métier).
        .package(path: "../PackageDomain")
    ],
    targets: [
        .target(
            name: "PackagePersistence",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "PackageDomain", package: "PackageDomain")
            ]
        ),
        .testTarget(
            name: "PackagePersistenceTests",
            dependencies: ["PackagePersistence"]
        )
    ]
)
