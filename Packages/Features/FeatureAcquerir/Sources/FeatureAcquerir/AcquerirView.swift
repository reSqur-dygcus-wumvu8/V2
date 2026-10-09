import SwiftUI
import PackageDomain
import PackageNetworking

/// Écran principal du module Acquérir : import de fichiers et gestion des veilles.
public struct AcquerirView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Label("Importer des fichiers depuis un dossier local ou une URL internet", systemImage: "square.and.arrow.down")
            Label("Veilles : Google Actualités, flux RSS/Atom, réseaux sociaux", systemImage: "antenna.radiowaves.left.and.right")
        }
        .navigationTitle("Acquérir")
    }
}
