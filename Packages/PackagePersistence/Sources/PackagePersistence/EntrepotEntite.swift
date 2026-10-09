import Foundation
import GRDB
import PackageDomain

/// Entrepôt des entités de la base de connaissance.
public struct EntrepotEntite: Sendable {

    let pool: DatabasePool

    public init(pool: DatabasePool) {
        self.pool = pool
    }

    /// Enregistre une entité (création ou modification).
    public func enregistrer(_ entite: Entite) throws {
        try pool.write { db in
            try entite.save(db)
        }
    }

    /// Liste les entités non supprimées, triées par dénomination.
    public func toutes() throws -> [Entite] {
        try pool.read { db in
            try Entite
                .filter(Column("supprime") == false)
                .order(Column("denomination"))
                .fetchAll(db)
        }
    }

    /// Entités d'un type donné.
    public func parType(_ type: TypeEntite) throws -> [Entite] {
        try pool.read { db in
            try Entite
                .filter(Column("supprime") == false && Column("type") == type.rawValue)
                .order(Column("denomination"))
                .fetchAll(db)
        }
    }

    /// Recherche par identifiant.
    public func chercher(id: UUID) throws -> Entite? {
        try pool.read { db in
            try Entite.filter(Column("id") == id.uuidString).fetchOne(db)
        }
    }

    /// Recherche par dénomination exacte.
    public func chercher(denomination: String) throws -> Entite? {
        try pool.read { db in
            try Entite
                .filter(Column("supprime") == false && Column("denomination") == denomination)
                .fetchOne(db)
        }
    }

    /// Marque une entité supprimée (tombstone, jamais d'effacement physique).
    public func supprimer(_ id: UUID) throws {
        try pool.write { db in
            try db.execute(
                sql: "UPDATE entite SET supprime = 1, updatedAt = ? WHERE id = ?",
                arguments: [Date(), id.uuidString]
            )
        }
    }

    /// Enregistre une relation entre deux entités (idempotent).
    public func relier(_ relation: RelationEntites) throws {
        try pool.write { db in
            try relation.save(db)
        }
    }

    /// Relations sortantes et entrantes d'une entité (rang 1 du graphe).
    public func relations(id: UUID) throws -> [RelationEntites] {
        try pool.read { db in
            let sortantes = try RelationEntites.filter(Column("idSource") == id.uuidString).fetchAll(db)
            let entrantes = try RelationEntites.filter(Column("idCible") == id.uuidString).fetchAll(db)
            return sortantes + entrantes
        }
    }

    /// Historique des modifications d'une fiche, plus récent en premier.
    public func historique(entiteId: UUID) throws -> [VersionEntite] {
        try pool.read { db in
            try VersionEntite
                .filter(Column("entiteId") == entiteId.uuidString)
                .order(Column("date").desc)
                .fetchAll(db)
        }
    }

    /// Journalise une modification de fiche.
    public func journaliser(_ version: VersionEntite) throws {
        try pool.write { db in
            try version.save(db)
        }
    }

    /// Rattache un document à une entité (lien N-N).
    public func rattacherDocument(documentId: UUID, entiteId: UUID) throws {
        try pool.write { db in
            try db.execute(
                sql: "INSERT OR IGNORE INTO documentEntite (documentId, entiteId) VALUES (?, ?)",
                arguments: [documentId.uuidString, entiteId.uuidString]
            )
        }
    }
}

extension RelationEntites: TableRecord, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "relationEntites"

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id.uuidString
        container["idSource"] = idSource.uuidString
        container["idCible"] = idCible.uuidString
        container["typeRelation"] = typeRelation
        container["cotationSource"] = cotation?.fiabiliteSource.rawValue
        container["cotationInfo"] = cotation?.credibiliteInfo.rawValue
        container["documentId"] = documentId?.uuidString
        container["createdAt"] = createdAt
    }

    public init(row: Row) {
        id = UUID(uuidString: row["id"]) ?? UUID()
        idSource = UUID(uuidString: row["idSource"]) ?? UUID()
        idCible = UUID(uuidString: row["idCible"]) ?? UUID()
        typeRelation = row["typeRelation"] ?? ""
        let f: FiabiliteSource? = row["cotationSource"].flatMap(FiabiliteSource.init(rawValue:))
        let c: CredibiliteInfo? = row["cotationInfo"].flatMap(CredibiliteInfo.init(rawValue:))
        cotation = f.flatMap { cotation in c.map { CotationOTAN(fiabiliteSource: cotation, credibiliteInfo: $0) } }
        documentId = row["documentId"].flatMap(UUID.init(uuidString:))
        createdAt = row["createdAt"] ?? Date()
    }
}

extension VersionEntite: TableRecord, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "versionEntite"

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id.uuidString
        container["entiteId"] = entiteId.uuidString
        container["date"] = date
        container["champsModifies"] = champsModifies.joined(separator: ",")
        container["appareil"] = appareil
    }

    public init(row: Row) {
        id = UUID(uuidString: row["id"]) ?? UUID()
        entiteId = UUID(uuidString: row["entiteId"]) ?? UUID()
        date = row["date"] ?? Date()
        champsModifies = (row["champsModifies"] as String?).map {
            $0.components(separatedBy: ",").filter { !$0.isEmpty }
        } ?? []
        appareil = row["appareil"] ?? ""
    }
}

extension RegroupementEvenement: TableRecord, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "regroupementEvenement"

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id.uuidString
        container["titre"] = titre
        container["resume"] = resume
        container["cotationSource"] = cotation?.fiabiliteSource.rawValue
        container["cotationInfo"] = cotation?.credibiliteInfo.rawValue
        container["elementIds"] = elementIds.map(\.uuidString).joined(separator: ",")
        container["createdAt"] = createdAt
    }

    public init(row: Row) {
        id = UUID(uuidString: row["id"]) ?? UUID()
        titre = row["titre"] ?? ""
        resume = row["resume"] ?? ""
        let f: FiabiliteSource? = row["cotationSource"].flatMap(FiabiliteSource.init(rawValue:))
        let c: CredibiliteInfo? = row["cotationInfo"].flatMap(CredibiliteInfo.init(rawValue:))
        cotation = f.flatMap { cotation in c.map { CotationOTAN(fiabiliteSource: cotation, credibiliteInfo: $0) } }
        elementIds = (row["elementIds"] as String?).map {
            $0.components(separatedBy: ",").compactMap(UUID.init(uuidString:))
        } ?? []
        createdAt = row["createdAt"] ?? Date()
    }
}

extension PropositionDoublon: TableRecord, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "propositionDoublon"

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id.uuidString
        container["idA"] = idA.uuidString
        container["idB"] = idB.uuidString
        container["score"] = score
        container["statut"] = statut.rawValue
        container["dateDecision"] = dateDecision
    }

    public init(row: Row) {
        id = UUID(uuidString: row["id"]) ?? UUID()
        idA = UUID(uuidString: row["idA"]) ?? UUID()
        idB = UUID(uuidString: row["idB"]) ?? UUID()
        score = row["score"] ?? 0
        statut = StatutDoublon(rawValue: row["statut"] ?? "") ?? .propose
        dateDecision = row["dateDecision"]
    }
}

/// Entrepôt des regroupements d'événements (capitalisation de la veille).
public struct EntrepotRegroupement: Sendable {

    let pool: DatabasePool

    public init(pool: DatabasePool) {
        self.pool = pool
    }

    /// Enregistre un regroupement.
    public func enregistrer(_ regroupement: RegroupementEvenement) throws {
        try pool.write { db in
            try regroupement.save(db)
        }
    }

    /// Liste tous les regroupements, plus récents en premier.
    public func tous() throws -> [RegroupementEvenement] {
        try pool.read { db in
            try RegroupementEvenement.order(Column("createdAt").desc).fetchAll(db)
        }
    }

    /// Supprime un regroupement.
    public func supprimer(_ id: UUID) throws {
        try pool.write { db in
            try RegroupementEvenement.deleteOne(db, key: id.uuidString)
        }
    }
}
