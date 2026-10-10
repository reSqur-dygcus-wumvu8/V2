import SwiftUI
import UniformTypeIdentifiers
import PackageDomain
import PackagePersistence

/// Écran d'import de fichiers : bouton de sélection, glisser-déposer,
/// champs obligatoires (Nom, Date, Source, Cotation A–F).
public struct ImportView: View {
    @StateObject private var modele = ModeleImport()
    @State private var donneesFichier: Data?
    @State private var typeMime = "text/plain"

    public init() {}

    public var body: some View {
        Form {
            Section("Fichier") {
                HStack {
                    Button("Choisir un fichier…") { choisirFichier() }
                    Text(modele.nomFichier ?? "Aucun fichier sélectionné")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .disabled(donneesFichier != nil)
            }

            Section("Métadonnées obligatoires") {
                TextField("Nom", text: $modele.nom)
                DatePicker("Date", selection: $modele.date, displayedComponents: .date)
                TextField("Source (libellé)", text: $modele.sourceDenomination)
                Picker("Cotation source", selection: $modele.cotationSource) {
                    ForEach(FiabiliteSource.allCases, id: \.self) { grade in
                        Text("\(grade.rawValue) — \(grade.libelle)").tag(grade)
                    }
                }
            }

            Section {
                Button("Importer") {
                    if let donnees = donneesFichier {
                        modele.importer(donnees: donnees, typeMime: typeMime)
                    }
                }
                .disabled(donneesFichier == nil || !modele.champsValides)
                if let message = modele.message {
                    Text(message).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Importer")
        .dropDestination(for: Data.self) { items, _ in
            guard let donnees = items.first else { return false }
            donneesFichier = donnees
            return true
        }
    }

    private func choisirFichier() {
        let panneau = NSOpenPanel()
        panneau.allowsMultipleSelection = false
        panneau.canChooseDirectories = false
        panneau.canChooseFiles = true
        if panneau.runModal() == .OK, let url = panneau.url {
            chargerFichier(url: url)
        }
    }

    private func chargerFichier(url: URL) {
        do {
            donneesFichier = try Data(contentsOf: url)
            typeMime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            if modele.nom.isEmpty {
                modele.nom = url.deletingPathExtension().lastPathComponent
            }
            modele.nomFichier = url.lastPathComponent
        } catch {
            modele.message = "Lecture impossible : \(error.localizedDescription)"
        }
    }
}

#if canImport(AppKit)
import AppKit
typealias NSOpenPanel = NSOpenPanel
#endif

/// Modèle de vue de l'import (MVVM), testable sans interface graphique.
@MainActor
public final class ModeleImport: ObservableObject {
    @Published public var nom = ""
    @Published public var date = Date()
    @Published public var sourceDenomination = ""
    @Published public var cotationSource: FiabiliteSource = .c
    @Published public var message: String?
    @Published public var nomFichier: String?

    private let serviceImport: ServiceImport
    private let entrepotDocument: EntrepotDocument
    private let entrepotSource: EntrepotSource

    public init(
        serviceImport: ServiceImport = ServiceImport(),
        entrepotDocument: EntrepotDocument,
        entrepotSource: EntrepotSource
    ) {
        self.serviceImport = serviceImport
        self.entrepotDocument = entrepotDocument
        self.entrepotSource = entrepotSource
    }

    public var champsValides: Bool {
        !nom.trimmingCharacters(in: .whitespaces).isEmpty
            && !sourceDenomination.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public func importer(donnees: Data, typeMime: String) {
        guard champsValides else {
            message = "Nom et source sont obligatoires."
            return
        }
        do {
            let source = try obtenirOuCreerSource()
            let document = Document(
                nom: nom,
                dateImport: date,
                typeMime: typeMime,
                hashSHA256: ServiceImport.hashFichier(donnees),
                texteExtrait: ServiceImport.extraireTexte(donnees: donnees, typeMime: typeMime),
                cotation: CotationOTAN(fiabiliteSource: cotationSource, credibiliteInfo: .nePeutEtreJugee),
                sourceId: source.id
            )
            let insere = entrepotDocument.inserer(document)
            message = insere ? "Document importé." : "Doublon : fichier déjà importé (hash identique)."
        } catch {
            message = "Erreur d'import : \(error.localizedDescription)"
        }
    }

    private func obtenirOuCreerSource() throws -> SourceInfo {
        let denomination = sourceDenomination.trimmingCharacters(in: .whitespaces)
        if let existante = entrepotSource.chercher(denomination: denomination) {
            return existante
        }
        let nouvelle = SourceInfo(denomination: denomination, cotation: cotationSource)
        entrepotSource.enregistrer(nouvelle)
        return nouvelle
    }
}
