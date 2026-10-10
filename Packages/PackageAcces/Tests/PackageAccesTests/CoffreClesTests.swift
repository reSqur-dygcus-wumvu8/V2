import XCTest
import CryptoKit
@testable import PackageAcces

/// Tests du modèle de clés KEK/DEK (enveloppement, session, phrase de secours).
final class ModeleClesTests: XCTestCase {


    func testEnvelopperDeballerDEK() throws {
        let dek = ModeleCles.genererDEK()
        let kek = SymmetricKey(size: .bits256)
        let enveloppe = try ModeleCles.envelopper(dek: dek, kek: kek)
        let deballee = try ModeleCles.deballer(enveloppe: enveloppe, kek: kek)
        XCTAssertEqual(dek.withUnsafeBytes { Data($0) }, deballee.withUnsafeBytes { Data($0) })
    }

    func testDeballageAvecMauvaiseKEKEchoue() throws {
        let dek = ModeleCles.genererDEK()
        let enveloppe = try ModeleCles.envelopper(dek: dek, kek: SymmetricKey(size: .bits256))
        XCTAssertThrowsError(try ModeleCles.deballer(enveloppe: enveloppe, kek: SymmetricKey(size: .bits256)))
    }

    func testCleSessionDifferentedeKEK() {
        let kek = SymmetricKey(size: .bits256)
        let session = ModeleCles.cleSession(kek: kek, expiration: Date().addingTimeInterval(60))
        XCTAssertNotEqual(
            kek.withUnsafeBytes { Data($0) },
            session.cle.withUnsafeBytes { Data($0) }
        )
        XCTAssertTrue(session.estValide())
        XCTAssertFalse(session.estValide(maintenant: Date().addingTimeInterval(120)))
    }

    func testPhraseRecuperationEtRestauration() throws {
        let phrase = ModeleCles.phraseRecuperation()
        XCTAssertEqual(phrase.count, 12)
        let kekSecours = try XCTUnwrap(ModeleCles.kekDepuisPhrase(phrase))
        // La même phrase dérive toujours la même KEK de secours.
        let kekSecours2 = try XCTUnwrap(ModeleCles.kekDepuisPhrase(phrase))
        XCTAssertEqual(kekSecours.withUnsafeBytes { Data($0) }, kekSecours2.withUnsafeBytes { Data($0) })
        // Phrase invalide refusée.
        XCTAssertNil(ModeleCles.kekDepuisPhrase(Array(phrase.prefix(11))))
        // Une phrase différente dérive une KEK différente.
        let autre = try XCTUnwrap(ModeleCles.kekDepuisPhrase(phrase.reversed()))
        XCTAssertNotEqual(kekSecours.withUnsafeBytes { Data($0) }, autre.withUnsafeBytes { Data($0) })
    }
}

/// Tests du coffret de clés : sessions, politiques, rotations, panic wipe, audit.
final class CoffreClesTests: XCTestCase {

    func testInitialisationSecretMLA() async {
        let coffret = CoffreCles(kek: SymmetricKey(size: .bits256))
        let phrase = await coffret.initialiserSecretMLA()
        let enveloppe = await coffret.enveloppe()
        XCTAssertNotNil(enveloppe)
        // Phrase secrète base64 d'une clé 256 bits (44 caractères).
        XCTAssertEqual(phrase.count, 44)
    }

    func testDelivranceSessionAppareilAutorise() async throws {
        let coffret = CoffreCles(kek: SymmetricKey(size: .bits256))
        _ = await coffret.initialiserSecretMLA()
        await coffret.autoriser(AppareilAutorise(nom: "Mac principal", profil: .complet))

        let session = await coffret.delivrerSession(appareil: "Mac principal", duree: 600)
        XCTAssertNotNil(session)
        XCTAssertTrue(session!.estValide())

        // La DEK se déballe avec la clé de session.
        let dek = try await coffret.deballerDEK(session: session!)
        XCTAssertEqual(dek.bitCount, 256)
    }

    func testRefusAppareilInconnuOuRevogue() async throws {
        let coffret = CoffreCles(kek: SymmetricKey(size: .bits256))
        _ = await coffret.initialiserSecretMLA()
        await coffret.autoriser(AppareilAutorise(nom: "iPhone", profil: .lectureSeule))

        // Inconnu.
        XCTAssertNil(await coffret.delivrerSession(appareil: "iPad inconnu"))

        // Révoqué.
        let appareil = await coffret.appareilsAutorises().first!
        await coffret.revoquer(id: appareil.id)
        XCTAssertNil(await coffret.delivrerSession(appareil: "iPhone"))

        // Le refus est consigné dans l'audit.
        let journal = await coffret.journalAudit()
        XCTAssertTrue(journal.contains { !$0.succes })
    }

    func testPlageHoraire() async throws {
        let coffret = CoffreCles(kek: SymmetricKey(size: .bits256))
        _ = await coffret.initialiserSecretMLA()
        // Plage 9h–18h uniquement.
        await coffret.autoriser(
            AppareilAutorise(nom: "Bureau", profil: .complet, plageHoraireDebut: 9, plageHoraireFin: 18)
        )
        // Heure hors plage (23h simulée) : refus.
        let nuit = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!
        XCTAssertNil(await coffret.delivrerSession(appareil: "Bureau", duree: 600, maintenant: nuit))
        // Heure dans la plage (12h simulée) : accord.
        let midi = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        XCTAssertNotNil(await coffret.delivrerSession(appareil: "Bureau", duree: 600, maintenant: midi))
    }

    func testSessionExpireeRefuseeAuDeballage() async throws {
        let coffret = CoffreCles(kek: SymmetricKey(size: .bits256))
        _ = await coffret.initialiserSecretMLA()
        await coffret.autoriser(AppareilAutorise(nom: "Mac", profil: .complet))
        let session = await coffret.delivrerSession(appareil: "Mac", duree: 600)
        let expiree = CleSession(cle: session!.cle, expiration: Date().addingTimeInterval(-1))
        do {
            _ = try await coffret.deballerDEK(session: expiree)
            XCTFail("Doit refuser une session expirée")
        } catch {
            // Attendu.
        }
    }

    func testRotationKEKInvalideAncienne() async throws {
        let coffret = CoffreCles(kek: SymmetricKey(size: .bits256))
        _ = await coffret.initialiserSecretMLA()
        await coffret.autoriser(AppareilAutorise(nom: "Mac", profil: .complet))
        let sessionAvant = await coffret.delivrerSession(appareil: "Mac", duree: 600)

        try await coffret.rotationKEK(nouvelleKEK: SymmetricKey(size: .bits256))

        // La session délivrée avant la rotation ne déballe plus la nouvelle enveloppe.
        let enveloppe = await coffret.enveloppe()
        XCTAssertThrowsError(try ModeleCles.deballer(enveloppe: enveloppe!, kek: sessionAvant!.cle))
    }

    func testRotationSecretMLARetourneNouvellePhrase() async throws {
        let coffret = CoffreCles(kek: SymmetricKey(size: .bits256))
        let phrase1 = await coffret.initialiserSecretMLA()
        let phrase2 = try await coffret.rotationSecretMLA()
        XCTAssertNotEqual(phrase1, phrase2)
        XCTAssertEqual(phrase2.count, 44)
    }

    func testPanicWipeRendArchivesIllisibles() async throws {
        let coffret = CoffreCles(kek: SymmetricKey(size: .bits256))
        _ = await coffret.initialiserSecretMLA()
        let enveloppeAvant = await coffret.enveloppe()
        await coffret.autoriser(AppareilAutorise(nom: "Mac", profil: .complet))
        _ = await coffret.delivrerSession(appareil: "Mac", duree: 600)

        await coffret.panique()

        // Plus d'enveloppe, plus de session délivrable.
        XCTAssertNil(await coffret.enveloppe())
        XCTAssertNil(await coffret.delivrerSession(appareil: "Mac"))
        // L'audit consigne le panic wipe.
        let journal = await coffret.journalAudit()
        XCTAssertTrue(journal.contains { $0.action.contains("PANIC") })
    }

    func testExportAuditJSON() async throws {
        let coffret = CoffreCles(kek: SymmetricKey(size: .bits256))
        _ = await coffret.initialiserSecretMLA()
        await coffret.autoriser(AppareilAutorise(nom: "Mac", profil: .complet))
        _ = await coffret.delivrerSession(appareil: "Mac")
        let donnees = try XCTUnwrap(await coffret.exporterAudit())
        let entrees = try JSONDecoder().decode([EntreeAudit].self, from: donnees)
        XCTAssertFalse(entrees.isEmpty)
    }
}
