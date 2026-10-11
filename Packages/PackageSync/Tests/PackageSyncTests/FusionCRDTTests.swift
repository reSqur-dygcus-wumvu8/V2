import XCTest
@testable import PackageSync

/// Tests de la fusion CRDT Automerge : modifications concurrentes fusionnées
/// sans conflit ni perte — jamais « dernier écrit gagnant ».
final class FusionCRDTTests: XCTestCase {

    func testCreationEtLectureDocument() throws {
        let fusion = FusionCRDT()
        let etat = try fusion.creerDocument(texte: "Le convoi est passé par la route nationale.")
        XCTAssertEqual(try fusion.texteCourant(etat: etat),
                       "Le convoi est passé par la route nationale.")
    }

    func testModificationLocaleAppliquee() throws {
        let fusion = FusionCRDT()
        var etat = try fusion.creerDocument(texte: "Version initiale.")
        try fusion.appliquerModification(etat: &etat, texte: "Version modifiée localement.")
        XCTAssertEqual(try fusion.texteCourant(etat: etat), "Version modifiée localement.")
    }

    func testFusionModificationsConcurrentesSansPerte() throws {
        let fusion = FusionCRDT()
        // Les deux appareils partagent le même état initial (même document,
        // même historique — condition nécessaire à une fusion CRDT).
        let etatInitial = try fusion.creerDocument(texte: "Biographie commune.")
        var etatA = etatInitial
        var etatB = etatInitial

        // Chaque appareil modifie indépendamment (hors ligne).
        try fusion.appliquerModification(etat: &etatA, texte: "Biographie commune. Ajout de A.")
        try fusion.appliquerModification(etat: &etatB, texte: "Biographie commune. Ajout de B.")

        // Reconnexion : A fusionne le delta de B — les deux ajouts subsistent.
        try fusion.fusionner(etatLocal: &etatA, delta: etatB)
        let resultat = try fusion.texteCourant(etat: etatA)
        XCTAssertTrue(resultat.contains("Ajout de A"), "la modification de A doit subsister")
        XCTAssertTrue(resultat.contains("Ajout de B"), "la modification de B doit subsister (pas de dernier-écrit-gagnant)")
    }

    func testFusionIdempotente() throws {
        let fusion = FusionCRDT()
        var etat = try fusion.creerDocument(texte: "Texte stable.")
        try fusion.fusionner(etatLocal: &etat, delta: etat)
        XCTAssertEqual(try fusion.texteCourant(etat: etat), "Texte stable.")
    }
}
