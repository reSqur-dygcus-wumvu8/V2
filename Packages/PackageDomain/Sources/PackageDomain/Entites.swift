import Foundation

/// Type d'entité de la base de connaissance.
public enum TypeEntite: String, CaseIterable, Codable, Sendable {
    case individu
    case organisation
    case evenement
    case lieu
    case objet
    case source

    /// Libellé affiché dans l'interface.
    public var libelle: String {
        switch self {
        case .individu: return "Individu"
        case .organisation: return "Organisation"
        case .evenement: return "Événement"
        case .lieu: return "Lieu"
        case .objet: return "Objet"
        case .source: return "Source"
        }
    }

    /// Champs attendus par type de fiche (utilisés par les features et la fusion).
    public var champs: [String] {
        switch self {
        case .individu: return ["prenom", "nom", "biographie", "commentaires"]
        case .organisation: return ["denomination", "typeOrganisation", "synthese", "commentaires"]
        case .evenement: return ["denomination", "dateHeure", "resume", "commentaires"]
        case .lieu: return ["denomination", "adresse", "coordonneesGPS", "resume", "commentaires"]
        case .objet: return ["denomination", "typeObjet", "precisions", "commentaires"]
        case .source: return ["denomination", "description", "cotation"]
        }
    }
}

/// Statut de traitement d'un document ou d'un élément de veille.
public enum StatutTraitement: String, Codable, Sendable {
    case nonTraite
    case enAttenteValidation
    case capitalise
    case ignore
}

/// Entité de la base de connaissance (table unique, colonne entityType).
public struct Entite: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var type: TypeEntite
    public var denomination: String
    public var prenom: String?
    public var nom: String?
    public var typeOrganisation: String?
    public var typeObjet: String?
    public var precisions: String?
    public var dateHeure: Date?
    public var adresse: String?
    public var latitude: Double?
    public var longitude: Double?
    public var resume: String?
    public var biographie: String?
    public var commentaires: String?
    public var cotationSource: FiabiliteSource?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        type: TypeEntite,
        denomination: String,
        prenom: String? = nil,
        nom: String? = nil,
        typeOrganisation: String? = nil,
        typeObjet: String? = nil,
        precisions: String? = nil,
        dateHeure: Date? = nil,
        adresse: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        resume: String? = nil,
        biographie: String? = nil,
        commentaires: String? = nil,
        cotationSource: FiabiliteSource? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.denomination = denomination
        self.prenom = prenom
        self.nom = nom
        self.typeOrganisation = typeOrganisation
        self.typeObjet = typeObjet
        self.precisions = precisions
        self.dateHeure = dateHeure
        self.adresse = adresse
        self.latitude = latitude
        self.longitude = longitude
        self.resume = resume
        self.biographie = biographie
        self.commentaires = commentaires
        self.cotationSource = cotationSource
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Relation dirigée entre deux entités (graphe relationnel).
public struct RelationEntites: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var idSource: UUID
    public var idCible: UUID
    public var typeRelation: String
    public var cotation: CotationOTAN?
    public var documentId: UUID?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        idSource: UUID,
        idCible: UUID,
        typeRelation: String,
        cotation: CotationOTAN? = nil,
        documentId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.idSource = idSource
        self.idCible = idCible
        self.typeRelation = typeRelation
        self.cotation = cotation
        self.documentId = documentId
        self.createdAt = createdAt
    }
}

/// Document importé (fichier local, page web, média) rattaché à une source.
public struct Document: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var nom: String
    public var dateImport: Date
    public var typeMime: String
    public var cheminFichier: String?
    public var hashSHA256: String
    public var texteExtrait: String?
    public var cotation: CotationOTAN?
    public var statut: StatutTraitement
    public var sourceId: UUID
    public var urlOrigine: String?

    public init(
        id: UUID = UUID(),
        nom: String,
        dateImport: Date = Date(),
        typeMime: String,
        cheminFichier: String? = nil,
        hashSHA256: String,
        texteExtrait: String? = nil,
        cotation: CotationOTAN? = nil,
        statut: StatutTraitement = .nonTraite,
        sourceId: UUID,
        urlOrigine: String? = nil
    ) {
        self.id = id
        self.nom = nom
        self.dateImport = dateImport
        self.typeMime = typeMime
        self.cheminFichier = cheminFichier
        self.hashSHA256 = hashSHA256
        self.texteExtrait = texteExtrait
        self.cotation = cotation
        self.statut = statut
        self.sourceId = sourceId
        self.urlOrigine = urlOrigine
    }
}

/// Type de veille configurable par l'utilisateur.
public enum TypeVeille: String, CaseIterable, Codable, Sendable {
    case googleNews
    case rss
    case social
}

/// Configuration d'une veille (mots-clés, source, fréquence, notifications).
public struct Veille: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var type: TypeVeille
    public var titre: String
    public var motsCles: [String]
    public var urlSource: String?
    public var plateforme: String?
    public var frequenceMinutes: Int
    public var active: Bool
    public var motsClesPriorite: [String]
    public var derniereExecution: Date?

    public init(
        id: UUID = UUID(),
        type: TypeVeille,
        titre: String,
        motsCles: [String] = [],
        urlSource: String? = nil,
        plateforme: String? = nil,
        frequenceMinutes: Int = 60,
        active: Bool = true,
        motsClesPriorite: [String] = [],
        derniereExecution: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.titre = titre
        self.motsCles = motsCles
        self.urlSource = urlSource
        self.plateforme = plateforme
        self.frequenceMinutes = frequenceMinutes
        self.active = active
        self.motsClesPriorite = motsClesPriorite
        self.derniereExecution = derniereExecution
    }
}

/// Résultat brut d'une exécution de veille, en attente de traitement (Capitaliser).
public struct ElementVeille: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var veilleId: UUID
    public var url: String
    public var titre: String
    public var contenu: String
    public var datePublication: Date?
    public var dateCollecte: Date
    public var hashContenu: String
    public var sourceId: UUID?
    public var cotationSource: FiabiliteSource?
    public var statut: StatutTraitement

    public init(
        id: UUID = UUID(),
        veilleId: UUID,
        url: String,
        titre: String,
        contenu: String,
        datePublication: Date? = nil,
        dateCollecte: Date = Date(),
        hashContenu: String,
        sourceId: UUID? = nil,
        cotationSource: FiabiliteSource? = nil,
        statut: StatutTraitement = .nonTraite
    ) {
        self.id = id
        self.veilleId = veilleId
        self.url = url
        self.titre = titre
        self.contenu = contenu
        self.datePublication = datePublication
        self.dateCollecte = dateCollecte
        self.hashContenu = hashContenu
        self.sourceId = sourceId
        self.cotationSource = cotationSource
        self.statut = statut
    }
}

/// Regroupement d'informations de veille relatives à un même événement.
public struct RegroupementEvenement: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var titre: String
    public var resume: String
    public var cotation: CotationOTAN?
    public var elementIds: [UUID]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        titre: String,
        resume: String,
        cotation: CotationOTAN? = nil,
        elementIds: [UUID] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.titre = titre
        self.resume = resume
        self.cotation = cotation
        self.elementIds = elementIds
        self.createdAt = createdAt
    }
}

/// Proposition de doublon entre deux entités ou deux documents.
public enum StatutDoublon: String, Codable, Sendable {
    case propose
    case valide
    case refuse
}

/// Proposition de doublon soumise à validation humaine explicite.
public struct PropositionDoublon: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var idA: UUID
    public var idB: UUID
    public var score: Double
    public var statut: StatutDoublon
    public var dateDecision: Date?

    public init(
        id: UUID = UUID(),
        idA: UUID,
        idB: UUID,
        score: Double,
        statut: StatutDoublon = .propose,
        dateDecision: Date? = nil
    ) {
        self.id = id
        self.idA = idA
        self.idB = idB
        self.score = score
        self.statut = statut
        self.dateDecision = dateDecision
    }
}

/// Entrée de l'historique des modifications d'une fiche.
public struct VersionEntite: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var entiteId: UUID
    public var date: Date
    public var champsModifies: [String]
    public var appareil: String

    public init(
        id: UUID = UUID(),
        entiteId: UUID,
        date: Date = Date(),
        champsModifies: [String],
        appareil: String
    ) {
        self.id = id
        self.entiteId = entiteId
        self.date = date
        self.champsModifies = champsModifies
        self.appareil = appareil
    }
}

/// Source d'information référencée (site, personne, canal…), cotée A–F.
public struct SourceInfo: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var denomination: String
    public var descriptionSource: String?
    public var cotation: FiabiliteSource?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        denomination: String,
        descriptionSource: String? = nil,
        cotation: FiabiliteSource? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.denomination = denomination
        self.descriptionSource = descriptionSource
        self.cotation = cotation
        self.createdAt = createdAt
    }
}
