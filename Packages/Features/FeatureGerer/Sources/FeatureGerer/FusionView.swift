import SwiftUI
import PackageDomain
import PackagePersistence

/// Fusion assistée champ par champ : avant de fusionner, l'utilisateur
/// choisit pour chaque champ la valeur à conserver (entité A, entité B,
/// ou concaténation pour les commentaires). Historique de fusion conservé.
public struct FusionView: View {
    @StateObject private var modele: ModeleFusion

    public init(modele: ModeleFusion) {
        _modele = StateObject(wrappedValue: modele)
    }

    public var body: some View {
        Form {
            Section("Entités") {
                HStack {
                    VStack(alignment: .leading) {
                        Text(modele.gardee.denomination).bold()
                        Text("Conservée").font(.caption).foregroundStyle(.tint)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                    VStack(alignment: .trailing) {
                        Text(modele.fusionnee.denomination).bold()
                        Text("Absorbée").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Picker("Inverser (conserver l'autre entité)", selection: $modele.inversee) {
                    Text("Garder \(modele.gardee.denomination)").tag(false)
                    Text("Garder \(modele.fusionnee.denomination)").tag(true)
                }
            }

            Section("Choix des champs") {
                ForEach(ModeleFusion.champsFusibles, id: \.self) { champ in
                    LigneChoixChamp(champ: champ, modele: modele)
                }
            }

            Section {
                Button("Fusionner définitivement", role: .destructive) {
                    modele.fusionner()
                }
                .disabled(!modele.champsValides)
                if let message = modele.message {
                    Text(message).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Fusion assistée")
    }
}

struct LigneChoixChamp: View {
    let champ: String
    @ObservedObject var modele: ModeleFusion

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(champ).font(.caption.bold()).foregroundStyle(.secondary)
            Picker("", selection: modele.choixBinding(champ)) {
                Text("Garder A").tag(SourceChamp.gardee)
                Text("Garder B").tag(SourceChamp.fusionnee)
                if champ == "commentaires" {
                    Text("Concaténer").tag(SourceChamp.concat)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            HStack {
                Text(modele.valeur(champ: champ, source: modele.choix[champ] ?? .gardee))
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundStyle(modele.choix[champ] == .fusionnee ? .tint : .primary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Source d'un champ lors de la fusion.
public enum SourceChamp: String, Codable, Sendable, Hashable {
    case gardee
    case fusionnee
    case concat
}

/// Modèle de vue de la fusion (MVVM), testable sans interface graphique.
@MainActor
public final class ModeleFusion: ObservableObject {
    @Published public var choix: [String: SourceChamp] = [:]
    @Published public var inversee = false
    @Published public var message: String?

    public let gardee: Entite
    public let fusionnee: Entite
    private let service: ServiceDoublons
    private let entrepotDoublon: EntrepotDoublon
    private let proposition: PropositionDoublon?

    /// Champs proposés au choix, selon le type des entités.
    public static let champsFusibles = ["denomination", "resume", "biographie", "commentaires"]

    public init(
        gardee: Entite,
        fusionnee: Entite,
        service: ServiceDoublons,
        entrepotDoublon: EntrepotDoublon,
        proposition: PropositionDoublon? = nil
    ) {
        self.gardee = gardee
        self.fusionnee = fusionnee
        self.service = service
        self.entrepotDoublon = entrepotDoublon
        self.proposition = proposition
        // Par défaut : garder les valeurs de l'entité conservée.
        for champ in Self.champsFusibles {
            choix[champ] = .gardee
        }
    }

    /// Choix effectif après inversion éventuelle.
    private var effectiveGardee: Entite { inversee ? fusionnee : gardee }
    private var effectiveFusionnee: Entite { inversee ? gardee : fusionnee }

    /// Validation : au moins un champ choisi.
    public var champsValides: Bool {
        !choix.isEmpty
    }

    /// Binding du choix pour un champ.
    public func choixBinding(_ champ: String) -> Binding<SourceChamp> {
        Binding(
            get: { choix[champ] ?? .gardee },
            set: { choix[champ] = $0 }
        )
    }

    /// Valeur affichée pour un champ selon la source choisie.
    public func valeur(champ: String, source: SourceChamp) -> String {
        switch source {
        case .gardee: return valeur(entite: effectiveGardee, champ: champ) ?? "—"
        case .fusionnee: return valeur(entite: effectiveFusionnee, champ: champ) ?? "—"
        case .concat:
            let a = valeur(entite: effectiveGardee, champ: champ) ?? ""
            let b = valeur(entite: effectiveFusionnee, champ: champ) ?? ""
            return [a, b].filter { !$0.isEmpty }.joined(separator: " / ")
        }
    }

    private func valeur(entite: Entite, champ: String) -> String? {
        switch champ {
        case "denomination": return entite.denomination
        case "resume": return entite.resume
        case "biographie": return entite.biographie
        case "commentaires": return entite.commentaires
        default: return nil
        }
    }

    /// Champs dont la valeur sera prise depuis l'absorbée.
    public var champsDepuisFusionnee: Set<String> {
        Set(choix.filter { $0.value == .fusionnee }.keys)
    }

    /// Champs à concaténer (gérés côté service comme « depuis l'absorbée »,
    /// la concaténation des commentaires est réalisée par le service).
    public var champsConcatenes: Set<String> {
        Set(choix.filter { $0.value == .concat }.keys)
    }

    /// Exécute la fusion selon les choix, journalise, marque la proposition.
    public func fusionner() {
        do {
            var champs = champsDepuisFusionnee
            champs.formUnion(champsConcatenes)
            try service.fusionnerEntites(
                gardee: effectiveGardee,
                fusionnee: effectiveFusionnee,
                champsDepuisFusionnee: champs
            )
            if let proposition = proposition {
                entrepotDoublon.decider(proposition.id, statut: .valide)
            }
            message = "Fusion effectuée : « \(effectiveGardee.denomination) » conservée."
        } catch {
            message = "Erreur de fusion : \(error.localizedDescription)"
        }
    }
}
