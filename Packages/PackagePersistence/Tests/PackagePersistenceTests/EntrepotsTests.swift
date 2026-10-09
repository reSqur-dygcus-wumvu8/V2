import XCTest
import PackageDomain
@testable import PackagePersistence

/// Tests des entrepôts (documents, éléments de veille, veilles, sources).
final class EntrepotsTests: XCTestCase {

    private var base: BaseDonneesService!
    private var chemin: String!

    override func setUpWithError() throws {
        chemin = NSTemporaryDirectory() + "entrepots-\(UUID().uuidString).sqlite"
        base = try BaseDonneesService(cheminBase: chemin, passphrase: "test")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: chemin)
    }

    func testInsertionDocumentEtDoublon() throws {
        let entrepot = EntrepotDocument(pool: base.pool)
        let source = SourceInfo(denomination: "Source A", cotation: .b)
        try EntrepotSource(pool: base.pool).enregistrer(source)

        let doc = Document(nom: "rapport.txt", typeMime: "text/plain", hashSHA256: "abc123", sourceId: source.id)
        XCTAssertTrue(try entrepot.inserer(doc))
        // Même hash → doublon refusé.
        let doc2 = Document(nom: "copie.txt", typeMime: "text/plain", hashSHA256: "abc123", sourceId: source.id)
        XCTAssertFalse(try entrepot.inserer(doc2))
        XCTAssertEqual(try entrepot.tous().count, 1)
    }

    func testInsertionElementsVeilleDedupliquee() throws {
        let entrepot = EntrepotElementVeille(pool: base.pool)
        let veilleId = UUID()
        let e1 = ElementVeille(veilleId: veilleId, url: "https://a.fr", titre: "A", contenu: "c", hashContenu: "h1")
        let e2 = ElementVeille(veilleId: veilleId, url: "https://b.fr", titre: "B", contenu: "c", hashContenu: "h2")
        let e3 = ElementVeille(veilleId: veilleId, url: "https://a.fr", titre: "A", contenu: "c", hashContenu: "h1")

        let inseres = try entrepot.insererNouveaux([e1, e2, e3])
        XCTAssertEqual(inseres.count, 2)
        XCTAssertEqual(try entrepot.hashesVus(veilleId: veilleId).count, 2)

        // Deuxième passage : tout est déjà vu.
        let deuxieme = try entrepot.insererNouveaux([e1, e2, e3])
        XCTAssertTrue(deuxieme.isEmpty)

        // File d'attente : tous non traités.
        XCTAssertEqual(try entrepot.fileAttente().count, 2)
        try entrepot.marquerTraite(e1.id, statut: .capitalise)
        XCTAssertEqual(try entrepot.fileAttente().count, 1)
    }

    func testVeillesEtJournal() throws {
        let entrepotVeille = EntrepotVeille(pool: base.pool)
        var veille = Veille(type: .googleNews, titre: "Veille test", motsCles: ["a"], frequenceMinutes: 30)
        try entrepotVeille.enregistrer(veille)

        try entrepotVeille.journaliser(
            ResultatJournal(veilleId: veille.id, date: Date(), succes: true, nbNouveaux: 3, message: "3 nouveaux")
        )
        veille.derniereExecution = Date()
        try entrepotVeille.enregistrer(veille)

        let toutes = try entrepotVeille.toutes()
        XCTAssertEqual(toutes.count, 1)
        XCTAssertEqual(toutes[0].derniereExecution, veille.derniereExecution)
        XCTAssertEqual(try entrepotVeille.journal(veilleId: veille.id).count, 1)
        XCTAssertEqual(try entrepotVeille.actives().count, 1)

        try entrepotVeille.supprimer(veille.id)
        XCTAssertTrue(try entrepotVeille.toutes().isEmpty)
    }

    func testSourceChercherParDenomination() throws {
        let entrepot = EntrepotSource(pool: base.pool)
        try entrepot.enregistrer(SourceInfo(denomination: "Le Monde", cotation: .b))
        XCTAssertNotNil(try entrepot.chercher(denomination: "Le Monde"))
        XCTAssertNil(try entrepot.chercher(denomination: "Inconnue"))
    }
}
