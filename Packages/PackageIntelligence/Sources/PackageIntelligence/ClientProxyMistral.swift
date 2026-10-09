import Foundation
import PackageDomain

/// Client du proxy Mistral. Toutes les requêtes passent par le serveur
/// proxy Vapor qui détient la clé API — l'app cliente ne la connaît jamais.
public actor ClientProxyMistral: Sendable {

    public struct Configuration: Sendable, Equatable {
        /// URL de base du proxy (ex. https://proxy.example.com).
        public var urlBase: URL
        /// Token d'authentification app→proxy, stocké dans le Keychain.
        public var token: String

        public init(urlBase: URL, token: String) {
            self.urlBase = urlBase
            self.token = token
        }
    }

    /// Résumé d'un contenu, avec ou sans mots-clés de focalisation.
    public func resumer(contenu: String, motsCles: [String] = []) async throws -> String {
        var requete = MultipartUpload(url: configuration.urlBase.appendingPathComponent("resumer"))
        requete.add(name: "contenu", string: contenu)
        for mot in motsCles {
            requete.add(name: "motsCles", string: mot)
        }
        return try await envoyer(requete)
    }

    /// Extraction d'entités nommées (NER) : individus, organisations,
    /// événements, lieux, objets.
    public func extraireEntites(contenu: String) async throws -> [EntiteExtraite] {
        var requete = MultipartUpload(url: configuration.urlBase.appendingPathComponent("ner"))
        requete.add(name: "contenu", string: contenu)
        let data = try await envoyerDonnees(requete)
        return try JSONDecoder().decode([EntiteExtraite].self, from: data)
    }

    /// Proposition de cotation OTAN assistée (source et information).
    public func proposerCotation(contenu: String) async throws -> CotationOTAN.Proposition {
        var requete = MultipartUpload(url: configuration.urlBase.appendingPathComponent("cotation"))
        requete.add(name: "contenu", string: contenu)
        let data = try await envoyerDonnees(requete)
        return try JSONDecoder().decode(CotationOTAN.Proposition.self, from: data)
    }

    /// Embeddings pour la détection de doublons et la reconnaissance d'entités.
    public func embeddings(texte: String) async throws -> [Float] {
        var requete = MultipartUpload(url: configuration.urlBase.appendingPathComponent("embeddings"))
        requete.add(name: "texte", string: texte)
        let data = try await envoyerDonnees(requete)
        return try JSONDecoder().decode([Float].self, from: data)
    }

    // MARK: - Privé

    private let configuration: Configuration
    private let session: URLSession

    public init(configuration: Configuration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    private func envoyer(_ requete: MultipartUpload) async throws -> String {
        let data = try await envoyerDonnees(requete)
        guard let texte = String(data: data, encoding: .utf8) else {
            throw ErreurProxy.reponseIllisible
        }
        return texte
    }

    private func envoyerDonnees(_ upload: MultipartUpload) async throws -> Data {
        var requete = URLRequest(url: upload.url)
        requete.httpMethod = "POST"
        requete.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        requete.timeoutInterval = 30
        requete.httpBody = upload.corps()
        let (data, reponse) = try await session.data(for: requete)
        guard let http = reponse as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ErreurProxy.statutInattendu
        }
        return data
    }
}

/// Erreurs du proxy.
public enum ErreurProxy: Error, LocalizedError {
    case reponseIllisible
    case statutInattendu

    public var errorDescription: String? {
        switch self {
        case .reponseIllisible: return "Réponse du proxy illisible."
        case .statutInattendu: return "Statut HTTP inattendu du proxy."
        }
    }
}

/// Entité nommée extraite par le NER.
public struct EntiteExtraite: Codable, Sendable, Equatable {
    public var texte: String
    public var type: String

    public init(texte: String, type: String) {
        self.texte = texte
        self.type = type
    }
}

/// Construction simple de corps multipart (sans dépendance externe).
public struct MultipartUpload: Sendable {
    private let limite = "----OsintSuiteLimite"
    private var parties: [String: String] = [:]
    private var ordre: [String] = []
    let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// Ajoute un champ texte (les valeurs répétées conservent l'ordre d'ajout).
    public mutating func add(name: String, string: String) {
        let cle = "\(name)#\(ordre.count)"
        parties[cle] = string
        ordre.append(cle)
    }

    /// Corps multipart encodé.
    public func corps() -> Data {
        var corps = Data()
        for cle in ordre {
            let nom = String(cle.split(separator: "#").first ?? "")
            guard let valeur = parties[cle] else { continue }
            corps.append("--\(limite)\r\n")
            corps.append("Content-Disposition: form-data; name=\"\(nom)\"\r\n\r\n")
            corps.append("\(valeur)\r\n")
        }
        corps.append("--\(limite)--\r\n")
        return corps
    }
}

extension Data {
    fileprivate mutating func append(_ texte: String) {
        append(Data(texte.utf8))
    }
}

/// Extension Domain : proposition de cotation par Mistral, validée par l'humain.
extension CotationOTAN {
    /// Proposition de cotation (avec justification) soumise à validation.
    public struct Proposition: Codable, Sendable, Equatable {
        public var cotation: CotationOTAN
        public var justification: String

        public init(cotation: CotationOTAN, justification: String) {
            self.cotation = cotation
            self.justification = justification
        }
    }
}
