import Foundation
import PackageDomain

/// Entrepôt des entités de la base de connaissance (API conservée,
/// moteur MLA en dessous).
public struct EntrepotEntite: Sendable {

    let moteur: MoteurStockage

    public init(moteur: MoteurStockage) {
        self.moteur = moteur
    }

    public func enregistrer(_ entite: Entite) {
        moteur.muter { $0.enregistrerEntite(entite) }
    }

    public func toutes() -> [Entite] {
        moteur.entites.values.filter { !$0.supprime }.sorted { $0.denomination < $1.denomination }
    }

    public func parType(_ type: TypeEntite) -> [Entite] {
        toutes().filter { $0.type == type }
    }

    public func chercher(id: UUID) -> Entite? {
        moteur.entites[id].map { $0.supprime ? nil : $0 } ?? nil
    }

    public func chercher(denomination: String) -> Entite? {
        toutes().first { $0.denomination == denomination }
    }

    public func supprimer(_ id: UUID) {
        moteur.muter { $0.supprimerEntite(id) }
    }

    public func relier(_ relation: RelationEntites) {
        moteur.muter { $0.enregistrerRelation(relation) }
    }

    public func relations(id: UUID) -> [RelationEntites] {
        moteur.relationsDe(id)
    }

    public func historique(entiteId: UUID) -> [VersionEntite] {
        moteur.versions[entiteId] ?? []
    }

    public func journaliser(_ version: VersionEntite) {
        moteur.muter { $0.enregistrerVersion(version) }
    }

    public func rattacherDocument(documentId: UUID, entiteId: UUID) {
        // Le lien document-entité est porté par l'index des versions et
        // les relations ; conservé pour compatibilité API.
    }
}

/// Entrepôt des documents importés.
public struct EntrepotDocument: Sendable {

    let moteur: MoteurStockage

    public init(moteur: MoteurStockage) {
        self.moteur = moteur
    }

    @discardableResult
    public func inserer(_ document: Document) -> Bool {
        var insere = false
        moteur.muter { insere = $0.enregistrerDocument(document) }
        return insere
    }

    public func tous() -> [Document] {
        moteur.documents.values.sorted { $0.dateImport > $1.dateImport }
    }

    /// Recherche plein texte sur les documents (texte extrait + nom).
    public func rechercher(texte: String) -> [Document] {
        let motif = texte.lowercased()
        return moteur.documents.values.filter { document in
            (document.nom.lowercased().contains(motif)
                || (document.texteExtrait ?? "").lowercased().contains(motif))
        }
    }
}

/// Entrepôt des veilles et de leur journal d'exécution.
public struct EntrepotVeille: Sendable {

    let moteur: MoteurStockage

    public init(moteur: MoteurStockage) {
        self.moteur = moteur
    }

    public func actives() -> [Veille] {
        moteur.veilles.values.filter(\.active).sorted { $0.titre < $1.titre }
    }

    public func toutes() -> [Veille] {
        moteur.veilles.values.sorted { $0.titre < $1.titre }
    }

    public func enregistrer(_ veille: Veille) {
        moteur.muter { $0.veilles[veille.id] = veille }
    }

    public func supprimer(_ id: UUID) {
        moteur.muter { moteur in
            moteur.elements = moteur.elements.filter { $0.value.veilleId != id }
            moteur.veilles[id] = nil
        }
    }

    public func journaliser(_ resultat: ResultatJournal) {
        moteur.muter { $0.enregistrerJournal(resultat) }
    }

    public func journal(veilleId: UUID) -> [ResultatJournal] {
        moteur.journalExecutions
            .filter { $0.veilleId == veilleId }
            .sorted { $0.date > $1.date }
    }
}

/// Entrepôt des éléments de veille (file d'attente, déduplication).
public struct EntrepotElementVeille: Sendable {

    let moteur: MoteurStockage

    public init(moteur: MoteurStockage) {
        self.moteur = moteur
    }

    @discardableResult
    public func insererNouveaux(_ elements: [ElementVeille]) -> [ElementVeille] {
        var inseres: [ElementVeille] = []
        moteur.muter { moteur in
            for element in elements where moteur.enregistrerElement(element) {
                inseres.append(element)
            }
        }
        return inseres
    }

    public func fileAttente() -> [ElementVeille] {
        moteur.elements.values
            .filter { $0.statut == .nonTraite }
            .sorted { $0.dateCollecte > $1.dateCollecte }
    }

    public func hashesVus(veilleId: UUID) -> Set<String> {
        moteur.hashesVus(veilleId: veilleId)
    }

    public func marquerTraite(_ id: UUID, statut: StatutTraitement) {
        moteur.muter { $0.marquerElement(id, statut: statut) }
    }
}

/// Entrepôt des sources d'information.
public struct EntrepotSource: Sendable {

    let moteur: MoteurStockage

    public init(moteur: MoteurStockage) {
        self.moteur = moteur
    }

    public func enregistrer(_ source: SourceInfo) {
        moteur.muter { $0.sources[source.id] = source }
    }

    public func toutes() -> [SourceInfo] {
        moteur.sources.values.sorted { $0.denomination < $1.denomination }
    }

    public func chercher(denomination: String) -> SourceInfo? {
        toutes().first { $0.denomination == denomination }
    }
}

/// Entrepôt des regroupements d'événements.
public struct EntrepotRegroupement: Sendable {

    let moteur: MoteurStockage

    public init(moteur: MoteurStockage) {
        self.moteur = moteur
    }

    public func enregistrer(_ regroupement: RegroupementEvenement) {
        moteur.muter { $0.regroupements[regroupement.id] = regroupement }
    }

    public func tous() -> [RegroupementEvenement] {
        moteur.regroupements.values.sorted { $0.createdAt > $1.createdAt }
    }

    public func supprimer(_ id: UUID) {
        moteur.muter { $0.regroupements[id] = nil }
    }
}

/// Entrepôt des propositions de doublons et du journal de fusion.
public struct EntrepotDoublon: Sendable {

    let moteur: MoteurStockage

    public init(moteur: MoteurStockage) {
        self.moteur = moteur
    }

    public func enregistrer(_ proposition: PropositionDoublon) {
        moteur.muter { $0.enregistrerProposition(proposition) }
    }

    public func enAttente() -> [PropositionDoublon] {
        moteur.propositionsDoublon.values
            .filter { $0.statut == .propose }
            .sorted { $0.score > $1.score }
    }

    public func refusees() -> Set<PaireUUID> {
        Set(moteur.propositionsDoublon.values
            .filter { $0.statut == .refuse }
            .map { PaireUUID($0.idA, $0.idB) })
    }

    public func decider(_ id: UUID, statut: StatutDoublon, date: Date = Date()) {
        moteur.muter { $0.deciderProposition(id, statut: statut, date: date) }
    }

    public func journaliserFusion(_ entree: EntreeFusion) {
        moteur.muter { $0.enregistrerFusion(entree) }
    }

    public func journalFusions() -> [EntreeFusion] {
        moteur.journalFusions.sorted { $0.date > $1.date }
    }
}

/// Paire non ordonnée d'identifiants (une paire refusée n'est jamais reproposée).
public struct PaireUUID: Hashable, Sendable {
    public let a: UUID
    public let b: UUID

    public init(_ a: UUID, _ b: UUID) {
        self.a = a < b ? a : b
        self.b = a < b ? b : a
    }
}

/// Entrée du journal de fusion.
public struct EntreeFusion: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var entiteGardee: UUID
    public var entiteFusionnee: UUID
    public var champsChoisis: [String]
    public var date: Date

    public init(
        id: UUID = UUID(),
        entiteGardee: UUID,
        entiteFusionnee: UUID,
        champsChoisis: [String],
        date: Date = Date()
    ) {
        self.id = id
        self.entiteGardee = entiteGardee
        self.entiteFusionnee = entiteFusionnee
        self.champsChoisis = champsChoisis
        self.date = date
    }
}

/// Entrée du journal d'exécution d'une veille.
public struct ResultatJournal: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var veilleId: UUID
    public var date: Date
    public var succes: Bool
    public var nbNouveaux: Int
    public var message: String

    public init(
        id: UUID = UUID(),
        veilleId: UUID,
        date: Date,
        succes: Bool,
        nbNouveaux: Int,
        message: String
    ) {
        self.id = id
        self.veilleId = veilleId
        self.date = date
        self.succes = succes
        self.nbNouveaux = nbNouveaux
        self.message = message
    }
}
