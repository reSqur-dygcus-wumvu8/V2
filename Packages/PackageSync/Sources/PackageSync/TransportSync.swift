import Foundation
import PackageDomain
import PackageMLA
import PackageTor

/// Abstraction du transport de synchronisation (GitHub via Tor en
/// production ; mock injectable pour les tests — aucun réseau requis).
public protocol TransportSync: Sendable {
    /// Pousse un delta chiffré (créé si inexistant).
    func pousser(delta: DeltaSync) async throws
    /// Relève les deltas plus récents que la date de référence.
    func relever(depuis: Date) async throws -> [DeltaSync]
}

/// Delta de synchronisation : fragment CRDT chiffré, horodaté, sourcé
/// de l'appareil émetteur. Le contenu chiffré (payload) est illisible
/// pour le dépôt distant.
public struct DeltaSync: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var appareil: String
    public var date: Date
    /// Contenu CRDT chiffré (segment MLA « delta »).
    public var payload: Data

    public init(id: UUID = UUID(), appareil: String, date: Date = Date(), payload: Data) {
        self.id = id
        self.appareil = appareil
        self.date = date
        self.payload = payload
    }
}

/// Synchronisation GitHub via Tor : les deltas CRDT chiffrés sont stockés
/// dans un dépôt privé (branche « sync ») et échangés entre appareils.
/// GitHub est joint exclusivement par le proxy SOCKS5 Tor.
public struct TransportSyncGitHub: TransportSync {

    public struct Configuration: Sendable, Equatable {
        /// Dépôt privé (ex. "reSqur-dygcus-wumvu8/V2-sync").
        public var depot: String
        /// Branche dédiée aux deltas.
        public var branche: String
        /// Token d'accès GitHub (portée repo privée) — Keychain, jamais en dur.
        public var token: String

        public init(depot: String, branche: String = "sync", token: String) {
            self.depot = depot
            self.branche = branche
            self.token = token
        }
    }

    private let configuration: Configuration
    private let reseau: ReseauTor

    public init(configuration: Configuration, reseau: ReseauTor) {
        self.configuration = configuration
        self.reseau = reseau
    }

    public func pousser(delta: DeltaSync) async throws {
        // API GitHub Contents : création du fichier sync/<timestamp>-<id>.json
        // (préfixe horodatage pour relever uniquement les nouveaux).
        let contenu = try JSONEncoder().encode(delta)
        var requete = URLRequest(url: URL(string: "https://api.github.com/repos/\(configuration.depot)/contents/sync/\(Int(delta.date.timeIntervalSince1970))-\(delta.id.uuidString).json?ref=\(configuration.branche)")!)
        requete.httpMethod = "PUT"
        requete.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        requete.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let corps: [String: Any] = [
            "message": "sync \(delta.id.uuidString)",
            "content": contenu.base64EncodedString(),
            "branch": configuration.branche
        ]
        requete.httpBody = try JSONSerialization.data(withJSONObject: corps)
        _ = try await reseau.envoyer(requete)
    }

    public func relever(depuis: Date) async throws -> [DeltaSync] {
        // Listing du dossier sync/ de la branche dédiée.
        var requete = URLRequest(url: URL(string: "https://api.github.com/repos/\(configuration.depot)/contents/sync?ref=\(configuration.branche)")!)
        requete.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        requete.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let donnees = try await reseau.envoyer(requete)
        guard let listing = try JSONSerialization.jsonObject(with: donnees) as? [[String: Any]] else {
            return []
        }
        var deltas: [DeltaSync] = []
        for entree in listing {
            guard let nom = entree["name"] as? String,
                  let chemin = entree["path"] as? String,
                  let dateFichier = Self.dateDepuisNom(nom) else { continue }
            guard dateFichier >= depuis else { continue }
            // Téléchargement du contenu du delta via Tor.
            var requeteFichier = URLRequest(url: URL(string: "https://api.github.com/repos/\(configuration.depot)/contents/\(chemin)?ref=\(configuration.branche)")!)
            requeteFichier.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
            requeteFichier.setValue("application/vnd.github.raw+json", forHTTPHeaderField: "Accept")
            let donneesFichier = try await reseau.envoyer(requeteFichier)
            if let delta = try? JSONDecoder().decode(DeltaSync.self, from: donneesFichier) {
                deltas.append(delta)
            }
        }
        return deltas.sorted { $0.date < $1.date }
    }
}

extension TransportSyncGitHub {
    /// Extrait la date encodée dans un nom de fichier de delta
    /// (sync/<timestamp>-<id>.json).
    static func dateDepuisNom(_ nom: String) -> Date? {
        // Format attendu : <timestamp>-<uuid>.json
        let parties = nom.replacingOccurrences(of: ".json", with: "").split(separator: "-")
        guard let timestamp = TimeInterval(parties.first ?? "") else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
}
