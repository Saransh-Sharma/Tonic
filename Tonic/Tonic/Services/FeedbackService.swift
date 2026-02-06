//
//  FeedbackService.swift
//  Tonic
//
//  Feedback and issue reporting service
//  Task: fn-4-as7.22
//

import Foundation
import AppKit

// MARK: - Feedback Models

struct FeedbackReport: Codable {
    let id: String
    let timestamp: Date
    let type: FeedbackType
    let title: String
    let description: String
    let systemInfo: SystemInfo
    let appVersion: String
    let buildVersion: String
    let logs: String?

    enum FeedbackType: String, Codable {
        case bug
        case featureRequest = "feature_request"
        case performance
        case crash
        case general
    }

    init(
        type: FeedbackType,
        title: String,
        description: String,
        logs: String? = nil
    ) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.type = type
        self.title = title
        self.description = description
        self.systemInfo = SystemInfo()
        self.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        self.buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        self.logs = logs
    }
}

struct SystemInfo: Codable {
    let osVersion: String
    let macOSVersion: String
    let architecture: String
    let processorCount: Int
    let totalMemory: UInt64

    init() {
        let processInfo = ProcessInfo.processInfo
        self.osVersion = processInfo.operatingSystemVersionString
        self.macOSVersion = {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        }()
        self.architecture = {
            var sysinfo = utsname()
            uname(&sysinfo)
            // Convert Int8 array to UInt8 array for String(decodingCString:as:)
            let machineData = withUnsafeBytes(of: &sysinfo.machine) { rawBuffer in
                Data(rawBuffer)
            }
            return String(data: machineData, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters) ?? "unknown"
        }()
        self.processorCount = processInfo.processorCount
        self.totalMemory = processInfo.physicalMemory
    }
}

// MARK: - Feedback Service

@Observable
final class FeedbackService: @unchecked Sendable {
    static let shared = FeedbackService()

    private let lock = NSLock()
    private let feedbackDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Tonic/Feedback")

    private init() {
        ensureFeedbackDirectory()
    }

    private func ensureFeedbackDirectory() {
        try? FileManager.default.createDirectory(at: feedbackDirectory, withIntermediateDirectories: true, attributes: nil)
    }

    func submitFeedback(
        type: FeedbackReport.FeedbackType,
        title: String,
        description: String,
        logs: String? = nil
    ) throws {
        let report = FeedbackReport(type: type, title: title, description: description, logs: logs)

        lock.lock()
        defer { lock.unlock() }

        let reportURL = feedbackDirectory.appendingPathComponent("\(report.id).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(report)
        try data.write(to: reportURL)

        // Also open GitHub issue link
        DispatchQueue.main.async { [weak self] in
            self?.openGitHubIssueForm(title: title, description: description, type: type)
        }
    }

    func saveCrashReport(error: Error, stackTrace: String?) {
        let description = "\(error.localizedDescription)\n\nStack Trace:\n\(stackTrace ?? "Not available")"
        do {
            try submitFeedback(type: .crash, title: "Crash Report: \(error.localizedDescription)", description: description)
        } catch {
            print("Failed to save crash report: \(error)")
        }
    }

    private func openGitHubIssueForm(title: String, description: String, type: FeedbackReport.FeedbackType) {
        let label = type == .bug ? "bug" : (type == .featureRequest ? "enhancement" : "feedback")
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Issue"
        let encodedDescription = description.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let gitHubURL = URL(string: "https://github.com/Saransh-Sharma/PreTonic/issues/new?title=\(encodedTitle)&labels=\(label)&body=\(encodedDescription)")!

        NSWorkspace.shared.open(gitHubURL)
    }

    func getAllFeedbackReports() throws -> [FeedbackReport] {
        lock.lock()
        defer { lock.unlock() }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: feedbackDirectory.path) else { return [] }

        let fileURLs = try fileManager.contentsOfDirectory(at: feedbackDirectory, includingPropertiesForKeys: nil)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return fileURLs.compactMap { url in
            guard url.pathExtension == "json" else { return nil }
            do {
                let data = try Data(contentsOf: url)
                return try decoder.decode(FeedbackReport.self, from: data)
            } catch {
                return nil
            }
        }
    }

    func deleteFeedbackReport(withID id: String) throws {
        lock.lock()
        defer { lock.unlock() }

        let reportURL = feedbackDirectory.appendingPathComponent("\(id).json")
        try FileManager.default.removeItem(at: reportURL)
    }

    func getApplicationLogs(lines: Int = 100) -> String? {
        guard let logsURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return nil }
        let logFile = logsURL.appendingPathComponent("Logs/com.tonic.Tonic/system.log")

        guard FileManager.default.fileExists(atPath: logFile.path) else { return nil }

        do {
            let logContent = try String(contentsOf: logFile, encoding: .utf8)
            let logLines = logContent.split(separator: "\n").suffix(lines).joined(separator: "\n")
            return logLines.isEmpty ? nil : logLines
        } catch {
            return nil
        }
    }
}

// MARK: - Crash Reporter

@Observable
final class CrashReporter: NSObject, @unchecked Sendable {
    static let shared = CrashReporter()

    private override init() {
        super.init()
        setupCrashHandling()
    }

    private func setupCrashHandling() {
        NSSetUncaughtExceptionHandler { exception in
            let stackTrace = exception.callStackSymbols.joined(separator: "\n")
            FeedbackService.shared.saveCrashReport(
                error: NSError(domain: exception.name.rawValue, code: -1, userInfo: [NSLocalizedDescriptionKey: exception.reason ?? "Unknown exception"]),
                stackTrace: stackTrace
            )
        }
    }

    func reportError(_ error: Error, stackTrace: String? = nil) {
        FeedbackService.shared.saveCrashReport(error: error, stackTrace: stackTrace)
    }
}
