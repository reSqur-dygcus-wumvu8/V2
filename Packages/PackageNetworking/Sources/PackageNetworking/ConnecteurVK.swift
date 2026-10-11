import Foundation
import PackageDomain
import PackageTor

/// Connecteur VK (ВКонтакте) : lecture du mur d'un compte ou d'une
/// communauté via l'API officielle (méthode wall.get), au moyen d'un
/// token d'accès personnel créé dans les réglages VK. Requêtes via Tor.
/// Risque documenté : API soumise aux CGU VK, token personnel à durée
/// de vie limitée (renouvellement périodique) ; certaines méthodes
/// exigent une confirmation téléphonique russe.
public struct ConnecteurVK: SocialFeedProvider {

    public var plateforme: PlateformeSociale { .vk }

    /// Token d'accès personnel VK (conservé dans le Keychain côté app,
    /// jamais en dur).
    public var token: String

    /// Version de l'API VK.
    public var versionAPI: String
    private let reseau: ReseauTor

    public init(token: String, versionAPI: String = "5.199", reseau: ReseauTor) {
        self.token = token
        self.versionAPI = versionAPI
        self.reseau = reseau
    }

    public func recuperer(configuration: ConfigurationConnecteur) async throws -> [ElementVeille] {
        // L'identifiant peut être un nom de communauté (« durov ») ou un id
        // numérique préfixé (« -1 » pour un groupe).
        let cible = configuration.identifiant.trimmingCharacters(in: .whitespaces)
        guard !cible.isEmpty else { throw ErreurVeille.urlInvalide }

        struct ReponseVK: Codable {
            var response: Contenu?
            struct Contenu: Codable {
                var items: [Publication]?
                struct Publication: Codable {
                    var id: Int?
                    var date: Int?
                    var text: String?
                    var ownerID: Int?

                    enum CodingKeys: String, CodingKey {
                        case id, date, text
                        case ownerID = "owner_id"
                    }
                }
            }
        }

        var requete = URLRequest(url: URL(string: "https://api.vk.com/method/wall.get")!)
        requete.httpMethod = "POST"
        requete.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let proprietaire = cible.hasPrefix("-") ? cible : (Int(cible).map { "\($0)" } ?? cible)
        let corps = "owner_id=\(proprietaire)&count=20&access_token=\(token)&v=\(versionAPI)"
        requete.httpBody = Data(corps.utf8)
        let donnees = try await reseau.envoyer(requete)
        let reponse = try JSONDecoder().decode(ReponseVK.self, from: donnees)

        return (reponse.response?.items ?? []).compactMap { publication in
            let texte = (publication.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !texte.isEmpty, let id = publication.id else { return nil }
            let lien = "https://vk.com/wall\(publication.ownerID ?? 0)_\(id)"
            let date = publication.date.map { Date(timeIntervalSince1970: TimeInterval($0)) }
            return ElementVeille(
                veilleId: UUID(),
                url: lien,
                titre: String(texte.prefix(80)),
                contenu: texte,
                datePublication: date,
                hashContenu: OrchestrateurVeille.hashSHA256(lien + texte)
            )
        }
    }
}
