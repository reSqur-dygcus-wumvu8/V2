import Foundation
import CryptoKit
import PackageDomain
import PackagePersistence

/// Service d'import de fichiers : hash SHA-256 anti-doublon, extraction
/// de texte (TXT, Markdown, HTML), copie chiffrée du binaire à venir (Étape 6).
public struct ServiceImport: Sendable {

    public init() {}

    /// Hash SHA-256 hexadécimal d'un fichier (détection de doublon d'import).
    public static func hashFichier(_ donnees: Data) -> String {
        let digest = SHA256.hash(data: donnees)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Extrait le texte d'un fichier selon son type : TXT/MD renvoyés tels quels,
    /// HTML débarrassé des balises ; PDF/images (OCR) à venir.
    public static func extraireTexte(donnees: Data, typeMime: String) -> String {
        switch typeMime {
        case "text/plain", "text/markdown", "text/x-markdown":
            return String(data: donnees, encoding: .utf8) ?? ""
        case "text/html", "application/xhtml+xml":
            guard let html = String(data: donnees, encoding: .utf8) else { return "" }
            return Self.texteDepuisHTML(html)
        default:
            // PDF, images, audio/vidéo : extraction/OCR à venir.
            return ""
        }
    }

    /// Retire les balises HTML et les entités courantes.
    static func texteDepuisHTML(_ html: String) -> String {
        var texte = html
        // Retire script et style.
        for balise in ["script", "style", "head"] {
            while let debut = texte.range(of: "<\(balise)"),
                  let fin = texte.range(of: "</\(balise)>", range: debut.upperBound..<texte.endIndex) {
                texte.removeSubrange(debut.lowerBound..<fin.upperBound)
            }
        }
        texte = texte.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        texte = texte
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        return texte
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
