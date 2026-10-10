import Foundation

/// État du client Tor embarqué.
public enum EtatTor: String, Sendable, Equatable {
    case arrete
    case demarrage
    case connecte
    case erreur
}

/// Configuration du client Arti embarqué.
public struct ConfigurationTor: Sendable, Equatable {
    /// Port du proxy SOCKS5 local (loopback uniquement).
    public var portSOCKS5: UInt16
    /// Ponts configurables (obfs4/meek) — lignes "obfs4 ip:port certificat".
    public var ponts: [String]
    /// Autoriser les nœuds de sortie français dans le circuit (facultatif).
    public var paysSortie: String?

    public init(portSOCKS5: UInt16 = 9050, ponts: [String] = [], paysSortie: String? = nil) {
        self.portSOCKS5 = portSOCKS5
        self.ponts = ponts
        self.paysSortie = paysSortie
    }
}

/// Client Tor Arti embarqué : démarre le runtime Rust via la FFI et expose
/// le proxy SOCKS5 sur 127.0.0.1. Tant que le xcframework n'est pas lié,
/// un état « erreur » documenté est rapporté (aucun fallback en clair :
/// l'application ne doit jamais sortir hors de Tor).
public final class ClientTor: @unchecked Sendable {

    public private(set) var configuration: ConfigurationTor
    private var etatInterne: EtatTor = .arrete

    public init(configuration: ConfigurationTor = ConfigurationTor()) {
        self.configuration = configuration
    }

    /// État courant du client.
    public var etat: EtatTor { etatInterne }

    /// Démarre le client Tor. Choix du moteur :
    /// - aucun pays de sortie : Arti (anonymat maximal, défaut) ;
    /// - pays de sortie configuré : tor C (ExitNodes {cc} + StrictNodes,
    ///   support mature de la restriction de sortie), via la FFI libtor.
    ///
    /// AVERTISSEMENT ANONYMAT : restreindre le pays de sortie réduit
    /// l'anonymat (ensemble de nœuds plus petit, corrélation facilitée) ;
    /// l'interface doit l'afficher explicitement à l'utilisateur.
    @discardableResult
    public func demarrer() async -> Bool {
        if let pays = configuration.paysSortie, !pays.isEmpty {
            // tor C avec restriction de sortie pays.
            guard BackendFFI_torC.estDisponible else {
                etatInterne = .erreur
                return false
            }
            etatInterne = .demarrage
            let code = torc_client_start(configuration.portSOCKS5, pays)
            etatInterne = code == 0 ? .connecte : .erreur
            return code == 0
        }
        guard BackendFFI_Arti.estDisponible else {
            etatInterne = .erreur
            return false
        }
        etatInterne = .demarrage
        let code = arti_client_start(configuration.portSOCKS5)
        etatInterne = code == 0 ? .connecte : .erreur
        return code == 0
    }

    /// Arrête le client Tor.
    public func arreter() {
        if BackendFFI_Arti.estDisponible {
            arti_client_stop()
        }
        etatInterne = .arrete
    }

    /// Fabrique la URLSession UNIQUE autorisée : proxy SOCKS5 loopback,
    /// résolution DNS via Tor (le proxy résout les noms).
    /// - Throws: TorIndisponible si le client n'est pas connecté.
    public func session() throws -> URLSession {
        guard etatInterne == .connecte else {
            throw ErreurTor.clientIndisponible
        }
        let configurationSession = URLSessionConfiguration.ephemeral
        configurationSession.connectionProxyDictionary = [
            kCFNetworkProxiesSOCKSProxy as String: "127.0.0.1",
            kCFNetworkProxiesSOCKSProxyPort as String: Int(configuration.portSOCKS5),
            // Résolution DNS via Tor : le système ne résout pas les noms.
            kCFNetworkProxiesSOCKSEnable as String: true,
        ]
        return URLSession(configuration: configurationSession)
    }
}

/// Erreurs du client Tor.
public enum ErreurTor: Error, LocalizedError {
    case clientIndisponible

    public var errorDescription: String? {
        switch self {
        case .clientIndisponible:
            return "Client Tor indisponible : aucune requête sortante n'est autorisée hors Tor."
        }
    }
}

/// FFI vers Arti (crate arti compilée en xcframework —
/// scripts/build-tor-xcframework.sh). Symboles déclarés ici, liés à
/// l'ajout du xcframework au projet Xcode.
public enum BackendFFI_Arti {

    public static var estDisponible: Bool {
        dlsym(UnsafeMutableRawPointer(bitPattern: 0), "arti_client_start") != nil
    }
}

// Liaisons C minimales (résolues au lien du xcframework).
@_silgen_name("arti_client_start")
func arti_client_start(_ port: UInt16) -> Int32
@_silgen_name("arti_client_stop")
func arti_client_stop()
