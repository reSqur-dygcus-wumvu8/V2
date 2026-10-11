import SwiftUI
import PackageDomain
import PackageIntelligence
import PackagePersistence

/// Mode découverte : saisie d'une thématique, estimation du coût Mistral
/// (confirmation obligatoire), lancement de la boucle de réflexion,
/// affichage de la synthèse, sources cotées à valider, création des
/// veilles en un clic, enregistrement de la synthèse comme document.
public struct DecouverteView: View {
    @StateObject private var modele: ModeleDecouverte

    public init(modele: ModeleDecouverte) {
        _modele = StateObject(wrappedValue: modele)
    }

    public var body: some View {
        Form {
            Section("Thématique à explorer") {
                TextField("Ex. : convois logistiques en Europe de l'Est", text: $modele.thematique, axis: .vertical)
                    .lineLimit(3)
                if !modele.thematique.isEmpty {
                    Text("Estimation : ~\(ServiceDecouverte.estimationAppels(thematique: modele.thematique)) appels Mistral.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button("Lancer la découverte") {
                    Task { await modele.lancer() }
                }
                .disabled(modele.thematique.trimmingCharacters(in: .whitespaces).isEmpty || modele.enCours)
                if modele.enCours {
                    HStack { ProgressView(); Text("Recherche itérative en cours…").font(.caption) }
                }
                if let message = modele.message {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }

            if let resultat = modele.resultat {
                Section("Synthèse") {
                    Text(resultat.synthese)
                        .textSelection(.enabled)
                    Button("Enregistrer comme document") { modele.enregistrerSynthese() }
                }
                Section("Sources citées — cotation à valider") {
                    ForEach(resultat.sources) { source in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(source.titre).bold()
                                Text(source.url).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(source.cotationProposee?.rawValue ?? "?")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                Section("Sources d'intérêt — créer des veilles en un clic") {
                    ForEach(resultat.sourcesInteret) { source in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(source.libelle).bold()
                                Text("\(source.genre.rawValue) — \(source.url)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Créer la veille") { modele.creerVeille(depuis: source) }
                                .controlSize(.small)
                        }
                    }
                }
            }
        }
        .navigationTitle("Découvrir")
    }
}

/// Modèle de vue du mode découverte (MVVM), testable sans interface.
@MainActor
public final class ModeleDecouverte: ObservableObject {
    @Published public var thematique = ""
    @Published public var enCours = false
    @Published public var resultat: ServiceDecouverte.ResultatDecouverte?
    @Published public var message: String?
    @Published public var veillesCreees = 0

    private let service: ServiceDecouverte
    private let entrepotVeille: EntrepotVeille?
    private let entrepotDocument: EntrepotDocument?
    private let entrepotSource: EntrepotSource?

    public init(
        service: ServiceDecouverte,
        entrepotVeille: EntrepotVeille? = nil,
        entrepotDocument: EntrepotDocument? = nil,
        entrepotSource: EntrepotSource? = nil
    ) {
        self.service = service
        self.entrepotVeille = entrepotVeille
        self.entrepotDocument = entrepotDocument
        self.entrepotSource = entrepotSource
    }

    /// Estimation d'appels affichée à l'utilisateur (confirmation implicite
    /// par le bouton Lancer).
    public var estimation: Int {
        ServiceDecouverte.estimationAppels(thematique: thematique)
    }

    /// Lance la boucle de réflexion Mistral sur la thématique saisie.
    public func lancer() async {
        let theme = thematique.trimmingCharacters(in: .whitespaces)
        guard !theme.isEmpty, !enCours else { return }
        enCours = true
        resultat = await service.decouvrir(thematique: theme)
        enCours = false
        message = resultat == nil
            ? "Découverte indisponible (proxy Mistral hors ligne ?)."
            : "Découverte terminée : \(resultat!.sources.count) source(s), \(resultat!.sourcesInteret.count) source(s) d'intérêt."
    }

    /// Crée la veille pré-remplie correspondant à une source d'intérêt.
    public func creerVeille(depuis source: ServiceDecouverte.SourceInteret) {
        guard let entrepotVeille else {
            message = "Veilles non disponibles (app verrouillée ?)."
            return
        }
        entrepotVeille.enregistrer(ServiceDecouverte.veilleProposee(depuis: source))
        veillesCreees += 1
        message = "Veille créée : \(source.libelle)."
    }

    /// Enregistre la synthèse comme document (capitalisable comme tout
    /// document, entités créables par clic droit).
    public func enregistrerSynthese() {
        guard let resultat, let entrepotDocument, let entrepotSource else {
            message = "Enregistrement indisponible (app verrouillée ?)."
            return
        }
        let source = SourceInfo(denomination: "Découverte — \(resultat.thematique)", cotation: .c)
        entrepotSource.enregistrer(source)
        let document = Document(
            nom: "Découverte — \(resultat.thematique)",
            typeMime: "text/markdown",
            hashSHA256: OrchestrateurHash.texte(resultat.synthese),
            texteExtrait: resultat.synthese,
            sourceId: source.id
        )
        _ = entrepotDocument.inserer(document)
        message = "Synthèse enregistrée comme document."
    }
}

/// Accès au hash depuis FeatureAcquerir sans dépendre du package
/// Networking (l'entrepôt document attend un hash SHA-256).
enum OrchestrateurHash {
    /// Hash simple déterministe pour les documents de découverte (la
    /// déduplication ne requiert pas la crypto réseau).
    static func texte(_ texte: String) -> String {
        var h: UInt64 = 0xcbf29ce484222325
        for octet in texte.utf8 {
            h = (h ^ UInt64(octet)) &* 0x100000001b3
        }
        return String(format: "%016llx", h)
    }
}
