import Foundation
import Automerge

/// Fusion CRDT des documents texte (biographies, synthèses, commentaires) :
/// Automerge garantit une fusion sans conflit ni perte — jamais
/// « dernier écrit gagnant ». Chaque appareil applique les deltas reçus
/// sur son document local ; les modifications concurrentes fusionnent.
public struct FusionCRDT: Sendable {

    public init() {}

    /// Crée un document Automerge depuis un texte initial.
    public func creerDocument(texte: String) throws -> Data {
        let document = try Document()
        let texte = try TextInDocument(text: texte)
        _ = try document.set(texte, path: "contenu")
        return try document.export()
    }

    /// Applique un delta distant (bytes Automerge) sur l'état local :
    /// fusion sans conflit des modifications concurrentes.
    public func fusionner(etatLocal: inout Data, delta: Data) throws {
        let documentLocal = try Document(etatLocal)
        let documentDistant = try Document(delta)
        try documentLocal.merge(&documentDistant)
        etatLocal = try documentLocal.export()
    }

    /// Extrait le texte courant du document fusionné.
    public func texteCourant(etat: Data) throws -> String {
        let document = try Document(etat)
        guard let texte = try document.get(path: "contenu") as? TextInDocument else {
            return ""
        }
        return texte.description
    }

    /// Applique une modification locale (insertion) sur l'état du document.
    public func appliquerModification(etat: inout Data, texte: String) throws {
        let document = try Document(etat)
        if var texteDoc = try document.get(path: "contenu") as? TextInDocument {
            try texteDoc.update(newText: texte)
            etat = try document.export()
        } else {
            let texteDoc = try TextInDocument(text: texte)
            _ = try document.set(texteDoc, path: "contenu")
            etat = try document.export()
        }
    }
}
