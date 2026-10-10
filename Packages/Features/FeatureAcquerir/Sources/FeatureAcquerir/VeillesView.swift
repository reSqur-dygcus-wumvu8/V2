import SwiftUI
import PackageDomain
import PackageNetworking
import PackagePersistence

/// Gestion des veilles : création/modification/suppression, activation,
/// journal d'exécution. Réglage « collecte / consomme uniquement »
/// documenté dans les paramètres (Étape 5).
public struct VeillesView: View {
    @StateObject private var modele: ModeleVeilles

    public init(modele: ModeleVeilles) {
        _modele = StateObject(wrappedValue: modele)
    }

    public var body: some View {
        List {
            Section("Veilles") {
                ForEach(modele.veilles) { veille in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(veille.titre).bold()
                            Text("\(veille.type.rawValue) — toutes les \(veille.frequenceMinutes) min")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: bindingActivation(veille)).labelsHidden()
                    }
                }
                .onDelete { index in
                    modele.supprimer(at: index)
                }
            }
            if let selection = modele.veilleSelectionnee {
                Section("Journal — \(selection.titre)") {
                    ForEach(modele.journal) { entree in
                        VStack(alignment: .leading) {
                            Text(entree.date, style: .date)
                            Text(entree.message).font(.caption)
                                .foregroundStyle(entree.succes ? .secondary : .red)
                        }
                    }
                }
            }
            Section {
                Button("Exécuter toutes maintenant") {
                    Task { await modele.executerToutes() }
                }
            }
        }
        .navigationTitle("Veilles")
        .toolbar {
            Button("Ajouter") { modele.nouvelleVeille() }
        }
        .sheet(item: $modele.veilleEditee) { veille in
            EditionVeilleView(veille: veille) { resultat in
                modele.enregistrer(resultat)
            }
        }
    }

    private func bindingActivation(_ veille: Veille) -> Binding<Bool> {
        Binding(
            get: { veille.active },
            set: { modele.activer(veille, actif: $0) }
        )
    }
}

/// Écran de création/modification d'une veille.
struct EditionVeilleView: View {
    @State private var veille: Veille
    let onValider: (Veille) -> Void

    init(veille: Veille, onValider: @escaping (Veille) -> Void) {
        _veille = State(initialValue: veille)
        self.onValider = onValider
    }

    var body: some View {
        Form {
            TextField("Titre", text: $veille.titre)
            Picker("Type", selection: $veille.type) {
                Text("Google Actualités").tag(TypeVeille.googleNews)
                Text("Flux RSS/Atom").tag(TypeVeille.rss)
                Text("Réseau social").tag(TypeVeille.social)
            }
            if veille.type == .googleNews {
                TextField("Mots-clés (séparés par des virgules)", text: motsClesBinding)
                TextField("Langues de recherche (ex. fr, en)", text: languesBinding)
                // Moteurs d'actualités interrogés.
                ForEach(MoteurActu.allCases, id: \.self) { moteur in
                    Toggle(moteur.libelle, isOn: moteurBinding(moteur))
                }
                TextField("Pays de sortie Tor (ex. fr — vide = anonymat maximal)", text: Binding(
                    get: { veille.paysSortie ?? "" },
                    set: { veille.paysSortie = $0.isEmpty ? nil : $0.lowercased() }
                ))
                if veille.paysSortie != nil {
                    Text("⚠️ Restreindre le pays de sortie RÉDUIT votre anonymat (ensemble de nœuds plus petit, corrélation facilitée).")
                        .font(.caption).foregroundStyle(.red)
                }
            }
            if veille.type == .rss {
                TextField("URL du flux", text: Binding(
                    get: { veille.urlSource ?? "" },
                    set: { veille.urlSource = $0 }
                ))
            }
            Stepper("Fréquence : \(veille.frequenceMinutes) min", value: $veille.frequenceMinutes, in: 5...1440, step: 5)
            TextField("Mots-clés de priorité (alertes)", text: motsClesPrioriteBinding)
        }
        .navigationTitle("Veille")
        .toolbar {
            Button("Enregistrer") { onValider(veille) }
        }
    }

    private var motsClesBinding: Binding<String> {
        Binding(
            get: { veille.motsCles.joined(separator: ", ") },
            set: { veille.motsCles = $0.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        )
    }

    private var languesBinding: Binding<String> {
        Binding(
            get: { (veille.langues ?? ["fr"]).joined(separator: ", ") },
            set: { veille.langues = $0.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty } }
        )
    }

    private func moteurBinding(_ moteur: MoteurActu) -> Binding<Bool> {
        Binding(
            get: { veille.moteurs?.contains(moteur) ?? (moteur == .google) },
            set: { actif in
                var moteurs = veille.moteurs ?? [.google]
                if actif {
                    if !moteurs.contains(moteur) { moteurs.append(moteur) }
                } else {
                    moteurs.removeAll { $0 == moteur }
                }
                veille.moteurs = moteurs
            }
        )
    }

    private var motsClesPrioriteBinding: Binding<String> {
        Binding(
            get: { veille.motsClesPriorite.joined(separator: ", ") },
            set: { veille.motsClesPriorite = $0.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        )
    }
}

/// Modèle de vue des veilles (MVVM), testable avec orchestrateur mocké.
@MainActor
public final class ModeleVeilles: ObservableObject {
    @Published public var veilles: [Veille] = []
    @Published public var journal: [ResultatJournal] = []
    @Published public var veilleSelectionnee: Veille?
    @Published public var veilleEditee: Veille?

    private let entrepotVeille: EntrepotVeille
    private let entrepotElements: EntrepotElementVeille
    private let orchestrateur: OrchestrateurVeille
    private let serviceAlertes: ServiceAlertes

    public init(
        entrepotVeille: EntrepotVeille,
        entrepotElements: EntrepotElementVeille,
        orchestrateur: OrchestrateurVeille,
        serviceAlertes: ServiceAlertes = ServiceAlertes()
    ) {
        self.entrepotVeille = entrepotVeille
        self.entrepotElements = entrepotElements
        self.orchestrateur = orchestrateur
        self.serviceAlertes = serviceAlertes
    }

    /// Recharge les veilles depuis la base.
    public func charger() {
        veilles = (try? entrepotVeille.toutes()) ?? []
    }

    /// Nouvelle veille vierge ouverte en édition.
    public func nouvelleVeille() {
        veilleEditee = Veille(type: .googleNews, titre: "Nouvelle veille")
    }

    /// Enregistre la veille éditée.
    public func enregistrer(_ veille: Veille) {
        try? entrepotVeille.enregistrer(veille)
        charger()
        veilleEditee = nil
    }

    /// Active/désactive une veille.
    public func activer(_ veille: Veille, actif: Bool) {
        var modifiee = veille
        modifiee.active = actif
        try? entrepotVeille.enregistrer(modifiee)
        charger()
    }

    /// Supprime une veille par index.
    public func supprimer(at index: Int) {
        guard veilles.indices.contains(index) else { return }
        try? entrepotVeille.supprimer(veilles[index].id)
        charger()
    }

    /// Sélectionne une veille et charge son journal.
    public func selectionner(_ veille: Veille) {
        veilleSelectionnee = veille
        journal = (try? entrepotVeille.journal(veilleId: veille.id)) ?? []
    }

    /// Exécute toutes les veilles actives (Mac hub ou rafraîchissement manuel).
    public func executerToutes() async {
        let actives = (try? entrepotVeille.actives()) ?? []
        for veille in actives {
            let hashes = (try? entrepotElements.hashesVus(veilleId: veille.id)) ?? []
            let resultat = await orchestrateur.executer(veille: veille, hashesVus: hashes)
            let inseres = (try? entrepotElements.insererNouveaux(resultat.nouveauxElements)) ?? []
            // Alerte locale si un nouvel élément atteint le seuil de priorité.
            await serviceAlertes.evaluer(elements: inseres, veille: veille)
            try? entrepotVeille.journaliser(
                ResultatJournal(
                    veilleId: veille.id,
                    date: resultat.date,
                    succes: resultat.succes,
                    nbNouveaux: resultat.nouveauxElements.count,
                    message: resultat.message
                )
            )
        }
        charger()
    }
}
