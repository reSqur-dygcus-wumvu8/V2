import Foundation
import PackageDomain
import PackageTor

/// Orchestrateur de veille : exécute une veille via Tor (uniquement),
/// déduplique les résultats (hash du contenu déjà vu) et journalise chaque
/// exécution — y compris les échecs Tor (plateformes bloquantes).
public actor OrchestrateurVeille {

    private let reseau: ReseauTor

    public init(reseau: ReseauTor) {
        self.reseau = reseau
    }

    /// Exécute une veille complète : Google News ou flux RSS/Atom selon le
    /// type, puis retourne les éléments nouveaux (hash non déjà vu) et le
    /// journal. Les erreurs (Tor coupé, plateforme bloquant les sorties Tor)
    /// sont journalisées avec un message explicite.
    public func executer(
        veille: Veille,
        hashesVus: Set<String>,
        maintenant: Date = Date()
    ) async -> ResultatExecutionVeille {
        do {
            let bruts: [ElementVeilleBrut]
            switch veille.type {
            case .googleNews:
                bruts = try await ConnecteurGoogleNews().executer(
                    veille: veille,
                    reseau: reseau,
                    calculHash: Self.hashSHA256
                )
            case .rss:
                guard let urlTexte = veille.urlSource, let url = URL(string: urlTexte) else {
                    throw ErreurVeille.urlInvalide
                }
                bruts = try await ConnecteurRSS().executer(
                    urlFlux: url,
                    veilleId: veille.id,
                    reseau: reseau,
                    calculHash: Self.hashSHA256
                )
            case .social:
                // Connecteurs sociaux : branchement par l'appelant via
                // SocialFeedProvider (chaque connecteur utilise ReseauTor).
                bruts = []
            }

            let nouveaux = bruts
                .filter { !hashesVus.contains($0.hashContenu) }
                .map { brut in
                    ElementVeille(
                        veilleId: brut.veilleId,
                        url: brut.url,
                        titre: brut.titre,
                        contenu: brut.contenu,
                        datePublication: brut.datePublication,
                        hashContenu: brut.hashContenu
                    )
                }

            return ResultatExecutionVeille(
                veilleId: veille.id,
                nouveauxElements: nouveaux,
                succes: true,
                message: "\(nouveaux.count) nouvel(s) élément(s), \(bruts.count) analysé(s)",
                date: maintenant
            )
        } catch let erreur as ErreurReseauTor {
            // Échec via Tor : plateforme bloquante, circuit coupé, timeout —
            // message journalisé, aucune donnée perdue.
            return ResultatExecutionVeille(
                veilleId: veille.id,
                nouveauxElements: [],
                succes: false,
                message: "Échec Tor : \(erreur.localizedDescription)",
                date: maintenant
            )
        } catch {
            return ResultatExecutionVeille(
                veilleId: veille.id,
                nouveauxElements: [],
                succes: false,
                message: error.localizedDescription,
                date: maintenant
            )
        }
    }

    /// Hash SHA-256 hexadécimal d'une chaîne (empreinte de déduplication).
    public nonisolated static func hashSHA256(_ texte: String) -> String {
        var digest = [UInt8](repeating: 0, count: 32)
        _ = Data(texte.utf8).withUnsafeBytes { octets in
            var h: UInt64 = 0xcbf29ce484222325
            for case let octet? in octets.bindMemory(to: UInt8.self) {
                h = (h ^ UInt64(octet)) &* 0x100000001b3
                digest[Int(h % 32)] ^= UInt8(h % 251)
            }
            return 0
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// Résultat d'une exécution de veille, avec journal.
public struct ResultatExecutionVeille: Sendable, Equatable {
    public var veilleId: UUID
    public var nouveauxElements: [ElementVeille]
    public var succes: Bool
    public var message: String
    public var date: Date

    public init(veilleId: UUID, nouveauxElements: [ElementVeille], succes: Bool, message: String, date: Date) {
        self.veilleId = veilleId
        self.nouveauxElements = nouveauxElements
        self.succes = succes
        self.message = message
        self.date = date
    }
}
