import XCTest
import PackageDomain
@testable import PackageNetworking

/// Tests du service d'alertes : score de priorité, seuil, notification injectée.
final class ServiceAlertesTests: XCTestCase {

    private func veille(priorite: [String]) -> Veille {
        Veille(type: .rss, titre: "Veille test", motsClesPriorite: priorite)
    }

    private func element(titre: String, cotation: FiabiliteSource? = .b) -> ElementVeille {
        ElementVeille(
            veilleId: UUID(),
            url: "https://a.fr",
            titre: titre,
            contenu: "contenu",
            hashContenu: "h",
            cotationSource: cotation
        )
    }

    func testAlerteMotClePrioriteTitre() async {
        var notifications: [(String, String)] = []
        let service = ServiceAlertes(seuilAlerte: 70) { titre, corps in
            notifications.append((titre, corps))
            return true
        }
        let veille = self.veille(priorite: ["urgence"])
        let element = self.element(titre: "Situation d'urgence à Paris")

        let alertes = await service.evaluer(elements: [element], veille: veille)
        XCTAssertEqual(alertes.count, 1)
        XCTAssertEqual(notifications.count, 1)
        XCTAssertTrue(notifications[0].0.contains("Veille test"))
        XCTAssertTrue(notifications[0].1.contains("urgence"))
    }

    func testPasDAlerteSousSeuil() async {
        var notifications: [(String, String)] = []
        let service = ServiceAlertes(seuilAlerte: 70) { titre, corps in
            notifications.append((titre, corps))
            return true
        }
        let veille = self.veille(priorite: ["inexistant"])
        let element = self.element(titre: "Actualité ordinaire", cotation: .d)

        let alertes = await service.evaluer(elements: [element], veille: veille)
        XCTAssertTrue(alertes.isEmpty)
        XCTAssertTrue(notifications.isEmpty)
    }

    func testSeuilPersonnaliseEtLimiteTrois() async {
        var compte = 0
        let service = ServiceAlertes(seuilAlerte: 50) { _, _ in
            compte += 1
            return true
        }
        let veille = self.veille(priorite: ["prioritaire"])
        let elements = (0..<5).map { index in
            self.element(titre: "Alerte prioritaire n°\(index)")
        }
        let alertes = await service.evaluer(elements: elements, veille: veille)
        // 5 éléments alertés mais 3 notifications maximum par passe.
        XCTAssertEqual(alertes.count, 5)
        XCTAssertEqual(compte, 3)
    }

    func testCotationFiableSansMotCle() async {
        let service = ServiceAlertes(seuilAlerte: 70) { _, _ in true }
        let veille = self.veille(priorite: [])
        let element = self.element(titre: "Info banale", cotation: .a)
        let alertes = await service.evaluer(elements: [element], veille: veille)
        XCTAssertTrue(alertes.isEmpty)
    }
}
