//
//  MenuBarManagerSettings.swift
//  Tonic
//
//  Persisted preferences for the Bartender-style menu bar item manager.
//

import Foundation

/// How hidden items are revealed when expanding.
public enum MenuBarRevealMode: String, Codable, Sendable, CaseIterable {
    /// Deflate the separators so items slide back onto the menu bar.
    case expand
    /// Show hidden items as icons in a floating Tonic Bar instead.
    case tonicBar

    public var title: String {
        switch self {
        case .expand: return "On the menu bar"
        case .tonicBar: return "In the Tonic Bar"
        }
    }
}

/// Optional cosmetic overlay drawn across the menu bar band.
public struct MenuBarStyling: Codable, Sendable, Equatable {
    public var isEnabled: Bool
    /// `#RRGGBB` tint; nil uses a neutral default.
    public var tintHex: String?
    public var usesGradient: Bool
    public var cornerRadius: Double
    public var opacity: Double

    public init(isEnabled: Bool = false, tintHex: String? = nil,
                usesGradient: Bool = false, cornerRadius: Double = 0, opacity: Double = 0.9) {
        self.isEnabled = isEnabled
        self.tintHex = tintHex
        self.usesGradient = usesGradient
        self.cornerRadius = max(0, min(16, cornerRadius))
        self.opacity = max(0.1, min(1, opacity))
    }
}

/// Behavior for hiding/revealing third-party menu bar items.
public struct MenuBarManagerSettings: Codable, Sendable, Equatable {
    /// Master switch: creates the separator + toggle status items.
    public var isEnabled: Bool
    /// Second separator for items that stay hidden even when expanded
    /// (revealed only via ⌥-click on the toggle).
    public var alwaysHiddenSectionEnabled: Bool
    /// Expand when the pointer dwells in the menu bar.
    public var showOnHover: Bool
    public var hoverDelaySeconds: Double
    /// Toggle when clicking an empty stretch of the menu bar.
    public var showOnClickEmptyMenuBar: Bool
    /// Collapse again after a delay once expanded.
    public var autoRehide: Bool
    public var rehideDelaySeconds: Double
    /// Collapse when another app becomes active.
    public var rehideOnFocusChange: Bool
    /// Where hidden items appear when revealed.
    public var revealMode: MenuBarRevealMode
    /// Cosmetic menu bar overlay.
    public var styling: MenuBarStyling

    public static let `default` = MenuBarManagerSettings()

    public init(
        isEnabled: Bool = false,
        alwaysHiddenSectionEnabled: Bool = false,
        showOnHover: Bool = false,
        hoverDelaySeconds: Double = 0.2,
        showOnClickEmptyMenuBar: Bool = false,
        autoRehide: Bool = true,
        rehideDelaySeconds: Double = 15,
        rehideOnFocusChange: Bool = false,
        revealMode: MenuBarRevealMode = .expand,
        styling: MenuBarStyling = MenuBarStyling()
    ) {
        self.isEnabled = isEnabled
        self.alwaysHiddenSectionEnabled = alwaysHiddenSectionEnabled
        self.showOnHover = showOnHover
        self.hoverDelaySeconds = max(0, min(2, hoverDelaySeconds))
        self.showOnClickEmptyMenuBar = showOnClickEmptyMenuBar
        self.autoRehide = autoRehide
        self.rehideDelaySeconds = max(2, min(120, rehideDelaySeconds))
        self.rehideOnFocusChange = rehideOnFocusChange
        self.revealMode = revealMode
        self.styling = styling
    }

    // Tolerant decoding with clamped values, matching the house settings style.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            isEnabled: try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false,
            alwaysHiddenSectionEnabled: try container.decodeIfPresent(Bool.self, forKey: .alwaysHiddenSectionEnabled) ?? false,
            showOnHover: try container.decodeIfPresent(Bool.self, forKey: .showOnHover) ?? false,
            hoverDelaySeconds: try container.decodeIfPresent(Double.self, forKey: .hoverDelaySeconds) ?? 0.2,
            showOnClickEmptyMenuBar: try container.decodeIfPresent(Bool.self, forKey: .showOnClickEmptyMenuBar) ?? false,
            autoRehide: try container.decodeIfPresent(Bool.self, forKey: .autoRehide) ?? true,
            rehideDelaySeconds: try container.decodeIfPresent(Double.self, forKey: .rehideDelaySeconds) ?? 15,
            rehideOnFocusChange: try container.decodeIfPresent(Bool.self, forKey: .rehideOnFocusChange) ?? false,
            revealMode: try container.decodeIfPresent(MenuBarRevealMode.self, forKey: .revealMode) ?? .expand,
            styling: try container.decodeIfPresent(MenuBarStyling.self, forKey: .styling) ?? MenuBarStyling()
        )
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled, alwaysHiddenSectionEnabled
        case showOnHover, hoverDelaySeconds
        case showOnClickEmptyMenuBar
        case autoRehide, rehideDelaySeconds, rehideOnFocusChange
        case revealMode, styling
    }
}

/// Persisted store; `MenuBarManager` re-applies behavior on every change.
@Observable
public final class MenuBarManagerSettingsStore: @unchecked Sendable {
    public static let shared = MenuBarManagerSettingsStore()
    private static let defaultsKey = "tonic.menuBarManager"

    public var settings: MenuBarManagerSettings {
        didSet {
            persist()
            NotificationCenter.default.post(name: .menuBarManagerSettingsDidChange, object: nil)
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode(MenuBarManagerSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .default
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}

extension Notification.Name {
    public static let menuBarManagerSettingsDidChange = Notification.Name("tonic.menuBarManager.settingsDidChange")
}
