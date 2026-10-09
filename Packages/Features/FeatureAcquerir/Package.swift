// swift-tools-version:5.10
import PackageDescription

/// FeatureAcquerir : import de fichiers (local/URL) et veilles internet.
let package = Package(
    name: "FeatureAcquerir",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "FeatureAcquerir", targets: ["FeatureAcquerir"])
    ],
    dependencies: [
        .package(path: "../../PackageDomain"),
        .package(path: "../../PackageNetworking")
    ],
    targets: [
        .target(
            name: "FeatureAcquerir",
            dependencies: [
                .product(name: "PackageDomain", package: "PackageDomain"),
                .product(name: "PackageNetworking", package: "PackageNetworking")
            ]
        )
    ]
)
