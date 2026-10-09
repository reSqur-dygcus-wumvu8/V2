import SwiftUI
import CryptoKit
import PackageAcces

/// Point d'entrée du Gestionnaire d'accès (app compagnon hors ligne).
/// À l'ouverture : configuration du pont App Intents avec le coffret de
/// clés (KEK liée au Secure Enclave via FournisseurKEKSecureEnclave,
/// non extractible, protégée par Face ID / Touch ID + code).
@main
struct GestionnaireAccesApp: App {
    @StateObject private var etat = EtatGestionnaireAcces()

    var body: some Scene {
        WindowGroup {
            AccueilGestionnaireView()
                .environmentObject(etat)
        }
    }
}

/// État global du Gestionnaire d'accès : coffret de clés, appareils, audit.
/// Le groupe de trousseau partagé (Team ID commun) est défini dans les
/// entitlements des deux applications : seule la clé de session y transite.
@MainActor
final class EtatGestionnaireAcces: ObservableObject {
    @Published var appareils: [AppareilAutorise] = []
    @Published var journal: [EntreeAudit] = []
    @Published var phraseRecuperation: [String]?
    @Published var message: String?

    /// Groupe trousseau partagé — à renseigner avec le Team ID réel
    /// (ex. "XXXXXXXXXX.fr.osintsuite.shared") dans les entitlements.
    static let groupePartage = "fr.osintsuite.shared"

    let coffret: CoffreCles
    let fournisseurKEK: FournisseurKEKSecureEnclave
    let trousseauPartage: TrousseauSessionPartage

    init() {
        fournisseurKEK = FournisseurKEKSecureEnclave()
        trousseauPartage = TrousseauSessionPartage(groupePartage: Self.groupePartage)
        // KEK : existante (Secure Enclave) ou générée à la première utilisation.
        let kek: SymmetricKey
        if fournisseurKEK.kekExistante, let chargee = try? fournisseurKEK.chargerKEK() {
            kek = chargee
            message = "KEK chargée depuis le Secure Enclave."
        } else if let neuve = try? fournisseurKEK.genererKEK() {
            kek = neuve
            message = "Nouvelle KEK générée dans le Secure Enclave."
        } else {
            // Repli logiciel (simulateur sans Secure Enclave) — documenté.
            kek = SymmetricKey(size: ModeleCles.tailleCle)
            message = "Secure Enclave indisponible : KEK logicielle (simulateur)."
        }
        coffret = CoffreCles(kek: kek)

        PontDeverrouillage.partage.coffret = coffret
        PontDeverrouillage.partage.observateurSession = { [trousseauPartage] session in
            Task { @MainActor in
                try? trousseauPartage.publier(session)
            }
        }
        Task { await recharger() }
    }

    /// Recharge appareils et journal depuis le coffret.
    func recharger() async {
        appareils = await coffret.appareilsAutorises()
        journal = await coffret.journalAudit()
    }

    /// Autorise un nouvel appareil.
    func autoriser(_ appareil: AppareilAutorise) async {
        await coffret.autoriser(appareil)
        await recharger()
    }

    /// Révoque un appareil.
    func revoquer(_ id: UUID) async {
        await coffret.revoquer(id: id)
        await recharger()
    }

    /// Affiche la phrase de récupération (une seule fois).
    func genererPhrase() async {
        phraseRecuperation = await coffret.genererPhraseRecuperation()
    }

    /// Panic wipe : KEK révoquée, session purgée, base définitivement
    /// illisible sur tous les appareils.
    func panique() async {
        await coffret.panique()
        trousseauPartage.purger()
        try? fournisseurKEK.supprimerKEK()
        await recharger()
    }
}

/// Accueil du Gestionnaire d'accès : statut, appareils, actions sensibles.
struct AccueilGestionnaireView: View {
    @EnvironmentObject private var etat: EtatGestionnaireAcces

    var body: some View {
        NavigationStack {
            List {
                if let message = etat.message {
                    Section {
                        Text(message).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Appareils autorisés") {
                    ForEach(etat.appareils) { appareil in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(appareil.nom).bold()
                                Text(appareil.profil.libelle)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !appareil.actif {
                                Text("Révoqué").foregroundStyle(.red)
                            }
                        }
                    }
                    Button("Autoriser cet appareil…") {
                        Task {
                            await etat.autoriser(
                                AppareilAutorise(nom: Host.current().localizedName ?? "Mac", profil: .complet)
                            )
                        }
                    }
                }
                Section("Actions") {
                    Button("Rotation de la KEK") {
                        Task {
                            _ = try? await etat.coffret.rotationKEK(nouvelleKEK: SymmetricKey(size: ModeleCles.tailleCle))
                            await etat.recharger()
                        }
                    }
                    Button("Rotation de la DEK") {
                        Task { _ = try? await etat.coffret.rotationDEK() }
                    }
                    Button("Phrase de récupération (affichée une seule fois)") {
                        Task { await etat.genererPhrase() }
                    }
                }
                if let phrase = etat.phraseRecuperation {
                    Section("Phrase de récupération — conserver hors appareil") {
                        Text(phrase.joined(separator: " "))
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                Section("Journal d'audit") {
                    ForEach(etat.journal.suffix(20).reversed()) { entree in
                        VStack(alignment: .leading) {
                            Text(entree.date, style: .date)
                            Text("\(entree.appareil) — \(entree.action)")
                                .font(.caption)
                                .foregroundStyle(entree.succes ? .secondary : .red)
                        }
                    }
                }
                Section {
                    Button("PANIC WIPE — révoquer la KEK", role: .destructive) {
                        Task { await etat.panique() }
                    }
                }
            }
            .navigationTitle("Gestionnaire d'accès")
        }
    }
}
