//
//  NavigationModels.swift
//  Tonic
//
//  Shared navigation models
//

import SwiftUI
import Foundation

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
}

enum FeatureFlags {
    private static let defaults = UserDefaults.standard

    static func isEnabled(_ feature: WIPFeature) -> Bool {
        #if DEBUG
        let key = key(for: feature)
        if defaults.object(forKey: key) != nil {
            return defaults.bool(forKey: key)
        }
        return true
        #else
        return false
        #endif
    }

    static func isEnabled(_ destination: NavigationDestination) -> Bool {
        guard let wipFeature = destination.wipFeature else {
            return true
        }
        return isEnabled(wipFeature)
    }

    #if DEBUG
    static func set(_ feature: WIPFeature, enabled: Bool) {
        defaults.set(enabled, forKey: key(for: feature))
    }

    static func clearOverride(_ feature: WIPFeature) {
        defaults.removeObject(forKey: key(for: feature))
    }

    static func clearAllOverrides() {
        WIPFeature.allCases.forEach(clearOverride)
    }
    #endif

    private static func key(for feature: WIPFeature) -> String {
        "tonic.ff.\(feature.rawValue)"
    }
}

enum NavigationDestination: String, CaseIterable {
    case dashboard = "Dashboard"
    case systemCleanup = "System Cleanup"
    case appManager = "App Manager"
    case diskAnalysis = "Storage Hub"
    case liveMonitoring = "Live Monitoring"
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
        case .liveMonitoring: return "gauge"
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
}
