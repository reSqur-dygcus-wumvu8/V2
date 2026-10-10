// swift-tools-version:5.10
import PackageDescription

/// PackageTor : client Tor Arti embarqué (FFI Rust, xcframework) exposant
/// un proxy SOCKS5 local 127.0.0.1. Aucune requête de l'application ne doit
/// sortir hors de ce proxy ; la résolution DNS passe par Tor.
let package = Package(
    name: "PackageTor",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PackageTor", targets: ["PackageTor"])
    ],
    targets: [
        .target(name: "PackageTor"),
        .testTarget(
            name: "PackageTorTests",
            dependencies: ["PackageTor"],
            path: "Tests/PackageTorTests"
        )
    ]
)
