import Foundation
import CryptoKit

/// Profil d'accès d'un appareil autorisé.
public enum ProfilAcces: String, Codable, Sendable {
    case lectureSeule
    case complet

    public var libelle: String {
        switch self {
        case .lectureSeule: return "Lecture seule"
        case .complet: return "Complet"
        }
    }
}

/// Appareil habilité à demander des sessions de déverrouillage.
public struct AppareilAutorise: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var nom: String
    public var profil: ProfilAcces
    public var plageHoraireDebut: Int?
    public var plageHoraireFin: Int?
    public var actif: Bool

    public init(
        id: UUID = UUID(),
        nom: String,
        profil: ProfilAcces = .complet,
        plageHoraireDebut: Int? = nil,
        plageHoraireFin: Int? = nil,
        actif: Bool = true
    ) {
        self.id = id
        self.nom = nom
        self.profil = profil
        self.plageHoraireDebut = plageHoraireDebut
        self.plageHoraireFin = plageHoraireFin
        self.actif = actif
    }

    /// L'accès est-il autorisé à cette heure (plage horaire éventuelle) ?
    public func accesAutorise(maintenant: Date = Date()) -> Bool {
        guard actif else { return false }
        guard let debut = plageHoraireDebut, let fin = plageHoraireFin else { return true }
        let heure = Calendar.current.component(.hour, from: maintenant)
        if debut <= fin {
            return (debut...fin).contains(heure)
        }
        // Plage à cheval sur minuit.
        return heure >= debut || heure <= fin
    }
}

/// Entrée du journal d'audit : chaque déverrouillage est consigné localement.
public struct EntreeAudit: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var date: Date
    public var appareil: String
    public var action: String
    public var succes: Bool

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        appareil: String,
        action: String,
        succes: Bool
    ) {
        self.id = id
        self.date = date
        self.appareil = appareil
        self.action = action
        self.succes = succes
    }
}

/// Coffret de clés du Gestionnaire d'accès : détient la KEK (abstraite ici
/// via un fournisseur de KEK — Secure Enclave en production, mock en tests),
/// enveloppe/déballe la DEK et délivre les clés de session selon les
/// politiques. Fonctionne entièrement hors ligne.
public actor CoffreCles {

    private var kek: SymmetricKey
    private var enveloppeDEK: EnveloppeDEK?
    private var appareils: [AppareilAutorise] = []
    private var journal: [EntreeAudit] = []
    private var phraseSecoursUtilisee = false

    /// Durée de session par défaut : 1 heure.
    public static let dureeSessionDefaut: TimeInterval = 3600

    public init(kek: SymmetricKey) {
        self.kek = kek
    }

    /// Initialise le coffret avec une DEK (première utilisation) :
    /// génère la DEK, l'enveloppe avec la KEK et retourne la DEK en clair
    /// pour que l'application principale chiffre sa base.
    public func initialiser() -> SymmetricKey {
        let dek = ModeleCles.genererDEK()
        enveloppeDEK = try? ModeleCles.envelopper(dek: dek, kek: kek)
        return dek
    }

    /// Enregistre une enveloppe DEK existante (restauration).
    public func restaurer(enveloppe: EnveloppeDEK) {
        self.enveloppeDEK = enveloppe
    }

    /// L'enveloppe DEK (stockable dans le trousseau partagé).
    public func enveloppe() -> EnveloppeDEK? {
        enveloppeDEK
    }

    /// Délivre une clé de session à durée limitée si l'appareil est autorisé
    /// et que la plage horaire le permet. C'est la seule valeur partagée.
    public func delivrerSession(
        appareil: String,
        duree: TimeInterval = CoffreCles.dureeSessionDefaut,
        maintenant: Date = Date()
    ) -> CleSession? {
        guard let habilitation = appareils.first(where: { $0.nom == appareil }),
              habilitation.accesAutorise(maintenant: maintenant),
              enveloppeDEK != nil else {
            consigner(appareil: appareil, action: "déverrouillage refusé", succes: false, date: maintenant)
            return nil
        }
        let session = ModeleCles.cleSession(kek: kek, expiration: maintenant.addingTimeInterval(duree))
        consigner(appareil: appareil, action: "déverrouillage (\(habilitation.profil.libelle))", succes: true, date: maintenant)
        return session
    }

    /// Déballe la DEK avec la clé de session délivrée (côté app principale).
    public func deballerDEK(session: CleSession, maintenant: Date = Date()) throws -> SymmetricKey {
        guard session.estValide(maintenant: maintenant), let enveloppe = enveloppeDEK else {
            throw ErreurCoffre.sessionExpiree
        }
        return try ModeleCles.deballer(enveloppe: enveloppe, kek: session.cle)
    }

    /// Ajoute un appareil autorisé.
    public func autoriser(_ appareil: AppareilAutorise) {
        appareils.append(appareil)
        consigner(appareil: appareil.nom, action: "appareil autorisé", succes: true)
    }

    /// Révoque un appareil (il ne pourra plus obtenir de session).
    public func revoquer(id: UUID) {
        if let index = appareils.firstIndex(where: { $0.id == id }) {
            appareils[index].actif = false
            consigner(appareil: appareils[index].nom, action: "appareil révoqué", succes: true)
        }
    }

    /// Liste des appareils.
    public func appareilsAutorises() -> [AppareilAutorise] {
        appareils
    }

    /// Rotation de la KEK : la DEK est déballée puis ré-enveloppée avec la
    /// nouvelle KEK ; l'ancienne KEK devient inutilisable.
    public func rotationKEK(nouvelleKEK: SymmetricKey) throws {
        guard let enveloppe = enveloppeDEK else {
            throw ErreurCoffre.pasDeDEK
        }
        let dek = try ModeleCles.deballer(enveloppe: enveloppe, kek: kek)
        self.kek = nouvelleKEK
        self.enveloppeDEK = try ModeleCles.envelopper(dek: dek, kek: nouvelleKEK)
        consigner(appareil: "local", action: "rotation KEK", succes: true)
    }

    /// Rotation de la DEK : nouvelle DEK générée et ré-enveloppée ; la base
    /// doit être ré-encryptée par l'app appelante avec la nouvelle DEK.
    public func rotationDEK() throws -> SymmetricKey {
        guard enveloppeDEK != nil else {
            throw ErreurCoffre.pasDeDEK
        }
        let dek = ModeleCles.genererDEK()
        enveloppeDEK = try ModeleCles.envelopper(dek: dek, kek: kek)
        consigner(appareil: "local", action: "rotation DEK", succes: true)
        return dek
    }

    /// Révocation / panic wipe : la KEK est écrasée, l'enveloppe détruite.
    /// La base devient définitivement illisible sur tous les appareils.
    public func panique() {
        kek = SymmetricKey(size: ModeleCles.tailleCle)
        enveloppeDEK = nil
        consigner(appareil: "local", action: "PANIC WIPE — KEK révoquée", succes: true)
    }

    /// Génère la phrase de récupération (une seule fois) et conserve la
    /// KEK de secours dérivée, utilisable uniquement via restauration.
    public func genererPhraseRecuperation() -> [String]? {
        guard !phraseSecoursUtilisee else { return nil }
        phraseSecoursUtilisee = true
        return ModeleCles.phraseRecuperation()
    }

    /// Restaure l'accès depuis la phrase de récupération (nouvel appareil).
    public func restaurerDepuisPhrase(_ mots: [String]) -> Bool {
        guard let kekSecours = ModeleCles.kekDepuisPhrase(mots) else { return false }
        kek = kekSecours
        consigner(appareil: "local", action: "restauration depuis phrase", succes: true)
        return true
    }

    /// Journal d'audit complet.
    public func journalAudit() -> [EntreeAudit] {
        journal
    }

    /// Export du journal d'audit (JSON).
    public func exporterAudit() -> Data? {
        let entrees = journal.sorted { $0.date < $1.date }
        return try? JSONEncoder().encode(entrees)
    }

    private func consigner(appareil: String, action: String, succes: Bool, date: Date = Date()) {
        journal.append(EntreeAudit(date: date, appareil: appareil, action: action, succes: succes))
    }
}

/// Erreurs du coffret de clés.
public enum ErreurCoffre: Error, LocalizedError {
    case sessionExpiree
    case pasDeDEK

    public var errorDescription: String? {
        switch self {
        case .sessionExpiree: return "Session expirée ou invalide."
        case .pasDeDEK: return "Aucune DEK à manipuler (coffret non initialisé)."
        }
    }
}
