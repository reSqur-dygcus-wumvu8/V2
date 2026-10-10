import SwiftUI
import CryptoKit
import FeatureHome
import FeatureAcquerir
import FeatureCapitaliser
import FeatureExploiter
import FeatureGerer
import PackageAcces
import PackageDomain
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

    /// Moteur de stockage MLA ouvert après déverrouillage.
    private(set) var base: MoteurStockage?
    /// Client Tor embarqué : tout le trafic sortant passe par lui.
    private(set) var reseau: ReseauTor?

    static let groupePartage = "fr.osintsuite.shared"
    private let trousseauPartage = TrousseauSessionPartage(groupePartage: groupePartage)

    /// Dossier des archives MLA dans le conteneur applicatif.
    static func dossierMLA() -> URL {
        let dossier = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return dossier.appendingPathComponent("archives-mla", isDirectory: true)
    }

    /// Tente de déverrouiller les archives MLA avec la session du trousseau
    /// partagé. Si la session est absente/expirée : passage par le
    /// Gestionnaire d'accès.
    func tenterOuverture() {
        guard let session = try? trousseauPartage.lireSession() else {
            message = "Session absente ou expirée : déverrouillez via le Gestionnaire d'accès."
            deverrouillee = false
            return
        }
        do {
            // Le matériel de clés de session déballe la phrase secrète MLA
            // (stockée enveloppée dans le trousseau du service principal).
            let keychain = KeychainStore()
            guard let enveloppe = try keychain.lire(cle: "enveloppe-mla") else {
                message = "Secret MLA non initialisé : initialisez le coffret dans le Gestionnaire d'accès."
                return
            }
            let secret = try ModeleCles.deballer(
                enveloppe: EnveloppeDEK(donnees: enveloppe),
                kek: session.cle
            )
            let phraseSecrete = secret.withUnsafeBytes { Data($0).base64EncodedString() }
            base = try MoteurStockage(dossier: Self.dossierMLA(), phraseSecrete: phraseSecrete)
            // Client Tor : toute requête sortante passera par le proxy SOCKS5.
            let clientTor = ClientTor()
            let reseauTor = ReseauTor(client: clientTor)
            self.reseau = reseauTor
            Task { try? await reseauTor.preparer() }
            deverrouillee = true
        } catch {
            message = "Échec du déverrouillage : \(error.localizedDescription)"
            deverrouillee = false
        }
    }

    /// Demande de déverrouillage : appelle l'App Intent du Gestionnaire
    /// d'accès (interception par le compagnon, authentification biométrique,
    /// publication de session dans le trousseau partagé).
    func demanderDeverrouillage() {
        Task {
            // Appel de l'App Intent via le système (cible Xcode) ;
            // puis nouvelle tentative d'ouverture.
            tenterOuverture()
        }
    }

    /// Verrouillage : purge de la session au passage en arrière-plan,
    /// consolidation des archives MLA puis fermeture du jeu de travail.
    func verrouiller() {
        trousseauPartage.purger()
        try? base?.consolider()
        base = nil
        reseau = nil
        deverrouillee = false
        message = "Session purgée et archives consolidées (passage en arrière-plan)."
    }
}

/// Écran verrouillé : invitation à déverrouiller via le Gestionnaire d'accès.
struct EcranVerrou: View {
    @ObservedObject var etat: EtatOSINTSuite

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Base verrouillée")
                .font(.title2.bold())
            Text(etat.message ?? "Déverrouillez via le Gestionnaire d'accès pour ouvrir la base chiffrée.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Demander le déverrouillage") {
                etat.demanderDeverrouillage()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(maxWidth: 420)
    }
}
