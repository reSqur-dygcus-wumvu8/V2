import Foundation
import GRDB
import PackageDomain

/// Conformances GRDB des types du Domain : colonnes explicites, encodage
/// JSON pour les champs listes, les cotations stockées en colonnes séparées.

extension Entite: TableRecord, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "entite"

    public enum Columns {
        static let id = Column("id")
        static let type = Column("type")
        static let denomination = Column("denomination")
        static let prenom = Column("prenom")
        static let nom = Column("nom")
        static let typeOrganisation = Column("typeOrganisation")
        static let typeObjet = Column("typeObjet")
        static let precisions = Column("precisions")
        static let dateHeure = Column("dateHeure")
        static let adresse = Column("adresse")
        static let latitude = Column("latitude")
        static let longitude = Column("longitude")
        static let resume = Column("resume")
        static let biographie = Column("biographie")
        static let commentaires = Column("commentaires")
        static let cotationSource = Column("cotationSource")
        static let createdAt = Column("createdAt")
        static let updatedAt = Column("updatedAt")
    }

    public func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id.uuidString
        container[Columns.type] = type.rawValue
        container[Columns.denomination] = denomination
        container[Columns.prenom] = prenom
        container[Columns.nom] = nom
        container[Columns.typeOrganisation] = typeOrganisation
        container[Columns.typeObjet] = typeObjet
        container[Columns.precisions] = precisions
        container[Columns.dateHeure] = dateHeure
        container[Columns.adresse] = adresse
        container[Columns.latitude] = latitude
        container[Columns.longitude] = longitude
        container[Columns.resume] = resume
        container[Columns.biographie] = biographie
        container[Columns.commentaires] = commentaires
        container[Columns.cotationSource] = cotationSource?.rawValue
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
    }

    public init(row: Row) {
        id = UUID(uuidString: row[Columns.id]) ?? UUID()
        type = TypeEntite(rawValue: row[Columns.type] ?? "") ?? .individu
        denomination = row[Columns.denomination] ?? ""
        prenom = row[Columns.prenom]
        nom = row[Columns.nom]
        typeOrganisation = row[Columns.typeOrganisation]
        typeObjet = row[Columns.typeObjet]
        precisions = row[Columns.precisions]
        dateHeure = row[Columns.dateHeure]
        adresse = row[Columns.adresse]
        latitude = row[Columns.latitude]
        longitude = row[Columns.longitude]
        resume = row[Columns.resume]
        biographie = row[Columns.biographie]
        commentaires = row[Columns.commentaires]
        cotationSource = row[Columns.cotationSource].flatMap(FiabiliteSource.init(rawValue:))
        createdAt = row[Columns.createdAt] ?? Date()
        updatedAt = row[Columns.updatedAt] ?? Date()
    }
}

extension ElementVeille: TableRecord, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "elementVeille"

    public enum Columns {
        static let id = Column("id")
        static let veilleId = Column("veilleId")
        static let url = Column("url")
        static let titre = Column("titre")
        static let contenu = Column("contenu")
        static let datePublication = Column("datePublication")
        static let dateCollecte = Column("dateCollecte")
        static let hashContenu = Column("hashContenu")
        static let sourceId = Column("sourceId")
        static let cotationSource = Column("cotationSource")
        static let statut = Column("statut")
    }

    public func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id.uuidString
        container[Columns.veilleId] = veilleId.uuidString
        container[Columns.url] = url
        container[Columns.titre] = titre
        container[Columns.contenu] = contenu
        container[Columns.datePublication] = datePublication
        container[Columns.dateCollecte] = dateCollecte
        container[Columns.hashContenu] = hashContenu
        container[Columns.sourceId] = sourceId?.uuidString
        container[Columns.cotationSource] = cotationSource?.rawValue
        container[Columns.statut] = statut.rawValue
    }

    public init(row: Row) {
        id = UUID(uuidString: row[Columns.id]) ?? UUID()
        veilleId = UUID(uuidString: row[Columns.veilleId]) ?? UUID()
        url = row[Columns.url] ?? ""
        titre = row[Columns.titre] ?? ""
        contenu = row[Columns.contenu] ?? ""
        datePublication = row[Columns.datePublication]
        dateCollecte = row[Columns.dateCollecte] ?? Date()
        hashContenu = row[Columns.hashContenu] ?? ""
        sourceId = row[Columns.sourceId].flatMap(UUID.init(uuidString:))
        cotationSource = row[Columns.cotationSource].flatMap(FiabiliteSource.init(rawValue:))
        statut = StatutTraitement(rawValue: row[Columns.statut] ?? "") ?? .nonTraite
    }
}

extension Document: TableRecord, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "document"

    public enum Columns {
        static let id = Column("id")
        static let nom = Column("nom")
        static let dateImport = Column("dateImport")
        static let typeMime = Column("typeMime")
        static let cheminFichier = Column("cheminFichier")
        static let hashSHA256 = Column("hashSHA256")
        static let texteExtrait = Column("texteExtrait")
        static let cotationSource = Column("cotationSource")
        static let cotationInfo = Column("cotationInfo")
        static let statut = Column("statut")
        static let sourceId = Column("sourceId")
        static let urlOrigine = Column("urlOrigine")
    }

    public func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id.uuidString
        container[Columns.nom] = nom
        container[Columns.dateImport] = dateImport
        container[Columns.typeMime] = typeMime
        container[Columns.cheminFichier] = cheminFichier
        container[Columns.hashSHA256] = hashSHA256
        container[Columns.texteExtrait] = texteExtrait
        container[Columns.cotationSource] = cotation?.fiabiliteSource.rawValue
        container[Columns.cotationInfo] = cotation?.credibiliteInfo.rawValue
        container[Columns.statut] = statut.rawValue
        container[Columns.sourceId] = sourceId.uuidString
        container[Columns.urlOrigine] = urlOrigine
    }

    public init(row: Row) {
        id = UUID(uuidString: row[Columns.id]) ?? UUID()
        nom = row[Columns.nom] ?? ""
        dateImport = row[Columns.dateImport] ?? Date()
        typeMime = row[Columns.typeMime] ?? ""
        cheminFichier = row[Columns.cheminFichier]
        hashSHA256 = row[Columns.hashSHA256] ?? ""
        texteExtrait = row[Columns.texteExtrait]
        let fiabilite: FiabiliteSource? = row[Columns.cotationSource].flatMap(FiabiliteSource.init(rawValue:))
        let credibilite: CredibiliteInfo? = row[Columns.cotationInfo].flatMap(CredibiliteInfo.init(rawValue:))
        cotation = fiabilite.flatMap { f in credibilite.map { CotationOTAN(fiabiliteSource: f, credibiliteInfo: $0) } }
        statut = StatutTraitement(rawValue: row[Columns.statut] ?? "") ?? .nonTraite
        sourceId = UUID(uuidString: row[Columns.sourceId]) ?? UUID()
        urlOrigine = row[Columns.urlOrigine]
    }
}

extension Veille: TableRecord, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "veille"

    public enum Columns {
        static let id = Column("id")
        static let type = Column("type")
        static let titre = Column("titre")
        static let motsCles = Column("motsCles")
        static let urlSource = Column("urlSource")
        static let plateforme = Column("plateforme")
        static let frequenceMinutes = Column("frequenceMinutes")
        static let active = Column("active")
        static let motsClesPriorite = Column("motsClesPriorite")
        static let derniereExecution = Column("derniereExecution")
    }

    public func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id.uuidString
        container[Columns.type] = type.rawValue
        container[Columns.titre] = titre
        container[Columns.motsCles] = Self.json(motsCles)
        container[Columns.urlSource] = urlSource
        container[Columns.plateforme] = plateforme
        container[Columns.frequenceMinutes] = frequenceMinutes
        container[Columns.active] = active
        container[Columns.motsClesPriorite] = Self.json(motsClesPriorite)
        container[Columns.derniereExecution] = derniereExecution
    }

    public init(row: Row) {
        id = UUID(uuidString: row[Columns.id]) ?? UUID()
        type = TypeVeille(rawValue: row[Columns.type] ?? "") ?? .rss
        titre = row[Columns.titre] ?? ""
        motsCles = Self.depuisJSON(row[Columns.motsCles] ?? "[]")
        urlSource = row[Columns.urlSource]
        plateforme = row[Columns.plateforme]
        frequenceMinutes = row[Columns.frequenceMinutes] ?? 60
        active = row[Columns.active] ?? true
        motsClesPriorite = Self.depuisJSON(row[Columns.motsClesPriorite] ?? "[]")
        derniereExecution = row[Columns.derniereExecution]
    }

    private static func json(_ liste: [String]) -> String {
        let data = (try? JSONEncoder().encode(liste)) ?? Data("[]".utf8)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private static func depuisJSON(_ texte: String) -> [String] {
        (try? JSONDecoder().decode([String].self, from: Data(texte.utf8))) ?? []
    }
}

extension SourceInfo: TableRecord, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "sourceInfo"

    public enum Columns {
        static let id = Column("id")
        static let denomination = Column("denomination")
        static let descriptionSource = Column("descriptionSource")
        static let cotation = Column("cotation")
        static let createdAt = Column("createdAt")
    }

    public func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id.uuidString
        container[Columns.denomination] = denomination
        container[Columns.descriptionSource] = descriptionSource
        container[Columns.cotation] = cotation?.rawValue
        container[Columns.createdAt] = createdAt
    }

    public init(row: Row) {
        id = UUID(uuidString: row[Columns.id]) ?? UUID()
        denomination = row[Columns.denomination] ?? ""
        descriptionSource = row[Columns.descriptionSource]
        cotation = row[Columns.cotation].flatMap(FiabiliteSource.init(rawValue:))
        createdAt = row[Columns.createdAt] ?? Date()
    }
}
