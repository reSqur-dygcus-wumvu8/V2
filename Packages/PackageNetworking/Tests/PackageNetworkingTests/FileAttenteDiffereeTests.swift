import XCTest
import PackageDomain
@testable import PackageNetworking

/// Tests de la file d'attente des tâches différées.
final class FileAttenteDiffereeTests: XCTestCase {

    func testAjoutEtDechargementApresCircuitTor() async throws {
        let file = FileAttenteDifferee()
        XCTAssertEqual(await file.nombreEnAttente, 0)

        await file.ajouter(TacheDifferee(genre: .executionVeille, url: "https://exemple.fr/rss"))
        await file.ajouter(TacheDifferee(genre: .telechargement, url: "https://exemple.fr/doc.pdf"))
        XCTAssertEqual(await file.nombreEnAttente, 2)

        // Circuit Tor coupé : rien ne sort.
        await file.circuitTorDisponible(false)
        XCTAssertTrue(await file.decharger().isEmpty)
        XCTAssertEqual(await file.nombreEnAttente, 2)

        // Circuit rétabli : les tâches repartent.
        await file.circuitTorDisponible(true)
        let taches = await file.decharger()
        XCTAssertEqual(taches.count, 2)
        XCTAssertEqual(await file.nombreEnAttente, 0)
    }

    func testConnecteursDocumententLeurRisque() {
        for plateforme in PlateformeSociale.allCases {
            XCTAssertFalse(plateforme.methodeEtRisque.isEmpty)
            XCTAssertFalse(plateforme.libelle.isEmpty)
        }
    }
}
