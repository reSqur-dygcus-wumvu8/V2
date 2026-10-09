import SwiftUI
import PackageDomain
import PackagePersistence

/// File d'attente de la veille : éléments non traités, sélection multiple,
/// regroupement en événement avec cotation assistée.
public struct FileAttenteView: View {
    @StateObject private var modele: ModeleFileAttente

    public init(modele: ModeleFileAttente) {
        _modele = StateObject(wrappedValue: modele)
    }

    public var body: some View {
        List {
            Section("Éléments non traités — sélection pour regrouper") {
                ForEach(modele.elements) { element in
                    HStack {
                        Image(systemName: modele.selection.contains(element.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading) {
                            Text(element.titre).bold()
                            Text(element.url).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { modele.bascule(element) }
                }
            }
            if !modele.selection.isEmpty {
                Section("Regroupement") {
                    TextField("Titre de l'événement", text: $modele.titreRegroupement)
                    Button("Proposition de cotation (Mistral)") {
                        Task { await modele.proposerCotation() }
                    }
                    if let proposition = modele.proposition {
                        Text("Proposé : \(proposition.cotation.code) — \(proposition.justification)")
                            .font(.caption)
                        Picker("Cotation finale (décision humaine)", selection: $modele.cotationFinale) {
                            ForEach(FiabiliteSource.allCases, id: \.self) { f in
                                ForEach(CredibiliteInfo.allCases, id: \.self) { c in
                                    Text(CotationOTAN(fiabiliteSource: f, credibiliteInfo: c).code)
                                        .tag(CotationOTAN(fiabiliteSource: f, credibiliteInfo: c))
                                }
                            }
                        }
                    }
                    Button("Capitaliser vers la base de connaissance") {
                        Task { await modele.capitaliser() }
                    }
                    if let message = modele.message {
                        Text(message).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("File d'attente de la veille")
        .onAppear { modele.charger() }
    }
}

/// Modèle de vue de la file d'attente (MVVM).
@MainActor
public final class ModeleFileAttente: ObservableObject {
    @Published public var elements: [ElementVeille] = []
    @Published public var selection: Set<UUID> = []
    @Published public var titreRegroupement = ""
    @Published public var proposition: CotationOTAN.Proposition?
    @Published public var cotationFinale: CotationOTAN?
    @Published public var message: String?

    private let service: ServiceCapitalisation

    public init(service: ServiceCapitalisation) {
        self.service = service
    }

    /// Charge les éléments non traités.
    public func charger() {
        elements = (try? service.entrepotElements.fileAttente()) ?? []
    }

    /// Bascule la sélection d'un élément.
    public func bascule(_ element: ElementVeille) {
        if selection.contains(element.id) {
            selection.remove(element.id)
        } else {
            selection.insert(element.id)
        }
    }

    /// Demande au service une proposition de cotation pour la sélection.
    public func proposerCotation() async {
        let contenu = elements
            .filter { selection.contains($0.id) }
            .map { "\($0.titre) — \($0.contenu)" }
            .joined(separator: "\n\n")
        proposition = await service.proposerCotation(contenu: contenu)
        cotationFinale = proposition?.cotation
    }

    /// Capitalise la sélection en regroupement d'événement.
    public func capitaliser() async {
        guard !titreRegroupement.trimmingCharacters(in: .whitespaces).isEmpty else {
            message = "Titre obligatoire."
            return
        }
        let choisis = elements.filter { selection.contains($0.id) }
        do {
            var regroupement = try await service.creerRegroupement(titre: titreRegroupement, elements: choisis)
            if let cotation = cotationFinale {
                regroupement.cotation = cotation
                try service.entrepotRegroupement.enregistrer(regroupement)
            }
            message = "Regroupement capitalisé (\(choisis.count) élément(s))."
            selection = []
            titreRegroupement = ""
            proposition = nil
            cotationFinale = nil
            charger()
        } catch {
            message = "Erreur : \(error.localizedDescription)"
        }
    }
}
