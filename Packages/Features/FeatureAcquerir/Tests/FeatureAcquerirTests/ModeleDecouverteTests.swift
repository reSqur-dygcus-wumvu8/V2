import XCTest
import PackageDomain
import PackagePersistence
@testable import FeatureAcquerir

/// Tests du modèle de vue du mode découverte (sans réseau).
final class ModeleDecouverteTests: XCTestCase {

    private var dossier: URL!

    override func setUp() {
        super.setUp()
        dossier = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("decouverte-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dossier)
        super.tearDown()
    }

    private func moteur() throws -> MoteurStockage {
        try MoteurStockage(dossier: dossier, phraseSecrete: "test")
    }

    func testEstimationAfficheeAvantLancement() {
        let service = ServiceDecouverte()
        let modele = ModeleDecouverte(service: service)
        modele.thematique = "convois"
        XCTAssertEqual(modele.estimation, ServiceDecouverte.estimationAppels(thematique: "convois"))
    }

    func testLancementSansClientMessage() async {
        let modele = ModeleDecouverte(service: ServiceDecouverte())
        modele.thematique = "gazoducs"
        await modele.lancer()
        XCTAssertNil(modele.resultat)
        XCTAssertNotNil(modele.message)
        XCTAssertFalse(modele.enCours)
    }

    func testThematiqueVideRefusee() async {
        let modele = ModeleDecouverte(service: ServiceDecouverte())
        modele.thematique = "   "
        await modele.lancer()
        XCTAssertNil(modele.resultat)
        XCTAssertFalse(modele.enCours)
    }

    func testCreationVeilleDepuisSourceInteret() throws {
        let moteur = try moteur()
        let modele = ModeleDecouverte(
            service: ServiceDecouverte(),
            entrepotVeille: EntrepotVeille(moteur: moteur)
        )
        let source = ServiceDecouverte.SourceInteret(
            genre: .flux,
            url: "https://exemple.fr/rss",
            libelle: "Exemple",
            typeVeilleSuggere: .rss
        )
        modele.creerVeille(depuis: source)
        XCTAssertEqual(modele.veillesCreees, 1)
        XCTAssertEqual(EntrepotVeille(moteur: moteur).toutes().count, 1)
    }

    func testHashDecouverteStableEtDistinct() {
        XCTAssertEqual(OrchestrateurHash.texte("abc"), OrchestrateurHash.texte("abc"))
        XCTAssertNotEqual(OrchestrateurHash.texte("abc"), OrchestrateurHash.texte("abd"))
    }
}
