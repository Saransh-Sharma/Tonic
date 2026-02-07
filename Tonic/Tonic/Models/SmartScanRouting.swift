//
//  SmartScanRouting.swift
//  Tonic
//
//  Route models for Smart Scan hub -> manager deep links.
//

import Foundation

enum Destination: Hashable {
    case smartScan
    case manager(ManagerRoute)
}

enum ManagerRoute: Hashable {
    case space(SpaceFocus)
    case performance(PerformanceFocus)
    case apps(AppsFocus)
}

struct CleanupCategoryID: Hashable, Sendable {
    let raw: String
}

struct CleanupRowID: Hashable, Sendable {
    let raw: String
}

struct DuplicateGroupID: Hashable, Sendable {
    let raw: String
}

struct FileID: Hashable, Sendable {
    let raw: String
}

struct TaskID: Hashable, Sendable {
    let raw: String
}

struct StartupItemID: Hashable, Sendable {
    let raw: String
}

enum CleanupNav: String, Hashable, Sendable {
    case systemJunk
    case mailAttachments
    case downloads
    case trashBins
    case xcodeJunk
    case hiddenSpace
}

enum ClutterNav: String, Hashable, Sendable {
    case downloads
    case duplicates
    case similarImages
    case largeOld
}

enum ClutterFilter: String, Hashable, Sendable {
    case allFiles
    case byKind
    case bySize
}

enum PerformanceNav: String, Hashable, Sendable {
    case maintenanceTasks
    case loginItems
    case backgroundItems
}

enum AppsNav: String, Hashable, Sendable {
    case uninstaller
    case updater
    case leftovers
}

enum AppFilter: String, Hashable, Sendable, CaseIterable {
    case all
    case unused
    case suspicious
    case large
}

enum SpaceFocus: Hashable {
    case spaceRoot
    case cleanup(CleanupNav, categoryId: CleanupCategoryID?, rowId: CleanupRowID?)
    case clutter(ClutterNav, filter: ClutterFilter?, groupId: DuplicateGroupID?, fileId: FileID?)
}

enum PerformanceFocus: Hashable {
    case root(defaultNav: PerformanceNav = .maintenanceTasks)
    case maintenanceTasks(preselectTaskIds: Set<TaskID>?)
    case loginItems(preselectItemIds: Set<StartupItemID>?)
    case backgroundItems(preselectItemIds: Set<StartupItemID>?)
}

enum AppsFocus: Hashable {
    case root(defaultNav: AppsNav = .uninstaller)
    case uninstaller(filter: AppFilter = .all)
    case updater
    case leftovers
}
