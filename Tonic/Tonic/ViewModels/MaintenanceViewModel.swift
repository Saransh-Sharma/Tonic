//
//  MaintenanceViewModel.swift
//  Tonic
//
//  View model for Maintenance view - extracted state management
//  Handles scan and clean operations with comprehensive error handling
//

import Foundation

// MARK: - Maintenance State

@Observable
final class MaintenanceViewModel: @unchecked Sendable {
    private let smartScanEngine = SmartScanEngine()
    private let deepCleanEngine = DeepCleanEngine()
    private let lock = NSLock()

    // MARK: - Scan State

    private var _scanState: ScanState = ScanState()

    var scanState: ScanState {
        get { lock.locked { _scanState } }
        set { lock.locked { _scanState = newValue } }
    }

    // MARK: - Clean State

    private var _cleanState: CleanState = CleanState()

    var cleanState: CleanState {
        get { lock.locked { _cleanState } }
        set { lock.locked { _cleanState = newValue } }
    }

    // MARK: - UI State

    @MainActor var selectedTab: Int = 0
    @MainActor var showResults: Bool = false
    @MainActor var resultsSummary: String = ""

    // MARK: - Scan Operations

    @MainActor
    func startScan() async {
        scanState.isRunning = true
        scanState.progress = 0
        scanState.error = nil
        scanState.results = nil

        do {
            try validateScanStarting()

            var accumulatedProgress = 0.0

            for stage in ScanStage.allCases {
                if scanState.isCancelled {
                    break
                }

                let stageProgress = await smartScanEngine.runStage(stage)
                accumulatedProgress = stageProgress
                scanState.progress = min(accumulatedProgress / 100, 0.99)
            }

            scanState.isRunning = false
            scanState.progress = 1.0
            showResults = true

            logInfo("Scan completed successfully")

        } catch let error as TonicError {
            handleScanError(error)
        } catch {
            handleScanError(.scanFailed(reason: error.localizedDescription))
        }
    }

    @MainActor
    func cancelScan() {
        scanState.isCancelled = true
        scanState.isRunning = false
        logInfo("Scan cancelled by user")
    }

    @MainActor
    func dismissScanError() {
        scanState.error = nil
    }

    // MARK: - Clean Operations

    @MainActor
    func startCleaning(categories: [CleanCategory]) async {
        cleanState.isRunning = true
        cleanState.progress = 0
        cleanState.error = nil
        cleanState.results = nil

        do {
            try validateCleaningStarting()

            var totalBytes: Int64 = 0
            var processedCategories = 0

            for category in categories {
                if cleanState.isCancelled {
                    break
                }

                let result = try await deepCleanEngine.cleanCategory(category)
                totalBytes += result.bytesFreed
                processedCategories += 1

                cleanState.progress = Double(processedCategories) / Double(categories.count)
            }

            cleanState.isRunning = false
            cleanState.progress = 1.0
            cleanState.results = CleanResults(
                totalBytesFreed: totalBytes,
                categoriesCleaned: processedCategories,
                duration: Date()
            )
            showResults = true

            logInfo("Cleaning completed: \(totalBytes) bytes freed")

        } catch let error as TonicError {
            handleCleaningError(error)
        } catch {
            handleCleaningError(.cleaningFailed(category: "unknown", reason: error.localizedDescription))
        }
    }

    @MainActor
    func cancelCleaning() {
        cleanState.isCancelled = true
        cleanState.isRunning = false
        logInfo("Cleaning cancelled by user")
    }

    @MainActor
    func dismissCleanError() {
        cleanState.error = nil
    }

    // MARK: - Error Handling

    private func handleScanError(_ error: TonicError) {
        scanState.isRunning = false
        scanState.error = error
        logError("Scan failed: \(error.errorCode)")
    }

    private func handleCleaningError(_ error: TonicError) {
        cleanState.isRunning = false
        cleanState.error = error
        logError("Cleaning failed: \(error.errorCode)")
    }

    // MARK: - Validation

    private func validateScanStarting() throws {
        let permissionManager = PermissionManager.shared
        guard permissionManager.hasFullDiskAccess() else {
            throw TonicError.fullDiskAccessRequired
        }
    }

    private func validateCleaningStarting() throws {
        let permissionManager = PermissionManager.shared
        guard permissionManager.hasFullDiskAccess() else {
            throw TonicError.fullDiskAccessRequired
        }
    }

    // MARK: - Logging

    private func logInfo(_ message: String) {
        let logger = Logger(subsystem: "com.tonic.app", category: "Maintenance")
        logger.info("\(message)")
    }

    private func logError(_ message: String) {
        let logger = Logger(subsystem: "com.tonic.app", category: "Maintenance")
        logger.error("\(message)")
    }
}

// MARK: - Scan State

struct ScanState: Sendable {
    var isRunning = false
    var progress: Double = 0
    var results: ScanResults?
    var error: TonicError?
    var isCancelled = false
}

struct ScanResults: Sendable {
    let filesFound: Int
    let spaceRecoverable: Int64
    let duration: Date
}

// MARK: - Clean State

struct CleanState: Sendable {
    var isRunning = false
    var progress: Double = 0
    var results: CleanResults?
    var error: TonicError?
    var isCancelled = false
}

struct CleanResults: Sendable {
    let totalBytesFreed: Int64
    let categoriesCleaned: Int
    let duration: Date
}

// MARK: - Clean Category

enum CleanCategory: String, CaseIterable, Sendable {
    case systemCache = "System Cache"
    case userCache = "User Cache"
    case logs = "Log Files"
    case tempFiles = "Temporary Files"
    case trash = "Trash"

    var icon: String {
        switch self {
        case .systemCache: return "internaldrive.fill"
        case .userCache: return "folder.fill"
        case .logs: return "doc.text.fill"
        case .tempFiles: return "trash.fill"
        case .trash: return "trash.fill"
        }
    }
}

// MARK: - Scan Stage

enum ScanStage: String, CaseIterable, Sendable {
    case preparing = "Preparing"
    case scanningDisk = "Scanning Disk"
    case checkingApps = "Checking Apps"
    case analyzingSystem = "Analyzing System"
    case complete = "Complete"

    var progressWeight: Double {
        switch self {
        case .preparing: return 0.1
        case .scanningDisk: return 0.4
        case .checkingApps: return 0.3
        case .analyzingSystem: return 0.2
        case .complete: return 1.0
        }
    }
}

// MARK: - Logger Import

import OSLog
