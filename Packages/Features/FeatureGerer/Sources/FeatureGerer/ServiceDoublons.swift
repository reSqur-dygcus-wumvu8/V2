import Foundation
import PackageDomain
import PackagePersistence

/// Service de détection et de fusion des doublons : documents (hash, similarité
/// de texte) et entités (dénominations similaires). Les propositions sont
/// toujours soumises à validation humaine explicite ; les paires refusées
/// sont mémorisées et jamais reproposées.
public struct ServiceDoublons: Sendable {

    public struct Seuils: Sendable, Equatable {
        /// Seuil de similarité Jaccard au-delà duquel une paire est proposée.
        public var similariteTexte: Double
        /// Similarité minimale entre dénominations d'entités.
        public var similariteDenomination: Double

        public init(similariteTexte: Double = 0.8, similariteDenomination: Double = 0.85) {
            self.similariteTexte = similariteTexte
            self.similariteDenomination = similariteDenomination
        }
    }

    let entrepotDoublon: EntrepotDoublon
    let entrepotEntite: EntrepotEntite
    let entrepotDocument: EntrepotDocument
    var seuils: Seuils

    public init(
        entrepotDoublon: EntrepotDoublon,
        entrepotEntite: EntrepotEntite,
        entrepotDocument: EntrepotDocument,
        seuils: Seuils = Seuils()
    ) {
        self.entrepotDoublon = entrepotDoublon
        self.entrepotEntite = entrepotEntite
        self.entrepotDocument = entrepotDocument
        self.seuils = seuils
    }

    /// Détecte les doublons d'entités : paires de dénominations similaires
    /// (Jaccard sur mots normalisés), hors paires déjà refusées.
    @discardableResult
    public func detecterDoublonsEntites() throws -> [PropositionDoublon] {
        let entites = entrepotEntite.toutes()
        let refusees = entrepotDoublon.refusees()
        var propositions: [PropositionDoublon] = []
        for i in 0..<entites.count {
            for j in (i + 1)..<entites.count {
                let a = entites[i]
                let b = entites[j]
                guard a.type == b.type else { continue }
                let paire = PaireUUID(a.id, b.id)
                guard !refusees.contains(paire) else { continue }
                let score = ReglesMetier.similariteJaccard(
                    ReglesMetier.normaliser(a.denomination),
                    ReglesMetier.normaliser(b.denomination)
                )
                if score >= seuils.similariteDenomination {
                    let proposition = PropositionDoublon(idA: a.id, idB: b.id, score: score)
                    entrepotDoublon.enregistrer(proposition)
                    propositions.append(proposition)
                }
            }
        }
        return propositions
    }

    /// Détecte les doublons de documents : textes extraits très similaires
    /// (le hash exact est déjà bloqué à l'import, cette passe couvre les
    /// contenus quasi identiques).
    @discardableResult
    public func detecterDoublonsDocuments() throws -> [PropositionDoublon] {
        let documents = entrepotDocument.tous()
        let refusees = entrepotDoublon.refusees()
        var propositions: [PropositionDoublon] = []
        for i in 0..<documents.count {
            for j in (i + 1)..<documents.count {
                let a = documents[i]
                let b = documents[j]
                guard let texteA = a.texteExtrait, let texteB = b.texteExtrait,
                      !texteA.isEmpty, !texteB.isEmpty else { continue }
                let paire = PaireUUID(a.id, b.id)
                guard !refusees.contains(paire) else { continue }
                let score = ReglesMetier.similariteJaccard(
                    ReglesMetier.normaliser(texteA),
                    ReglesMetier.normaliser(texteB)
                )
                if score >= seuils.similariteTexte {
                    let proposition = PropositionDoublon(idA: a.id, idB: b.id, score: score)
                    entrepotDoublon.enregistrer(proposition)
                    propositions.append(proposition)
                }
            }
        }
        return propositions
    }

    /// Fusionne deux entités : les champs choisis proviennent de l'entité
    /// absorbée, les autres sont conservés ; toutes les relations de
    /// l'absorbée sont transférées ; la fusion est journalisée.
    public func fusionnerEntites(
        gardee: Entite,
        fusionnee: Entite,
        champsDepuisFusionnee: Set<String>
    ) throws {
        var resultat = gardee
        if champsDepuisFusionnee.contains("denomination") { resultat.denomination = fusionnee.denomination }
        if champsDepuisFusionnee.contains("prenom") { resultat.prenom = fusionnee.prenom }
        if champsDepuisFusionnee.contains("nom") { resultat.nom = fusionnee.nom }
        if champsDepuisFusionnee.contains("resume") { resultat.resume = fusionnee.resume ?? resultat.resume }
        if champsDepuisFusionnee.contains("biographie") { resultat.biographie = fusionnee.biographie ?? resultat.biographie }
        if champsDepuisFusionnee.contains("commentaires") {
            let commentaires = [resultat.commentaires, fusionnee.commentaires]
                .compactMap { $0 }.filter { !$0.isEmpty }
            resultat.commentaires = commentaires.isEmpty ? nil : commentaires.joined(separator: "\n")
        }
        resultat.updatedAt = Date()
        entrepotEntite.enregistrer(resultat)

        // Transfert des relations de l'absorbée vers la conservée.
        for var relation in entrepotEntite.relations(id: fusionnee.id) {
            if relation.idSource == fusionnee.id { relation.idSource = gardee.id } else { relation.idCible = gardee.id }
            entrepotEntite.relier(relation)
        }
        // L'absorbée devient une tombstone.
        entrepotEntite.supprimer(fusionnee.id)
        // Journal de fusion.
        entrepotDoublon.journaliserFusion(
            EntreeFusion(
                entiteGardee: gardee.id,
                entiteFusionnee: fusionnee.id,
                champsChoisis: Array(champsDepuisFusionnee).sorted()
            )
        )
    }
}
