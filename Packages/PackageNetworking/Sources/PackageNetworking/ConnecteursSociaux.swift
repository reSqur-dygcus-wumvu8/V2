import Foundation
import PackageDomain

/// Connecteur X (Twitter) : flux RSS tiers (nitter) ou API officielle si un
/// token est disponible. Risque documenté : les instances non officielles
/// sont instables ; l'API officielle est payante au-delà des quotas.
public struct ConnecteurX: SocialFeedProvider {

    public var plateforme: PlateformeSociale { .xTwitter }

    /// Instance nitter utilisée (flux RSS tiers).
    public var instanceNitter: String

    public init(instanceNitter: String = "https://nitter.net") {
        self.instanceNitter = instanceNitter
    }

    public func recuperer(configuration: ConfigurationConnecteur) async throws -> [ElementVeille] {
        guard let url = URL(string: "\(instanceNitter)/\(configuration.identifiant)/rss") else {
            throw ErreurVeille.urlInvalide
        }
        let (donnees, _) = try await URLSession.shared.data(from: url)
        guard let xml = String(data: donnees, encoding: .utf8) else {
            throw ErreurVeille.fluxIllisible
        }
        let analyseur = AnalyseurRSS()
        let bruts = analyseur.analyser(xml: xml, veilleId: UUID(), hash: OrchestrateurVeille.hashSHA256)
        return bruts.map { brut in
            ElementVeille(
                veilleId: brut.veilleId,
                url: brut.url,
                titre: brut.titre,
                contenu: brut.contenu,
                datePublication: brut.datePublication,
                hashContenu: brut.hashContenu
            )
        }
    }
}

/// Connecteur Telegram : lecture de la page publique d'un canal
/// (t.me/s/<canal>, scraping HTML gratuit). Risque documenté : la mise en
/// page du service public peut changer ; aucune API payante requise.
public struct ConnecteurTelegram: SocialFeedProvider {

    public var plateforme: PlateformeSociale { .telegram }

    public init() {}

    public func recuperer(configuration: ConfigurationConnecteur) async throws -> [ElementVeille] {
        let canal = configuration.identifiant
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "https://t.me/", with: "")
            .replacingOccurrences(of: "@", with: "")
        guard !canal.isEmpty,
              let url = URL(string: "https://t.me/s/\(canal)") else {
            throw ErreurVeille.urlInvalide
        }
        let (donnees, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: donnees, encoding: .utf8) else {
            throw ErreurVeille.fluxIllisible
        }
        return Self.extraireMessages(html: html, canal: canal)
    }

    /// Extraction des messages du HTML de t.me/s/<canal> : chaque bloc
    /// contient une classe "tgme_widget_message_text" et un lien daté.
    static func extraireMessages(html: String, canal: String) -> [ElementVeille] {
        var elements: [ElementVeille] = []
        let blocs = html.components(separatedBy: "tgme_widget_message ")
        for bloc in blocs.dropFirst() {
            guard let texteBrut = Self.valeurClasse("tgme_widget_message_text", dans: bloc) else { continue }
            let texte = Self.nettoyer(texteBrut)
            guard !texte.isEmpty else { continue }
            let id = Self.valeurAttribut("data-post", dans: bloc) ?? "\(canal)-\(elements.count)"
            let lien = "https://t.me/\(id)"
            let date = Self.valeurAttribut("datetime", dans: bloc).flatMap(Self.parserDateISO)
            elements.append(
                ElementVeille(
                    veilleId: UUID(),
                    url: lien,
                    titre: String(texte.prefix(80)),
                    contenu: texte,
                    datePublication: date,
                    hashContenu: OrchestrateurVeille.hashSHA256(lien + texte)
                )
            )
        }
        return elements
    }

    /// Valeur textuelle d'un élément portant une classe donnée.
    static func valeurClasse(_ classe: String, dans bloc: String) -> String? {
        guard let debut = bloc.range(of: "class=\"\(classe)") else { return nil }
        let apres = bloc[debut.upperBound...]
        guard let ouverture = apres.range(of: ">") else { return nil }
        guard let fermeture = apres.range(of: "</div>", range: ouverture.upperBound..<apres.endIndex) else { return nil }
        return String(apres[ouverture.upperBound..<fermeture.lowerBound])
    }

    /// Valeur d'un attribut (data-post, datetime).
    static func valeurAttribut(_ attribut: String, dans bloc: String) -> String? {
        guard let debut = bloc.range(of: "\(attribut)=\"") else { return nil }
        let apres = bloc[debut.upperBound...]
        guard let fin = apres.range(of: "\"") else { return nil }
        return String(apres[..<fin.lowerBound])
    }

    /// Nettoyage HTML : balises et entités courantes.
    static func nettoyer(_ texte: String) -> String {
        texte
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parsing ISO8601 (attribut datetime).
    static func parserDateISO(_ texte: String) -> Date? {
        ISO8601DateFormatter().date(from: texte)
    }
}

/// Registre des connecteurs sociaux : toute nouvelle plateforme implémente
/// SocialFeedProvider et s'enregistre ici.
public enum RegistreConnecteurs {

    /// Connecteurs disponibles, par plateforme.
    public static func fournisseur(pour plateforme: PlateformeSociale) -> (any SocialFeedProvider)? {
        switch plateforme {
        case .xTwitter: return ConnecteurX()
        case .telegram: return ConnecteurTelegram()
        // Discord (bot/webhook) et TikTok (import manuel) : Étape suivante.
        case .discord, .tiktok: return nil
        }
    }
}
