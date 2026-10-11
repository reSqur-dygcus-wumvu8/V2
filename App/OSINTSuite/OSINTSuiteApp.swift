import SwiftUI
import CryptoKit
import FeatureHome
import FeatureAcquerir
import FeatureCapitaliser
import FeatureExploiter
import FeatureGerer
import PackageAcces
import PackageDomain
import PackageIntelligence
import PackageMLA
import PackagePersistence
import PackageTor

/// Point d'entrée de l'application OSINT Suite (macOS, iOS, iPadOS).
/// À l'ouverture, la clé de session publiée par le Gestionnaire d'accès
/// (trousseau partagé) est lue ; la DEK est déballée et la base ouverte.
/// Sans session valide : écran verrouillé avec demande de déverrouillage.
/// La session est purgée au passage en arrière-plan.
@main
struct OSINTSuiteApp: App {
    @StateObject private var etat = EtatOSINTSuite()

    var body: some Scene {
        WindowGroup {
            EcranRacine(etat: etat)
                .onChange(of: etat.scene) { _, nouvelle in
                    if nouvelle == .background {
                        etat.verrouiller()
                    }
                }
        }
        // Fenêtres multiples sur macOS.
        #if os(macOS)
        Window("Acquérir", id: "acquerir") { AcquerirView() }
        Window("Capitaliser", id: "capitaliser") { CapitaliserView() }
        Window("Exploiter", id: "exploiter") { ExploiterView() }
        Window("Gérer", id: "gerer") { GererView() }
        #endif
    }
}

/// Écran racine : verrouillé ou accueil selon l'état de session.
struct EcranRacine: View {
    @ObservedObject var etat: EtatOSINTSuite
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if etat.deverrouillee, let base = etat.base {
                AccueilView().environmentObject(base)
            } else {
                EcranVerrou(etat: etat)
            }
        }
        .onAppear {
            etat.scene = scenePhase
            etat.tenterOuverture()
        }
        .onChange(of: scenePhase) { _, nouveau in etat.scene = nouveau }
    }
}

/// État de déverrouillage de l'application principale.
@MainActor
final class EtatOSINTSuite: ObservableObject {
    @Published var deverrouillee = false
    @Published var message: String?
    @Published var scene: ScenePhase = .inactive

    /// Phrase secrète saisie dans l'écran de déverrouillage (mode test sans compte développeur).
    @Published var phraseSaisie = ""
    /// Moteur de stockage MLA ouvert après déverrouillage.
    private(set) var base: MoteurStockage?
    /// Client Tor embarqué : tout le trafic sortant passe par lui.
    private(set) var reseau: ReseauTor?
    /// Mode découverte (pont Mistral via Tor) — construit après ouverture.
    private(set) var serviceDecouverte: ServiceDecouverte?


    /// Dossier des archives MLA dans le conteneur applicatif.
    static func dossierMLA() -> URL {
        let dossier = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return dossier.appendingPathComponent("archives-mla", isDirectory: true)
    }

    /// Tente de déverrouiller les archives MLA avec la phrase secrète
    /// saisie (mode test sans compte développeur : pas de trousseau partagé,
    /// le secret maître MLA est saisi manuellement à chaque ouverture).
    func tenterOuverture() {
        message = "Saisissez la phrase secrète MLA pour ouvrir la base chiffrée."
        deverrouillee = false
    }

    /// Déverrouillage manuel : ouvre les archives avec la phrase saisie.
    func deverrouillerAvecPhrase() {
        guard !phraseSaisie.isEmpty else {
            message = "Saisissez la phrase secrète MLA."
            return
        }
        do {
            base = try MoteurStockage(dossier: Self.dossierMLA(), phraseSecrete: phraseSaisie)
            ouvrirServices()
            deverrouillee = true
            phraseSaisie = ""
        } catch {
            message = "Échec du déverrouillage : \(error.localizedDescription)"
            deverrouillee = false
        }
    }

    /// Initialisation première : génère une phrase secrète MLA, crée les
    /// archives puis l'affiche une seule fois pour la noter hors appareil.
    func initialiserBase() {
        let phrase = ModeleCles.genererDEK()
            .withUnsafeBytes { Data($0).base64EncodedString() }
        do {
            base = try MoteurStockage(dossier: Self.dossierMLA(), phraseSecrete: phrase)
            ouvrirServices()
            deverrouillee = true
            message = "NOTER LA PHRASE SECRÈTE (affichée une seule fois) :\n\(phrase)"
        } catch {
            message = "Échec de l'initialisation : \(error.localizedDescription)"
        }
    }

    /// Construit les services réseau (Tor, découverte) après ouverture.
    private func ouvrirServices() {
        let keychain = KeychainStore()
        let clientTor = ClientTor()
        let reseauTor = ReseauTor(client: clientTor)
        reseau = reseauTor
        Task { try? await reseauTor.preparer() }
        if let urlTexte = keychain.lireToString(cle: "url-proxy"),
           let token = keychain.lireToString(cle: "token-proxy"),
           let url = URL(string: urlTexte) {
            serviceDecouverte = ServiceDecouverte(
                clientDecouverte: ClientDecouverteProxy(
                    urlBase: url,
                    token: token,
                    reseau: reseauTor
                )
            )
        } else {
            serviceDecouverte = ServiceDecouverte()
        }
    }


    /// Verrouillage : consolidation des archives MLA puis fermeture du jeu
    /// de travail (mode test : rien à purger, la phrase n'est jamais stockée).
    func verrouiller() {
        try? base?.consolider()
        base = nil
        reseau = nil
        deverrouillee = false
        message = "Archives consolidées et base verrouillée (passage en arrière-plan)."
    }
}

/// Écran verrouillé : saisie manuelle de la phrase secrète MLA (mode test
/// sans compte développeur — pas de trousseau partagé entre applications).
struct EcranVerrou: View {
    @ObservedObject var etat: EtatOSINTSuite

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Base verrouillée")
                .font(.title2.bold())
            Text(etat.message ?? "Saisissez la phrase secrète MLA pour ouvrir la base chiffrée.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            SecureField("Phrase secrète MLA", text: $etat.phraseSaisie)
                .textFieldStyle(.roundedBorder)
            Button("Déverrouiller") {
                etat.deverrouillerAvecPhrase()
            }
            .buttonStyle(.borderedProminent)
            Divider()
            Button("Première utilisation : créer la base") {
                etat.initialiserBase()
            }
            .buttonStyle(.bordered)
            Text("La phrase secrète n'est jamais stockée sur l'appareil. Sans elle, la base est définitivement illisible.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: 460)
    }
}
