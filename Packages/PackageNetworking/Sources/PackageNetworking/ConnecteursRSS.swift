import Foundation
import PackageDomain

/// Connecteur Google Actualités : construit l'URL du flux RSS de recherche
/// à partir des mots-clés et le récupère périodiquement.
public struct ConnecteurGoogleNews: Sendable {

    /// URL de base du flux RSS de recherche Google Actualités en français.
    public static let urlBaseGoogleNews = "https://news.google.com/rss/search?q="

    public init() {}

    /// Construit l'URL du flux pour une liste de mots-clés.
    public func urlRecherche(motsCles: [String]) -> URL? {
        guard !motsCles.isEmpty else { return nil }
        let requete = motsCles.joined(separator: " ")
        let encodee = requete.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? requete
        return URL(string: Self.urlBaseGoogleNews + encodee + "&hl=fr&gl=FR&ceid=FR:fr")
    }

    /// Récupère et analyse le flux Google News pour la veille donnée.
    public func executer(
        veille: Veille,
        session: URLSession = .shared,
        calculHash: (String) -> String
    ) async throws -> [ElementVeilleBrut] {
        guard let url = urlRecherche(motsCles: veille.motsCles) else { return [] }
        let (donnees, _) = try await session.data(from: url)
        guard let xml = String(data: donnees, encoding: .utf8) else {
            throw ErreurVeille.fluxIllisible
        }
        let analyseur = AnalyseurRSS()
        return analyseur.analyser(xml: xml, veilleId: veille.id, hash: calculHash)
    }
}

/// Connecteur de flux RSS/Atom générique (sources sélectionnées par l'utilisateur).
public struct ConnecteurRSS: Sendable {

    public init() {}

    /// Récupère et analyse un flux RSS/Atom donné.
    public func executer(
        urlFlux: URL,
        veilleId: UUID,
        session: URLSession = .shared,
        calculHash: (String) -> String
    ) async throws -> [ElementVeilleBrut] {
        let (donnees, _) = try await session.data(from: urlFlux)
        guard let xml = String(data: donnees, encoding: .utf8) else {
            throw ErreurVeille.fluxIllisible
        }
        let analyseur = AnalyseurRSS()
        return analyseur.analyser(xml: xml, veilleId: veilleId, hash: calculHash)
    }
}

/// Erreurs d'exécution des veilles.
public enum ErreurVeille: Error, LocalizedError {
    case fluxIllisible
    case urlInvalide

    public var errorDescription: String? {
        switch self {
        case .fluxIllisible: return "Flux RSS/Atom illisible."
        case .urlInvalide: return "URL de flux invalide."
        }
    }
}
