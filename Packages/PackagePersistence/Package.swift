// swift-tools-version:5.10
import PackageDescription

/// PackagePersistence : moteur de stockage sur archives chiffrées MLA.
/// Jeu de travail en mémoire (index, recherche plein texte, graphe) +
/// consolidation des archives MLA à la mise au repos. Les API d'entrepôts
/// (Entite, Document, Veille, ElementVeille, Doublon…) sont conservées.
let package = Package(
    name: "PackagePersistence",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PackagePersistence", targets: ["PackagePersistence"])
    ],
    dependencies: [
        .package(path: "../PackageDomain"),
        .package(path: "../PackageMLA")
    ],
    targets: [
        .target(
            name: "PackagePersistence",
            dependencies: [
                .product(name: "PackageDomain", package: "PackageDomain"),
                .product(name: "PackageMLA", package: "PackageMLA")
            ]
        ),
        .testTarget(
            name: "PackagePersistenceTests",
            dependencies: ["PackagePersistence"],
            path: "Tests/PackagePersistenceTests"
        )
    ]
)
