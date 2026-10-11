import XCTest
import PackageDomain
@testable import PackageNetworking

/// Tests de la file d'attente des tâches différées.
final class FileAttenteDiffereeTests: XCTestCase {

    func testAjoutEtDechargementApresCircuitTor() async throws {
        let file = FileAttenteDifferee()
        let initial = await file.nombreEnAttente
        XCTAssertEqual(initial, 0)

        await file.ajouter(TacheDifferee(genre: .executionVeille, url: "https://exemple.fr/rss"))
        await file.ajouter(TacheDifferee(genre: .telechargement, url: "https://exemple.fr/doc.pdf"))
        let apresAjout = await file.nombreEnAttente
        XCTAssertEqual(apresAjout, 2)

        // Circuit Tor coupé : rien ne sort.
        await file.circuitTorDisponible(false)
        let vide = await file.decharger()
        XCTAssertTrue(vide.isEmpty)
        let toujoursEnAttente = await file.nombreEnAttente
        XCTAssertEqual(toujoursEnAttente, 2)

        // Circuit rétabli : les tâches repartent.
        await file.circuitTorDisponible(true)
        let taches = await file.decharger()
        XCTAssertEqual(taches.count, 2)
        let final = await file.nombreEnAttente
        XCTAssertEqual(final, 0)
    }

    func testConnecteursDocumententLeurRisque() {
        for plateforme in PlateformeSociale.allCases {
            XCTAssertFalse(plateforme.methodeEtRisque.isEmpty)
            XCTAssertFalse(plateforme.libelle.isEmpty)
        }
    }
}
