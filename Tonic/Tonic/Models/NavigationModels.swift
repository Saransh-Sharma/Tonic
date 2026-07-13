//
//  NavigationModels.swift
//  Tonic
//
//  Shared navigation models
//

import SwiftUI
import Foundation

enum TonicUserDefaultsKey {
    static let powerUserModeEnabled = "tonic.powerUserMode.enabled"
    /// Clutter scan depth preference: "quick" (default) or "deep".
    static let clutterScanDepth = "tonic.clutterScanDepth"
}

enum TonicUserMode: String, CaseIterable, Identifiable {
    case standard
    case powerUser

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "Standard"
        case .powerUser: return "Power User"
        }
    }

    var subtitle: String {
        switch self {
        case .standard:
            return "A calm command center with safe defaults and review-first cleanup."
        case .powerUser:
            return "Reveals developer caches, path-level detail, and advanced scan context."
        }
    }

    var icon: String {
        switch self {
        case .standard: return "checkmark.shield.fill"
        case .powerUser: return "slider.horizontal.3"
        }
    }
}

enum WIPFeature: String, CaseIterable {
    case activity
    case storageHub
    case developerTools
    case designSandbox

    var displayName: String {
        switch self {
        case .activity: return "Activity"
        case .storageHub: return "Storage Hub"
        case .developerTools: return "Developer Tools"
        case .designSandbox: return "Design Sandbox"
        }
    }

    var icon: String {
        switch self {
        case .activity: return "gauge"
        case .storageHub: return "externaldrive.fill"
        case .developerTools: return "hammer.fill"
        case .designSandbox: return "paintbrush.fill"
        }
    }

    /// Labs features have passed hardening and ship in Release builds with a
    /// Settings toggle. The rest stay DEBUG-only.
    var isLabs: Bool {
        switch self {
        case .activity, .storageHub: return true
        case .developerTools, .designSandbox: return false
        }
    }
}

enum FeatureFlags {
    static func isEnabled(_ feature: WIPFeature) -> Bool {
        let key = key(for: feature)
        let defaults = UserDefaults.standard
        if defaults.object(forKey: key) != nil {
            return defaults.bool(forKey: key)
        }
        #if DEBUG
        return true
        #else
        // Labs features default on in Release; dev-only surfaces never ship.
        return feature.isLabs
        #endif
    }

    static func isEnabled(_ destination: NavigationDestination) -> Bool {
        guard let wipFeature = destination.wipFeature else {
            return true
        }
        return isEnabled(wipFeature)
    }

    /// Persist a user's Labs toggle (or a DEBUG override).
    static func set(_ feature: WIPFeature, enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: key(for: feature))
    }

    static func clearOverride(_ feature: WIPFeature) {
        UserDefaults.standard.removeObject(forKey: key(for: feature))
    }

    static func clearAllOverrides() {
        WIPFeature.allCases.forEach(clearOverride)
    }

    private static func key(for feature: WIPFeature) -> String {
        "tonic.ff.\(feature.rawValue)"
    }
}

enum NavigationDestination: String, CaseIterable {
    case dashboard = "Dashboard"
    case systemCleanup = "System Cleanup"
    case appManager = "App Manager"
    case diskAnalysis = "Storage Hub"
    case recentlyCleaned = "Recently Cleaned"
    case liveMonitoring = "Live Monitoring"
    case menuBarManager = "Menu Bar"
    case menuBarWidgets = "Menu Bar Widgets"
    case developerTools = "Developer Tools"
    case designSandbox = "Design Sandbox"
    case settings = "Settings"

    var systemImage: String {
        switch self {
        case .dashboard: return "chart.line.uptrend.xyaxis"
        case .systemCleanup: return "shield.lefthalf.filled.badge.checkmark"
        case .appManager: return "app.badge"
        case .diskAnalysis: return "externaldrive.fill"
        case .recentlyCleaned: return "clock.arrow.circlepath"
        case .liveMonitoring: return "gauge"
        case .menuBarManager: return "menubar.rectangle"
        case .menuBarWidgets: return "square.grid.2x2"
        case .developerTools: return "hammer.fill"
        case .designSandbox: return "paintbrush.fill"
        case .settings: return "gear"
        }
    }

    var displayName: String {
        self.rawValue
    }

    var wipFeature: WIPFeature? {
        switch self {
        case .diskAnalysis: return .storageHub
        case .liveMonitoring: return .activity
        case .developerTools: return .developerTools
        case .designSandbox: return .designSandbox
        default: return nil
        }
    }

    static func sanitize(_ destination: NavigationDestination) -> NavigationDestination {
        guard !FeatureFlags.isEnabled(destination) else {
            return destination
        }

        switch destination {
        case .diskAnalysis, .liveMonitoring:
            return .dashboard
        case .developerTools, .designSandbox:
            return .settings
        default:
            return .dashboard
        }
    }
}

extension Notification.Name {
    static let featureFlagsDidChange = Notification.Name("tonic.featureFlagsDidChange")
    /// Main-menu navigation (⌘1–⌘5). userInfo["destination"] = NavigationDestination.rawValue.
    static let navigateToDestination = Notification.Name("tonic.navigateToDestination")
    /// Tools ▸ Run Smart Scan.
    static let runSmartScanCommand = Notification.Name("tonic.runSmartScanCommand")
    /// userInfo["path"]: String — folder chosen via File ▸ Scan Folder… or a Dock drop.
    static let scanFolderCommand = Notification.Name("tonic.scanFolderCommand")
}
