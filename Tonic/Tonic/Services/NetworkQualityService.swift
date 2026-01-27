//
//  NetworkQualityService.swift
//  Tonic
//
//  Service for measuring network quality using ICMP ping
//  Task ID: fn-2.8.3
//  Fixed: Using system ping command for actual ICMP measurements
//

import Foundation
import Network
import os
import SystemConfiguration

// MARK: - Network Quality Service

/// Service for measuring network quality (ping, jitter, packet loss)
/// Uses system ICMP ping for accurate latency measurements
@Observable
public final class NetworkQualityService {
    public static let shared = NetworkQualityService()

    private let logger = Logger(subsystem: "com.tonic.app", category: "NetworkQualityService")

    // Current quality data - @Observable for SwiftUI
    public private(set) var routerQuality: NetworkQualityData?
    public private(set) var internetQuality: NetworkQualityData?

    // Configuration
    public var pingInterval: TimeInterval = 30.0  // seconds
    public var pingTimeout: TimeInterval = 1.0    // seconds for each ping
    public var pingCount: Int = 3                 // pings per measurement

    private var pingTimer: DispatchSourceTimer?
    private var isMonitoring = false
    private let queue = DispatchQueue(label: "com.tonic.network-quality", qos: .userInitiated)

    // Result caching
    private struct CachedResult {
        let data: NetworkQualityData
        let timestamp: Date
    }

    private var cachedRouterResult: CachedResult?
    private var cachedInternetResult: CachedResult?
    private let cacheValidity: TimeInterval = 15.0  // 15 second cache

    // Default test hosts
    private var routerHost = "192.168.1.1"
    private let internetHosts = [
        "1.1.1.1",       // Cloudflare DNS
        "8.8.8.8",       // Google DNS
        "208.67.222.222" // OpenDNS
    ]

    private init() {
        // Update router host to actual gateway synchronously
        if let gateway = Self.getDefaultGatewaySync() {
            routerHost = gateway
        }
    }

    // MARK: - Public Methods

    /// Start monitoring network quality
    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // Initial measurement
        Task.detached(priority: .userInitiated) {
            await Self.shared.updateAllMeasurements()
        }

        // Setup recurring measurements
        pingTimer = DispatchSource.makeTimerSource(queue: queue)
        pingTimer?.schedule(deadline: .now() + pingInterval, repeating: pingInterval)
        pingTimer?.setEventHandler { [weak self] in
            Task.detached(priority: .userInitiated) {
                await self?.updateAllMeasurements()
            }
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

    /// Perform a single router quality test (with caching)
    public func testRouterQuality() async -> NetworkQualityData {
        // Check cache first
        if let cached = cachedRouterResult,
           Date().timeIntervalSince(cached.timestamp) < cacheValidity {
            logger.debug("Using cached router quality result")
            return cached.data
        }

        // Try to detect gateway if we haven't found a better one
        if routerHost == "192.168.1.1" || routerHost == "192.168.0.1" {
            if let gateway = await detectDefaultGatewayAsync() {
                routerHost = gateway
            }
        }

        let result = await pingHost(routerHost, targetName: "Router")

        // Log results for debugging
        if let ping = result.ping {
            logger.debug("Router ping: \(String(format: "%.1f", ping * 1000))ms, jitter: \(result.jitter != nil ? String(format: "%.1f", result.jitter! * 1000) : "N/A")ms, loss: \(result.packetLoss != nil ? String(format: "%.0f", result.packetLoss!) : "N/A")%")
        } else {
            logger.warning("Router ping failed - all pings timed out for host: \(self.routerHost)")
        }

        // Update cache
        await MainActor.run {
            self.cachedRouterResult = CachedResult(data: result, timestamp: Date())
            self.routerQuality = result
        }

        return result
    }

    /// Perform a single internet quality test (with caching)
    public func testInternetQuality() async -> NetworkQualityData {
        // Check cache first
        if let cached = cachedInternetResult,
           Date().timeIntervalSince(cached.timestamp) < cacheValidity {
            logger.debug("Using cached internet quality result")
            return cached.data
        }

        let primaryHost = internetHosts[0]
        let result = await pingHost(primaryHost, targetName: "Internet")

        // Log results
        if let ping = result.ping {
            logger.debug("Internet ping: \(String(format: "%.1f", ping * 1000))ms, jitter: \(result.jitter != nil ? String(format: "%.1f", result.jitter! * 1000) : "N/A")ms")
        }

        // Update cache
        await MainActor.run {
            self.cachedInternetResult = CachedResult(data: result, timestamp: Date())
            self.internetQuality = result
        }

        return result
    }

    /// Invalidate cache (call after network changes)
    public func invalidateCache() {
        cachedRouterResult = nil
        cachedInternetResult = nil
        logger.debug("Network quality cache invalidated")
    }

    /// Update all quality measurements (background)
    private func updateAllMeasurements() async {
        let routerResult = await testRouterQuality()
        let internetResult = await testInternetQuality()

        await MainActor.run {
            self.routerQuality = routerResult
            self.internetQuality = internetResult
        }
    }

    // MARK: - Gateway Detection

    /// Synchronous gateway detection using system command
    private static func getDefaultGatewaySync() -> String? {
        // Use netstat to get default gateway
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        process.arguments = ["-nr", "-f", "inet"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }

            // Parse netstat output: "default 192.168.1.1 UGSc 0 0 en0"
            let lines = output.components(separatedBy: "\n")
            for line in lines {
                if line.contains("default") {
                    let components = line.split(separator: " ", omittingEmptySubsequences: true)
                    if components.count >= 2 {
                        return String(components[1])
                    }
                }
            }
        } catch {
            // Silently fall back to default
        }

        return nil
    }

    /// Async gateway detection by trying common IPs
    private func detectDefaultGatewayAsync() async -> String? {
        let commonGateways = [
            "192.168.1.1", "192.168.0.1", "192.168.2.1",
            "192.168.1.254", "192.168.0.254",
            "10.0.0.1", "10.0.1.1",
            "192.168.10.1", "192.168.50.1"
        ]

        for gw in commonGateways {
            // Quick check - if we can ping it, it's the gateway
            if await quickPingCheck(gw) {
                logger.debug("Detected gateway: \(gw)")
                return gw
            }
        }

        return nil
    }

    /// Quick ping check to see if host is reachable
    private func quickPingCheck(_ host: String) async -> Bool {
        let result = await singleSystemPing(host: host, timeout: 0.5)
        return !result.isEmpty
    }

    // MARK: - ICMP Ping Implementation

    /// Ping a host using system ICMP ping and return quality metrics
    private func pingHost(_ host: String, targetName: String) async -> NetworkQualityData {
        let pingResults = await runSystemPing(host: host, count: pingCount)

        // Calculate metrics from real ping times
        let avgPing: TimeInterval?
        if !pingResults.isEmpty {
            avgPing = pingResults.reduce(0, +) / Double(pingResults.count)
        } else {
            avgPing = nil
        }

        let jitter: TimeInterval?
        if pingResults.count >= 2, let avg = avgPing {
            let variance = pingResults.map { pow($0 - avg, 2) }.reduce(0, +) / Double(pingResults.count)
            jitter = sqrt(variance)
        } else {
            jitter = nil
        }

        let packetLoss: Double?
        if pingCount > 0 {
            packetLoss = (Double(pingCount - pingResults.count) / Double(pingCount)) * 100
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

    /// Run multiple system ping commands in parallel
    private func runSystemPing(host: String, count: Int) async -> [TimeInterval] {
        await withTaskGroup(of: TimeInterval?.self) { group in
            var results: [TimeInterval] = []

            for _ in 0..<count {
                group.addTask {
                    await self.singleSystemPing(host: host, timeout: self.pingTimeout)
                        .first
                }
            }

            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }

            return results
        }
    }

    /// Single ICMP ping using system ping command
    private func singleSystemPing(host: String, timeout: TimeInterval) async -> [TimeInterval] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")

        // -c 1: send 1 ping
        // -W <seconds>: timeout in seconds
        let timeoutMs = Int(timeout * 1000)
        process.arguments = ["-c", "1", "-W", String(timeoutMs), host]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return []
            }

            return parsePingOutput(output)
        } catch {
            logger.debug("Ping command failed: \(error.localizedDescription)")
            return []
        }
    }

    /// Parse ping output to extract time values
    /// Format: "64 bytes from 192.168.1.1: icmp_seq=0 ttl=64 time=2.5 ms"
    private func parsePingOutput(_ output: String) -> [TimeInterval] {
        var times: [TimeInterval] = []

        // Match pattern: time=<number> ms (handles both integers and decimals)
        let timePattern = /time=(\d+\.?\d*)\s*ms/

        for match in output.matches(of: timePattern) {
            let timeValue = String(match.output.1)
            if let time = Double(timeValue) {
                // Convert milliseconds to seconds
                times.append(time / 1000.0)
            }
        }

        return times
    }
}
