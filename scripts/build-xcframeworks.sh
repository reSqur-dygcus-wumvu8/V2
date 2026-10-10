#!/bin/bash
# Compilation des xcframeworks MLA et Arti (Tor) pour macOS et iOS.
# Prérequis : rustup avec les cibles installées :
#   rustup target add aarch64-apple-darwin x86_64-apple-darwin \
#                        aarch64-apple-ios aarch64-apple-ios-sim
#
# Produit : Frameworks/mla.xcframework et Frameworks/tor.xcframework
# à lier aux cibles Xcode (voir docs/XCODE.md).

set -euo pipefail
cd "$(dirname "$0")/.."

RACINE="$(pwd)"
FRAMEWORKS="$RACINE/Frameworks"
mkdir -p "$FRAMEWORKS"

build_statique() {
    local crate="$1" nom="$2"
    echo "==> Compilation $nom ($crate)…"
    (
        cd "$crate"
        for cible in aarch64-apple-darwin x86_64-apple-darwin \
                     aarch64-apple-ios aarch64-apple-ios-sim; do
            echo "    -> $cible"
            cargo build --release --target "$cible"
        done
    )
}

# ---------- MLA (archives chiffrées ANSSI) ----------
build_statique "Packages/PackageMLA/ffi" "mla-ffi"
xcodebuild -create-xcframework \
    -library Packages/PackageMLA/ffi/target/aarch64-apple-darwin/release/libmlaffi.a \
    -library Packages/PackageMLA/ffi/target/x86_64-apple-darwin/release/libmlaffi.a \
    -library Packages/PackageMLA/ffi/target/aarch64-apple-ios/release/libmlaffi.a \
    -library Packages/PackageMLA/ffi/target/aarch64-apple-ios-sim/release/libmlaffi.a \
    -output "$FRAMEWORKS/mla.xcframework"

# ---------- Arti (client Tor) ----------
build_statique "Packages/PackageTor/ffi" "arti-ffi"
xcodebuild -create-xcframework \
    -library Packages/PackageTor/ffi/target/aarch64-apple-darwin/release/libartiffi.a \
    -library Packages/PackageTor/ffi/target/x86_64-apple-darwin/release/libartiffi.a \
    -library Packages/PackageTor/ffi/target/aarch64-apple-ios/release/libartiffi.a \
    -library Packages/PackageTor/ffi/target/aarch64-apple-ios-sim/release/libartiffi.a \
    -output "$FRAMEWORKS/tor.xcframework"

echo ""
echo "XCFrameworks générés dans Frameworks/ :"
ls -d "$FRAMEWORKS"/*.xcframework
echo "Lier mla.xcframework et tor.xcframework aux cibles dans Xcode"
echo "(General > Frameworks, Libraries and Embedded Content), puis activer"
echo "les symboles FFI (carchive_*, arti_client_*) — voir docs/XCODE.md."
