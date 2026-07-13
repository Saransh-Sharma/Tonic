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
    /// Show hidden items in the floating Quick Shelf. The raw value remains
    /// `tonicBar` so existing preferences migrate without a rewrite.
    case tonicBar

    public var title: String {
        switch self {
        case .expand: return "On the menu bar"
        case .tonicBar: return "In Quick Shelf"
        }
    }
}

public enum QuickShelfPresentation: String, Codable, Sendable, CaseIterable {
    case compactStrip
    case labeledGrid
    case searchableList

    public var title: String {
        switch self {
        case .compactStrip: return "Compact icons"
        case .labeledGrid: return "Labeled grid"
        case .searchableList: return "Searchable list"
        }
    }
}

public enum MenuBarStylePreset: String, CaseIterable, Identifiable, Sendable {
    case clear
    case mineralGlass
    case obsidian
    case matchWallpaper

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .clear: return "Clear"
        case .mineralGlass: return "Mineral Glass"
        case .obsidian: return "Obsidian"
        case .matchWallpaper: return "Match Wallpaper"
        }
    }
    public var styling: MenuBarStyling {
        switch self {
        case .clear:
            return MenuBarStyling(isEnabled: false)
        case .mineralGlass:
            return MenuBarStyling(isEnabled: true, tintHex: "#526B88", gradientEndHex: "#5C8C84",
                                  usesGradient: true, borderWidth: 0.5, shadowStrength: 0.22,
                                  cornerRadius: 11, opacity: 0.58, isFullWidth: false)
        case .obsidian:
            return MenuBarStyling(isEnabled: true, tintHex: "#11151C", gradientEndHex: "#232A36",
                                  usesGradient: true, borderWidth: 0.5, shadowStrength: 0.4,
                                  cornerRadius: 8, opacity: 0.92, isFullWidth: true)
        case .matchWallpaper:
            return MenuBarStyling(isEnabled: true, tintHex: "#536A76", gradientEndHex: "#7B6978",
                                  usesGradient: true, borderWidth: 0.5, shadowStrength: 0.2,
                                  cornerRadius: 10, opacity: 0.66, isFullWidth: true,
                                  matchesWallpaper: true)
        }
    }
}

/// Optional cosmetic overlay drawn across the menu bar band.
public struct MenuBarStyling: Codable, Sendable, Equatable {
    public var isEnabled: Bool
    /// `#RRGGBB` tint; nil uses a neutral default.
    public var tintHex: String?
    public var gradientEndHex: String?
    public var usesGradient: Bool
    public var borderWidth: Double
    public var shadowStrength: Double
    public var cornerRadius: Double
    public var opacity: Double
    public var isFullWidth: Bool
    public var matchesWallpaper: Bool

    public init(isEnabled: Bool = false, tintHex: String? = nil,
                gradientEndHex: String? = nil, usesGradient: Bool = false,
                borderWidth: Double = 0, shadowStrength: Double = 0.2,
                cornerRadius: Double = 0, opacity: Double = 0.9,
                isFullWidth: Bool = true, matchesWallpaper: Bool = false) {
        self.isEnabled = isEnabled
        self.tintHex = tintHex
        self.gradientEndHex = gradientEndHex
        self.usesGradient = usesGradient
        self.borderWidth = max(0, min(4, borderWidth))
        self.shadowStrength = max(0, min(1, shadowStrength))
        self.cornerRadius = max(0, min(16, cornerRadius))
        self.opacity = max(0.1, min(1, opacity))
        self.isFullWidth = isFullWidth
        self.matchesWallpaper = matchesWallpaper
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            isEnabled: try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false,
            tintHex: try container.decodeIfPresent(String.self, forKey: .tintHex),
            gradientEndHex: try container.decodeIfPresent(String.self, forKey: .gradientEndHex),
            usesGradient: try container.decodeIfPresent(Bool.self, forKey: .usesGradient) ?? false,
            borderWidth: try container.decodeIfPresent(Double.self, forKey: .borderWidth) ?? 0,
            shadowStrength: try container.decodeIfPresent(Double.self, forKey: .shadowStrength) ?? 0.2,
            cornerRadius: try container.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? 0,
            opacity: try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 0.9,
            isFullWidth: try container.decodeIfPresent(Bool.self, forKey: .isFullWidth) ?? true,
            matchesWallpaper: try container.decodeIfPresent(Bool.self, forKey: .matchesWallpaper) ?? false
        )
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
    /// Reveal from a two-finger swipe or scroll in the menu-bar band.
    public var showOnScroll: Bool
    /// Collapse again after a delay once expanded.
    public var autoRehide: Bool
    public var rehideDelaySeconds: Double
    /// Collapse when another app becomes active.
    public var rehideOnFocusChange: Bool
    /// Avoid surprise overlays while the active app occupies a full-screen Space.
    public var suppressInFullScreen: Bool
    /// Hide managed items on menu bars that are not under the pointer.
    public var hideOnInactiveDisplays: Bool
    /// Where hidden items appear when revealed.
    public var revealMode: MenuBarRevealMode
    public var quickShelfPresentation: QuickShelfPresentation
    /// Cosmetic menu bar overlay.
    public var styling: MenuBarStyling

    public static let `default` = MenuBarManagerSettings()

    public init(
        isEnabled: Bool = false,
        alwaysHiddenSectionEnabled: Bool = false,
        showOnHover: Bool = true,
        hoverDelaySeconds: Double = 0.2,
        showOnClickEmptyMenuBar: Bool = true,
        showOnScroll: Bool = true,
        autoRehide: Bool = true,
        rehideDelaySeconds: Double = 15,
        rehideOnFocusChange: Bool = false,
        suppressInFullScreen: Bool = true,
        hideOnInactiveDisplays: Bool = false,
        revealMode: MenuBarRevealMode = .expand,
        quickShelfPresentation: QuickShelfPresentation = .compactStrip,
        styling: MenuBarStyling = MenuBarStyling()
    ) {
        self.isEnabled = isEnabled
        self.alwaysHiddenSectionEnabled = alwaysHiddenSectionEnabled
        self.showOnHover = showOnHover
        self.hoverDelaySeconds = max(0, min(2, hoverDelaySeconds))
        self.showOnClickEmptyMenuBar = showOnClickEmptyMenuBar
        self.showOnScroll = showOnScroll
        self.autoRehide = autoRehide
        self.rehideDelaySeconds = max(2, min(120, rehideDelaySeconds))
        self.rehideOnFocusChange = rehideOnFocusChange
        self.suppressInFullScreen = suppressInFullScreen
        self.hideOnInactiveDisplays = hideOnInactiveDisplays
        self.revealMode = revealMode
        self.quickShelfPresentation = quickShelfPresentation
        self.styling = styling
    }

    // Tolerant decoding with clamped values, matching the house settings style.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            isEnabled: try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false,
            alwaysHiddenSectionEnabled: try container.decodeIfPresent(Bool.self, forKey: .alwaysHiddenSectionEnabled) ?? false,
            showOnHover: try container.decodeIfPresent(Bool.self, forKey: .showOnHover) ?? true,
            hoverDelaySeconds: try container.decodeIfPresent(Double.self, forKey: .hoverDelaySeconds) ?? 0.2,
            showOnClickEmptyMenuBar: try container.decodeIfPresent(Bool.self, forKey: .showOnClickEmptyMenuBar) ?? true,
            showOnScroll: try container.decodeIfPresent(Bool.self, forKey: .showOnScroll) ?? true,
            autoRehide: try container.decodeIfPresent(Bool.self, forKey: .autoRehide) ?? true,
            rehideDelaySeconds: try container.decodeIfPresent(Double.self, forKey: .rehideDelaySeconds) ?? 15,
            rehideOnFocusChange: try container.decodeIfPresent(Bool.self, forKey: .rehideOnFocusChange) ?? false,
            suppressInFullScreen: try container.decodeIfPresent(Bool.self, forKey: .suppressInFullScreen) ?? true,
            hideOnInactiveDisplays: try container.decodeIfPresent(Bool.self, forKey: .hideOnInactiveDisplays) ?? false,
            revealMode: try container.decodeIfPresent(MenuBarRevealMode.self, forKey: .revealMode) ?? .expand,
            quickShelfPresentation: try container.decodeIfPresent(QuickShelfPresentation.self, forKey: .quickShelfPresentation) ?? .compactStrip,
            styling: try container.decodeIfPresent(MenuBarStyling.self, forKey: .styling) ?? MenuBarStyling()
        )
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled, alwaysHiddenSectionEnabled
        case showOnHover, hoverDelaySeconds
        case showOnClickEmptyMenuBar, showOnScroll
        case autoRehide, rehideDelaySeconds, rehideOnFocusChange
        case suppressInFullScreen, hideOnInactiveDisplays
        case revealMode, quickShelfPresentation, styling
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
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode(MenuBarManagerSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .default
        }
        // Wave 4 deliberately enables every non-keyboard reveal path for all
        // existing users while retaining their delay, rehide, sections, and style.
        if defaults.integer(forKey: "tonic.menuBarRevealMigrationVersion") < 2 {
            settings.showOnHover = true
            settings.showOnClickEmptyMenuBar = true
            settings.showOnScroll = true
            defaults.set(2, forKey: "tonic.menuBarRevealMigrationVersion")
            persist()
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
