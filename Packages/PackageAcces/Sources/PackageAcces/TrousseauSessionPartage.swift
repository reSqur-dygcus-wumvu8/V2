import Foundation
import Security
import CryptoKit

/// Trousseau partagé pour la clé de session : SEUL élément transitoire
/// partagé entre le Gestionnaire d'accès et OSINT Suite (groupe d'accès
/// du Team ID commun). La KEK n'y est jamais placée.
public struct TrousseauSessionPartage: Sendable {

    /// Clé de compte de la session dans le trousseau partagé.
    public static let compteSession = "session-osint"

    let groupePartage: String

    /// - Parameter groupePartage: groupe d'accès trousseau (ex. "TEAMID.fr.osintsuite.shared").
    public init(groupePartage: String) {
        self.groupePartage = groupePartage
    }

    // MARK: - Écriture (côté Gestionnaire d'accès)

    /// Publie la clé de session dans le trousseau partagé avec son expiration.
    public func publier(_ session: CleSession) throws {
        try ecrire(cle: Self.compteSession, donnees: EncoderSession.encoder(session))
    }

    /// Purge la session (expiration ou passage en arrière-plan).
    public func purger() {
        var requete: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.compteSession,
            kSecAttrAccessGroup as String: groupePartage
        ]
        SecItemDelete(requete as CFDictionary)
    }

    // MARK: - Lecture (côté OSINT Suite)

    /// Lit la clé de session publiée, si elle est encore valide.
    public func lireSession(maintenant: Date = Date()) throws -> CleSession? {
        var requete: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount: Self.compteSession,
            kSecAttrAccessGroup: groupePartage,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var resultat: AnyObject?
        let statut = SecItemCopyMatching(requete as CFDictionary, &resultat)
        guard statut == errSecSuccess, let donnees = resultat as? Data else { return nil }
        guard let session = EncoderSession.decoder(donnees), session.estValide(maintenant: maintenant) else {
            purger()
            return nil
        }
        return session
    }

    private func ecrire(cle: String, donnees: Data) throws {
        var requete: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount: cle,
            kSecAttrAccessGroup: groupePartage,
            kSecValueData: donnees
        ]
        SecItemDelete(requete as CFDictionary)
        let statut = SecItemAdd(requete as CFDictionary, nil)
        guard statut == errSecSuccess else {
            throw ErreurSessionPartage.ecriture(statut)
        }
    }
}

/// Erreurs du trousseau partagé.
public enum ErreurSessionPartage: Error, LocalizedError {
    case ecriture(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .ecriture(let s): return "Écriture de la session dans le trousseau partagé impossible (\(s))."
        }
    }
}

/// Sérialisation de la clé de session (clé + expiration).
enum EncoderSession {
    static func encoder(_ session: CleSession) -> Data {
        let cle = session.cle.withUnsafeBytes { Data($0) }
        return cle + avecExpiration(session.expiration)
    }

    static func decoder(_ donnees: Data) -> CleSession? {
        guard donnees.count == 32 + 8 else { return nil }
        let cle = donnees.prefix(32)
        let expiration = depuisExpiration(donnees.suffix(8))
        return CleSession(cle: SymmetricKey(data: cle), expiration: expiration)
    }

    private static func avecExpiration(_ date: Date) -> Data {
        withUnsafeBytes(of: date.timeIntervalSince1970.bitPattern) { Data($0) }
    }

    private static func depuisExpiration(_ donnees: Data) -> Date {
        donnees.withUnsafeBytes { raw in
            let bits = raw.load(as: UInt64.self)
            return Date(timeIntervalSince1970: Double(bits: bits))
        }
    }
}
