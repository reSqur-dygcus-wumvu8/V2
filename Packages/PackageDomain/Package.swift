// swift-tools-version:5.10
import PackageDescription

/// Package Domain : entités métier, cotations OTAN et règles.
/// Aucune dépendance externe — couche la plus basse du monorepo.
let package = Package(
    name: "PackageDomain",
    products: [
        .library(name: "PackageDomain", targets: ["PackageDomain"])
    ],
    targets: [
        .target(name: "PackageDomain"),
        .testTarget(name: "PackageDomainTests", dependencies: ["PackageDomain"])
    ]
)
