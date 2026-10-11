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
        let texteObjet = try document.putObject(obj: ObjId.ROOT, key: "contenu", ty: .Text)
        try document.updateText(obj: texteObjet, value: texte)
        return document.save()
    }

    /// Applique un delta distant (bytes Automerge) sur l'état local :
    /// fusion sans conflit des modifications concurrentes.
    public func fusionner(etatLocal: inout Data, delta: Data) throws {
        let documentLocal = try Document(etatLocal)
        let documentDistant = try Document(delta)
        try documentLocal.merge(other: documentDistant)
        etatLocal = documentLocal.save()
    }

    /// Extrait le texte courant du document fusionné.
    public func texteCourant(etat: Data) throws -> String {
        let document = try Document(etat)
        guard let valeur = try document.get(obj: ObjId.ROOT, key: "contenu"),
              case .Object(let objet, _) = valeur else {
            return ""
        }
        return try document.text(obj: objet)
    }

    /// Applique une modification locale (texte complet) sur l'état du document.
    public func appliquerModification(etat: inout Data, texte: String) throws {
        let document = try Document(etat)
        if let valeur = try document.get(obj: ObjId.ROOT, key: "contenu"),
           case .Object(let objet, _) = valeur {
            try document.updateText(obj: objet, value: texte)
        } else {
            let objet = try document.putObject(obj: ObjId.ROOT, key: "contenu", ty: .Text)
            try document.updateText(obj: objet, value: texte)
        }
        etat = document.save()
    }
}
