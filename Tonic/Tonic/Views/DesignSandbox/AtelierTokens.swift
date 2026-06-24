import SwiftUI

// MARK: - Atelier Color Foundation

enum AtelierTokens {
    enum Color {
        static let obsidian = SwiftUI.Color(hex: "09090C")
        static let cinder = SwiftUI.Color(hex: "121318")
        static let smoke = SwiftUI.Color(hex: "1A1C22")
        static let porcelain = SwiftUI.Color(hex: "F6F4EF")
        static let pearl = SwiftUI.Color(hex: "E8E2D5")
        static let champagne = SwiftUI.Color(hex: "DAB783")
        static let gold = SwiftUI.Color(hex: "AA8452")
        static let graphite = SwiftUI.Color(hex: "B9BAC3")

        static let success = SwiftUI.Color(hex: "7FC59F")
        static let warning = SwiftUI.Color(hex: "E0B06C")
        static let danger = SwiftUI.Color(hex: "DA7B7F")
        static let info = SwiftUI.Color(hex: "7EA7E4")
    }

    enum World {
        static func token(for world: TonicWorld) -> TonicWorldColorToken {
            switch world {
            case .smartScanPurple:
                return .init(
                    darkMode: .init(darkHex: "0D0A16", midHex: "443566", lightHex: "B8A6E3"),
                    lightMode: .init(darkHex: "F7F2FB", midHex: "E7DBF5", lightHex: "6A4AA1")
                )
            case .cleanupGreen:
                return .init(
                    darkMode: .init(darkHex: "0B150F", midHex: "305641", lightHex: "8DC8A7"),
                    lightMode: .init(darkHex: "EFFAF3", midHex: "D7EFDE", lightHex: "2D6C4D")
                )
            case .clutterTeal:
                return .init(
                    darkMode: .init(darkHex: "0A1315", midHex: "2E4E55", lightHex: "85BCC8"),
                    lightMode: .init(darkHex: "EEF9FB", midHex: "D2EBEE", lightHex: "2A6870")
                )
            case .applicationsBlue:
                return .init(
                    darkMode: .init(darkHex: "0A1120", midHex: "304A79", lightHex: "8AA7DB"),
                    lightMode: .init(darkHex: "EEF4FF", midHex: "D4E1F8", lightHex: "2D5CB8")
                )
            case .performanceOrange:
                return .init(
                    darkMode: .init(darkHex: "171007", midHex: "6A3D18", lightHex: "D6A476"),
                    lightMode: .init(darkHex: "FFF5EA", midHex: "F5DEC5", lightHex: "9B4C1F")
                )
            case .protectionMagenta:
                return .init(
                    darkMode: .init(darkHex: "170C13", midHex: "5A2B4F", lightHex: "CF94BA"),
                    lightMode: .init(darkHex: "FFF1F7", midHex: "F3D8E8", lightHex: "8A2F66")
                )
            }
        }
    }
}
