//
//  HotkeySettingsStore.swift
//  Tonic
//
//  Persists the global shortcut for each HotkeyAction slot. Replaces the
//  single PopupSettings.keyboardShortcut field (migrated once on first run).
//

import Carbon.HIToolbox
import Foundation

/// The distinct global shortcuts Tonic can register: three app-level slots plus
/// one slot per window-management action. Each maps to a Carbon EventHotKeyID;
/// keep the ids and storage keys stable — they live in UserDefaults.
public enum HotkeyAction: Hashable, CaseIterable, Codable, Sendable {
    case toggleConsole
    case quickSearch
    case toggleMenuBar
    case topShelf
    case window(WindowAction)

    public static var allCases: [HotkeyAction] {
        [.toggleConsole, .quickSearch, .toggleMenuBar, .topShelf]
            + WindowAction.allCases.map(HotkeyAction.window)
    }

    /// UserDefaults key. The three legacy cases keep their pre-Wave-4 rawValues
    /// so existing `tonic.hotkeys` payloads decode unchanged.
    public var storageKey: String {
        switch self {
        case .toggleConsole: return "toggleConsole"
        case .quickSearch: return "quickSearch"
        case .toggleMenuBar: return "toggleMenuBar"
        case .topShelf: return "topShelf"
        case .window(let action): return "window.\(action.rawValue)"
        }
    }

    public init?(storageKey: String) {
        switch storageKey {
        case "toggleConsole": self = .toggleConsole
        case "quickSearch": self = .quickSearch
        case "toggleMenuBar": self = .toggleMenuBar
        case "topShelf": self = .topShelf
        default:
            guard storageKey.hasPrefix("window."),
                  let action = WindowAction(rawValue: String(storageKey.dropFirst("window.".count)))
            else { return nil }
            self = .window(action)
        }
    }

    /// Carbon EventHotKeyID. 1–3 are the shipped app slots; window actions use
    /// an explicit table starting at 100 — NEVER derived from case order, so
    /// adding actions can't shuffle registrations.
    var hotKeyID: UInt32 {
        switch self {
        case .toggleConsole: return 1
        case .quickSearch: return 2
        case .toggleMenuBar: return 3
        case .topShelf: return 4
        case .window(let action): return Self.windowHotKeyIDs[action] ?? 0
        }
    }

    private static let windowHotKeyIDs: [WindowAction: UInt32] = [
        .leftHalf: 100, .rightHalf: 101, .topHalf: 102, .bottomHalf: 103,
        .topLeft: 104, .topRight: 105, .bottomLeft: 106, .bottomRight: 107,
        .maximize: 108, .centered: 109, .leftTwoThirds: 110, .rightTwoThirds: 111,
        .leftThird: 112, .centerThird: 113, .rightThird: 114,
        .topLeftSixth: 115, .topCenterSixth: 116, .topRightSixth: 117,
        .bottomLeftSixth: 118, .bottomCenterSixth: 119, .bottomRightSixth: 120,
        .nextDisplay: 121, .previousDisplay: 122
    ]

    public var title: String {
        switch self {
        case .toggleConsole: return "Toggle Console"
        case .quickSearch: return "Quick Search"
        case .toggleMenuBar: return "Show/Hide Menu Bar Items"
        case .topShelf: return "Show Top Shelf"
        case .window(let action): return action.title
        }
    }

    public var subtitle: String {
        switch self {
        case .toggleConsole: return "Open the primary menu-bar widget console."
        case .quickSearch: return "Search and open any menu bar item from the keyboard."
        case .toggleMenuBar: return "Reveal or collapse hidden menu bar items."
        case .topShelf: return "Open the contextual Top Shelf on the active display."
        case .window(let action):
            return action.isDisplayMove
                ? "Send the focused window to the \(action == .nextDisplay ? "next" : "previous") display."
                : "Place the focused window: \(action.title.lowercased())."
        }
    }

    /// Rectangle-style suggested shortcut, applied only by the explicit
    /// "Enable default window shortcuts" action — never on upgrade.
    public var recommendedDefault: ShortcutSpec? {
        let controlOption = UInt32(controlKey) | UInt32(optionKey)
        let controlOptionCommand = controlOption | UInt32(cmdKey)
        switch self {
        case .toggleConsole, .quickSearch, .toggleMenuBar, .topShelf:
            return nil
        case .window(let action):
            switch action {
            case .leftHalf: return ShortcutSpec(keyCode: UInt32(kVK_LeftArrow), carbonModifiers: controlOption)
            case .rightHalf: return ShortcutSpec(keyCode: UInt32(kVK_RightArrow), carbonModifiers: controlOption)
            case .topHalf: return ShortcutSpec(keyCode: UInt32(kVK_UpArrow), carbonModifiers: controlOption)
            case .bottomHalf: return ShortcutSpec(keyCode: UInt32(kVK_DownArrow), carbonModifiers: controlOption)
            case .topLeft: return ShortcutSpec(keyCode: UInt32(kVK_ANSI_U), carbonModifiers: controlOption)
            case .topRight: return ShortcutSpec(keyCode: UInt32(kVK_ANSI_I), carbonModifiers: controlOption)
            case .bottomLeft: return ShortcutSpec(keyCode: UInt32(kVK_ANSI_J), carbonModifiers: controlOption)
            case .bottomRight: return ShortcutSpec(keyCode: UInt32(kVK_ANSI_K), carbonModifiers: controlOption)
            case .maximize: return ShortcutSpec(keyCode: UInt32(kVK_Return), carbonModifiers: controlOption)
            case .centered: return ShortcutSpec(keyCode: UInt32(kVK_ANSI_C), carbonModifiers: controlOption)
            case .leftThird: return ShortcutSpec(keyCode: UInt32(kVK_ANSI_D), carbonModifiers: controlOption)
            case .centerThird: return ShortcutSpec(keyCode: UInt32(kVK_ANSI_F), carbonModifiers: controlOption)
            case .rightThird: return ShortcutSpec(keyCode: UInt32(kVK_ANSI_G), carbonModifiers: controlOption)
            case .leftTwoThirds: return ShortcutSpec(keyCode: UInt32(kVK_ANSI_E), carbonModifiers: controlOption)
            case .rightTwoThirds: return ShortcutSpec(keyCode: UInt32(kVK_ANSI_T), carbonModifiers: controlOption)
            case .nextDisplay: return ShortcutSpec(keyCode: UInt32(kVK_RightArrow), carbonModifiers: controlOptionCommand)
            case .previousDisplay: return ShortcutSpec(keyCode: UInt32(kVK_LeftArrow), carbonModifiers: controlOptionCommand)
            case .topLeftSixth, .topCenterSixth, .topRightSixth,
                 .bottomLeftSixth, .bottomCenterSixth, .bottomRightSixth:
                return nil
            }
        }
    }

    // Codable as the stable storage key (single string value).
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let key = try container.decode(String.self)
        guard let action = HotkeyAction(storageKey: key) else {
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Unknown HotkeyAction key: \(key)")
        }
        self = action
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storageKey)
    }
}

@Observable
public final class HotkeySettingsStore: @unchecked Sendable {
    public static let shared = HotkeySettingsStore()
    private static let defaultsKey = "tonic.hotkeys"

    /// action → ShortcutSpec.stringValue
    public private(set) var shortcuts: [HotkeyAction: String] {
        didSet {
            persist()
            NotificationCenter.default.post(name: .hotkeySettingsDidChange, object: nil)
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            shortcuts = Self.actionsByStorageKey(decoded)
        } else {
            shortcuts = [:]
        }
        migrateLegacyConsoleShortcutIfNeeded()
    }

    /// Pure decode of a persisted payload — unknown keys are dropped, the three
    /// legacy rawValue keys map to their original slots. (Kept static so tests
    /// can prove pre-Wave-4 payloads survive the enum restructure.)
    static func actionsByStorageKey(_ decoded: [String: String]) -> [HotkeyAction: String] {
        var map: [HotkeyAction: String] = [:]
        for (key, value) in decoded {
            if let action = HotkeyAction(storageKey: key) { map[action] = value }
        }
        return map
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

    /// The action already bound to `spec`, if any — for recorder conflict hints.
    public func action(boundTo spec: ShortcutSpec, excluding: HotkeyAction? = nil) -> HotkeyAction? {
        shortcuts.first { key, value in key != excluding && value == spec.stringValue }?.key
    }

    /// Fill every *unbound* window slot with its recommended default, skipping
    /// any combo already taken by another slot. Never overwrites, so it is safe
    /// to press repeatedly. Returns the number of shortcuts added.
    @discardableResult
    public func enableRecommendedWindowDefaults() -> Int {
        var next = shortcuts
        var taken = Set(next.values)
        var added = 0
        for action in HotkeyAction.allCases {
            guard case .window = action,
                  next[action] == nil,
                  let spec = action.recommendedDefault,
                  !taken.contains(spec.stringValue) else { continue }
            next[action] = spec.stringValue
            taken.insert(spec.stringValue)
            added += 1
        }
        if added > 0 { shortcuts = next }
        return added
    }

    /// Remove every window-slot binding (the app slots stay).
    public func clearWindowShortcuts() {
        let filtered = shortcuts.filter { key, _ in
            if case .window = key { return false }
            return true
        }
        if filtered.count != shortcuts.count { shortcuts = filtered }
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
        let raw = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.key.storageKey, $0.value) })
        if let data = try? JSONEncoder().encode(raw) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}

extension Notification.Name {
    public static let hotkeySettingsDidChange = Notification.Name("tonic.hotkeySettingsDidChange")
}
