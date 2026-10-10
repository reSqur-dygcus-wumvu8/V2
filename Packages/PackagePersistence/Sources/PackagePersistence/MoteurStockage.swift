import Foundation
import PackageDomain
import PackageMLA

/// Moteur de stockage MLA : jeu de travail en mémoire reconstruit à
/// l'ouverture (après déverrouillage), écritures dans un journal en
/// attente, consolidation des segments d'archive à la mise au repos.
///
/// Cycle : ouvrir(déverrouillage) → mutations via les entrepôts →
/// consolider() à chaque mise en arrière-plan / fermeture.
/// Aucune donnée n'est jamais déchiffrée sur disque : les archives MLA
/// sont déchiffrées en mémoire uniquement.
public final class MoteurStockage: @unchecked Sendable {

    // MARK: - Segments d'archive

    private enum Segment: String, CaseIterable {
        case entites, documents, veilles, elements, relations
        case regroupements, sources, journal, doublons, fusions, versions
    }

    // MARK: - Jeu de travail en mémoire

    private(set) var entites: [UUID: Entite] = [:]
    private(set) var documents: [UUID: Document] = [:]
    private(set) var veilles: [UUID: Veille] = [:]
    private(set) var elements: [UUID: ElementVeille] = [:]
    private(set) var relations: [RelationKey: RelationEntites] = [:]
    private(set) var regroupements: [UUID: RegroupementEvenement] = [:]
    private(set) var sources: [UUID: SourceInfo] = [:]
    private(set) var journalExecutions: [ResultatJournal] = []
    private(set) var propositionsDoublon: [UUID: PropositionDoublon] = [:]
    private(set) var journalFusions: [EntreeFusion] = []
    private(set) var versions: [UUID: [VersionEntite]] = [:]

    /// Index inversé plein texte (mots normalisés → identifiants d'entités).
    private var indexRecherche: [String: Set<UUID>] = [:]
    /// Index de hachage pour la déduplication des éléments de veille.
    private var hashElements: Set<String> = []

    private let archive: StockageMLA
    private let fileAttenteEcritures = DispatchQueue(label: "fr.osintsuite.moteur")

    /// - Parameters:
    ///   - dossier: répertoire des segments d'archive (conteneur app).
    ///   - phraseSecrete: matériel de clés de session délivré par le
    ///     Gestionnaire d'accès (jamais persisté par ce moteur).
    public init(dossier: URL, phraseSecrete: String) throws {
        self.archive = try ArchiveMLA(dossier: dossier, phraseSecrete: phraseSecrete)
        try charger()
    }

    // MARK: - Ouverture : déchiffrement en mémoire et reconstruction d'index

    private func charger() throws {
        entites = try chargerDictionnaire(.entites) ?? [:]
        documents = try chargerDictionnaire(.documents) ?? [:]
        veilles = try chargerDictionnaire(.veilles) ?? [:]
        elements = try chargerDictionnaire(.elements) ?? [:]
        regroupements = try chargerDictionnaire(.regroupements) ?? [:]
        sources = try chargerDictionnaire(.sources) ?? [:]
        propositionsDoublon = try chargerDictionnaire(.doublons) ?? [:]
        journalExecutions = try chargerListe(.journal) ?? []
        journalFusions = try chargerListe(.fusions) ?? []
        let relationsListe: [RelationEntites] = try chargerListe(.relations) ?? []
        relations = Dictionary(uniqueKeysWithValues: relationsListe.map { (RelationKey($0.id), $0) })
        let versionsListe: [VersionEntite] = try chargerListe(.versions) ?? []
        versions = Dictionary(grouping: versionsListe, by: \.entiteId)
            .mapValues { $0.sorted { $0.date > $1.date } }
        hashElements = Set(elements.values.map(\.hashContenu))
        reconstruireIndex()
    }

    private func chargerDictionnaire<V: Codable & Identifiable>(_ segment: Segment) throws -> [UUID: V]? where V.ID == UUID {
        guard let donnees = try archive.lire(segment: segment.rawValue) else { return nil }
        let valeurs = try JSONDecoder().decode([V].self, from: donnees)
        return Dictionary(uniqueKeysWithValues: valeurs.map { ($0.id, $0) })
    }

    private func chargerListe<V: Codable>(_ segment: Segment) throws -> [V]? {
        guard let donnees = try archive.lire(segment: segment.rawValue) else { return nil }
        return try JSONDecoder().decode([V].self, from: donnees)
    }

    /// Reconstruit l'index inversé plein texte sur les entités.
    private func reconstruireIndex() {
        indexRecherche.removeAll()
        for entite in entites.values {
            indexer(entite: entite)
        }
    }

    private func indexer(entite: Entite) {
        let textes = [entite.denomination, entite.resume ?? "", entite.biographie ?? "", entite.commentaires ?? ""]
        let mots = textes
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
        for mot in mots where mot.count > 2 {
            indexRecherche[mot, default: []].insert(entite.id)
        }
    }

    // MARK: - Consolidation : mise au repos dans les archives MLA

    /// Consolide toutes les collections dans les segments d'archive chiffrés.
    /// Appelé à chaque mise en arrière-plan et à la fermeture de session.
    public func consolider() throws {
        try ecrire(.entites, Array(entites.values))
        try ecrire(.documents, Array(documents.values))
        try ecrire(.veilles, Array(veilles.values))
        try ecrire(.elements, Array(elements.values))
        try ecrire(.relations, Array(relations.values))
        try ecrire(.regroupements, Array(regroupements.values))
        try ecrire(.sources, Array(sources.values))
        try ecrire(.journal, journalExecutions)
        try ecrire(.doublons, Array(propositionsDoublon.values))
        try ecrire(.fusions, journalFusions)
        try ecrire(.versions, versions.values.flatMap { $0 })
    }

    private func ecrire<V: Codable>(_ segment: Segment, _ valeurs: [V]) throws {
        let donnees = try JSONEncoder().encode(valeurs)
        try archive.ecrire(donnees, segment: segment.rawValue)
    }

    // MARK: - Panic wipe

    /// Effacement complet : destruction des segments d'archive (le matériel
    /// de clés étant détruit côté Gestionnaire d'accès, les données sont
    /// définitivement irrécupérables).
    public func panicWipe() throws {
        for segment in Segment.allCases {
            try archive.supprimer(segment: segment.rawValue)
        }
        entites.removeAll(); documents.removeAll(); veilles.removeAll()
        elements.removeAll(); relations.removeAll(); regroupements.removeAll()
        sources.removeAll(); journalExecutions.removeAll()
        propositionsDoublon.removeAll(); journalFusions.removeAll()
        versions.removeAll(); indexRecherche.removeAll(); hashElements.removeAll()
    }

    // MARK: - Mutations (thread-safe via la file d'écritures)

    func muter(_ bloc: @escaping (MoteurStockage) -> Void) {
        fileAttenteEcritures.sync { bloc(self) }
    }

    func enregistrerEntite(_ entite: Entite) {
        entites[entite.id] = entite
        indexer(entite: entite)
    }

    func supprimerEntite(_ id: UUID) {
        if var entite = entites[id] {
            entite.supprime = true
            entite.updatedAt = Date()
            entites[id] = entite
        }
    }

    func enregistrerDocument(_ document: Document) -> Bool {
        let dejaVu = documents.values.contains { $0.hashSHA256 == document.hashSHA256 }
        guard !dejaVu else { return false }
        documents[document.id] = document
        return true
    }

    func enregistrerElement(_ element: ElementVeille) -> Bool {
        guard !hashElements.contains(element.hashContenu) else { return false }
        elements[element.id] = element
        hashElements.insert(element.hashContenu)
        return true
    }

    func marquerElement(_ id: UUID, statut: StatutTraitement) {
        if var element = elements[id] {
            element.statut = statut
            elements[id] = element
        }
    }

    func enregistrerRelation(_ relation: RelationEntites) {
        relations[RelationKey(relation.id)] = relation
    }

    func relationsDe(_ id: UUID) -> [RelationEntites] {
        relations.values.filter { $0.idSource == id || $0.idCible == id }
    }

    func enregistrerJournal(_ entree: ResultatJournal) {
        journalExecutions.append(entree)
    }

    func enregistrerProposition(_ proposition: PropositionDoublon) {
        propositionsDoublon[proposition.id] = proposition
    }

    func deciderProposition(_ id: UUID, statut: StatutDoublon, date: Date) {
        if var p = propositionsDoublon[id] {
            p.statut = statut
            p.dateDecision = date
            propositionsDoublon[id] = p
        }
    }

    func enregistrerFusion(_ entree: EntreeFusion) {
        journalFusions.append(entree)
    }

    func enregistrerVersion(_ version: VersionEntite) {
        versions[version.entiteId, default: []].insert(version, at: 0)
    }

    // MARK: - Recherche

    /// Recherche plein texte sur les entités (index inversé normalisé FR).
    public func rechercher(texte: String) -> [Entite] {
        let mots = texte
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }
        guard !mots.isEmpty else { return [] }
        var resultats: Set<UUID>?
        for mot in mots {
            let correspondances = indexRecherche[mot] ?? []
            resultats = resultats.map { $0.intersection(correspondances) } ?? correspondances
        }
        return (resultats ?? []).compactMap { entites[$0] }.filter { !$0.supprime }
    }

    /// Hashes d'éléments déjà vus pour une veille (déduplication).
    public func hashesVus(veilleId: UUID) -> Set<String> {
        Set(elements.values.filter { $0.veilleId == veilleId }.map(\.hashContenu))
    }
}

/// Clé de relation pour le dictionnaire en mémoire.
struct RelationKey: Hashable {
    let id: UUID
    init(_ id: UUID) { self.id = id }
}
