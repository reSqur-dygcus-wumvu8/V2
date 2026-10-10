import Foundation
import CryptoKit
import PackageDomain

/// Client de traduction Mistral : les résultats de veille hors français
/// sont traduits via le proxy (clé jamais dans le client) ; l'original est
/// conservé et consultable. Le proxy expose POST /traduire.
public actor ClientTraductionMistral {

    public struct Configuration: Sendable, Equatable {
        public var urlBase: URL
        public var token: String

        public init(urlBase: URL, token: String) {
            self.urlBase = urlBase
            self.token = token
        }
    }

    private let configuration: Configuration
    private let reseau: ReseauTorBridge

    public init(configuration: Configuration, reseau: ReseauTorBridge) {
        self.configuration = configuration
        self.reseau = reseau
    }

    /// Traduit un texte vers le français. Retourne nil en cas d'échec
    /// (l'original est alors conservé tel quel, consultable).
    public func traduireVersFrancais(_ texte: String, depuisLangue: String?) async -> String? {
        guard !texte.isEmpty else { return nil }
        var requete = URLRequest(url: configuration.urlBase.appendingPathComponent("traduire"))
        requete.httpMethod = "POST"
        requete.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        requete.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let corps: [String: Any] = ["texte": texte, "langue_source": depuisLangue ?? "auto"]
        requete.httpBody = try? JSONSerialization.data(withJSONObject: corps)
        guard let donnees = try? await reseau.envoyer(requete),
              let reponse = try? JSONSerialization.jsonObject(with: donnees) as? [String: Any],
              let traduction = reponse["traduction"] as? String else {
            return nil
        }
        return traduction.isEmpty ? nil : traduction
    }
}

/// Pont vers la façade réseau Tor (ReseauTor vit dans PackageTor ; ce
/// protocole évite la dépendance directe côté Intelligence et reste
/// testable par injection).
public protocol ReseauTorBridge: Sendable {
    func envoyer(_ requete: URLRequest) async throws -> Data
    func telecharger(_ url: URL) async throws -> Data
}

/// Service de traduction des éléments de veille : détecte la langue
/// (heuristique simple), traduit via Mistral et conserve l'original.
public struct ServiceTraduction: Sendable {

    public init() {}

    /// Indique si un texte est vraisemblablement en français (mots
    /// d'arrêt courants). Heuristique volontairement simple : la traduction
    /// est inutile pour le français, coûteuse pour les autres.
    public static func sembleFrancais(_ texte: String) -> Bool {
        let motsArret: Set<String> = ["le", "la", "les", "un", "une", "des", "et", "du", "de", "au", "aux", "est", "en", "que"]
        let mots = texte.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 1 }
        guard !mots.isEmpty else { return true }
        let francais = mots.filter { motsArret.contains($0) }.count
        return Double(francais) / Double(mots.count) >= 0.08
    }

    /// Traduit un élément de veille vers le français si nécessaire :
    /// le contenu affiché devient la traduction, l'original est conservé
    /// dans contenuOriginal avec sa langue.
    public static func traduire(
        _ element: ElementVeille,
        avec client: ClientTraductionMistral?
    ) async -> ElementVeille {
        var resultat = element
        // Déjà en français : rien à traduire.
        if let langue = resultat.langueOriginale, langue == "fr" {
            return resultat
        }
        guard let client, !sembleFrancais(element.contenu) else {
            return resultat
        }
        let langue = resultat.langueOriginale
        if let traduction = await client.traduireVersFrancais(resultat.contenu, depuisLangue: langue) {
            resultat.contenuOriginal = resultat.contenu
            resultat.contenu = traduction
        }
        return resultat
    }
}
