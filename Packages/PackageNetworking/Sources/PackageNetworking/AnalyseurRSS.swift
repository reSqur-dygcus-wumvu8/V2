import Foundation

/// Analyse de flux RSS 2.0 et Atom (XML) sans dépendance externe.
public struct AnalyseurRSS: Sendable {

    public init() {}

    /// Analyse le contenu XML d'un flux RSS/Atom et retourne les éléments.
    public func analyser(xml: String, veilleId: UUID, hash: (String) -> String) -> [ElementVeilleBrut] {
        let articles = Self.extraire(xml: xml)
        return articles.map { article in
            ElementVeilleBrut(
                veilleId: veilleId,
                url: article.lien,
                titre: article.titre,
                contenu: article.description ?? "",
                datePublication: article.date,
                hashContenu: hash(article.lien + (article.description ?? article.titre))
            )
        }
    }

    /// Extraction simple par balises : items RSS (item) et entrées Atom (entry).
    static func extraire(xml: String) -> [ArticleBrut] {
        var articles: [ArticleBrut] = []
        let blocs = Self.blocs(nomBalise: "item", xml: xml) + Self.blocs(nomBalise: "entry", xml: xml)
        for bloc in blocs {
            let titre = Self.valeur(balises: ["title"], dans: bloc) ?? "Sans titre"
            let lien = Self.valeur(balises: ["link", "link href"], dans: bloc)
                ?? Self.lienAtom(dans: bloc)
                ?? ""
            let description = Self.valeur(balises: ["description", "summary", "content"], dans: bloc)
            let date = Self.valeur(balises: ["pubDate", "published", "updated"], dans: bloc)
                .flatMap(Self.parserDate)
            articles.append(ArticleBrut(titre: titre, lien: lien, description: description, date: date))
        }
        return articles
    }

    private static func blocs(nomBalise: String, xml: String) -> [String] {
        var resultats: [String] = []
        var reste = xml
        while let debut = reste.range(of: "<\(nomBalise)>") {
            guard let fin = reste.range(of: "</\(nomBalise)>", range: debut.upperBound..<reste.endIndex) else { break }
            resultats.append(String(reste[debut.upperBound..<fin.lowerBound]))
            reste = String(reste[fin.upperBound...])
        }
        return resultats
    }

    private static func valeur(balises: [String], dans bloc: String) -> String? {
        for balise in balises {
            if let valeur = Self.contenu(balise: balise, dans: bloc), !valeur.isEmpty {
                return Self.nettoyer(valeur)
            }
        }
        return nil
    }

    private static func contenu(balise: String, dans bloc: String) -> String? {
        guard let debut = bloc.range(of: "<\(balise)>") ?? bloc.range(of: "<\(balise) "),
              let fin = bloc.range(of: "</\(balise)>") else { return nil }
        return String(bloc[debut.upperBound..<fin.lowerBound])
    }

    /// Lien Atom : <link rel="alternate" href="…"/>.
    private static func lienAtom(dans bloc: String) -> String? {
        guard let debut = bloc.range(of: "href=\"") else { return nil }
        guard let fin = bloc.range(of: "\"", range: debut.upperBound..<bloc.endIndex) else { return nil }
        return String(bloc[debut.upperBound..<fin.lowerBound])
    }

    /// Décode les entités HTML courantes et retire les éventuelles balises CDATA.
    private static func nettoyer(_ texte: String) -> String {
        texte
            .replacingOccurrences(of: "<![CDATA[", with: "")
            .replacingOccurrences(of: "]]>", with: "")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parsing des formats de date RSS/Atom courants.
    private static func parserDate(_ texte: String) -> Date? {
        let formats = ["EEE, dd MMM yyyy HH:mm:ss Z", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss.SSSZ"]
        let decodeur = DateFormatter()
        decodeur.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            decodeur.dateFormat = format
            if let date = decodeur.date(from: texte) { return date }
        }
        return ISO8601DateFormatter().date(from: texte)
    }
}

/// Article brut extrait d'un flux, avant conversion en ElementVeille.
public struct ArticleBrut: Sendable, Equatable {
    public var titre: String
    public var lien: String
    public var description: String?
    public var date: Date?

    public init(titre: String, lien: String, description: String?, date: Date?) {
        self.titre = titre
        self.lien = lien
        self.description = description
        self.date = date
    }
}

/// Élément de veille brut, avant déduplication et insertion en base.
public struct ElementVeilleBrut: Sendable, Equatable {
    public var veilleId: UUID
    public var url: String
    public var titre: String
    public var contenu: String
    public var datePublication: Date?
    public var hashContenu: String

    public init(veilleId: UUID, url: String, titre: String, contenu: String, datePublication: Date?, hashContenu: String) {
        self.veilleId = veilleId
        self.url = url
        self.titre = titre
        self.contenu = contenu
        self.datePublication = datePublication
        self.hashContenu = hashContenu
    }
}
