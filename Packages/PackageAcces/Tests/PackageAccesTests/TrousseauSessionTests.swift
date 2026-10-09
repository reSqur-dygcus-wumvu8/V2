import XCTest
import CryptoKit
@testable import PackageAcces

/// Tests de sérialisation de la clé de session (clé + expiration).
final class TrousseauSessionTests: XCTestCase {

    func testEncodageDecodageSession() throws {
        let cle = SymmetricKey(size: .bits256)
        let expiration = Date().addingTimeInterval(600)
        let session = CleSession(cle: cle, expiration: expiration)

        let donnees = EncoderSession.encoder(session)
        XCTAssertEqual(donnees.count, 40) // 32 octets clé + 8 octets expiration

        let decodee = try XCTUnwrap(EncoderSession.decoder(donnees))
        XCTAssertEqual(
            cle.withUnsafeBytes { Data($0) },
            decodee.cle.withUnsafeBytes { Data($0) }
        )
        XCTAssertEqual(decodee.expiration.timeIntervalSince1970,
                       expiration.timeIntervalSince1970, accuracy: 0.001)
    }

    func testDecodageDonneesCorrompuesRefuse() {
        XCTAssertNil(EncoderSession.decoder(Data(repeating: 0, count: 10)))
        XCTAssertNil(EncoderSession.decoder(Data(count: 41)))
    }

    func testSessionExpireeInvalide() {
        let session = CleSession(
            cle: SymmetricKey(size: .bits256),
            expiration: Date().addingTimeInterval(-1)
        )
        XCTAssertFalse(session.estValide())
    }
}
