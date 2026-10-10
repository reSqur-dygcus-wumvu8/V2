// swift-tools-version:5.10
import PackageDescription

/// PackageMLA : stockage au repos dans des archives chiffrées MLA (ANSSI).
/// Intégration via FFI Rust (xcframework) ; un backend Swift provisoire
/// (AES-GCM par segment) assure le fonctionnement jusqu'à la compilation
/// du xcframework (scripts/build-mla-xcframework.sh).
let package = Package(
    name: "PackageMLA",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PackageMLA", targets: ["PackageMLA"])
    ],
    targets: [
        .target(name: "PackageMLA"),
        .testTarget(
            name: "PackageMLATests",
            dependencies: ["PackageMLA"],
            path: "Tests/PackageMLATests"
        )
    ]
)
