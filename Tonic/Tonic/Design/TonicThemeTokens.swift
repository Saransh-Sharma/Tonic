//
//  TonicThemeTokens.swift
//  Tonic
//
//  Immersive theme token pack for Smart Scan and manager experiences.
//

import SwiftUI

// MARK: - World Colors

struct TonicWorldColorToken: Sendable {
    let darkHex: String
    let midHex: String
    let lightHex: String

    var dark: Color { Color(hex: darkHex) }
    var mid: Color { Color(hex: midHex) }
    var light: Color { Color(hex: lightHex) }
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
        switch self {
        case .smartScanPurple:
            return .init(darkHex: "090044", midHex: "54188A", lightHex: "B88AB9")
        case .cleanupGreen:
            return .init(darkHex: "113013", midHex: "3C672B", lightHex: "8DBB86")
        case .clutterTeal:
            return .init(darkHex: "1E4A48", midHex: "377A74", lightHex: "78ACA9")
        case .applicationsBlue:
            return .init(darkHex: "0E2861", midHex: "1F3F8D", lightHex: "5F86B5")
        case .performanceOrange:
            return .init(darkHex: "65230E", midHex: "9B3A19", lightHex: "BD906F")
        case .protectionMagenta:
            return .init(darkHex: "550E2E", midHex: "8B296C", lightHex: "BE81AB")
        }
    }
}

// MARK: - Neutral / Text / Stroke

enum TonicNeutralToken {
    static let white = Color(hex: "FFFFFF")
    static let black = Color(hex: "0A0A0F")
}

enum TonicTextToken {
    static let primary = TonicNeutralToken.white.opacity(0.92)
    static let secondary = TonicNeutralToken.white.opacity(0.72)
    static let tertiary = TonicNeutralToken.white.opacity(0.52)
}

enum TonicStrokeToken {
    static let subtle = TonicNeutralToken.white.opacity(0.12)
    static let stronger = TonicNeutralToken.white.opacity(0.20)
}

// MARK: - Radius / Space

enum TonicRadiusToken {
    static let s: CGFloat = 10
    static let m: CGFloat = 14
    static let l: CGFloat = 18
    static let xl: CGFloat = 24
}

enum TonicSpaceToken {
    static let one: CGFloat = 8
    static let two: CGFloat = 12
    static let three: CGFloat = 16
    static let four: CGFloat = 24
    static let five: CGFloat = 32
    static let six: CGFloat = 48
    static let seven: CGFloat = 64
}

// MARK: - Shadow

struct TonicShadowStyle: Sendable {
    let color: Color
    let y: CGFloat
    let blur: CGFloat
}

enum TonicShadowToken {
    static let elev1 = TonicShadowStyle(color: .black.opacity(0.28), y: 8, blur: 24)
    static let elev2 = TonicShadowStyle(color: .black.opacity(0.34), y: 18, blur: 60)
    static let elev3 = TonicShadowStyle(color: .black.opacity(0.38), y: 28, blur: 90)
}

// MARK: - Motion

enum TonicMotionToken {
    static let fade: Double = 0.32
    static let hover: Double = 0.12
    static let press: Double = 0.09

    static var ease: Animation {
        .easeInOut(duration: fade)
    }
}

// MARK: - Surface

struct TonicGlassToken {
    static let fill = TonicNeutralToken.white.opacity(0.08)
    static let stroke = TonicNeutralToken.white.opacity(0.12)
    static let blur: CGFloat = 24
}

// MARK: - Typography

enum TonicTypeToken {
    static let display = Font.system(size: 60, weight: .semibold)
    static let title = Font.system(size: 32, weight: .semibold)
    static let body = Font.system(size: 17, weight: .regular)
    static let caption = Font.system(size: 13, weight: .regular)
    static let micro = Font.system(size: 11, weight: .regular)
}

// MARK: - Theme

struct TonicTheme: Sendable {
    let world: TonicWorld

    var worldToken: TonicWorldColorToken { world.token }
    var accent: Color { worldToken.mid }
    var glow: Color { worldToken.light.opacity(0.25) }
    var canvasDark: Color { worldToken.dark }
    var canvasMid: Color { worldToken.mid }
    var canvasLight: Color { worldToken.light }
}
