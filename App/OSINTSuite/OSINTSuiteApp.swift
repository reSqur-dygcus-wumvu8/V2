import SwiftUI
import CryptoKit
import FeatureHome
import FeatureAcquerir
import FeatureCapitaliser
import FeatureExploiter
import FeatureGerer
import PackageAcces
import PackagePersistence

/// Point d'entrée de l'application OSINT Suite (macOS, iOS, iPadOS).
/// À l'ouverture, la base chiffrée est déverrouillée via le Gestionnaire
/// d'accès (App Intent + clé de session dans le trousseau partagé) ;
/// sans session valide, l'app reste en mode verrouillé.
@main
struct OSINTSuiteApp: App {
    @StateObject private var etat = EtatOSINTSuite()

    var body: some Scene {
        WindowGroup {
            if etat.deverrouillee {
                AccueilView()
            } else {
                EcranVerrou(demande: etat)
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

/// État de déverrouillage de l'application principale : lit la clé de
/// session dans le trousseau partagé, déballe la DEK et ouvre la base.
@MainActor
final class EtatOSINTSuite: ObservableObject {
    @Published var deverrouillee = false
    @Published var message: String?

    private var base: BaseDonneesService?

    func demanderDeverrouillage() {
        // 1. Appel de l'App Intent du Gestionnaire d'accès.
        //    (Branchement effectif dans la cible Xcode : AppIntents perform
        //    intercepté côté compagnon ; en attendant, tente une session
        //    déjà publiée dans le trousseau partagé.)
        Task { await lireSessionEtOuvrir() }
    }

    /// Lit la clé de session du trousseau partagé et ouvre la base.
    func lireSessionEtOuvrir() async {
        // Branchement trousseau partagé (cible Xcode, entitlements du Team ID) :
        //guard let donneesSession = try? keychainPartage.lire(cle: "session-osint") else { ... }
        // Le scénario nominal complet requiert l'entitlement de groupe ; la
        // logique de déverrouillage est testée dans PackageAcces.
        message = "En attente de validation par le Gestionnaire d'accès."
    }
}

/// Écran verrouillé : invitation à déverrouiller via le Gestionnaire d'accès.
struct EcranVerrou: View {
    @ObservedObject var demande: EtatOSINTSuite

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Base verrouillée")
                .font(.title2.bold())
            Text(demande.message ?? "Déverrouillez via le Gestionnaire d'accès pour ouvrir la base chiffrée.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Demander le déverrouillage") {
                demande.demanderDeverrouillage()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(maxWidth: 420)
    }
}
