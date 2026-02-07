//
//  TonicThemeTokens.swift
//  Tonic
//
//  Immersive theme token pack for Smart Scan and manager experiences.
//

import SwiftUI
import AppKit

// MARK: - Appearance Helpers

enum TonicAppearanceMode: Sendable {
    case dark
    case light

    init(_ colorScheme: ColorScheme) {
        switch colorScheme {
        case .dark:
            self = .dark
        default:
            self = .light
        }
    }
}

private struct TonicSRGB {
    let r: Double
    let g: Double
    let b: Double

    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&int)
        switch sanitized.count {
        case 3:
            self.r = Double((int >> 8) * 17) / 255.0
            self.g = Double((int >> 4 & 0xF) * 17) / 255.0
            self.b = Double((int & 0xF) * 17) / 255.0
        case 6:
            self.r = Double(int >> 16) / 255.0
            self.g = Double(int >> 8 & 0xFF) / 255.0
            self.b = Double(int & 0xFF) / 255.0
        default:
            self.r = 0
            self.g = 0
            self.b = 0
        }
    }

    func blended(with other: TonicSRGB, weight: Double) -> TonicSRGB {
        let clamped = min(max(weight, 0), 1)
        return TonicSRGB(
            r: r * (1 - clamped) + other.r * clamped,
            g: g * (1 - clamped) + other.g * clamped,
            b: b * (1 - clamped) + other.b * clamped
        )
    }

    private init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    func toNSColor(alpha: Double = 1) -> NSColor {
        NSColor(
            calibratedRed: r,
            green: g,
            blue: b,
            alpha: min(max(alpha, 0), 1)
        )
    }
}

private extension Color {
    static func tonicDynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? dark : light
        })
    }

    static func tonicDynamic(lightHex: String, darkHex: String, lightAlpha: Double = 1, darkAlpha: Double = 1) -> Color {
        tonicDynamic(
            light: TonicSRGB(hex: lightHex).toNSColor(alpha: lightAlpha),
            dark: TonicSRGB(hex: darkHex).toNSColor(alpha: darkAlpha)
        )
    }
}

// MARK: - World Colors

struct TonicWorldModeColorToken: Sendable {
    let darkHex: String
    let midHex: String
    let lightHex: String
}

struct TonicWorldColorToken: Sendable {
    let darkMode: TonicWorldModeColorToken
    let lightMode: TonicWorldModeColorToken

    func token(for mode: TonicAppearanceMode) -> TonicWorldModeColorToken {
        mode == .dark ? darkMode : lightMode
    }

    var dark: Color {
        Color.tonicDynamic(lightHex: lightMode.darkHex, darkHex: darkMode.darkHex)
    }

    var mid: Color {
        Color.tonicDynamic(lightHex: lightMode.midHex, darkHex: darkMode.midHex)
    }

    var light: Color {
        Color.tonicDynamic(lightHex: lightMode.lightHex, darkHex: darkMode.lightHex)
    }
}

enum TonicWorld: String, CaseIterable, Identifiable, Sendable {
    case smartScanPurple
    case cleanupGreen
    case clutterTeal
    case applicationsBlue
    case performanceOrange
    case protectionMagenta

    var id: String { rawValue }

    var token: TonicWorldColorToken {
        let palette = AppearancePreferences.shared.colorPalette
        return palette.worldToken(for: self)
    }

    /// The original default purple palette colors, used as the canonical fallback.
    var defaultToken: TonicWorldColorToken {
        TonicColorPalette.defaultPurple.worldToken(for: self)
    }
}

// MARK: - Color Palette

public enum TonicColorPalette: String, CaseIterable, Identifiable, Sendable {
    case defaultPurple
    case ocean
    case sunset
    case forest
    case lavender
    case midnight
    case roseGold
    case arctic

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .defaultPurple: return "Default Purple"
        case .ocean: return "Ocean"
        case .sunset: return "Sunset"
        case .forest: return "Forest"
        case .lavender: return "Lavender"
        case .midnight: return "Midnight"
        case .roseGold: return "Rose Gold"
        case .arctic: return "Arctic"
        }
    }

    var mood: String {
        switch self {
        case .defaultPurple: return "Creative, focused, modern"
        case .ocean: return "Cool, professional, trustworthy"
        case .sunset: return "Warm, energetic, optimistic"
        case .forest: return "Natural, grounding, serene"
        case .lavender: return "Elegant, calm, contemplative"
        case .midnight: return "Dramatic, modern, powerful"
        case .roseGold: return "Luxurious, warm, sophisticated"
        case .arctic: return "Clean, minimal, precise"
        }
    }

    /// Primary accent color for swatch previews.
    var primaryAccent: TonicWorldModeColorToken {
        switch self {
        case .defaultPurple: return .init(darkHex: "AFA6E6", midHex: "2E295E", lightHex: "5B4EF0")
        case .ocean: return .init(darkHex: "7CC4E8", midHex: "1B3E5E", lightHex: "1A6FB5")
        case .sunset: return .init(darkHex: "F0A873", midHex: "6E3A18", lightHex: "D45A1E")
        case .forest: return .init(darkHex: "8ABF8A", midHex: "2A5234", lightHex: "2D6E3A")
        case .lavender: return .init(darkHex: "C8A8E0", midHex: "3E2860", lightHex: "7A3EB0")
        case .midnight: return .init(darkHex: "7A8CF0", midHex: "1E2258", lightHex: "3040C8")
        case .roseGold: return .init(darkHex: "E8A8A0", midHex: "5E3030", lightHex: "C0504A")
        case .arctic: return .init(darkHex: "94B8D0", midHex: "2A4458", lightHex: "3A6888")
        }
    }

    // swiftlint:disable function_body_length cyclomatic_complexity
    func worldToken(for world: TonicWorld) -> TonicWorldColorToken {
        switch (self, world) {

        // MARK: Default Purple
        case (.defaultPurple, .smartScanPurple):
            return .init(
                darkMode: .init(darkHex: "0C0B1B", midHex: "2E295E", lightHex: "AFA6E6"),
                lightMode: .init(darkHex: "F1F0FF", midHex: "D6D1FF", lightHex: "5B4EF0")
            )
        case (.defaultPurple, .cleanupGreen):
            return .init(
                darkMode: .init(darkHex: "0A1712", midHex: "254A38", lightHex: "85CBA6"),
                lightMode: .init(darkHex: "EDFBF2", midHex: "CFEEDD", lightHex: "1F6A4A")
            )
        case (.defaultPurple, .clutterTeal):
            return .init(
                darkMode: .init(darkHex: "071417", midHex: "244A50", lightHex: "79BEC4"),
                lightMode: .init(darkHex: "EAFBFC", midHex: "CDEFF1", lightHex: "1E6E74")
            )
        case (.defaultPurple, .applicationsBlue):
            return .init(
                darkMode: .init(darkHex: "0A1323", midHex: "2A3F78", lightHex: "86A6E6"),
                lightMode: .init(darkHex: "EEF3FF", midHex: "D2DEFF", lightHex: "2B4ED6")
            )
        case (.defaultPurple, .performanceOrange):
            return .init(
                darkMode: .init(darkHex: "160E09", midHex: "6E341B", lightHex: "E8B08E"),
                lightMode: .init(darkHex: "FFF3EC", midHex: "FFDCCB", lightHex: "A8441C")
            )
        case (.defaultPurple, .protectionMagenta):
            return .init(
                darkMode: .init(darkHex: "170A14", midHex: "62234F", lightHex: "E4A0CA"),
                lightMode: .init(darkHex: "FFEFF8", midHex: "FFD1EB", lightHex: "8E1D63")
            )

        // MARK: Ocean
        case (.ocean, .smartScanPurple):
            return .init(
                darkMode: .init(darkHex: "080F18", midHex: "1B3E5E", lightHex: "7CC4E8"),
                lightMode: .init(darkHex: "EDF6FC", midHex: "C4E2F6", lightHex: "1A6FB5")
            )
        case (.ocean, .cleanupGreen):
            return .init(
                darkMode: .init(darkHex: "091610", midHex: "1E4A3A", lightHex: "6DC8A4"),
                lightMode: .init(darkHex: "ECFAF2", midHex: "C8EDDA", lightHex: "1B7050")
            )
        case (.ocean, .clutterTeal):
            return .init(
                darkMode: .init(darkHex: "081317", midHex: "1E4650", lightHex: "68C0CC"),
                lightMode: .init(darkHex: "EAFAFC", midHex: "C2EEF2", lightHex: "17727C")
            )
        case (.ocean, .applicationsBlue):
            return .init(
                darkMode: .init(darkHex: "08101F", midHex: "203A6E", lightHex: "6BA0E0"),
                lightMode: .init(darkHex: "ECF2FE", midHex: "C6D8F8", lightHex: "2252C8")
            )
        case (.ocean, .performanceOrange):
            return .init(
                darkMode: .init(darkHex: "140E08", midHex: "5E3218", lightHex: "D8A680"),
                lightMode: .init(darkHex: "FFF2EB", midHex: "FFD6C2", lightHex: "9A4018")
            )
        case (.ocean, .protectionMagenta):
            return .init(
                darkMode: .init(darkHex: "140912", midHex: "522048", lightHex: "D494BC"),
                lightMode: .init(darkHex: "FEEFF6", midHex: "F8CCE6", lightHex: "801B5E")
            )

        // MARK: Sunset
        case (.sunset, .smartScanPurple):
            return .init(
                darkMode: .init(darkHex: "161008", midHex: "6E3A18", lightHex: "F0A873"),
                lightMode: .init(darkHex: "FFF5EC", midHex: "FFDCBA", lightHex: "D45A1E")
            )
        case (.sunset, .cleanupGreen):
            return .init(
                darkMode: .init(darkHex: "10140A", midHex: "3C4E20", lightHex: "A8CC6E"),
                lightMode: .init(darkHex: "F4FAE8", midHex: "DCEEC0", lightHex: "4A7A1A")
            )
        case (.sunset, .clutterTeal):
            return .init(
                darkMode: .init(darkHex: "0E1410", midHex: "345040", lightHex: "8AC4A0"),
                lightMode: .init(darkHex: "EFFAF0", midHex: "D2EED6", lightHex: "2A7248")
            )
        case (.sunset, .applicationsBlue):
            return .init(
                darkMode: .init(darkHex: "140C08", midHex: "5A2E18", lightHex: "E09468"),
                lightMode: .init(darkHex: "FFF0E6", midHex: "FFD0B0", lightHex: "B84418")
            )
        case (.sunset, .performanceOrange):
            return .init(
                darkMode: .init(darkHex: "181008", midHex: "784018", lightHex: "F0B868"),
                lightMode: .init(darkHex: "FFF6E6", midHex: "FFE0AA", lightHex: "B86A10")
            )
        case (.sunset, .protectionMagenta):
            return .init(
                darkMode: .init(darkHex: "180A0A", midHex: "6E2020", lightHex: "E88888"),
                lightMode: .init(darkHex: "FFF0F0", midHex: "FFD0D0", lightHex: "B82828")
            )

        // MARK: Forest
        case (.forest, .smartScanPurple):
            return .init(
                darkMode: .init(darkHex: "0A120A", midHex: "2A5234", lightHex: "8ABF8A"),
                lightMode: .init(darkHex: "EEF6EE", midHex: "C8E4CC", lightHex: "2D6E3A")
            )
        case (.forest, .cleanupGreen):
            return .init(
                darkMode: .init(darkHex: "0C140C", midHex: "2E5830", lightHex: "7EC882"),
                lightMode: .init(darkHex: "ECFAEC", midHex: "C4EACA", lightHex: "1E6824")
            )
        case (.forest, .clutterTeal):
            return .init(
                darkMode: .init(darkHex: "0A1210", midHex: "264A3E", lightHex: "72B8A0"),
                lightMode: .init(darkHex: "ECF8F4", midHex: "C4E8DC", lightHex: "1A6650")
            )
        case (.forest, .applicationsBlue):
            return .init(
                darkMode: .init(darkHex: "0C100E", midHex: "304238", lightHex: "88B498"),
                lightMode: .init(darkHex: "F0F6F2", midHex: "D0E2D6", lightHex: "2E5E42")
            )
        case (.forest, .performanceOrange):
            return .init(
                darkMode: .init(darkHex: "12100A", midHex: "564024", lightHex: "C8A472"),
                lightMode: .init(darkHex: "FAF4EC", midHex: "ECD8B8", lightHex: "886030")
            )
        case (.forest, .protectionMagenta):
            return .init(
                darkMode: .init(darkHex: "120C10", midHex: "4E2844", lightHex: "C088B0"),
                lightMode: .init(darkHex: "FAF0F6", midHex: "E8D0DE", lightHex: "7A2E60")
            )

        // MARK: Lavender
        case (.lavender, .smartScanPurple):
            return .init(
                darkMode: .init(darkHex: "0E0A14", midHex: "3E2860", lightHex: "C8A8E0"),
                lightMode: .init(darkHex: "F6F0FC", midHex: "E2D0F4", lightHex: "7A3EB0")
            )
        case (.lavender, .cleanupGreen):
            return .init(
                darkMode: .init(darkHex: "0A1210", midHex: "264A38", lightHex: "7CC4A0"),
                lightMode: .init(darkHex: "EEFAF2", midHex: "CCEED8", lightHex: "1E6A46")
            )
        case (.lavender, .clutterTeal):
            return .init(
                darkMode: .init(darkHex: "080E14", midHex: "203E50", lightHex: "6CB0C8"),
                lightMode: .init(darkHex: "ECF4FA", midHex: "C6DEF0", lightHex: "186878")
            )
        case (.lavender, .applicationsBlue):
            return .init(
                darkMode: .init(darkHex: "0A0C18", midHex: "283468", lightHex: "8898D8"),
                lightMode: .init(darkHex: "F0F0FC", midHex: "D2D4F4", lightHex: "3240B8")
            )
        case (.lavender, .performanceOrange):
            return .init(
                darkMode: .init(darkHex: "140C08", midHex: "5E2E18", lightHex: "D89870"),
                lightMode: .init(darkHex: "FFF2EA", midHex: "FFD4B8", lightHex: "983C16")
            )
        case (.lavender, .protectionMagenta):
            return .init(
                darkMode: .init(darkHex: "140A10", midHex: "522040", lightHex: "D090B8"),
                lightMode: .init(darkHex: "FCEFF6", midHex: "F4CCE2", lightHex: "7E1C58")
            )

        // MARK: Midnight
        case (.midnight, .smartScanPurple):
            return .init(
                darkMode: .init(darkHex: "06060F", midHex: "1E2258", lightHex: "7A8CF0"),
                lightMode: .init(darkHex: "F0F0FF", midHex: "D0D4FC", lightHex: "3040C8")
            )
        case (.midnight, .cleanupGreen):
            return .init(
                darkMode: .init(darkHex: "06100C", midHex: "183E2E", lightHex: "58C890"),
                lightMode: .init(darkHex: "ECFAF0", midHex: "C4ECD6", lightHex: "146E40")
            )
        case (.midnight, .clutterTeal):
            return .init(
                darkMode: .init(darkHex: "060E10", midHex: "183A44", lightHex: "50BCC8"),
                lightMode: .init(darkHex: "ECF8FA", midHex: "C0E8EE", lightHex: "106A78")
            )
        case (.midnight, .applicationsBlue):
            return .init(
                darkMode: .init(darkHex: "060A18", midHex: "182E68", lightHex: "6888E8"),
                lightMode: .init(darkHex: "EEF0FE", midHex: "C8D2FA", lightHex: "2244D0")
            )
        case (.midnight, .performanceOrange):
            return .init(
                darkMode: .init(darkHex: "100A06", midHex: "502C12", lightHex: "D89460"),
                lightMode: .init(darkHex: "FFF0E6", midHex: "FFD0AA", lightHex: "8E3810")
            )
        case (.midnight, .protectionMagenta):
            return .init(
                darkMode: .init(darkHex: "100614", midHex: "441E50", lightHex: "C07CE0"),
                lightMode: .init(darkHex: "F8EEFE", midHex: "E8CEF8", lightHex: "701E98")
            )

        // MARK: Rose Gold
        case (.roseGold, .smartScanPurple):
            return .init(
                darkMode: .init(darkHex: "140C0A", midHex: "5E3030", lightHex: "E8A8A0"),
                lightMode: .init(darkHex: "FCF2F0", midHex: "F0D0CC", lightHex: "C0504A")
            )
        case (.roseGold, .cleanupGreen):
            return .init(
                darkMode: .init(darkHex: "0C1410", midHex: "2A5038", lightHex: "80C496"),
                lightMode: .init(darkHex: "EEF8F0", midHex: "CCECD4", lightHex: "20684A")
            )
        case (.roseGold, .clutterTeal):
            return .init(
                darkMode: .init(darkHex: "0A1214", midHex: "224850", lightHex: "70BAC2"),
                lightMode: .init(darkHex: "ECF8FA", midHex: "C8ECF0", lightHex: "1A6C74")
            )
        case (.roseGold, .applicationsBlue):
            return .init(
                darkMode: .init(darkHex: "0E0C18", midHex: "383060", lightHex: "9890D0"),
                lightMode: .init(darkHex: "F2F0FA", midHex: "DCD6F0", lightHex: "4840A0")
            )
        case (.roseGold, .performanceOrange):
            return .init(
                darkMode: .init(darkHex: "160E0A", midHex: "6A3820", lightHex: "E0A880"),
                lightMode: .init(darkHex: "FEF4EC", midHex: "FFD8C0", lightHex: "A04820")
            )
        case (.roseGold, .protectionMagenta):
            return .init(
                darkMode: .init(darkHex: "160A0E", midHex: "5E2038", lightHex: "E090A8"),
                lightMode: .init(darkHex: "FEF0F2", midHex: "FFC8D8", lightHex: "901840")
            )

        // MARK: Arctic
        case (.arctic, .smartScanPurple):
            return .init(
                darkMode: .init(darkHex: "0A0E12", midHex: "2A4458", lightHex: "94B8D0"),
                lightMode: .init(darkHex: "F2F6F8", midHex: "D4E2EC", lightHex: "3A6888")
            )
        case (.arctic, .cleanupGreen):
            return .init(
                darkMode: .init(darkHex: "0A1210", midHex: "264838", lightHex: "78C0A0"),
                lightMode: .init(darkHex: "EEF8F2", midHex: "CCE8D8", lightHex: "1E6648")
            )
        case (.arctic, .clutterTeal):
            return .init(
                darkMode: .init(darkHex: "0A1014", midHex: "243E4C", lightHex: "72B0C0"),
                lightMode: .init(darkHex: "EEF6FA", midHex: "CCE4EE", lightHex: "1C6472")
            )
        case (.arctic, .applicationsBlue):
            return .init(
                darkMode: .init(darkHex: "0A0E16", midHex: "263860", lightHex: "7898CC"),
                lightMode: .init(darkHex: "F0F2FA", midHex: "D2DAF0", lightHex: "2848A0")
            )
        case (.arctic, .performanceOrange):
            return .init(
                darkMode: .init(darkHex: "120E0A", midHex: "503418", lightHex: "C89C70"),
                lightMode: .init(darkHex: "F8F4EE", midHex: "ECD8C0", lightHex: "7C5028")
            )
        case (.arctic, .protectionMagenta):
            return .init(
                darkMode: .init(darkHex: "100A10", midHex: "40203E", lightHex: "B080AA"),
                lightMode: .init(darkHex: "F6F0F6", midHex: "E2D0E0", lightHex: "6A2864")
            )
        }
    }
    // swiftlint:enable function_body_length cyclomatic_complexity
}

// MARK: - Neutral / Text / Stroke

enum TonicNeutralToken {
    static let white = Color(hex: "FFFFFF")
    static let black = Color(hex: "0A0A0F")

    // Light neutral stack (Option B)
    static let neutral0 = Color(hex: "F5F6FA")
    static let neutral1 = Color(hex: "EEF0F6")
    static let neutral2 = Color(hex: "F8F9FC")
    static let neutral3 = Color(hex: "FFFFFF")

    static let dynamicBackground = Color.tonicDynamic(lightHex: "F5F6FA", darkHex: "0A0A0F")
}

enum TonicTextToken {
    static let primary = Color.tonicDynamic(lightHex: "000000", darkHex: "FFFFFF", lightAlpha: 0.88, darkAlpha: 0.92)
    static let secondary = Color.tonicDynamic(lightHex: "000000", darkHex: "FFFFFF", lightAlpha: 0.64, darkAlpha: 0.70)
    static let tertiary = Color.tonicDynamic(lightHex: "000000", darkHex: "FFFFFF", lightAlpha: 0.50, darkAlpha: 0.52)
}

enum TonicStrokeToken {
    // Light: #0000001A / #0000002B, Dark preserved as white-alpha stack.
    static let subtle = Color.tonicDynamic(lightHex: "000000", darkHex: "FFFFFF", lightAlpha: 0.10, darkAlpha: 0.12)
    static let stronger = Color.tonicDynamic(lightHex: "000000", darkHex: "FFFFFF", lightAlpha: 0.17, darkAlpha: 0.20)
}

// MARK: - Radius / Space

enum TonicRadiusToken {
    static let s: CGFloat = 10
    static let m: CGFloat = 14
    static let l: CGFloat = 22
    static let xl: CGFloat = 26
    static let container: CGFloat = 30

    static let chip: CGFloat = 12
}

enum TonicSpaceToken {
    static let one: CGFloat = 8
    static let two: CGFloat = 12
    static let three: CGFloat = 16
    static let four: CGFloat = 24
    static let five: CGFloat = 32
    static let six: CGFloat = 48
    static let seven: CGFloat = 64

    static let gridGap: CGFloat = 16
}

// MARK: - Semantic

enum TonicSemanticKind: String, CaseIterable, Sendable {
    case success
    case info
    case warning
    case danger
    case neutral
}

struct TonicStatusStyle {
    let fill: Color
    let stroke: Color
    let text: Color
}

enum TonicStatusPalette {
    static func style(_ kind: TonicSemanticKind, for colorScheme: ColorScheme) -> TonicStatusStyle {
        let isDark = colorScheme == .dark

        switch kind {
        case .success where !isDark:
            return .init(fill: Color(hex: "E6F6ED"), stroke: Color(hex: "BFE7CF"), text: Color(hex: "116A3C"))
        case .success:
            return .init(fill: Color(hex: "123022"), stroke: Color(hex: "1E5A3C"), text: Color(hex: "8BE0B4"))

        case .warning where !isDark:
            return .init(fill: Color(hex: "FFF3E2"), stroke: Color(hex: "FFD7A6"), text: Color(hex: "8A4B00"))
        case .warning:
            return .init(fill: Color(hex: "2A1E10"), stroke: Color(hex: "6C3F12"), text: Color(hex: "FFC57A"))

        case .danger where !isDark:
            return .init(fill: Color(hex: "FFE9EA"), stroke: Color(hex: "FFC0C4"), text: Color(hex: "8B1D2C"))
        case .danger:
            return .init(fill: Color(hex: "2C1215"), stroke: Color(hex: "6B1E2A"), text: Color(hex: "FF9AA3"))

        case .info where !isDark:
            return .init(fill: Color(hex: "E9F1FF"), stroke: Color(hex: "C7DAFF"), text: Color(hex: "1C4FA8"))
        case .info:
            return .init(fill: Color(hex: "0F1D33"), stroke: Color(hex: "1D3F7A"), text: Color(hex: "9EC2FF"))

        case .neutral where !isDark:
            return .init(fill: Color(hex: "EEF0F4"), stroke: Color(hex: "D8DCE6"), text: Color(hex: "3B4254"))
        case .neutral:
            return .init(fill: Color(hex: "161A22"), stroke: Color(hex: "2A3242"), text: Color(hex: "B9C0D0"))
        }
    }

    static func fill(_ kind: TonicSemanticKind) -> Color {
        switch kind {
        case .success:
            return Color.tonicDynamic(lightHex: "E6F6ED", darkHex: "123022")
        case .warning:
            return Color.tonicDynamic(lightHex: "FFF3E2", darkHex: "2A1E10")
        case .danger:
            return Color.tonicDynamic(lightHex: "FFE9EA", darkHex: "2C1215")
        case .info:
            return Color.tonicDynamic(lightHex: "E9F1FF", darkHex: "0F1D33")
        case .neutral:
            return Color.tonicDynamic(lightHex: "EEF0F4", darkHex: "161A22")
        }
    }

    static func stroke(_ kind: TonicSemanticKind) -> Color {
        switch kind {
        case .success:
            return Color.tonicDynamic(lightHex: "BFE7CF", darkHex: "1E5A3C")
        case .warning:
            return Color.tonicDynamic(lightHex: "FFD7A6", darkHex: "6C3F12")
        case .danger:
            return Color.tonicDynamic(lightHex: "FFC0C4", darkHex: "6B1E2A")
        case .info:
            return Color.tonicDynamic(lightHex: "C7DAFF", darkHex: "1D3F7A")
        case .neutral:
            return Color.tonicDynamic(lightHex: "D8DCE6", darkHex: "2A3242")
        }
    }

    static func text(_ kind: TonicSemanticKind) -> Color {
        switch kind {
        case .success:
            return Color.tonicDynamic(lightHex: "116A3C", darkHex: "8BE0B4")
        case .warning:
            return Color.tonicDynamic(lightHex: "8A4B00", darkHex: "FFC57A")
        case .danger:
            return Color.tonicDynamic(lightHex: "8B1D2C", darkHex: "FF9AA3")
        case .info:
            return Color.tonicDynamic(lightHex: "1C4FA8", darkHex: "9EC2FF")
        case .neutral:
            return Color.tonicDynamic(lightHex: "3B4254", darkHex: "B9C0D0")
        }
    }
}

enum TonicSemanticTokens {
    @available(*, deprecated, message: "Use TonicStatusPalette.style(_:for:) for fill/stroke/text tokenized status surfaces.")
    static func color(_ kind: TonicSemanticKind) -> Color {
        TonicStatusPalette.text(kind)
    }
}

// MARK: - Shadow

struct TonicShadowStyle: Sendable {
    let color: Color
    let y: CGFloat
    let blur: CGFloat
}

enum TonicShadowToken {
    // Dark elevation stack.
    static let elev1 = TonicShadowStyle(color: .black.opacity(0.30), y: 8, blur: 22)
    static let elev2 = TonicShadowStyle(color: .black.opacity(0.35), y: 16, blur: 52)
    static let elev3 = TonicShadowStyle(color: .black.opacity(0.40), y: 26, blur: 86)

    // Light elevation stack.
    static let lightE1 = TonicShadowStyle(color: .black.opacity(0.08), y: 6, blur: 18)
    static let lightE2 = TonicShadowStyle(color: .black.opacity(0.10), y: 14, blur: 34)

    static func level1(for colorScheme: ColorScheme) -> TonicShadowStyle {
        colorScheme == .dark ? elev1 : lightE1
    }

    static func level2(for colorScheme: ColorScheme) -> TonicShadowStyle {
        colorScheme == .dark ? elev2 : lightE2
    }
}

// MARK: - Motion

enum TonicMotionToken {
    static let fast: Double = 0.12
    static let med: Double = 0.20
    static let slow: Double = 0.35

    static let fade: Double = slow
    static let hover: Double = fast
    static let press: Double = fast

    static let springTapResponse: Double = 0.25
    static let springTapDamping: Double = 0.82

    static var ease: Animation {
        .easeInOut(duration: med)
    }

    static var springTap: Animation {
        .spring(response: springTapResponse, dampingFraction: springTapDamping)
    }

    // MARK: Hero Breathing

    static let breathingScale: ClosedRange<CGFloat> = 1.0 ... 1.015
    static let breathingDuration: Double = 4.5

    // MARK: Scan Pulse

    static let scanPulseAmplitude: Double = 0.04
    static let scanPulseDuration: Double = 2.0

    // MARK: Stage Transitions

    static let stageExitDuration: Double = 0.20
    static var stageEnterSpring: Animation { .spring(response: 0.40, dampingFraction: 0.85) }
    static var stageCheckmarkSpring: Animation { .spring(response: 0.30, dampingFraction: 0.60) }

    // MARK: Result Reveal

    static let resultStaggerDelay: Double = 0.08
    static var resultCardSpring: Animation { .spring(response: 0.45, dampingFraction: 0.82) }
    static var resultMetricSpring: Animation { .spring(response: 0.50, dampingFraction: 0.75) }
    static let resultCountUpDuration: Double = 0.80

    // MARK: Modal

    static var modalPresentSpring: Animation { .spring(response: 0.50, dampingFraction: 0.86) }
    static var modalDismissSpring: Animation { .spring(response: 0.30, dampingFraction: 0.90) }
}

enum TonicControlState: String, CaseIterable, Sendable {
    case `default`
    case hover
    case pressed
    case focused
    case disabled
}

struct TonicControlStateToken {
    let brightnessDelta: Double
    let scale: CGFloat
    let contentOpacity: Double
    let strokeBoostOpacity: Double
    let shadowMultiplier: Double
}

enum TonicFocusToken {
    static let ringOpacity: Double = 0.40

    static func ring(for accent: Color) -> Color {
        accent.opacity(ringOpacity)
    }
}

enum TonicButtonStateTokens {
    static func token(for state: TonicControlState) -> TonicControlStateToken {
        switch state {
        case .default:
            return .init(brightnessDelta: 0, scale: 1, contentOpacity: 1, strokeBoostOpacity: 0, shadowMultiplier: 1)
        case .hover:
            return .init(brightnessDelta: 0.06, scale: 1, contentOpacity: 1, strokeBoostOpacity: 0.16, shadowMultiplier: 1.1)
        case .pressed:
            return .init(brightnessDelta: -0.02, scale: 0.98, contentOpacity: 1, strokeBoostOpacity: 0.06, shadowMultiplier: 0.7)
        case .focused:
            return .init(brightnessDelta: 0.01, scale: 1, contentOpacity: 1, strokeBoostOpacity: 0.10, shadowMultiplier: 1)
        case .disabled:
            return .init(brightnessDelta: 0, scale: 1, contentOpacity: 0.5, strokeBoostOpacity: 0, shadowMultiplier: 1)
        }
    }
}

enum TonicChipStateTokens {
    static func token(for state: TonicControlState) -> TonicControlStateToken {
        switch state {
        case .default:
            return .init(brightnessDelta: 0, scale: 1, contentOpacity: 1, strokeBoostOpacity: 0, shadowMultiplier: 1)
        case .hover:
            return .init(brightnessDelta: 0.03, scale: 1, contentOpacity: 1, strokeBoostOpacity: 0.10, shadowMultiplier: 1)
        case .pressed:
            return .init(brightnessDelta: -0.02, scale: 0.98, contentOpacity: 1, strokeBoostOpacity: 0.06, shadowMultiplier: 1)
        case .focused:
            return .init(brightnessDelta: 0.01, scale: 1, contentOpacity: 1, strokeBoostOpacity: 0.08, shadowMultiplier: 1)
        case .disabled:
            return .init(brightnessDelta: 0, scale: 1, contentOpacity: 0.55, strokeBoostOpacity: 0, shadowMultiplier: 1)
        }
    }
}

// MARK: - Surface

enum TonicGlassVariant: Sendable {
    case base
    case raised
    case sunken
}

struct TonicGlassStyle {
    let fill: Color
    let vignette: Color
    let stroke: Color
    let innerHighlight: Color
    let shadow: Color
}

struct TonicGlassAlphaProfile: Sendable {
    let fill: Double
    let vignette: Double
    let stroke: Double
    let innerHighlight: Double
    let shadow: Double
}

enum TonicGlassToken {
    static let blur: CGFloat = 24

    static func alphaProfile(for colorScheme: ColorScheme, variant: TonicGlassVariant = .base) -> TonicGlassAlphaProfile {
        let isDark = colorScheme == .dark

        // Premium glass: slightly higher fill for depth, refined vignette for richness.
        var fillAlpha = isDark ? 0.07 : 0.025
        var vignetteAlpha = isDark ? 0.24 : 0.035
        var strokeAlpha = isDark ? 0.11 : 0.10
        let innerHighlightAlpha = isDark ? 0.07 : 0.18
        var shadowAlpha = isDark ? 0.38 : 0.07

        switch variant {
        case .base:
            break
        case .raised:
            fillAlpha += 0.025
            strokeAlpha += 0.02
            shadowAlpha += 0.06
        case .sunken:
            vignetteAlpha += 0.05
            fillAlpha -= 0.015
        }

        return TonicGlassAlphaProfile(
            fill: fillAlpha,
            vignette: vignetteAlpha,
            stroke: strokeAlpha,
            innerHighlight: innerHighlightAlpha,
            shadow: shadowAlpha
        )
    }

    static func style(for colorScheme: ColorScheme, variant: TonicGlassVariant = .base) -> TonicGlassStyle {
        let isDark = colorScheme == .dark
        let profile = alphaProfile(for: colorScheme, variant: variant)

        return TonicGlassStyle(
            fill: (isDark ? TonicNeutralToken.white : TonicNeutralToken.black).opacity(profile.fill),
            vignette: TonicNeutralToken.black.opacity(profile.vignette),
            stroke: (isDark ? TonicNeutralToken.white : TonicNeutralToken.black).opacity(profile.stroke),
            innerHighlight: TonicNeutralToken.white.opacity(profile.innerHighlight),
            shadow: TonicNeutralToken.black.opacity(profile.shadow)
        )
    }

    static var fill: Color { Color.tonicDynamic(lightHex: "000000", darkHex: "FFFFFF", lightAlpha: 0.02, darkAlpha: 0.06) }
    static var stroke: Color { Color.tonicDynamic(lightHex: "000000", darkHex: "FFFFFF", lightAlpha: 0.10, darkAlpha: 0.10) }
    static var baseVignette: Color { Color.tonicDynamic(lightHex: "000000", darkHex: "000000", lightAlpha: 0.06, darkAlpha: 0.22) }
}

struct TonicButtonStyle {
    let background: Color
    let foreground: Color
    let stroke: Color
    let focusRing: Color
    let strokeBoost: Color
}

enum TonicButtonVariant: Sendable {
    case primary
    case secondary
}

enum TonicButtonTokens {
    static func style(
        variant: TonicButtonVariant,
        state: TonicControlState = .default,
        colorScheme: ColorScheme,
        accent: Color = .accentColor
    ) -> TonicButtonStyle {
        let base = baseStyle(variant: variant, colorScheme: colorScheme)
        let motion = TonicButtonStateTokens.token(for: state)
        let focusRing = TonicFocusToken.ring(for: accent)

        let boostColor = (colorScheme == .dark ? TonicNeutralToken.white : TonicNeutralToken.black)
            .opacity(motion.strokeBoostOpacity)

        return .init(
            background: base.background,
            foreground: base.foreground.opacity(motion.contentOpacity),
            stroke: base.stroke,
            focusRing: focusRing,
            strokeBoost: boostColor
        )
    }

    private static func baseStyle(variant: TonicButtonVariant, colorScheme: ColorScheme) -> TonicButtonStyle {
        let isDark = colorScheme == .dark

        switch variant {
        case .primary where isDark:
            return .init(
                background: Color(hex: "FFFFFF"),
                foreground: Color(hex: "0B0C10"),
                stroke: TonicNeutralToken.white.opacity(0.18),
                focusRing: Color.accentColor.opacity(TonicFocusToken.ringOpacity),
                strokeBoost: .clear
            )
        case .primary:
            return .init(
                background: Color(hex: "111318"),
                foreground: Color(hex: "FFFFFF"),
                stroke: TonicNeutralToken.black.opacity(0.20),
                focusRing: Color.accentColor.opacity(TonicFocusToken.ringOpacity),
                strokeBoost: .clear
            )
        case .secondary where isDark:
            return .init(
                background: TonicNeutralToken.white.opacity(31.0 / 255.0), // #FFFFFF1F
                foreground: TonicTextToken.primary,
                stroke: TonicNeutralToken.white.opacity(0.20),
                focusRing: Color.accentColor.opacity(TonicFocusToken.ringOpacity),
                strokeBoost: .clear
            )
        case .secondary:
            return .init(
                background: TonicNeutralToken.white.opacity(168.0 / 255.0), // #FFFFFFA8
                foreground: TonicTextToken.primary,
                stroke: TonicNeutralToken.black.opacity(0.17),
                focusRing: Color.accentColor.opacity(TonicFocusToken.ringOpacity),
                strokeBoost: .clear
            )
        }
    }

    static func primary(for colorScheme: ColorScheme) -> TonicButtonStyle {
        style(variant: .primary, state: .default, colorScheme: colorScheme)
    }

    static func secondary(for colorScheme: ColorScheme) -> TonicButtonStyle {
        style(variant: .secondary, state: .default, colorScheme: colorScheme)
    }
}

// MARK: - Chip Tokens

enum TonicChipStrength: Sendable {
    case subtle
    case strong
    case outline
}

enum TonicChipRole: Sendable {
    case semantic(TonicSemanticKind)
    case world(TonicWorld)
}

struct TonicChipStyle {
    let backgroundBase: Color
    let backgroundTint: Color
    let stroke: Color
    let strokeOverlay: Color
    let text: Color
    let icon: Color

    let strokeWidth: CGFloat
    let height: CGFloat
    let radius: CGFloat
    let paddingX: CGFloat
    let paddingY: CGFloat
    let iconSize: CGFloat
    let tracking: CGFloat
    let font: Font

    let stateToken: TonicControlStateToken
}

enum TonicChipTokens {
    static func style(role: TonicChipRole, strength: TonicChipStrength, colorScheme: ColorScheme) -> TonicChipStyle {
        style(role: role, strength: strength, colorScheme: colorScheme, state: .default, isEnabled: true)
    }

    static func style(
        role: TonicChipRole,
        strength: TonicChipStrength,
        colorScheme: ColorScheme,
        state: TonicControlState = .default,
        isEnabled: Bool = true
    ) -> TonicChipStyle {
        let resolvedState: TonicControlState = isEnabled ? state : .disabled
        let stateToken = TonicChipStateTokens.token(for: resolvedState)

        switch role {
        case .semantic(let kind):
            return semanticStatusStyle(
                kind: kind,
                strength: strength,
                colorScheme: colorScheme,
                state: resolvedState,
                token: stateToken
            )
        case .world(let world):
            return worldStyle(
                world: world,
                strength: strength,
                colorScheme: colorScheme,
                state: resolvedState,
                token: stateToken
            )
        }
    }

    private static func semanticStatusStyle(
        kind: TonicSemanticKind,
        strength: TonicChipStrength,
        colorScheme: ColorScheme,
        state: TonicControlState,
        token: TonicControlStateToken
    ) -> TonicChipStyle {
        let palette = TonicStatusPalette.style(kind, for: colorScheme)

        let outlineFill = colorScheme == .dark ? TonicNeutralToken.black.opacity(0.32) : TonicNeutralToken.neutral3
        let baseFill: Color = strength == .outline ? outlineFill : palette.fill
        let baseStroke: Color = strength == .outline ? palette.stroke : palette.stroke
        let baseText = palette.text.opacity(token.contentOpacity)
        let strengthLayer = strength == .strong
            ? palette.text.opacity(colorScheme == .dark ? 0.08 : 0.05)
            : Color.clear
        let stateLayerColor = stateLayer(for: state, colorScheme: colorScheme)
        let overlayLayer = state == .default ? strengthLayer : stateLayerColor

        return TonicChipStyle(
            backgroundBase: baseFill,
            backgroundTint: overlayLayer,
            stroke: baseStroke,
            strokeOverlay: stateStrokeLayer(for: state, colorScheme: colorScheme),
            text: baseText,
            icon: baseText, // status icons always match status text
            strokeWidth: 1,
            height: 27,
            radius: 999,
            paddingX: 11,
            paddingY: 5,
            iconSize: 12,
            tracking: -0.12,
            font: .system(size: 11.5, weight: .semibold),
            stateToken: token
        )
    }

    private static func worldStyle(
        world: TonicWorld,
        strength: TonicChipStrength,
        colorScheme: ColorScheme,
        state: TonicControlState,
        token: TonicControlStateToken
    ) -> TonicChipStyle {
        let isDark = colorScheme == .dark
        let swatch = Color(hex: world.token.token(for: TonicAppearanceMode(colorScheme)).lightHex)

        let baseSurface = isDark ? TonicNeutralToken.black.opacity(0.26) : TonicNeutralToken.neutral3
        let outlineSurface = isDark ? TonicNeutralToken.black.opacity(0.24) : TonicNeutralToken.neutral2

        let tintAlpha: Double
        let strokeAlpha: Double
        switch (strength, isDark) {
        case (.strong, true):
            tintAlpha = 0.18
            strokeAlpha = 0.34
        case (.strong, false):
            tintAlpha = 0.14
            strokeAlpha = 0.28
        case (.outline, true):
            tintAlpha = 0
            strokeAlpha = 0.38
        case (.outline, false):
            tintAlpha = 0
            strokeAlpha = 0.30
        case (.subtle, true):
            tintAlpha = 0.12
            strokeAlpha = 0.26
        case (.subtle, false):
            tintAlpha = 0.08
            strokeAlpha = 0.22
        }

        let backgroundBase = strength == .outline ? outlineSurface : baseSurface
        let tintedAlpha: Double = {
            switch state {
            case .hover:
                return min(1, tintAlpha + 0.03)
            case .pressed:
                return max(0, tintAlpha - 0.02)
            case .disabled:
                return max(0, tintAlpha - 0.05)
            default:
                return tintAlpha
            }
        }()

        let backgroundTint = swatch.opacity(tintedAlpha)
        let text = (isDark ? TonicNeutralToken.white : TonicTextToken.primary)
            .opacity((strength == .strong ? 0.95 : 0.88) * token.contentOpacity)

        return TonicChipStyle(
            backgroundBase: backgroundBase,
            backgroundTint: backgroundTint.opacity(token.contentOpacity),
            stroke: swatch.opacity(strokeAlpha),
            strokeOverlay: stateStrokeLayer(for: state, colorScheme: colorScheme),
            text: text,
            icon: swatch.opacity(isDark ? 0.85 : 0.92),
            strokeWidth: 1,
            height: 27,
            radius: 999,
            paddingX: 11,
            paddingY: 5,
            iconSize: 12,
            tracking: -0.08,
            font: .system(size: 11.5, weight: .semibold),
            stateToken: token
        )
    }

    private static func stateLayer(for state: TonicControlState, colorScheme: ColorScheme) -> Color {
        switch (state, colorScheme) {
        case (.hover, .dark):
            return TonicNeutralToken.white.opacity(0.06)
        case (.hover, .light):
            return TonicNeutralToken.white.opacity(0.06)
        case (.pressed, _):
            return TonicNeutralToken.black.opacity(0.08)
        case (.disabled, .dark):
            return TonicNeutralToken.black.opacity(0.16)
        case (.disabled, .light):
            return TonicNeutralToken.white.opacity(0.20)
        case (.focused, .dark):
            return TonicNeutralToken.white.opacity(0.02)
        case (.focused, .light):
            return TonicNeutralToken.white.opacity(0.02)
        default:
            return .clear
        }
    }

    private static func stateStrokeLayer(for state: TonicControlState, colorScheme: ColorScheme) -> Color {
        let token = TonicChipStateTokens.token(for: state)
        return (colorScheme == .dark ? TonicNeutralToken.white : TonicNeutralToken.black)
            .opacity(token.strokeBoostOpacity)
    }
}

// MARK: - Canvas

enum TonicCanvasTokens {
    private static let neutralDarkBase = TonicSRGB(hex: "0A0A0F")
    private static let lightBase = TonicNeutralToken.neutral0

    static func fill(for world: TonicWorld, colorScheme: ColorScheme) -> Color {
        if colorScheme == .light {
            return lightBase
        }

        let worldDark = TonicSRGB(hex: world.token.darkMode.darkHex)
        return neutralDarkBase.blended(with: worldDark, weight: 0.55).toNSColor().swiftUIColor
    }

    static func tint(for world: TonicWorld, colorScheme: ColorScheme) -> Color {
        if colorScheme == .light {
            return world.token.light.opacity(0.06)
        }
        return world.token.mid.opacity(0.18)
    }

    static func edgeGlow(for world: TonicWorld, colorScheme: ColorScheme) -> Color {
        if colorScheme == .light {
            return world.token.light.opacity(0.10)
        }
        return world.token.light.opacity(0.22)
    }
}

private extension NSColor {
    var swiftUIColor: Color { Color(nsColor: self) }
}

// MARK: - Typography

enum TonicTypeToken {
    static let hero = Font.system(size: 44, weight: .semibold)
    static let pillarTitle = Font.system(size: 34, weight: .semibold)
    static let tileMetric = Font.system(size: 28, weight: .semibold)

    // Back-compat aliases
    static let display = hero
    static let title = pillarTitle

    static let body = Font.system(size: 15, weight: .regular)
    static let caption = Font.system(size: 12, weight: .medium)
    static let micro = Font.system(size: 11, weight: .regular)
}

// MARK: - Theme

struct TonicTheme: Sendable {
    let world: TonicWorld

    var worldToken: TonicWorldColorToken { world.token }
    var accent: Color { worldToken.mid }

    var glowSoft: Color { worldToken.light.opacity(0.14) }
    var glowStrong: Color { worldToken.light.opacity(0.22) }

    // Back-compat alias
    var glow: Color { glowStrong }

    var canvasDark: Color { worldToken.dark }
    var canvasMid: Color { worldToken.mid }
    var canvasLight: Color { worldToken.light }
}
