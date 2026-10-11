import Foundation
import PackageDomain
import PackageTor

/// Pont concret du mode découverte : appelle le proxy Mistral
/// (POST /decouvrir) via Tor et décode la synthèse structurée
/// (sources cotées + sources d'intérêt). La clé API vit côté proxy.
public struct ClientDecouverteProxy: ClientDecouverteBridge {

    private let urlBase: URL
    private let token: String
    private let reseau: ReseauTor

    public init(urlBase: URL, token: String, reseau: ReseauTor) {
        self.urlBase = urlBase
        self.token = token
        self.reseau = reseau
    }

    public func decouvrir(thematique: String) async -> ServiceDecouverte.ResultatDecouverte? {
        var requete = URLRequest(url: urlBase.appendingPathComponent("decouvrir"))
        requete.httpMethod = "POST"
        requete.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        requete.setValue("application/json", forHTTPHeaderField: "Content-Type")
        requete.timeoutInterval = 300
        let corps: [String: String] = ["thematique": thematique]
        requete.httpBody = try? JSONSerialization.data(withJSONObject: corps)

        // La réponse du proxy est la synthèse finale structurée en JSON.
        guard let donnees = try? await reseau.envoyer(requete),
              let objet = try? JSONSerialization.jsonObject(with: donnees) as? [String: Any],
              let synthese = objet["synthese"] as? String else {
            return nil
        }

        let sources = Self.decoderSources(objet["sources"])
        let sourcesInteret = Self.decoderSourcesInteret(objet["sourcesInteret"])
        return ServiceDecouverte.ResultatDecouverte(
            thematique: thematique,
            synthese: synthese,
            sources: sources,
            sourcesInteret: sourcesInteret
        )
    }

    /// Décode les sources citées : {url, titre, cotation A–F}.
    private static func decoderSources(_ brut: Any?) -> [ServiceDecouverte.SourceDecouverte] {
        guard let liste = brut as? [[String: Any]] else { return [] }
        return liste.compactMap { entree in
            guard let url = entree["url"] as? String else { return nil }
            return ServiceDecouverte.SourceDecouverte(
                url: url,
                titre: (entree["titre"] as? String) ?? url,
                cotationProposee: (entree["cotation"] as? String).flatMap(FiabiliteSource.init(rawValue:))
            )
        }
    }

    /// Décode les sources d'intérêt : {genre, url, libelle, typeVeille, motsCles}.
    private static func decoderSourcesInteret(_ brut: Any?) -> [ServiceDecouverte.SourceInteret] {
        guard let liste = brut as? [[String: Any]] else { return [] }
        return liste.compactMap { entree in
            guard let url = entree["url"] as? String,
                  let libelle = entree["libelle"] as? String else { return nil }
            let genre = ServiceDecouverte.SourceInteret.Genre(rawValue: entree["genre"] as? String ?? "site") ?? .site
            let typeVeille = TypeVeille(rawValue: entree["typeVeille"] as? String ?? "rss") ?? .rss
            let motsCles = (entree["motsCles"] as? [String]) ?? []
            return ServiceDecouverte.SourceInteret(
                genre: genre,
                url: url,
                libelle: libelle,
                typeVeilleSuggere: typeVeille,
                motsClesSuggeres: motsCles
            )
        }
    }
}
