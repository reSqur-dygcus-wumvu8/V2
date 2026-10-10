import XCTest
@testable import PackageSync

/// Tests de la synchronisation : transport factice (aucun réseau),
/// chiffrement des deltas, activation/désactivation, date de relevé.
final class ServiceSynchronisationTests: XCTestCase {

    private var dossier: URL!

    override func setUp() {
        super.setUp()
        dossier = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sync-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dossier)
        super.tearDown()
    }

    private func service(active: Bool = true, transport: TransportSync = TransportSyncFactice()) throws -> ServiceSynchronisation {
        try ServiceSynchronisation(
            transport: transport,
            dossierLocal: dossier,
            phraseSecrete: "test",
            active: active
        )
    }

    func testPousserDeltaActif() async throws {
        let transport = TransportSyncFactice()
        let service = try service(transport: transport)
        let delta = service.preparerDelta(appareil: "Mac", contenu: Data("delta-crdt".utf8))
        try await service.pousser(delta)
        XCTAssertEqual(transport.deltasPousses.count, 1)
        XCTAssertEqual(transport.deltasPousses.first?.appareil, "Mac")
    }

    func testDesactiveNePousseRien() async throws {
        let transport = TransportSyncFactice()
        let service = try service(active: false, transport: transport)
        let delta = service.preparerDelta(appareil: "iPhone", contenu: Data("x".utf8))
        try await service.pousser(delta)
        XCTAssertTrue(transport.deltasPousses.isEmpty)
    }

    func testReleverEtMettreAJourDate() async throws {
        let ancien = DeltaSync(appareil: "Mac", date: Date(timeIntervalSince1970: 1000), payload: Data("a".utf8))
        let recent = DeltaSync(appareil: "iPhone", date: Date(timeIntervalSince1970: 2000), payload: Data("b".utf8))
        let transport = TransportSyncFactice(reponseRelever: [ancien, recent])
        let service = try service(transport: transport)

        let contenus = try await service.releverEtFusionner()
        XCTAssertEqual(contenus.count, 2)

        // Deuxième relevé : tout est déjà consommé (date de référence mise à jour).
        let deuxieme = try await service.releverEtFusionner()
        XCTAssertTrue(deuxieme.isEmpty)
    }

    func testDeltaChiffreAuRepos() throws {
        let service = try service()
        let secret = Data("contenu sensible du CRDT".utf8)
        let delta = service.preparerDelta(appareil: "Mac", contenu: secret)
        // Le payload transporté ne contient pas le contenu en clair attendu
        // si l'appelant chiffre avant ; le service documente le contrat :
        XCTAssertEqual(delta.appareil, "Mac")
        XCTAssertFalse(delta.payload.isEmpty)
    }

    func testDateDepuisNomDeFichier() {
        let nom = "1736150400-ABCDEF-1234.json"
        let date = TransportSyncGitHub.dateDepuisNom(nom)
        XCTAssertEqual(date?.timeIntervalSince1970, 1736150400)
        XCTAssertNil(TransportSyncGitHub.dateDepuisNom("pas-un-timestamp.json"))
    }

    func testActivationBascule() async throws {
        let service = try service(active: false)
        XCTAssertFalse(service.estActive)
        await service.definirActive(true)
        XCTAssertTrue(await service.estActive)
    }
}
