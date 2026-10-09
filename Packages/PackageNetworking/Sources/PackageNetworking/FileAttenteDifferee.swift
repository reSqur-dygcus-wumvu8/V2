import Foundation
import PackageDomain

/// File d'attente persistante des tâches réseau différées.
/// En mode avion, les tâches sont mises en file et rejouées au retour
/// de la connexion (NWPathMonitor côté app).
public actor FileAttenteDifferee {

    private var taches: [TacheDifferee] = []
    private let continu: Bool

    public init(continu: Bool = false) {
        self.continu = continu
    }

    /// Ajoute une tâche à la file.
    public func ajouter(_ tache: TacheDifferee) {
        taches.append(tache)
    }

    /// Retourne et retire les tâches prêtes à être exécutées (toutes,
    /// la décision de connexion relevant de l'appelant).
    public func decharger() -> [TacheDifferee] {
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
