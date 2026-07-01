//
//  Recommendation.swift
//  Tonic
//
//  Dashboard/scan recommendation model. Extracted from the legacy
//  DashboardSupport.swift view file so it survives the presentation-layer rewrite.
//

import SwiftUI

// MARK: - Recommendation Model

struct Recommendation: Identifiable, Equatable {
    let id: UUID
    let title: String
    let description: String
    let type: RecommendationType
    let category: RecommendationCategory
    let priority: Priority
    let actionText: String
    let scanRecommendation: ScanRecommendation
    let scoreImpact: Int
    var isCompleted: Bool = false

    init(
        scanRecommendation: ScanRecommendation,
        type: RecommendationType,
        category: RecommendationCategory,
        priority: Priority,
        actionText: String
    ) {
        id = scanRecommendation.id
        title = scanRecommendation.title
        description = scanRecommendation.description
        self.type = type
        self.category = category
        self.priority = priority
        self.actionText = actionText
        self.scanRecommendation = scanRecommendation
        scoreImpact = scanRecommendation.scoreImpact
    }

    /// Category for grouping recommendations
    enum RecommendationCategory: String, CaseIterable {
        case cache = "Cache"
        case logs = "Logs"
        case system = "System"
        case apps = "Apps"
        case other = "Other"
    }

    enum RecommendationType {
        case clean
        case optimize
        case update
        case security

        var icon: String {
            switch self {
            case .clean: return "trash.fill"
            case .optimize: return "speedometer"
            case .update: return "arrow.up.circle.fill"
            case .security: return "checkmark.shield.fill"
            }
        }

        /// The recommendation *type* is taxonomy, not machine state — its icon uses a
        /// neutral ink tint. Status/urgency color lives on `Priority` (the data), never here,
        /// and brand coral never touches a data row.
        var color: Color {
            TonicDS.Colors.textPrimary
        }
    }

    /// RAG priority coding: High=red, Medium=orange, Low=blue/gray
    enum Priority: CaseIterable {
        case critical
        case high
        case medium
        case low

        var color: Color {
            switch self {
            case .critical: return TonicDS.Colors.statusCritical
            case .high: return TonicDS.Colors.statusCaution
            case .medium: return TonicDS.Colors.statusWarning
            case .low: return TonicDS.Colors.statusInfo
            }
        }

        var backgroundColor: Color {
            color.opacity(0.1)
        }

        var label: String {
            switch self {
            case .critical: return "Critical"
            case .high: return "High"
            case .medium: return "Medium"
            case .low: return "Low"
            }
        }

        var icon: String {
            switch self {
            case .critical: return "exclamationmark.circle.fill"
            case .high: return "exclamationmark.triangle.fill"
            case .medium: return "info.circle.fill"
            case .low: return "checkmark.circle.fill"
            }
        }

        var sortOrder: Int {
            switch self {
            case .critical: return 0
            case .high: return 1
            case .medium: return 2
            case .low: return 3
            }
        }
    }

    static func == (lhs: Recommendation, rhs: Recommendation) -> Bool {
        lhs.id == rhs.id
    }
}
