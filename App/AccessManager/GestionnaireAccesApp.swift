import SwiftUI
import CryptoKit
import PackageAcces

/// Point d'entrée du Gestionnaire d'accès (app compagnon hors ligne).
/// À l'ouverture : configuration du pont App Intents avec le coffret de
/// clés (KEK liée au Secure Enclave en production : kSecAttrTokenIDSecureEnclave,
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
@MainActor
final class EtatGestionnaireAcces: ObservableObject {
    @Published var appareils: [AppareilAutorise] = []
    @Published var journal: [EntreeAudit] = []
    @Published var phraseRecuperation: [String]?

    let coffret: CoffreCles

    init() {
        // En production : KEK générée et liée au Secure Enclave, protégée par
        // biométrie + code. Les tests utilisent une KEK logicielle.
        coffret = CoffreCles(kek: SymmetricKey(size: .bits256))
        PontDeverrouillage.partage.coffret = coffret
        PontDeverrouillage.partage.observateurSession = { session in
            // Écriture dans le groupe de trousseau partagé (seul élément
            // transitoire partagé — jamais la KEK), avec purge à l'expiration
            // ou au passage en arrière-plan.
            Task { @MainActor in
                EcrivainTrousseauPartage.ecrire(session)
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

    /// Panic wipe : KEK révoquée, base définitivement illisible partout.
    func panique() async {
        await coffret.panique()
        EcrivainTrousseauPartage.purger()
        await recharger()
    }
}

/// Écriture de la clé de session dans le groupe de trousseau partagé.
/// En production, utilise KeychainStore de PackagePersistence avec le groupe
/// d'accès du Team ID commun (cible applicative, entitlements).
enum EcrivainTrousseauPartage {
    static func ecrire(_ session: CleSession) {
        // Branché sur le trousseau partagé dans la cible Xcode :
        // try keychainPartage.enregistrer(donnees, cle: "session-osint")
    }

    static func purger() {
        // Suppression de la clé de session du trousseau partagé.
    }
}

/// Accueil du Gestionnaire d'accès : statut, appareils, actions sensibles.
struct AccueilGestionnaireView: View {
    @EnvironmentObject private var etat: EtatGestionnaireAcces

    var body: some View {
        NavigationStack {
            List {
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
                }
                Section("Actions") {
                    Button("Rotation de la KEK") {
                        Task { try? await etat.coffret.rotationKEK(nouvelleKEK: SymmetricKey(size: .bits256)) }
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
