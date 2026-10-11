import Foundation
import PackageDomain
import PackageNetworking
import PackagePersistence
import PackageTor

/// Collecteur Mac hub : passe périodique sur les veilles actives via Tor
/// et insère les nouveaux éléments dans le stockage MLA local. Lancé par
/// le LaunchAgent com.osintsuite.collecteur (15 min).
///
/// Usage : Collecteur <dossier-mla>
/// La phrase de session est lue dans le trousseau (entrée « phrase-collecteur »
/// du service com.osintsuite.secrets, écrite par l'app macOS à l'installation)
/// — jamais passée en argument ni stockée en clair sur disque.
let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: Collecteur <dossier-mla>\n".utf8))
    exit(1)
}

let dossierMLA = URL(fileURLWithPath: arguments[1])
guard let donneesPhrase = try? KeychainStore().lire(cle: "phrase-collecteur"),
      let phraseSecrete = String(data: donneesPhrase, encoding: .utf8),
      !phraseSecrete.isEmpty else {
    FileHandle.standardError.write(Data("Collecteur : phrase de session absente du trousseau (installer via l'app macOS).\n".utf8))
    exit(1)
}

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
