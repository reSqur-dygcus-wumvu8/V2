import XCTest
import PackageDomain
@testable import PackagePersistence

/// Tests du moteur de stockage MLA : cycle complet ouverture → mutations →
/// consolidation → réouverture, chiffrement au repos, index, panic wipe.
final class MoteurStockageTests: XCTestCase {

    private var dossier: URL!

    override func setUp() {
        super.setUp()
        dossier = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("moteur-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dossier)
        super.tearDown()
    }

    func testCycleCompletConsolidationReouverture() throws {
        // Session 1 : écritures puis consolidation.
        let moteur = try MoteurStockage(dossier: dossier, phraseSecrete: "session-1")
        let entite = Entite(type: .individu, denomination: "Jean Dupont", prenom: "Jean", nom: "Dupont")
        moteur.muter { $0.enregistrerEntite(entite) }
        let source = SourceInfo(denomination: "Le Monde", cotation: .b)
        moteur.muter { $0.sources[source.id] = source }
        let document = Document(nom: "rapport.txt", typeMime: "text/plain",
                                hashSHA256: "abc", texteExtrait: "convoi", sourceId: source.id)
        XCTAssertTrue(moteur.enregistrerDocument(document))
        try moteur.consolider()

        // Session 2 : réouverture avec la même phrase — tout est restitué.
        let moteur2 = try MoteurStockage(dossier: dossier, phraseSecrete: "session-1")
        XCTAssertEqual(try XCTUnwrap(moteur2.chercherEntite(id: entite.id)).denomination, "Jean Dupont")
        XCTAssertEqual(moteur2.sources.count, 1)
        XCTAssertEqual(moteur2.documents.count, 1)
    }

    func testReouvertureSansPhraseEchoue() throws {
        let moteur = try MoteurStockage(dossier: dossier, phraseSecrete: "bonne")
        moteur.muter { $0.enregistrerEntite(Entite(type: .lieu, denomination: "Lyon")) }
        try moteur.consolider()
        // Mauvaise phrase de session : les archives ne se déchiffrent pas.
        XCTAssertThrowsError(try MoteurStockage(dossier: dossier, phraseSecrete: "fausse"))
    }

    func testDeduplicationDocumentsEtElements() throws {
        let moteur = try MoteurStockage(dossier: dossier, phraseSecrete: "s")
        let source = SourceInfo(denomination: "S")
        moteur.muter { $0.sources[source.id] = source }
        let d1 = Document(nom: "a", typeMime: "text/plain", hashSHA256: "h1", sourceId: source.id)
        let d2 = Document(nom: "b", typeMime: "text/plain", hashSHA256: "h1", sourceId: source.id)
        XCTAssertTrue(moteur.enregistrerDocument(d1))
        XCTAssertFalse(moteur.enregistrerDocument(d2))

        let veilleId = UUID()
        let e1 = ElementVeille(veilleId: veilleId, url: "https://a.fr", titre: "A",
                                contenu: "c", hashContenu: "h-e1")
        let e2 = ElementVeille(veilleId: veilleId, url: "https://a.fr", titre: "A",
                               contenu: "c", hashContenu: "h-e1")
        XCTAssertTrue(moteur.enregistrerElement(e1))
        XCTAssertFalse(moteur.enregistrerElement(e2))
    }

    func testRecherchePleinTexteNormalisee() throws {
        let moteur = try MoteurStockage(dossier: dossier, phraseSecrete: "s")
        moteur.muter {
            $0.enregistrerEntite(Entite(type: .individu, denomination: "Événement à Paris",
                                       resume: "Le convoi est passé"))
        }
        XCTAssertEqual(moteur.rechercher(texte: "convoi").count, 1)
        XCTAssertEqual(moteur.rechercher(texte: "ÉVÉNEMENT").count, 1)
        XCTAssertTrue(moteur.rechercher(texte: "lyon").isEmpty)
    }

    func testFileAttenteEtMarquage() throws {
        let moteur = try MoteurStockage(dossier: dossier, phraseSecrete: "s")
        let veilleId = UUID()
        let e1 = ElementVeille(veilleId: veilleId, url: "u1", titre: "T1", contenu: "c", hashContenu: "h1")
        let e2 = ElementVeille(veilleId: veilleId, url: "u2", titre: "T2", contenu: "c", hashContenu: "h2")
        _ = moteur.enregistrerElement(e1)
        _ = moteur.enregistrerElement(e2)
        XCTAssertEqual(moteur.elements.values.filter { $0.statut == .nonTraite }.count, 2)
        moteur.marquerElement(e1.id, statut: .capitalise)
        XCTAssertEqual(moteur.elements.values.filter { $0.statut == .nonTraite }.count, 1)
    }

    func testPanicWipeEffaceTout() throws {
        let moteur = try MoteurStockage(dossier: dossier, phraseSecrete: "s")
        moteur.muter { $0.enregistrerEntite(Entite(type: .objet, denomination: "Véhicule")) }
        try moteur.consolider()
        try moteur.panicWipe()
        XCTAssertTrue(moteur.entites.isEmpty)
        // Après wipe, une réouverture ne trouve plus aucun segment.
        let moteur2 = try MoteurStockage(dossier: dossier, phraseSecrete: "s")
        XCTAssertTrue(moteur2.entites.isEmpty)
    }

    func testDoublonsEtFusionsPersistes() throws {
        let moteur = try MoteurStockage(dossier: dossier, phraseSecrete: "s")
        let a = UUID(), b = UUID()
        moteur.muter {
            $0.enregistrerProposition(PropositionDoublon(idA: a, idB: b, score: 0.9))
        }
        moteur.muter {
            $0.deciderProposition(UUID(), statut: .refuse, date: Date())
        }
        // Décision sur la proposition réelle.
        let idProposition = moteur.propositionsDoublon.values.first!.id
        moteur.muter { $0.deciderProposition(idProposition, statut: .refuse, date: Date()) }
        moteur.muter {
            $0.enregistrerFusion(EntreeFusion(entiteGardee: a, entiteFusionnee: b, champsChoisis: ["resume"]))
        }
        try moteur.consolider()

        let moteur2 = try MoteurStockage(dossier: dossier, phraseSecrete: "s")
        XCTAssertEqual(moteur2.propositionsDoublon.values.first?.statut, .refuse)
        XCTAssertEqual(moteur2.journalFusions.count, 1)
    }
}

extension MoteurStockage {
    /// Accès de test : recherche d'entité par identifiant.
    func chercherEntite(id: UUID) -> Entite? {
        entites[id].map { $0.supprime ? nil : $0 }
    }
}
