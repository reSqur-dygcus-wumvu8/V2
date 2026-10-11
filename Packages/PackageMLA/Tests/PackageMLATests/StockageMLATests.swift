import XCTest
@testable import PackageMLA

/// Tests du stockage chiffré au repos (segments d'archive).
final class StockageMLATests: XCTestCase {

    private var dossier: URL!

    override func setUp() {
        super.setUp()
        dossier = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mla-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dossier)
        super.tearDown()
    }

    private func archive() throws -> ArchiveMLA {
        try ArchiveMLA(dossier: dossier, phraseSecrete: "phrase-de-test")
    }

    func testEcrireLireSegment() throws {
        let archive = try archive()
        let donnees = Data("Le convoi est passé par la route nationale".utf8)
        try archive.ecrire(donnees, segment: "entites")
        XCTAssertEqual(try archive.lire(segment: "entites"), donnees)
    }

    func testSegmentAbsentRetourneNil() throws {
        let archive = try archive()
        XCTAssertNil(try archive.lire(segment: "inexistant"))
    }

    func testRemplacementEtSuppression() throws {
        let archive = try archive()
        try archive.ecrire(Data("v1".utf8), segment: "index")
        try archive.ecrire(Data("v2".utf8), segment: "index")
        XCTAssertEqual(try archive.lire(segment: "index"), Data("v2".utf8))
        try archive.supprimer(segment: "index")
        XCTAssertNil(try archive.lire(segment: "index"))
    }

    func testListeSegments() throws {
        let archive = try archive()
        try archive.ecrire(Data("a".utf8), segment: "entites")
        try archive.ecrire(Data("b".utf8), segment: "relations")
        try archive.ecrire(Data("c".utf8), segment: "veilles")
        XCTAssertEqual(try archive.segments(), ["entites", "relations", "veilles"])
    }

    func testMauvaisePhraseNeDechiffrePas() throws {
        let archive = try archive()
        try archive.ecrire(Data("secret".utf8), segment: "entites")
        let autre = try ArchiveMLA(dossier: dossier, phraseSecrete: "autre-phrase")
        XCTAssertThrowsError(try autre.lire(segment: "entites"))
    }

    func testFichierAuReposIllisibleSansCle() throws {
        let archive = try archive()
        try archive.ecrire(Data("données sensibles".utf8), segment: "entites")
        // Le fichier brut n'est pas en clair sur le disque.
        let brut = try Data(contentsOf: dossier.appendingPathComponent("entites.mla"))
        XCTAssertFalse(String(data: brut, encoding: .utf8)?.contains("sensibles") ?? true)
    }

    func testSelArchivePersisteEtEstReutilise() throws {
        let premiere = try archive()
        try premiere.ecrire(Data("v1".utf8), segment: "entites")
        let cheminSel = dossier.appendingPathComponent("sel.kdf")
        let selInitial = try Data(contentsOf: cheminSel)
        // Réouverture avec la même phrase : même sel, déchiffrement possible.
        let seconde = try ArchiveMLA(dossier: dossier, phraseSecrete: "phrase-de-test")
        XCTAssertEqual(try Data(contentsOf: cheminSel), selInitial)
        XCTAssertEqual(try seconde.lire(segment: "entites"), Data("v1".utf8))
    }

    func testSelsDistinctsEntreArchives() throws {
        try archive().ecrire(Data("a".utf8), segment: "entites")
        let selPremier = try Data(contentsOf: dossier.appendingPathComponent("sel.kdf"))
        let autreDossier = dossier.appendingPathComponent("sous-dossier")
        try FileManager.default.createDirectory(at: autreDossier, withIntermediateDirectories: true)
        _ = try ArchiveMLA(dossier: autreDossier, phraseSecrete: "phrase-de-test")
        let selSecond = try Data(contentsOf: autreDossier.appendingPathComponent("sel.kdf"))
        // Deux archives distinctes ne partagent pas le même sel.
        XCTAssertNotEqual(selPremier, selSecond)
    }

    func testDerivationCleDeterministePourMemePhraseEtSel() throws {
        let premiere = try archive()
        let seconde = try ArchiveMLA(dossier: dossier, phraseSecrete: "phrase-de-test")
        // Même phrase + même sel (réutilisé dans le même dossier) → même clé
        // → déchiffrement possible depuis une nouvelle instance.
        try premiere.ecrire(Data("secret".utf8), segment: "entites")
        XCTAssertEqual(try seconde.lire(segment: "entites"), Data("secret".utf8))
    }
}
