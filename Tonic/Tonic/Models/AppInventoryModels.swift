//
//  AppInventoryModels.swift
//  Tonic
//
//  Data models for the App Manager feature.
//

import Foundation

// MARK: - Item Type Classification

/// Item type classification for discovered apps and system components
enum ItemType: String, CaseIterable, Identifiable {
    case apps = "Apps"
    case appExtensions = "App Extensions"
    case preferencePanes = "Preference Panes"
    case quickLookPlugins = "Quick Look Plugins"
    case spotlightImporters = "Spotlight Importers"
    case frameworks = "Frameworks & Runtimes"
    case systemUtilities = "System Utilities"
    case loginItems = "Login Items & Agents"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .apps: return "app.fill"
        case .appExtensions: return "puzzlepiece.extension"
        case .preferencePanes: return "slider.horizontal.3"
        case .quickLookPlugins: return "eye"
        case .spotlightImporters: return "magnifyingglass"
        case .frameworks: return "cube.box"
        case .systemUtilities: return "wrench.and.screwdriver"
        case .loginItems: return "person.2"
        }
    }
}

// MARK: - Quick Filter Categories

/// Quick filter categories for items
enum QuickFilterCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case leastUsed = "Least Used"
    case development = "Development"
    case games = "Games"
    case productivity = "Productivity"
    case utilities = "Utilities"
    case social = "Social"
    case creative = "Creative"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .leastUsed: return "clock.arrow.circlepath"
        case .development: return "hammer"
        case .games: return "gamecontroller"
        case .productivity: return "checkmark.circle"
        case .utilities: return "wrench.and.screwdriver"
        case .social: return "person.2"
        case .creative: return "paintbrush"
        case .other: return "ellipsis"
        }
    }
}

// MARK: - Login Item Filter

/// Quick filter specifically for login items
enum LoginItemFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case launchAgents = "Launch Agents"
    case daemons = "Daemons"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .launchAgents: return "gear.circle.fill"
        case .daemons: return "gearshape.2.fill"
        }
    }
}

// MARK: - View Mode

/// Display mode for the app list (list vs grid)
enum AppViewMode: String, CaseIterable {
    case list
    case grid
}

// MARK: - Fast App Data

/// Fast app data without size (used during initial scan phase)
struct FastAppData: Sendable {
    let name: String
    let path: String
    let bundleIdentifier: String
    let version: String
    let installDate: Date
    let category: AppMetadata.AppCategory
    var totalSize: Int64
    let itemType: ItemType
}
