//
//  AppearancePreferences.swift
//  Tonic
//
//  Theme + appearance preference state. Extracted from the legacy DarkModeThemeView.swift
//  view file so it survives the presentation-layer rewrite. Drives the in-app
//  Light/Dark/System selector and is applied by the AppDelegate.
//

import SwiftUI

/// Theme mode
public enum ThemeMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    public var id: String { rawValue }

    var icon: String {
        switch self {
        case .system: return "desktopcomputer"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Icon style options
public enum IconStyle: String, CaseIterable, Identifiable {
    case filled = "Filled"
    case outline = "Outline"

    public var id: String { rawValue }
}

/// Appearance preferences
@Observable
public final class AppearancePreferences: @unchecked Sendable {
    public static let shared = AppearancePreferences()

    public var themeMode: ThemeMode = .system
    public var iconStyle: IconStyle = .filled
    public var reduceTransparency: Bool = false
    public var reduceMotion: Bool = false

    private init() {
        loadFromUserDefaults()
    }

    private enum Keys {
        static let themeMode = "tonic.appearance.themeMode"
        static let iconStyle = "tonic.appearance.iconStyle"
        static let reduceTransparency = "tonic.appearance.reduceTransparency"
        static let reduceMotion = "tonic.appearance.reduceMotion"
    }

    public func setThemeMode(_ mode: ThemeMode) {
        themeMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Keys.themeMode)
        Task { @MainActor in
            let event = ActivityEvent(
                category: .preference,
                title: "Theme updated",
                detail: "Theme: \(mode.rawValue)",
                impact: .none
            )
            ActivityLogStore.shared.record(event)
        }
    }

    public func setIconStyle(_ style: IconStyle) {
        iconStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: Keys.iconStyle)
        Task { @MainActor in
            let event = ActivityEvent(
                category: .preference,
                title: "Icon style updated",
                detail: "Style: \(style.rawValue)",
                impact: .none
            )
            ActivityLogStore.shared.record(event)
        }
    }

    public func setReduceTransparency(_ reduce: Bool) {
        reduceTransparency = reduce
        UserDefaults.standard.set(reduce, forKey: Keys.reduceTransparency)
        Task { @MainActor in
            let title = reduce ? "Reduce transparency enabled" : "Reduce transparency disabled"
            let event = ActivityEvent(
                category: .preference,
                title: title,
                detail: "Reduce transparency: \(reduce ? "On" : "Off")",
                impact: .none
            )
            ActivityLogStore.shared.record(event)
        }
    }

    public func setReduceMotion(_ reduce: Bool) {
        reduceMotion = reduce
        UserDefaults.standard.set(reduce, forKey: Keys.reduceMotion)
        Task { @MainActor in
            let title = reduce ? "Reduce motion enabled" : "Reduce motion disabled"
            let event = ActivityEvent(
                category: .preference,
                title: title,
                detail: "Reduce motion: \(reduce ? "On" : "Off")",
                impact: .none
            )
            ActivityLogStore.shared.record(event)
        }
    }

    private func loadFromUserDefaults() {
        if let modeString = UserDefaults.standard.string(forKey: Keys.themeMode),
           let mode = ThemeMode(rawValue: modeString) {
            themeMode = mode
        }

        if let styleString = UserDefaults.standard.string(forKey: Keys.iconStyle),
           let style = IconStyle(rawValue: styleString) {
            iconStyle = style
        }

        reduceTransparency = UserDefaults.standard.bool(forKey: Keys.reduceTransparency)
        reduceMotion = UserDefaults.standard.bool(forKey: Keys.reduceMotion)
    }
}
