import SwiftUI
import PackageDomain
import PackagePersistence

/// Écran de revue des doublons proposés : validation ou refus explicite,
/// fusion assistée champ par champ, journal des fusions.
public struct DoublonsView: View {
    @StateObject private var modele: ModeleDoublons

    public init(modele: ModeleDoublons) {
        _modele = StateObject(wrappedValue: modele)
    }

    public var body: some View {
        List {
            Section("Propositions à valider") {
                if modele.propositions.isEmpty {
                    Text("Aucune proposition en attente.").foregroundStyle(.secondary)
                }
                ForEach(modele.propositions) { proposition in
                    LigneProposition(proposition: proposition, modele: modele)
                }
            }
            Section("Journal des fusions") {
                ForEach(modele.fusions) { fusion in
                    VStack(alignment: .leading) {
                        Text(fusion.date, style: .date)
                        Text("Fusion : champs \(fusion.champsChoisis.joined(separator: ", "))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Doublons")
        .onAppear { modele.charger() }
    }
}

struct LigneProposition: View {
    let proposition: PropositionDoublon
    @ObservedObject var modele: ModeleDoublons

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(modele.denomination(id: proposition.idA))
                Image(systemName: "arrow.left.arrow.right")
                Text(modele.denomination(id: proposition.idB))
            }
            Text("Score : \(proposition.score, format: .percent.precision(.fractionLength(0)))")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("C'est un doublon") { modele.valider(proposition) }
                    .buttonStyle(.borderedProminent)
                Button("Ce n'est pas un doublon") { modele.refuser(proposition) }
                    .buttonStyle(.bordered)
            }
            .controlSize(.small)
        }
    }
}

/// Modèle de vue de la revue des doublons (MVVM).
@MainActor
public final class ModeleDoublons: ObservableObject {
    @Published public var propositions: [PropositionDoublon] = []
    @Published public var fusions: [EntreeFusion] = []

    private let entrepotDoublon: EntrepotDoublon
    private let entrepotEntite: EntrepotEntite
    private let service: ServiceDoublons

    public init(
        entrepotDoublon: EntrepotDoublon,
        entrepotEntite: EntrepotEntite,
        service: ServiceDoublons
    ) {
        self.entrepotDoublon = entrepotDoublon
        self.entrepotEntite = entrepotEntite
        self.service = service
    }

    /// Charge propositions et journal, puis relance une passe de détection.
    public func charger() {
        try? service.detecterDoublonsEntites()
        propositions = (try? entrepotDoublon.enAttente()) ?? []
        fusions = (try? entrepotDoublon.journalFusions()) ?? []
    }

    /// Dénomination d'une entité par identifiant (affichage).
    public func denomination(id: UUID) -> String {
        (try? entrepotEntite.chercher(id: id))?.denomination ?? "Inconnu"
    }

    /// Validation explicite : fusion assistée — les champs non vides de
    /// l'absorbée complètent la conservée.
    public func valider(_ proposition: PropositionDoublon) {
        guard let a = try? entrepotEntite.chercher(id: proposition.idA),
              let b = try? entrepotEntite.chercher(id: proposition.idB) else { return }
        // Fusion assistée simple : l'entité A est conservée, les champs non
        // vides de B complètent/complètent A ; l'utilisateur peut raffiner
        // via l'édition de fiche après fusion.
        let champsDepuisB: Set<String> = ["resume", "biographie", "commentaires"]
        do {
            try service.fusionnerEntites(gardee: a, fusionnee: b, champsDepuisFusionnee: champsDepuisB)
            try entrepotDoublon.decider(proposition.id, statut: .valide)
        } catch {
            return
        }
        charger()
    }

    /// Refus explicite : la paire est mémorisée et ne sera plus reproposée.
    public func refuser(_ proposition: PropositionDoublon) {
        try? entrepotDoublon.decider(proposition.id, statut: .refuse)
        charger()
    }
}
