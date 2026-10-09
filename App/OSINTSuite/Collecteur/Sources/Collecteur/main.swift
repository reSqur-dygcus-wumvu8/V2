import Foundation
import GRDB
import PackageDomain
import PackageNetworking
import PackagePersistence

/// Collecteur Mac hub : passe périodique sur les veilles actives et insère
/// les nouveaux éléments dans la base chiffrée locale. Lancé par le
/// LaunchAgent com.osintsuite.collecteur (StartIntervalInsec 900 = 15 min).
///
/// Usage : Collecteur <chemin-base> <passphrase-dek-b64>
/// (passphrase fournie par l'application principale au moment du
/// déverrouillage, jamais stockée en clair sur disque).
let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("Usage: Collecteur <chemin-base> <passphrase-b64>\n".utf8))
    exit(1)
}

let cheminBase = arguments[1]
let passphrase = String(data: Data(base64Encoded: arguments[2]) ?? Data(), encoding: .utf8) ?? arguments[2]

do {
    let base = try BaseDonneesService(cheminBase: cheminBase, passphrase: passphrase)
    let entrepotVeille = EntrepotVeille(pool: base.pool)
    let entrepotElements = EntrepotElementVeille(pool: base.pool)
    let orchestrateur = OrchestrateurVeille()

    let veillesActives = try entrepotVeille.actives()
    var total = 0
    for veille in veillesActives {
        let hashes = try entrepotElements.hashesVus(veilleId: veille.id)
        let resultat = await orchestrateur.executer(veille: veille, hashesVus: hashes)
        let inseres = try entrepotElements.insererNouveaux(resultat.nouveauxElements)
        try entrepotVeille.journaliser(
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
    print("Collecteur : \(total) nouvel(s) élément(s) sur \(veillesActives.count) veille(s).")
} catch {
    FileHandle.standardError.write(Data("Erreur collecteur : \(error)\n".utf8))
    exit(1)
}
