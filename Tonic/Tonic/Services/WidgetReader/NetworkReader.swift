//
//  NetworkReader.swift
//  Tonic
//
//  Network data reader conforming to WidgetReader protocol
//  Follows Stats Master's Network module reader pattern
//  Task ID: fn-5-v8r.5
//

import Foundation
import CoreWLAN
import SystemConfiguration

/// Network data reader conforming to WidgetReader protocol
/// Follows Stats Master's Network module UsageReader pattern
@MainActor
final class NetworkReader: WidgetReader {
    typealias Output = NetworkData

    let preferredInterval: TimeInterval = 2.0

    private var previousStats: (bytesIn: UInt64, bytesOut: UInt64, timestamp: Date)?
    private let statsLock = NSLock()

    // Cached interface info
    private var primaryInterface: String {
        get {
            if let global = SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4" as CFString),
               let name = global["PrimaryInterface"] as? String {
                return name
            }
            return "en0"
        }
    }

    init() {}

    func read() async throws -> NetworkData {
        // Run on background thread for stats collection
        return await Task.detached {
            self.getNetworkData()
        }.value
    }

    private func getNetworkData() async -> NetworkData {
        let (totalBytesIn, totalBytesOut) = getNetworkStats()

        statsLock.lock()
        let now = Date()
        var uploadRate: Double = 0
        var downloadRate: Double = 0
        var isConnected = true

        if let previous = previousStats {
            let timeDelta = now.timeIntervalSince(previous.timestamp)

            if timeDelta > 0 {
                uploadRate = Double(totalBytesOut - previous.bytesOut) / timeDelta
                downloadRate = Double(totalBytesIn - previous.bytesIn) / timeDelta
            }

            // Consider connected if activity detected or recent check
            isConnected = (totalBytesIn != previous.bytesIn || totalBytesOut != previous.bytesOut) || timeDelta < 5.0
        }

        previousStats = (totalBytesIn, totalBytesOut, now)
        statsLock.unlock()

        // Get connection info
        let connectionType = getConnectionType()
        let ssid = getWiFiSSID()
        let ipAddress = getLocalIP()

        return NetworkData(
            uploadBytesPerSecond: max(0, uploadRate),
            downloadBytesPerSecond: max(0, downloadRate),
            isConnected: isConnected,
            connectionType: connectionType,
            ssid: ssid,
            ipAddress: ipAddress,
            timestamp: now
        )
    }

    // MARK: - Private Methods

    private func getNetworkStats() -> (UInt64, UInt64) {
        var totalBytesIn: UInt64 = 0
        var totalBytesOut: UInt64 = 0

        // mib array: CTL_NET, PF_ROUTE, 0 (protocol), 0 (address family - all), NET_RT_IFLIST2, 0 (interface index - all)
        var mib: [Int32] = [CTL_NET, Int32(PF_ROUTE), 0, 0, NET_RT_IFLIST2, 0]
        var len: Int = 0

        // First call to get required buffer size
        if sysctl(&mib, UInt32(mib.count), nil, &len, nil, 0) != 0 {
            return (0, 0)
        }

        guard len > 0 else {
            return (0, 0)
        }

        var buffer = [UInt8](repeating: 0, count: len)
        if sysctl(&mib, UInt32(mib.count), &buffer, &len, nil, 0) != 0 {
            return (0, 0)
        }

        // Process the buffer
        buffer.withUnsafeBytes { rawBuffer in
            var offset = 0
            while offset + MemoryLayout<if_msghdr2>.size <= len {
                let msgPtr = rawBuffer.baseAddress!.advanced(by: offset)
                let ifm = msgPtr.assumingMemoryBound(to: if_msghdr2.self).pointee

                guard ifm.ifm_msglen > 0 else { break }

                if Int32(ifm.ifm_type) == RTM_IFINFO2 {
                    // Accumulate stats from all active interfaces
                    totalBytesIn += ifm.ifm_data.ifi_ibytes
                    totalBytesOut += ifm.ifm_data.ifi_obytes
                }

                offset += Int(ifm.ifm_msglen)
            }
        }

        return (totalBytesIn, totalBytesOut)
    }

    private func getConnectionType() -> ConnectionType {
        // Use CoreWLAN to detect connection type
        let client = CWWiFiClient.shared()
        if let interface = client.interfaces()?.first, interface.powerOn() {
            if interface.ssid() != nil {
                return .wifi
            }
        }

        // Check for ethernet by examining interfaces
        var ifaddrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrs) == 0, let firstAddr = ifaddrs else {
            return .unknown
        }

        defer { freeifaddrs(ifaddrs) }

        var hasEthernet = false
        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            let interface = String(cString: current.pointee.ifa_name)
            let addrFamily = current.pointee.ifa_addr.pointee.sa_family

            // Check for active ethernet interfaces
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                // en0 is typically WiFi on macOS, other en* could be ethernet
                if interface.hasPrefix("en") && interface != "en0" {
                    hasEthernet = true
                }
            }

            ptr = current.pointee.ifa_next
        }

        return hasEthernet ? .ethernet : .unknown
    }

    private func getWiFiSSID() -> String? {
        // Use CoreWLAN to get the current SSID
        let client = CWWiFiClient.shared()
        if let interface = client.interfaces()?.first, interface.powerOn() {
            return interface.ssid()
        }
        return nil
    }

    private func getLocalIP() -> String? {
        var ifaddrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrs) == 0, let firstAddr = ifaddrs else {
            return nil
        }

        defer { freeifaddrs(ifaddrs) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            var addr = current.pointee.ifa_addr.pointee

            guard addr.sa_family == UInt8(AF_INET) else {
                ptr = current.pointee.ifa_next
                continue
            }

            var ip = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(
                &addr,
                socklen_t(addr.sa_len),
                &ip,
                Int32(ip.count),
                nil,
                0,
                NI_NUMERICHOST
            )

            let ipStr = String(cString: ip)
            if !ipStr.isEmpty && ipStr != "127.0.0.1" {
                return ipStr
            }

            ptr = current.pointee.ifa_next
        }

        return nil
    }
}

// MARK: - Constants

private let CTL_NET = 4
private let PF_ROUTE = 17
private let NET_RT_IFLIST2: Int32 = 0x0106
private let RTM_IFINFO2: Int32 = 0x14
private let AF_INET = UInt8(2)
private let AF_INET6 = UInt8(30)
private let IFF_UP = UInt32(0x1)
private let NI_MAXHOST = 1025
private let NI_NUMERICHOST = 0x01
