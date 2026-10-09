import Vapor

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
            return try await appelerMistral(req, cle: cleMistral, endpoint: "chat")
        }

        // POST /ner — extraction d'entités nommées.
        app.post("ner") { req -> String in
            try verifierToken(req, attendu: tokenClient)
            return try await appelerMistral(req, cle: cleMistral, endpoint: "chat")
        }

        // POST /cotation — proposition de cotation OTAN.
        app.post("cotation") { req -> String in
            try verifierToken(req, attendu: tokenClient)
            return try await appelerMistral(req, cle: cleMistral, endpoint: "chat")
        }

        // POST /embeddings — vecteurs de similarité.
        app.post("embeddings") { req -> String in
            try verifierToken(req, attendu: tokenClient)
            return try await appelerMistral(req, cle: cleMistral, endpoint: "embeddings")
        }

        defer { app.shutdown() }
        try await app.execute()
    }

    /// Vérifie le token app→proxy.
    private static func verifierToken(_ req: Request, attendu: String) throws {
        guard req.headers.first(name: "Authorization") == "Bearer \(attendu)" else {
            throw Abort(.unauthorized)
        }
    }

    /// Relais générique vers l'API Mistral (clé ajoutée côté serveur).
    private static func appelerMistral(_ req: Request, cle: String, endpoint: String) async throws -> String {
        let corps = try req.content.decode(ByteBuffer.self)
        var enTetes = HTTPHeaders()
        enTetes.replaceOrAdd(name: .authorization, value: "Bearer \(cle)")
        enTetes.replaceOrAdd(name: .contentType, value: "application/json")
        let reponse = try await req.client.post("https://api.mistral.ai/v1/\(endpoint)", headers: enTetes) { requeteSortante in
            requeteSortante.body = corps
        }
        return String(buffer: reponse.body ?? ByteBuffer())
    }
}
