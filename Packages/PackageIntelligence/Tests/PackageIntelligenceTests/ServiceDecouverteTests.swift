import XCTest
import PackageDomain
@testable import PackageIntelligence

/// Tests du mode découverte (estimation des appels, veille proposée,
/// structures du résultat) — sans réseau.
final class ServiceDecouverteTests: XCTestCase {

    func testEstimationAppelsBornee() {
        XCTAssertEqual(ServiceDecouverte.estimationAppels(thematique: "convoi"), 5)
        XCTAssertTrue(ServiceDecouverte.estimationAppels(thematique: String(repeating: "a", count: 400)) <= 15)
        XCTAssertTrue(ServiceDecouverte.estimationAppels(thematique: String(repeating: "a", count: 400)) >= 5)
    }

    func testSansClientRetourneNil() async {
        let service = ServiceDecouverte()
        let resultat = await service.decouvrir(thematique: "géopolitique du gaz")
        XCTAssertNil(resultat)
    }

    func testVeilleProposeeDepuisSourceInteret() {
        let source = ServiceDecouverte.SourceInteret(
            genre: .flux,
            url: "https://exemple.fr/rss",
            libelle: "Exemple",
            typeVeilleSuggere: .rss,
            motsClesSuggeres: ["convoi"]
        )
        let veille = ServiceDecouverte.veilleProposee(depuis: source)
        XCTAssertEqual(veille.type, .rss)
        XCTAssertEqual(veille.titre, "Veille — Exemple")
        XCTAssertEqual(veille.urlSource, "https://exemple.fr/rss")
        XCTAssertEqual(veille.motsCles, ["convoi"])
    }

    func testResultatDecouverteCodable() throws {
        let resultat = ServiceDecouverte.ResultatDecouverte(
            thematique: "convois",
            synthese: "Synthèse structurée.",
            sources: [
                ServiceDecouverte.SourceDecouverte(
                    url: "https://exemple.fr",
                    titre: "Exemple",
                    cotationProposee: .b
                )
            ],
            sourcesInteret: [
                ServiceDecouverte.SourceInteret(
                    genre: .reseauSocial,
                    url: "https://t.me/s/canal",
                    libelle: "Canal",
                    typeVeilleSuggere: .rss
                )
            ]
        )
        let data = try JSONEncoder().encode(resultat)
        let decode = try JSONDecoder().decode(ServiceDecouverte.ResultatDecouverte.self, from: data)
        XCTAssertEqual(decode, resultat)
        XCTAssertEqual(decode.sources.first?.cotationProposee, .b)
    }
}
