import XCTest
@testable import PackageTor

/// Tests du client Tor embarqué (configuration, états, refus hors Tor).
final class ClientTorTests: XCTestCase {

    func testConfigurationParDefaut() {
        let config = ConfigurationTor()
        XCTAssertEqual(config.portSOCKS5, 9050)
        XCTAssertTrue(config.ponts.isEmpty)
        XCTAssertNil(config.paysSortie)
    }

    func testConfigurationPersonnalisee() {
        let config = ConfigurationTor(
            portSOCKS5: 9150,
            ponts: ["obfs4 1.2.3.4:9999 cert=abc"],
            paysSortie: "fr"
        )
        XCTAssertEqual(config.portSOCKS5, 9150)
        XCTAssertEqual(config.ponts.count, 1)
        XCTAssertEqual(config.paysSortie, "fr")
    }

    func testDemarrageSansXCFrameworkRefuse() async {
        // Sans xcframework lié (environnement de test), le démarrage échoue
        // proprement et l'état est « erreur » — jamais de fallback en clair.
        let client = ClientTor()
        let demarre = await client.demarrer()
        if BackendFFI_Arti.estDisponible {
            XCTAssertTrue(demarre)
            XCTAssertEqual(client.etat, .connecte)
        } else {
            XCTAssertFalse(demarre)
            XCTAssertEqual(client.etat, .erreur)
        }
    }

    func testSessionRefuseeHorsConnexion() async {
        let client = ClientTor()
        _ = await client.demarrer()
        if client.etat != .connecte {
            XCTAssertThrowsError(try client.session()) { erreur in
                XCTAssertEqual(erreur as? ErreurTor, .clientIndisponible)
            }
        }
    }

    func testSessionProxySOCKS5Loopback() async throws {
        let client = ClientTor(configuration: ConfigurationTor(portSOCKS5: 9150))
        _ = await client.demarrer()
        guard client.etat == .connecte else {
            throw XCTSkip("XCFramework Arti non lié dans cet environnement.")
        }
        let session = try client.session()
        let proxy = session.configuration.connectionProxyDictionary
        XCTAssertEqual(proxy?[kCFNetworkProxiesSOCKSProxy as String] as? String, "127.0.0.1")
        XCTAssertEqual(proxy?[kCFNetworkProxiesSOCKSProxyPort as String] as? Int, 9150)
    }

    func testArretReinitialiseEtat() async {
        let client = ClientTor()
        _ = await client.demarrer()
        client.arreter()
        XCTAssertEqual(client.etat, .arrete)
    }
}
