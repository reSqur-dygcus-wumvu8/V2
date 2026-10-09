import Foundation
import CryptoKit

/// Génération et manipulation des clés du modèle à deux niveaux.
/// La KEK enveloppe la DEK ; seule une clé de session dérivée (à durée
/// limitée) transite dans le groupe de trousseau partagé — jamais la KEK.
public enum ModeleCles {

    /// Taille des clés symétriques (AES-256).
    public static let tailleCle = SymmetricKeySize.bits256

    /// Génère une DEK (clé de chiffrement des données, 256 bits).
    public static func genererDEK() -> SymmetricKey {
        SymmetricKey(size: tailleCle)
    }

    /// Enveloppe la DEK avec la KEK (AES-GCM) : seul ce « wrap » est stocké.
    public static func envelopper(dek: SymmetricKey, kek: SymmetricKey) throws -> EnveloppeDEK {
        let scrambled = try AES.GCM.seal(
            dek.withUnsafeBytes { Data($0) },
            using: kek
        )
        return EnveloppeDEK(donnees: scrambled.combined)
    }

    /// Déballe la DEK avec la KEK.
    public static func deballer(enveloppe: EnveloppeDEK, kek: SymmetricKey) throws -> SymmetricKey {
        let boite = try AES.GCM.SealedBox(combined: enveloppe.donnees)
        let dek = try AES.GCM.open(boite, using: kek)
        return SymmetricKey(data: dek)
    }

    /// Dérive une clé de session à durée limitée depuis la KEK (HKDF) :
    /// c'est la seule valeur placée dans le trousseau partagé.
    public static func cleSession(kek: SymmetricKey, expiration: Date) -> CleSession {
        let sel = Data("osint-suite-session".utf8)
        let derivee = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: kek,
            salt: sel,
            outputByteCount: 32
        )
        return CleSession(cle: derivee, expiration: expiration)
    }

    /// Génère une phrase de récupération (12 mots, affichée une seule fois).
    /// Sert de secours : KEK dérivée de la phrase si le Secure Enclave est
    /// indisponible (changement d'appareil).
    public static func phraseRecuperation() -> [String] {
        (0..<12).map { _ in
            LexiqueRecuperation.mots.randomElement()!
        }
    }

    /// Dérive une KEK de secours depuis la phrase de récupération.
    public static func kekDepuisPhrase(_ mots: [String]) -> SymmetricKey? {
        guard mots.count == 12 else { return nil }
        let phrase = mots.joined(separator: " ").lowercased()
        guard let donnees = phrase.data(using: .utf8) else { return nil }
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: donnees),
            salt: Data("osint-suite-kek-secours".utf8),
            outputByteCount: 32
        )
    }
}

/// DEK enveloppée (stockable dans le trousseau partagé).
public struct EnveloppeDEK: Sendable, Equatable {
    public let donnees: Data

    public init(donnees: Data) {
        self.donnees = donnees
    }
}

/// Clé de session transitoire délivrée à l'application principale.
public struct CleSession: Sendable, Equatable {
    public let cle: SymmetricKey
    public let expiration: Date

    public init(cle: SymmetricKey, expiration: Date) {
        self.cle = cle
        self.expiration = expiration
    }

    /// La session est-elle encore valide ?
    public func estValide(maintenant: Date = Date()) -> Bool {
        maintenant < expiration
    }
}

/// Lexique de la phrase de récupération (sous-ensemble simple et vérifiable).
public enum LexiqueRecuperation {
    public static let mots: [String] = [
        "abricot", "ancre", "bison", "braise", "cactus", "carte",
        "dauphin", "dune", "eclipse", "erable", "faucon", "forge",
        "gazelle", "glacier", "harpe", "hibou", "ivoire", "jade",
        "koala", "lagune", "lotus", "mimosa", "neptune", "olive",
        "orage", "panda", "quartz", "riviere", "sable", "tempete",
        "tulipe", "ursus", "vautour", "zebre", "cygne", "mistral"
    ]
}
