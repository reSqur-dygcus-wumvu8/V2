// swift-tools-version:5.10
import PackageDescription

/// Package Intelligence : client du proxy Mistral (résumé, NER, cotation
/// assistée, embeddings). La clé API ne quitte jamais le serveur proxy.
let package = Package(
    name: "PackageIntelligence",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PackageIntelligence", targets: ["PackageIntelligence"])
    ],
    dependencies: [
        .package(path: "../PackageDomain")
    ],
    targets: [
        .target(
            name: "PackageIntelligence",
            dependencies: [.product(name: "PackageDomain", package: "PackageDomain")]
        ),
        .testTarget(
            name: "PackageIntelligenceTests",
            dependencies: ["PackageIntelligence"],
            path: "Tests/PackageIntelligenceTests"
        )
    ]
)
