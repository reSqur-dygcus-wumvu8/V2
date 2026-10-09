import XCTest
import PackageDomain
@testable import PackagePersistence

/// Tests de la base chiffrée : création, migrations, panic wipe.
final class BaseDonneesServiceTests: XCTestCase {

    private var cheminTemp: String!

    override func setUp() {
        super.setUp()
        cheminTemp = NSTemporaryDirectory() + "test-\(UUID().uuidString).sqlite"
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: cheminTemp)
        cheminTemp = nil
        super.tearDown()
    }

    func testCreationBaseEtMigrations() throws {
        let base = try BaseDonneesService(cheminBase: cheminTemp, passphrase: "dek-de-test")
        let tables: [String] = try base.pool.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
        }
        XCTAssertTrue(tables.contains("entite"))
        XCTAssertTrue(tables.contains("document"))
        XCTAssertTrue(tables.contains("veille"))
        XCTAssertTrue(tables.contains("elementVeille"))
        XCTAssertTrue(tables.contains("relationEntites"))
        XCTAssertTrue(tables.contains("propositionDoublon"))
    }

    func testBaseChiffreeIllisibleSansPassphrase() throws {
        _ = try BaseDonneesService(cheminBase: cheminTemp, passphrase: "bonne-cle")
        // Sans la clé (ou avec une mauvaise clé), l'ouverture doit échouer.
        XCTAssertThrowsError(try BaseDonneesService(cheminBase: cheminTemp, passphrase: "mauvaise-cle"))
    }

    func testPanicWipe() throws {
        _ = try BaseDonneesService(cheminBase: cheminTemp, passphrase: "cle")
        XCTAssertTrue(FileManager.default.fileExists(atPath: cheminTemp))
        try BaseDonneesService.panicWipe(
            cheminBase: cheminTemp,
            dossierBinaires: cheminTemp + "-binaires",
            keychain: KeychainStore()
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: cheminTemp))
    }

    func testBaseMemoire() throws {
        let base = try BaseDonneesService.baseMemoire()
        let tables: [String] = try base.pool.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
        }
        XCTAssertFalse(tables.isEmpty)
    }
}

/// Tests du trousseau Keychain (service dédié, suppression).
final class KeychainStoreTests: XCTestCase {

    func testEnregistrerLireSupprimer() throws {
        let store = KeychainStore()
        let cle = "test-\(UUID().uuidString)"
        defer { try? store.supprimer(cle: cle) }

        try store.enregistrer(Data("secret".utf8), cle: cle)
        let lu = try store.lire(cle: cle)
        XCTAssertEqual(lu, Data("secret".utf8))

        try store.supprimer(cle: cle)
        XCTAssertNil(try store.lire(cle: cle))
    }
}
