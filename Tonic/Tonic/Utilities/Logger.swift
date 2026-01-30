//
//  Logger.swift
//  Tonic
//
//  Structured logging utility for diagnostics, error tracking, and performance monitoring
//  Provides privacy-aware, level-based logging to persistent storage
//

import Foundation
import OSLog

// MARK: - Logger Configuration

/// Structured logging system for Tonic application
/// Provides multiple severity levels, file persistence, and privacy-aware logging
struct Logger {

    // MARK: - Logging Levels

    /// Severity levels for logging
    enum Level: Int, CaseIterable, Comparable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case critical = 4

        var symbol: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🔴"
            }
        }

        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .error
            }
        }

        var name: String {
            switch self {
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .warning: return "WARNING"
            case .error: return "ERROR"
            case .critical: return "CRITICAL"
            }
        }

        static func < (lhs: Level, rhs: Level) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    // MARK: - Properties

    let subsystem: String
    let category: String

    private let osLogger: OSLog
    private let fileLogger: FileLogger
    static let minimumLevel: Level = .debug

    // MARK: - Initialization

    init(subsystem: String = "com.tonic.app", category: String = "general") {
        self.subsystem = subsystem
        self.category = category
        self.osLogger = OSLog(subsystem: subsystem, category: category)
        self.fileLogger = FileLogger(subsystem: subsystem, category: category)
    }

    // MARK: - Public Logging Methods

    /// Log a debug message
    func debug(_ message: String, _ args: CVarArg...) {
        log(message, level: .debug, args: args)
    }

    /// Log an info message
    func info(_ message: String, _ args: CVarArg...) {
        log(message, level: .info, args: args)
    }

    /// Log a warning message
    func warning(_ message: String, _ args: CVarArg...) {
        log(message, level: .warning, args: args)
    }

    /// Log an error message
    func error(_ message: String, _ args: CVarArg...) {
        log(message, level: .error, args: args)
    }

    /// Log a critical error
    func critical(_ message: String, _ args: CVarArg...) {
        log(message, level: .critical, args: args)
    }

    /// Log an error with context
    func error(_ message: String, error: Error, _ args: CVarArg...) {
        let fullMessage = "\(message): \(error.localizedDescription)"
        log(fullMessage, level: .error, args: args)
    }

    /// Log performance measurement
    func logPerformance(_ operation: String, duration: TimeInterval, threshold: TimeInterval? = nil) {
        var message = "\(operation) completed in \(String(format: "%.3f", duration))s"
        if let threshold = threshold, duration > threshold {
            message += " (⚠️ exceeded \(String(format: "%.3f", threshold))s threshold)"
            warning(message)
        } else {
            info(message)
        }
    }

    /// Log memory usage
    func logMemory(_ message: String, bytes: Int64) {
        let formatted = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        info("\(message): \(formatted)")
    }

    // MARK: - Private Logging Implementation

    private func log(_ message: String, level: Level, args: [CVarArg]) {
        // Check minimum level
        guard level >= Logger.minimumLevel else { return }

        // Format message
        let formattedMessage = formatMessage(message, args: args)
        let logEntry = LogEntry(
            timestamp: Date(),
            level: level,
            subsystem: subsystem,
            category: category,
            message: formattedMessage
        )

        // Log to OS
        os_log("%{public}@", log: osLogger, type: level.osLogType, formattedMessage)

        // Log to file
        fileLogger.log(entry: logEntry)
    }

    private func formatMessage(_ message: String, args: [CVarArg]) -> String {
        guard !args.isEmpty else { return message }
        return String(format: message, arguments: args)
    }

    // MARK: - Diagnostics

    /// Collect log entries for diagnostic export
    static func collectDiagnostics(sinceDate: Date? = nil) -> String {
        FileLogger.collectLogs(sinceDate: sinceDate ?? Date(timeIntervalSinceNow: -3600))
    }

    /// Clear old logs (older than specified interval)
    static func clearOldLogs(olderThan interval: TimeInterval = 86400 * 7) {
        FileLogger.clearOldLogs(olderThan: interval)
    }

    /// Get log file URL
    static var logFileURL: URL? {
        FileLogger.logFileURL
    }
}

// MARK: - Log Entry

/// A single log entry
struct LogEntry: Codable {
    let timestamp: Date
    let level: Logger.Level
    let subsystem: String
    let category: String
    let message: String

    var formattedString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let timeString = formatter.string(from: timestamp)
        return "[\(timeString)] [\(level.name)] [\(subsystem).\(category)] \(message)"
    }
}

// MARK: - File Logger

/// Handles persistent logging to disk
private struct FileLogger {

    let subsystem: String
    let category: String
    private static let logDirectory: URL? = {
        let paths = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
        return paths.first?.appendingPathComponent("Logs/Tonic")
    }()

    private static let logFileURL: URL? = {
        guard let directory = logDirectory else { return nil }
        return directory.appendingPathComponent("tonic.log")
    }()

    init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
        ensureLogDirectory()
    }

    func log(entry: LogEntry) {
        guard let fileURL = FileLogger.logFileURL else { return }

        let formattedLine = entry.formattedString + "\n"

        // Append to log file
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let fileHandle = FileHandle(forWritingAtPath: fileURL.path) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(formattedLine.data(using: .utf8) ?? Data())
                fileHandle.closeFile()
            }
        } else {
            try? formattedLine.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    private func ensureLogDirectory() {
        guard let directory = FileLogger.logDirectory else { return }

        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    // MARK: - Diagnostics

    static func collectLogs(sinceDate: Date) -> String {
        guard let fileURL = logFileURL else { return "" }

        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let cutoffString = formatter.string(from: sinceDate)

        let lines = content.components(separatedBy: .newlines)
        let filtered = lines.filter { line in
            guard let match = line.range(of: "\\[(.+?)\\]", options: .regularExpression) else {
                return false
            }
            let timestamp = String(line[match]).dropFirst().dropLast()
            return timestamp > cutoffString
        }

        return filtered.joined(separator: "\n")
    }

    static func clearOldLogs(olderThan interval: TimeInterval) {
        guard let fileURL = logFileURL else { return }

        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard let modificationDate = attributes?[.modificationDate] as? Date else { return }

        if Date().timeIntervalSince(modificationDate) > interval {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}

// MARK: - Global Logger Convenience

/// Global logger instance for general use
let appLogger = Logger(subsystem: "com.tonic.app", category: "main")

/// Convenience function for quick logging
func logDebug(_ message: String, _ args: CVarArg...) {
    appLogger.debug(message, args)
}

func logInfo(_ message: String, _ args: CVarArg...) {
    appLogger.info(message, args)
}

func logWarning(_ message: String, _ args: CVarArg...) {
    appLogger.warning(message, args)
}

func logError(_ message: String, _ args: CVarArg...) {
    appLogger.error(message, args)
}

func logCritical(_ message: String, _ args: CVarArg...) {
    appLogger.critical(message, args)
}

// MARK: - Performance Logging Extension

extension Logger {
    /// Measure and log a function's execution time
    func measureTime(_ label: String, threshold: TimeInterval? = nil, _ closure: () -> Void) {
        let start = Date()
        closure()
        let duration = Date().timeIntervalSince(start)
        logPerformance(label, duration: duration, threshold: threshold)
    }

    /// Measure and log an async function's execution time
    @available(macOS 10.15, *)
    func measureTimeAsync(_ label: String, threshold: TimeInterval? = nil, _ closure: () async -> Void) async {
        let start = Date()
        await closure()
        let duration = Date().timeIntervalSince(start)
        logPerformance(label, duration: duration, threshold: threshold)
    }
}

// MARK: - Error Logging Extension

extension Error {
    /// Log this error
    func log(in logger: Logger, message: String = "Error occurred") {
        logger.error(message, error: self)
    }
}

// MARK: - Scrubbing & Privacy

extension Logger {
    /// Scrub sensitive information from log strings
    static func scrubbedString(_ original: String) -> String {
        var scrubbed = original

        // Scrub file paths (PII)
        scrubbed = scrubbed.replacingOccurrences(
            of: "/Users/[^/]+/",
            with: "/Users/[redacted]/",
            options: .regularExpression
        )

        // Scrub email addresses
        scrubbed = scrubbed.replacingOccurrences(
            of: "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
            with: "[email redacted]",
            options: .regularExpression
        )

        // Scrub IP addresses
        scrubbed = scrubbed.replacingOccurrences(
            of: "\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b",
            with: "[ip redacted]",
            options: .regularExpression
        )

        return scrubbed
    }
}
