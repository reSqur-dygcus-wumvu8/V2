import Vapor
import Crypto

/// Proxy Mistral : relais authentifié entre l'application et l'API Mistral.
/// La clé Mistral est lue depuis la variable d'environnement MISTRAL_API_KEY
/// (fichier .env ignoré par Git) et n'est jamais exposée au client.
@main
struct ProxyMistral {
    static func main() async throws {
        var env = try await Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        let app = try await Application.make(env)

        // Authentification des clients : token app→proxy attendu dans
        // l'en-tête Authorization (variable d'environnement TOKEN_CLIENT).
        guard let cleMistral = Environment.get("MISTRAL_API_KEY"),
              let tokenClient = Environment.get("TOKEN_CLIENT") else {
            fatalError("Variables MISTRAL_API_KEY et TOKEN_CLIENT requises.")
        }

        // GET /sante — vérification de disponibilité.
        app.get("sante") { req in
            "ok"
        }

        // POST /resumer — résumé d'un contenu.
        app.post("resumer") { req -> String in
            try verifierToken(req, attendu: tokenClient)
            return try await appelerMistralChat(req, cle: cleMistral, corps: try corpsControle(req, obligatoire: "contenu"))
        }

        // POST /ner — extraction d'entités nommées.
        app.post("ner") { req -> String in
            try verifierToken(req, attendu: tokenClient)
            return try await appelerMistralChat(req, cle: cleMistral, corps: try corpsControle(req, obligatoire: "contenu"))
        }

        // POST /cotation — proposition de cotation OTAN.
        app.post("cotation") { req -> String in
            try verifierToken(req, attendu: tokenClient)
            return try await appelerMistralChat(req, cle: cleMistral, corps: try corpsControle(req, obligatoire: "contenu"))
        }

        // POST /embeddings — vecteurs de similarité.
        app.post("embeddings") { req -> String in
            try verifierToken(req, attendu: tokenClient)
            return try await appelerMistralEmbeddings(req, cle: cleMistral, corps: try corpsControle(req, obligatoire: "texte"))
        }

        // POST /traduire — traduction vers le français (veille multilingue).
        app.post("traduire") { req -> String in
            try verifierToken(req, attendu: tokenClient)
            guard let corps = try? req.content.decode([String: String].self),
                  let texte = corps["texte"] else {
                throw Abort(.badRequest)
            }
            guard texte.utf8.count <= limiteCaracteres else {
                throw Abort(.payloadTooLarge)
            }
            let langueSource = corps["langue_source"] ?? "auto"
            let prompt = """
            Tu es un traducteur. Traduis en français le texte entre les délimiteurs \
            et réponds uniquement par la traduction, sans commentaire.
            Langue source : \(langueSource)
            <<<DEBUT_TEXTE>>>
            \(texte)
            <<<FIN_TEXTE>>>
            """
            return try await appelerMistralPrompt(req, cle: cleMistral, prompt: prompt)
        }

        defer { app.shutdown() }
        try await app.execute()
    }

    /// Limite de taille des textes soumis (caractères) — borne l'abus de
    /// quota sur la clé Mistral côté serveur.
    static let limiteCaracteres = 60_000

    /// Vérifie le token app→proxy par comparaison à temps constant
    /// (HMAC sur les deux valeurs : aucune fuite temporelle liée à la
    /// longueur ou au contenu du token attendu).
    private static func verifierToken(_ req: Request, attendu: String) throws {
        guard let autorisation = req.headers.first(name: "Authorization"),
              autorisation.hasPrefix("Bearer ") else {
            throw Abort(.unauthorized)
        }
        let recu = Data(String(autorisation.dropFirst("Bearer ".count)).utf8)
        let cleHMAC = SymmetricKey(data: Data(attendu.utf8))
        let attenduHMAC = HMAC<SHA256>.authenticationCode(for: Data(attendu.utf8), using: cleHMAC)
        let recuHMAC = HMAC<SHA256>.authenticationCode(for: recu, using: cleHMAC)
        guard Data(recuHMAC) == Data(attenduHMAC) else {
            throw Abort(.unauthorized)
        }
    }

    /// Décode le corps du client en conservant uniquement les champs
    /// autorisés (contenu / motsCles / texte) et en bornant leur taille :
    /// le client ne contrôle ni le modèle ni les paramètres de la requête
    /// Mistral finale. Accepte JSON ou multipart (format du client iOS).
    private static func corpsControle(_ req: Request, obligatoire: String) throws -> [String: Any] {
        let champs: [String: String]
        if let json = try? req.content.decode([String: String].self) {
            champs = json
        } else {
            let brut = try req.content.decode(ByteBuffer.self)
            champs = Self.champsMultipart(corps: brut)
        }
        guard let champ = champs[obligatoire], !champ.isEmpty else {
            throw Abort(.badRequest)
        }
        guard champ.utf8.count <= limiteCaracteres else {
            throw Abort(.payloadTooLarge)
        }
        if obligatoire == "texte" {
            return ["model": "mistral-embed", "input": champ]
        }
        var invite = "Résume le texte suivant. "
        if let motsCles = champs["motsCles"], !motsCles.isEmpty {
            let liste = motsCles.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            invite += "Focalise sur les mots-clés suivants : \(liste.joined(separator: ", ")). "
        }
        invite += "Texte : \(champ)"
        return ["model": "mistral-small-latest", "messages": [["role": "user", "content": invite]]]
    }

    /// Extraction des champs d'un corps multipart (form-data) : nom entre
    /// guillemets après Content-Disposition, valeur jusqu'au bloc suivant.
    static func champsMultipart(corps: ByteBuffer) -> [String: String] {
        guard let texte = String(buffer: corps) else { return [:] }
        guard let debutLimite = texte.range(of: "--") else { return [:] }
        let longueurLimite = min(64, texte.distance(from: debutLimite.lowerBound, to: texte.endIndex))
        let limite = String(texte[debutLimite.lowerBound..<texte.index(debutLimite.lowerBound, offsetBy: longueurLimite)])
        var champs: [String: String] = [:]
        let blocs = texte.components(separatedBy: limite)
        for bloc in blocs.dropFirst() where bloc.contains("name=\"") {
            guard let ouverture = bloc.range(of: "name=\""),
                  let finNom = bloc.range(of: "\"", range: ouverture.upperBound..<bloc.endIndex),
                  let debutValeur = bloc.range(of: "\r\n\r\n") else { continue }
            let nom = String(bloc[ouverture.upperBound..<finNom.lowerBound])
            let valeur = String(bloc[debutValeur.upperBound...])
                .replacingOccurrences(of: "\r\n--", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "\r\n-"))
            champs[nom] = valeur
        }
        return champs
    }

    /// Relais chat avec corps contrôlé (résumé / NER / cotation).
    private static func appelerMistralChat(_ req: Request, cle: String, corps: [String: Any]) async throws -> String {
        try await relayer(req, cle: cle, endpoint: "chat/completions", corps: corps)
    }

    /// Relais embeddings avec corps contrôlé.
    private static func appelerMistralEmbeddings(_ req: Request, cle: String, corps: [String: Any]) async throws -> String {
        try await relayer(req, cle: cle, endpoint: "embeddings", corps: corps)
    }

    /// Relais chat avec prompt direct (traduction, texte délimité).
    private static func appelerMistralPrompt(_ req: Request, cle: String, prompt: String) async throws -> String {
        let corps: [String: Any] = [
            "model": "mistral-small-latest",
            "messages": [["role": "user", "content": prompt]]
        ]
        return try await relayer(req, cle: cle, endpoint: "chat/completions", corps: corps)
    }

    /// Relais générique vers l'API Mistral — corps toujours construit côté
    /// serveur (le JSON du client n'est jamais retransmis tel quel).
    private static func relayer(_ req: Request, cle: String, endpoint: String, corps: [String: Any]) async throws -> String {
        let donnees = try JSONSerialization.data(withJSONObject: corps)
        var enTetes = HTTPHeaders()
        enTetes.replaceOrAdd(name: .authorization, value: "Bearer \(cle)")
        enTetes.replaceOrAdd(name: .contentType, value: "application/json")
        let reponse = try await req.client.post("https://api.mistral.ai/v1/\(endpoint)", headers: enTetes) { requeteSortante in
            requeteSortante.body = ByteBuffer(data: donnees)
        }
        guard (200..<300).contains(reponse.status.code) else {
            throw Abort(.badGateway)
        }
        return String(buffer: reponse.body ?? ByteBuffer())
    }
}
