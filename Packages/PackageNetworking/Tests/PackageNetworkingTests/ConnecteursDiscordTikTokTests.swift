import XCTest
import PackageDomain
import PackageTor
@testable import PackageNetworking

/// Tests des connecteurs Discord (décodage API bot) et TikTok (import manuel).
final class ConnecteursDiscordTikTokTests: XCTestCase {

    private let jsonDiscord = """
    [
      {"id": "111", "content": "Message du canal surveillé.", "timestamp": "2025-01-06T20:30:00Z", "author": {"username": "analyste"}},
      {"id": "112", "content": "", "timestamp": "2025-01-06T21:00:00Z", "author": {"username": "bot"}},
      {"id": "113", "content": "Troisième message.", "timestamp": "2025-01-07T09:00:00Z"}
    ]
    """

    func testDecodageMessagesDiscord() throws {
        let elements = try ConnecteurDiscord.decoderMessages(
            donnees: Data(jsonDiscord.utf8),
            idCanal: "555"
        )
        // Le message vide est écarté.
        XCTAssertEqual(elements.count, 2)
        XCTAssertEqual(elements[0].titre, "analyste : Message du canal surveillé.")
        XCTAssertTrue(elements[0].url.hasSuffix("/555/111"))
        XCTAssertNotNil(elements[0].datePublication)
        // Message sans auteur : repli « inconnu ».
        XCTAssertTrue(elements[1].titre.hasPrefix("inconnu :"))
    }

    func testDecodageDiscordInvalide() {
        XCTAssertThrowsError(try ConnecteurDiscord.decoderMessages(donnees: Data("pas json".utf8), idCanal: "1"))
    }

    func testConnecteurDiscordConfig() {
        let connecteur = ConnecteurDiscord(tokenBot: "token-x", idCanal: "555", reseau: ReseauTor(client: ClientTor()))
        XCTAssertEqual(connecteur.plateforme, .discord)
        XCTAssertEqual(connecteur.idCanal, "555")
        XCTAssertEqual(ConnecteurDiscord.apiBase, "https://discord.com/api/v10")
    }

    func testTikTokImportManuel() {
        let lignes = [
            "https://tiktok.com/@canal/video/123 | Vidéo montrant le convoi",
            "Publication collée sans URL",
            "",
            "https://tiktok.com/@canal/video/456 |"
        ]
        let veilleId = UUID()
        let elements = ConnecteurTikTok.importerManuel(lignes: lignes, veilleId: veilleId)
        // La ligne vide est écartée ; la ligne URL sans texte garde un hash unique.
        XCTAssertEqual(elements.count, 3)
        XCTAssertEqual(elements[0].url, "https://tiktok.com/@canal/video/123")
        XCTAssertEqual(elements[1].url, "import://tiktok/1")
        XCTAssertTrue(elements.allSatisfy { $0.veilleId == veilleId })
        // Hashes distincts.
        XCTAssertEqual(Set(elements.map(\.hashContenu)).count, 3)
    }

    func testTikTokRecuperationLeveErreur() async {
        let connecteur = ConnecteurTikTok()
        do {
            _ = try await connecteur.recuperer(
                configuration: ConfigurationConnecteur(identifiant: "@canal", plateforme: .tiktok)
            )
            XCTFail("Doit lever importManuelRequis")
        } catch let erreur as ErreurVeille {
            XCTAssertEqual(erreur.errorDescription, ErreurVeille.importManuelRequis.errorDescription)
        } catch {
            XCTFail("Type d'erreur inattendu")
        }
    }
}
