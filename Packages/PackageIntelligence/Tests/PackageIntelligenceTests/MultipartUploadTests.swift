import XCTest
import PackageDomain
@testable import PackageIntelligence

/// Tests de la construction des requêtes multipart vers le proxy.
final class MultipartUploadTests: XCTestCase {

    func testCorpsMultipartContientLesChamps() {
        var upload = MultipartUpload(url: URL(string: "https://proxy.example.com/resumer")!)
        upload.add(name: "contenu", string: "texte à résumer")
        upload.add(name: "motsCles", string: "urgence")
        let corps = String(data: upload.corps(), encoding: .utf8) ?? ""
        XCTAssertTrue(corps.contains("contenu"))
        XCTAssertTrue(corps.contains("texte à résumer"))
        XCTAssertTrue(corps.contains("motsCles"))
        XCTAssertTrue(corps.contains("urgence"))
    }

    func testPropositionCotationDecodable() throws {
        let json = """
        {"cotation": {"fiabiliteSource": "B", "credibiliteInfo": 2}, "justification": "Deux sources concordantes"}
        """
        let proposition = try JSONDecoder().decode(CotationOTAN.Proposition.self, from: Data(json.utf8))
        XCTAssertEqual(proposition.cotation.code, "B2")
        XCTAssertEqual(proposition.justification, "Deux sources concordantes")
    }

    func testEntiteExtraiteDecodable() throws {
        let json = """
        [{"texte": "Jean Dupont", "type": "individu"}]
        """
        let entites = try JSONDecoder().decode([EntiteExtraite].self, from: Data(json.utf8))
        XCTAssertEqual(entites.count, 1)
        XCTAssertEqual(entites.first?.texte, "Jean Dupont")
    }
}
