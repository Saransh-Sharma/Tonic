//
//  HotkeySettingsStore.swift
//  Tonic
//
//  Persists the global shortcut for each HotkeyAction slot. Replaces the
//  single PopupSettings.keyboardShortcut field (migrated once on first run).
//

import Foundation

/// The distinct global shortcuts Tonic can register. Each maps to a Carbon
/// EventHotKeyID; keep the ids stable.
public enum HotkeyAction: String, CaseIterable, Codable, Sendable {
    case toggleConsole
    case quickSearch
    case toggleMenuBar

    var hotKeyID: UInt32 {
        switch self {
        case .toggleConsole: return 1
        case .quickSearch: return 2
        case .toggleMenuBar: return 3
        }
    }

    public var title: String {
        switch self {
        case .toggleConsole: return "Toggle Console"
        case .quickSearch: return "Quick Search"
        case .toggleMenuBar: return "Show/Hide Menu Bar Items"
        }
    }

    public var subtitle: String {
        switch self {
        case .toggleConsole: return "Open the primary menu-bar widget console."
        case .quickSearch: return "Search and open any menu bar item from the keyboard."
        case .toggleMenuBar: return "Reveal or collapse hidden menu bar items."
        }
    }
}

@Observable
public final class HotkeySettingsStore: @unchecked Sendable {
    public static let shared = HotkeySettingsStore()
    private static let defaultsKey = "tonic.hotkeys"

    /// action.rawValue → ShortcutSpec.stringValue
    public private(set) var shortcuts: [HotkeyAction: String] {
        didSet {
            persist()
            NotificationCenter.default.post(name: .hotkeySettingsDidChange, object: nil)
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            var map: [HotkeyAction: String] = [:]
            for (key, value) in decoded {
                if let action = HotkeyAction(rawValue: key) { map[action] = value }
            }
            shortcuts = map
        } else {
            shortcuts = [:]
        }
        migrateLegacyConsoleShortcutIfNeeded()
    }

    public func spec(for action: HotkeyAction) -> ShortcutSpec? {
        shortcuts[action].flatMap(ShortcutSpec.init(string:))
    }

    public func setShortcut(_ spec: ShortcutSpec?, for action: HotkeyAction) {
        if let spec {
            shortcuts[action] = spec.stringValue
        } else {
            shortcuts.removeValue(forKey: action)
        }
    }

    /// One-way import of the old single-shortcut field into the console slot.
    /// The legacy value is left in place for downgrade safety.
    private func migrateLegacyConsoleShortcutIfNeeded() {
        guard shortcuts[.toggleConsole] == nil,
              let legacy = PopupSettingsStore.shared.settings.keyboardShortcut,
              ShortcutSpec(string: legacy) != nil else { return }
        shortcuts[.toggleConsole] = legacy
    }

    private func persist() {
        let raw = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(raw) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}

extension Notification.Name {
    public static let hotkeySettingsDidChange = Notification.Name("tonic.hotkeySettingsDidChange")
}
