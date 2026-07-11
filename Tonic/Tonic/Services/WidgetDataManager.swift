//
//  WidgetDataManager.swift
//  Tonic
//
//  Central data manager for menu bar widgets
//  Task ID: fn-2.2
//

import Foundation
import IOKit.ps
import IOKit
import CoreWLAN
import AppKit
import MachO
import SwiftUI
import os
import Network
import SystemConfiguration
import Darwin

// MARK: - proc_pid_rusage types

@_silgen_name("proc_pid_rusage")
func proc_pid_rusage(_ pid: Int32, _ flavor: Int32, _ buffer: UnsafeMutablePointer<rusage_info_v2>) -> Int32

public var RUSAGE_INFO_V2: Int32 { 2 }

// rusage_info_v2 structure for per-process resource usage
public struct rusage_info_v2 {
    public var ri_uuid: uuid_t
    public var ri_user_time: UInt64
    public var ri_system_time: UInt64
    public var ri_pkg_idle_wkups: UInt64
    public var ri_pkg_wkups: UInt64
    public var ri_interrupt_wkups: UInt64
    public var ri_pageins: UInt64
    public var ri_wired_size: UInt64
    public var ri_resident_size: UInt64
    public var ri_phys_footprint: UInt64
    public var ri_start_time: UInt64
    public var ri_proc_start_abstime: UInt64
    public var ri_proc_exit_abstime: UInt64
    public var ri_child_user_time: UInt64
    public var ri_child_system_time: UInt64
    public var ri_child_pkg_idle_wkups: UInt64
    public var ri_child_pkg_wkups: UInt64
    public var ri_child_interrupt_wkups: UInt64
    public var ri_child_pageins: UInt64
    public var ri_child_elapsed_abstime: UInt64
    public var ri_diskio_bytesread: UInt64
    public var ri_diskio_byteswritten: UInt64

    public init() {
        ri_uuid = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        ri_user_time = 0
        ri_system_time = 0
        ri_pkg_idle_wkups = 0
        ri_pkg_wkups = 0
        ri_interrupt_wkups = 0
        ri_pageins = 0
        ri_wired_size = 0
        ri_resident_size = 0
        ri_phys_footprint = 0
        ri_start_time = 0
        ri_proc_start_abstime = 0
        ri_proc_exit_abstime = 0
        ri_child_user_time = 0
        ri_child_system_time = 0
        ri_child_pkg_idle_wkups = 0
        ri_child_pkg_wkups = 0
        ri_child_interrupt_wkups = 0
        ri_child_pageins = 0
        ri_child_elapsed_abstime = 0
        ri_diskio_bytesread = 0
        ri_diskio_byteswritten = 0
    }
}

// MARK: - IOKit Constants

// Missing IOKit constants for block storage drivers
private let kIOBlockStorageDriverClass = "IOBlockStorageDriver"
private let kIOBlockStorageDriverStatisticsKey = "Statistics"
private let kIOBlockStorageDriverStatisticsBytesReadKey = "BytesRead"
private let kIOBlockStorageDriverStatisticsBytesWrittenKey = "BytesWritten"
private let kIOPropertyPlaneKey = "IOPropertyPlane"
private let kIOPropertyThermalInformationKey = "ThermalInformation"

// MARK: - Widget Data Models

/// CPU usage data for widgets
public struct CPUData: Sendable {
    public let totalUsage: Double
    public let perCoreUsage: [Double]
    public let eCoreUsage: [Double]?       // Efficiency core usage values
    public let pCoreUsage: [Double]?       // Performance core usage values
    public let frequency: Double?          // Current CPU frequency in GHz
    public let eCoreFrequency: Double?     // Efficiency cores frequency in GHz
    public let pCoreFrequency: Double?     // Performance cores frequency in GHz
    public let temperature: Double?        // CPU temperature in Celsius
    public let thermalLimit: Bool?         // Whether CPU is being thermally throttled
    public let averageLoad: [Double]?      // 1-minute, 5-minute, 15-minute load averages

    // Enhanced fields for Stats Master parity
    public let systemUsage: Double         // System CPU usage percentage
    public let userUsage: Double           // User CPU usage percentage
    public let idleUsage: Double           // Idle CPU usage percentage
    public let uptime: TimeInterval        // Seconds since boot
    public let schedulerLimit: Double?     // Max CPU scheduler limit
    public let speedLimit: Double?         // CPU speed limit percentage
    public let topProcesses: [ProcessUsage]?  // Top CPU-consuming processes (popup only)

    public let timestamp: Date

    public init(
        totalUsage: Double,
        perCoreUsage: [Double],
        eCoreUsage: [Double]? = nil,
        pCoreUsage: [Double]? = nil,
        frequency: Double? = nil,
        eCoreFrequency: Double? = nil,
        pCoreFrequency: Double? = nil,
        temperature: Double? = nil,
        thermalLimit: Bool? = nil,
        averageLoad: [Double]? = nil,
        systemUsage: Double = 0,
        userUsage: Double = 0,
        idleUsage: Double = 100,
        uptime: TimeInterval = 0,
        schedulerLimit: Double? = nil,
        speedLimit: Double? = nil,
        topProcesses: [ProcessUsage]? = nil,
        timestamp: Date = Date()
    ) {
        self.totalUsage = totalUsage
        self.perCoreUsage = perCoreUsage
        self.eCoreUsage = eCoreUsage
        self.pCoreUsage = pCoreUsage
        self.frequency = frequency
        self.eCoreFrequency = eCoreFrequency
        self.pCoreFrequency = pCoreFrequency
        self.temperature = temperature
        self.thermalLimit = thermalLimit
        self.averageLoad = averageLoad
        self.systemUsage = systemUsage
        self.userUsage = userUsage
        self.idleUsage = idleUsage
        self.uptime = uptime
        self.schedulerLimit = schedulerLimit
        self.speedLimit = speedLimit
        self.topProcesses = topProcesses
        self.timestamp = timestamp
    }

    /// Backward-compatible initializer for existing code
    public init(totalUsage: Double, perCoreUsage: [Double], timestamp: Date) {
        self.totalUsage = totalUsage
        self.perCoreUsage = perCoreUsage
        self.eCoreUsage = nil
        self.pCoreUsage = nil
        self.frequency = nil
        self.eCoreFrequency = nil
        self.pCoreFrequency = nil
        self.temperature = nil
        self.thermalLimit = nil
        self.averageLoad = nil
        self.systemUsage = 0
        self.userUsage = 0
        self.idleUsage = 100
        self.uptime = 0
        self.schedulerLimit = nil
        self.speedLimit = nil
        self.topProcesses = nil
        self.timestamp = timestamp
    }
}

/// Memory usage data for widgets
public struct MemoryData: Sendable {
    public let usedBytes: UInt64
    public let totalBytes: UInt64
    public let pressure: MemoryPressure
    public let compressedBytes: UInt64
    public let swapBytes: UInt64
    public let timestamp: Date

    // Enhanced properties for Stats Master parity
    public let freeBytes: UInt64?                      // Calculated free memory
    public let activeBytes: UInt64?                    // Active memory pages
    public let swapTotalBytes: UInt64?                 // Total swap space available
    public let swapUsedBytes: UInt64?                  // Actual swap space used
    public let pressureValue: Double?                  // Memory pressure on 0-100 scale
    public let topProcesses: [AppResourceUsage]?       // Top memory-consuming processes

    /// Full initializer with all enhanced properties
    public init(
        usedBytes: UInt64,
        totalBytes: UInt64,
        pressure: MemoryPressure,
        compressedBytes: UInt64 = 0,
        swapBytes: UInt64 = 0,
        freeBytes: UInt64? = nil,
        activeBytes: UInt64? = nil,
        swapTotalBytes: UInt64? = nil,
        swapUsedBytes: UInt64? = nil,
        pressureValue: Double? = nil,
        topProcesses: [AppResourceUsage]? = nil,
        timestamp: Date = Date()
    ) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.pressure = pressure
        self.compressedBytes = compressedBytes
        self.swapBytes = swapBytes
        self.freeBytes = freeBytes
        self.activeBytes = activeBytes
        self.swapTotalBytes = swapTotalBytes
        self.swapUsedBytes = swapUsedBytes
        self.pressureValue = pressureValue
        self.topProcesses = topProcesses
        self.timestamp = timestamp
    }

    /// Backward-compatible initializer for existing code
    public init(usedBytes: UInt64, totalBytes: UInt64, pressure: MemoryPressure,
                compressedBytes: UInt64 = 0, swapBytes: UInt64 = 0, timestamp: Date = Date()) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.pressure = pressure
        self.compressedBytes = compressedBytes
        self.swapBytes = swapBytes
        self.timestamp = timestamp
        // Enhanced properties default to nil for backward compatibility
        self.freeBytes = nil
        self.activeBytes = nil
        self.swapTotalBytes = nil
        self.swapUsedBytes = nil
        self.pressureValue = nil
        self.topProcesses = nil
    }

    public var usagePercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }

    /// Swap usage percentage
    public var swapUsagePercentage: Double? {
        guard let swapTotal = swapTotalBytes, swapTotal > 0 else { return nil }
        return Double(swapUsedBytes ?? 0) / Double(swapTotal) * 100
    }

    /// Free memory percentage
    public var freePercentage: Double? {
        guard totalBytes > 0 else { return nil }
        return Double(freeBytes ?? 0) / Double(totalBytes) * 100
    }
}

/// Disk volume data for widgets
public struct DiskVolumeData: Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let path: String
    public let usedBytes: UInt64
    public let totalBytes: UInt64
    public let isBootVolume: Bool
    public let isInternal: Bool
    public let isActive: Bool
    public let timestamp: Date

    // Enhanced properties for Stats Master parity
    public let smartData: NVMeSMARTData?           // NVMe SMART health data
    public let readIOPS: Double?                   // Read operations per second
    public let writeIOPS: Double?                  // Write operations per second
    public let readBytesPerSecond: Double?         // Read throughput (bytes/sec)
    public let writeBytesPerSecond: Double?        // Write throughput (bytes/sec)
    public let readTime: TimeInterval?             // Total read time (milliseconds from IOKit)
    public let writeTime: TimeInterval?            // Total write time (milliseconds from IOKit)
    public let topProcesses: [ProcessUsage]?       // Top disk I/O processes

    public init(name: String, path: String, usedBytes: UInt64, totalBytes: UInt64,
                isBootVolume: Bool = false, isInternal: Bool = true, isActive: Bool = false,
                smartData: NVMeSMARTData? = nil,
                readIOPS: Double? = nil, writeIOPS: Double? = nil,
                readBytesPerSecond: Double? = nil, writeBytesPerSecond: Double? = nil,
                readTime: TimeInterval? = nil, writeTime: TimeInterval? = nil,
                topProcesses: [ProcessUsage]? = nil,
                timestamp: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.isBootVolume = isBootVolume
        self.isInternal = isInternal
        self.isActive = isActive
        self.smartData = smartData
        self.readIOPS = readIOPS
        self.writeIOPS = writeIOPS
        self.readBytesPerSecond = readBytesPerSecond
        self.writeBytesPerSecond = writeBytesPerSecond
        self.readTime = readTime
        self.writeTime = writeTime
        self.topProcesses = topProcesses
        self.timestamp = timestamp
    }

    public var usagePercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }

    public var freeBytes: UInt64 {
        max(0, totalBytes - usedBytes)
    }

    /// Combined IOPS (read + write)
    public var totalIOPS: Double? {
        guard let read = readIOPS, let write = writeIOPS else { return nil }
        return read + write
    }

    /// Combined throughput (read + write)
    public var totalBytesPerSecond: Double? {
        guard let read = readBytesPerSecond, let write = writeBytesPerSecond else { return nil }
        return read + write
    }

    /// Formatted read throughput string
    public var readThroughputString: String? {
        guard let readBytesPerSecond = readBytesPerSecond else { return nil }
        return formatBytesPerSecond(readBytesPerSecond)
    }

    /// Formatted write throughput string
    public var writeThroughputString: String? {
        guard let writeBytesPerSecond = writeBytesPerSecond else { return nil }
        return formatBytesPerSecond(writeBytesPerSecond)
    }

    private func formatBytesPerSecond(_ bytes: Double) -> String {
        if bytes >= 1_000_000 {
            return String(format: "%.1f MB/s", bytes / 1_000_000)
        } else if bytes >= 1_000 {
            return String(format: "%.1f KB/s", bytes / 1_000)
        } else {
            return String(format: "%.0f B/s", bytes)
        }
    }
}

/// Network data for widgets
public struct NetworkData: Sendable {
    public let uploadBytesPerSecond: Double
    public let downloadBytesPerSecond: Double
    public let isConnected: Bool
    public let connectionType: ConnectionType
    public let ssid: String?
    public let ipAddress: String?
    public let timestamp: Date

    // Enhanced properties for Stats Master parity
    public let wifiDetails: WiFiDetails?           // Extended WiFi information
    public let publicIP: PublicIPInfo?             // Public IP with geolocation
    public let connectivity: ConnectivityInfo?     // Latency, jitter, reachability
    public let topProcesses: [ProcessNetworkUsage]?  // Top network-using processes
    public let interfaceName: String?              // Primary interface (e.g., en0)
    public let macAddress: String?                 // MAC address of primary interface
    public let linkSpeedMbps: Double?              // Link speed in Mbps (if available)
    public let dnsServers: [String]                // DNS server list

    public init(uploadBytesPerSecond: Double, downloadBytesPerSecond: Double,
                isConnected: Bool, connectionType: ConnectionType = .unknown,
                ssid: String? = nil, ipAddress: String? = nil,
                wifiDetails: WiFiDetails? = nil,
                publicIP: PublicIPInfo? = nil,
                connectivity: ConnectivityInfo? = nil,
                topProcesses: [ProcessNetworkUsage]? = nil,
                interfaceName: String? = nil,
                macAddress: String? = nil,
                linkSpeedMbps: Double? = nil,
                dnsServers: [String] = [],
                timestamp: Date = Date()) {
        self.uploadBytesPerSecond = uploadBytesPerSecond
        self.downloadBytesPerSecond = downloadBytesPerSecond
        self.isConnected = isConnected
        self.connectionType = connectionType
        self.ssid = ssid
        self.ipAddress = ipAddress
        self.wifiDetails = wifiDetails
        self.publicIP = publicIP
        self.connectivity = connectivity
        self.topProcesses = topProcesses
        self.interfaceName = interfaceName
        self.macAddress = macAddress
        self.linkSpeedMbps = linkSpeedMbps
        self.dnsServers = dnsServers
        self.timestamp = timestamp
    }

    /// Backward-compatible initializer for existing code
    public init(uploadBytesPerSecond: Double, downloadBytesPerSecond: Double,
                isConnected: Bool, connectionType: ConnectionType = .unknown,
                ssid: String? = nil, ipAddress: String? = nil, timestamp: Date = Date()) {
        self.uploadBytesPerSecond = uploadBytesPerSecond
        self.downloadBytesPerSecond = downloadBytesPerSecond
        self.isConnected = isConnected
        self.connectionType = connectionType
        self.ssid = ssid
        self.ipAddress = ipAddress
        self.wifiDetails = nil
        self.publicIP = nil
        self.connectivity = nil
        self.topProcesses = nil
        self.interfaceName = nil
        self.macAddress = nil
        self.linkSpeedMbps = nil
        self.dnsServers = []
        self.timestamp = timestamp
    }

    public var uploadMbps: Double {
        uploadBytesPerSecond * 8 / 1_000_000
    }

    public var downloadMbps: Double {
        downloadBytesPerSecond * 8 / 1_000_000
    }

    public var uploadString: String {
        formatBytes(uploadBytesPerSecond)
    }

    public var downloadString: String {
        formatBytes(downloadBytesPerSecond)
    }

    private func formatBytes(_ bytes: Double) -> String {
        if bytes >= 1_000_000 {
            return String(format: "%.1f MB/s", bytes / 1_000_000)
        } else if bytes >= 1_000 {
            return String(format: "%.1f KB/s", bytes / 1_000)
        } else {
            return String(format: "%.0f B/s", bytes)
        }
    }
}

// ConnectionType is now defined in NetworkDetails.swift with enhanced cases

/// GPU data for widgets (Apple Silicon only)
public struct GPUData: Sendable {
    public let usagePercentage: Double?
    public let usedMemory: UInt64?
    public let totalMemory: UInt64?
    public let temperature: Double? // Celsius
    public let timestamp: Date

    // Enhanced properties for Stats Master parity (fn-8-v3b.6)
    public let renderUtilization: Double?   // GPU render engine utilization
    public let tilerUtilization: Double?    // GPU tiler engine utilization
    public let coreClock: Double?           // GPU core clock in MHz
    public let memoryClock: Double?         // GPU memory clock in MHz
    public let fanSpeed: Int?               // GPU fan speed in RPM
    public let vendor: String?              // GPU vendor name
    public let model: String?               // GPU model name
    public let cores: Int?                  // Number of GPU cores
    public let isActive: Bool?              // Whether GPU is currently active

    public init(
        usagePercentage: Double? = nil,
        usedMemory: UInt64? = nil,
        totalMemory: UInt64? = nil,
        temperature: Double? = nil,
        renderUtilization: Double? = nil,
        tilerUtilization: Double? = nil,
        coreClock: Double? = nil,
        memoryClock: Double? = nil,
        fanSpeed: Int? = nil,
        vendor: String? = nil,
        model: String? = nil,
        cores: Int? = nil,
        isActive: Bool? = nil,
        timestamp: Date = Date()
    ) {
        self.usagePercentage = usagePercentage
        self.usedMemory = usedMemory
        self.totalMemory = totalMemory
        self.temperature = temperature
        self.renderUtilization = renderUtilization
        self.tilerUtilization = tilerUtilization
        self.coreClock = coreClock
        self.memoryClock = memoryClock
        self.fanSpeed = fanSpeed
        self.vendor = vendor
        self.model = model
        self.cores = cores
        self.isActive = isActive
        self.timestamp = timestamp
    }

    public var memoryUsagePercentage: Double? {
        guard let used = usedMemory, let total = totalMemory, total > 0 else { return nil }
        return Double(used) / Double(total) * 100
    }
}

/// Battery data for widgets
public struct BatteryData: Sendable {
    public let isPresent: Bool
    public let isCharging: Bool
    public let isCharged: Bool
    public let chargePercentage: Double
    public let estimatedMinutesRemaining: Int?
    public let health: BatteryHealth
    public let cycleCount: Int?
    public let temperature: Double?  // Celsius
    public let optimizedCharging: Bool?  // Optimized Battery Charging enabled
    public let chargerWattage: Double?  // Charger wattage (W)

    // Electrical metrics
    public let amperage: Double?           // mA (negative = charging, positive = discharging)
    public let voltage: Double?             // V (from IOKit mV / 1000)
    public let batteryPower: Double?       // W (calculated: voltage × |amperage| / 1000)
    public let designedCapacity: UInt64?   // mAh (design capacity from IOKit)
    public let currentCapacity: UInt64?    // mAh (current capacity)
    public let maxCapacity: UInt64?        // mAh (maximum capacity)
    public let chargingCurrent: Double?    // Adapter current in mA (estimated from wattage)
    public let chargingVoltage: Double?    // Adapter voltage in V (estimated from wattage)
    public let lastChargeTimestamp: Date?  // Time when AC power was last connected

    public let timestamp: Date

    public init(isPresent: Bool, isCharging: Bool = false, isCharged: Bool = false,
                chargePercentage: Double = 0, estimatedMinutesRemaining: Int? = nil,
                health: BatteryHealth = .unknown, cycleCount: Int? = nil,
                temperature: Double? = nil, optimizedCharging: Bool? = nil,
                chargerWattage: Double? = nil,
                amperage: Double? = nil, voltage: Double? = nil, batteryPower: Double? = nil,
                designedCapacity: UInt64? = nil, currentCapacity: UInt64? = nil,
                maxCapacity: UInt64? = nil, chargingCurrent: Double? = nil,
                chargingVoltage: Double? = nil, lastChargeTimestamp: Date? = nil,
                timestamp: Date = Date()) {
        self.isPresent = isPresent
        self.isCharging = isCharging
        self.isCharged = isCharged
        self.chargePercentage = chargePercentage
        self.cycleCount = cycleCount
        self.temperature = temperature
        self.optimizedCharging = optimizedCharging
        self.chargerWattage = chargerWattage
        self.estimatedMinutesRemaining = estimatedMinutesRemaining
        self.health = health
        self.amperage = amperage
        self.voltage = voltage
        self.batteryPower = batteryPower
        self.designedCapacity = designedCapacity
        self.currentCapacity = currentCapacity
        self.maxCapacity = maxCapacity
        self.chargingCurrent = chargingCurrent
        self.chargingVoltage = chargingVoltage
        self.lastChargeTimestamp = lastChargeTimestamp
        self.timestamp = timestamp
    }

    /// Backward-compatible initializer for existing code
    public init(isPresent: Bool, isCharging: Bool = false, isCharged: Bool = false,
                chargePercentage: Double = 0, estimatedMinutesRemaining: Int? = nil,
                health: BatteryHealth = .unknown, cycleCount: Int? = nil,
                temperature: Double? = nil, timestamp: Date = Date()) {
        self.isPresent = isPresent
        self.isCharging = isCharging
        self.isCharged = isCharged
        self.chargePercentage = chargePercentage
        self.cycleCount = cycleCount
        self.temperature = temperature
        self.estimatedMinutesRemaining = estimatedMinutesRemaining
        self.health = health
        // Enhanced properties default to nil for backward compatibility
        self.optimizedCharging = nil
        self.chargerWattage = nil
        self.amperage = nil
        self.voltage = nil
        self.batteryPower = nil
        self.designedCapacity = nil
        self.currentCapacity = nil
        self.maxCapacity = nil
        self.chargingCurrent = nil
        self.chargingVoltage = nil
        self.lastChargeTimestamp = nil
        self.timestamp = timestamp
    }
}

/// Bluetooth device data for widgets
public struct BluetoothData: Sendable {
    public let isBluetoothEnabled: Bool
    public let connectedDevices: [BluetoothDevice]
    public let timestamp: Date

    public init(isBluetoothEnabled: Bool = false, connectedDevices: [BluetoothDevice] = [], timestamp: Date = Date()) {
        self.isBluetoothEnabled = isBluetoothEnabled
        self.connectedDevices = connectedDevices
        self.timestamp = timestamp
    }

    /// Devices with battery information
    public var devicesWithBattery: [BluetoothDevice] {
        connectedDevices.filter { $0.primaryBatteryLevel != nil }
    }

    /// All connected devices (alias for connectedDevices)
    public var devices: [BluetoothDevice] {
        connectedDevices
    }

    /// Empty Bluetooth data
    public static let empty = BluetoothData()
}

/// Bluetooth device information
public struct BluetoothDevice: Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let deviceType: BluetoothDeviceType
    public let isConnected: Bool
    public let isPaired: Bool
    public let primaryBatteryLevel: Int? // 0-100, nil if no battery (kept for backward compatibility)
    public let signalStrength: Int? // 0-100 RSSI
    public let batteryLevels: [DeviceBatteryLevel] // Multiple battery levels for AirPods-style devices

    public init(id: UUID = UUID(), name: String, deviceType: BluetoothDeviceType = .unknown,
                isConnected: Bool = false, isPaired: Bool = false,
                primaryBatteryLevel: Int? = nil, signalStrength: Int? = nil,
                batteryLevels: [DeviceBatteryLevel] = []) {
        self.id = id
        self.name = name
        self.deviceType = deviceType
        self.isConnected = isConnected
        self.isPaired = isPaired
        self.primaryBatteryLevel = primaryBatteryLevel
        self.signalStrength = signalStrength
        // If batteryLevels is provided, use it; otherwise derive from primaryBatteryLevel
        if batteryLevels.isEmpty, let level = primaryBatteryLevel {
            self.batteryLevels = [DeviceBatteryLevel(label: "Battery", percentage: level)]
        } else {
            self.batteryLevels = batteryLevels
        }
    }

    /// Convenience init with single battery level (backward compatible)
    public init(id: UUID = UUID(), name: String, deviceType: BluetoothDeviceType = .unknown,
                isConnected: Bool = false, isPaired: Bool = false,
                batteryLevel: Int? = nil, signalStrength: Int? = nil) {
        self.id = id
        self.name = name
        self.deviceType = deviceType
        self.isConnected = isConnected
        self.isPaired = isPaired
        self.primaryBatteryLevel = batteryLevel
        self.signalStrength = signalStrength
        if let level = batteryLevel {
            self.batteryLevels = [DeviceBatteryLevel(label: "Battery", percentage: level)]
        } else {
            self.batteryLevels = []
        }
    }

    /// Individual battery level for a device component (Case, Left, Right, etc.)
    public struct DeviceBatteryLevel: Identifiable, Sendable, Codable, Equatable {
        public let id: UUID
        public let label: String
        public let percentage: Int
        public let component: BatteryComponent

        public init(label: String, percentage: Int, component: BatteryComponent = .unknown) {
            self.id = UUID()
            self.label = label
            self.percentage = percentage
            self.component = component
        }

        /// Icon for the battery component
        public var icon: String {
            switch component {
            case .caseBattery: return "airpodsprochargingcase"
            case .left: return "airpods.left"
            case .right: return "airpods.right"
            case .unknown: return "battery.100"
            }
        }
    }

    /// Battery component type for multi-battery devices
    public enum BatteryComponent: String, Sendable, Codable {
        case caseBattery = "Case"
        case left = "Left"
        case right = "Right"
        case unknown = "Unknown"
    }
}

/// Bluetooth device type
public enum BluetoothDeviceType: String, Sendable {
    case unknown
    case headphones
    case speaker
    case keyboard
    case mouse
    case trackpad
    case gameController
    case watch
    case phone
    case tablet

    public var icon: String {
        switch self {
        case .headphones: return "headphones"
        case .speaker: return "hifispeaker"
        case .keyboard: return "keyboard"
        case .mouse: return "computermouse"
        case .trackpad: return "trackpad"
        case .gameController: return "gamecontroller"
        case .watch: return "applewatch"
        case .phone: return "iphone"
        case .tablet: return "ipad"
        case .unknown: return "antenna.radiowaves.left.and.right"
        }
    }
}

/// App resource usage
public struct AppResourceUsage: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let bundleIdentifier: String?
    public let icon: NSImage?
    public let cpuUsage: Double
    public let memoryBytes: UInt64
    public let timestamp: Date

    public init(name: String, bundleIdentifier: String? = nil, icon: NSImage? = nil,
                cpuUsage: Double = 0, memoryBytes: UInt64 = 0, timestamp: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.icon = icon
        self.cpuUsage = cpuUsage
        self.memoryBytes = memoryBytes
        self.timestamp = timestamp
    }

    public var memoryString: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryBytes), countStyle: .memory)
    }
}

// MARK: - Widget Data Manager

/// Central data manager that aggregates and distributes system monitoring data to widgets
@MainActor
@Observable
public final class WidgetDataManager {
    public static let shared = WidgetDataManager()

    private let logger = Logger(subsystem: "com.tonic.app", category: "WidgetDataManager")
    private let logFile: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let path = paths[0].appendingPathComponent("tonic_widget_debug.txt")
        // Clear previous log
        try? FileManager.default.removeItem(at: path)
        return path
    }()

    // MARK: - History Constants

    private let isDebugLoggingEnabled = UserDefaults.standard.bool(forKey: "WidgetDataManagerDebugLogging")

    private func logToFile(_ message: String) {
        guard isDebugLoggingEnabled else { return }
        let data = "\(Date()): \(message)\n".data(using: .utf8)!
        if FileManager.default.fileExists(atPath: logFile.path) {
            if let handle = try? FileHandle(forWritingTo: logFile) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: logFile)
        }
    }

    // Stats Master parity: 180 points for better trend visualization
    private static let maxHistoryPoints = 180

    // MARK: - Circular History Buffers
    // Performance optimization: Use fixed-size arrays instead of removeFirst() to avoid O(n) operations

    /// Circular buffer for efficient history storage
    private struct CircularBuffer {
        private var buffer: [Double]
        private var capacity: Int
        private var head: Int = 0
        private var count: Int = 0

        init(capacity: Int) {
            self.capacity = capacity
            self.buffer = Array(repeating: 0.0, count: capacity)
        }

        mutating func add(_ value: Double) {
            buffer[head] = value
            head = (head + 1) % capacity
            count = min(count + 1, capacity)
        }

        func toArray() -> [Double] {
            if count < capacity {
                return Array(buffer.prefix(count))
            }
            return Array(buffer.suffix(from: head)) + Array(buffer.prefix(head))
        }
    }

    /// Circular buffer for history with O(1) add operation
    private var cpuCircularBuffer = CircularBuffer(capacity: 180)
    private var memoryCircularBuffer = CircularBuffer(capacity: 180)
    private var diskCircularBuffer = CircularBuffer(capacity: 180)
    private var diskReadCircularBuffer = CircularBuffer(capacity: 180)  // Per-disk read rate history
    private var diskWriteCircularBuffer = CircularBuffer(capacity: 180) // Per-disk write rate history
    private var networkUploadCircularBuffer = CircularBuffer(capacity: 180)
    private var networkDownloadCircularBuffer = CircularBuffer(capacity: 180)
    private var gpuCircularBuffer = CircularBuffer(capacity: 180)
    private var gpuRenderCircularBuffer = CircularBuffer(capacity: 180)
    private var gpuTilerCircularBuffer = CircularBuffer(capacity: 180)
    private var gpuTemperatureCircularBuffer = CircularBuffer(capacity: 180)
    private var batteryCircularBuffer = CircularBuffer(capacity: 180)
    private var sensorsCircularBuffer = CircularBuffer(capacity: 180)
    private var bluetoothCircularBuffer = CircularBuffer(capacity: 180)

    // MARK: - CPU Data

    public private(set) var cpuData: CPUData = CPUData(totalUsage: 0, perCoreUsage: [])
    public private(set) var cpuHistory: [Double] = []

    // MARK: - Memory Data

    public private(set) var memoryData: MemoryData = MemoryData(
        usedBytes: 0, totalBytes: 0, pressure: .normal
    )
    public private(set) var memoryHistory: [Double] = []

    // MARK: - Disk Data

    public private(set) var diskVolumes: [DiskVolumeData] = []
    public private(set) var primaryDiskActivity: Bool = false
    public private(set) var diskHistory: [Double] = []
    public private(set) var diskReadHistory: [Double] = []   // Read rate history (bytes/sec)
    public private(set) var diskWriteHistory: [Double] = []  // Write rate history (bytes/sec)

    // MARK: - Network Data

    public private(set) var networkData: NetworkData = NetworkData(
        uploadBytesPerSecond: 0, downloadBytesPerSecond: 0, isConnected: false
    )
    public private(set) var networkUploadHistory: [Double] = []
    public private(set) var networkDownloadHistory: [Double] = []

    /// Cumulative upload bytes since last reset (for Details section)
    public private(set) var totalUploadBytes: Int64 = 0

    /// Cumulative download bytes since last reset (for Details section)
    public private(set) var totalDownloadBytes: Int64 = 0

    /// Connectivity status history for grid visualization (bool array)
    public private(set) var connectivityHistory: [Bool] = []

    /// Per-app bandwidth while the network popover is open (nettop, direct build only)
    public private(set) var networkTopProcesses: [ProcessNetworkUsage]?
    private var networkTopProcessTask: Task<Void, Never>?

    // MARK: - GPU Data

    public private(set) var gpuData: GPUData = GPUData()
    public private(set) var gpuHistory: [Double] = []
    public private(set) var gpuRenderHistory: [Double] = []
    public private(set) var gpuTilerHistory: [Double] = []
    public private(set) var gpuTemperatureHistory: [Double] = []

    // MARK: - Battery Data

    public private(set) var batteryData: BatteryData = BatteryData(isPresent: false)
    public private(set) var batteryHistory: [Double] = []

    // MARK: - Sensors Data

    public private(set) var sensorsData: SensorsData = SensorsData()
    public private(set) var sensorsHistory: [Double] = []

    // MARK: - Bluetooth Data

    public private(set) var bluetoothData: BluetoothData = BluetoothData.empty
    /// Bluetooth connection count history for chart visualization
    public private(set) var bluetoothHistory: [Double] = []

    /// Weather data (optional, may be nil if location not available)
    public private(set) var weatherData: WeatherData?

    // MARK: - Monitoring State

    public private(set) var isMonitoring = false
    public private(set) var hasLiveMetricSample = false
    public private(set) var lastLiveSampleAt: Date?
    public private(set) var lastMonitoringStartAt: Date?

    // MARK: - Private Properties

    /// Background queue for heavy data fetching work to avoid blocking the main thread
    private let monitoringQueue = DispatchQueue(label: "com.tonic.widgetdata.monitoring", qos: .utility)

    /// Reader descriptors are immutable. Their state mutations are main-actor
    /// isolated; collectors can move behind actors without exposing races to SwiftUI.
    private struct MonitoringReader: Sendable {
        let id: String
        let module: WidgetType
        let intervalKey: String
        let defaultInterval: TimeInterval
        let popupOnly: Bool
        let action: @MainActor @Sendable (WidgetDataManager) -> Void
    }

    private var readerTimers: [String: DispatchSourceTimer] = [:]
    private let requiredLiveReaderIDs: Set<String> = ["CPU.load", "RAM.load", "Disk.load", "Net.load"]
    private var popupVisibleModules: Set<WidgetType> = []
    private var lastNetworkStats: (upload: UInt64, download: UInt64, timestamp: Date)?
    private var lastDiskReadBytes: UInt64 = 0
    private var lastDiskWriteBytes: UInt64 = 0

    // Enhanced disk tracking for IOPS and activity rates
    private var lastDiskStats: DiskIOStatsSnapshot?
    private let diskStatsLock = NSLock()

    // CPU tracking for delta calculation
    private var previousCPUSnapshot: CPUCounterSnapshot?
    private let cpuLock = NSLock()
    private var cachedCPUCoreConfig: (eCoreCount: Int, pCoreCount: Int)?
    private var lastCPUCoreConfigFetch: Date?
    private var cachedCPUFrequency: (Double?, Double?, Double?)?
    private var lastCPUFrequencyFetch: Date?
    private var cachedCPUTemperature: Double?
    private var lastCPUTemperatureFetch: Date?
    private var cachedThermalLimit: Bool?
    private var cachedCPUSpeedLimits: (schedulerLimit: Double?, speedLimit: Double?)?
    private var lastCPUThermalFetch: Date?
    private var cachedAverageLoad: [Double]?
    private var cachedUptime: TimeInterval = 0
    private var lastCPULoadFetch: Date?

    private var preferredModuleIntervals: [WidgetType: TimeInterval] = [:]

    private var lastBluetoothUpdate: Date?
    private let bluetoothUpdateInterval: TimeInterval = 10.0  // Bluetooth updates less frequently

    // Network enhancement caching
    private var cachedPublicIP: PublicIPInfo?
    private var lastPublicIPFetch: Date?
    private var lastConnectivityCheck: Date?
    private var previousPingLatencies: [Double] = []
    private let publicIPCacheInterval: TimeInterval = 300  // 5 minutes
    private let connectivityCheckInterval: TimeInterval = 30  // 30 seconds
    private var cachedConnectivity: ConnectivityInfo?
    private let connectivityQueue = DispatchQueue(label: "com.tonic.widgetdata.connectivity", qos: .utility)
    private var connectivityRefreshInFlight = false
    private var cachedDNSServers: [String] = []
    private var lastDNSFetch: Date?
    private let dnsCacheInterval: TimeInterval = 60  // 1 minute
    private var lastWiFiSecurityFetch: Date?
    private var cachedWiFiSecurity: String?
    private var cachedWiFiSecuritySSID: String?

    // Network reachability
    private var pathMonitor: NWPathMonitor?
    private let pathMonitorQueue = DispatchQueue(label: "com.tonic.network.pathmonitor", qos: .utility)
    private var networkReachable: Bool?

    // Battery transition tracking for "Last charge" parity behavior.
    private var batteryLastACPowerTimestamp: Date?
    private var wasOnACPower: Bool = false

    // MARK: - Initialization

    private init() {
        // Register for reset network usage notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleResetTotalNetworkUsage),
            name: .resetTotalNetworkUsage,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWidgetConfigurationDidUpdate),
            name: .widgetConfigurationDidUpdate,
            object: nil
        )
        startNetworkPathMonitor()
    }

    /// Handle reset total network usage notification
    @objc private func handleResetTotalNetworkUsage() {
        resetTotalNetworkUsage()
    }

    @objc private func handleWidgetConfigurationDidUpdate() {
        applyWidgetSamplingPreferences()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        // Cancel path monitor if it exists
        // Note: pathMonitor cleanup is handled by NWPathMonitor internally on dealloc
        // We don't need explicit cancellation here since the object is being destroyed
    }

    // MARK: - Public Methods

    /// Start monitoring system data
    public func startMonitoring() {
        if isMonitoring {
            logger.warning("Already monitoring, validating live reader health")
            logToFile("Already monitoring, validating live reader health")
            ensureLiveMonitoring(reason: "startMonitoring existing session")
            return
        }
        isMonitoring = true
        lastMonitoringStartAt = Date()
        applyWidgetSamplingPreferences(restartIfNeeded: false)
        logger.info("🔵 Starting parity reader monitoring")
        logToFile("🔵 STARTING PARITY READER MONITORING")
        restartReaderTimers()
        triggerImmediateReaderPass()
    }

    /// Stop monitoring system data
    public func stopMonitoring() {
        isMonitoring = false
        readerTimers.values.forEach { $0.cancel() }
        readerTimers.removeAll()
        popupVisibleModules.removeAll()
    }

    /// Ensure the live monitor has active required readers and recent samples.
    public func ensureLiveMonitoring(reason: String = "unspecified") {
        guard isMonitoring else {
            logger.info("Ensuring live monitoring by starting stopped monitor: \(reason)")
            logToFile("Ensuring live monitoring by starting stopped monitor: \(reason)")
            startMonitoring()
            return
        }

        applyWidgetSamplingPreferences(restartIfNeeded: false)

        let activeReaderIDs = Set(readerTimers.keys)
        let missingRequiredReaders = !requiredLiveReaderIDs.isSubset(of: activeReaderIDs)
        let staleSample = isLiveSampleStale()
        let hasNoSample = !hasLiveMetricSample

        guard missingRequiredReaders || staleSample || hasNoSample else { return }

        logger.warning("Repairing live monitoring, reason: \(reason), missingRequiredReaders: \(missingRequiredReaders), staleSample: \(staleSample), hasNoSample: \(hasNoSample)")
        logToFile("Repairing live monitoring: \(reason), missingRequiredReaders=\(missingRequiredReaders), staleSample=\(staleSample), hasNoSample=\(hasNoSample)")

        if missingRequiredReaders || staleSample {
            restartReaderTimers()
        }
        triggerImmediateReaderPass()
    }

    /// Update the monitoring interval based on preferences
    public func updateInterval() {
        if isMonitoring {
            restartReaderTimers()
        }
    }

    public func applyWidgetSamplingPreferences(restartIfNeeded: Bool = true) {
        var intervals: [WidgetType: TimeInterval] = [:]
        for type in WidgetType.allCases {
            if let interval = WidgetPreferences.shared.config(for: type)?.refreshInterval.timeInterval {
                intervals[type] = interval
            }
        }
        preferredModuleIntervals = intervals

        if restartIfNeeded, isMonitoring {
            restartReaderTimers()
        }
    }

    public func setModuleUpdateInterval(for widgetType: WidgetType, interval: TimeInterval) {
        guard interval >= 0.5 else { return }
        UserDefaults.standard.set(interval, forKey: moduleIntervalKey(for: widgetType))
        if isMonitoring {
            restartReaderTimers()
        }
    }

    public func setPopupVisible(for widgetType: WidgetType, isVisible: Bool) {
        if isVisible {
            popupVisibleModules.insert(widgetType)
        } else {
            popupVisibleModules.remove(widgetType)
        }

        // Per-app bandwidth (nettop) runs on its own cadence, only while the
        // network popover is open.
        if widgetType == .network {
            if isVisible {
                startNetworkTopProcessSampling()
            } else {
                stopNetworkTopProcessSampling()
            }
        }

        // Weather has no reader timer; refresh on open so the console isn't stale.
        if widgetType == .weather, isVisible {
            WeatherService.shared.updateWeather()
        }

        guard isVisible, isMonitoring else { return }
        for reader in monitoringReaders where reader.popupOnly && reader.module == widgetType {
            reader.action(self)
        }
    }

    // MARK: - Per-App Network Sampling (popup only)

    private func startNetworkTopProcessSampling() {
        #if !TONIC_STORE
        guard networkTopProcessTask == nil, NetworkPerProcessSampler.shared.isAvailable else { return }
        networkTopProcessTask = Task { [weak self] in
            while !Task.isCancelled {
                // First nettop pass establishes the baseline (zero rates);
                // real rates arrive from the second pass onward.
                let bandwidth = await NetworkPerProcessSampler.shared.sample(limit: 5)
                let usage = bandwidth
                    .filter { $0.bytesInPerSecond + $0.bytesOutPerSecond > 0 }
                    .map {
                        ProcessNetworkUsage(pid: Int($0.pid), name: $0.name,
                                            uploadBytes: UInt64($0.bytesOutPerSecond),
                                            downloadBytes: UInt64($0.bytesInPerSecond))
                    }
                await MainActor.run { [weak self] in
                    self?.networkTopProcesses = usage.isEmpty ? nil : usage
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
        #endif
    }

    private func stopNetworkTopProcessSampling() {
        networkTopProcessTask?.cancel()
        networkTopProcessTask = nil
        networkTopProcesses = nil
    }

    // MARK: - Reader Scheduling

    private var monitoringReaders: [MonitoringReader] {
        [
            MonitoringReader(id: "CPU.load", module: .cpu, intervalKey: "CPU_updateInterval", defaultInterval: 1.0, popupOnly: false) { $0.updateCPUData() },
            MonitoringReader(id: "RAM.load", module: .memory, intervalKey: "RAM_updateInterval", defaultInterval: 1.0, popupOnly: false) { $0.updateMemoryData() },
            MonitoringReader(id: "Disk.load", module: .disk, intervalKey: "Disk_updateInterval", defaultInterval: 1.0, popupOnly: false) { $0.updateDiskData() },
            MonitoringReader(id: "Net.load", module: .network, intervalKey: "Net_updateInterval", defaultInterval: 1.0, popupOnly: false) { $0.updateNetworkData() },
            MonitoringReader(id: "GPU.load", module: .gpu, intervalKey: "GPU_updateInterval", defaultInterval: 1.0, popupOnly: true) { $0.updateGPUData() },
            MonitoringReader(id: "Battery.load", module: .battery, intervalKey: "Battery_updateInterval", defaultInterval: 2.0, popupOnly: true) { $0.updateBatteryData() },
            MonitoringReader(id: "Sensors.load", module: .sensors, intervalKey: "Sensors_updateInterval", defaultInterval: 2.0, popupOnly: true) { $0.updateSensorsData() },
            MonitoringReader(id: "Bluetooth.load", module: .bluetooth, intervalKey: "Bluetooth_updateInterval", defaultInterval: bluetoothUpdateInterval, popupOnly: true) { $0.updateBluetoothData() }
        ]
    }

    private func restartReaderTimers() {
        readerTimers.values.forEach { $0.cancel() }
        readerTimers.removeAll()

        for reader in monitoringReaders {
            let interval = moduleInterval(reader: reader)
            // Reader actions mutate observable state and are main-actor isolated.
            // Scheduling on the main queue preserves that contract; heavy collectors
            // should do their own actor-isolated work before publishing a sample.
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(
                deadline: .now() + .milliseconds(100),
                repeating: dispatchInterval(seconds: interval),
                leeway: .milliseconds(100)
            )
            timer.setEventHandler { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if reader.popupOnly && !self.popupVisibleModules.contains(reader.module) {
                        return
                    }
                    reader.action(self)
                }
            }
            timer.resume()
            readerTimers[reader.id] = timer
        }
    }

    private func triggerImmediateReaderPass() {
        for reader in monitoringReaders where !reader.popupOnly {
            reader.action(self)
        }
    }

    private func moduleInterval(reader: MonitoringReader) -> TimeInterval {
        if let preferred = preferredModuleIntervals[reader.module], preferred >= 0.5 {
            return preferred
        }

        let stored = UserDefaults.standard.double(forKey: reader.intervalKey)
        if stored >= 0.5 {
            return stored
        }
        return reader.defaultInterval
    }

    private func moduleIntervalKey(for widgetType: WidgetType) -> String {
        switch widgetType {
        case .cpu: return "CPU_updateInterval"
        case .memory: return "RAM_updateInterval"
        case .disk: return "Disk_updateInterval"
        case .network: return "Net_updateInterval"
        case .gpu: return "GPU_updateInterval"
        case .battery: return "Battery_updateInterval"
        case .sensors: return "Sensors_updateInterval"
        case .bluetooth: return "Bluetooth_updateInterval"
        case .clock: return "Clock_updateInterval"
        case .weather: return "Weather_updateInterval"
        case .tonic: return "Tonic_updateInterval"
        }
    }

    private func dispatchInterval(seconds: TimeInterval) -> DispatchTimeInterval {
        .milliseconds(max(250, Int(seconds * 1000)))
    }

    private func isLiveSampleStale(now: Date = Date()) -> Bool {
        let threshold = maxRequiredLiveReaderInterval() * 2
        if let lastLiveSampleAt {
            return now.timeIntervalSince(lastLiveSampleAt) > threshold
        }
        if let lastMonitoringStartAt {
            return now.timeIntervalSince(lastMonitoringStartAt) > threshold
        }
        return true
    }

    private func maxRequiredLiveReaderInterval() -> TimeInterval {
        let requiredReaders = monitoringReaders.filter { requiredLiveReaderIDs.contains($0.id) }
        let maxInterval = requiredReaders
            .map { moduleInterval(reader: $0) }
            .max() ?? 1.0
        return max(1.0, maxInterval)
    }

    private func markLiveMetricSampleReceived(at date: Date = Date()) {
        hasLiveMetricSample = true
        lastLiveSampleAt = date
    }

    // MARK: - CPU Monitoring

    private func updateCPUData() {
        let usageSnapshot = getCPUUsageSnapshot()
        let perCore = usageSnapshot.perCoreUsage

        // Get E/P core usage distribution (Apple Silicon only)
        let (eCores, pCores) = getEPCores(from: perCore)

        let (frequency, eCoreFreq, pCoreFreq) = getCachedCPUFrequency()
        let temperature = getCachedCPUTemperature()
        let thermalLimit = cachedThermalLimit
        let averageLoad = getCachedAverageLoad()
        let uptime = getCachedSystemUptime()
        let (schedulerLimit, speedLimit) = cachedCPUSpeedLimits ?? (nil, nil)

        // Per-process CPU is popup/detail data; skip the libproc pass otherwise.
        let topProcesses: [ProcessUsage]? = popupVisibleModules.contains(.cpu)
            ? ProcessSampler.shared.topByCPU(limit: 3)
            : nil

        let newCPUData = CPUData(
            totalUsage: usageSnapshot.totalUsage,
            perCoreUsage: perCore,
            eCoreUsage: eCores,
            pCoreUsage: pCores,
            frequency: frequency,
            eCoreFrequency: eCoreFreq,
            pCoreFrequency: pCoreFreq,
            temperature: temperature,
            thermalLimit: thermalLimit,
            averageLoad: averageLoad,
            systemUsage: usageSnapshot.systemUsage,
            userUsage: usageSnapshot.userUsage,
            idleUsage: usageSnapshot.idleUsage,
            uptime: uptime,
            schedulerLimit: schedulerLimit,
            speedLimit: speedLimit,
            topProcesses: topProcesses
        )

        // Dispatch property updates to main thread for @Observable
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.cpuData = newCPUData
            // Performance optimization: Use circular buffer for O(1) history add
            self.cpuCircularBuffer.add(usageSnapshot.totalUsage)
            self.cpuHistory = self.cpuCircularBuffer.toArray()
            self.markLiveMetricSampleReceived()
            self.recordResourceHistorySample()

            // Check notification thresholds
            NotificationManager.shared.checkThreshold(widgetType: .cpu, value: usageSnapshot.totalUsage)
        }

        if isDebugLoggingEnabled {
            logger.debug("🔵 CPU updated: \(Int(usageSnapshot.totalUsage))% (\(perCore.count) cores)")
            logToFile("🔵 CPU updated: \(Int(usageSnapshot.totalUsage))% (\(perCore.count) cores), perCore: \(perCore.prefix(3))")
        }
    }

    private func getCPUUsageSnapshot() -> CPUUsageSnapshot {
        guard let current = readCPUCounterSnapshot() else {
            return .zero(coreCount: previousCPUSnapshot?.cores.count ?? 0)
        }

        cpuLock.lock()
        defer { cpuLock.unlock() }

        let usage = ResourceMetricCalculators.cpuUsage(previous: previousCPUSnapshot, current: current)
        previousCPUSnapshot = current
        return usage
    }

    private func readCPUCounterSnapshot() -> CPUCounterSnapshot? {
        var numCpuInfo: mach_msg_type_number_t = 0
        var cpuInfo: processor_info_array_t?
        var numTotalCpu: UInt32 = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numTotalCpu,
            &cpuInfo,
            &numCpuInfo
        )

        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return nil
        }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: info)),
                vm_size_t(Int(numCpuInfo) * MemoryLayout<integer_t>.size)
            )
        }

        let cpuStateCount = 4
        var cores: [CPUCounterSnapshot.Core] = []
        cores.reserveCapacity(Int(numTotalCpu))
        for i in 0..<Int(numTotalCpu) {
            let base = i * cpuStateCount
            cores.append(CPUCounterSnapshot.Core(
                user: UInt64(info[base + Int(CPU_STATE_USER)]),
                system: UInt64(info[base + Int(CPU_STATE_SYSTEM)]),
                idle: UInt64(info[base + Int(CPU_STATE_IDLE)]),
                nice: UInt64(info[base + Int(CPU_STATE_NICE)])
            ))
        }

        return CPUCounterSnapshot(cores: cores)
    }

    // MARK: - Enhanced CPU Readers

    /// Get CPU core configuration (E/P cores for Apple Silicon)
    private func getCPUCoreConfig() -> (eCoreCount: Int, pCoreCount: Int)? {
        #if arch(arm64)
        // Apple Silicon - read E/P core counts from sysctl
        var eCoreCount: Int = 0
        var pCoreCount: Int = 0
        var size: Int = MemoryLayout<Int>.size

        // Get efficiency core count (perflevel0 = E cores)
        if sysctlbyname("hw.perflevel0.physicalcpu", &eCoreCount, &size, nil, 0) != 0 {
            // Fallback: try alternative sysctl
            eCoreCount = 0
        }

        // Get performance core count (perflevel1 = P cores)
        if sysctlbyname("hw.perflevel1.physicalcpu", &pCoreCount, &size, nil, 0) != 0 {
            // Fallback: try alternative sysctl
            pCoreCount = 0
        }

        // If we couldn't get perflevel data, try legacy approach
        if eCoreCount == 0 && pCoreCount == 0 {
            var totalCores: Int = 0
            sysctlbyname("hw.physicalcpu", &totalCores, &size, nil, 0)

            // Default to assuming half are E cores for modern Apple Silicon
            if totalCores > 0 {
                eCoreCount = totalCores / 2
                pCoreCount = totalCores - eCoreCount
            }
        }

        if eCoreCount > 0 || pCoreCount > 0 {
            return (eCoreCount, pCoreCount)
        }
        #endif
        return nil
    }

    /// Split per-core usage into E and P core arrays
    private func getEPCores(from perCoreUsage: [Double]) -> (eCores: [Double]?, pCores: [Double]?) {
        #if arch(arm64)
        guard let config = getCachedCPUCoreConfig() else {
            return (nil, nil)
        }

        let totalCores = perCoreUsage.count
        guard totalCores >= config.eCoreCount + config.pCoreCount else {
            return (nil, nil)
        }

        // On Apple Silicon, E cores typically come first in the core list
        let eCores = Array(perCoreUsage.prefix(config.eCoreCount))
        let pCores = Array(perCoreUsage.suffix(config.pCoreCount))

        return (eCores.isEmpty ? nil : eCores, pCores.isEmpty ? nil : pCores)
        #else
        return (nil, nil)
        #endif
    }

    private func getCachedCPUCoreConfig() -> (eCoreCount: Int, pCoreCount: Int)? {
        if let lastFetch = lastCPUCoreConfigFetch,
           Date().timeIntervalSince(lastFetch) < 30 {
            return cachedCPUCoreConfig
        }

        cachedCPUCoreConfig = getCPUCoreConfig()
        lastCPUCoreConfigFetch = Date()
        return cachedCPUCoreConfig
    }

    private func getCachedCPUFrequency() -> (Double?, Double?, Double?) {
        if let lastFetch = lastCPUFrequencyFetch,
           Date().timeIntervalSince(lastFetch) < 30,
           let cached = cachedCPUFrequency {
            return cached
        }

        let value = getCPUFrequency()
        cachedCPUFrequency = value
        lastCPUFrequencyFetch = Date()
        return value
    }

    private func getCachedCPUTemperature() -> Double? {
        if let lastFetch = lastCPUTemperatureFetch,
           Date().timeIntervalSince(lastFetch) < 2 {
            return cachedCPUTemperature
        }

        cachedCPUTemperature = getThermalStateTemperature()
        lastCPUTemperatureFetch = Date()
        return cachedCPUTemperature
    }

    private func getCachedThermalLimit() -> Bool? {
        refreshCPUThermalCacheIfNeeded()
        return cachedThermalLimit
    }

    private func getCachedCPUSpeedLimits() -> (schedulerLimit: Double?, speedLimit: Double?) {
        refreshCPUThermalCacheIfNeeded()
        return cachedCPUSpeedLimits ?? (nil, nil)
    }

    private func refreshCPUThermalCacheIfNeeded() {
        if let lastFetch = lastCPUThermalFetch,
           Date().timeIntervalSince(lastFetch) < 10 {
            return
        }

        cachedThermalLimit = getThermalLimit()
        cachedCPUSpeedLimits = getCPUSpeedLimits()
        lastCPUThermalFetch = Date()
    }

    private func getCachedAverageLoad() -> [Double]? {
        refreshCPULoadCacheIfNeeded()
        return cachedAverageLoad
    }

    private func getCachedSystemUptime() -> TimeInterval {
        refreshCPULoadCacheIfNeeded()
        return cachedUptime
    }

    private func refreshCPULoadCacheIfNeeded() {
        if let lastFetch = lastCPULoadFetch,
           Date().timeIntervalSince(lastFetch) < 5 {
            return
        }

        cachedAverageLoad = getAverageLoad()
        cachedUptime = getSystemUptime()
        lastCPULoadFetch = Date()
    }

    /// Get current CPU frequency in GHz
    /// Returns tuple: (overall frequency, E-core frequency, P-core frequency)
    private func getCPUFrequency() -> (Double?, Double?, Double?) {
        #if arch(arm64)
        // For Apple Silicon, get base frequency from sysctl
        var frequency: Int64 = 0
        var size = MemoryLayout<Int64>.size

        // Get overall CPU frequency
        var overallFreq: Double? = nil
        if sysctlbyname("hw.cpufrequency", &frequency, &size, nil, 0) == 0 {
            overallFreq = Double(frequency) / 1_000_000_000 // Convert Hz to GHz
        }

        // Get E-core frequency (perflevel0 = efficiency)
        var eFreq: Int64 = 0
        var eCoreFreq: Double? = nil
        if sysctlbyname("hw.perflevel0.cpufrequency", &eFreq, &size, nil, 0) == 0 {
            eCoreFreq = Double(eFreq) / 1_000_000_000 // Convert Hz to GHz
        }

        // Get P-core frequency (perflevel1 = performance)
        var pFreq: Int64 = 0
        var pCoreFreq: Double? = nil
        if sysctlbyname("hw.perflevel1.cpufrequency", &pFreq, &size, nil, 0) == 0 {
            pCoreFreq = Double(pFreq) / 1_000_000_000 // Convert Hz to GHz
        }

        // If overall frequency is nil but we have P-core frequency, use P-core as overall
        let finalOverall = overallFreq ?? pCoreFreq

        return (finalOverall, eCoreFreq, pCoreFreq)
        #else
        // Intel Macs - get CPU frequency
        var frequency: Int64 = 0
        var size = MemoryLayout<Int64>.size

        if sysctlbyname("hw.cpufrequency", &frequency, &size, nil, 0) == 0 {
            return (Double(frequency) / 1_000_000_000, nil, nil)
        }

        return (nil, nil, nil)
        #endif
    }

    /// Get CPU temperature in Celsius
    private func getCPUTemperature() -> Double? {
        // Try SMC temperature reading first (most accurate)
        if SMCReader.shared.isAvailable {
            if let smcTemp = SMCReader.shared.getValue("TC0P"), smcTemp > 0, smcTemp < 120 {
                return smcTemp
            }
            if let smcTemp = SMCReader.shared.getValue("TC0D"), smcTemp > 0, smcTemp < 120 {
                return smcTemp
            }
        }

        #if arch(arm64)
        // Apple Silicon temperature reading via IOKit
        var iterator: io_iterator_t = 0

        // Try to access thermal sensors via IORegistry
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOThermalSensor"), &iterator)

        guard result == KERN_SUCCESS else {
            // Fallback: use ProcessInfo thermal state
            return getThermalStateTemperature()
        }

        defer { IOObjectRelease(iterator) }

        var temperatures: [Double] = []

        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }

            if let props = IORegistryEntryCreateCFProperty(service, "Temperature" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Double {
                temperatures.append(props)
            }

            IOObjectRelease(service)
        }

        if !temperatures.isEmpty {
            return temperatures.reduce(0, +) / Double(temperatures.count)
        }

        return getThermalStateTemperature()
        #else
        // Intel Macs - try SMC via IOKit (limited access)
        // Return nil for Intel as we don't have direct SMC access
        return getThermalStateTemperature()
        #endif
    }

    /// Estimate temperature based on ProcessInfo thermal state
    private func getThermalStateTemperature() -> Double? {
        let thermalState = ProcessInfo.processInfo.thermalState

        switch thermalState {
        case .nominal:
            return 45.0 // Typical idle temperature
        case .fair:
            return 60.0
        case .serious:
            return 75.0
        case .critical:
            return 90.0
        @unknown default:
            return nil
        }
    }

    /// Check if CPU is being thermally throttled
    private func getThermalLimit() -> Bool {
        // Check using ProcessInfo thermal state
        let thermalState = ProcessInfo.processInfo.thermalState

        let isThrottled = thermalState == .serious || thermalState == .critical

        if isThrottled {
            return true
        }

        // Also check pmset for additional thermal info
        let task = Process()
        task.launchPath = "/usr/bin/pmset"
        task.arguments = ["-g", "therm"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return false }

            // Check if any CPU limits are active
            let lines = output.split(separator: "\n")
            for line in lines where line.contains("CPU") || line.contains("Scheduler") {
                if let value = Int(line.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()),
                   value > 0 {
                    return true
                }
            }
        } catch {
            // If pmset fails, rely on ProcessInfo
        }

        return false
    }

    /// Get CPU speed limits from pmset thermal data
    /// Returns (schedulerLimit, speedLimit) as percentages (0-100)
    private func getCPUSpeedLimits() -> (schedulerLimit: Double?, speedLimit: Double?) {
        let task = Process()
        task.launchPath = "/usr/bin/pmset"
        task.arguments = ["-g", "therm"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return (nil, nil) }

            var speedLimit: Double?
            var schedulerLimit: Double?

            let lines = output.split(separator: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.contains("CPU_Speed_Limit") {
                    // Parse "CPU_Speed_Limit = 100" format
                    let parts = trimmed.components(separatedBy: "=")
                    if parts.count == 2, let value = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                        speedLimit = Double(value)
                    }
                } else if trimmed.contains("CPU_Scheduler_Limit") {
                    let parts = trimmed.components(separatedBy: "=")
                    if parts.count == 2, let value = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                        schedulerLimit = Double(value)
                    }
                }
            }

            return (schedulerLimit, speedLimit)
        } catch {
            return (nil, nil)
        }
    }

    /// Get average load (1, 5, 15 minute averages)
    private func getAverageLoad() -> [Double]? {
        var loads = [Double](repeating: 0, count: 3)
        let count = getloadavg(&loads, Int32(loads.count))
        guard count == Int32(loads.count) else { return nil }
        return loads
    }

    /// Get system uptime in seconds (time since boot)
    private func getSystemUptime() -> TimeInterval {
        var bootTime = timeval()
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]

        var len = MemoryLayout<timeval>.stride
        let result = sysctl(&mib, u_int(mib.count), &bootTime, &len, nil, 0)

        guard result == 0 else {
            // Fallback to ProcessInfo.uptime if sysctl fails
            return ProcessInfo.processInfo.systemUptime
        }

        var now = timeval()
        var nowLen = MemoryLayout<timeval>.stride
        gettimeofday(&now, &nowLen)

        let bootTimeInterval = TimeInterval(bootTime.tv_sec) + TimeInterval(bootTime.tv_usec) / 1_000_000.0
        let nowTimeInterval = TimeInterval(now.tv_sec) + TimeInterval(now.tv_usec) / 1_000_000.0

        return max(0, nowTimeInterval - bootTimeInterval)
    }

    // MARK: - Memory Monitoring

    private func updateMemoryData() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            let emptyData = MemoryData(usedBytes: 0, totalBytes: 0, pressure: .normal)
            DispatchQueue.main.async { [weak self] in
                self?.memoryData = emptyData
            }
            return
        }

        var kernelPageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &kernelPageSize)
        let pageSize = UInt64(kernelPageSize)

        // Calculate memory usage
        let used = (UInt64(stats.active_count) + UInt64(stats.wire_count)) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize

        // Get physical memory
        var memSize: Int = 0
        var memSizeLen = MemoryLayout<Int>.size
        sysctlbyname("hw.memsize", &memSize, &memSizeLen, nil, 0)

        // Get enhanced swap usage
        let (swapTotal, swapUsed) = getSwapUsage()

        // Calculate free memory
        let free = UInt64(stats.free_count) * pageSize
        let total = UInt64(stats.wire_count + stats.active_count + stats.inactive_count + stats.free_count) * pageSize
        let freePercentage = total > 0 ? Double(free) / Double(total) : 0

        // Get actual kernel memory pressure level via kern.memorystatus_vm_pressure_level
        // Stats Master pattern: returns 0-4 where 0/1=normal, 2=warning, 4=critical
        let (pressure, pressureLevel) = getKernelMemoryPressure()

        // Calculate pressure value on 0-100 scale using kernel level
        let pressureValue = getMemoryPressureValue(level: pressureLevel, freePercentage: freePercentage)

        // Real top-memory processes via libproc (~ms per pass). Previously
        // hardcoded nil, which left every popover's process list empty.
        let topProcesses: [AppResourceUsage]? = ProcessSampler.shared.topByMemory(limit: 5)

        let swapBytes = swapUsed ?? 0

        let newMemoryData = MemoryData(
            usedBytes: used,
            totalBytes: UInt64(memSize),
            pressure: pressure,
            compressedBytes: compressed,
            swapBytes: swapBytes,
            freeBytes: free,
            swapTotalBytes: swapTotal,
            swapUsedBytes: swapUsed,
            pressureValue: pressureValue,
            topProcesses: topProcesses
        )

        // Dispatch property updates to main thread for @Observable
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.memoryData = newMemoryData
            // Performance optimization: Use circular buffer for O(1) history add
            self.memoryCircularBuffer.add(newMemoryData.usagePercentage)
            self.memoryHistory = self.memoryCircularBuffer.toArray()
            self.markLiveMetricSampleReceived()
            self.recordResourceHistorySample()

            // Check notification thresholds
            NotificationManager.shared.checkThreshold(widgetType: .memory, value: newMemoryData.usagePercentage)
        }
    }

    // MARK: - Enhanced Memory Readers

    /// Get detailed swap usage information
    /// Returns (totalBytes, usedBytes)
    private func getSwapUsage() -> (total: UInt64?, used: UInt64?) {
        var xswUsage = xsw_usage(xsu_total: 0, xsu_used: 0, xsu_pagesize: 0, xsu_encrypted: 0)
        var xswSize = MemoryLayout<xsw_usage>.stride

        guard sysctlbyname("vm.swapusage", &xswUsage, &xswSize, nil, 0) == 0 else {
            return (nil, nil)
        }

        // xsw_usage structure provides:
        // - xsu_total: total swap space in bytes
        // - xsu_used: used swap space in bytes
        // - xsu_pagesize: page size (for reference)
        return (UInt64(xswUsage.xsu_total), UInt64(xswUsage.xsu_used))
    }

    /// Get actual kernel memory pressure level via kern.memorystatus_vm_pressure_level
    /// Stats Master pattern: returns 0-4 where 0/1=normal, 2=warning, 4=critical
    private func getKernelMemoryPressure() -> (pressure: MemoryPressure, level: Int) {
        var pressureLevel: Int = 0
        var intSize: size_t = MemoryLayout<Int>.size

        let result = sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureLevel, &intSize, nil, 0)

        guard result == 0 else {
            // Fallback to normal if sysctl fails
            return (.normal, 0)
        }

        // Map kernel pressure level to MemoryPressure enum
        // Stats Master: 2 = warning, 4 = critical, default = normal
        let pressure: MemoryPressure
        switch pressureLevel {
        case 2:
            pressure = .warning
        case 4:
            pressure = .critical
        default:
            pressure = .normal
        }

        return (pressure, pressureLevel)
    }

    /// Map memory pressure to a 0-100 scale using kernel level
    /// - 0-33: Normal (low pressure)
    /// - 34-66: Warning (moderate pressure)
    /// - 67-100: Critical (high pressure)
    private func getMemoryPressureValue(level: Int, freePercentage: Double) -> Double {
        switch level {
        case 0, 1:
            // Normal: 0-33, inversely proportional to free memory
            // More free memory = lower pressure value
            let normalizedFree = min(1.0, max(0.0, freePercentage))
            return (1.0 - normalizedFree) * 33.0
        case 2:
            // Warning: 34-66
            // Use free percentage to position within warning range
            let normalizedFree = min(0.15, max(0.0, freePercentage))
            return 34.0 + (1.0 - normalizedFree / 0.15) * 32.0
        case 4:
            // Critical: 67-100
            // Use free percentage to position within critical range
            let normalizedFree = min(0.05, max(0.0, freePercentage))
            return 67.0 + (1.0 - normalizedFree / 0.05) * 33.0
        default:
            // Unknown level, treat as normal
            return (1.0 - min(1.0, freePercentage)) * 33.0
        }
    }

    // MARK: - Disk Monitoring

    private func updateDiskData() {
        var volumes: [DiskVolumeData] = []
        let now = Date()

        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeIsRootFileSystemKey,
            .volumeIsInternalKey
        ]

        // Get enhanced disk stats (IOPS, activity rates)
        let (readIOPS, writeIOPS, readBps, writeBps, readTime, writeTime) = getDiskIORates()

        // Keep live disk sampling cheap; SMART stays popup/detail data.
        let bootVolumeSMART: NVMeSMARTData? = nil
        // Per-process disk I/O only while the disk popover is open.
        let topDiskProcesses: [ProcessUsage]? = popupVisibleModules.contains(.disk)
            ? ProcessSampler.shared.topByDiskIO(limit: 3)
            : nil

        if let volumesURLs = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys) {
            for url in volumesURLs {
                guard let resourceValues = try? url.resourceValues(forKeys: Set(keys)),
                      let name = resourceValues.volumeName,
                      let total = resourceValues.volumeTotalCapacity,
                      let available = resourceValues.volumeAvailableCapacity else {
                    continue
                }

                let used = total - available
                let isBoot = resourceValues.volumeIsRootFileSystem ?? false
                let isInternal = resourceValues.volumeIsInternal ?? true

                // Only include SMART data for boot/internal volumes
                let smartData = isBoot ? bootVolumeSMART : nil

                volumes.append(DiskVolumeData(
                    name: name,
                    path: url.path,
                    usedBytes: UInt64(used),
                    totalBytes: UInt64(total),
                    isBootVolume: isBoot,
                    isInternal: isInternal,
                    isActive: false,
                    smartData: smartData,
                    readIOPS: isBoot ? readIOPS : nil,
                    writeIOPS: isBoot ? writeIOPS : nil,
                    readBytesPerSecond: isBoot ? readBps : nil,
                    writeBytesPerSecond: isBoot ? writeBps : nil,
                    readTime: isBoot ? readTime : nil,
                    writeTime: isBoot ? writeTime : nil,
                    topProcesses: isBoot ? topDiskProcesses : nil,
                    timestamp: now
                ))
            }
        }

        // Sort: boot volume first, then by used bytes
        volumes.sort { $0.isBootVolume && !$1.isBootVolume || ($0.isBootVolume == $1.isBootVolume && $0.usedBytes > $1.usedBytes) }

        // Get disk I/O statistics using IOKit (for activity detection)
        let (readBytes, writeBytes) = getDiskIOStatistics()
        let isActive = (readBytes != lastDiskReadBytes || writeBytes != lastDiskWriteBytes)
        lastDiskReadBytes = readBytes
        lastDiskWriteBytes = writeBytes

        // Dispatch property updates to main thread for @Observable
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.diskVolumes = volumes
            self.primaryDiskActivity = isActive

            // Check notification thresholds for primary volume
            if let primaryVolume = volumes.first {
                // Performance optimization: Use circular buffer for O(1) history add
                self.diskCircularBuffer.add(primaryVolume.usagePercentage)
                self.diskHistory = self.diskCircularBuffer.toArray()

                // Track read/write rate history in bytes/sec; formatting belongs at the UI boundary.
                self.diskReadCircularBuffer.add(primaryVolume.readBytesPerSecond ?? 0)
                self.diskWriteCircularBuffer.add(primaryVolume.writeBytesPerSecond ?? 0)
                self.diskReadHistory = self.diskReadCircularBuffer.toArray()
                self.diskWriteHistory = self.diskWriteCircularBuffer.toArray()
                self.markLiveMetricSampleReceived()
                self.recordResourceHistorySample()

                NotificationManager.shared.checkThreshold(widgetType: .disk, value: primaryVolume.usagePercentage)
            }
        }
    }

    // MARK: - Enhanced Disk Readers

    /// Snapshot of disk I/O statistics for delta calculation
    private struct DiskIOStatsSnapshot {
        let readBytes: UInt64
        let writeBytes: UInt64
        let readOperations: UInt64
        let writeOperations: UInt64
        let readTime: UInt64        // Total read time in nanoseconds
        let writeTime: UInt64       // Total write time in nanoseconds
        let timestamp: Date
    }

    /// Get disk I/O rates (IOPS and throughput) using delta calculation
    /// Returns: (readIOPS, writeIOPS, readBytesPerSecond, writeBytesPerSecond, readTimeMs, writeTimeMs)
    private func getDiskIORates() -> (Double?, Double?, Double?, Double?, TimeInterval?, TimeInterval?) {
        let currentStats = getDetailedDiskIOStats()
        let now = Date()

        diskStatsLock.lock()
        defer { diskStatsLock.unlock() }

        guard let previous = lastDiskStats else {
            lastDiskStats = DiskIOStatsSnapshot(
                readBytes: currentStats.readBytes,
                writeBytes: currentStats.writeBytes,
                readOperations: currentStats.readOperations,
                writeOperations: currentStats.writeOperations,
                readTime: currentStats.readTime,
                writeTime: currentStats.writeTime,
                timestamp: now
            )
            return (nil, nil, nil, nil, nil, nil)
        }

        let timeDelta = now.timeIntervalSince(previous.timestamp)
        guard timeDelta > 0 else {
            return (nil, nil, nil, nil, nil, nil)
        }

        // Guard against unsigned underflow when counters wrap or reset
        // If current < previous, it means the counter wrapped or a different device was observed
        guard currentStats.readBytes >= previous.readBytes,
              currentStats.writeBytes >= previous.writeBytes,
              currentStats.readOperations >= previous.readOperations,
              currentStats.writeOperations >= previous.writeOperations,
              currentStats.readTime >= previous.readTime,
              currentStats.writeTime >= previous.writeTime else {
            // Counter wrapped or changed - reset snapshot and return nil for this interval
            lastDiskStats = DiskIOStatsSnapshot(
                readBytes: currentStats.readBytes,
                writeBytes: currentStats.writeBytes,
                readOperations: currentStats.readOperations,
                writeOperations: currentStats.writeOperations,
                readTime: currentStats.readTime,
                writeTime: currentStats.writeTime,
                timestamp: now
            )
            return (nil, nil, nil, nil, nil, nil)
        }

        let readBytesDelta = currentStats.readBytes - previous.readBytes
        let writeBytesDelta = currentStats.writeBytes - previous.writeBytes
        let readOpsDelta = currentStats.readOperations - previous.readOperations
        let writeOpsDelta = currentStats.writeOperations - previous.writeOperations
        let readTimeDelta = currentStats.readTime - previous.readTime
        let writeTimeDelta = currentStats.writeTime - previous.writeTime

        let readIOPS = Double(readOpsDelta) / timeDelta
        let writeIOPS = Double(writeOpsDelta) / timeDelta
        let readBps = Double(readBytesDelta) / timeDelta
        let writeBps = Double(writeBytesDelta) / timeDelta

        // Convert nanoseconds to milliseconds for timing stats
        let readTimeMs = readTimeDelta > 0 ? TimeInterval(readTimeDelta) / 1_000_000 : nil
        let writeTimeMs = writeTimeDelta > 0 ? TimeInterval(writeTimeDelta) / 1_000_000 : nil

        // Update snapshot for next iteration
        lastDiskStats = DiskIOStatsSnapshot(
            readBytes: currentStats.readBytes,
            writeBytes: currentStats.writeBytes,
            readOperations: currentStats.readOperations,
            writeOperations: currentStats.writeOperations,
            readTime: currentStats.readTime,
            writeTime: currentStats.writeTime,
            timestamp: now
        )

        return (readIOPS, writeIOPS, readBps, writeBps, readTimeMs, writeTimeMs)
    }

    /// Detailed disk I/O statistics including operation counts and timing
    private struct DetailedDiskStats {
        let readBytes: UInt64
        let writeBytes: UInt64
        let readOperations: UInt64
        let writeOperations: UInt64
        let readTime: UInt64      // Total read time in nanoseconds
        let writeTime: UInt64     // Total write time in nanoseconds
    }

    /// Get detailed disk I/O statistics from IORegistry
    private func getDetailedDiskIOStats() -> DetailedDiskStats {
        var totalReadBytes: UInt64 = 0
        var totalWriteBytes: UInt64 = 0
        var totalReadOps: UInt64 = 0
        var totalWriteOps: UInt64 = 0
        var totalReadTime: UInt64 = 0  // Total read time in nanoseconds
        var totalWriteTime: UInt64 = 0 // Total write time in nanoseconds

        // Match IOKit services for block storage drivers
        let matchingDict = IOServiceMatching(kIOBlockStorageDriverClass)
        var serviceIterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &serviceIterator)
        guard result == KERN_SUCCESS else {
            return DetailedDiskStats(
                readBytes: 0, writeBytes: 0, readOperations: 0, writeOperations: 0,
                readTime: 0, writeTime: 0
            )
        }

        defer { IOObjectRelease(serviceIterator) }

        while true {
            let nextService = IOIteratorNext(serviceIterator)
            guard nextService != 0 else { break }
            defer { IOObjectRelease(nextService) }

            // Get statistics properties from the driver
            guard let properties = IORegistryEntryCreateCFProperty(nextService, kIOPropertyPlaneKey as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] else {
                continue
            }

            // Extract statistics
            if let stats = properties[kIOBlockStorageDriverStatisticsKey] as? [String: Any] {
                if let readBytes = stats[kIOBlockStorageDriverStatisticsBytesReadKey] as? UInt64 {
                    totalReadBytes += readBytes
                }
                if let writeBytes = stats[kIOBlockStorageDriverStatisticsBytesWrittenKey] as? UInt64 {
                    totalWriteBytes += writeBytes
                }
                // Try to get operation counts (may not be available on all macOS versions)
                if let readOps = stats["Operations (Read)"] as? UInt64 {
                    totalReadOps += readOps
                } else if let readOps = stats["kIOBlockStorageDriverStatisticsReadsKey"] as? UInt64 {
                    totalReadOps += readOps
                }
                if let writeOps = stats["Operations (Write)"] as? UInt64 {
                    totalWriteOps += writeOps
                } else if let writeOps = stats["kIOBlockStorageDriverStatisticsWritesKey"] as? UInt64 {
                    totalWriteOps += writeOps
                }
                // Try to get timing data (IORegistry returns milliseconds, convert to nanoseconds)
                // Note: These keys may not be available on all macOS versions or disk controllers.
                // The IOKit constants are defined as:
                //   kIOBlockStorageDriverStatisticsReadTimeKey -> "Read Time"
                //   kIOBlockStorageDriverStatisticsWriteTimeKey -> "Write Time"
                // Due to Swift bridging limitations with CFString in dictionary access,
                // we use the string literal values directly (same pattern as operation counts above).
                if let readTimeVal = stats["Read Time"] as? UInt64 {
                    totalReadTime += readTimeVal * 1_000_000  // Convert ms to ns
                }
                if let writeTimeVal = stats["Write Time"] as? UInt64 {
                    totalWriteTime += writeTimeVal * 1_000_000  // Convert ms to ns
                }
            }
        }

        return DetailedDiskStats(
            readBytes: totalReadBytes,
            writeBytes: totalWriteBytes,
            readOperations: totalReadOps,
            writeOperations: totalWriteOps,
            readTime: totalReadTime,
            writeTime: totalWriteTime
        )
    }

    /// Get system-wide disk I/O statistics using IOKit (legacy method for activity detection)
    private func getDiskIOStatistics() -> (readBytes: UInt64, writeBytes: UInt64) {
        let stats = getDetailedDiskIOStats()
        return (stats.readBytes, stats.writeBytes)
    }

    /// Get NVMe SMART data for the boot volume
    /// Reads NVMe SMART attributes from IORegistry
    private func getNVMeSMARTData() -> NVMeSMARTData? {
        // Try to find NVMe controller in IORegistry
        var iterator: io_iterator_t = 0

        // Match NVMe controller
        let matchingDict = IOServiceMatching("IONVMeController")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)

        guard result == KERN_SUCCESS else {
            return getFallbackSMARTData()
        }

        defer { IOObjectRelease(iterator) }

        let nvmeService: io_service_t = IOIteratorNext(iterator)
        guard nvmeService != 0 else {
            return getFallbackSMARTData()
        }

        defer { IOObjectRelease(nvmeService) }

        // Try to get SMART data from IORegistry properties
        guard let properties = IORegistryEntryCreateCFProperty(nvmeService, "SMART" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] else {
            return getFallbackSMARTData()
        }

        // Parse NVMe SMART attributes
        let temperature = (properties["Composite Temperature"] as? Double) ?? 45.0

        // Percentage used (Attribute 4)
        var percentageUsed: Double? = nil
        if let percentUsed = properties["Percentage Used"] as? Double {
            percentageUsed = percentUsed
        }

        // Critical warning (Attribute 1)
        var criticalWarning = false
        if let warning = properties["Critical Warning"] as? UInt8 {
            criticalWarning = warning != 0
        }

        // Power cycles
        let powerCycles: UInt64 = (properties["Power Cycles"] as? UInt64) ?? 0

        // Power on hours
        let powerOnHours: UInt64 = (properties["Power On Hours"] as? UInt64) ?? 0

        // Data units read/written (in 512-byte units, convert to bytes)
        var dataReadBytes: UInt64? = nil
        var dataWrittenBytes: UInt64? = nil

        if let dataUnitsRead = properties["Data Units Read"] as? UInt64 {
            dataReadBytes = dataUnitsRead * 512
        }

        if let dataUnitsWritten = properties["Data Units Written"] as? UInt64 {
            dataWrittenBytes = dataUnitsWritten * 512
        }

        return NVMeSMARTData(
            temperature: temperature,
            percentageUsed: percentageUsed,
            criticalWarning: criticalWarning,
            powerCycles: powerCycles,
            powerOnHours: powerOnHours,
            dataReadBytes: dataReadBytes,
            dataWrittenBytes: dataWrittenBytes
        )
    }

    /// Fallback SMART data using system_profiler for non-NVMe drives
    private func getFallbackSMARTData() -> NVMeSMARTData? {
        // Use system_profiler to get basic disk info
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        task.arguments = ["SPStorageDataType", "-json"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let _ = pipe.fileHandleForReading.readDataToEndOfFile()
            guard task.terminationStatus == 0 else {
                return nil
            }

            // Try to parse SMART status from JSON
            // For now, return a basic structure with estimated values
            return NVMeSMARTData(
                temperature: nil,
                percentageUsed: nil,
                criticalWarning: false,
                powerCycles: 0,
                powerOnHours: 0
            )
        } catch {
            return nil
        }
    }

    // MARK: - Network Monitoring

    private func startNetworkPathMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.networkReachable = (path.status == .satisfied)
            }
        }
        monitor.start(queue: pathMonitorQueue)
        pathMonitor = monitor
    }

    private struct NetworkStats {
        let bytesIn: UInt64
        let bytesOut: UInt64
    }

    private func updateNetworkData() {
        let stats = getNetworkStats()
        let now = Date()

        var uploadRate: Double = 0
        var downloadRate: Double = 0
        var uploadDeltaBytes: UInt64 = 0
        var downloadDeltaBytes: UInt64 = 0
        var isConnected = true

        if let last = lastNetworkStats {
            let timeDelta = now.timeIntervalSince(last.timestamp)

            if timeDelta > 0 {
                // Handle counter wrap-around (when current < last, assume reset or wrap)
                let uploadDelta: UInt64
                if stats.bytesOut >= last.upload {
                    uploadDelta = stats.bytesOut - last.upload
                } else {
                    uploadDelta = stats.bytesOut // Counter reset, use current value
                }

                let downloadDelta: UInt64
                if stats.bytesIn >= last.download {
                    downloadDelta = stats.bytesIn - last.download
                } else {
                    downloadDelta = stats.bytesIn // Counter reset, use current value
                }

                uploadDeltaBytes = uploadDelta
                downloadDeltaBytes = downloadDelta
                uploadRate = Double(uploadDelta) / timeDelta
                downloadRate = Double(downloadDelta) / timeDelta
            }

            let trafficConnected = (stats.bytesIn != last.download || stats.bytesOut != last.upload) || timeDelta < 5.0
            if let reachable = networkReachable {
                isConnected = reachable
            } else {
                isConnected = trafficConnected
            }
        }

        lastNetworkStats = (upload: stats.bytesOut, download: stats.bytesIn, timestamp: now)

        let previousNetworkData = networkData

        // Keep live network sampling to cheap byte counters. Wi-Fi metadata uses
        // synchronous CoreWLAN XPC calls, so preserve cached values on this path.
        let connectionType: ConnectionType = isConnected ? previousNetworkData.connectionType : .disconnected
        let ssid = previousNetworkData.ssid
        let ipAddress = previousNetworkData.ipAddress ?? getLocalIPAddress()
        let wifiDetails = previousNetworkData.wifiDetails
        let publicIP = previousNetworkData.publicIP
        let connectivity = getConnectivityInfo()
        // Per-process network usage comes from the popup-only nettop task.
        let topProcesses: [ProcessNetworkUsage]? = networkTopProcesses
        let interfaceName = previousNetworkData.interfaceName
        let macAddress = previousNetworkData.macAddress
        let linkSpeed = previousNetworkData.linkSpeedMbps
        let dnsServers = previousNetworkData.dnsServers

        let newNetworkData = NetworkData(
            uploadBytesPerSecond: max(0, uploadRate),
            downloadBytesPerSecond: max(0, downloadRate),
            isConnected: isConnected,
            connectionType: connectionType,
            ssid: ssid,
            ipAddress: ipAddress,
            wifiDetails: wifiDetails,
            publicIP: publicIP,
            connectivity: connectivity,
            topProcesses: topProcesses,
            interfaceName: interfaceName,
            macAddress: macAddress,
            linkSpeedMbps: linkSpeed,
            dnsServers: dnsServers
        )

        // Dispatch property updates to main thread for @Observable
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.networkData = newNetworkData

            // Performance optimization: Use circular buffers for O(1) history add
            self.networkUploadCircularBuffer.add(uploadRate)
            self.networkDownloadCircularBuffer.add(downloadRate)
            self.networkUploadHistory = self.networkUploadCircularBuffer.toArray()
            self.networkDownloadHistory = self.networkDownloadCircularBuffer.toArray()
            self.markLiveMetricSampleReceived()
            self.recordResourceHistorySample()

            // Update cumulative totals (for Details section)
            self.totalUploadBytes += Int64(uploadDeltaBytes)
            self.totalDownloadBytes += Int64(downloadDeltaBytes)

            // Update connectivity history (for grid visualization)
            self.connectivityHistory.append(isConnected)
            if self.connectivityHistory.count > 360 {
                self.connectivityHistory.removeFirst()
            }

            // Check notification thresholds for network speed (total in MB/s)
            let totalSpeedMBps = (uploadRate + downloadRate) / 1_000_000
            NotificationManager.shared.checkThreshold(widgetType: .network, value: totalSpeedMBps)
        }
    }

    private func getNetworkStats() -> NetworkStats {
        var activeBytesIn: UInt64 = 0
        var activeBytesOut: UInt64 = 0
        var fallbackBytesIn: UInt64 = 0
        var fallbackBytesOut: UInt64 = 0
        let interfaceNames = interfaceNamesByIndex()

        // mib array: CTL_NET, PF_ROUTE, 0 (protocol), 0 (address family - all), NET_RT_IFLIST2, 0 (interface index - all)
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len: Int = 0

        // First call to get required buffer size
        if sysctl(&mib, UInt32(mib.count), nil, &len, nil, 0) != 0 {
            return NetworkStats(bytesIn: 0, bytesOut: 0)
        }

        guard len > 0 else {
            return NetworkStats(bytesIn: 0, bytesOut: 0)
        }

        var buffer = [UInt8](repeating: 0, count: len)
        if sysctl(&mib, UInt32(mib.count), &buffer, &len, nil, 0) != 0 {
            return NetworkStats(bytesIn: 0, bytesOut: 0)
        }

        // Process the buffer inside withUnsafeBytes to avoid dangling pointer
        buffer.withUnsafeBytes { rawBuffer in
            var offset = 0
            while offset + MemoryLayout<if_msghdr2>.size <= len {
                let msgPtr = rawBuffer.baseAddress!.advanced(by: offset)
                let ifm = msgPtr.assumingMemoryBound(to: if_msghdr2.self).pointee

                guard ifm.ifm_msglen > 0 else { break }

                if Int32(ifm.ifm_type) == RTM_IFINFO2 {
                    // The if_data64 is embedded in if_msghdr2 as ifm_data
                    let name = interfaceNames[UInt32(ifm.ifm_index)]
                    let isLoopback = (Int32(ifm.ifm_flags) & IFF_LOOPBACK) != 0
                    let isUp = (Int32(ifm.ifm_flags) & IFF_UP) != 0
                    let isVirtual = name.map(isVirtualNetworkInterface) ?? false

                    if !isLoopback {
                        fallbackBytesIn += ifm.ifm_data.ifi_ibytes
                        fallbackBytesOut += ifm.ifm_data.ifi_obytes
                    }

                    if isUp && !isLoopback && !isVirtual {
                        activeBytesIn += ifm.ifm_data.ifi_ibytes
                        activeBytesOut += ifm.ifm_data.ifi_obytes
                    }
                }

                offset += Int(ifm.ifm_msglen)
            }
        }

        if activeBytesIn > 0 || activeBytesOut > 0 {
            return NetworkStats(bytesIn: activeBytesIn, bytesOut: activeBytesOut)
        }
        return NetworkStats(bytesIn: fallbackBytesIn, bytesOut: fallbackBytesOut)
    }

    private func interfaceNamesByIndex() -> [UInt32: String] {
        var names: [UInt32: String] = [:]
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else {
            return names
        }
        defer { freeifaddrs(ifaddrPtr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            if let ifaName = current.pointee.ifa_name,
               let addr = current.pointee.ifa_addr,
               addr.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: ifaName)
                let sdl = UnsafeRawPointer(addr).assumingMemoryBound(to: sockaddr_dl.self).pointee
                if sdl.sdl_index > 0 {
                    names[UInt32(sdl.sdl_index)] = name
                }
            }
            ptr = current.pointee.ifa_next
        }
        return names
    }

    private func isVirtualNetworkInterface(_ name: String) -> Bool {
        let virtualPrefixes = [
            "lo", "utun", "awdl", "llw", "bridge", "gif", "stf",
            "p2p", "vmenet", "vmnet", "ipsec", "ap"
        ]
        return virtualPrefixes.contains { name.hasPrefix($0) }
    }

    private func getConnectionType() -> ConnectionType {
        // Use CoreWLAN to detect connection type
        let client = CWWiFiClient.shared()
        if let interface = client.interfaces()?.first,
           interface.powerOn() {
            // WiFi is on and connected
            if interface.ssid() != nil {
                return .wifi
            }
        }

        // Check if we have any network connectivity (fallback to ethernet/other)
        var ifaddrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrs) == 0, let firstAddr = ifaddrs else {
            return .unknown
        }

        defer { freeifaddrs(ifaddrs) }

        var hasEthernet = false
        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            // ifa_name can be null in some cases - must check before creating String
            guard let ifa_name = current.pointee.ifa_name else {
                ptr = current.pointee.ifa_next
                continue
            }
            let interface = String(cString: ifa_name)
            let nextPtr = current.pointee.ifa_next
            ptr = nextPtr

            // Safely unwrap ifa_addr - it can be nil for some interfaces
            guard let ifa_addr = current.pointee.ifa_addr else { continue }
            let addrFamily = ifa_addr.pointee.sa_family

            // Check for active ethernet interfaces (en0, en1, etc.)
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                if interface.hasPrefix("en") && interface != "en0" {
                    // en0 is typically WiFi on macOS, other en* are ethernet
                    hasEthernet = true
                }
            }
        }

        return hasEthernet ? .ethernet : .unknown
    }

    private func getWiFiInterface() -> String? {
        // Use CoreWLAN to get WiFi interface name
        let client = CWWiFiClient.shared()
        if let interface = client.interfaces()?.first,
           interface.powerOn() {
            return interface.interfaceName
        }
        return nil
    }

    private func getWiFiSSID() -> String? {
        // Use CoreWLAN to get the current SSID
        // Note: This requires the app to have the "com.apple.security.network.client" entitlement
        // or be run without sandboxing (like a menu bar app)
        let client = CWWiFiClient.shared()
        if let interface = client.interfaces()?.first,
           interface.powerOn() {
            return interface.ssid()
        }
        return nil
    }

    /// Get local IP address of the primary network interface
    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }

        defer {
            freeifaddrs(ifaddr)
        }

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            let interface = current.pointee

            // ifa_name can be null in some cases - must check before creating String
            guard let ifa_name = interface.ifa_name else {
                ptr = interface.ifa_next
                continue
            }

            // Safely unwrap ifa_addr - it can be nil for some interfaces
            guard let addrPtr = interface.ifa_addr else {
                ptr = interface.ifa_next
                continue
            }

            // Get address family
            let addrFamily = addrPtr.pointee.sa_family

            // Check for IPv4 address
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: ifa_name)

                // Skip loopback and virtual interfaces
                if name == "lo0" || name.hasPrefix("utun") || name.hasPrefix("awdl") || name.hasPrefix("p2p") {
                    ptr = interface.ifa_next
                    continue
                }

                // Prioritize en0 (typically WiFi or primary ethernet)
                if name == "en0" || name == "en1" {
                    // Validate sa_len is reasonable before using it
                    let saLen = Int(addrPtr.pointee.sa_len)
                    guard saLen >= MemoryLayout<sockaddr>.size && saLen <= 256 else {
                        ptr = interface.ifa_next
                        continue
                    }

                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let result = getnameinfo(addrPtr, socklen_t(saLen),
                                            &hostname, socklen_t(hostname.count),
                                            nil, socklen_t(0), NI_NUMERICHOST)
                    if result == 0 {
                        let bytes = hostname.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
                        address = String(decoding: bytes, as: UTF8.self)
                    }
                }
            }

            ptr = interface.ifa_next
        }

        return address
    }

    // MARK: - Enhanced Network Readers

    /// Get detailed WiFi information including SSID, RSSI, channel, security, and BSSID
    private func getWiFiDetails() -> WiFiDetails? {
        let client = CWWiFiClient.shared()
        guard let interface = client.interfaces()?.first,
              interface.powerOn(),
              let ssid = interface.ssid() else {
            return nil
        }

        // Get RSSI (signal strength)
        let rssi = interface.rssiValue()
        let noise = interface.noiseMeasurement()

        // Get channel information
        var channel = 0
        var channelWidth = 20
        var band: WiFiBand = .unknown
        if let channelInfo = interface.wlanChannel() {
            channel = channelInfo.channelNumber
            switch channelInfo.channelWidth {
            case .width20MHz:
                channelWidth = 20
            case .width40MHz:
                channelWidth = 40
            case .width80MHz:
                channelWidth = 80
            case .width160MHz:
                channelWidth = 160
            case .widthUnknown:
                channelWidth = 20
            @unknown default:
                channelWidth = 20
            }

            switch channelInfo.channelBand {
            case .band2GHz:
                band = .ghz24
            case .band5GHz:
                band = .ghz5
            case .band6GHz:
                band = .ghz6
            case .bandUnknown:
                band = .unknown
            @unknown default:
                band = .unknown
            }
        }

        // Get security type and standard
        let security = getSecurityType(from: interface)
        let standard = getWiFiStandard(from: interface)

        // Get BSSID
        let bssid = interface.bssid() ?? "Unknown"

        return WiFiDetails(
            ssid: ssid,
            rssi: rssi,
            noise: noise,
            channel: channel,
            channelWidth: channelWidth,
            band: band,
            security: security,
            standard: standard,
            bssid: bssid
        )
    }

    /// Get Wi-Fi standard (802.11a/b/g/n/ac/ax/be) from PHY mode
    private func getWiFiStandard(from interface: CWInterface) -> String {
        switch interface.activePHYMode() {
        case .mode11a:
            return "802.11a"
        case .mode11b:
            return "802.11b"
        case .mode11g:
            return "802.11g"
        case .mode11n:
            return "802.11n"
        case .mode11ac:
            return "802.11ac"
        case .mode11ax:
            return "802.11ax"
        case .mode11be:
            return "802.11be"
        case .modeNone:
            return "Unknown"
        @unknown default:
            return "Unknown"
        }
    }

    /// Get security type from WiFi interface
    private func getSecurityType(from interface: CWInterface) -> String {
        if let ssid = interface.ssid(),
           let cachedSSID = cachedWiFiSecuritySSID,
           ssid == cachedSSID,
           let cached = cachedWiFiSecurity,
           let lastFetch = lastWiFiSecurityFetch,
           Date().timeIntervalSince(lastFetch) < 600 {
            return cached
        }
        // CoreWLAN security detection via system_profiler
        // This is the most reliable method without requiring additional entitlements
        let security = getSecurityTypeFromSystemProfiler()
        cachedWiFiSecuritySSID = interface.ssid()
        cachedWiFiSecurity = security
        lastWiFiSecurityFetch = Date()
        return security
    }

    /// Get security type from system_profiler (fallback)
    private func getSecurityTypeFromSystemProfiler() -> String {
        if let cached = cachedWiFiSecurity,
           let lastFetch = lastWiFiSecurityFetch,
           Date().timeIntervalSince(lastFetch) < 600 {
            return cached
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        task.arguments = ["SPAirPortDataType", "-xml"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return "Unknown"
            }

            // Parse XML for security type (simplified)
            if output.contains("WPA3") {
                cachedWiFiSecurity = "WPA3"
            } else if output.contains("WPA2") {
                cachedWiFiSecurity = "WPA2"
            } else if output.contains("WPA") {
                cachedWiFiSecurity = "WPA"
            } else if output.contains("WEP") {
                cachedWiFiSecurity = "WEP"
            } else {
                cachedWiFiSecurity = "Unknown"
            }
            lastWiFiSecurityFetch = Date()
            if let cached = cachedWiFiSecurity {
                return cached
            }
        } catch {}

        return "Unknown"
    }

    /// Get public IP information with caching
    private func getPublicIP() -> PublicIPInfo? {
        let now = Date()

        // Return cached IP if still valid
        if let cached = cachedPublicIP,
           let lastFetch = lastPublicIPFetch,
           now.timeIntervalSince(lastFetch) < publicIPCacheInterval {
            return cached
        }

        // Fetch fresh IP data asynchronously
        Task { @MainActor in
            if let ipInfo = await fetchPublicIPFromAPI() {
                self.cachedPublicIP = ipInfo
                self.lastPublicIPFetch = now

                // Trigger IP change notification if IP changed
                if let oldIP = self.cachedPublicIP?.ipAddress,
                   oldIP != ipInfo.ipAddress {
                    self.logger.info("Public IP changed from \(oldIP) to \(ipInfo.ipAddress)")
                }
            }
        }

        return cachedPublicIP
    }

    /// Fetch public IP from external APIs with fallback, then enrich with geolocation
    private func fetchPublicIPFromAPI() async -> PublicIPInfo? {
        // Try multiple APIs for reliability
        let apis: [String] = [
            "https://api.ipify.org?format=text",           // Simple IP
            "https://icanhazip.com",                        // Simple IP
            "https://ifconfig.me/ip",                       // Simple IP
        ]

        for api in apis {
            if let ip = await fetchIPFrom(url: api) {
                let trimmedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
                // Try to enrich with geolocation data
                if let geoInfo = await fetchGeoIPData(ip: trimmedIP) {
                    return geoInfo
                }
                // Fall back to IP-only if geo lookup fails
                return PublicIPInfo(ipAddress: trimmedIP)
            }
        }

        return nil
    }

    /// Fetch geolocation data for a given IP address
    private func fetchGeoIPData(ip: String) async -> PublicIPInfo? {
        guard let url = URL(string: "http://ip-api.com/json/\(ip)?fields=country,city,isp,query") else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }

            let country = json["country"] as? String
            let city = json["city"] as? String
            let isp = json["isp"] as? String
            let queryIP = json["query"] as? String ?? ip

            return PublicIPInfo(ipAddress: queryIP, country: country, city: city, isp: isp)
        } catch {
            logger.warning("Failed to fetch GeoIP data for \(ip): \(error.localizedDescription)")
            return nil
        }
    }

    /// Fetch IP from a specific URL
    private func fetchIPFrom(url: String) async -> String? {
        guard let url = URL(string: url) else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return String(data: data, encoding: .utf8)
        } catch {
            logger.warning("Failed to fetch IP from \(url): \(error.localizedDescription)")
            return nil
        }
    }

    /// Get connectivity information (latency, jitter, reachability)
    private func getConnectivityInfo() -> ConnectivityInfo? {
        let now = Date()

        if let lastCheck = lastConnectivityCheck,
           now.timeIntervalSince(lastCheck) < connectivityCheckInterval {
            return cachedConnectivity
        }

        scheduleConnectivityRefreshIfNeeded(startedAt: now)
        return cachedConnectivity ?? ConnectivityInfo(
            latency: 0,
            jitter: 0,
            isReachable: networkReachable ?? true,
            timestamp: now
        )
    }

    private func scheduleConnectivityRefreshIfNeeded(startedAt now: Date) {
        guard !connectivityRefreshInFlight else { return }
        connectivityRefreshInFlight = true
        lastConnectivityCheck = now
        let fallbackReachable = networkReachable ?? false

        connectivityQueue.async { [weak self] in
            guard let self = self else { return }
            let pingResults = Self.performPingTest(host: "8.8.8.8", count: 2)
            let info: ConnectivityInfo
            if let avgLatency = pingResults.average, !pingResults.latencies.isEmpty {
                info = ConnectivityInfo(
                    latency: avgLatency,
                    jitter: Self.calculateJitter(latencies: pingResults.latencies),
                    isReachable: pingResults.isReachable
                )
            } else {
                info = ConnectivityInfo(
                    latency: 0,
                    jitter: 0,
                    isReachable: fallbackReachable
                )
            }

            Task { @MainActor [weak self] in
                self?.cachedConnectivity = info
                self?.connectivityRefreshInFlight = false
            }
        }
    }

    /// Get DNS server list using SystemConfiguration (cached)
    private func getDNSServers() -> [String] {
        let now = Date()
        if let lastFetch = lastDNSFetch,
           now.timeIntervalSince(lastFetch) < dnsCacheInterval {
            return cachedDNSServers
        }

        let key = "State:/Network/Global/DNS" as CFString
        if let dict = SCDynamicStoreCopyValue(nil, key) as? [String: Any],
           let servers = dict["ServerAddresses"] as? [String] {
            cachedDNSServers = servers
        } else {
            cachedDNSServers = []
        }
        lastDNSFetch = now
        return cachedDNSServers
    }

    /// Primary interface name from SystemConfiguration (e.g., en0)
    private func getPrimaryInterfaceName() -> String? {
        let key = "State:/Network/Global/IPv4" as CFString
        if let dict = SCDynamicStoreCopyValue(nil, key) as? [String: Any],
           let name = dict["PrimaryInterface"] as? String {
            return name
        }
        return nil
    }

    /// MAC address for the given interface name
    private func getMACAddress(for interfaceName: String) -> String? {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else {
            return nil
        }
        defer { freeifaddrs(ifaddrPtr) }

        var ptr = firstAddr
        while true {
            let interface = ptr.pointee
            let name = String(cString: interface.ifa_name)
            if name == interfaceName,
               let addr = interface.ifa_addr,
               addr.pointee.sa_family == UInt8(AF_LINK) {
                let sdl = UnsafeRawPointer(addr).assumingMemoryBound(to: sockaddr_dl.self).pointee
                let macPtr = withUnsafePointer(to: sdl.sdl_data) { ptr -> UnsafeRawPointer in
                    UnsafeRawPointer(ptr)
                }
                let addrPtr = macPtr.advanced(by: Int(sdl.sdl_nlen)).assumingMemoryBound(to: UInt8.self)
                var bytes: [UInt8] = []
                bytes.reserveCapacity(Int(sdl.sdl_alen))
                for i in 0..<Int(sdl.sdl_alen) {
                    bytes.append(addrPtr[i])
                }
                return bytes.map { String(format: "%02x", $0) }.joined(separator: ":").uppercased()
            }
            if let next = interface.ifa_next {
                ptr = next
            } else {
                break
            }
        }
        return nil
    }

    /// Link speed in Mbps if available (WiFi transmit rate)
    private func getLinkSpeedMbps(interfaceName: String?) -> Double? {
        guard let interfaceName else { return nil }
        let client = CWWiFiClient.shared()
        if let interface = client.interface(withName: interfaceName),
           interface.powerOn() {
            return interface.transmitRate()
        }
        return nil
    }

    /// Ping test result structure
    private struct PingResult {
        let latencies: [Double]
        let isReachable: Bool
        let average: Double?
    }

    /// Perform ICMP ping test to a host
    nonisolated private static func performPingTest(host: String, count: Int) -> PingResult {
        var latencies: [Double] = []

        // Use ping command with timeout
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/sbin/ping")
        task.arguments = [
            "-c", String(count),
            "-i", "0.2",  // 200ms between pings
            "-W", "1000", // 1 second timeout per ping
            host
        ]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        let completion = DispatchSemaphore(value: 0)
        task.terminationHandler = { _ in
            completion.signal()
        }

        do {
            try task.run()
            let timeout: DispatchTime = .now() + .seconds(3)
            if completion.wait(timeout: timeout) == .timedOut {
                task.terminate()
                return PingResult(latencies: [], isReachable: false, average: nil)
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return PingResult(latencies: [], isReachable: false, average: nil)
            }

            let isReachable = task.terminationStatus == 0

            // Parse ping output for latencies
            // Expected format: "64 bytes from 8.8.8.8: icmp_seq=0 ttl=117 time=14.2 ms"
            let lines = output.split(separator: "\n")
            for line in lines {
                if line.contains("time=") {
                    if let timeRange = line.range(of: "time="),
                       let msRange = line[timeRange.upperBound...].range(of: " ") {
                        let timeString = String(line[timeRange.upperBound..<msRange.lowerBound])
                        if let latency = Double(timeString) {
                            latencies.append(latency)
                        }
                    }
                }
            }

            let average = latencies.isEmpty ? nil : latencies.reduce(0, +) / Double(latencies.count)
            return PingResult(latencies: latencies, isReachable: isReachable, average: average)

        } catch {
            return PingResult(latencies: [], isReachable: false, average: nil)
        }
    }

    /// Calculate jitter (standard deviation of latencies)
    nonisolated private static func calculateJitter(latencies: [Double]) -> Double {
        guard latencies.count > 1 else { return 0 }

        let avg = latencies.reduce(0, +) / Double(latencies.count)
        let variance = latencies.map { pow($0 - avg, 2) }.reduce(0, +) / Double(latencies.count)
        return sqrt(variance)
    }

    // MARK: - GPU Monitoring

    private func updateGPUData() {
        #if arch(arm64)
        var usage: Double? = nil
        var usedMemory: UInt64? = nil
        var totalMemory: UInt64? = nil
        var temperature: Double? = nil
        var renderUtilization: Double? = nil
        var tilerUtilization: Double? = nil
        var coreClock: Double? = nil
        var memoryClock: Double? = nil
        var fanSpeed: Int? = nil
        var vendor: String? = nil
        var model: String? = nil
        var isActive: Bool? = nil

        // Get total unified memory available to GPU
        if let physMemory = getPhysicalMemory() {
            // Keep a system-reserved pool and treat the remainder as GPU-addressable.
            let gpuAccessibleMemory = physMemory - (2 * 1024 * 1024 * 1024)
            totalMemory = gpuAccessibleMemory
        }

        if let snapshot = readIOAcceleratorSnapshot() {
            usage = snapshot.utilization
            renderUtilization = snapshot.renderUtilization
            tilerUtilization = snapshot.tilerUtilization
            temperature = snapshot.temperature
            coreClock = snapshot.coreClock
            memoryClock = snapshot.memoryClock
            fanSpeed = snapshot.fanSpeed
            vendor = snapshot.vendor
            model = snapshot.model
            isActive = snapshot.isActive
            // Use actual GPU memory from IOAccelerator if available
            usedMemory = snapshot.usedMemory
        }

        // Fallback temperature source when IOAccelerator does not expose one.
        if temperature == nil, let thermals = getThermalInfo() {
            temperature = thermals.gpuTemperature
        }

        // Fall back to estimation only if actual memory not available
        if usedMemory == nil, let total = totalMemory {
            let estimatedGPUMemoryPercent = usage ?? 10.0
            usedMemory = UInt64(Double(total) * (estimatedGPUMemoryPercent / 100.0))
        }

        let newGPUData = GPUData(
            usagePercentage: usage,
            usedMemory: usedMemory,
            totalMemory: totalMemory,
            temperature: temperature,
            renderUtilization: renderUtilization,
            tilerUtilization: tilerUtilization,
            coreClock: coreClock,
            memoryClock: memoryClock,
            fanSpeed: fanSpeed,
            vendor: vendor,
            model: model,
            cores: nil,
            isActive: isActive,
            timestamp: Date()
        )

        // Dispatch property updates to main thread for @Observable
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.gpuData = newGPUData

            if let gpuUsage = usage {
                self.gpuCircularBuffer.add(gpuUsage)
                self.gpuHistory = self.gpuCircularBuffer.toArray()
                NotificationManager.shared.checkThreshold(widgetType: .gpu, value: gpuUsage)
            }
            if let renderUtil = renderUtilization {
                self.gpuRenderCircularBuffer.add(renderUtil)
                self.gpuRenderHistory = self.gpuRenderCircularBuffer.toArray()
            }
            if let tilerUtil = tilerUtilization {
                self.gpuTilerCircularBuffer.add(tilerUtil)
                self.gpuTilerHistory = self.gpuTilerCircularBuffer.toArray()
            }

            if let temperature = temperature {
                self.gpuTemperatureCircularBuffer.add(temperature)
                self.gpuTemperatureHistory = self.gpuTemperatureCircularBuffer.toArray()
            }
        }
        #else
        // Intel Macs - GPU monitoring not supported (discrete GPU)
        // Return empty GPU data to indicate no GPU available
        let emptyGPUData = GPUData(timestamp: Date())
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.gpuData = emptyGPUData
            self.gpuRenderHistory = []
            self.gpuTilerHistory = []
        }
        #endif
    }

    private struct IOAcceleratorSnapshot {
        let utilization: Double?
        let renderUtilization: Double?
        let tilerUtilization: Double?
        let temperature: Double?
        let fanSpeed: Int?
        let coreClock: Double?
        let memoryClock: Double?
        let vendor: String?
        let model: String?
        let isActive: Bool?
        let usedMemory: UInt64?
    }

    private func readIOAcceleratorSnapshot() -> IOAcceleratorSnapshot? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var selected: IOAcceleratorSnapshot?

        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            defer { IOObjectRelease(service) }

            guard let stats = IORegistryEntryCreateCFProperty(
                service,
                "PerformanceStatistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any] else {
                continue
            }

            let ioClass = (IORegistryEntryCreateCFProperty(
                service,
                "IOClass" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? String ?? "").lowercased()

            let utilization = percentFromAny(stats["Device Utilization %"]) ?? percentFromAny(stats["GPU Activity(%)"])
            let renderUtil = percentFromAny(stats["Renderer Utilization %"])
            let tilerUtil = percentFromAny(stats["Tiler Utilization %"])
            let temperature = doubleFromAny(stats["Temperature(C)"])
            let fanSpeed = intFromAny(stats["Fan Speed(%)"])
            let coreClock = doubleFromAny(stats["Core Clock(MHz)"])
            let memoryClock = doubleFromAny(stats["Memory Clock(MHz)"])
            let model = (stats["model"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

            // Try to read actual GPU memory allocation from IOAccelerator stats
            let usedMemory: UInt64? = {
                // Try known keys for GPU memory allocation
                for key in ["alloc_system_memory", "inUseSystemMemory", "vramUsedBytes"] {
                    if let value = stats[key] {
                        if let num = value as? UInt64, num > 0 { return num }
                        if let num = value as? Int, num > 0 { return UInt64(num) }
                        if let num = value as? NSNumber, num.uint64Value > 0 { return num.uint64Value }
                    }
                }
                return nil
            }()

            let vendor: String?
            if ioClass.contains("amd") {
                vendor = "AMD"
            } else if ioClass.contains("intel") {
                vendor = "Intel"
            } else if ioClass.contains("agx") || ioClass.contains("apple") {
                vendor = "Apple"
            } else {
                vendor = nil
            }

            var isActive: Bool? = nil
            if let agcInfo = IORegistryEntryCreateCFProperty(
                service,
                "AGCInfo" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Int],
               let poweredOff = agcInfo["poweredOffByAGC"] {
                isActive = poweredOff == 0
            }

            let candidate = IOAcceleratorSnapshot(
                utilization: utilization,
                renderUtilization: renderUtil,
                tilerUtilization: tilerUtil,
                temperature: temperature,
                fanSpeed: fanSpeed,
                coreClock: coreClock,
                memoryClock: memoryClock,
                vendor: vendor,
                model: model,
                isActive: isActive,
                usedMemory: usedMemory
            )

            // Keep the most active entry if multiple accelerators are present.
            if selected == nil || (candidate.utilization ?? 0) > (selected?.utilization ?? 0) {
                selected = candidate
            }
        }

        return selected
    }

    private func percentFromAny(_ raw: Any?) -> Double? {
        guard let value = doubleFromAny(raw) else { return nil }
        if value > 1 {
            return max(0, min(100, value))
        }
        return max(0, min(100, value * 100))
    }

    private func doubleFromAny(_ raw: Any?) -> Double? {
        switch raw {
        case let number as NSNumber:
            return number.doubleValue
        case let value as Double:
            return value
        case let value as Int:
            return Double(value)
        case let value as Float:
            return Double(value)
        default:
            return nil
        }
    }

    private func intFromAny(_ raw: Any?) -> Int? {
        switch raw {
        case let number as NSNumber:
            return number.intValue
        case let value as Int:
            return value
        case let value as Double:
            return Int(value)
        default:
            return nil
        }
    }

    /// Get physical memory size
    private func getPhysicalMemory() -> UInt64? {
        var mib: [Int32] = [CTL_HW, HW_MEMSIZE]
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        guard sysctl(&mib, u_int(mib.count), &size, &len, nil, 0) == 0 else { return nil }
        return size
    }

    /// Thermal information structure
    private struct ThermalInfo {
        let cpuTemperature: Double?
        let gpuTemperature: Double?
        let fanSpeed: Int?
    }

    /// Get thermal information from SMC or IOPM
    private func getThermalInfo() -> ThermalInfo? {
        // Try IOPM thermal management
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOPMThermalProfile"), &iterator) == KERN_SUCCESS else {
            return nil
        }

        defer { IOObjectRelease(iterator) }

        let cpuTemp: Double? = nil
        let gpuTemp: Double? = nil

        // Apple Silicon thermal zones
        let _ = [
            "TC0E", // CPU
            "TC0F", // CPU
            "TC0c", // CPU
            "TG0E", // GPU (if available)
            "TG0P"  // GPU
        ]

        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            if let _ = IORegistryEntryCreateCFProperty(service, kIOPropertyThermalInformationKey as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
                // Try to parse thermal info
                IOObjectRelease(service)
                // Thermal info parsing is complex - return nil for now
                // Temperature monitoring requires SMC access which is restricted
                break
            }
            IOObjectRelease(service)
        }

        return ThermalInfo(cpuTemperature: cpuTemp, gpuTemperature: gpuTemp, fanSpeed: nil)
    }

    // MARK: - Battery Monitoring

    private func updateBatteryData() {
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFDictionary]

        let noBatteryData = BatteryData(isPresent: false)

        guard let powerSources = sources else {
            batteryLastACPowerTimestamp = nil
            wasOnACPower = false
            DispatchQueue.main.async { [weak self] in
                self?.batteryData = noBatteryData
            }
            return
        }

        for source in powerSources {
            let info = source as NSDictionary

            guard let type = info[kIOPSTypeKey] as? String,
                  type == kIOPSInternalBatteryType else {
                continue
            }

            let isPresent = info[kIOPSIsPresentKey] as? Bool ?? true
            guard isPresent else {
                batteryLastACPowerTimestamp = nil
                wasOnACPower = false
                DispatchQueue.main.async { [weak self] in
                    self?.batteryData = noBatteryData
                }
                return
            }

            let currentState = info[kIOPSPowerSourceStateKey] as? String
            let isOnACPower = currentState == kIOPSACPowerValue
            let isCharging = isOnACPower
            let isCharged = info[kIOPSIsChargedKey] as? Bool ?? false

            if isOnACPower {
                if !wasOnACPower || batteryLastACPowerTimestamp == nil {
                    batteryLastACPowerTimestamp = Date()
                }
            }

            // IOPS key meanings:
            // - kIOPSCurrentCapacityKey: current capacity in mAh
            // - kIOPSMaxCapacityKey: maximum capacity in mAh
            // - kIOPSDesignCapacityKey: design capacity in mAh
            // Percentage is calculated as (current / max) * 100
            let currentCapacitymAh = info[kIOPSCurrentCapacityKey] as? Int
            let maxCapacitymAh = info[kIOPSMaxCapacityKey] as? Int
            let designCapacitymAh = info[kIOPSDesignCapacityKey] as? Int

            // Calculate percentage from current/max mAh
            let capacityPercent: Int
            if let current = currentCapacitymAh, let maxCap = maxCapacitymAh, maxCap > 0 {
                capacityPercent = Int((Double(current) / Double(maxCap)) * 100.0)
            } else {
                capacityPercent = 0
            }

            let timeToEmpty = info[kIOPSTimeToEmptyKey] as? Int

            // Battery health
            let health: BatteryHealth
            if let maxCap = maxCapacitymAh, let designCap = designCapacitymAh, designCap > 0 {
                let healthPercent = Double(maxCap) / Double(designCap) * 100
                if healthPercent > 80 {
                    health = .good
                } else if healthPercent > 60 {
                    health = .fair
                } else {
                    health = .poor
                }
            } else {
                health = .unknown
            }

            // Get cycle count from IOKit
            let cycleCount = getBatteryCycleCount()

            // Get temperature from IOKit (in deci-degrees)
            let temperature = getBatteryTemperature()

            // Get optimized charging status from IOPS
            let optimizedCharging = getOptimizedChargingStatus(from: info)

            // Get charger wattage
            let chargerWattage = getChargerWattage()

            // Get electrical metrics from IOKit
            let amperage = getBatteryAmperage()
            let voltage = getBatteryVoltage()
            let designedCapacity = getBatteryDesignedCapacity()  // Gets from IOKit AppleSmartBattery

            // Use IOPS capacity values directly (mAh)
            let currentCapacity: UInt64? = currentCapacitymAh.flatMap { UInt64($0) }
            let maxCapacity: UInt64? = maxCapacitymAh.flatMap { UInt64($0) }
            let chargingCurrent = getChargingCurrent()
            let chargingVoltage = getChargingVoltage()

            // Calculate battery power (W = V × A / 1000 for mV/mA to W)
            var batteryPower: Double? = nil
            if let v = voltage, let a = amperage {
                // Use absolute value of amperage for power display
                batteryPower = (v * abs(a)) / 1000.0  // W
            }

            let newBatteryData = BatteryData(
                isPresent: true,
                isCharging: isCharging,
                isCharged: isCharged,
                chargePercentage: Double(capacityPercent),
                estimatedMinutesRemaining: timeToEmpty,
                health: health,
                cycleCount: cycleCount,
                temperature: temperature,
                optimizedCharging: optimizedCharging,
                chargerWattage: chargerWattage,
                amperage: amperage,
                voltage: voltage,
                batteryPower: batteryPower,
                designedCapacity: designedCapacity,
                currentCapacity: currentCapacity,
                maxCapacity: maxCapacity,
                chargingCurrent: chargingCurrent,
                chargingVoltage: chargingVoltage,
                lastChargeTimestamp: batteryLastACPowerTimestamp
            )
            // Dispatch property updates to main thread for @Observable
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.batteryData = newBatteryData

                // Performance optimization: Use circular buffer for O(1) history add
                self.batteryCircularBuffer.add(Double(capacityPercent))
                self.batteryHistory = self.batteryCircularBuffer.toArray()

                // Check notification thresholds (only when not charging to avoid spam)
                if !isCharging {
                    NotificationManager.shared.checkThreshold(widgetType: .battery, value: Double(capacityPercent))
                }
            }
            wasOnACPower = isOnACPower
            return
        }

        batteryLastACPowerTimestamp = nil
        wasOnACPower = false
        DispatchQueue.main.async { [weak self] in
            self?.batteryData = noBatteryData
        }
    }

    // MARK: - Enhanced Battery Readers

    /// Get battery cycle count from IOKit
    private func getBatteryCycleCount() -> Int? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery"),
            &iterator
        ) == KERN_SUCCESS else {
            return nil
        }

        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard let properties = IORegistryEntryCreateCFProperty(
            service,
            "DesignCycleCount9C" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Int else {
            return nil
        }

        return properties
    }

    /// Get battery temperature from IOKit (returns Celsius)
    private func getBatteryTemperature() -> Double? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery"),
            &iterator
        ) == KERN_SUCCESS else {
            return nil
        }

        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        // Temperature is stored in deci-degrees (divide by 100 to get Celsius)
        guard let tempValue = IORegistryEntryCreateCFProperty(
            service,
            "Temperature" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Int else {
            return nil
        }

        // Convert from deci-degrees Celsius to Celsius
        return Double(tempValue) / 100.0
    }

    /// Get optimized charging status from IOPS power source info
    private func getOptimizedChargingStatus(from info: NSDictionary) -> Bool? {
        // Check if "Optimized Battery Charging Engaged" key exists
        if let optimizedEngaged = info["Optimized Battery Charging Engaged"] as? Int {
            return optimizedEngaged == 1
        }
        return nil
    }

    /// Get charger wattage from IOPS
    private func getChargerWattage() -> Double? {
        guard let adapterDetails = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any] else {
            return nil
        }

        if let watts = adapterDetails[kIOPSPowerAdapterWattsKey] as? Int {
            return Double(watts)
        }

        return nil
    }

    /// Get battery amperage from IOKit (mA, negative = charging, positive = discharging)
    private func getBatteryAmperage() -> Double? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery"),
            &iterator
        ) == KERN_SUCCESS else {
            return nil
        }

        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard let amperage = IORegistryEntryCreateCFProperty(
            service,
            "Amperage" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Int else {
            return nil
        }

        return Double(amperage)  // mA, negative when charging
    }

    /// Get battery voltage from IOKit (mV)
    private func getBatteryVoltage() -> Double? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery"),
            &iterator
        ) == KERN_SUCCESS else {
            return nil
        }

        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard let voltage = IORegistryEntryCreateCFProperty(
            service,
            "Voltage" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Int else {
            return nil
        }

        return Double(voltage) / 1000.0  // Convert mV to V
    }

    /// Get battery designed capacity from IOKit (mAh)
    private func getBatteryDesignedCapacity() -> UInt64? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery"),
            &iterator
        ) == KERN_SUCCESS else {
            return nil
        }

        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard let capacity = IORegistryEntryCreateCFProperty(
            service,
            "DesignCapacity" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Int else {
            return nil
        }

        return UInt64(capacity)
    }

    /// Get charging current from adapter (mA)
    /// Note: IOPS doesn't provide current directly, so we estimate from wattage
    /// assuming USB-C PD standard voltages (5V, 9V, 15V, 20V)
    private func getChargingCurrent() -> Double? {
        guard let adapterDetails = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any] else {
            return nil
        }

        // Get wattage if available
        guard let watts = adapterDetails[kIOPSPowerAdapterWattsKey] as? Int else {
            return nil
        }

        // USB-C Power Delivery typical voltages: 5V, 9V, 15V, 20V
        // Estimate current based on wattage
        let wattage = Double(watts)
        let possibleVoltages = [5.0, 9.0, 15.0, 20.0]

        // Find most likely voltage and compute current
        for voltage in possibleVoltages.reversed() {
            if wattage / voltage >= 0.5 && wattage / voltage <= 6.0 {
                return wattage / voltage * 1000  // Convert A to mA
            }
        }

        // Fallback: assume 20V for higher wattage chargers
        if wattage >= 60 {
            return wattage / 20.0 * 1000
        } else if wattage >= 30 {
            return wattage / 15.0 * 1000
        }

        return nil
    }

    /// Get charging voltage from adapter (V)
    /// Note: IOPS doesn't provide voltage directly, so we estimate from wattage
    private func getChargingVoltage() -> Double? {
        guard let adapterDetails = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any] else {
            return nil
        }

        guard let watts = adapterDetails[kIOPSPowerAdapterWattsKey] as? Int else {
            return nil
        }

        let wattage = Double(watts)

        // Estimate voltage based on wattage ranges
        if wattage >= 60 { return 20.0 }      // 60W+ chargers typically use 20V
        else if wattage >= 30 { return 15.0 } // 30-60W typically use 15V
        else if wattage >= 18 { return 9.0 }  // 18-30W typically use 9V
        else if wattage >= 10 { return 5.0 }  // 10-18W typically use 5V
        else { return 5.0 }                   // Low wattage uses 5V
    }

    // MARK: - Sensors Monitoring

    private func updateSensorsData() {
        let newSensorsData = SensorsData(
            temperatures: getSMCTemperatures(),
            fans: getSMCFans(),
            voltages: getSMCVoltages(),
            power: getSMCPower()
        )
        // Dispatch property updates to main thread for @Observable
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.sensorsData = newSensorsData

            // Check notification thresholds for max temperature
            if let maxTemp = newSensorsData.temperatures.map({ $0.value }).max() {
                // Performance optimization: Use circular buffer for O(1) history add
                self.sensorsCircularBuffer.add(maxTemp)
                self.sensorsHistory = self.sensorsCircularBuffer.toArray()

                NotificationManager.shared.checkThreshold(widgetType: .sensors, value: maxTemp)
            }
        }
    }

    // MARK: - Enhanced Sensors Readers

    /// Get temperature sensors using SMCReader first, then IOKit fallback
    private func getSMCTemperatures() -> [SensorReading] {
        // Try SMCReader first for accurate hardware readings
        if SMCReader.shared.isAvailable {
            let smcReadings = SMCReader.shared.readTemperatures()
            if !smcReadings.isEmpty {
                return smcReadings
            }
        }

        var readings: [SensorReading] = []

        #if arch(arm64)
        // Apple Silicon: Use IORegistry for thermal sensors
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOThermalSensor"),
            &iterator
        ) == KERN_SUCCESS else {
            return getEstimatedTemperatures()
        }

        defer { IOObjectRelease(iterator) }

        var temps: [Double] = []
        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }

            if let props = IORegistryEntryCreateCFProperty(
                service,
                "Temperature" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? Double {
                temps.append(props)
            }
            IOObjectRelease(service)
        }

        if !temps.isEmpty {
            let avgTemp = temps.reduce(0, +) / Double(temps.count)
            readings.append(SensorReading(
                id: "cpu_thermal",
                name: "CPU",
                value: avgTemp,
                unit: "°C",
                min: 20,
                max: 100
            ))
        }
        #else
        // Intel Macs: Try to estimate temperature
        readings.append(getEstimatedTemperatures().first ?? SensorReading(
            id: "cpu_estimated",
            name: "CPU",
            value: getThermalStateTemperature() ?? 45,
            unit: "°C",
            min: 20,
            max: 100
        ))
        #endif

        return readings.isEmpty ? getEstimatedTemperatures() : readings
    }

    /// Get estimated temperature based on thermal state
    private func getEstimatedTemperatures() -> [SensorReading] {
        let thermalState = ProcessInfo.processInfo.thermalState
        let temp: Double
        switch thermalState {
        case .nominal: temp = 45
        case .fair: temp = 60
        case .serious: temp = 75
        case .critical: temp = 90
        @unknown default: temp = 50
        }

        return [SensorReading(
            id: "cpu_estimated",
            name: "CPU",
            value: temp,
            unit: "°C",
            min: 20,
            max: 100
        )]
    }

    /// Get fan sensors using IOKit
    private func getSMCFans() -> [FanReading] {
        var readings: [FanReading] = []

        // Try to read fan info from IOKit
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AppleSMC"),
            &iterator
        ) == KERN_SUCCESS else {
            return readings
        }

        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else {
            return readings
        }
        defer { IOObjectRelease(service) }

        // Try to get fan count
        if let fanCountProp = IORegistryEntryCreateCFProperty(
            service,
            "FNum" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Int {
            for i in 0..<fanCountProp {
                let currentSpeedKey = "F\(i)Ac" as CFString
                let maxSpeedKey = "F\(i)Mx" as CFString

                let currentSpeed = IORegistryEntryCreateCFProperty(
                    service,
                    currentSpeedKey,
                    kCFAllocatorDefault,
                    0
                )?.takeRetainedValue() as? Int

                let maxSpeed = IORegistryEntryCreateCFProperty(
                    service,
                    maxSpeedKey,
                    kCFAllocatorDefault,
                    0
                )?.takeRetainedValue() as? Int

                if let current = currentSpeed {
                    readings.append(FanReading(
                        id: "fan_\(i)",
                        name: "Fan \(i)",
                        rpm: current,
                        minRPM: 0,
                        maxRPM: maxSpeed,
                        mode: .automatic
                    ))
                }
            }
        }

        return readings
    }

    /// Get voltage sensors
    private func getSMCVoltages() -> [SensorReading] {
        var readings: [SensorReading] = []

        #if arch(arm64)
        // Apple Silicon voltage reading via IORegistry (limited availability)
        // Most voltage sensors require privileged access
        var iterator: io_iterator_t = 0
        if IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AppleARMIODevice"),
            &iterator
        ) == KERN_SUCCESS {
            defer { IOObjectRelease(iterator) }

            var service: io_object_t
            repeat {
                service = IOIteratorNext(iterator)
                guard service != 0 else { break }

                if let voltage = IORegistryEntryCreateCFProperty(
                    service,
                    "voltage-s0" as CFString,
                    kCFAllocatorDefault,
                    0
                )?.takeRetainedValue() as? Double {
                    readings.append(SensorReading(
                        id: "cpu_voltage",
                        name: "CPU Voltage",
                        value: voltage / 1000, // Convert mV to V
                        unit: "V",
                        min: 0.8,
                        max: 1.5
                    ))
                }
                IOObjectRelease(service)
            } while service != 0
        }
        #endif

        // SMC voltage fallback
        let voltageKeys: [(key: String, name: String)] = [
            ("VC0C", "CPU Core"),
            ("VD0R", "DRAM"),
            ("VP0R", "12V Rail"),
            ("VN0C", "GPU"),
        ]
        for entry in voltageKeys {
            if let voltage = SMCReader.shared.getValue(entry.key) {
                readings.append(SensorReading(
                    id: "voltage_\(entry.key)",
                    name: "\(entry.name) Voltage",
                    value: voltage,
                    unit: "V",
                    min: 0.0,
                    max: 15.0
                ))
            }
        }

        return readings
    }

    /// Get power sensors
    private func getSMCPower() -> [SensorReading] {
        var readings: [SensorReading] = []

        // Try SMC power keys first
        let powerKeys: [(key: String, name: String)] = [
            ("PSTR", "System Total"),
            ("PC0C", "CPU Package"),
            ("PCPG", "GPU"),
            ("PDTR", "DRAM"),
        ]
        for entry in powerKeys {
            if let power = SMCReader.shared.getValue(entry.key) {
                readings.append(SensorReading(
                    id: "power_\(entry.key)",
                    name: "\(entry.name) Power",
                    value: power,
                    unit: "W",
                    min: 0,
                    max: 100
                ))
            }
        }

        // Fall back to thermal estimates only if no SMC readings succeeded
        if readings.isEmpty {
            #if arch(arm64)
            if let cpuPower = getCPUThermalPower() {
                readings.append(SensorReading(
                    id: "cpu_power_estimated",
                    name: "CPU Power",
                    value: cpuPower,
                    unit: "W",
                    min: 0,
                    max: 30
                ))
            }

            if let gpuPower = getGPUThermalPower() {
                readings.append(SensorReading(
                    id: "gpu_power_estimated",
                    name: "GPU Power",
                    value: gpuPower,
                    unit: "W",
                    min: 0,
                    max: 30
                ))
            }
            #endif
        }

        return readings
    }

    /// Estimate CPU power consumption based on thermal state
    private func getCPUThermalPower() -> Double? {
        let thermalState = ProcessInfo.processInfo.thermalState
        switch thermalState {
        case .nominal: return 2.0
        case .fair: return 8.0
        case .serious: return 15.0
        case .critical: return 25.0
        @unknown default: return nil
        }
    }

    /// Estimate GPU power consumption based on usage
    private func getGPUThermalPower() -> Double? {
        // Use GPU data from WidgetDataManager
        if gpuData.usagePercentage != nil {
            let percent = gpuData.usagePercentage ?? 0
            return percent * 0.3 // Max ~30W at full load
        }
        return nil
    }

    // MARK: - Helper Methods

    /// Performance optimization: Add to circular buffer and update history array
    /// This is more efficient than append + removeFirst which is O(n)
    private func addToHistory(_ array: inout [Double], value: Double, maxPoints: Int) {
        array.append(value)
        if array.count > maxPoints {
            array.removeFirst()
        }
    }

    /// Add value to appropriate circular buffer and sync with history array
    private func addToCircularBuffer(_ buffer: inout CircularBuffer, history: inout [Double], value: Double) {
        buffer.add(value)
        // Only update history when needed for UI access (lazy sync)
        // This reduces memory allocations from repeated array operations
    }

    /// Sync circular buffer to history array for UI access
    private func syncHistory(_ buffer: CircularBuffer, history: inout [Double]) {
        history = buffer.toArray()
    }

    /// Sync all circular buffers to history arrays (call sparingly)
    public func syncAllHistory() {
        cpuHistory = cpuCircularBuffer.toArray()
        memoryHistory = memoryCircularBuffer.toArray()
        diskHistory = diskCircularBuffer.toArray()
        diskReadHistory = diskReadCircularBuffer.toArray()
        diskWriteHistory = diskWriteCircularBuffer.toArray()
        networkUploadHistory = networkUploadCircularBuffer.toArray()
        networkDownloadHistory = networkDownloadCircularBuffer.toArray()
        gpuHistory = gpuCircularBuffer.toArray()
        gpuRenderHistory = gpuRenderCircularBuffer.toArray()
        gpuTilerHistory = gpuTilerCircularBuffer.toArray()
        batteryHistory = batteryCircularBuffer.toArray()
        sensorsHistory = sensorsCircularBuffer.toArray()
        bluetoothHistory = bluetoothCircularBuffer.toArray()
    }

    #if DEBUG
    var activeReaderIDsForTesting: Set<String> {
        Set(readerTimers.keys)
    }

    func cancelReaderTimersForTesting(keepMonitoring: Bool = true) {
        readerTimers.values.forEach { $0.cancel() }
        readerTimers.removeAll()
        isMonitoring = keepMonitoring
    }

    func setLastLiveSampleAtForTesting(_ date: Date?) {
        lastLiveSampleAt = date
        hasLiveMetricSample = date != nil
    }

    func markLiveMetricSampleReceivedForTesting(at date: Date = Date()) {
        markLiveMetricSampleReceived(at: date)
    }
    #endif

    private func recordResourceHistorySample() {
        let primaryDisk = diskVolumes.first(where: { $0.isBootVolume }) ?? diskVolumes.first
        let sample = ResourceMetricSample(
            cpuPercent: cpuData.totalUsage,
            memoryPercent: memoryData.usagePercentage,
            memoryUsedBytes: memoryData.usedBytes,
            memoryTotalBytes: memoryData.totalBytes,
            networkUploadBytesPerSecond: networkData.uploadBytesPerSecond,
            networkDownloadBytesPerSecond: networkData.downloadBytesPerSecond,
            diskUsedPercent: primaryDisk?.usagePercentage ?? 0,
            diskReadBytesPerSecond: primaryDisk?.readBytesPerSecond ?? 0,
            diskWriteBytesPerSecond: primaryDisk?.writeBytesPerSecond ?? 0
        )
        WidgetHistoryStore.shared.record(sample)
    }

    // MARK: - Bluetooth Monitoring

    /// Get list of connected Bluetooth devices with battery information
    private func getBluetoothDevices() -> [BluetoothDevice] {
        var devices: [BluetoothDevice] = []

        // Try to read from system_profiler SPBluetoothDataType
        let task = Process()
        task.launchPath = "/usr/sbin/system_profiler"
        task.arguments = ["SPBluetoothDataType", "-json"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                // Handle both array and dict formats (macOS 14+ returns array)
                var controllerDicts: [[String: Any]] = []
                if let array = json["SPBluetoothDataType"] as? [[String: Any]] {
                    controllerDicts = array
                } else if let dict = json["SPBluetoothDataType"] as? [String: Any] {
                    controllerDicts = [dict]
                }

                for controllerDict in controllerDicts {
                    // Parse connected devices
                    if let connectedDevices = controllerDict["device_connected"] as? [[String: Any]] {
                        for deviceInfo in connectedDevices {
                            if let name = deviceInfo["device_name"] as? String {
                                let device = parseBluetoothDevice(name: name, info: deviceInfo, isConnected: true)
                                devices.append(device)
                            }
                        }
                    }

                    // Also check for device_title for devices in a different format
                    if let allDevices = controllerDict["device_title"] as? [[String: Any]] {
                        for deviceInfo in allDevices {
                            if let name = deviceInfo["device_name"] as? String,
                               let connectionStatus = deviceInfo["device_connectionStatus"] as? String,
                               connectionStatus.contains("Connected") {
                                let device = parseBluetoothDevice(name: name, info: deviceInfo, isConnected: true)
                                devices.append(device)
                            }
                        }
                    }
                }
            }
        } catch {
            // Silently fail - Bluetooth not available or permission denied
        }

        return devices
    }

    /// Parse a single Bluetooth device from system_profiler info dict
    private func parseBluetoothDevice(name: String, info: [String: Any], isConnected: Bool) -> BluetoothDevice {
        let primaryBattery = info["device_batteryLevel"] as? Int

        // Multi-battery: AirPods case/left/right
        var batteryLevels: [BluetoothDevice.DeviceBatteryLevel] = []
        if let caseBattery = info["device_batteryLevelCase"] as? Int {
            batteryLevels.append(BluetoothDevice.DeviceBatteryLevel(label: "Case", percentage: caseBattery, component: .caseBattery))
        }
        if let leftBattery = info["device_batteryLevelLeft"] as? Int {
            batteryLevels.append(BluetoothDevice.DeviceBatteryLevel(label: "Left", percentage: leftBattery, component: .left))
        }
        if let rightBattery = info["device_batteryLevelRight"] as? Int {
            batteryLevels.append(BluetoothDevice.DeviceBatteryLevel(label: "Right", percentage: rightBattery, component: .right))
        }

        // Device type from minorType string
        let deviceType: BluetoothDeviceType
        if let minorType = info["device_minorType"] as? String {
            if minorType.contains("Headphones") || minorType.contains("Headset") {
                deviceType = .headphones
            } else if minorType.contains("Mouse") {
                deviceType = .mouse
            } else if minorType.contains("Keyboard") {
                deviceType = .keyboard
            } else if minorType.contains("Trackpad") {
                deviceType = .trackpad
            } else if minorType.contains("Speaker") {
                deviceType = .speaker
            } else if minorType.contains("Gamepad") || minorType.contains("Game Controller") {
                deviceType = .gameController
            } else {
                deviceType = .unknown
            }
        } else {
            deviceType = .unknown
        }

        // Signal strength from RSSI (-100 to -30 dBm mapped to 0-100)
        var signalStrength: Int?
        if let rssi = info["device_rssi"] as? Int {
            signalStrength = max(0, min(100, Int((Double(rssi + 100) / 70.0) * 100)))
        } else if let rssiStr = info["device_rssi"] as? String, let rssi = Int(rssiStr) {
            signalStrength = max(0, min(100, Int((Double(rssi + 100) / 70.0) * 100)))
        }

        return BluetoothDevice(
            name: name,
            deviceType: deviceType,
            isConnected: isConnected,
            isPaired: true,
            primaryBatteryLevel: primaryBattery,
            signalStrength: signalStrength,
            batteryLevels: batteryLevels
        )
    }

    private func updateBluetoothData() {
        // Bluetooth updates less frequently than other data sources
        if let lastUpdate = lastBluetoothUpdate,
           Date().timeIntervalSince(lastUpdate) < bluetoothUpdateInterval {
            return
        }

        lastBluetoothUpdate = Date()

        // Read bluetooth data inline using IOBluetooth
        let devices = getBluetoothDevices()
        let newData = BluetoothData(
            isBluetoothEnabled: !devices.isEmpty,
            connectedDevices: devices,
            timestamp: Date()
        )
        self.bluetoothData = newData

        // Performance optimization: Use circular buffer for O(1) history add
        let connectedCount = Double(devices.filter { $0.isConnected }.count)
        bluetoothCircularBuffer.add(connectedCount)
        bluetoothHistory = bluetoothCircularBuffer.toArray()

        // Check notification thresholds for Bluetooth device batteries
        let connectedDeviceBatteries = devices
            .filter { $0.isConnected }
            .compactMap { $0.primaryBatteryLevel }
        if let lowestBattery = connectedDeviceBatteries.min() {
            NotificationManager.shared.checkThreshold(widgetType: .bluetooth, value: Double(lowestBattery))
        }
    }

    // MARK: - History Accessors

    /// Get network upload history for chart visualization
    public func getNetworkUploadHistory() -> [Double] {
        networkUploadHistory
    }

    /// Get network download history for chart visualization
    public func getNetworkDownloadHistory() -> [Double] {
        networkDownloadHistory
    }

    /// Reset total network usage statistics (called from Network popover reset button)
    public func resetTotalNetworkUsage() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.totalUploadBytes = 0
            self.totalDownloadBytes = 0
        }
    }

    /// Get CPU history for chart visualization
    public func getCPUHistory() -> [Double] {
        cpuHistory
    }

    /// Get memory history for chart visualization
    public func getMemoryHistory() -> [Double] {
        memoryHistory
    }

    /// Get GPU history for chart visualization
    public func getGPUHistory() -> [Double] {
        gpuHistory
    }

    /// Get battery history for chart visualization
    public func getBatteryHistory() -> [Double] {
        batteryHistory
    }

    /// Get sensors history for chart visualization
    public func getSensorsHistory() -> [Double] {
        sensorsHistory
    }

    /// Get bluetooth history for chart visualization
    public func getBluetoothHistory() -> [Double] {
        bluetoothHistory
    }

    /// Get disk history for chart visualization
    public func getDiskHistory() -> [Double] {
        diskHistory
    }
}

// MARK: - C Types

private struct xsw_usage {
    var xsu_total: UInt64
    var xsu_used: UInt64
    var xsu_pagesize: UInt32
    var xsu_encrypted: UInt32
}
