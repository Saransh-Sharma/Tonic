//
//  ActivityLogModels.swift
//  Tonic
//
//  Persistent activity log models
//

import SwiftUI

enum ActivityCategory: String, Codable, CaseIterable {
    case install
    case update
    case scan
    case clean
    case optimize
    case app
    case disk
    case notification
    case preference
    case alert
    case info

    var icon: String {
        switch self {
        case .install: return "sparkles"
        case .update: return "arrow.up.circle.fill"
        case .scan: return "magnifyingglass"
        case .clean: return "sparkles"
        case .optimize: return "gearshape.2"
        case .app: return "app.badge"
        case .disk: return "externaldrive.fill"
        case .notification: return "bell.fill"
        case .preference: return "slider.horizontal.3"
        case .alert: return "exclamationmark.triangle.fill"
        case .info: return "info.circle"
        }
    }

    var color: Color {
        switch self {
        case .install: return DesignTokens.Colors.success
        case .update: return DesignTokens.Colors.accent
        case .scan: return DesignTokens.Colors.accent
        case .clean: return DesignTokens.Colors.success
        case .optimize: return DesignTokens.Colors.info
        case .app: return DesignTokens.Colors.accent
        case .disk: return DesignTokens.Colors.warning
        case .notification: return DesignTokens.Colors.warning
        case .preference: return DesignTokens.Colors.textSecondary
        case .alert: return DesignTokens.Colors.error
        case .info: return DesignTokens.Colors.textSecondary
        }
    }
}

enum ActivityImpact: String, Codable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    case none = "None"

    var color: Color {
        switch self {
        case .high: return DesignTokens.Colors.error
        case .medium: return DesignTokens.Colors.warning
        case .low: return DesignTokens.Colors.success
        case .none: return DesignTokens.Colors.textSecondary
        }
    }
}

struct ActivityEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let category: ActivityCategory
    let title: String
    let detail: String
    let impact: ActivityImpact
    let metadata: [String: String]?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: ActivityCategory,
        title: String,
        detail: String,
        impact: ActivityImpact = .none,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.title = title
        self.detail = detail
        self.impact = impact
        self.metadata = metadata
    }
}
