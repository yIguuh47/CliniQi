//
//  EMEBrand.swift
//  CliniQi
//

import SwiftUI

enum PDFPageMetrics {
    static let a4 = CGSize(width: 595, height: 842)
}

enum EMEBrand {
    static let name = "e m e concept"

    static let sand = Color(red: 237 / 255, green: 229 / 255, blue: 222 / 255)
    static let paper = Color(red: 255 / 255, green: 251 / 255, blue: 247 / 255)
    static let taupe = Color(red: 195 / 255, green: 169 / 255, blue: 153 / 255)
    static let taupeBox = Color(red: 205 / 255, green: 189 / 255, blue: 172 / 255)
    static let ink = Color(red: 111 / 255, green: 99 / 255, blue: 90 / 255)
    static let muted = Color(red: 154 / 255, green: 139 / 255, blue: 126 / 255)
    static let watermark = Color(red: 232 / 255, green: 213 / 255, blue: 200 / 255)
    static let cream = Color(red: 250 / 255, green: 244 / 255, blue: 233 / 255)

    static func didot(_ size: CGFloat) -> Font {
        .custom("Didot", size: size)
    }

    static func sans(_ size: CGFloat, weight: SansWeight = .regular) -> Font {
        .custom(weight.postScriptName, size: size)
    }

    static func script(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "SnellRoundhand-Bold" : "SnellRoundhand", size: size)
    }

    enum SansWeight {
        case ultraLight, regular, italic, medium, demiBold, bold

        var postScriptName: String {
            switch self {
            case .ultraLight: "AvenirNext-UltraLight"
            case .regular: "AvenirNext-Regular"
            case .italic: "AvenirNext-Italic"
            case .medium: "AvenirNext-Medium"
            case .demiBold: "AvenirNext-DemiBold"
            case .bold: "AvenirNext-Bold"
            }
        }
    }
}

enum FileNameSanitizer {
    static func sanitize(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Orcamento" }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mapped = trimmed.map { character -> Character in
            character == " " ? "_" : character
        }

        let cleaned = String(mapped).unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "_"
        }

        let compact = String(cleaned)
            .replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        return compact.isEmpty ? "Orcamento" : compact
    }
}
