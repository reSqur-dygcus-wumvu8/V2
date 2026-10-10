import SwiftUI
import PackageDomain
import PackagePersistence

/// Paramètres : seuils de similarité, fréquences de veille, effacement complet
/// (panic wipe), export chiffré. Les secrets restent dans le Keychain.
public struct ParametresView: View {
    @StateObject private var modele: ModeleParametres

    public init(modele: ModeleParametres) {
        _modele = StateObject(wrappedValue: modele)
    }

    public var body: some View {
        Form {
            Section("Doublons") {
                Stepper("Seuil texte : \(modele.seuilTexte, format: .percent)",
                        value: $modele.seuilTexte, in: 0.5...1.0, step: 0.05)
                Stepper("Seuil dénominations : \(modele.seuilDenomination, format: .percent)",
                        value: $modele.seuilDenomination, in: 0.5...1.0, step: 0.05)
            }
            Section("Veilles") {
                Stepper("Fréquence par défaut : \(modele.frequenceDefaut) min",
                        value: $modele.frequenceDefaut, in: 5...1440, step: 5)
                Toggle("Actions automatiques Mistral", isOn: $modele.actionsMistral)
            }
            Section("Synchronisation") {
                Toggle("Synchronisation CloudKit", isOn: $modele.syncActive)
                Text("L'application reste pleinement fonctionnelle sans iCloud.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Données") {
                Button("Exporter la base (sauvegarde chiffrée)") { modele.exporter() }
                Button("Effacer toutes les données (panic wipe)", role: .destructive) {
                    modele.demanderPanicWipe = true
                }
            }
            if let message = modele.message {
                Text(message).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Paramètres")
        .confirmationDialog("Effacer définitivement toutes les données ?",
                            isPresented: $modele.demanderPanicWipe, titleVisibility: .visible) {
            Button("Effacer tout", role: .destructive) { modele.panicWipe() }
            Button("Annuler", role: .cancel) {}
        }
    }
}

/// Modèle de vue des paramètres (MVVM).
@MainActor
public final class ModeleParametres: ObservableObject {
    @Published public var seuilTexte: Double = 0.8 {
        didSet { sauvegarder("seuilTexte", seuilTexte) }
    }
    @Published public var seuilDenomination: Double = 0.85 {
        didSet { sauvegarder("seuilDenomination", seuilDenomination) }
    }
    @Published public var frequenceDefaut: Int = 60 {
        didSet { sauvegarder("frequenceDefaut", frequenceDefaut) }
    }
    @Published public var actionsMistral = true {
        didSet { sauvegarder("actionsMistral", actionsMistral) }
    }
    @Published public var syncActive = false {
        didSet { sauvegarder("syncActive", syncActive) }
    }
    @Published public var demanderPanicWipe = false
    @Published public var message: String?

    private let dossierMLA: URL
    private let keychain: KeychainStore
    private let reglages = UserDefaults.standard

    public init(
        dossierMLA: URL,
        keychain: KeychainStore = KeychainStore()
    ) {
        self.dossierMLA = dossierMLA
        seuilTexte = reglages.object(forKey: "seuilTexte") as? Double ?? 0.8
        seuilDenomination = reglages.object(forKey: "seuilDenomination") as? Double ?? 0.85
        frequenceDefaut = reglages.object(forKey: "frequenceDefaut") as? Int ?? 60
        actionsMistral = reglages.object(forKey: "actionsMistral") as? Bool ?? true
        syncActive = reglages.object(forKey: "syncActive") as? Bool ?? false
    }

    /// Écrit un réglage (les réglages ne contiennent jamais de secret).
    private func sauvegarder(_ cle: String, _ valeur: some Any) {
        reglages.set(valeur, forKey: cle)
    }

    /// Export chiffré : copie les segments MLA dans un dossier de sauvegarde.
    public func exporter() {
        let gestionnaire = FileManager.default
        do {
            let dossierExport = gestionnaire.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? gestionnaire.temporaryDirectory
            let destination = dossierExport
                .appendingPathComponent("sauvegarde-\(Int(Date().timeIntervalSince1970))", isDirectory: true)
            if gestionnaire.fileExists(atPath: dossierMLA.path) {
                try gestionnaire.copyItem(at: dossierMLA, to: destination)
                message = "Sauvegarde chiffrée créée : \(destination.lastPathComponent)"
            } else {
                message = "Aucune donnée à exporter."
            }
        } catch {
            message = "Erreur d'export : \(error.localizedDescription)"
        }
    }

    /// Panic wipe : destruction des segments d'archive MLA et du trousseau
    /// de service (le secret maître est révoqué côté Gestionnaire d'accès).
    public func panicWipe() {
        do {
            try FileManager.default.removeItem(at: dossierMLA)
            try keychain.toutSupprimer()
            message = "Toutes les données ont été effacées (archives MLA détruites)."
        } catch {
            message = "Erreur d'effacement : \(error.localizedDescription)"
        }
    }
}
