import Foundation
import PackageDomain
import PackageNetworking
import PackagePersistence
import PackageTor

/// Collecteur Mac hub : passe périodique sur les veilles actives via Tor
/// et insère les nouveaux éléments dans le stockage MLA local. Lancé par
/// le LaunchAgent com.osintsuite.collecteur (15 min).
///
/// Usage : Collecteur <dossier-mla> <phrase-secrete>
/// (phrase de session délivrée par le Gestionnaire d'accès, jamais stockée
/// en clair sur disque).
let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("Usage: Collecteur <dossier-mla> <phrase-secrete>\n".utf8))
    exit(1)
}

let dossierMLA = URL(fileURLWithPath: arguments[1])
let phraseSecrete = arguments[2]

 Task {
    do {
        let moteur = try MoteurStockage(dossier: dossierMLA, phraseSecrete: phraseSecrete)
        let entrepotVeille = EntrepotVeille(moteur: moteur)
        let entrepotElements = EntrepotElementVeille(moteur: moteur)

        // Toutes les requêtes passent par Tor (Arti embarqué).
        let reseau = ReseauTor(client: ClientTor())
        try await reseau.preparer()
        let orchestrateur = OrchestrateurVeille(reseau: reseau)

        let veillesActives = entrepotVeille.actives()
        var total = 0
        for veille in veillesActives {
            let hashes = entrepotElements.hashesVus(veilleId: veille.id)
            let resultat = await orchestrateur.executer(veille: veille, hashesVus: hashes)
            let inseres = entrepotElements.insererNouveaux(resultat.nouveauxElements)
            entrepotVeille.journaliser(
                ResultatJournal(
                    veilleId: veille.id,
                    date: resultat.date,
                    succes: resultat.succes,
                    nbNouveaux: inseres.count,
                    message: resultat.message
                )
            )
            total += inseres.count
        }
        // Mise au repos des archives MLA.
        try moteur.consolider()
        print("Collecteur : \(total) nouvel(s) élément(s) sur \(veillesActives.count) veille(s).")
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("Erreur collecteur : \(error)\n".utf8))
        exit(1)
    }
}
