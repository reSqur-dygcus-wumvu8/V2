import Foundation
import GRDB
import PackageDomain

/// Service d'accès à la base de données locale chiffrée (GRDB + SQLCipher).
/// La DEK (clé des données) enveloppée par la KEK est lue dans le trousseau ;
/// la clé de session délivrée par le Gestionnaire d'accès permet de la déballer.
public final class BaseDonneesService: Sendable {

    /// Pool de connexions à la base chiffrée.
    public let pool: DatabasePool

    /// Emplacement de la base sur disque.
    public let cheminBase: String

    /// Ouvre (ou crée) la base chiffrée avec la passphrase SQLCipher fournie.
    /// - Parameters:
    ///   - cheminBase: chemin du fichier .sqlite.
    ///   - passphrase: DEK déballée, utilisée comme passphrase SQLCipher.
    public init(cheminBase: String, passphrase: String) throws {
        self.cheminBase = cheminBase
        var config = Configuration()
        config.passphrase = passphrase
        self.pool = try DatabasePool(path: cheminBase, configuration: config)
        try Self.appliquerMigrations(pool: pool)
    }

    /// Base temporaire en mémoire pour les tests et les prévisualisations.
    public static func baseMemoire(passphrase: String = "test") throws -> BaseDonneesService {
        try BaseDonneesService(cheminBase: ":memory:", passphrase: passphrase)
    }

    // MARK: - Panic wipe

    /// Effacement complet des données : base, fichiers binaires chiffrés
    /// et entrées trousseau du service applicatif.
    public static func panicWipe(
        cheminBase: String,
        dossierBinaires: String,
        keychain: KeychainStore
    ) throws {
        try? FileManager.default.removeItem(atPath: cheminBase)
        try? FileManager.default.removeItem(atPath: cheminBase + "-wal")
        try? FileManager.default.removeItem(atPath: cheminBase + "-shm")
        try? FileManager.default.removeItem(atPath: dossierBinaires)
        try keychain.toutSupprimer()
    }

    // MARK: - Migrations

    /// Applique l'ensemble des migrations du schéma (idempotent).
    private static func appliquerMigrations(pool: DatabasePool) throws {
        var migrator = DatabaseMigrator()

        // v1 — schéma initial complet.
        migrator.registerMigration("v1_schema_initial") { db in
            try db.create(table: "sourceInfo") { t in
                t.autoIncrementedPrimaryKey("rowid")
                t.column("id", .text).notNull().unique()
                t.column("denomination", .text).notNull()
                t.column("descriptionSource", .text)
                t.column("cotation", .text)
                t.column("createdAt", .datetime).notNull()
            }

            try db.create(table: "document") { t in
                t.autoIncrementedPrimaryKey("rowid")
                t.column("id", .text).notNull().unique()
                t.column("nom", .text).notNull()
                t.column("dateImport", .datetime).notNull()
                t.column("typeMime", .text).notNull()
                t.column("cheminFichier", .text)
                t.column("hashSHA256", .text).notNull()
                t.column("texteExtrait", .text)
                t.column("cotationSource", .text)
                t.column("cotationInfo", .integer)
                t.column("statut", .text).notNull()
                t.column("sourceId", .text).notNull().references("sourceInfo")
                t.column("urlOrigine", .text)
            }

            try db.create(table: "veille") { t in
                t.autoIncrementedPrimaryKey("rowid")
                t.column("id", .text).notNull().unique()
                t.column("type", .text).notNull()
                t.column("titre", .text).notNull()
                t.column("motsCles", .text).notNull()
                t.column("urlSource", .text)
                t.column("plateforme", .text)
                t.column("frequenceMinutes", .integer).notNull()
                t.column("active", .boolean).notNull()
                t.column("motsClesPriorite", .text).notNull()
                t.column("derniereExecution", .datetime)
            }

            try db.create(table: "elementVeille") { t in
                t.autoIncrementedPrimaryKey("rowid")
                t.column("id", .text).notNull().unique()
                t.column("veilleId", .text).notNull().references("veille")
                t.column("url", .text).notNull()
                t.column("titre", .text).notNull()
                t.column("contenu", .text).notNull()
                t.column("datePublication", .datetime)
                t.column("dateCollecte", .datetime).notNull()
                t.column("hashContenu", .text).notNull()
                t.column("sourceId", .text)
                t.column("cotationSource", .text)
                t.column("statut", .text).notNull()
            }
            try db.create(index: "idx_elementVeille_hash", on: "elementVeille", columns: ["hashContenu"])

            try db.create(table: "entite") { t in
                t.autoIncrementedPrimaryKey("rowid")
                t.column("id", .text).notNull().unique()
                t.column("type", .text).notNull()
                t.column("denomination", .text).notNull()
                t.column("prenom", .text)
                t.column("nom", .text)
                t.column("typeOrganisation", .text)
                t.column("typeObjet", .text)
                t.column("precisions", .text)
                t.column("dateHeure", .datetime)
                t.column("adresse", .text)
                t.column("latitude", .double)
                t.column("longitude", .double)
                t.column("resume", .text)
                t.column("biographie", .text)
                t.column("commentaires", .text)
                t.column("cotationSource", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("supprime", .boolean).notNull().default(false)
            }
            try db.create(index: "idx_entite_type", on: "entite", columns: ["type"])

            try db.create(table: "relationEntites") { t in
                t.autoIncrementedPrimaryKey("rowid")
                t.column("id", .text).notNull().unique()
                t.column("idSource", .text).notNull().references("entite")
                t.column("idCible", .text).notNull().references("entite")
                t.column("typeRelation", .text).notNull()
                t.column("cotationSource", .text)
                t.column("cotationInfo", .integer)
                t.column("documentId", .text)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(index: "idx_relation_source", on: "relationEntites", columns: ["idSource"])
            try db.create(index: "idx_relation_cible", on: "relationEntites", columns: ["idCible"])

            try db.create(table: "regroupementEvenement") { t in
                t.autoIncrementedPrimaryKey("rowid")
                t.column("id", .text).notNull().unique()
                t.column("titre", .text).notNull()
                t.column("resume", .text).notNull()
                t.column("cotationSource", .text)
                t.column("cotationInfo", .integer)
                t.column("elementIds", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }

            try db.create(table: "documentEntite") { t in
                t.column("documentId", .text).notNull().references("document")
                t.column("entiteId", .text).notNull().references("entite")
                t.primaryKey(["documentId", "entiteId"])
            }

            try db.create(table: "propositionDoublon") { t in
                t.autoIncrementedPrimaryKey("rowid")
                t.column("id", .text).notNull().unique()
                t.column("idA", .text).notNull()
                t.column("idB", .text).notNull()
                t.column("score", .double).notNull()
                t.column("statut", .text).notNull()
                t.column("dateDecision", .datetime)
            }

            try db.create(table: "versionEntite") { t in
                t.autoIncrementedPrimaryKey("rowid")
                t.column("id", .text).notNull().unique()
                t.column("entiteId", .text).notNull().references("entite")
                t.column("date", .datetime).notNull()
                t.column("champsModifies", .text).notNull()
                t.column("appareil", .text).notNull()
            }

            try db.create(table: "parametres") { t in
                t.column("cle", .text).primaryKey()
                t.column("valeur", .text).notNull()
            }
        }

        // v2 — recherche plein texte FTS5 sur entités et documents.
        migrator.registerMigration("v2_fts") { db in
            try db.create(table: "fts_entite") { t in
                t.synchronized(with: "entite")
                t.tokenizer = .porter(language: .french)
                t.column("denomination")
                t.column("resume")
                t.column("biographie")
                t.column("commentaires")
            }
            try db.create(table: "fts_document") { t in
                t.synchronized(with: "document")
                t.tokenizer = .porter(language: .french)
                t.column("nom")
                t.column("texteExtrait")
            }
        }

        // v3 — journal d'exécution des veilles.
        migrator.registerMigration("v3_journal_execution") { db in
            try db.create(table: "executionJournal") { t in
                t.autoIncrementedPrimaryKey("rowid")
                t.column("id", .text).notNull().unique()
                t.column("veilleId", .text).notNull().references("veille")
                t.column("date", .datetime).notNull()
                t.column("succes", .boolean).notNull()
                t.column("nbNouveaux", .integer).notNull()
                t.column("message", .text).notNull()
            }
            try db.create(index: "idx_journal_veille", on: "executionJournal", columns: ["veilleId"])
        }

        // v4 — journal des fusions.
        migrator.registerMigration("v4_journal_fusion") { db in
            try db.create(table: "fusionJournal") { t in
                t.autoIncrementedPrimaryKey("rowid")
                t.column("id", .text)
                t.column("entiteGardee", .text).notNull()
                t.column("entiteFusionnee", .text).notNull()
                t.column("champsChoisis", .text).notNull()
                t.column("date", .datetime).notNull()
            }
        }

        try migrator.migrate(pool)
    }
}
