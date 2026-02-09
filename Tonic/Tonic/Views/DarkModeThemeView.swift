//
//  DarkModeThemeView.swift
//  Tonic
//
//  Dark mode and visual polish
//  Task ID: fn-1.13
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

/// Appearance preferences
@Observable
public final class AppearancePreferences: @unchecked Sendable {
    public static let shared = AppearancePreferences()

    public var themeMode: ThemeMode = .system
    public var iconStyle: IconStyle = .filled
    public var reduceTransparency: Bool = false
    public var reduceMotion: Bool = false
    public var colorPalette: TonicColorPalette = .defaultPurple

    private init() {
        loadFromUserDefaults()
    }

    private enum Keys {
        static let themeMode = "tonic.appearance.themeMode"
        static let iconStyle = "tonic.appearance.iconStyle"
        static let reduceTransparency = "tonic.appearance.reduceTransparency"
        static let reduceMotion = "tonic.appearance.reduceMotion"
        static let colorPalette = "tonic.appearance.colorPalette"
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

    public func setColorPalette(_ palette: TonicColorPalette) {
        colorPalette = palette
        UserDefaults.standard.set(palette.rawValue, forKey: Keys.colorPalette)
        NotificationCenter.default.post(name: NSNotification.Name("TonicThemeDidChange"), object: nil)
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

        if let paletteString = UserDefaults.standard.string(forKey: Keys.colorPalette),
           let palette = TonicColorPalette(rawValue: paletteString) {
            colorPalette = palette
        }

        reduceTransparency = UserDefaults.standard.bool(forKey: Keys.reduceTransparency)
        reduceMotion = UserDefaults.standard.bool(forKey: Keys.reduceMotion)
    }
}

/// Icon style options
public enum IconStyle: String, CaseIterable, Identifiable {
    case filled = "Filled"
    case outline = "Outline"

    public var id: String { rawValue }
}

/// Appearance settings view
struct AppearanceSettingsView: View {
    @State private var preferences = AppearancePreferences.shared

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    themeSection
                    iconStyleSection
                    effectsSection
                }
                .padding()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(preferences.themeMode.colorScheme)
    }

    private var header: some View {
        HStack {
            Text("Appearance")
                .font(.headline)

            Spacer()
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Theme Section

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Theme")
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                ForEach(ThemeMode.allCases) { mode in
                    ThemeModeButton(
                        mode: mode,
                        isSelected: preferences.themeMode == mode
                    ) {
                        preferences.setThemeMode(mode)
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Icon Style Section

    private var iconStyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Icon Style")
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                ForEach(IconStyle.allCases) { style in
                    IconStyleButton(
                        style: style,
                        isSelected: preferences.iconStyle == style
                    ) {
                        preferences.setIconStyle(style)
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Effects Section

    private var effectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Visual Effects")
                .font(.subheadline)
                .fontWeight(.semibold)

            EffectToggle(
                title: "Reduce Transparency",
                subtitle: "Replace transparency effects with solid colors",
                isOn: $preferences.reduceTransparency
            )

            EffectToggle(
                title: "Reduce Motion",
                subtitle: "Minimize animation effects",
                isOn: $preferences.reduceMotion
            )
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Supporting Views

struct ThemeModeButton: View {
    let mode: ThemeMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .frame(width: 50, height: 40)

                    Image(systemName: mode.icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? TonicColors.accent : .secondary)
                }

                Text(mode.rawValue)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct IconStyleButton: View {
    let style: IconStyle
    let isSelected: Bool
    let action: () -> Void

    var iconName: String {
        style == .filled ? "star.fill" : "star"
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? TonicColors.accent : .secondary)

                Text(style.rawValue)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? TonicColors.accent.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct EffectToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
        }
    }
}

#Preview {
    AppearanceSettingsView()
        .frame(width: 500, height: 600)
}
