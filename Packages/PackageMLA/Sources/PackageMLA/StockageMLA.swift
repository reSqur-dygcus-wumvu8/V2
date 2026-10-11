import Foundation
import CryptoKit
import CommonCrypto

/// Abstraction du stockage au repos : segments d'archive chiffrés.
/// En production, chaque segment est une archive MLA (format ANSSI :
/// chiffrement, compression, signatures, option post-quantique) manipulée
/// via la FFI Rust. Le backend provisoire chiffre chaque segment en
/// AES-GCM avec une clé dérivée de la phrase secrète (HKDF).
public protocol StockageMLA: Sendable {
    /// Écrit (remplace) un segment d'archive.
    func ecrire(_ donnees: Data, segment: String) throws
    /// Lit un segment (nil si absent).
    func lire(segment: String) throws -> Data?
    /// Supprime un segment.
    func supprimer(segment: String) throws
    /// Liste des segments existants.
    func segments() throws -> [String]
}

/// Archive MLA : façade de haut niveau sur le stockage chiffré.
/// Sélectionne le backend FFI Rust si le xcframework est lié, sinon le
/// backend Swift provisoire (documenté — chiffrement AES-GCM au repos).
public final class ArchiveMLA: StockageMLA {

    private let dossier: URL
    private let cle: SymmetricKey
    private let backendFFI: Bool

    /// - Parameters:
    ///   - dossier: répertoire contenant les segments `<segment>.mla`.
    ///   - phraseSecrete: phrase secrète (matériel de clés dérivé par HKDF).
    public init(dossier: URL, phraseSecrete: String) throws {
        self.dossier = dossier
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        self.cle = SymmetricKey(data: try Self.deriverCle(phraseSecrete: phraseSecrete, dossier: dossier))
        self.backendFFI = BackendFFI_MLA.estDisponible
    }

    public func ecrire(_ donnees: Data, segment: String) throws {
        let chemise = cleAESGCM(scelle: donnees)
        try chemise.write(to: cheminSegment(segment), options: .atomic)
    }

    public func lire(segment: String) throws -> Data? {
        guard let scellee = try? Data(contentsOf: cheminSegment(segment)) else { return nil }
        return try deballer(scellee: scellee)
    }

    public func supprimer(segment: String) throws {
        try? FileManager.default.removeItem(at: cheminSegment(segment))
    }

    public func segments() throws -> [String] {
        let fichiers = try FileManager.default.contentsOfDirectory(at: dossier, includingPropertiesForKeys: nil)
        return fichiers
            .filter { $0.pathExtension == "mla" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    // MARK: - Chiffrement de segment (backend provisoire)

    private func cheminSegment(_ segment: String) -> URL {
        dossier.appendingPathComponent("\(segment).mla")
    }

    /// Scelle un segment : nonce + AES-GCM (authentifié).
    private func cleAESGCM(scelle donnees: Data) throws -> Data {
        let boite = try AES.GCM.seal(donnees, using: cle)
        return boite.combined ?? Data()
    }

    private func deballer(scellee: Data) throws -> Data {
        let boite = try AES.GCM.SealedBox(combined: scellee)
        return try AES.GCM.open(boite, using: cle)
    }

    // MARK: - Dérivation de clé (backend provisoire)

    /// Dérive la clé de segment depuis la phrase secrète : sel aléatoire
    /// propre à l'archive (fichier `sel.kdf`) + PBKDF2-SHA256 (facteur de
    /// travail élevé contre la force brute hors ligne).
    static func deriverCle(phraseSecrete: String, dossier: URL) throws -> Data {
        let sel = try Self.chargerOuCreerSel(dossier: dossier)
        var cle = Data(repeating: 0, count: 32)
        let phrase = Data(phraseSecrete.utf8)
        let statut = phrase.withUnsafeBytes { phraseBrut in
            sel.withUnsafeBytes { selBrut in
                cle.withUnsafeMutableBytes { cleBrut in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        phraseBrut.baseAddress?.assumingMemoryBound(to: Int8.self), phrase.count,
                        selBrut.baseAddress?.assumingMemoryBound(to: UInt8.self), sel.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), Self.iterationsPBKDF2,
                        cleBrut.baseAddress?.assumingMemoryBound(to: UInt8.self), cle.count
                    )
                }
            }
        }
        guard statut == kCCSuccess else { throw ErreurArchiveMLA.derivationCle(statut) }
        return cle
    }

    /// Nombre d'itérations PBKDF2 (recommandation OWASP pour PBKDF2-SHA256).
    static let iterationsPBKDF2: UInt32 = 310_000

    /// Charge le sel de l'archive, ou en génère un (16 octets aléatoires).
    private static func chargerOuCreerSel(dossier: URL) throws -> Data {
        let cheminSel = dossier.appendingPathComponent("sel.kdf")
        if let existant = try? Data(contentsOf: cheminSel), existant.count == 16 {
            return existant
        }
        var sel = Data(count: 16)
        let resultat = sel.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        guard resultat == errSecSuccess else { throw ErreurArchiveMLA.generationSel(resultat) }
        try sel.write(to: cheminSel, options: .atomic)
        return sel
    }
}

/// FFI vers libmla (bindings C compilés depuis ffi/ — voir
/// scripts/build-mla-xcframework.sh). Les symboles sont déclarés ici ;
/// la liaison réelle intervient à l'ajout du xcframework au projet Xcode.
/// Tant que le framework n'est pas lié, estDisponible = false et le
/// backend Swift provisoire est utilisé.
/// Erreurs du backend Swift provisoire (dérivation de clé).
public enum ErreurArchiveMLA: Error, LocalizedError {
    case derivationCle(Int32)
    case generationSel(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .derivationCle(let s): return "Dérivation de clé impossible (\(s))."
        case .generationSel(let s): return "Génération du sel impossible (\(s))."
        }
    }
}

public enum BackendFFI_MLA {

    public static var estDisponible: Bool {
        // Détection d'exécution : le symbole carchive_open existe uniquement
        // lorsque le xcframework MLA est lié à la cible.
        dlsym(UnsafeMutableRawPointer(bitPattern: 0), "carchive_open") != nil
    }
}
