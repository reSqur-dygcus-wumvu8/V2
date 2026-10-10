import SwiftUI
import PackageDomain
import PackagePersistence
import PackageTor

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
            Section("Tor — trafic sortant") {
                Stepper("Port SOCKS5 : \(modele.portSOCKS5)", value: $modele.portSOCKS5, in: 9050...9150, step: 1)
                Text("Tout le trafic sortant (veilles, tuiles, Mistral, GitHub) transite par Tor. Ponts obfs4 configurables.")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("Ponts (obfs4 ip:port certificat, un par ligne)", text: $modele.ponts, axis: .vertical)
                    .font(.system(.caption, design: .monospaced))
            }
            Section("Synchronisation (dépôt GitHub via Tor)") {
                Toggle("Synchronisation", isOn: $modele.syncActive)
                Text("Deltas CRDT chiffrés échangés via un dépôt GitHub privé, relevés via Tor. L'application reste pleinement fonctionnelle sans synchronisation.")
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
    @Published public var portSOCKS5: Int = 9050 {
        didSet { sauvegarder("portSOCKS5", portSOCKS5) }
    }
    @Published public var ponts = "" {
        didSet { sauvegarder("ponts", ponts) }
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
        portSOCKS5 = reglages.object(forKey: "portSOCKS5") as? Int ?? 9050
        ponts = reglages.string(forKey: "ponts") ?? ""
    }

    /// Configuration Tor courante (ponts parsés ligne par ligne).
    public var configurationTor: ConfigurationTor {
        ConfigurationTor(
            portSOCKS5: UInt16(portSOCKS5),
            ponts: ponts.components(separatedBy: .newlines).filter { !$0.isEmpty }
        )
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
