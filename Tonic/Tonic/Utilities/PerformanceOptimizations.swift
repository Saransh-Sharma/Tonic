//
//  PerformanceOptimizations.swift
//  Tonic
//
//  Performance profiling utilities and optimization strategies
//  Tracks app launch time, scan performance, and render performance
//

import Foundation
import os.log

// MARK: - Performance Logger

@MainActor
final class PerformanceLogger {
    static let shared = PerformanceLogger()

    private let logger = os.Logger(subsystem: "com.pretonic.tonic", category: "performance")
    private var measurements: [String: CFAbsoluteTime] = [:]

    /// Mark the start of a performance measurement
    /// - Parameter key: Unique identifier for this measurement
    func startMeasure(_ key: String) {
        measurements[key] = CFAbsoluteTimeGetCurrent()
        logger.log("Started measuring: \(key)")
    }

    /// End a performance measurement and log duration
    /// - Parameter key: Must match the key from startMeasure
    /// - Returns: Duration in milliseconds
    @discardableResult
    func endMeasure(_ key: String) -> Double {
        guard let startTime = measurements[key] else {
            logger.error("No start time found for: \(key)")
            return 0
        }

        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000 // Convert to ms
        measurements.removeValue(forKey: key)

        let level: OSLogType = duration > 100 ? .info : .debug
        logger.log(level: level, "[\(key)] completed in \(String(format: "%.1f", duration))ms")

        return duration
    }

    /// Measure a synchronous operation
    /// - Parameters:
    ///   - key: Unique identifier
    ///   - block: The code to measure
    /// - Returns: Duration in milliseconds
    @discardableResult
    func measure<T>(_ key: String, _ block: () throws -> T) rethrows -> T {
        startMeasure(key)
        defer { endMeasure(key) }
        return try block()
    }

    /// Measure an async operation
    /// - Parameters:
    ///   - key: Unique identifier
    ///   - block: The async code to measure
    /// - Returns: Duration in milliseconds
    @discardableResult
    func measureAsync<T>(_ key: String, _ block: () async throws -> T) async rethrows -> T {
        startMeasure(key)
        defer { endMeasure(key) }
        return try await block()
    }
}

// MARK: - App Launch Performance Tracking

@MainActor
final class LaunchPerformanceTracker {
    static let shared = LaunchPerformanceTracker()

    private let logger = os.Logger(subsystem: "com.pretonic.tonic", category: "launch")
    private let appStartTime = CFAbsoluteTimeGetCurrent()

    var timeToFirstFrame: Double {
        (CFAbsoluteTimeGetCurrent() - appStartTime) * 1000
    }

    /// Log current time to first frame
    func logTimeToFirstFrame() {
        let ttff = timeToFirstFrame
        let level: OSLogType = ttff < 2000 ? .debug : .info
        logger.log(level: level, "Time to First Frame: \(String(format: "%.0f", ttff))ms")

        if ttff > 2000 {
            logger.warning("App launch exceeded 2 second target")
        }
    }
}

// MARK: - Scan Performance Tracking

final class ScanPerformanceTracker {
    private let logger = os.Logger(subsystem: "com.pretonic.tonic", category: "scan")

    func trackSmartScanDuration(_ duration: TimeInterval) {
        let seconds = duration
        let level: OSLogType = seconds > 30 ? .info : .debug
        logger.log(level: level, "Smart Scan completed in \(String(format: "%.1f", seconds))s")

        if seconds > 30 {
            logger.warning("Smart Scan exceeded 30 second target")
        }
    }

    func trackDiskTreeLoad(_ duration: TimeInterval) {
        let ms = duration * 1000
        logger.log("Disk tree loaded in \(String(format: "%.0f", ms))ms")
    }
}
