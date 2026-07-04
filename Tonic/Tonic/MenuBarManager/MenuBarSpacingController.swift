//
//  MenuBarSpacingController.swift
//  Tonic
//
//  Reads and writes the system-wide menu bar item spacing / padding through
//  the global preferences domain (the same keys `defaults -globalDomain`
//  exposes). Changes take effect as apps relaunch. Direct build only —
//  writing the global domain is not sandbox-compatible.
//

#if !TONIC_STORE

import Foundation

/// Menu bar density presets. `nil` means "leave the system default".
public enum MenuBarSpacingPreset: String, CaseIterable, Sendable, Identifiable {
    case system
    case compact
    case tight

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: return "Default"
        case .compact: return "Compact"
        case .tight: return "Tight"
        }
    }

    /// (NSStatusItemSpacing, NSStatusItemSelectionPadding). `nil` deletes the
    /// override to restore macOS defaults (≈16 / 16).
    public var values: (spacing: Int?, padding: Int?) {
        switch self {
        case .system: return (nil, nil)
        case .compact: return (8, 6)
        case .tight: return (4, 3)
        }
    }

    /// Best-fit preset for the values currently written to the domain.
    public static func matching(spacing: Int?, padding: Int?) -> MenuBarSpacingPreset {
        for preset in allCases where preset.values.spacing == spacing && preset.values.padding == padding {
            return preset
        }
        return .system
    }
}

@MainActor
final class MenuBarSpacingController {
    static let shared = MenuBarSpacingController()

    private let spacingKey = "NSStatusItemSpacing" as CFString
    private let paddingKey = "NSStatusItemSelectionPadding" as CFString
    private let appID = kCFPreferencesAnyApplication

    private init() {}

    func current() -> (spacing: Int?, padding: Int?) {
        (readInt(spacingKey), readInt(paddingKey))
    }

    func currentPreset() -> MenuBarSpacingPreset {
        let values = current()
        return MenuBarSpacingPreset.matching(spacing: values.spacing, padding: values.padding)
    }

    func apply(_ preset: MenuBarSpacingPreset) {
        let values = preset.values
        write(spacingKey, value: values.spacing)
        write(paddingKey, value: values.padding)
        CFPreferencesSynchronize(appID, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
    }

    func reset() {
        apply(.system)
    }

    // MARK: - CFPreferences

    private func readInt(_ key: CFString) -> Int? {
        let value = CFPreferencesCopyValue(key, appID, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        return (value as? NSNumber)?.intValue
    }

    private func write(_ key: CFString, value: Int?) {
        if let value {
            CFPreferencesSetValue(key, value as CFNumber, appID,
                                  kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        } else {
            CFPreferencesSetValue(key, nil, appID,
                                  kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        }
    }
}

#endif
