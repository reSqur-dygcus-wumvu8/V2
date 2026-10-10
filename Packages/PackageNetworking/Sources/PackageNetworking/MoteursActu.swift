import Foundation
import PackageDomain
import PackageTor

/// Protocole commun des moteurs d'actualités (aux côtés de
/// SocialFeedProvider) : toute nouvelle source d'actualités l'implémente.
public protocol MoteurActuProvider: Sendable {
    /// Moteur géré par ce connecteur.
    var moteur: MoteurActu { get }
    /// Exécute une recherche d'actualités pour des mots-clés et une langue,
    /// via Tor exclusivement.
    func rechercher(motsCles: [String], langue: String, reseau: ReseauTor) async throws -> [ElementVeilleBrut]
}

/// Connecteur Google Actualités : flux RSS de recherche, paramètres
/// hl/gl par langue.
public struct ConnecteurGoogleActu: MoteurActuProvider {

    public var moteur: MoteurActu { .google }

    public init() {}

    public func rechercher(motsCles: [String], langue: String, reseau: ReseauTor) async throws -> [ElementVeilleBrut] {
        guard !motsCles.isEmpty else { return [] }
        let requete = motsCles.joined(separator: " ")
        let encodee = requete.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? requete
        let pays = Self.paysPourLangue(langue)
        guard let url = URL(string: "https://news.google.com/rss/search?q=\(encodee)&hl=\(langue)&gl=\(pays)&ceid=\(pays):\(langue)") else {
            return []
        }
        let donnees = try await reseau.telecharger(url)
        guard let xml = String(data: donnees, encoding: .utf8) else {
            throw ErreurVeille.fluxIllisible
        }
        return AnalyseurRSS().analyser(xml: xml, veilleId: UUID(), hash: OrchestrateurVeille.hashSHA256)
    }

    /// Code pays usuel associé à une langue (hl/gl du flux Google).
    static func paysPourLangue(_ langue: String) -> String {
        switch langue {
        case "fr": return "FR"
        case "en": return "US"
        case "de": return "DE"
        case "es": return "ES"
        case "it": return "IT"
        case "ru": return "RU"
        default: return langue.uppercased()
        }
    }
}

/// Connecteur Qwant Actualités : API publique JSON v3. Risque documenté :
/// API non contractuelle — une évolution de Qwant peut la rompre ; les
/// échecs sont journalisés par l'orchestrateur.
public struct ConnecteurQwantActu: MoteurActuProvider {

    public var moteur: MoteurActu { .qwant }

    public init() {}

    public func rechercher(motsCles: [String], langue: String, reseau: ReseauTor) async throws -> [ElementVeilleBrut] {
        guard !motsCles.isEmpty else { return [] }
        let requete = motsCles.joined(separator: " ")
        let encodee = requete.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? requete
        let pays = ConnecteurGoogleActu.paysPourLangue(langue).lowercased()
        guard let url = URL(string: "https://api.qwant.com/v3/search/news?q=\(encodee)&locale=\(langue)_\(pays)&count=10") else {
            return []
        }
        var requeteHTTP = URLRequest(url: url)
        requeteHTTP.setValue("Mozilla/5.0 (Macintosh)", forHTTPHeaderField: "User-Agent")
        let donnees = try await reseau.envoyer(requeteHTTP)
        struct ReponseQwant: Codable {
            var data: Donnees?
            struct Donnees: Codable {
                var result: Resultat?
                struct Resultat: Codable {
                    var items: [Item]?
                    struct Item: Codable {
                        var title: String?
                        var url: String?
                        var desc: String?
                        var date: String?
                    }
                }
            }
        }
        let reponse = try JSONDecoder().decode(ReponseQwant.self, from: donnees)
        return (reponse.data?.result?.items ?? []).map { item in
            ElementVeilleBrut(
                veilleId: UUID(),
                url: item.url ?? "",
                titre: item.title ?? "Sans titre",
                contenu: item.desc ?? "",
                datePublication: ConnecteurQwantActu.parserDate(item.date),
                hashContenu: OrchestrateurVeille.hashSHA256((item.url ?? "") + (item.desc ?? item.title ?? ""))
            )
        }
    }

    static func parserDate(_ texte: String?) -> Date? {
        guard let texte else { return nil }
        let formats = ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss.SSSZ"]
        let decodeur = DateFormatter()
        decodeur.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            decodeur.dateFormat = format
            if let date = decodeur.date(from: texte) { return date }
        }
        return ISO8601DateFormatter().date(from: texte)
    }
}

/// Connecteur Yandex Actualités : flux RSS de recherche, paramètre lr
/// (région/langue). Risque documenté : disponibilité variable selon le
/// pays de sortie Tor — c'est précisément le cas d'usage du pays de
/// sortie privilégié par veille (tor C).
public struct ConnecteurYandexActu: MoteurActuProvider {

    public var moteur: MoteurActu { .yandex }

    public init() {}

    public func rechercher(motsCles: [String], langue: String, reseau: ReseauTor) async throws -> [ElementVeilleBrut] {
        guard !motsCles.isEmpty else { return [] }
        let requete = motsCles.joined(separator: " ")
        let encodee = requete.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? requete
        // lr : code région Yandex (ex. 225 = France, 1 = Russie).
        let region = Self.regionPourLangue(langue)
        guard let url = URL(string: "https://news.yandex.ru/yandsearch?text=\(encodee)&lr=\(region)&rss=1") else {
            return []
        }
        let donnees = try await reseau.telecharger(url)
        guard let xml = String(data: donnees, encoding: .utf8) else {
            throw ErreurVeille.fluxIllisible
        }
        return AnalyseurRSS().analyser(xml: xml, veilleId: UUID(), hash: OrchestrateurVeille.hashSHA256)
    }

    /// Région Yandex usuelle par langue.
    static func regionPourLangue(_ langue: String) -> Int {
        switch langue {
        case "fr": return 225
        case "ru": return 1
        case "en": return 65
        case "de": return 149
        case "es": return 249
        default: return 225
        }
    }
}

/// Registre des moteurs d'actualités.
public enum RegistreMoteursActu {

    /// Connecteur d'un moteur donné.
    public static func fournisseur(pour moteur: MoteurActu) -> any MoteurActuProvider {
        switch moteur {
        case .google: return ConnecteurGoogleActu()
        case .qwant: return ConnecteurQwantActu()
        case .yandex: return ConnecteurYandexActu()
        }
    }
}
