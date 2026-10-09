import XCTest
import PackageDomain
import PackagePersistence
@testable import FeatureAcquerir

/// Tests du service d'import : hash, extraction texte, HTML.
final class ServiceImportTests: XCTestCase {

    func testHashSHA256Stable() {
        let donnees = Data("contenu identique".utf8)
        XCTAssertEqual(ServiceImport.hashFichier(donnees), ServiceImport.hashFichier(donnees))
        XCTAssertNotEqual(ServiceImport.hashFichier(donnees), ServiceImport.hashFichier(Data("autre".utf8)))
    }

    func testExtractionTexteBrut() {
        let texte = "Rapport du 6 janvier."
        XCTAssertEqual(ServiceImport.extraireTexte(donnees: Data(texte.utf8), typeMime: "text/plain"), texte)
    }

    func testExtractionHTML() {
        let html = "<html><head><style>p{}</style></head><body><p>Bonjour &amp; au revoir</p><script>alert(1)</script></body></html>"
        let texte = ServiceImport.texteDepuisHTML(html)
        XCTAssertTrue(texte.contains("Bonjour & au revoir"))
        XCTAssertFalse(texte.contains("alert"))
        XCTAssertFalse(texte.contains("<"))
    }

    func testExtractionTypeInconnuVide() {
        XCTAssertEqual(ServiceImport.extraireTexte(donnees: Data([0x89, 0x50]), typeMime: "application/pdf"), "")
    }
}
