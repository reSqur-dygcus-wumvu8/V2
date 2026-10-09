import SwiftUI
import PackageDomain

/// Entrée principale de la page d'accueil.
public enum EntreePrincipale: String, CaseIterable {
    case acquerir
    case capitaliser
    case exploiter
    case gerer

    public var titre: String {
        switch self {
        case .acquerir: return "Acquérir"
        case .capitaliser: return "Capitaliser"
        case .exploiter: return "Exploiter"
        case .gerer: return "Gérer"
        }
    }

    public var sousTitre: String {
        switch self {
        case .acquerir: return "Importer et collecter des informations"
        case .capitaliser: return "Structurer les informations dans la base de connaissance"
        case .exploiter: return "Consulter, analyser et visualiser"
        case .gerer: return "Administration, doublons, paramètres"
        }
    }

    public var systemImage: String {
        switch self {
        case .acquerir: return "square.and.arrow.down"
        case .capitaliser: return "books.vertical"
        case .exploiter: return "point.3.connected.trianglepath.dotted"
        case .gerer: return "gearshape"
        }
    }
}

/// Page d'accueil : grille adaptative des quatre modules.
public struct AccueilView: View {
    @State private var selection: EntreePrincipale?

    public init() {}

    public var body: some View {
        NavigationSplitView {
            List(EntreePrincipale.allCases, selection: $selection) { entree in
                Label(entree.titre, systemImage: entree.systemImage)
                    .tag(entree)
            }
            .navigationTitle("OSINT Suite")
        } detail: {
            grilleEntrees
        }
    }

    /// Grille adaptative : LazyVGrid dont le nombre de colonnes s'adapte
    /// à la largeur disponible (compact : 2 colonnes, régulier : 4).
    private var grilleEntrees: some View {
        GeometryReader { geo in
            let colonnes = max(2, Int(geo.size.width / 220))
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: colonnes), spacing: 16) {
                    ForEach(EntreePrincipale.allCases, id: \.self) { entree in
                        CarteEntree(entree: entree)
                    }
                }
                .padding()
            }
        }
    }
}

/// Carte cliquable d'une entrée principale.
struct CarteEntree: View {
    let entree: EntreePrincipale

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: entree.systemImage)
                .font(.system(size: 32))
                .foregroundStyle(.tint)
            Text(entree.titre)
                .font(.title2.bold())
            Text(entree.sousTitre)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
