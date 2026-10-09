import SwiftUI
import PackageDomain
import PackagePersistence

/// Base de connaissance : liste des entités par type, recherche,
/// création de fiche avec complétion automatique proposée à validation.
public struct BaseConnaissanceView: View {
    @StateObject private var modele: ModeleBaseConnaissance

    public init(modele: ModeleBaseConnaissance) {
        _modele = StateObject(wrappedValue: modele)
    }

    public var body: some View {
        List {
            Section {
                TextField("Recherche", text: $modele.recherche)
                    .textFieldStyle(.roundedBorder)
            }
            ForEach(TypeEntite.allCases) { type in
                let entites = modele.entitesFiltrees(type: type)
                if !entites.isEmpty {
                    Section(type.libelle) {
                        ForEach(entites) { entite in
                            NavigationLink(value: entite.id) {
                                VStack(alignment: .leading) {
                                    Text(entite.denomination).bold()
                                    if let resume = entite.resume, !resume.isEmpty {
                                        Text(resume).font(.caption).lineLimit(1).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Base de connaissance")
        .onAppear { modele.charger() }
        .searchable(text: $modele.recherche)
    }
}

/// Modèle de vue de la base de connaissance (MVVM).
@MainActor
public final class ModeleBaseConnaissance: ObservableObject {
    @Published public var entites: [Entite] = []
    @Published public var recherche = ""

    private let entrepot: EntrepotEntite

    public init(entrepot: EntrepotEntite) {
        self.entrepot = entrepot
    }

    /// Charge toutes les entités non supprimées.
    public func charger() {
        entites = (try? entrepot.toutes()) ?? []
    }

    /// Entités d'un type filtrées par la recherche.
    public func entitesFiltrees(type: TypeEntite) -> [Entite] {
        let duType = entites.filter { $0.type == type }
        guard !recherche.trimmingCharacters(in: .whitespaces).isEmpty else { return duType }
        let terme = recherche.trimmingCharacters(in: .whitespaces)
        return duType.filter {
            $0.denomination.localizedCaseInsensitiveContains(terme)
                || ($0.resume ?? "").localizedCaseInsensitiveContains(terme)
        }
    }
}

/// Fiche d'une entité : tous les champs éditables à la main, historique,
/// informations liées avec sources et cotations, accès direct à Exploiter.
public struct FicheEntiteView: View {
    @StateObject private var modele: ModeleFicheEntite

    public init(modele: ModeleFicheEntite) {
        _modele = StateObject(wrappedValue: modele)
    }

    public var body: some View {
        Form {
            Section("Identité") {
                TextField("Dénomination", text: $modele.denomination)
                if modele.type == .individu {
                    TextField("Prénom", text: $modele.prenom)
                    TextField("Nom", text: $modele.nom)
                }
                if modele.type == .organisation {
                    TextField("Type d'organisation", text: $modele.typeOrganisation)
                }
                if modele.type == .objet {
                    TextField("Type d'objet", text: $modele.typeObjet)
                    TextField("Précisions (immatriculation, n° série…)", text: $modele.precisions, axis: .vertical)
                }
                if modele.type == .evenement {
                    DatePicker("Date et heure", selection: $modele.dateHeure)
                }
                if modele.type == .lieu {
                    TextField("Adresse", text: $modele.adresse)
                    TextField("Coordonnées GPS (lat, lon)", text: $modele.coordonneesGPS)
                }
                if modele.type == .source {
                    Picker("Cotation", selection: $modele.cotationSource) {
                        Text("—").tag(FiabiliteSource?.none)
                        ForEach(FiabiliteSource.allCases, id: \.self) { f in
                            Text("\(f.rawValue) — \(f.libelle)").tag(FiabiliteSource?.some(f))
                        }
                    }
                }
            }

            Section("Contenu") {
                if modele.type == .individu {
                    TextField("Biographie", text: $modele.biographie, axis: .vertical)
                } else if modele.type == .evenement {
                    TextField("Résumé de l'événement", text: $modele.resume, axis: .vertical)
                } else {
                    TextField("Synthèse / résumé", text: $modele.resume, axis: .vertical)
                }
                TextField("Commentaires", text: $modele.commentaires, axis: .vertical)
            }

            Section("Liens") {
                ForEach(modele.relations) { relation in
                    LigneRelation(relation: relation, denomination: modele.denominationRelation(relation))
                }
            }

            Section("Historique des modifications") {
                ForEach(modele.historique) { version in
                    VStack(alignment: .leading) {
                        Text(version.date, style: .date)
                        Text("Champs : \(version.champsModifies.joined(separator: ", "))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button("Enregistrer") { modele.enregistrer() }
            }
        }
        .navigationTitle(modele.denomination.isEmpty ? "Fiche" : modele.denomination)
        .toolbar {
            Menu("Exploiter") {
                Button("Graphe relationnel") { modele.ouvrirExploiter(.graphe) }
                Button("Frise chronologique") { modele.ouvrirExploiter(.frise) }
                if modele.type == .lieu { Button("Carte") { modele.ouvrirExploiter(.carte) } }
            }
        }
    }
}

struct LigneRelation: View {
    let relation: RelationEntites
    let denomination: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(denomination)
            if let cotation = relation.cotation {
                Text("Cotation \(cotation.code)").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// Destination dans le module Exploiter depuis une fiche.
public enum DestinationExploiter: Hashable {
    case graphe
    case frise
    case carte
}

/// Modèle de vue d'une fiche (MVVM), testable sans interface graphique.
@MainActor
public final class ModeleFicheEntite: ObservableObject {
    @Published public var denomination = ""
    @Published public var prenom = ""
    @Published public var nom = ""
    @Published public var typeOrganisation = ""
    @Published public var typeObjet = ""
    @Published public var precisions = ""
    @Published public var dateHeure = Date()
    @Published public var adresse = ""
    @Published public var coordonneesGPS = ""
    @Published public var resume = ""
    @Published public var biographie = ""
    @Published public var commentaires = ""
    @Published public var cotationSource: FiabiliteSource?
    @Published public var relations: [RelationEntites] = []
    @Published public var historique: [VersionEntite] = []
    @Published public var destinationExploiter: DestinationExploiter?

    public let id: UUID
    public let type: TypeEntite
    private let entrepot: EntrepotEntite
    private let appareil: String

    public init(entite: Entite, entrepot: EntrepotEntite, appareil: String = "Mac") {
        self.id = entite.id
        self.type = entite.type
        self.entrepot = entrepot
        self.appareil = appareil
        denomination = entite.denomination
        prenom = entite.prenom ?? ""
        nom = entite.nom ?? ""
        typeOrganisation = entite.typeOrganisation ?? ""
        typeObjet = entite.typeObjet ?? ""
        precisions = entite.precisions ?? ""
        dateHeure = entite.dateHeure ?? Date()
        adresse = entite.adresse ?? ""
        if let lat = entite.latitude, let lon = entite.longitude {
            coordonneesGPS = "\(lat), \(lon)"
        }
        resume = entite.resume ?? ""
        biographie = entite.biographie ?? ""
        commentaires = entite.commentaires ?? ""
        cotationSource = entite.cotationSource
        relations = (try? entrepot.relations(id: entite.id)) ?? []
        historique = (try? entrepot.historique(entiteId: entite.id)) ?? []
    }

    /// Dénomination de l'autre extrémité d'une relation.
    public func denominationRelation(_ relation: RelationEntites) -> String {
        let autreId = relation.idSource == id ? relation.idCible : relation.idSource
        let autre = try? entrepot.chercher(id: autreId)
        return autre?.denomination ?? "Entité supprimée"
    }

    /// Enregistre la fiche et journalise les champs modifiés.
    public func enregistrer() {
        guard var entite = try? entrepot.chercher(id: id) else { return }
        var champsModifies: [String] = []
        if entite.denomination != denomination { champsModifies.append("denomination"); entite.denomination = denomination }
        if (entite.prenom ?? "") != prenom { champsModifies.append("prenom"); entite.prenom = prenom.isEmpty ? nil : prenom }
        if (entite.nom ?? "") != nom { champsModifies.append("nom"); entite.nom = nom.isEmpty ? nil : nom }
        if (entite.typeOrganisation ?? "") != typeOrganisation { champsModifies.append("typeOrganisation"); entite.typeOrganisation = typeOrganisation.isEmpty ? nil : typeOrganisation }
        if (entite.typeObjet ?? "") != typeObjet { champsModifies.append("typeObjet"); entite.typeObjet = typeObjet.isEmpty ? nil : typeObjet }
        if (entite.precisions ?? "") != precisions { champsModifies.append("precisions"); entite.precisions = precisions.isEmpty ? nil : precisions }
        if entite.dateHeure != dateHeure { champsModifies.append("dateHeure"); entite.dateHeure = dateHeure }
        if (entite.adresse ?? "") != adresse { champsModifies.append("adresse"); entite.adresse = adresse.isEmpty ? nil : adresse }
        if (entite.resume ?? "") != resume { champsModifies.append("resume"); entite.resume = resume.isEmpty ? nil : resume }
        if (entite.biographie ?? "") != biographie { champsModifies.append("biographie"); entite.biographie = biographie.isEmpty ? nil : biographie }
        if (entite.commentaires ?? "") != commentaires { champsModifies.append("commentaires"); entite.commentaires = commentaires.isEmpty ? nil : commentaires }
        if entite.cotationSource != cotationSource { champsModifies.append("cotationSource"); entite.cotationSource = cotationSource }
        if let (lat, lon) = Self.parserGPS(coordonneesGPS) {
            if entite.latitude != lat || entite.longitude != lon {
                champsModifies.append("coordonneesGPS")
                entite.latitude = lat
                entite.longitude = lon
            }
        }
        entite.updatedAt = Date()
        try? entrepot.enregistrer(entite)
        if !champsModifies.isEmpty {
            try? entrepot.journaliser(
                VersionEntite(entiteId: id, champsModifies: champsModifies, appareil: appareil)
            )
        }
        historique = (try? entrepot.historique(entiteId: id)) ?? []
    }

    /// Demande d'ouverture d'un élément du module Exploiter.
    public func ouvrirExploiter(_ destination: DestinationExploiter) {
        destinationExploiter = destination
    }

    /// Analyse "lat, lon" en couple de coordonnées.
    static func parserGPS(_ texte: String) -> (Double, Double)? {
        let parties = texte.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parties.count == 2, let lat = Double(parties[0]), let lon = Double(parties[1]) else { return nil }
        return (lat, lon)
    }
}
