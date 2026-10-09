import SwiftUI
import PackageDomain

/// Écran principal du module Gérer : revue des doublons et paramètres.
public struct GererView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Label("Doublons — validation explicite et fusion assistée", systemImage: "arrow.triangle.merge")
            Label("Paramètres — clés, veilles, synchronisation, effacement", systemImage: "gearshape")
        }
        .navigationTitle("Gérer")
    }
}
