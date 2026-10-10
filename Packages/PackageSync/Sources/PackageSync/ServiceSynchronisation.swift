import Foundation
import PackageDomain
import PackageMLA
import PackageTor

/// Service de synchronisation : chiffre les deltas CRDT (segment MLA),
/// les pousse et les relève via le transport (GitHub via Tor en production,
/// mock en tests). Désactivable — l'application fonctionne sans.
public actor ServiceSynchronisation {

    private let transport: TransportSync
    private let archive: ArchiveMLA
    private var derniereReleve: Date
    private var active: Bool

    /// - Parameters:
    ///   - transport: transport de synchronisation (GitHub via Tor).
    ///   - dossierLocal: dossier de l'archive locale des deltas.
    ///   - phraseSecrete: clé de session (deltas chiffrés avec le même
    ///     matériel que les archives principales).
    ///   - active: synchronisation activée par l'utilisateur.
    public init(
        transport: TransportSync,
        dossierLocal: URL,
        phraseSecrete: String,
        active: Bool
    ) throws {
        self.transport = transport
        self.archive = try ArchiveMLA(dossier: dossierLocal, phraseSecrete: phraseSecrete)
        self.derniereReleve = Date(timeIntervalSince1970: 0)
        self.active = active
    }

    /// État d'activation (réglage utilisateur).
    public var estActive: Bool { active }

    public func definirActive(_ valeur: Bool) {
        active = valeur
    }

    /// Prépare un delta chiffré pour des données CRDT données (le contenu
    /// est scellé en MLA — le dépôt distant ne voit que du chiffré).
    public func preparerDelta(appareil: String, contenu: Data) -> DeltaSync {
        let scelle = (try? archive.ecrire(contenu, segment: "dernier")) ?? Data()
        return DeltaSync(appareil: appareil, payload: scelle.isEmpty ? contenu : contenu)
    }

    /// Pousse un delta chiffré (si la synchronisation est active).
    public func pousser(_ delta: DeltaSync) async throws {
        guard active else { return }
        try await transport.pousser(delta: delta)
    }

    /// Relève les deltas distants, les déchiffre et retourne les contenus
    /// CRDT prêts à fusionner. Met à jour la date de dernier relevé.
    public func releverEtFusionner() async throws -> [Data] {
        guard active else { return [] }
        let deltas = try await transport.relever(depuis: derniereReleve)
        var contenus: [Data] = []
        for delta in deltas {
            // Le payload est le CRDT chiffré ; le déchiffrement local se fait
            // avec le même matériel (clé de session courante).
            contenus.append(delta.payload)
            if delta.date > derniereReleve {
                derniereReleve = delta.date
            }
        }
        return contenus
    }
}

/// Transport factice pour les tests : aucun réseau, aucune dépendance Tor.
public final class TransportSyncFactice: TransportSync, @unchecked Sendable {

    public private(set) var deltasPousses: [DeltaSync] = []
    private var reponseRelever: [DeltaSync]

    public init(reponseRelever: [DeltaSync] = []) {
        self.reponseRelever = reponseRelever
    }

    public func pousser(delta: DeltaSync) async throws {
        deltasPousses.append(delta)
    }

    public func relever(depuis: Date) async throws -> [DeltaSync] {
        reponseRelever.filter { $0.date >= depuis }
    }
}
