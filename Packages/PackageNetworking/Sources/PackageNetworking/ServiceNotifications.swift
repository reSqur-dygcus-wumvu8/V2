import Foundation
import UserNotifications
import PackageDomain

/// Service d'alertes : à chaque nouveau résultat de veille, calcul du score
/// de priorité (cotation source + mots-clés de priorité) et notification
/// locale si le seuil est atteint. Le permission est demandée à la première
/// utilisation ; l'envoi est testable via un injectable.
public struct ServiceAlertes: Sendable {

    /// Seuil de score déclenchant une alerte (0–100).
    public var seuilAlerte: Int

    /// Injecteur de notification (test sans interface système).
    private let envoyeur: @Sendable (String, String) async -> Bool

    public init(
        seuilAlerte: Int = 70,
        envoyeur: (@Sendable (String, String) async -> Bool)? = nil
    ) {
        self.seuilAlerte = seuilAlerte
        self.envoyeur = envoyeur ?? { titre, corps in
            let centre = UNUserNotificationCenter.current()
            let contenu = UNMutableNotificationContent()
            contenu.title = titre
            contenu.body = corps
            let requete = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: contenu,
                trigger: nil
            )
            return (try? await centre.add(requete)) != nil
        }
    }

    /// Demande la permission de notification (une fois, à l'activation).
    public static func demanderPermission() async -> Bool {
        let centre = UNUserNotificationCenter.current()
        return (try? await centre.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Évalue les nouveaux éléments d'une veille et notifie ceux dont le
    /// score de priorité atteint le seuil. Retourne les éléments alertés.
    @discardableResult
    public func evaluer(
        elements: [ElementVeille],
        veille: Veille
    ) async -> [ElementVeille] {
        let alertes = elements.filter { element in
            let score = ReglesMetier.scorePriorite(element: element, veille: veille)
            return ReglesMetier.doitAlerter(score: score, seuil: seuilAlerte)
        }
        for element in alertes.prefix(3) {
            _ = await envoyeur(
                "Alerte — \(veille.titre)",
                element.titre
            )
        }
        return alertes
    }
}
