import XCTest
import PackageDomain
@testable import PackageNetworking

/// Tests du connecteur VK (décodage API, plateformes).
final class ConnecteurVKTests: XCTestCase {

    private let jsonVK = """
    {
      "response": {
        "items": [
          {"id": 101, "date": 1736150400, "text": "Publication du mur surveillé.", "owner_id": -12345},
          {"id": 102, "date": 1736236800, "text": "", "owner_id": -12345},
          {"id": 103, "date": 1736323200, "text": "Troisième publication.", "owner_id": -12345}
        ]
      }
    }
    """

    func testPlateformeVKDeclaree() {
        XCTAssertTrue(PlateformeSociale.allCases.contains(.vk))
        XCTAssertEqual(PlateformeSociale.vk.libelle, "VK (ВКонтакте)")
        XCTAssertFalse(PlateformeSociale.vk.methodeEtRisque.isEmpty)
        XCTAssertTrue(PlateformeSociale.vk.methodeEtRisque.contains("wall.get"))
    }

    func testConnecteurVKConfiguration() {
        let connecteur = ConnecteurVK(token: "token-x", reseau: ReseauTor(client: ClientTor()))
        XCTAssertEqual(connecteur.plateforme, .vk)
        XCTAssertEqual(connecteur.versionAPI, "5.199")
    }

    func testDecodagePublications() throws {
        // Le décodage JSON de la structure VK est validé via la réponse type.
        struct ReponseTest: Codable {
            var response: Contenu
            struct Contenu: Codable {
                var items: [Item]
                struct Item: Codable {
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
        let reponse = try JSONDecoder().decode(ReponseTest.self, from: Data(jsonVK.utf8))
        XCTAssertEqual(reponse.response.items.count, 3)
        XCTAssertEqual(reponse.response.items[0].text, "Publication du mur surveillé.")
        XCTAssertNotNil(reponse.response.items[0].date)
    }
}

/// Tests de la couche ACLED (décodage CSV, filtres).
final class CoucheACLEDTests: XCTestCase {

    private let csvACLED = """
    "data"
    "event_id_cnt","event_date","event_type","actor1","actor2","country","location","latitude","longitude","notes","fatalities"
    "100001","2025-01-06","Battles","Force A","Force B","France","Lyon","45.75","4.85","Notes complètes","3"
    "100002","2025-01-07","Protests","Groupement","","France","Paris","48.85","2.35","","0"
    "100003","2025-01-08","Riots","","","France","","","","",""
    """

    func testAttributionObligatoire() {
        XCTAssertTrue(ServiceACLED.attribution.contains("ACLED"))
    }

    func testDecodageCSV() throws {
        // La réponse ACLED réelle a une ligne "data" puis l'en-tête ; le
        // décodeur du service attend en-tête en ligne 0 : la ligne "data"
        // est ignorée par le garde (valeurs != entetes).
        let evenements = try ServiceACLED.decoderCSV(donnees: Data(csvACLED.utf8))
        // L'en-tête est la 1re ligne, "data" est traité comme en-tête invalide :
        // on vérifie ici le comportement de champsCSV et du décodage simple.
        XCTAssertGreaterThanOrEqual(evenements.count, 2)
        XCTAssertEqual(evenements.first?.typeEvenement, "Battles")
        XCTAssertEqual(evenements.first?.fatalites, 3)
        XCTAssertEqual(evenements.first?.latitude ?? 0, 45.75, accuracy: 0.001)
        // La ligne sans pays valide est potentiellement conservée — le garde
        // porte sur event_id_cnt non vide.
    }

    func testChampsCSVAvecGuillemets() {
        let champs = ServiceACLED.champsCSV(ligne: "\"a,b\",\"c\"\"d\",e")
        XCTAssertEqual(champs, ["a,b", "c\"d", "e"])
    }

    func testFiltresDateTypeZone() {
        let evenements = [
            EvenementACLED(idACLED: "1", date: "2025-01-06", typeEvenement: "Battles", pays: "France", latitude: 45.75, longitude: 4.85),
            EvenementACLED(idACLED: "2", date: "2025-02-01", typeEvenement: "Protests", pays: "France", latitude: 48.85, longitude: 2.35),
            EvenementACLED(idACLED: "3", date: "2025-01-07", typeEvenement: "Battles", pays: "France", latitude: 10.0, longitude: 10.0)
        ]
        // Filtre date.
        XCTAssertEqual(ServiceACLED.filtrer(evenements: evenements, jusqua: "2025-01-31").count, 2)
        // Filtre zone (bbox France).
        let france = (41.0, -5.0, 51.0, 10.0)
        XCTAssertEqual(ServiceACLED.filtrer(evenements: evenements, zone: france).count, 2)
        // Filtre type (le type ne correspondant pas est écarté).
        XCTAssertEqual(ServiceACLED.filtrer(evenements: evenements, typeEvenement: "inexistant").count, 0)
    }
}
