import Foundation
import PackageMLA

/// Stockage des binaires importés (PDF, images, audio/vidéo) : chaque
/// binaire est une archive MLA dédiée blobs/<uuid>.mla, chargée à la
/// demande — la RAM du moteur ne porte que les métadonnées.
public struct EntrepotBlobs: Sendable {

    private let dossierBlobs: URL
    private let archive: ArchiveMLA

    public init(dossierConteneur: URL, phraseSecrete: String) throws {
        self.dossierBlobs = dossierConteneur.appendingPathComponent("blobs", isDirectory: true)
        try FileManager.default.createDirectory(at: dossierBlobs, withIntermediateDirectories: true)
        self.archive = try ArchiveMLA(dossier: dossierBlobs, phraseSecrete: phraseSecrete)
    }

    /// Enregistre un binaire sous un identifiant donné.
    public func enregistrer(_ donnees: Data, id: UUID) throws {
        try archive.ecrire(donnees, segment: id.uuidString)
    }

    /// Charge un binaire à la demande (nil si absent).
    public func charger(id: UUID) throws -> Data? {
        try archive.lire(segment: id.uuidString)
    }

    /// Supprime un binaire.
    public func supprimer(id: UUID) throws {
        try archive.supprimer(segment: id.uuidString)
    }

    /// Identifiants des binaires stockés.
    public func tous() throws -> [UUID] {
        try archive.segments().compactMap(UUID.init(uuidString:))
    }

    /// Panic wipe : destruction de tous les binaires chiffrés.
    public func toutSupprimer() throws {
        for id in try tous() {
            try archive.supprimer(segment: id.uuidString)
        }
    }
}
