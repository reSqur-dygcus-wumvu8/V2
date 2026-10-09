import Foundation
import GRDB
import PackageDomain

/// Entrepôt des éléments de veille : insertion dédupliquée (hash déjà vu),
/// file d'attente des éléments non traités, marquage du traitement.
public struct EntrepotElementVeille: Sendable {

    let pool: DatabasePool

    public init(pool: DatabasePool) {
        self.pool = pool
    }

    /// Insère les éléments nouveaux (hash non déjà présent) et retourne
    /// ceux effectivement insérés.
    public func insererNouveaux(_ elements: [ElementVeille]) throws -> [ElementVeille] {
        var inseres: [ElementVeille] = []
        try pool.write { db in
            for var element in elements {
                let dejaVu = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM elementVeille WHERE hashContenu = ?",
                    arguments: [element.hashContenu]
                ) ?? 0
                if dejaVu == 0 {
                    try element.insert(db)
                    inseres.append(element)
                }
            }
        }
        return inseres
    }

    /// File d'attente chronologique des éléments non traités (module Capitaliser).
    public func fileAttente() throws -> [ElementVeille] {
        try pool.read { db in
            try ElementVeille
                .filter(Column("statut") == StatutTraitement.nonTraite.rawValue)
                .order(Column("dateCollecte").desc)
                .fetchAll(db)
        }
    }

    /// Hashes déjà collectés pour une veille (déduplication à l'exécution).
    public func hashesVus(veilleId: UUID) throws -> Set<String> {
        let hashes: [String] = try pool.read { db in
            try String.fetchAll(db, sql: "SELECT hashContenu FROM elementVeille WHERE veilleId = ?", arguments: [veilleId.uuidString])
        }
        return Set(hashes)
    }

    /// Marque un élément comme traité (capitalisé ou ignoré).
    public func marquerTraite(_ id: UUID, statut: StatutTraitement) throws {
        try pool.write { db in
            try db.execute(
                sql: "UPDATE elementVeille SET statut = ? WHERE id = ?",
                arguments: [statut.rawValue, id.uuidString]
            )
        }
    }
}

/// Entrepôt des documents importés (module Acquérir).
public struct EntrepotDocument: Sendable {

    let pool: DatabasePool

    public init(pool: DatabasePool) {
        self.pool = pool
    }

    /// Insère un document ; retourne false si un document avec le même hash
    /// existe déjà (doublon d'import).
    @discardableResult
    public func inserer(_ document: Document) throws -> Bool {
        try pool.write { db in
            let dejaVu = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM document WHERE hashSHA256 = ?",
                arguments: [document.hashSHA256]
            ) ?? 0
            guard dejaVu == 0 else { return false }
            try document.insert(db)
            return true
        }
    }

    /// Liste tous les documents.
    public func tous() throws -> [Document] {
        try pool.read { db in
            try Document.order(Column("dateImport").desc).fetchAll(db)
        }
    }

    /// Recherche plein texte (FTS5) sur les documents.
    public func rechercher(texte: String) throws -> [Document] {
        let motif = "\"\(texte.replacingOccurrences(of: "\"", with: ""))*\""
        return try pool.read { db in
            try Document
                .joining(
                    required: Document
                        .aliased("d")
                        .matching(TableRecord.filter(key: ["rowid"]))
                )
                .filter(sql: "rowid IN (SELECT rowid FROM fts_document WHERE fts_document MATCH ?)", arguments: [motif])
                .fetchAll(db)
        }
    }
}

/// Entrepôt des veilles (configuration) et de leur journal d'exécution.
public struct EntrepotVeille: Sendable {

    let pool: DatabasePool

    public init(pool: DatabasePool) {
        self.pool = pool
    }

    /// Liste les veilles actives (celles à exécuter périodiquement).
    public func actives() throws -> [Veille] {
        try pool.read { db in
            try Veille.filter(Column("active") == true).fetchAll(db)
        }
    }

    /// Liste toutes les veilles.
    public func toutes() throws -> [Veille] {
        try pool.read { db in
            try Veille.order(Column("titre")).fetchAll(db)
        }
    }

    /// Enregistre une veille (création ou modification).
    public func enregistrer(_ veille: Veille) throws {
        try pool.write { db in
            try veille.save(db)
        }
    }

    /// Supprime une veille et son journal.
    public func supprimer(_ id: UUID) throws {
        try pool.write { db in
            try db.execute(sql: "DELETE FROM elementVeille WHERE veilleId = ?", arguments: [id.uuidString])
            try Veille.deleteOne(db, key: id.uuidString)
        }
    }

    /// Journalise une exécution de veille (succès ou échec).
    public func journaliser(_ resultat: ResultatJournal) throws {
        try pool.write { db in
            try resultat.insert(db)
            try db.execute(
                sql: "UPDATE veille SET derniereExecution = ? WHERE id = ?",
                arguments: [resultat.date, resultat.veilleId.uuidString]
            )
        }
    }

    /// Journal d'exécution d'une veille, plus récent en premier.
    public func journal(veilleId: UUID) throws -> [ResultatJournal] {
        try pool.read { db in
            try ResultatJournal
                .filter(Column("veilleId") == veilleId.uuidString)
                .order(Column("date").desc)
                .fetchAll(db)
        }
    }
}

/// Entrée du journal d'exécution d'une veille.
public struct ResultatJournal: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID?
    public var veilleId: UUID
    public var date: Date
    public var succes: Bool
    public var nbNouveaux: Int
    public var message: String

    public init(id: UUID? = nil, veilleId: UUID, date: Date, succes: Bool, nbNouveaux: Int, message: String) {
        self.id = id
        self.veilleId = veilleId
        self.date = date
        self.succes = succes
        self.nbNouveaux = nbNouveaux
        self.message = message
    }
}

extension ResultatJournal: TableRecord, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "executionJournal"

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

/// Entrepôt des sources d'information.
public struct EntrepotSource: Sendable {

    let pool: DatabasePool

    public init(pool: DatabasePool) {
        self.pool = pool
    }

    /// Enregistre une source (création ou modification).
    public func enregistrer(_ source: SourceInfo) throws {
        try pool.write { db in
            try source.save(db)
        }
    }

    /// Liste toutes les sources.
    public func toutes() throws -> [SourceInfo] {
        try pool.read { db in
            try SourceInfo.order(Column("denomination")).fetchAll(db)
        }
    }

    /// Recherche une source par dénomination exacte (normalisée).
    public func chercher(denomination: String) throws -> SourceInfo? {
        try pool.read { db in
            try SourceInfo
                .filter(Column("denomination") == denomination)
                .fetchOne(db)
        }
    }
}
