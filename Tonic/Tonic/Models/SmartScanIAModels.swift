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

enum SmartScanTileID: String, CaseIterable, Hashable, Sendable, Identifiable {
    case spaceSystemJunk
    case spaceTrashBins
    case spaceExtraBinaries
    case spaceXcodeJunk
    case performanceMaintenanceTasks
    case performanceLoginItems
    case performanceBackgroundItems
    case appsUpdates
    case appsUnused
    case appsLeftovers
    case appsInstallationFiles

    var id: String { rawValue }

    var pillar: SmartScanPillar {
        switch self {
        case .spaceSystemJunk, .spaceTrashBins, .spaceExtraBinaries, .spaceXcodeJunk:
            return .space
        case .performanceMaintenanceTasks, .performanceLoginItems, .performanceBackgroundItems:
            return .performance
        case .appsUpdates, .appsUnused, .appsLeftovers, .appsInstallationFiles:
            return .apps
        }
    }
}

enum SmartScanTileActionKind: String, Hashable, Sendable {
    case review
    case clean
    case remove
    case run
    case update
}

enum SmartScanQuickActionScope: Hashable, Sendable {
    case tile(SmartScanTileID)
}

enum SmartScanBentoTileSize: Hashable, Sendable {
    case large
    case wide
    case small
}

struct SmartScanBentoTileActionModel: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let kind: SmartScanTileActionKind
    let enabled: Bool

    init(title: String, kind: SmartScanTileActionKind, enabled: Bool = true) {
        self.id = "\(kind.rawValue)-\(title)"
        self.title = title
        self.kind = kind
        self.enabled = enabled
    }
}

struct SmartScanBentoTileModel: Identifiable, Hashable, Sendable {
    let id: SmartScanTileID
    let size: SmartScanBentoTileSize
    let metricTitle: String
    let title: String
    let subtitle: String
    let iconSymbols: [String]
    let reviewTarget: SmartScanReviewTarget
    let actions: [SmartScanBentoTileActionModel]
}

struct SmartScanPillarSectionModel: Identifiable, Hashable, Sendable {
    let pillar: SmartScanPillar
    let title: String
    let subtitle: String
    let summary: String
    let sectionActionTitle: String
    let sectionReviewTarget: SmartScanReviewTarget
    let world: TonicWorld
    let tiles: [SmartScanBentoTileModel]

    var id: String { pillar.rawValue }
}

enum SmartScanReviewTarget: Hashable {
    case section(SmartScanPillar)
    case contributor(id: String)
    case tile(SmartScanTileID)
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

        case .tile(let tileID):
            switch tileID {
            case .spaceSystemJunk:
                return .manager(.space(.cleanup(.systemJunk, categoryId: CleanupCategoryID(raw: "systemJunk"), rowId: nil)))
            case .spaceTrashBins:
                return .manager(.space(.cleanup(.trashBins, categoryId: CleanupCategoryID(raw: "trashBins"), rowId: nil)))
            case .spaceExtraBinaries:
                return .manager(.space(.cleanup(.hiddenSpace, categoryId: CleanupCategoryID(raw: "hiddenSpace"), rowId: nil)))
            case .spaceXcodeJunk:
                return .manager(.space(.cleanup(.systemJunk, categoryId: CleanupCategoryID(raw: "xcodeJunk"), rowId: nil)))
            case .performanceMaintenanceTasks:
                return .manager(.performance(.maintenanceTasks(preselectTaskIds: nil)))
            case .performanceLoginItems:
                return .manager(.performance(.loginItems(preselectItemIds: nil)))
            case .performanceBackgroundItems:
                return .manager(.performance(.backgroundItems(preselectItemIds: nil)))
            case .appsUpdates:
                return .manager(.apps(.updater))
            case .appsUnused:
                return .manager(.apps(.uninstaller(filter: .unused)))
            case .appsLeftovers:
                return .manager(.apps(.leftovers))
            case .appsInstallationFiles:
                return .manager(.apps(.uninstaller(filter: .large)))
            }

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
