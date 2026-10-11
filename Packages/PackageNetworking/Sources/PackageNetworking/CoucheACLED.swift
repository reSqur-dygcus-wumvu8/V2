import Foundation
import PackageDomain
import PackageTor

/// Événement ACLED (Armed Conflict Location & Event Data) mis en cache
/// localement (segment MLA « acled »), filtrable par date, type et zone.
public struct EvenementACLED: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    /// Identifiant ACLED d'origine (event_id_cnt).
    public var idACLED: String
    public var date: String
    public var typeEvenement: String
    public var acteur1: String?
    public var acteur2: String?
    public var pays: String
    public var lieu: String?
    public var latitude: Double?
    public var longitude: Double?
    public var notes: String?
    public var fatalites: Int?

    public init(
        id: UUID = UUID(),
        idACLED: String,
        date: String,
        typeEvenement: String,
        acteur1: String? = nil,
        acteur2: String? = nil,
        pays: String,
        lieu: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        notes: String? = nil,
        fatalites: Int? = nil
    ) {
        self.id = id
        self.idACLED = idACLED
        self.date = date
        self.typeEvenement = typeEvenement
        self.acteur1 = acteur1
        self.acteur2 = acteur2
        self.pays = pays
        self.lieu = lieu
        self.latitude = latitude
        self.longitude = longitude
        self.notes = notes
        self.fatalites = fatalites
    }
}

/// Service ACLED : téléchargement via Tor (API ACLED, gratuit après
/// inscription myACLED — clé conservée dans le Gestionnaire d'accès),
/// stockage local en archive MLA (segment « acled »), mise à jour à la
/// demande, filtres date/type/zone, rattachement à la base de
/// connaissance par clic droit.
/// Attribution obligatoire : « ACLED » doit être affichée sur la couche
/// et dans tous les exports contenant des données ACLED.
public struct ServiceACLED: Sendable {

    /// Point d'entrée de l'API ACLED (extraction CSV).
    public static let urlAPI = "https://api.acleddata.com/acled/read"

    private let reseau: ReseauTor

    public init(reseau: ReseauTor) {
        self.reseau = reseau
    }

    /// Attribution obligatoire (politique ACLED) : à afficher sur la
    /// couche carte et dans tous les exports de données ACLED.
    public static let attribution = "Données : ACLED (Armed Conflict Location & Event Data Project)"

    /// Télécharge les événements d'une période et d'une zone (bbox),
    /// via Tor, avec la clé myACLED (délivrée par le Gestionnaire d'accès).
    /// - Parameters:
    ///   - cleAPI: clé d'accès myACLED (jamais stockée par ce service).
    ///   - email: e-mail du compte myACLED (requis par l'API).
    ///   - depuis/ jusqua: dates ISO (yyyy-MM-dd).
    ///   - limites: bbox optionnelle (lat_min, lon_min, lat_max, lon_max).
    public func telecharger(
        cleAPI: String,
        email: String,
        depuis: String,
        jusqua: String,
        limites: (Double, Double, Double, Double)? = nil
    ) async throws -> [EvenementACLED] {
        var parametres = [
            "key=\(cleAPI)",
            "email=\(email)",
            "event_date=\(depuis)|\(jusqua)",
            "event_date_where=BETWEEN",
            "limit=1000"
        ]
        if let limites {
            parametres.append("lat_min=\(limites.0)")
            parametres.append("lon_min=\(limites.1)")
            parametres.append("lat_max=\(limites.2)")
            parametres.append("lon_max=\(limites.3)")
        }
        let urlTexte = "\(Self.urlAPI)?" + parametres.joined(separator: "&")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        guard let url = URL(string: urlTexte) else { throw ErreurVeille.urlInvalide }
        let donnees = try await reseau.telecharger(url)
        return try Self.decoderCSV(donnees: donnees)
    }

    /// Décode la réponse CSV de l'API ACLED (en-tête : data).
    static func decoderCSV(donnees: Data) throws -> [EvenementACLED] {
        guard let texte = String(data: donnees, encoding: .utf8) else {
            throw ErreurVeille.fluxIllisible
        }
        let lignes = texte.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard lignes.count > 1 else { return [] }
        let entetes = Self.champsCSV(ligne: lignes[0])
        var evenements: [EvenementACLED] = []
        for ligne in lignes.dropFirst() {
            let valeurs = Self.champsCSV(ligne: ligne)
            guard valeurs.count == entetes.count else { continue }
            var dict: [String: String] = [:]
            for (index, entete) in entetes.enumerated() {
                dict[entete] = index < valeurs.count ? valeurs[index] : ""
            }
            guard let idACLED = dict["event_id_cnt"], !idACLED.isEmpty else { continue }
            evenements.append(
                EvenementACLED(
                    idACLED: idACLED,
                    date: dict["event_date"] ?? "",
                    typeEvenement: dict["event_type"] ?? "",
                    acteur1: dict["actor1"].flatMap { $0.isEmpty ? nil : $0 },
                    acteur2: dict["actor2"].flatMap { $0.isEmpty ? nil : $0 },
                    pays: dict["country"] ?? "",
                    lieu: dict["location"].flatMap { $0.isEmpty ? nil : $0 },
                    latitude: Double(dict["latitude"] ?? ""),
                    longitude: Double(dict["longitude"] ?? ""),
                    notes: dict["notes"].flatMap { $0.isEmpty ? nil : $0 },
                    fatalites: Int(dict["fatalities"] ?? "")
                )
            )
        }
        return evenements
    }

    /// Découpe une ligne CSV en gérant les guillemets.
    static func champsCSV(ligne: String) -> [String] {
        var champs: [String] = []
        var courant = ""
        var entreGuillemets = false
        for caractere in ligne {
            if caractere == "\"" {
                entreGuillemets.toggle()
            } else if caractere == "," && !entreGuillemets {
                champs.append(courant)
                courant = ""
            } else {
                courant.append(caractere)
            }
        }
        champs.append(courant)
        return champs
    }

    /// Filtre les événements par date, type et zone (bbox).
    public static func filtrer(
        evenements: [EvenementACLED],
        depuis: String? = nil,
        jusqua: String? = nil,
        typeEvenement: String? = nil,
        zone: (Double, Double, Double, Double)? = nil
    ) -> [EvenementACLED] {
        evenements.filter { evenement in
            if let depuis, evenement.date < depuis { return false }
            if let jusqua, evenement.date > jusqua { return false }
            if let typeEvenement, !typeEvenement.isEmpty,
               evenement.typeEvenement.localizedCaseInsensitiveContains(typeEvenement) { return false }
            if let zone, let lat = evenement.latitude, let lon = evenement.longitude {
                guard lat >= zone.0, lat <= zone.2, lon >= zone.1, lon <= zone.3 else { return false }
            }
            return true
        }
    }
}
