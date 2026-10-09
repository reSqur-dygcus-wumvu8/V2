import Foundation
import GRDB
import PackageDomain

/// Entrepôt des propositions de doublons et du journal de fusion.
public struct EntrepotDoublon: Sendable {

    let pool: DatabasePool

    public init(pool: DatabasePool) {
        self.pool = pool
    }

    /// Enregistre une proposition de doublon (création ou mise à jour).
    public func enregistrer(_ proposition: PropositionDoublon) throws {
        try pool.write { db in
            try proposition.save(db)
        }
    }

    /// Propositions en attente de validation humaine.
    public func enAttente() throws -> [PropositionDoublon] {
        try pool.read { db in
            try PropositionDoublon
                .filter(Column("statut") == StatutDoublon.propose.rawValue)
                .order(Column("score").desc)
                .fetchAll(db)
        }
    }

    /// Toutes les paires déjà refusées (pour ne jamais les reproposer).
    public func refusees() throws -> Set<PaireUUID> {
        let paires: [PropositionDoublon] = try pool.read { db in
            try PropositionDoublon
                .filter(Column("statut") == StatutDoublon.refuse.rawValue)
                .fetchAll(db)
        }
        return Set(paires.map { PaireUUID($0.idA, $0.idB) })
    }

    /// Décision humaine explicite sur une proposition.
    public func decider(_ id: UUID, statut: StatutDoublon, date: Date = Date()) throws {
        try pool.write { db in
            try db.execute(
                sql: "UPDATE propositionDoublon SET statut = ?, dateDecision = ? WHERE id = ?",
                arguments: [statut.rawValue, date, id.uuidString]
            )
        }
    }

    /// Journalise une fusion effectuée (traçabilité).
    public func journaliserFusion(_ entree: EntreeFusion) throws {
        try pool.write { db in
            try entree.save(db)
        }
    }

    /// Journal complet des fusions, plus récentes en premier.
    public func journalFusions() throws -> [EntreeFusion] {
        try pool.read { db in
            try EntreeFusion.order(Column("date").desc).fetchAll(db)
        }
    }
}

/// Paire non ordonnée d'identifiants (une paire refusée n'est jamais reproposée,
/// quel que soit l'ordre des extrémités).
public struct PaireUUID: Hashable, Sendable {
    public let a: UUID
    public let b: UUID

    public init(_ a: UUID, _ b: UUID) {
        self.a = a < b ? a : b
        self.b = a < b ? b : a
    }
}

/// Entrée du journal de fusion : entité conservée, entité absorbée,
/// champs choisis, date.
public struct EntreeFusion: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID?
    public var entiteGardee: UUID
    public var entiteFusionnee: UUID
    public var champsChoisis: [String]
    public var date: Date

    public init(
        id: UUID? = nil,
        entiteGardee: UUID,
        entiteFusionnee: UUID,
        champsChoisis: [String],
        date: Date = Date()
    ) {
        self.id = id
        self.entiteGardee = entiteGardee
        self.entiteFusionnee = entiteFusionnee
        self.champsChoisis = champsChoisis
        self.date = date
    }
}

extension EntreeFusion: TableRecord, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "fusionJournal"

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id?.uuidString
        container["entiteGardee"] = entiteGardee.uuidString
        container["entiteFusionnee"] = entiteFusionnee.uuidString
        container["champsChoisis"] = champsChoisis.joined(separator: ",")
        container["date"] = date
    }

    public init(row: Row) {
        id = (row["id"] as String?).flatMap(UUID.init(uuidString:))
        entiteGardee = UUID(uuidString: row["entiteGardee"] ?? "") ?? UUID()
        entiteFusionnee = UUID(uuidString: row["entiteFusionnee"] ?? "") ?? UUID()
        champsChoisis = (row["champsChoisis"] as String?).map {
            $0.components(separatedBy: ",").filter { !$0.isEmpty }
        } ?? []
        date = row["date"] ?? Date()
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
