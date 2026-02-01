//
//  CrashReportingService.swift
//  Tonic
//
//  Crash reporting service - captures uncaught exceptions and provides diagnostics
//

import Foundation

// MARK: - Global Exception Handler Context

/// Global reference to the crash reporting service for C function pointer callback
private var crashReportingServiceInstance: CrashReportingService?

/// Shared instance accessor for exception handler
private final class CrashReportingSharedInstance {
    static weak var shared: CrashReportingService?
}

/// C function pointer for uncaught exception handler
private func CrashReportingExceptionHandler(_ exception: NSException) {
    // Handle the exception
    crashReportingServiceInstance?.handleUncaughtException(exception)

    // Call previous handler if it exists
    if let previousHandler = previousExceptionHandlerPointer {
        previousHandler(exception)
    }
}

/// Storage for previous exception handler (file-scoped for C function access)
private var previousExceptionHandlerPointer: (@convention(c) (NSException) -> Swift.Void)?

// MARK: - Crash Report

/// A captured crash report
struct CrashReport: Identifiable {
    let id: UUID
    let timestamp: Date
    let appVersion: String
    let osVersion: String
    let deviceModel: String
    let exceptionName: String
    let exceptionReason: String?
    let stackTrace: [String]
    let diagnostics: CrashDiagnostics
    var userConsent: Bool

    init(
        timestamp: Date = Date(),
        appVersion: String = Bundle.main.appVersion,
        osVersion: String = ProcessInfo.processInfo.operatingSystemVersionString,
        deviceModel: String = ProcessInfo.processInfo.environment["MODEL"] ?? "Unknown",
        exceptionName: String,
        exceptionReason: String? = nil,
        stackTrace: [String] = [],
        diagnostics: CrashDiagnostics = CrashDiagnostics(),
        userConsent: Bool = false
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.deviceModel = deviceModel
        self.exceptionName = exceptionName
        self.exceptionReason = exceptionReason
        self.stackTrace = stackTrace
        self.diagnostics = diagnostics
        self.userConsent = userConsent
    }
}

// MARK: - Crash Diagnostics

/// Diagnostic information captured at crash time
struct CrashDiagnostics {
    let memoryUsage: Int64?
    let uptime: TimeInterval?
    let activeViewControllers: [String]
    let recentLogs: [String]
    let capturedAt: Date

    init(
        memoryUsage: Int64? = nil,
        uptime: TimeInterval? = nil,
        activeViewControllers: [String] = [],
        recentLogs: [String] = [],
        capturedAt: Date = Date()
    ) {
        self.memoryUsage = memoryUsage
        self.uptime = uptime
        self.activeViewControllers = activeViewControllers
        self.recentLogs = recentLogs
        self.capturedAt = capturedAt
    }
}

// MARK: - Crash Reporting Service

/// Service for capturing and reporting crashes
@MainActor
class CrashReportingService: ObservableObject {

    // MARK: - Shared Instance

    static let shared = CrashReportingService()

    // MARK: - Properties

    @Published private(set) var lastCrashReport: CrashReport?
    @Published private(set) var isEnabled: Bool = false
    @Published var userConsentRequired: Bool = true
    @Published var autoSubmitEnabled: Bool = false

    private let logTag = "CrashReporting"
    private let storageManager: CrashReportStorageManager

    private var systemSignalHandlers: [Int32] = []

    // MARK: - Initialization

    private init() {
        self.storageManager = CrashReportStorageManager()
        self.loadCrashReportSettings()
    }

    // MARK: - Setup

    /// Register crash handlers
    func registerCrashHandlers() {
        DispatchQueue.main.async {
            // Handle uncaught exceptions
            self.registerUncaughtExceptionHandler()

            // Load previous crash reports
            self.loadPreviousCrashes()

            self.isEnabled = true
            print("[\(self.logTag)] Crash reporting enabled")
        }
    }

    private func registerUncaughtExceptionHandler() {
        // Store previous handler if exists
        previousExceptionHandlerPointer = NSGetUncaughtExceptionHandler()

        // Store self globally for the C function pointer callback
        crashReportingServiceInstance = self

        // Set the exception handler using a function pointer
        NSSetUncaughtExceptionHandler(CrashReportingExceptionHandler)
    }

    // MARK: - Exception Handling

    nonisolated internal func handleUncaughtException(_ exception: NSException) {
        let stackTrace = exception.callStackSymbols
        let tag = "CrashReporting"
        print("[\(tag)] Uncaught exception: \(exception.name.rawValue)")

        // Capture diagnostics synchronously
        let diagnostics = nonisolatedCaptureDiagnostics()

        let report = CrashReport(
            exceptionName: exception.name.rawValue,
            exceptionReason: exception.reason,
            stackTrace: stackTrace,
            diagnostics: diagnostics,
            userConsent: false
        )

        // Save synchronously to disk
        storageManager.saveCrashReport(report)

        print("[\(tag)] Crash saved: \(report.id)")
    }

    // MARK: - Diagnostics Capture

    private func captureDiagnostics() -> CrashDiagnostics {
        let memoryUsage = getMemoryUsage()
        let uptime = ProcessInfo.processInfo.systemUptime
        let logString = Logger.collectDiagnostics(sinceDate: Date(timeIntervalSinceNow: -300))
        let recentLogs = logString.components(separatedBy: "\n").filter { !$0.isEmpty }

        return CrashDiagnostics(
            memoryUsage: memoryUsage,
            uptime: uptime,
            activeViewControllers: [],
            recentLogs: recentLogs,
            capturedAt: Date()
        )
    }

    /// Non-isolated version of diagnostics capture for use in crash handler
    private nonisolated func nonisolatedCaptureDiagnostics() -> CrashDiagnostics {
        let memoryUsage = getNonisolatedMemoryUsage()
        let uptime = ProcessInfo.processInfo.systemUptime
        let recentLogs = collectNonisolatedLogs()

        return CrashDiagnostics(
            memoryUsage: memoryUsage,
            uptime: uptime,
            activeViewControllers: [],
            recentLogs: recentLogs,
            capturedAt: Date()
        )
    }

    // MARK: - Diagnostics Capture (Non-isolated)

    private nonisolated func getNonisolatedMemoryUsage() -> Int64? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : nil
    }

    private nonisolated func collectNonisolatedLogs() -> [String] {
        // Return basic diagnostic info instead of trying to access Logger
        return [
            "Memory: \(getNonisolatedMemoryUsage() ?? 0) bytes",
            "Uptime: \(ProcessInfo.processInfo.systemUptime) seconds",
            "Timestamp: \(Date())"
        ]
    }

    private func getMemoryUsage() -> Int64 {
        var info = task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_basic_info>.size)
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }

    // MARK: - Report Management

    /// Submit a crash report
    func submitCrashReport(_ report: CrashReport, userConsent: Bool = false) {
        print("[\(logTag)] Submitting crash report: \(report.id)")

        var updatedReport = report
        updatedReport.userConsent = userConsent

        // Here you would send to crash reporting service (Sentry, Rollbar, etc.)
        // For now, we just save it with consent flag
        storageManager.saveCrashReport(updatedReport)

        print("[\(logTag)] Crash report submitted")
    }

    /// Get all stored crash reports
    func getAllCrashReports() -> [CrashReport] {
        return storageManager.loadAllCrashReports()
    }

    /// Delete a crash report
    func deleteCrashReport(_ report: CrashReport) {
        storageManager.deleteCrashReport(report)
        print("[\(logTag)] Deleted crash report: \(report.id)")
    }

    /// Clear all crash reports
    func clearAllCrashReports() {
        storageManager.clearAllCrashReports()
        print("[\(logTag)] Cleared all crash reports")
    }

    // MARK: - Settings

    private func loadCrashReportSettings() {
        let defaults = UserDefaults.standard
        userConsentRequired = defaults.bool(forKey: "crashReporting.userConsentRequired") || true
        autoSubmitEnabled = defaults.bool(forKey: "crashReporting.autoSubmit")
    }

    func setAutoSubmit(_ enabled: Bool) {
        autoSubmitEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "crashReporting.autoSubmit")
        print("[\(logTag)] Auto-submit crash reports: \(enabled)")
    }

    func setUserConsentRequired(_ required: Bool) {
        userConsentRequired = required
        UserDefaults.standard.set(required, forKey: "crashReporting.userConsentRequired")
        print("[\(logTag)] User consent required: \(required)")
    }

    // MARK: - Previous Crashes

    private func loadPreviousCrashes() {
        let reports = storageManager.loadAllCrashReports()
        if !reports.isEmpty {
            print("[\(logTag)] Found \(reports.count) previous crash report(s)")
            if let mostRecent = reports.sorted(by: { $0.timestamp > $1.timestamp }).first {
                lastCrashReport = mostRecent
            }
        }
    }
}

// MARK: - Darwin Signal Definitions

import Darwin

private let TASK_BASIC_INFO = task_flavor_t(1)

// MARK: - Crash Report Storage Manager

private struct CrashReportStorageManager {

    private static var storageDirectory: URL? {
        let paths = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
        return paths.first?.appendingPathComponent("Tonic/CrashReports")
    }

    init() {
        ensureStorageDirectory()
    }

    func saveCrashReport(_ report: CrashReport) {
        guard let directory = Self.storageDirectory else { return }

        let fileURL = directory.appendingPathComponent("\(report.id).txt")
        var text = """
        Crash Report: \(report.id)
        Timestamp: \(report.timestamp.description)
        App Version: \(report.appVersion)
        OS Version: \(report.osVersion)
        Device Model: \(report.deviceModel)

        Exception: \(report.exceptionName)
        Reason: \(report.exceptionReason ?? "N/A")

        Stack Trace:
        \(report.stackTrace.joined(separator: "\n"))

        Memory Usage: \(report.diagnostics.memoryUsage ?? 0)
        Uptime: \(report.diagnostics.uptime ?? 0)
        """

        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save crash report: \(error)")
        }
    }

    func loadAllCrashReports() -> [CrashReport] {
        // For now, return empty array - full implementation would parse text files
        return []
    }

    func deleteCrashReport(_ report: CrashReport) {
        guard let directory = Self.storageDirectory else { return }

        let fileURL = directory.appendingPathComponent("\(report.id).json")
        try? FileManager.default.removeItem(at: fileURL)
    }

    func clearAllCrashReports() {
        guard let directory = Self.storageDirectory else { return }

        try? FileManager.default.removeItem(at: directory)
        ensureStorageDirectory()
    }

    private func ensureStorageDirectory() {
        guard let directory = Self.storageDirectory else { return }

        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
}

// MARK: - Bundle Extensions

private extension Bundle {
    var appVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "Unknown"
    }

    var buildNumber: String {
        (infoDictionary?["CFBundleVersion"] as? String) ?? "Unknown"
    }
}
