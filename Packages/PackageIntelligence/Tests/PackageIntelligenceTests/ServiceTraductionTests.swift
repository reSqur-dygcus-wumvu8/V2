import XCTest
import PackageDomain
@testable import PackageIntelligence

/// Tests du service de traduction (détection de français, conservation
/// de l'original) — sans réseau (client nil).
final class ServiceTraductionTests: XCTestCase {

    func testDetectionFrancais() {
        XCTAssertTrue(ServiceTraduction.seembleFrancais(
            "Le convoi est passé par la route nationale hier soir"
        ))
        XCTAssertFalse(ServiceTraduction.seembleFrancais(
            "The convoy passed the national road yesterday evening"
        ))
    }

    func testSansClientLElementResteInchange() async {
        let element = ElementVeille(
            veilleId: UUID(),
            url: "https://exemple.de",
            titre: "Konvoi",
            contenu: "Der Konvoi passierte die Nationalstraße",
            hashContenu: "h",
            langueOriginale: "de"
        )
        let resultat = await ServiceTraduction.traduire(element, avec: nil)
        XCTAssertEqual(resultat.contenu, element.contenu)
        XCTAssertNil(resultat.contenuOriginal)
    }

    func testElementFrancaisNonTraduit() async {
        // Même avec un client, un élément déjà en français n'est pas traduit.
        let element = ElementVeille(
            veilleId: UUID(),
            url: "https://exemple.fr",
            titre: "Convoi",
            contenu: "Le convoi est passé par la route nationale",
            hashContenu: "h",
            langueOriginale: "fr"
        )
        let resultat = await ServiceTraduction.traduire(element, avec: nil)
        XCTAssertEqual(resultat.contenu, element.contenu)
    }

    func testTexteVideResteVide() async {
        let element = ElementVeille(
            veilleId: UUID(),
            url: "https://a.fr",
            titre: "Vide",
            contenu: "",
            hashContenu: "h"
        )
        let resultat = await ServiceTraduction.traduire(element, avec: nil)
        XCTAssertEqual(resultat.contenu, "")
    }
}
