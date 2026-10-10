import Foundation

/// Façade réseau unique de l'application : tout téléchargement passe par
/// le client Tor embarqué. En cas d'échec (plateforme bloquant les sorties
/// Tor, circuit indisponible), l'erreur est explicite et journalisable —
/// jamais de repli hors Tor.
public actor ReseauTor {

    private let client: ClientTor
    private var session: URLSession?

    public init(client: ClientTor) {
        self.client = client
    }

    /// Prépare la session (après démarrage réussi du client Tor).
    public func preparer() async throws {
        guard await client.demarrer() else {
            throw ErreurTor.clientIndisponible
        }
        session = try client.session()
    }

    /// Télécharge le contenu d'une URL via Tor (DNS résolu par le proxy).
    /// - Throws: ErreurReseauTor si Tor est indisponible ou si le
    ///   téléchargement échoue (plateforme bloquante, timeout).
    public func telecharger(_ url: URL) async throws -> Data {
        guard let session else {
            throw ErreurReseauTor.torIndisponible
        }
        do {
            let (donnees, reponse) = try await session.data(from: url)
            guard let http = reponse as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw ErreurReseauTor.statutInattendu
            }
            return donnees
        } catch let erreur as ErreurReseauTor {
            throw erreur
        } catch {
            // Échec réseau via Tor : plateforme bloquant les sorties Tor,
            // circuit coupé, timeout — remonté tel quel à la couche veille
            // pour journalisation.
            throw ErreurReseauTor.echecTor(underlying: error)
        }
    }

    /// Envoie une requête via Tor.
    public func envoyer(_ requete: URLRequest) async throws -> Data {
        guard let session else {
            throw ErreurReseauTor.torIndisponible
        }
        do {
            let (donnees, reponse) = try await session.data(for: requete)
            guard let http = reponse as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw ErreurReseauTor.statutInattendu
            }
            return donnees
        } catch let erreur as ErreurReseauTor {
            throw erreur
        } catch {
            throw ErreurReseauTor.echecTor(underlying: error)
        }
    }
}

/// Erreurs de la façade réseau Tor : toujours explicites pour la journal.
public enum ErreurReseauTor: Error, LocalizedError {
    case torIndisponible
    case statutInattendu
    case echecTor(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .torIndisponible:
            return "Tor indisponible : requête refusée (aucun fallback hors Tor)."
        case .statutInattendu:
            return "Statut HTTP inattendu via Tor."
        case .echecTor(let cause):
            return "Échec via Tor (plateforme bloquante ou circuit coupé) : \(cause.localizedDescription)"
        }
    }
}
