import Foundation
import AppIntents

/// Intent de déverrouillage : l'application principale demande une session
/// au Gestionnaire d'accès via App Intents (mécanisme standard inter-applications,
/// jamais de schéma d'URL pour les secrets). L'authentification biométrique et
/// l'écriture dans le trousseau partagé sont réalisées par la cible applicative
/// du Gestionnaire d'accès, qui configure le pont avec son CoffreCles.
@available(macOS 13.0, iOS 16.0, *)
public struct IntentDeverrouillage: AppIntent {
    public static let title: LocalizedStringResource = "Déverrouiller la base OSINT"
    public static let description = IntentDescription(
        "Authentifie l'utilisateur et délivre une clé de session à durée limitée à OSINT Suite."
    )

    @Parameter(title: "Appareil demandeur")
    public var appareil: String

    public init() {}

    public init(appareil: String) {
        self.appareil = appareil
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let coffret = await PontDeverrouillage.partage.coffret,
              let session = await coffret.delivrerSession(appareil: appareil) else {
            return .result(value: "REFUSE")
        }
        await PontDeverrouillage.partage.publierSession(session)
        return .result(value: "OK")
    }
}

/// Pont entre l'App Intent et le coffret de clés : la cible applicative du
/// Gestionnaire d'accès configure ce singleton à son lancement (KEK Secure
/// Enclave en production), et observe les sessions publiées pour les écrire
/// dans le groupe de trousseau partagé (seul élément transitoire partagé).
@MainActor
public final class PontDeverrouillage: @unchecked Sendable {
    public static let partage = PontDeverrouillage()

    public var coffret: CoffreCles?
    public private(set) var sessionPubliee: CleSession?
    public var observateurSession: ((CleSession) -> Void)?

    private init() {}

    public func publierSession(_ session: CleSession) {
        sessionPubliee = session
        observateurSession?(session)
    }

    /// Purge la session au passage en arrière-plan (l'app compagnon l'appelle
    /// depuis scenePhase).
    public func purgerSession() {
        sessionPubliee = nil
    }
}
