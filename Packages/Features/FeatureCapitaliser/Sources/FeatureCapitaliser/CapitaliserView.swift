import SwiftUI
import PackageDomain

/// Écran principal du module Capitaliser : file d'attente de la veille
/// et base de connaissance.
public struct CapitaliserView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Label("File d'attente de la veille — regroupement par événements", systemImage: "tray.and.arrow.down")
            Label("Base de connaissance — individus, organisations, événements, lieux, objets, sources", systemImage: "books.vertical")
        }
        .navigationTitle("Capitaliser")
    }
}
