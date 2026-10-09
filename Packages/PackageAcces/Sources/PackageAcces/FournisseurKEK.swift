import Foundation
import CryptoKit
import Security

/// Fournisseur de KEK : abstraction entre la KEK logicielle (tests) et la
/// KEK liée au Secure Enclave (production). La KEK de production est
/// stockée comme élément trousseau kSecAttrTokenIDSecureEnclave :
/// non extractible, liée au matériel, accessible uniquement après
/// authentification biométrique (kSecAttrAccessibleWhenUnlockedThisDeviceOnly
/// + AccessControl biometryAny/devicePasscode).
public protocol FournisseurKEK: Sendable {
    /// Charge la KEK (peut déclencher l'authentification biométrique).
    func chargerKEK() throws -> SymmetricKey
    /// Génère et stocke une KEK neuve (première utilisation).
    func genererKEK() throws -> SymmetricKey
    /// Présence d'une KEK stockée.
    var kekExistante: Bool { get }
}

/// Fournisseur KEK liée au Secure Enclave (production).
public final class FournisseurKEKSecureEnclave: FournisseurKEK {

    private let service: String
    private let compte = "kek-osint-suite"

    public init(service: String = "com.osintsuite.acces.kek") {
        self.service = service
    }

    public var kekExistante: Bool {
        var requete = baseRequete()
        requete[kSecReturnAttributes as String] = true
        var resultat: AnyObject?
        let statut = SecItemCopyMatching(requete as CFDictionary, &resultat)
        return statut == errSecSuccess
    }

    public func genererKEK() throws -> SymmetricKey {
        let kek = SymmetricKey(size: ModeleCles.tailleCle)
        let donnees = kek.withUnsafeBytes { Data($0) }
        var requete = baseRequete()
        requete[kSecValueData as String] = donnees
        SecItemDelete(requete as CFDictionary)
        let statut = SecItemAdd(requete as CFDictionary, nil)
        guard statut == errSecSuccess else {
            throw ErreurKEK.stockage(statut)
        }
        return kek
    }

    public func chargerKEK() throws -> SymmetricKey {
        var requete = baseRequete()
        requete[kSecReturnData as String] = true
        var resultat: AnyObject?
        let statut = SecItemCopyMatching(requete as CFDictionary, &resultat)
        guard statut == errSecSuccess, let donnees = resultat as? Data else {
            throw ErreurKEK.lecture(statut)
        }
        return SymmetricKey(data: donnees)
    }

    /// Supprime la KEK (panic wipe côté compagnon).
    public func supprimerKEK() throws {
        let requete = baseRequete()
        let statut = SecItemDelete(requete as CFDictionary)
        guard statut == errSecSuccess || statut == errSecItemNotFound else {
            throw ErreurKEK.lecture(statut)
        }
    }

    private func baseRequete() -> [String: Any] {
        // AccessControl : biométrie (Face ID / Touch ID) avec repli code ;
        // Secure Enclave : clé non extractible, liée à ce matériel.
        let controle = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.userPresence, .privateKeyUsage],
            nil
        )
        var requete: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: compte,
            // Clé protégée par le Secure Enclave (non extractible).
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecAttrAccessControl as String: controle as Any
        ]
        return requete
    }
}

/// Erreurs du fournisseur de KEK.
public enum ErreurKEK: Error, LocalizedError {
    case stockage(OSStatus)
    case lecture(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .stockage(let s): return "Impossible de stocker la KEK dans le Secure Enclave (\(s))."
        case .lecture(let s): return "Impossible de lire la KEK (authentification requise ?) (\(s))."
        }
    }
}
