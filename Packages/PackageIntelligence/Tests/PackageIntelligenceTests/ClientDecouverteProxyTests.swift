import XCTest
import PackageDomain
@testable import PackageIntelligence

/// Tests du pont découverte : décodage des structures JSON renvoyées
/// par le proxy /decouvrir (le réseau n'est pas requis).
final class ClientDecouverteProxyTests: XCTestCase {

    func testDecodageReponseComplete() {
        // Le décodage vit dans le pont via JSONSerialization ; on valide
        // ici les structures attendues par le ServiceDecouverte.
        let json = """
        {
          "synthese": "Analyse structurée de la thématique.",
          "sources": [
            {"url": "https://exemple.fr/a", "titre": "Article A", "cotation": "B"}
          ],
          "sourcesInteret": [
            {"genre": "flux", "url": "https://exemple.fr/rss", "libelle": "Exemple", "typeVeille": "rss", "motsCles": ["convoi"]}
          ]
        }
        """
        let objet = try! JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
        XCTAssertNotNil(objet["synthese"] as? String)
        let sources = objet["sources"] as! [[String: Any]]
        XCTAssertEqual(FiabiliteSource(rawValue: sources[0]["cotation"] as! String), .b)
        let interets = objet["sourcesInteret"] as! [[String: Any]]
        XCTAssertEqual(TypeVeille(rawValue: interets[0]["typeVeille"] as! String), .rss)
    }

    func testCotationInvalideIgnoree() {
        XCTAssertNil(FiabiliteSource(rawValue: "Z"))
        XCTAssertNil(FiabiliteSource(rawValue: ""))
    }

    func testGenreInteretParDefaut() {
        XCTAssertEqual(ServiceDecouverte.SourceInteret.Genre(rawValue: "site"), .site)
        XCTAssertEqual(ServiceDecouverte.SourceInteret.Genre(rawValue: "inconnu") ?? .site, .site)
    }
}
