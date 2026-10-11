import Foundation
import PackageDomain

/// Mode découverte : recherche libre assistée sur une thématique.
/// Boucle de réflexion Mistral (itérations de recherche via Tor,
/// modèle de raisonnement approfondi), synthèse structurée avec sources
/// cotées, proposition de sources d'intérêt → veilles créables en un clic.
public struct ServiceDecouverte: Sendable {

    /// Résultat d'une découverte : synthèse + sources + veilles proposées.
    public struct ResultatDecouverte: Codable, Sendable, Equatable {
        public var thematique: String
        public var synthese: String
        public var sources: [SourceDecouverte]
        public var sourcesInteret: [SourceInteret]
        public var date: Date

        public init(
            thematique: String,
            synthese: String,
            sources: [SourceDecouverte] = [],
            sourcesInteret: [SourceInteret] = [],
            date: Date = Date()
        ) {
            self.thematique = thematique
            self.synthese = synthese
            self.sources = sources
            self.sourcesInteret = sourcesInteret
            self.date = date
        }
    }

    /// Source citée dans la synthèse, avec cotation proposée (validation
    /// humaine comme toujours).
    public struct SourceDecouverte: Codable, Sendable, Equatable, Identifiable {
        public var id: UUID
        public var url: String
        public var titre: String
        public var cotationProposee: FiabiliteSource?

        public init(id: UUID = UUID(), url: String, titre: String, cotationProposee: FiabiliteSource? = nil) {
            self.id = id
            self.url = url
            self.titre = titre
            self.cotationProposee = cotationProposee
        }
    }

    /// Source d'intérêt proposée à l'issue de la découverte : surveillable
    /// en un clic (création de veille pré-remplie).
    public struct SourceInteret: Codable, Sendable, Equatable, Identifiable {
        public enum Genre: String, Codable, Sendable {
            case site
            case flux
            case reseauSocial
        }

        public var id: UUID
        public var genre: Genre
        public var url: String
        public var libelle: String
        /// Pré-remplissage de veille : type et mots-clés suggérés.
        public var typeVeilleSuggere: TypeVeille
        public var motsClesSuggeres: [String]

        public init(
            id: UUID = UUID(),
            genre: Genre,
            url: String,
            libelle: String,
            typeVeilleSuggere: TypeVeille,
            motsClesSuggeres: [String] = []
        ) {
            self.id = id
            self.genre = genre
            self.url = url
            self.libelle = libelle
            self.typeVeilleSuggere = typeVeilleSuggere
            self.motsClesSuggeres = motsClesSuggeres
        }
    }

    let clientDecouverte: ClientDecouverteBridge?

    public init(clientDecouverte: ClientDecouverteBridge? = nil) {
        self.clientDecouverte = clientDecouverte
    }

    /// Estimation du nombre d'appels Mistral d'une découverte (affichée à
    /// l'utilisateur avant lancement — confirmation systématique).
    public static func estimationAppels(thematique: String) -> Int {
        // Boucle de réflexion : ~3 requêtes de recherche + 2 itérations
        // d'affinage + 1 synthèse + 1 extraction de sources.
        max(5, min(15, 5 + thematique.count / 40))
    }

    /// Lance la découverte sur une thématique. Le pont exécute la boucle
    /// de réflexion (requêtes générées → recherches via Tor → affinage)
    /// et retourne le résultat structuré.
    public func decouvrir(thematique: String) async -> ResultatDecouverte? {
        guard let client = clientDecouverte, !thematique.isEmpty else { return nil }
        return await client.decouvrir(thematique: thematique)
    }

    /// Construit la veille pré-remplie correspondant à une source d'intérêt
    /// (création en un clic depuis l'UI).
    public static func veilleProposee(depuis source: SourceInteret) -> Veille {
        Veille(
            type: source.typeVeilleSuggere,
            titre: "Veille — \(source.libelle)",
            motsCles: source.motsClesSuggeres,
            urlSource: source.genre == .flux ? source.url : nil
        )
    }
}

/// Pont vers le proxy Mistral en mode réflexion (l'implémentation
/// réseau est injectée ; le prompt de boucle de raisonnement vit côté
/// proxy, /decouvrir).
public protocol ClientDecouverteBridge: Sendable {
    func decouvrir(thematique: String) async -> ServiceDecouverte.ResultatDecouverte?
}
