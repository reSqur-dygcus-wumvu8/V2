import Foundation

/// Fiabilité de la source selon la nomenclature OTAN (Admiralty Code), de A à F.
public enum FiabiliteSource: String, CaseIterable, Codable, Sendable, Comparable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case e = "E"
    case f = "F"

    /// Libellé complet du grade.
    public var libelle: String {
        switch self {
        case .a: return "Totalement fiable"
        case .b: return "Habituellement fiable"
        case .c: return "Assez fiable"
        case .d: return "Habituellement peu fiable"
        case .e: return "Peu fiable"
        case .f: return "Ne peut être jugée"
        }
    }

    /// Rang de fiabilité croissant (A < B < ... < F) pour les tris et filtres.
    public var rang: Int { FiabiliteSource.allCases.firstIndex(of: self)! + 1 }

    public static func < (lhs: FiabiliteSource, rhs: FiabiliteSource) -> Bool {
        lhs.rang < rhs.rang
    }
}

/// Crédibilité de l'information selon la nomenclature OTAN, de 1 à 6.
public enum CredibiliteInfo: Int, CaseIterable, Codable, Sendable, Comparable {
    case confirmee = 1
    case probablementVraie = 2
    case possiblementVraie = 3
    case douteuse = 4
    case improbable = 5
    case nePeutEtreJugee = 6

    /// Libellé complet du grade.
    public var libelle: String {
        switch self {
        case .confirmee: return "Confirmée par d'autres sources"
        case .probablementVraie: return "Probablement vraie"
        case .possiblementVraie: return "Possiblement vraie"
        case .douteuse: return "Douteuse"
        case .improbable: return "Improbable"
        case .nePeutEtreJugee: return "Ne peut être jugée"
        }
    }

    public static func < (lhs: CredibiliteInfo, rhs: CredibiliteInfo) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Cotation composite OTAN d'une information : source (A–F) + information (1–6).
public struct CotationOTAN: Codable, Sendable, Equatable, Hashable {
    public let fiabiliteSource: FiabiliteSource
    public let credibiliteInfo: CredibiliteInfo

    public init(fiabiliteSource: FiabiliteSource, credibiliteInfo: CredibiliteInfo) {
        self.fiabiliteSource = fiabiliteSource
        self.credibiliteInfo = credibiliteInfo
    }

    /// Affichage composite, ex. "A1", "C3".
    public var code: String {
        "\(fiabiliteSource.rawValue)\(credibiliteInfo.rawValue)"
    }

    /// Analyse d'un code composite saisi par l'utilisateur, ex. "a1" ou "C3".
    public static func depuis(code: String) -> CotationOTAN? {
        let caracteres = code.trimmingCharacters(in: .whitespaces)
        guard caracteres.count == 2,
              let lettre = caracteres.first?.uppercased(),
              let chiffre = caracteres.last.flatMap(String.init).flatMap(Int.init),
              let fiabilite = FiabiliteSource(rawValue: lettre),
              let credibilite = CredibiliteInfo(rawValue: chiffre) else { return nil }
        return CotationOTAN(fiabiliteSource: fiabilite, credibiliteInfo: credibilite)
    }

    /// Position ordinale pour les tris et les filtres « cotation minimale ».
    public var ordinal: Int { fiabiliteSource.rang * 10 + credibiliteInfo.rawValue }
}
