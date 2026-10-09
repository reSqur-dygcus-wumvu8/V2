import Foundation
import Security
import PackageDomain

/// Accès au trousseau Keychain pour les secrets (DEK enveloppée, token proxy,
/// clé de session). Jamais de secret dans UserDefaults.
public final class KeychainStore: Sendable {

    /// Service trousseau utilisé par l'application principale.
    public static let servicePrincipal = "com.osintsuite.secrets"

    /// Groupe d'accès partagé entre OSINT Suite et le Gestionnaire d'accès
    /// (même Team ID). Seuls des éléments transitoires (clé de session)
    /// y sont placés — jamais la KEK.
    public let groupePartage: String?

    public init(groupePartage: String? = nil) {
        self.groupePartage = groupePartage
    }

    // MARK: - Lecture / écriture génériques

    /// Enregistre des données dans le trousseau (remplace l'entrée existante).
    public func enregistrer(_ donnees: Data, cle: String) throws {
        var requete = baseRequete(cle: cle)
        requete[kSecValueData as String] = donnees
        SecItemDelete(requete as CFDictionary)
        let statut = SecItemAdd(requete as CFDictionary, nil)
        guard statut == errSecSuccess else {
            throw ErreurKeychain.ecriture(statut)
        }
    }

    /// Lit des données du trousseau.
    public func lire(cle: String) throws -> Data? {
        var requete = baseRequete(cle: cle)
        requete[kSecReturnData as String] = true
        requete[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultat: AnyObject?
        let statut = SecItemCopyMatching(requete as CFDictionary, &resultat)
        if statut == errSecItemNotFound { return nil }
        guard statut == errSecSuccess else {
            throw ErreurKeychain.lecture(statut)
        }
        return resultat as? Data
    }

    /// Supprime une entrée du trousseau.
    public func supprimer(cle: String) throws {
        let requete = baseRequete(cle: cle)
        let statut = SecItemDelete(requete as CFDictionary)
        guard statut == errSecSuccess || statut == errSecItemNotFound else {
            throw ErreurKeychain.suppression(statut)
        }
    }

    /// Supprime toutes les entrées du service applicatif (panic wipe).
    public func toutSupprimer() throws {
        var requete: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.servicePrincipal
        ]
        if let groupe = groupePartage {
            requete[kSecAttrAccessGroup as String] = groupe
        }
        let statut = SecItemDelete(requete as CFDictionary)
        guard statut == errSecSuccess || statut == errSecItemNotFound else {
            throw ErreurKeychain.suppression(statut)
        }
    }

    // MARK: - Privé

    private func baseRequete(cle: String) -> [String: Any] {
        var requete: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.servicePrincipal,
            kSecAttrAccount as String: cle
        ]
        if let groupe = groupePartage {
            requete[kSecAttrAccessGroup as String] = groupe
        }
        return requete
    }
}

/// Erreurs du trousseau.
public enum ErreurKeychain: Error, LocalizedError {
    case ecriture(OSStatus)
    case lecture(OSStatus)
    case suppression(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .ecriture(let s): return "Erreur d'écriture trousseau (\(s))."
        case .lecture(let s): return "Erreur de lecture trousseau (\(s))."
        case .suppression(let s): return "Erreur de suppression trousseau (\(s))."
        }
    }
}
