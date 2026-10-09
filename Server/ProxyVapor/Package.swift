// swift-tools-version:5.10
import PackageDescription

/// Proxy Mistral (Vapor) : détient la clé API Mistral (variable
/// d'environnement MISTRAL_API_KEY, jamais commitée) et relaie les
/// requêtes de l'application. Déployable sur Fly.io / Render / VPS.
let package = Package(
    name: "ProxyVapor",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor", from: "4.89.0")
    ],
    targets: [
        .executableTarget(
            name: "ProxyVapor",
            dependencies: [.product(name: "Vapor", package: "vapor")]
        )
    ]
)
