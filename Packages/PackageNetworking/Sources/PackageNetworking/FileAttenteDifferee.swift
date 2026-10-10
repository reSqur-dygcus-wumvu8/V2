import Foundation
import PackageDomain
import PackageTor

/// File d'attente persistante des tâches réseau différées.
/// En mode avion ou circuit Tor coupé, les tâches sont mises en file et
/// rejouées dès que le client Tor retrouve un circuit fonctionnel.
public actor FileAttenteDifferee {

    private var taches: [TacheDifferee] = []
    private var torPret = false

    public init() {}

    /// Ajoute une tâche à la file.
    public func ajouter(_ tache: TacheDifferee) {
        taches.append(tache)
    }

    /// Signale l'état du circuit Tor (appelé au retour de connexion).
    public func circuitTorDisponible(_ pret: Bool) {
        torPret = pret
    }

    /// Tor est-il prêt à exécuter des requêtes ?
    public var estPret: Bool { torPret }

    /// Retourne et retire les tâches prêtes (uniquement si Tor est prêt).
    public func decharger() -> [TacheDifferee] {
        guard torPret else { return [] }
        let aExecuter = taches
        taches.removeAll()
        return aExecuter
    }

    /// Nombre de tâches en attente.
    public var nombreEnAttente: Int { taches.count }
}

/// Tâche différée : téléchargement, appel proxy, exécution de veille.
public struct TacheDifferee: Codable, Sendable, Equatable, Identifiable {
    public enum Genre: String, Codable, Sendable {
        case telechargement
        case appelProxy
        case executionVeille
    }

    public var id: UUID
    public var genre: Genre
    public var url: String
    public var dateCreation: Date

    public init(id: UUID = UUID(), genre: Genre, url: String, dateCreation: Date = Date()) {
        self.id = id
        self.genre = genre
        self.url = url
        self.dateCreation = dateCreation
    }
}
