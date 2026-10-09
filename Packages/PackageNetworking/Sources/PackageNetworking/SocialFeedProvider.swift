import Foundation
import PackageDomain

/// Plateforme sociale supportée par un connecteur.
public enum PlateformeSociale: String, CaseIterable, Sendable {
    case xTwitter
    case telegram
    case discord
    case tiktok

    public var libelle: String {
        switch self {
        case .xTwitter: return "X (Twitter)"
        case .telegram: return "Telegram"
        case .discord: return "Discord"
        case .tiktok: return "TikTok"
        }
    }

    /// Méthode d'accès et risque documenté (CGU, stabilité).
    public var methodeEtRisque: String {
        switch self {
        case .xTwitter: return "Flux RSS tiers (nitter) ou API officielle si disponible — risque : flux non officiels instables."
        case .telegram: return "Page publique t.me/s/<canal> (scraping HTML, gratuit) — risque : mise en page susceptible de changer."
        case .discord: return "Invites publiques + webhook lecture seule — risque : l'API complète exige un bot."
        case .tiktok: return "Aucune API publique — import manuel ou flux RSS tiers, best effort."
        }
    }
}

/// Configuration d'un connecteur social (compte, canal, chaîne surveillés).
public struct ConfigurationConnecteur: Codable, Sendable, Equatable {
    public var identifiant: String
    public var plateforme: PlateformeSociale
    public var motsClesPriorite: [String]

    public init(identifiant: String, plateforme: PlateformeSociale, motsClesPriorite: [String] = []) {
        self.identifiant = identifiant
        self.plateforme = plateforme
        self.motsClesPriorite = motsClesPriorite
    }
}

/// Protocole commun des connecteurs sociaux : toute nouvelle plateforme
/// implémente ce protocole pour être branchée dans la veille.
public protocol SocialFeedProvider: Sendable {
    /// Plateforme gérée par ce connecteur.
    var plateforme: PlateformeSociale { get }

    /// Récupère les publications nouvelles pour la configuration donnée.
    func recuperer(configuration: ConfigurationConnecteur) async throws -> [ElementVeille]
}

/// Résultat d'une exécution de veille.
public struct ResultatVeille: Sendable, Equatable {
    public var veilleId: UUID
    public var nouveauxElements: [ElementVeille]
    public var erreur: String?

    public init(veilleId: UUID, nouveauxElements: [ElementVeille], erreur: String? = nil) {
        self.veilleId = veilleId
        self.nouveauxElements = nouveauxElements
        self.erreur = erreur
    }
}
