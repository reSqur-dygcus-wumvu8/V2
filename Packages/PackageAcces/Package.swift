// swift-tools-version:5.10
import PackageDescription

/// PackageAcces : modèle de chiffrement à deux niveaux (KEK/DEK) du
/// Gestionnaire d'accès. Les primitives cryptographiques pures sont
/// testables sans interface graphique ni Secure Enclave (mock injectable).
let package = Package(
    name: "PackageAcces",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PackageAcces", targets: ["PackageAcces"])
    ],
    targets: [
        .target(name: "PackageAcces"),
        .testTarget(
            name: "PackageAccesTests",
            dependencies: ["PackageAcces"],
            path: "Tests/PackageAccesTests"
        )
    ]
)
