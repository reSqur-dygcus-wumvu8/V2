import SwiftUI
import PackageDomain
import PackageNetworking

/// Écran principal du module Acquérir : onglets Import et Veilles.
public struct AcquerirView: View {
    public init() {}

    public var body: some View {
        TabView {
            Text("Importer des fichiers depuis un dossier local ou une URL internet")
                .tabItem { Label("Importer", systemImage: "square.and.arrow.down") }
            Text("Veilles : Google Actualités, flux RSS/Atom, réseaux sociaux")
                .tabItem { Label("Veilles", systemImage: "antenna.radiowaves.left.and.right") }
        }
        .navigationTitle("Acquérir")
    }
}
