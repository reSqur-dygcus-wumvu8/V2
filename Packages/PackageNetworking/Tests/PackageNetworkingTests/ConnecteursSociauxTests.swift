import XCTest
import PackageDomain
import PackageTor
@testable import PackageNetworking

/// Tests du connecteur Telegram (extraction HTML de t.me/s).
final class ConnecteurTelegramTests: XCTestCase {

    private let htmlCanal = """
    <div class="tgme_widget_message ..." data-post="canaltest/42">
    <div class="tgme_widget_message_text js-message_text" dir="auto">Le convoi est passé par la <b>route nationale</b> hier soir&nbsp;!</div>
    <time datetime="2025-01-06T20:30:00+00:00">6 janvier</time>
    </div>
    <div class="tgme_widget_message ..." data-post="canaltest/43">
    <div class="tgme_widget_message_text js-message_text" dir="auto">Deuxième message du canal.</div>
    <time datetime="2025-01-07T09:00:00+00:00">7 janvier</time>
    </div>
    <div class="tgme_widget_message ..." data-post="canaltest/44">
    <div>Message sans texte exploitable.</div>
    </div>
    """

    func testExtractionMessages() {
        let elements = ConnecteurTelegram.extraireMessages(html: htmlCanal, canal: "canaltest")
        XCTAssertEqual(elements.count, 2)
        XCTAssertTrue(elements[0].contenu.contains("route nationale"))
        XCTAssertEqual(elements[0].url, "https://t.me/canaltest/42")
        XCTAssertNotNil(elements[0].datePublication)
        XCTAssertEqual(elements[1].titre, "Deuxième message du canal.")
    }

    func testNettoyageHTML() {
        let nettoyee = ConnecteurTelegram.nettoyer("Texte<br/>sur lignes &amp; entités")
        XCTAssertTrue(nettoyee.contains("\n"))
        XCTAssertTrue(nettoyee.contains("&"))
        XCTAssertFalse(nettoyee.contains("<br"))
    }

    func testAttributsExtraits() {
        XCTAssertEqual(
            ConnecteurTelegram.valeurAttribut("data-post", dans: htmlCanal),
            "canaltest/42"
        )
        XCTAssertNil(ConnecteurTelegram.valeurAttribut("attribut-inexistant", dans: htmlCanal))
    }

    func testRegistreFournisseurs() {
        let reseau = ReseauTor(client: ClientTor())
        XCTAssertNotNil(RegistreConnecteurs.fournisseur(pour: .xTwitter, reseau: reseau))
        XCTAssertNotNil(RegistreConnecteurs.fournisseur(pour: .telegram, reseau: reseau))
        XCTAssertNil(RegistreConnecteurs.fournisseur(pour: .discord, reseau: reseau))
        XCTAssertNil(RegistreConnecteurs.fournisseur(pour: .tiktok, reseau: reseau))
    }

    func testConfigurationConnecteurCodable() throws {
        let config = ConfigurationConnecteur(identifiant: "@canal", plateforme: .telegram, motsClesPriorite: ["a"])
        let data = try JSONEncoder().encode(config)
        let decodee = try JSONDecoder().decode(ConfigurationConnecteur.self, from: data)
        XCTAssertEqual(decodee, config)
    }
}

/// Tests du connecteur X (construction d'URL nitter).
final class ConnecteurXTests: XCTestCase {

    func testInstanceNitterParDefaut() {
        let connecteur = ConnecteurX()
        XCTAssertEqual(connecteur.plateforme, .xTwitter)
        XCTAssertEqual(connecteur.instanceNitter, "https://nitter.net")
    }

    func testInstancePersonnalisee() {
        let connecteur = ConnecteurX(instanceNitter: "https://nitter.example.org")
        XCTAssertEqual(connecteur.instanceNitter, "https://nitter.example.org")
    }
}
