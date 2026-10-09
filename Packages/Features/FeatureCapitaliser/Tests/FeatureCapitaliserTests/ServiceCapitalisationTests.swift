import XCTest
import PackageDomain
import PackagePersistence
@testable import FeatureCapitaliser

/// Tests du service de capitalisation (regroupement, reconnaissance, création).
final class ServiceCapitalisationTests: XCTestCase {

    private var base: BaseDonneesService!
    private var chemin: String!
    private var service: ServiceCapitalisation!

    override func setUpWithError() throws {
        chemin = NSTemporaryDirectory() + "capitaliser-\(UUID().uuidString).sqlite"
        base = try BaseDonneesService(cheminBase: chemin, passphrase: "test")
        service = ServiceCapitalisation(
            entrepotEntite: EntrepotEntite(pool: base.pool),
            entrepotElements: EntrepotElementVeille(pool: base.pool),
            entrepotRegroupement: EntrepotRegroupement(pool: base.pool),
            clientMistral: nil
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(atPath: chemin)
    }

    private func insererElement(titre: String, contenu: String) throws -> ElementVeille {
        let element = ElementVeille(veilleId: UUID(), url: "https://a.fr", titre: titre, contenu: contenu, hashContenu: UUID().uuidString)
        _ = try EntrepotElementVeille(pool: base.pool).insererNouveaux([element])
        return element
    }

    func testCreerRegroupementCapitaliseLesElements() async throws {
        let e1 = try insererElement(titre: "Incident", contenu: "Un convoi signalé.")
        let e2 = try insererElement(titre: "Suite", contenu: "Confirmation par seconde source.")

        let regroupement = try await service.creerRegroupement(titre: "Incident du 6", elements: [e1, e2])
        XCTAssertEqual(regroupement.elementIds.count, 2)
        XCTAssertFalse(regroupement.resume.isEmpty)

        let tous = try EntrepotRegroupement(pool: base.pool).tous()
        XCTAssertEqual(tous.count, 1)
        // Les éléments sont marqués capitalisés.
        XCTAssertTrue(try EntrepotElementVeille(pool: base.pool).fileAttente().isEmpty)
    }

    func testPropositionCotationSansProxyEstNeutre() async {
        let proposition = await service.proposerCotation(contenu: "texte")
        XCTAssertEqual(proposition.cotation.code, "F6")
    }

    func testReconnaissanceEntitesExistantes() throws {
        let entrepot = EntrepotEntite(pool: base.pool)
        try entrepot.enregistrer(Entite(type: .individu, denomination: "Jean Dupont", prenom: "Jean", nom: "Dupont"))
        try entrepot.enregistrer(Entite(type: .lieu, denomination: "Lyon"))

        let reconnues = try service.reconnaitreEntites(dans: "Jean Dupont a été vu à Lyon hier.")
        XCTAssertEqual(reconnues.count, 2)
        XCTAssertTrue(reconnues.contains { $0.0.denomination == "Jean Dupont" })
        XCTAssertTrue(reconnues.contains { $0.0.denomination == "Lyon" })
    }

    func testReconnaissanceSansCorrespondance() throws {
        try service.entrepotEntite.enregistrer(Entite(type: .organisation, denomination: "ACME"))
        let reconnues = try service.reconnaitreEntites(dans: "Rien de pertinent ici.")
        XCTAssertTrue(reconnues.isEmpty)
    }

    func testCreerEntiteDepuisTerme() throws {
        let individu = try service.creerEntite(depuisTerme: "Marie Martin", type: .individu)
        XCTAssertEqual(individu.prenom, "Marie")
        XCTAssertEqual(individu.nom, "Martin")

        let organisation = try service.creerEntite(depuisTerme: "Otan", type: .organisation)
        XCTAssertEqual(organisation.denomination, "Otan")
        XCTAssertEqual(organisation.type, .organisation)
    }

    func testHistoriqueEtRelations() throws {
        let entrepot = EntrepotEntite(pool: base.pool)
        var entite = Entite(type: .organisation, denomination: "ACME")
        try entrepot.enregistrer(entite)

        var modifiee = entite
        modifiee.resume = "Nouvelle synthèse"
        modifiee.updatedAt = Date()
        try entrepot.enregistrer(modifiee)
        try entrepot.journaliser(VersionEntite(entiteId: entite.id, champsModifies: ["resume"], appareil: "Mac"))

        let historique = try entrepot.historique(entiteId: entite.id)
        XCTAssertEqual(historique.count, 1)
        XCTAssertEqual(historique.first?.champsModifies, ["resume"])

        let autre = Entite(type: .individu, denomination: "Contact ACME")
        try entrepot.enregistrer(autre)
        try entrepot.relier(RelationEntites(idSource: entite.id, idCible: autre.id, typeRelation: "employeur"))
        XCTAssertEqual(try entrepot.relations(id: entite.id).count, 1)
    }
}
