//
//  SmartScanIAModels.swift
//  Tonic
//
//  IA mappings and deep-link contracts for Smart Scan review actions.
//

import Foundation

enum SmartScanPillar: String, CaseIterable, Identifiable, Sendable {
    case space = "Space"
    case performance = "Performance"
    case apps = "Apps"

    var id: String { rawValue }
}

enum SmartScanReviewTarget: Hashable {
    case section(SmartScanPillar)
    case contributor(id: String)
}

enum SmartScanDeepLinkMapper {
    static func destination(for target: SmartScanReviewTarget) -> Destination {
        switch target {
        case .section(.space):
            return .manager(.space(.spaceRoot))
        case .section(.performance):
            return .manager(.performance(.root(defaultNav: .maintenanceTasks)))
        case .section(.apps):
            return .manager(.apps(.root(defaultNav: .uninstaller)))

        case .contributor(let id):
            switch id {
            case "xcodeJunk":
                return .manager(.space(.cleanup(.systemJunk, categoryId: CleanupCategoryID(raw: "xcodeJunk"), rowId: nil)))
            case "downloads":
                return .manager(.space(.clutter(.downloads, filter: .allFiles, groupId: nil, fileId: nil)))
            case "duplicates":
                return .manager(.space(.clutter(.duplicates, filter: .allFiles, groupId: nil, fileId: nil)))
            case "maintenanceTasks":
                return .manager(.performance(.maintenanceTasks(preselectTaskIds: nil)))
            case "backgroundItems":
                return .manager(.performance(.backgroundItems(preselectItemIds: nil)))
            case "loginItems":
                return .manager(.performance(.loginItems(preselectItemIds: nil)))
            case "uninstaller":
                return .manager(.apps(.uninstaller(filter: .all)))
            case "updater":
                return .manager(.apps(.updater))
            case "leftovers":
                return .manager(.apps(.leftovers))
            default:
                return .smartScan
            }
        }
    }
}

struct SmartScanSectionSummary: Sendable {
    let pillar: SmartScanPillar
    let metricText: String
    let contributors: [String]
}
