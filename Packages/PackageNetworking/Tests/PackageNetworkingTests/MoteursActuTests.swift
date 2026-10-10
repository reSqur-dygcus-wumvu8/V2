import XCTest
import PackageDomain
@testable import PackageNetworking

/// Tests des connecteurs d'actualités (URL, régions, parsing factice).
final class MoteursActuTests: XCTestCase {

    func testRegistreMoteurs() {
        XCTAssertEqual(RegistreMoteursActu.fournisseur(pour: .google).moteur, .google)
        XCTAssertEqual(RegistreMoteursActu.fournisseur(pour: .qwant).moteur, .qwant)
        XCTAssertEqual(RegistreMoteursActu.fournisseur(pour: .yandex).moteur, .yandex)
        XCTAssertEqual(MoteurActu.allCases.count, 3)
    }

    func testPaysPourLangue() {
        XCTAssertEqual(ConnecteurGoogleActu.paysPourLangue("fr"), "FR")
        XCTAssertEqual(ConnecteurGoogleActu.paysPourLangue("en"), "US")
        XCTAssertEqual(ConnecteurGoogleActu.paysPourLangue("de"), "DE")
        XCTAssertEqual(ConnecteurGoogleActu.paysPourLangue("ru"), "RU")
    }

    func testRegionYandexPourLangue() {
        XCTAssertEqual(ConnecteurYandexActu.regionPourLangue("fr"), 225)
        XCTAssertEqual(ConnecteurYandexActu.regionPourLangue("ru"), 1)
        XCTAssertEqual(ConnecteurYandexActu.regionPourLangue("en"), 65)
    }

    func testRechercheSansMotsClesRetourneVide() async throws {
        let reseau = ReseauTor(client: ClientTor())
        let google = ConnecteurGoogleActu()
        let resultat = try await google.rechercher(motsCles: [], langue: "fr", reseau: reseau)
        XCTAssertTrue(resultat.isEmpty)
        let yandex = ConnecteurYandexActu()
        XCTAssertTrue(try await yandex.rechercher(motsCles: [], langue: "fr", reseau: reseau).isEmpty)
        let qwant = ConnecteurQwantActu()
        XCTAssertTrue(try await qwant.rechercher(motsCles: [], langue: "fr", reseau: reseau).isEmpty)
    }

    func testParsingDateQwant() {
        XCTAssertNotNil(ConnecteurQwantActu.parserDate("2025-01-06T20:30:00Z"))
        XCTAssertNotNil(ConnecteurQwantActu.parserDate("2025-01-06T20:30:00.123Z"))
        XCTAssertNil(ConnecteurQwantActu.parserDate(nil))
        XCTAssertNil(ConnecteurQwantActu.parserDate("pas une date"))
    }
}

/// Tests de la configuration multilingue de la veille.
final class VeilleMultilingueTests: XCTestCase {

    func testVeilleParDefautGoogleFrancais() {
        let veille = Veille(type: .googleNews, titre: "Test", motsCles: ["x"])
        XCTAssertNil(veille.moteurs)
        XCTAssertNil(veille.langues)
        XCTAssertNil(veille.paysSortie)
        // L'orchestrateur interprète nil = [google] × ["fr"].
    }

    func testVeilleMultilingueMultiMoteurs() {
        let veille = Veille(
            type: .googleNews,
            titre: "Multilingue",
            motsCles: ["convoi"],
            langues: ["fr", "en", "de"],
            moteurs: [.google, .qwant, .yandex],
            paysSortie: "fr"
        )
        XCTAssertEqual(veille.langues?.count, 3)
        XCTAssertEqual(veille.moteurs?.count, 3)
        XCTAssertEqual(veille.paysSortie, "fr")
    }

    func testLangueOriginaleConserveeSurElement() {
        let element = ElementVeille(
            veilleId: UUID(),
            url: "https://exemple.de",
            titre: "Konvoi",
            contenu: "Der Konvoi passierte die Nationalstraße",
            hashContenu: "h",
            contenuOriginal: "Der Konvoi passierte die Nationalstraße",
            langueOriginale: "de"
        )
        XCTAssertEqual(element.langueOriginale, "de")
        XCTAssertEqual(element.contenuOriginal, element.contenu)
    }
}
