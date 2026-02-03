//
//  DNSService.swift
//  Tonic
//
//  Service for DNS configuration and performance testing
//  Task ID: fn-2.8.4
//

import Foundation
import Network
import os
import SystemConfiguration

// MARK: - DNS Service

/// Service for DNS configuration and performance testing
@MainActor
@Observable
public final class DNSService {
    public static let shared = DNSService()

    private let logger = Logger(subsystem: "com.tonic.app", category: "DNSService")

    // Current DNS data
    public private(set) var currentDNS: DNSData?

    // Test domains for lookup
    private let testDomains = [
        "example.com",
        "www.apple.com",
        "www.cloudflare.com"
    ]

    private init() {
        updateDNSInfo()
    }

    // MARK: - Public Methods

    /// Update DNS information from system configuration
    public func updateDNSInfo() {
        let servers = getDNSServers()
        let source = determineDNSSource()

        Task {
            let lookupTime = await performDNSLookupTest()

            await MainActor.run {
                self.currentDNS = DNSData(
                    servers: servers,
                    source: source,
                    lookupTime: lookupTime,
                    testDomain: testDomains.randomElement() ?? testDomains[0]
                )
            }
        }
    }

    /// Perform a DNS lookup test
    public func testLookup(for domain: String) async -> TimeInterval? {
        return await performSingleLookup(domain)
    }

    /// Refresh DNS configuration
    public func refresh() {
        updateDNSInfo()
    }

    // MARK: - DNS Server Detection

    /// Get configured DNS servers from the system
    private func getDNSServers() -> [String] {
        var servers: [String] = []

        // Try SCDynamicStore API for DNS configuration
        if let store = SCDynamicStoreCreate(nil, "com.tonic.dns" as CFString, nil, nil),
           let dnsConfig = SCDynamicStoreCopyValue(store, "State:/Network/Global/DNS" as CFString) as? [String: Any] {

            if let serverAddresses = dnsConfig["ServerAddresses"] as? [String] {
                servers = serverAddresses
            }

            // Also check for per-service DNS
            if let services = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
               let primaryService = services["PrimaryService"] as? String {

                let serviceKey = "State:/Network/Service/\(primaryService)/DNS" as CFString
                if let serviceDNS = SCDynamicStoreCopyValue(store, serviceKey) as? [String: Any],
                   let serviceServers = serviceDNS["ServerAddresses"] as? [String] {
                    servers = serviceServers
                }
            }
        }

        // Fallback: read from resolv.conf
        if servers.isEmpty {
            servers = parseResolvConf()
        }

        // Known DNS server identification
        return servers.isEmpty ? ["Unknown"] : servers
    }

    /// Parse /etc/resolv.conf for DNS servers
    private func parseResolvConf() -> [String] {
        var servers: [String] = []

        guard let _ = "/etc/resolv.conf".cString(using: .utf8),
              let resolvConf = try? String(contentsOfFile: "/etc/resolv.conf") else {
            return servers
        }

        let lines = resolvConf.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("nameserver") {
                let parts = trimmed.components(separatedBy: .whitespaces)
                if parts.count >= 2, let server = parts.last {
                    servers.append(server)
                }
            }
        }

        return servers
    }

    /// Determine how DNS was configured
    private func determineDNSSource() -> DNSSource {
        let servers = getDNSServers()

        // Check for encrypted/secure DNS indicators
        if isEncryptedDNSEnabled() {
            return .secure
        }

        // Check for known public DNS
        if servers.contains("1.1.1.1") || servers.contains("1.0.0.1") {
            return .manual  // Cloudflare
        }
        if servers.contains("8.8.8.8") || servers.contains("8.8.4.4") {
            return .manual  // Google
        }
        if servers.contains("208.67.222.222") || servers.contains("208.67.220.220") {
            return .manual  // OpenDNS
        }

        // Check if it's a private router IP
        for server in servers {
            if isRouterIP(server) {
                return .router
            }
        }

        // Assume DHCP assigned
        return .dhcp
    }

    /// Check if encrypted DNS (DoH/DoT) is enabled
    private func isEncryptedDNSEnabled() -> Bool {
        // Check for macOS encrypted DNS settings
        if let store = SCDynamicStoreCreate(nil, "com.tonic.dns" as CFString, nil, nil),
           let dnsConfig = SCDynamicStoreCopyValue(store, "State:/Network/Privacy/DNS" as CFString) as? [String: Any] {

            // If this key exists, encrypted DNS is likely enabled
            return dnsConfig["Enabled"] as? Bool ?? false
        }

        return false
    }

    /// Check if an IP address is likely a router
    private func isRouterIP(_ ip: String) -> Bool {
        // Common router IP ranges
        let routerPrefixes = [
            "192.168.",
            "10.0.",
            "10.1.",
            "172.16.",
            "192.168.0.",
            "192.168.1.",
            "192.168.2."
        ]

        for prefix in routerPrefixes {
            if ip.hasPrefix(prefix) {
                return true
            }
        }

        return false
    }

    // MARK: - DNS Lookup Testing

    /// Perform DNS lookup test with multiple domains
    private func performDNSLookupTest() async -> TimeInterval? {
        var times: [TimeInterval] = []

        for domain in testDomains.prefix(3) {
            if let time = await performSingleLookup(domain) {
                times.append(time)
            }
        }

        return times.isEmpty ? nil : (times.reduce(0, +) / Double(times.count))
    }

    /// Perform a single DNS lookup and return the time taken
    private func performSingleLookup(_ domain: String) async -> TimeInterval? {
        return await withCheckedContinuation { continuation in
            let host = NWEndpoint.Host(domain)
            let startTime = Date()

            // Use NWConnection to resolve the host
            // This triggers DNS resolution
            let connection = NWConnection(
                to: .hostPort(host: host, port: 443),
                using: .tls
            )

            var hasResumed = false
            let resumeOnce = { (result: TimeInterval?) in
                guard !hasResumed else { return }
                hasResumed = true
                connection.cancel()
                continuation.resume(returning: result)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready, .preparing:
                    // DNS resolution happened
                    let elapsed = Date().timeIntervalSince(startTime)
                    resumeOnce(elapsed)
                case .failed:
                    resumeOnce(nil)
                default:
                    break
                }
            }

            connection.start(queue: .global())

            // Timeout after 2 seconds
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                resumeOnce(nil)
            }
        }
    }

    // MARK: - Known DNS Servers

    /// Get display name for a DNS server IP
    public func getDNSDisplayName(_ ip: String) -> String {
        switch ip {
        case "1.1.1.1", "1.0.0.1":
            return "Cloudflare"
        case "8.8.8.8", "8.8.4.4":
            return "Google"
        case "208.67.222.222", "208.67.220.220":
            return "OpenDNS"
        case "9.9.9.9", "149.112.112.112":
            return "Quad9"
        case "64.6.64.6", "64.6.65.6":
            return "Verisign"
        case "185.228.168.9", "185.228.169.9":
            return "CleanBrowsing"
        case "Unknown":
            return "Unknown"
        default:
            if isRouterIP(ip) {
                return "Router"
            }
            return ip
        }
    }

    /// Get icon for DNS server type
    public func getDNSIcon(for source: DNSSource) -> String {
        return source.icon
    }
}

// MARK: - CFString Extension

private extension String {
    var cfString: CFString {
        self as CFString
    }
}
