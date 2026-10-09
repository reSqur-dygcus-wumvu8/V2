import XCTest
@testable import PackageDomain

/// Tests des cotations OTAN (types sûrs, codes composites, tris).
final class CotationsTests: XCTestCase {

    func testAffichageComposite() {
        let cotation = CotationOTAN(fiabiliteSource: .a, credibiliteInfo: .confirmee)
        XCTAssertEqual(cotation.code, "A1")
        let autre = CotationOTAN(fiabiliteSource: .c, credibiliteInfo: .possiblementVraie)
        XCTAssertEqual(autre.code, "C3")
    }

    func testAnalyseCodeComposite() {
        XCTAssertEqual(CotationOTAN.depuis(code: "A1")?.code, "A1")
        XCTAssertEqual(CotationOTAN.depuis(code: "c3")?.code, "C3")
        XCTAssertNil(CotationOTAN.depuis(code: "G1"))
        XCTAssertNil(CotationOTAN.depuis(code: "A7"))
        XCTAssertNil(CotationOTAN.depuis(code: "A"))
        XCTAssertNil(CotationOTAN.depuis(code: ""))
    }

    func testLibellesFiabilite() {
        XCTAssertEqual(FiabiliteSource.a.libelle, "Totalement fiable")
        XCTAssertEqual(FiabiliteSource.f.libelle, "Ne peut être jugée")
        XCTAssertEqual(FiabiliteSource.allCases.count, 6)
    }

    func testLibellesCredibilite() {
        XCTAssertEqual(CredibiliteInfo.confirmee.libelle, "Confirmée par d'autres sources")
        XCTAssertEqual(CredibiliteInfo.nePeutEtreJugee.libelle, "Ne peut être jugée")
        XCTAssertEqual(CredibiliteInfo.allCases.count, 6)
    }

    func testOrdreFiabilite() {
        XCTAssertTrue(FiabiliteSource.a < FiabiliteSource.f)
        XCTAssertTrue(CredibiliteInfo.confirmee < CredibiliteInfo.nePeutEtreJugee)
    }

    func testFiltreCotationMinimale() {
        let cotations = [
            CotationOTAN(fiabiliteSource: .a, credibiliteInfo: .confirmee),
            CotationOTAN(fiabiliteSource: .c, credibiliteInfo: .possiblementVraie),
            CotationOTAN(fiabiliteSource: .e, credibiliteInfo: .douteuse)
        ]
        let seuil = CotationOTAN(fiabiliteSource: .c, credibiliteInfo: .possiblementVraie).ordinal
        let visibles = cotations.filter { $0.ordinal <= seuil }
        XCTAssertEqual(visibles.count, 2)
    }
}

/// Tests des règles métier (priorités, similarités, normalisation).
final class ReglesMetierTests: XCTestCase {

    private func element(titre: String, contenu: String = "", cotation: FiabiliteSource? = nil) -> ElementVeille {
        ElementVeille(
            veilleId: UUID(),
            url: "https://exemple.fr",
            titre: titre,
            contenu: contenu,
            hashContenu: "abc",
            cotationSource: cotation
        )
    }

    func testScorePrioriteMotCleTitre() {
        let veille = Veille(type: .rss, titre: "Test", motsClesPriorite: ["urgence"])
        let el = element(titre: "Situation d'urgence à Paris", cotation: .b)
        let score = ReglesMetier.scorePriorite(element: el, veille: veille)
        XCTAssertGreaterThanOrEqual(score, 70)
        XCTAssertTrue(ReglesMetier.doitAlerter(score: score))
    }

    func testScoreBorne0100() {
        let veille = Veille(type: .rss, titre: "Test", motsClesPriorite: ["a", "b", "c", "d"])
        let el = element(titre: "a b c d", contenu: "a b c d", cotation: .a)
        let score = ReglesMetier.scorePriorite(element: el, veille: veille)
        XCTAssertLessThanOrEqual(score, 100)
        XCTAssertGreaterThanOrEqual(score, 0)
    }

    func testSimilariteJaccard() {
        let a = "Le convoi est passé par la route nationale"
        let b = "Le convoi est passé par la route départementale"
        let score = ReglesMetier.similariteJaccard(a, b)
        XCTAssertGreaterThan(score, 0.5)
        XCTAssertLessThan(score, 1.0)
        XCTAssertEqual(ReglesMetier.similariteJaccard(a, a), 1.0)
        XCTAssertEqual(ReglesMetier.similariteJaccard("", ""), 0.0)
    }

    func testNormalisation() {
        let normalisee = ReglesMetier.normaliser("Événement: à Paris!")
        XCTAssertEqual(normalisee, "evenement a paris")
    }
}

/// Tests de construction des entités (valeurs par défaut, champs par type).
final class EntitesTests: XCTestCase {

    func testChampsParType() {
        XCTAssertEqual(TypeEntite.individu.champs, ["prenom", "nom", "biographie", "commentaires"])
        XCTAssertEqual(TypeEntite.source.champs, ["denomination", "description", "cotation"])
        XCTAssertTrue(TypeEntite.lieu.champs.contains("coordonneesGPS"))
    }

    func testConstructionIndividu() {
        var entite = Entite(type: .individu, denomination: "Dupont Jean")
        entite.prenom = "Jean"
        entite.nom = "Dupont"
        XCTAssertEqual(entite.type, .individu)
        XCTAssertNil(entite.cotationSource)
        XCTAssertEqual(TypeEntite.individu.libelle, "Individu")
    }

    func testConstructionDocument() {
        let doc = Document(
            nom: "rapport.pdf",
            typeMime: "application/pdf",
            hashSHA256: "deadbeef",
            sourceId: UUID()
        )
        XCTAssertEqual(doc.statut, .nonTraite)
        XCTAssertNil(doc.cotation)
    }
}
