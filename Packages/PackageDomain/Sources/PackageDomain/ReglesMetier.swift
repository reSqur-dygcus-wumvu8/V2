import Foundation

/// Règles métier pures : cotations, doublons, priorités de veille.
/// Aucune dépendance externe ; entièrement testable sans interface graphique.
public enum ReglesMetier {

    /// Calcule un score de priorité d'un élément de veille (0–100) à partir
    /// de la cotation de sa source et de la présence de mots-clés de priorité.
    /// - Fiabilité A/B : bonus fort ; E/F : malus.
    /// - Mot-clé de priorité présent dans le titre : +30, dans le contenu : +10.
    public static func scorePriorite(
        element: ElementVeille,
        veille: Veille
    ) -> Int {
        var score = 50
        switch element.cotationSource {
        case .a, .b: score += 20
        case .c: score += 5
        case .d: score -= 10
        case .e, .f: score -= 20
        case nil: break
        }
        let titreMinuscule = element.titre.lowercased()
        let contenuMinuscule = element.contenu.lowercased()
        for mot in veille.motsClesPriorite where !mot.isEmpty {
            let motMinuscule = mot.lowercased()
            if titreMinuscule.contains(motMinuscule) {
                score += 30
                break
            } else if contenuMinuscule.contains(motMinuscule) {
                score += 10
            }
        }
        return max(0, min(100, score))
    }

    /// Indique si un élément de veille mérite une alerte (notification locale)
    /// selon le seuil de score configuré.
    public static func doitAlerter(score: Int, seuil: Int = 70) -> Bool {
        score >= seuil
    }

    /// Similarité de Jaccard entre deux textes découpés en mots (0–1).
    /// Utilisée comme première passe de détection de doublons, complétée
    /// par les embeddings côté Intelligence.
    public static func similariteJaccard(_ a: String, _ b: String) -> Double {
        let motsA = Set(ReglesMetier.motsNormalises(a))
        let motsB = Set(ReglesMetier.motsNormalises(b))
        guard !motsA.isEmpty, !motsB.isEmpty else { return 0 }
        let intersection = motsA.intersection(motsB).count
        let union = motsA.union(motsB).count
        return Double(intersection) / Double(union)
    }

    /// Normalise une chaîne pour comparaison : minuscules, sans accents,
    /// sans ponctuation, espaces resserrés.
    public static func normaliser(_ texte: String) -> String {
        texte
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }

    private static func motsNormalises(_ texte: String) -> [String] {
        normaliser(texte).components(separatedBy: " ").filter { !$0.isEmpty }
    }
}
