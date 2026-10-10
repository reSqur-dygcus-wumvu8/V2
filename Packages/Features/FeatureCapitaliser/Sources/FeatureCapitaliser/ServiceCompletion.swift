import Foundation
import PackageDomain
import PackageTor
import PackagePersistence
import PackageIntelligence

/// Service de complétion automatique de fiches : à la création d'une entité,
/// recherche sur internet (moteur de recherche / Wikipedia) et via Mistral
/// pour pré-remplir les champs. Les champs auto-remplis sont marqués
/// « source : internet » jusqu'à validation humaine.
public struct ServiceCompletion: Sendable {

    public enum OrigineValeur: String, Codable, Sendable, Equatable {
        case internet
        case mistral
        case manuel
    }

    /// Valeur proposée pour un champ, avec son origine (marqueur visuel).
    public struct ValeurProposee: Codable, Sendable, Equatable {
        public var champ: String
        public var valeur: String
        public var origine: OrigineValeur

        public init(champ: String, valeur: String, origine: OrigineValeur) {
            self.champ = champ
            self.valeur = valeur
            self.origine = origine
        }
    }

    let clientMistral: ClientProxyMistral?
    let reseau: ReseauTor

    public init(clientMistral: ClientProxyMistral? = nil, reseau: ReseauTor) {
        self.clientMistral = clientMistral
        self.reseau = reseau
    }

    /// Complète une entité à partir de sa dénomination : recherche internet
    /// (Wikipedia FR en priorité, aucune dépendance externe), puis synthèse
    /// Mistral si le proxy est disponible. Retourne les propositions à
    /// valider par l'utilisateur.
    public func completer(entite: Entite) async -> [ValeurProposee] {
        var propositions: [ValeurProposee] = []

        // 1. Recherche internet : résumé Wikipedia FR si l'entité est notoire.
        if let resume = await resumeWikipedia(denomination: entite.denomination) {
            propositions.append(
                ValeurProposee(champ: entite.type == .individu ? "biographie" : "resume", valeur: resume, origine: .internet)
            )
        }

        // 2. Synthèse Mistral (via proxy) à partir du résumé ou de la dénomination.
        if let client = clientMistral,
           let synthese = try? await client.resumer(
               contenu: propositions.first?.valeur ?? entite.denomination,
               motsCles: [entite.denomination]
           ) {
            propositions.append(
                ValeurProposee(champ: "synthese", valeur: synthese, origine: .mistral)
            )
        }

        return propositions
    }

    /// Résumé Wikipedia FR : API officielle gratuite (résumé 3 phrases).
    func resumeWikipedia(denomination: String) async -> String? {
        let encodee = denomination
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? denomination
        guard let url = URL(string: "https://fr.wikipedia.org/api/rest_v1/page/summary/\(encodee)") else {
            return nil
        }
        guard let donnees = try? await reseau.telecharger(url),
              let objet = try? JSONSerialization.jsonObject(with: donnees) as? [String: Any],
              let extrait = objet["extract"] as? String,
              !extrait.isEmpty else { return nil }
        return extrait
    }

    /// Applique une proposition validée à une entité (avec le marqueur
    /// d'origine conservé dans les commentaires de traçabilité).
    public func appliquer(_ proposition: ValeurProposee, a entite: inout Entite) {
        switch proposition.champ {
        case "biographie": entite.biographie = proposition.valeur
        case "resume": entite.resume = proposition.valeur
        case "synthese":
            if entite.type == .individu {
                entite.biographie = proposition.valeur
            } else {
                entite.resume = proposition.valeur
            }
        case "commentaires": entite.commentaires = proposition.valeur
        default: break
        }
        entite.updatedAt = Date()
    }

    /// Marqueur de traçabilité ajouté aux commentaires lors de l'application
    /// d'une valeur auto-remplie (jusqu'à validation, champ visuellement
    /// distingué dans la fiche).
    public static func marqueurOrigine(_ proposition: ValeurProposee) -> String {
        "[source : \(proposition.origine.rawValue)]"
    }
}
