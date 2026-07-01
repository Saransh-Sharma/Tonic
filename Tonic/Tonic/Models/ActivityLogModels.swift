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

    /// Activity category is taxonomy — the icon uses a neutral ink tint. Urgency/state color
    /// lives on `ActivityImpact` (the data). Brand coral never rides a log row.
    var color: Color {
        TonicDS.Colors.textPrimary
    }
}

enum ActivityImpact: String, Codable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    case none = "None"

    var color: Color {
        switch self {
        case .high: return TonicDS.Colors.statusCritical
        case .medium: return TonicDS.Colors.statusWarning
        case .low: return TonicDS.Colors.statusSuccess
        case .none: return TonicDS.Colors.textMuted
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
