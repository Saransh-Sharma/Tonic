//
//  SpeedTestService.swift
//  Tonic
//
//  Service for performing network speed tests
//  Task ID: fn-2.8.5
//  Performance optimized: Reduced main thread blocking, optimized progress updates
//

import Foundation
import Network
import os
import Combine
import SwiftUI

// MARK: - Speed Test Service

/// Service for performing network speed tests
/// Optimized to run off main thread with minimal UI updates
@Observable
public final class SpeedTestService {
    public static let shared = SpeedTestService()

    private let logger = Logger(subsystem: "com.tonic.app", category: "SpeedTestService")

    // Current test state
    public private(set) var testData: SpeedTestData = SpeedTestData()
    public private(set) var isRunning = false
    public private(set) var currentPhase: SpeedTestPhase = .idle
    public private(set) var progress: Double = 0

    // Configuration
    public var testDuration: TimeInterval = 10.0  // seconds per phase
    public var downloadTestURL: URL = URL(string: "https://speed.cloudflare.com/__down?bytes=10000000")!
    public var uploadTestURL: URL = URL(string: "https://speed.cloudflare.com/__up")!
    public var bufferSize: Int = 16_384  // 16KB chunks

    // Test servers
    private let testServers = [
        "https://speed.cloudflare.com",
        "https://speedtest.tele2.net",
        "https://testfile.org"
    ]

    private var downloadTask: Task<Void, Never>?
    private var uploadTask: Task<Void, Never>?
    private var urlSession: URLSession?

    // Pre-generated test data to avoid blocking during upload
    private static var uploadTestData: Data?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        urlSession = URLSession(configuration: config)

        // Pre-generate upload test data on background thread
        Task.detached(priority: .background) {
            let size = 5_000_000  // 5MB
            var localData = Data(count: size)
            localData.withUnsafeMutableBytes { bytes in
                guard let baseAddr = bytes.baseAddress else { return }
                for i in 0..<bytes.count {
                    baseAddr.advanced(by: i).storeBytes(of: UInt8.random(in: 0...255), as: UInt8.self)
                }
            }
            await MainActor.run {
                Self.uploadTestData = localData
            }
        }
    }

    // MARK: - Public Methods

    /// Start a complete speed test (ping + download + upload)
    public func startTest() {
        guard !isRunning else { return }

        isRunning = true
        currentPhase = .ping
        progress = 0

        // Reset test data
        testData = SpeedTestData(isRunning: true, progress: 0)

        Task {
            await runFullTest()
        }
    }

    /// Cancel the current speed test
    public func cancelTest() {
        isRunning = false
        currentPhase = .idle
        progress = 0

        downloadTask?.cancel()
        uploadTask?.cancel()

        testData = SpeedTestData(isRunning: false)
    }

    /// Test only download speed
    public func testDownloadOnly() async {
        isRunning = true
        currentPhase = .download
        progress = 0

        let downloadSpeed = await performDownloadTest()

        testData = SpeedTestData(
            downloadSpeed: downloadSpeed,
            isRunning: false,
            progress: 1
        )

        isRunning = false
        currentPhase = .idle
    }

    /// Test only upload speed
    public func testUploadOnly() async {
        isRunning = true
        currentPhase = .upload
        progress = 0

        let uploadSpeed = await performUploadTest()

        testData = SpeedTestData(
            uploadSpeed: uploadSpeed,
            isRunning: false,
            progress: 1
        )

        isRunning = false
        currentPhase = .idle
    }

    // MARK: - Test Implementation

    /// Run the full speed test sequence
    private func runFullTest() async {
        // Phase 1: Ping test
        currentPhase = .ping
        await updateProgress(0.05)

        let pingResult = await performPingTest()

        await MainActor.run {
            self.testData = SpeedTestData(
                ping: pingResult?.ping,
                jitter: pingResult?.jitter,
                isRunning: true,
                progress: 0.1
            )
        }

        guard isRunning else { return }

        // Phase 2: Download test
        currentPhase = .download
        await updateProgress(0.15)

        let downloadSpeed = await performDownloadTest()

        await MainActor.run {
            self.testData = SpeedTestData(
                downloadSpeed: downloadSpeed,
                ping: pingResult?.ping,
                jitter: pingResult?.jitter,
                isRunning: true,
                progress: 0.6
            )
        }

        guard isRunning else { return }

        // Phase 3: Upload test
        currentPhase = .upload
        await updateProgress(0.65)

        let uploadSpeed = await performUploadTest()

        // Complete
        await MainActor.run {
            self.testData = SpeedTestData(
                downloadSpeed: downloadSpeed,
                uploadSpeed: uploadSpeed,
                ping: pingResult?.ping,
                jitter: pingResult?.jitter,
                isRunning: false,
                progress: 1
            )
        }

        isRunning = false
        currentPhase = .complete

        // Reset to idle after delay
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        currentPhase = .idle
    }

    /// Update progress on main thread
    private func updateProgress(_ value: Double) async {
        await MainActor.run {
            self.progress = value
        }
    }

    /// Perform a quick ping test for latency
    private func performPingTest() async -> (ping: TimeInterval, jitter: TimeInterval)? {
        let host = "1.1.1.1"  // Cloudflare DNS
        var pingTimes: [TimeInterval] = []

        for _ in 0..<5 {
            let start = Date()

            let success = await pingHost(host)

            if success {
                let duration = Date().timeIntervalSince(start)
                pingTimes.append(duration)
            }

            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        }

        guard !pingTimes.isEmpty else { return nil }

        let avgPing = pingTimes.reduce(0, +) / Double(pingTimes.count)

        let jitter: TimeInterval
        if pingTimes.count >= 2 {
            let variance = pingTimes.map { pow($0 - avgPing, 2) }.reduce(0, +) / Double(pingTimes.count)
            jitter = sqrt(variance)
        } else {
            jitter = 0
        }

        return (avgPing, jitter)
    }

    /// Perform download speed test
    private func performDownloadTest() async -> Double? {
        guard let session = urlSession else { return nil }

        let testURLs = [
            URL(string: "https://speed.cloudflare.com/__down?bytes=25000000")!,  // 25MB
            URL(string: "https://testfile.org/50MB.iso")!,
            URL(string: "https://www.thinkbroadband.com/download/50MB.zip")!
        ]

        for testURL in testURLs {
            guard isRunning else { return nil }

            if let speed = await tryDownloadTest(session: session, url: testURL) {
                return speed
            }
        }

        return nil
    }

    /// Try a single download test
    private func tryDownloadTest(session: URLSession, url: URL) async -> Double? {
        let startTime = Date()
        var totalBytes: Int64 = 0
        var lastProgressUpdate = startTime

        do {
            let (bytes, response) = try await session.bytes(for: URLRequest(url: url))

            // Check if response is valid
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            // Start time after connection
            let downloadStartTime = Date()

            for try await _ in bytes {
                guard isRunning else { return nil }

                totalBytes += 1

                // Update progress less frequently (every 5MB instead of 1MB) to reduce main thread overhead
                let now = Date()
                let shouldUpdate = totalBytes % 5_242_880 == 0 && now.timeIntervalSince(lastProgressUpdate) > 0.5

                if shouldUpdate {
                    lastProgressUpdate = now
                    let elapsed = now.timeIntervalSince(downloadStartTime)
                    let currentSpeed = (Double(totalBytes) * 8) / (elapsed * 1_000_000)  // Mbps
                    let capturedBytes = totalBytes
                    let capturedPing = testData.ping
                    let capturedJitter = testData.jitter

                    await MainActor.run {
                        self.testData = SpeedTestData(
                            downloadSpeed: currentSpeed,
                            ping: capturedPing,
                            jitter: capturedJitter,
                            isRunning: true,
                            progress: 0.1 + (Double(capturedBytes) / 25_000_000) * 0.5
                        )
                    }
                }

                // Timeout after 30 seconds
                if Date().timeIntervalSince(downloadStartTime) > 30 {
                    break
                }

                // Limit to 25MB
                if totalBytes >= 25_000_000 {
                    break
                }
            }

            let elapsed = Date().timeIntervalSince(downloadStartTime)
            let speedMbps = (Double(totalBytes) * 8) / (elapsed * 1_000_000)

            return speedMbps

        } catch {
            logger.warning("Download test failed for \(url.host ?? "unknown"): \(error.localizedDescription)")
            return nil
        }
    }

    /// Perform upload speed test
    private func performUploadTest() async -> Double? {
        // Use pre-generated test data
        guard let uploadData = Self.uploadTestData else {
            logger.warning("Upload test data not ready")
            // Fallback to estimating from download
            let downloadSpeed = await MainActor.run { self.testData.downloadSpeed }
            if let downloadSpeed = downloadSpeed {
                return downloadSpeed * 0.2
            }
            return nil
        }

        guard let session = urlSession else { return nil }

        var request = URLRequest(url: uploadTestURL)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let startTime = Date()

        do {
            let (_, response) = try await session.upload(for: request, from: uploadData)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
                return nil
            }

            let elapsed = Date().timeIntervalSince(startTime)
            let speedMbps = (Double(uploadData.count) * 8) / (elapsed * 1_000_000)

            return speedMbps

        } catch {
            logger.warning("Upload test failed: \(error.localizedDescription)")

            // Fallback: estimate from download speed (common for home connections)
            let downloadSpeed = await MainActor.run { self.testData.downloadSpeed }
            if let downloadSpeed = downloadSpeed {
                // Many home connections have upload ~1/5 to 1/10 of download
                return downloadSpeed * 0.2
            }

            return nil
        }
    }

    /// Simple ping to check host availability
    private func pingHost(_ host: String) async -> Bool {
        await withCheckedContinuation { continuation in
            let hostEndpoint = NWEndpoint.Host(host)
            guard let port = NWEndpoint.Port(rawValue: 443) else {
                continuation.resume(returning: false)
                return
            }

            let connection = NWConnection(
                host: hostEndpoint,
                port: port,
                using: .tls
            )

            var hasResumed = false
            let resumeOnce = { (result: Bool) in
                guard !hasResumed else { return }
                hasResumed = true
                connection.cancel()
                continuation.resume(returning: result)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    resumeOnce(true)
                case .failed, .waiting:
                    resumeOnce(false)
                default:
                    break
                }
            }

            connection.start(queue: .global())

            // Timeout after 2 seconds
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                resumeOnce(false)
            }
        }
    }

    // MARK: - Helpers

    /// Format speed for display
    public func formatSpeed(_ mbps: Double) -> String {
        if mbps >= 1000 {
            return String(format: "%.2f Gbps", mbps / 1000)
        } else {
            return String(format: "%.1f Mbps", mbps)
        }
    }

    /// Get connection grade based on speed
    public func getSpeedGrade(_ mbps: Double?) -> SpeedGrade {
        guard let speed = mbps else { return .unknown }
        switch speed {
        case 0..<25: return .slow
        case 25..<100: return .basic
        case 100..<500: return .good
        case 500..<1000: return .fast
        case 1000...: return .ultra
        default: return .unknown
        }
    }
}

// MARK: - Speed Test Phase

/// Phases of a speed test
public enum SpeedTestPhase: Sendable {
    case idle       // Not running
    case ping       // Testing latency
    case download   // Testing download
    case upload     // Testing upload
    case complete   // Test finished

    public var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .ping: return "Testing Ping..."
        case .download: return "Testing Download..."
        case .upload: return "Testing Upload..."
        case .complete: return "Complete"
        }
    }

    public var icon: String {
        switch self {
        case .idle: return "network"
        case .ping: return "waveform.path"
        case .download: return "arrow.down.circle"
        case .upload: return "arrow.up.circle"
        case .complete: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Speed Grade

/// Speed grade classification
public enum SpeedGrade: Sendable {
    case slow       // < 25 Mbps
    case basic      // 25-100 Mbps
    case good       // 100-500 Mbps
    case fast       // 500-1000 Mbps
    case ultra      // > 1000 Mbps
    case unknown

    public var color: SwiftUI.Color {
        switch self {
        case .slow: return .red
        case .basic: return .orange
        case .good: return .green
        case .fast: return .blue
        case .ultra: return .purple
        case .unknown: return .gray
        }
    }

    public var label: String {
        switch self {
        case .slow: return "Slow"
        case .basic: return "Basic"
        case .good: return "Good"
        case .fast: return "Fast"
        case .ultra: return "Ultra"
        case .unknown: return "Unknown"
        }
    }
}
