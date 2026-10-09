import XCTest
import PackageDomain
import PackagePersistence
@testable import FeatureGerer

/// Tests du service de doublons : détection, refus mémorisé, fusion, journal.
final class ServiceDoublonsTests: XCTestCase {

    private var base: BaseDonneesService!
    private var chemin: String!
    private var entrepotEntite: EntrepotEntite!
    private var entrepotDoublon: EntrepotDoublon!
    private var service: ServiceDoublons!

    override func setUpWithError() throws {
        chemin = NSTemporaryDirectory() + "gerer-\(UUID().uuidString).sqlite"
        base = try BaseDonneesService(cheminBase: chemin, passphrase: "test")
        entrepotEntite = EntrepotEntite(pool: base.pool)
        entrepotDoublon = EntrepotDoublon(pool: base.pool)
        service = ServiceDoublons(
            entrepotDoublon: entrepotDoublon,
            entrepotEntite: entrepotEntite,
            entrepotDocument: EntrepotDocument(pool: base.pool)
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: chemin)
    }

    func testDetectionDoublonsDenominations() throws {
        try entrepotEntite.enregistrer(Entite(type: .individu, denomination: "Jean Dupont"))
        try entrepotEntite.enregistrer(Entite(type: .individu, denomination: "Jean Dupont"))
        try entrepotEntite.enregistrer(Entite(type: .individu, denomination: "Marie Curie"))

        let propositions = try service.detecterDoublonsEntites()
        XCTAssertEqual(propositions.count, 1)
        XCTAssertEqual(propositions[0].score, 1.0, accuracy: 0.001)
    }

    func testPaireRefuseeJamaisRepropossee() throws {
        let a = Entite(type: .organisation, denomination: "ACME SARL")
        let b = Entite(type: .organisation, denomination: "ACME SARL")
        try entrepotEntite.enregistrer(a)
        try entrepotEntite.enregistrer(b)

        var propositions = try service.detecterDoublonsEntites()
        XCTAssertEqual(propositions.count, 1)

        // Refus explicite de la paire.
        try entrepotDoublon.decider(propositions[0].id, statut: .refuse)

        // Nouvelle passe : la paire refusée n'est plus proposée.
        propositions = try service.detecterDoublonsEntites()
        XCTAssertTrue(propositions.isEmpty)
    }

    func testDetectionDocumentsSimilaires() throws {
        let entrepotDocument = EntrepotDocument(pool: base.pool)
        let source = SourceInfo(denomination: "S")
        try EntrepotSource(pool: base.pool).enregistrer(source)
        let texte = "Le convoi est passé par la route nationale hier soir vers minuit"
        try entrepotDocument.inserer(Document(nom: "a.txt", typeMime: "text/plain", hashSHA256: "h1", texteExtrait: texte, sourceId: source.id))
        try entrepotDocument.inserer(Document(nom: "b.txt", typeMime: "text/plain", hashSHA256: "h2", texteExtrait: texte, sourceId: source.id))
        try entrepotDocument.inserer(Document(nom: "c.txt", typeMime: "text/plain", hashSHA256: "h3", texteExtrait: "Contenu totalement différent", sourceId: source.id))

        let propositions = try service.detecterDoublonsDocuments()
        XCTAssertEqual(propositions.count, 1)
    }

    func testFusionTransfereRelationsEtJournalise() throws {
        var gardee = Entite(type: .individu, denomination: "Jean Dupont")
        var fusionnee = Entite(type: .individu, denomination: "J. Dupont", resume: "Biographie complète")
        try entrepotEntite.enregistrer(gardee)
        try entrepotEntite.enregistrer(fusionnee)

        let tiers = Entite(type: .organisation, denomination: "ACME")
        try entrepotEntite.enregistrer(tiers)
        try entrepotEntite.relier(RelationEntites(idSource: fusionnee.id, idCible: tiers.id, typeRelation: "employé"))

        try service.fusionnerEntites(gardee: gardee, fusionnee: fusionnee, champsDepuisFusionnee: ["resume"])

        // L'entité conservée porte le résumé de l'absorbée.
        gardee = try XCTUnwrap(try entrepotEntite.chercher(id: gardee.id))
        XCTAssertEqual(gardee.resume, "Biographie complète")
        // Les relations de l'absorbée sont transférées.
        XCTAssertEqual(try entrepotEntite.relations(id: gardee.id).count, 1)
        // L'absorbée est une tombstone (invisible, jamais effacée physiquement).
        let fusionneeApres = try XCTUnwrap(try entrepotEntite.chercher(id: fusionnee.id))
        XCTAssertEqual(try entrepotEntite.toutes().contains { $0.id == fusionneeApres.id }, false)
        // La fusion est journalisée.
        let journal = try entrepotDoublon.journalFusions()
        XCTAssertEqual(journal.count, 1)
        XCTAssertEqual(journal[0].entiteGardee, gardee.id)
        XCTAssertEqual(journal[0].champsChoisis, ["resume"])
    }

    func testSeuilsPersonnalises() throws {
        var seuils = ServiceDoublons.Seuils()
        seuils.similariteDenomination = 0.99
        let serviceStrict = ServiceDoublons(
            entrepotDoublon: entrepotDoublon,
            entrepotEntite: entrepotEntite,
            entrepotDocument: EntrepotDocument(pool: base.pool),
            seuils: seuils
        )
        try entrepotEntite.enregistrer(Entite(type: .lieu, denomination: "Gare de Lyon"))
        try entrepotEntite.enregistrer(Entite(type: .lieu, denomination: "Gare de Lyon Paris"))
        // Similarité < 0.99 → pas de proposition.
        XCTAssertTrue(try serviceStrict.detecterDoublonsEntites().isEmpty)
    }
}
