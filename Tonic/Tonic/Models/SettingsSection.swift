//
//  SettingsSection.swift
//  Tonic
//
//  Settings section model for the consolidated Settings IA. Extracted from the legacy
//  PreferencesView.swift so it survives the presentation-layer rewrite and can back
//  the `openSettingsSection` deep-links from the new shell.
//

import Foundation

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case modules = "Modules"
    case maintenance = "Maintenance"
    case permissions = "Permissions"
    case updates = "Updates"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .modules: return "square.grid.2x2.fill"
        case .maintenance: return "clock.arrow.2.circlepath"
        case .permissions: return "hand.raised.fill"
        case .updates: return "arrow.down.circle.fill"
        case .about: return "info.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .general: return "Appearance"
        case .modules: return "Widget configuration"
        case .maintenance: return "Scheduled care"
        case .permissions: return BuildCapabilities.current.requiresScopeAccess ? "Access & permissions" : "System access"
        case .updates: return "Software updates"
        case .about: return "App information"
        }
    }
}
