import Foundation
import PackageDomain
import PackagePersistence
import PackageIntelligence

/// Service de capitalisation : regroupement d'éléments de veille en événements,
/// cotation assistée par Mistral (validation humaine obligatoire), reconnaissance
/// d'entités existantes et création de nouvelles entités.
public struct ServiceCapitalisation: Sendable {

    let entrepotEntite: EntrepotEntite
    let entrepotElements: EntrepotElementVeille
    let entrepotRegroupement: EntrepotRegroupement
    let clientMistral: ClientProxyMistral?

    public init(
        entrepotEntite: EntrepotEntite,
        entrepotElements: EntrepotElementVeille,
        entrepotRegroupement: EntrepotRegroupement,
        clientMistral: ClientProxyMistral? = nil
    ) {
        self.entrepotEntite = entrepotEntite
        self.entrepotElements = entrepotElements
        self.entrepotRegroupement = entrepotRegroupement
        self.clientMistral = clientMistral
    }

    /// Crée un regroupement d'événements à partir d'éléments sélectionnés,
    /// avec résumé Mistral si le client est disponible (sinon résumé local).
    public func creerRegroupement(
        titre: String,
        elements: [ElementVeille]
    ) async throws -> RegroupementEvenement {
        var regroupement = RegroupementEvenement(
            titre: titre,
            resume: resumeLocal(elements: elements),
            elementIds: elements.map(\.id)
        )
        if let client = clientMistral {
            let contenuConcatene = elements.map { "\($0.titre) — \($0.contenu)" }.joined(separator: "\n\n")
            regroupement.resume = (try? await client.resumer(contenu: contenuConcatene)) ?? regroupement.resume
        }
        entrepotRegroupement.enregistrer(regroupement)
        for element in elements {
            entrepotElements.marquerTraite(element.id, statut: .capitalise)
        }
        return regroupement
    }

    /// Propose une cotation OTAN assistée : Mistral propose, l'humain valide.
    /// Retourne la proposition (ou une cotation neutre F6 en l'absence de client).
    public func proposerCotation(contenu: String) async -> CotationOTAN.Proposition {
        guard let client = clientMistral,
              let proposition = try? await client.proposerCotation(contenu: contenu) else {
            return CotationOTAN.Proposition(
                cotation: CotationOTAN(fiabiliteSource: .f, credibiliteInfo: .nePeutEtreJugee),
                justification: "Proxy indisponible — cotation neutre F6, à décider manuellement."
            )
        }
        return proposition
    }

    /// Reconnaissance d'entités : cherche dans la base les entités dont le nom
    /// apparaît dans le texte (similarité de dénomination), retourne les couples
    /// (entité existante, occurrence trouvée) pour validation.
    public func reconnaitreEntites(dans texte: String) throws -> [(Entite, String)] {
        let entites = entrepotEntite.toutes()
        var reconnues: [(Entite, String)] = []
        for entite in entites {
            let candidats = [entite.denomination, entite.prenom, entite.nom]
                .compactMap { $0 }
                .filter { $0.count > 2 }
            for candidat in candidats where texte.localizedCaseInsensitiveContains(candidat) {
                reconnues.append((entite, candidat))
                break
            }
        }
        return reconnues
    }

    /// Extrait les entités nommées via Mistral (NER) et propose les types.
    public func extraireEntites(dans contenu: String) async -> [EntiteExtraite] {
        guard let client = clientMistral else { return [] }
        return (try? await client.extraireEntites(contenu: contenu)) ?? []
    }

    /// Crée une nouvelle entité depuis un terme sélectionné du texte
    /// (clic droit « Créer comme entité »).
    @discardableResult
    public func creerEntite(depuisTerme terme: String, type: TypeEntite) throws -> Entite {
        var entite: Entite
        switch type {
        case .individu:
            let parties = terme.split(separator: " ", maxSplits: 1)
            entite = Entite(type: .individu, denomination: terme)
            entite.prenom = parties.first.map(String.init)
            entite.nom = parties.count > 1 ? String(parties[1]) : nil
        case .evenement:
            entite = Entite(type: .evenement, denomination: terme, dateHeure: Date())
        default:
            entite = Entite(type: type, denomination: terme)
        }
        entrepotEntite.enregistrer(entite)
        return entite
    }

    /// Résumé local de secours (premières phrases des éléments).
    func resumeLocal(elements: [ElementVeille]) -> String {
        elements
            .map { $0.titre + " : " + String($0.contenu.prefix(120)) }
            .joined(separator: " ")
    }
}
