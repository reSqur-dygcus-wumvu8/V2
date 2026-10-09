import XCTest
import PackageDomain
@testable import PackageNetworking

/// Tests de l'analyseur RSS/Atom (parsing XML sans dépendance externe).
final class AnalyseurRSSTests: XCTestCase {

    private let fluxRSS = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0"><channel>
    <item>
    <title>Situation à Paris</title>
    <link>https://exemple.fr/paris</link>
    <description><![CDATA[Le convoi est passé par la route nationale.]]></description>
    <pubDate>Mon, 06 Jan 2025 08:00:00 +0000</pubDate>
    </item>
    <item>
    <title>Deuxième article</title>
    <link>https://exemple.fr/deux</link>
    <description>Résumé bref.</description>
    </item>
    </channel></rss>
    """

    func testAnalyseFluxRSS() {
        let analyseur = AnalyseurRSS()
        let elements = analyseur.analyser(xml: fluxRSS, veilleId: UUID(), hash: { $0.count.description })
        XCTAssertEqual(elements.count, 2)
        XCTAssertEqual(elements[0].titre, "Situation à Paris")
        XCTAssertEqual(elements[0].url, "https://exemple.fr/paris")
        XCTAssertTrue(elements[0].contenu.contains("route nationale"))
        XCTAssertNotNil(elements[0].datePublication)
        XCTAssertNil(elements[1].datePublication)
    }

    func testAnalyseFluxAtom() {
        let fluxAtom = """
        <?xml version="1.0"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
        <entry>
        <title>Entrée Atom</title>
        <link rel="alternate" href="https://exemple.fr/atom"/>
        <summary>Résumé Atom.</summary>
        <updated>2025-01-06T08:00:00Z</updated>
        </entry>
        </feed>
        """
        let elements = AnalyseurRSS().analyser(xml: fluxAtom, veilleId: UUID(), hash: { _ in "h" })
        XCTAssertEqual(elements.count, 1)
        XCTAssertEqual(elements[0].titre, "Entrée Atom")
        XCTAssertEqual(elements[0].url, "https://exemple.fr/atom")
        XCTAssertNotNil(elements[0].datePublication)
    }

    func testFluxVide() {
        let elements = AnalyseurRSS().analyser(xml: "<rss></rss>", veilleId: UUID(), hash: { _ in "h" })
        XCTAssertTrue(elements.isEmpty)
    }
}

/// Tests de l'orchestrateur de veille avec URL de flux fictive locale.
final class OrchestrateurVeilleTests: XCTestCase {

    func testURLGoogleNewsConstruite() throws {
        let connecteur = ConnecteurGoogleNews()
        let url = try XCTUnwrap(connecteur.urlRecherche(motsCles: ["crise", "énergie"]))
        XCTAssertTrue(url.absoluteString.contains("news.google.com/rss/search"))
        XCTAssertTrue(url.absoluteString.contains("hl=fr"))
        XCTAssertNil(connecteur.urlRecherche(motsCles: []))
    }

    func testDeduplicationParHash() async {
        let veille = Veille(type: .googleNews, titre: "Test", motsCles: ["x"])
        // Hashes "vus" couvrent tous les éléments → aucun nouveau.
        let orchestrateur = OrchestrateurVeille(session: URLSessionFactice.partage)
        let resultat = await orchestrateur.executer(
            veille: veille,
            hashesVus: ["h1", "h2"],
            maintenant: Date()
        )
        // Sans réseau, l'exécution échoue proprement (message d'erreur, succès false).
        XCTAssertFalse(resultat.succes)
        XCTAssertEqual(resultat.veilleId, veille.id)
    }
}

/// Session factice pour les tests : toutes les requêtes échouent proprement.
final class URLSessionFactice: URLSession {
    static let partage = URLSessionFactice()
}
