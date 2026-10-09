import XCTest
import PackageDomain
@testable import FeatureCapitaliser

/// Tests du service de complétion automatique (propositions, application,
/// marqueurs d'origine) — sans réseau (Wikipedia/Mistral absents en test).
final class ServiceCompletionTests: XCTestCase {

    func testPropositionBiographieIndividu() async {
        let service = ServiceCompletion()
        let entite = Entite(type: .individu, denomination: "Personne Inexistante ZZZQQQ")
        // Sans réseau : aucune proposition Wikipedia ; comportement silencieux.
        let propositions = await service.completer(entite: entite)
        XCTAssertTrue(propositions.allSatisfy { $0.champ != "biographie" || $0.origine == .internet })
    }

    func testApplicationValeurProposee() {
        var entite = Entite(type: .organisation, denomination: "ACME")
        let service = ServiceCompletion()
        let proposition = ServiceCompletion.ValeurProposee(champ: "resume", valeur: "Société fictive.", origine: .internet)
        service.appliquer(proposition, a: &entite)
        XCTAssertEqual(entite.resume, "Société fictive.")
    }

    func testApplicationSyntheseSelonType() {
        var individu = Entite(type: .individu, denomination: "Jean")
        var lieu = Entite(type: .lieu, denomination: "Lyon")
        let service = ServiceCompletion()
        let synthese = ServiceCompletion.ValeurProposee(champ: "synthese", valeur: "Texte de synthèse.", origine: .mistral)
        service.appliquer(synthese, a: &individu)
        service.appliquer(synthese, a: &lieu)
        XCTAssertEqual(individu.biographie, "Texte de synthèse.")
        XCTAssertEqual(lieu.resume, "Texte de synthèse.")
    }

    func testMarqueurOrigine() {
        let internet = ServiceCompletion.ValeurProposee(champ: "resume", valeur: "x", origine: .internet)
        let mistral = ServiceCompletion.ValeurProposee(champ: "synthese", valeur: "x", origine: .mistral)
        XCTAssertEqual(ServiceCompletion.marqueurOrigine(internet), "[source : internet]")
        XCTAssertEqual(ServiceCompletion.marqueurOrigine(mistral), "[source : mistral]")
    }
}
