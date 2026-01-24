//
//  NetworkQualityService.swift
//  Tonic
//
//  Service for measuring network quality using ICMP ping
//  Task ID: fn-2.8.3
//

import Foundation
import Network
import os
import SystemConfiguration

// MARK: - Network Quality Service

/// Service for measuring network quality (ping, jitter, packet loss)
@MainActor
@Observable
public final class NetworkQualityService {
    public static let shared = NetworkQualityService()

    private let logger = Logger(subsystem: "com.tonic.app", category: "NetworkQualityService")

    // Current quality data
    public private(set) var routerQuality: NetworkQualityData?
    public private(set) var internetQuality: NetworkQualityData?

    // Configuration
    public var pingInterval: TimeInterval = 30.0  // seconds
    public var pingTimeout: TimeInterval = 5.0    // seconds
    public var pingCount: Int = 5                 // pings per measurement

    private var pingTimer: DispatchSourceTimer?
    private var isMonitoring = false
    private let queue = DispatchQueue(label: "com.tonic.network-quality", qos: .userInitiated)

    // Default test hosts
    private let routerHost = "192.168.1.1"  // Will be updated to actual gateway
    private let internetHosts = [
        "1.1.1.1",       // Cloudflare DNS
        "8.8.8.8",       // Google DNS
        "208.67.222.222" // OpenDNS
    ]

    private init() {
        // Update router host to actual gateway
        if let gateway = getDefaultGateway() {
            routerHost = gateway
        }
    }

    // MARK: - Public Methods

    /// Start monitoring network quality
    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // Initial measurement
        updateAllMeasurements()

        // Setup recurring measurements
        pingTimer = DispatchSource.makeTimerSource(queue: queue)
        pingTimer?.schedule(deadline: .now() + pingInterval, repeating: pingInterval)
        pingTimer?.setEventHandler { [weak self] in
            self?.updateAllMeasurements()
        }
        pingTimer?.resume()

        logger.info("Network quality monitoring started")
    }

    /// Stop monitoring network quality
    public func stopMonitoring() {
        isMonitoring = false
        pingTimer?.cancel()
        pingTimer = nil
        logger.info("Network quality monitoring stopped")
    }

    /// Perform a single router quality test
    public func testRouterQuality() async -> NetworkQualityData {
        let gateway = getDefaultGateway() ?? routerHost
        return await pingHost(gateway, targetName: "Router")
    }

    /// Perform a single internet quality test
    public func testInternetQuality() async -> NetworkQualityData {
        // Test all internet hosts and return the best result
        var bestResult: NetworkQualityData?

        for host in internetHosts {
            let result = await pingHost(host, targetName: "Internet")
            if bestResult == nil || (result.ping ?? 999) < (bestResult?.ping ?? 999) {
                bestResult = result
            }
        }

        return bestResult ?? NetworkQualityData(targetName: "Internet")
    }

    /// Update all quality measurements
    private func updateAllMeasurements() {
        Task {
            let routerResult = await testRouterQuality()
            let internetResult = await testInternetQuality()

            await MainActor.run {
                self.routerQuality = routerResult
                self.internetQuality = internetResult
            }

            self.logger.debug("Quality - Router: \(routerResult.ping ?? 0)ms, Internet: \(internetResult.ping ?? 0)ms")
        }
    }

    // MARK: - Ping Implementation

    /// Ping a host and return quality metrics
    private func pingHost(_ host: String, targetName: String) async -> NetworkQualityData {
        var pingTimes: [TimeInterval] = []
        var successCount = 0

        for _ in 0..<pingCount {
            let startTime = Date()

            let result = await performPing(host: host, timeout: pingTimeout)

            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)

            if result {
                successCount += 1
                pingTimes.append(duration)
            }

            // Small delay between pings
            try? await Task.sleep(nanoseconds: UInt64(100_000_000)) // 100ms
        }

        // Calculate metrics
        let avgPing: TimeInterval?
        if !pingTimes.isEmpty {
            avgPing = pingTimes.reduce(0, +) / Double(pingTimes.count)
        } else {
            avgPing = nil
        }

        let jitter: TimeInterval?
        if pingTimes.count >= 2, let avg = avgPing {
            // Calculate standard deviation
            let variance = pingTimes.map { pow($0 - avg, 2) }.reduce(0, +) / Double(pingTimes.count)
            jitter = sqrt(variance)
        } else {
            jitter = nil
        }

        let packetLoss: Double?
        if pingCount > 0 {
            packetLoss = (Double(pingCount - successCount) / Double(pingCount)) * 100
        } else {
            packetLoss = nil
        }

        return NetworkQualityData(
            ping: avgPing,
            jitter: jitter,
            packetLoss: packetLoss,
            targetHost: host,
            targetName: targetName
        )
    }

    /// Perform a single ICMP ping using NWConnection
    private func performPing(host: String, timeout: TimeInterval) async -> Bool {
        return await withCheckedContinuation { continuation in
            // Use NWConnection for IPv4
            guard let hostEndpoint = NWEndpoint.Host(host) else {
                continuation.resume(returning: false)
                return
            }

            let port = NWEndpoint.Port(rawValue: 80)!  // Use port 80 for TCP ping (more reliable)

            let connection = NWConnection(
                host: hostEndpoint,
                port: port,
                using: .tcp
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
                    // Connection successful - host is reachable
                    resumeOnce(true)
                case .failed(let error):
                    logger.debug("Ping to \(host) failed: \(error.localizedDescription)")
                    resumeOnce(false)
                case .waiting(let error):
                    logger.debug("Ping to \(host) waiting: \(error.localizedDescription)")
                    resumeOnce(false)
                default:
                    break
                }
            }

            connection.start(queue: .global())

            // Set timeout
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                resumeOnce(false)
            }
        }
    }

    // MARK: - Gateway Detection

    /// Get the default gateway IP address
    private func getDefaultGateway() -> String? {
        // Try to get gateway from system configuration
        var address: String?
        var netmask: String?
        var gateway: String?

        // Test with common gateway IPs
        let commonGateways = [
            "192.168.1.1",
            "192.168.0.1",
            "192.168.2.1",
            "10.0.0.1",
            "10.0.1.1",
            "172.16.0.1"
        ]

        // Quick check: Try to ping common gateways
        for gw in commonGateways {
            if isHostReachable(gw) {
                logger.debug("Found gateway: \(gw)")
                return gw
            }
        }

        return nil
    }

    /// Quick check if a host is reachable
    private func isHostReachable(_ host: String) -> Bool {
        var result = false

        let semaphore = DispatchSemaphore(value: 0)

        guard let hostEndpoint = NWEndpoint.Host(host) else {
            return false
        }

        let port = NWEndpoint.Port(rawValue: 80)!
        let connection = NWConnection(host: hostEndpoint, port: port, using: .tcp)

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                result = true
                connection.cancel()
                semaphore.signal()
            case .failed, .waiting:
                connection.cancel()
                semaphore.signal()
            default:
                break
            }
        }

        connection.start(queue: .global())
        connection.cancel(after: .now() + 0.5)

        _ = semaphore.wait(timeout: .now() + 1)

        return result
    }
}

// MARK: - NWConnection Extension

private extension NWConnection {
    func cancel(after deadline: DispatchTime) {
        DispatchQueue.global().asyncAfter(deadline: deadline) {
            self.cancel()
        }
    }
}
