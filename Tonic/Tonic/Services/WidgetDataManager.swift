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

    public init(uploadBytesPerSecond: Double, downloadBytesPerSecond: Double,
                isConnected: Bool, connectionType: ConnectionType = .unknown,
                ssid: String? = nil, ipAddress: String? = nil,
                wifiDetails: WiFiDetails? = nil,
                publicIP: PublicIPInfo? = nil,
                connectivity: ConnectivityInfo? = nil,
                topProcesses: [ProcessNetworkUsage]? = nil,
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

    public let timestamp: Date

    public init(isPresent: Bool, isCharging: Bool = false, isCharged: Bool = false,
                chargePercentage: Double = 0, estimatedMinutesRemaining: Int? = nil,
                health: BatteryHealth = .unknown, cycleCount: Int? = nil,
                temperature: Double? = nil, optimizedCharging: Bool? = nil,
                chargerWattage: Double? = nil,
                amperage: Double? = nil, voltage: Double? = nil, batteryPower: Double? = nil,
                designedCapacity: UInt64? = nil, currentCapacity: UInt64? = nil,
                maxCapacity: UInt64? = nil, chargingCurrent: Double? = nil,
                chargingVoltage: Double? = nil,
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
        public let id = UUID()
        public let label: String
        public let percentage: Int
        public let component: BatteryComponent

        public init(label: String, percentage: Int, component: BatteryComponent = .unknown) {
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

    // Performance optimization: Disable debug logging in release builds
    #if DEBUG
    private let isDebugLoggingEnabled = true
    #else
    private let isDebugLoggingEnabled = false
    #endif

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
    private var batteryCircularBuffer = CircularBuffer(capacity: 180)
    private var sensorsCircularBuffer = CircularBuffer(capacity: 180)
    private var bluetoothCircularBuffer = CircularBuffer(capacity: 180)

    // MARK: - CPU Data

    public private(set) var cpuData: CPUData = CPUData(totalUsage: 0, perCoreUsage: [])
    public private(set) var cpuHistory: [Double] = []
    public private(set) var topCPUApps: [AppResourceUsage] = []

    // MARK: - Memory Data

    public private(set) var memoryData: MemoryData = MemoryData(
        usedBytes: 0, totalBytes: 0, pressure: .normal
    )
    public private(set) var memoryHistory: [Double] = []
    public private(set) var topMemoryApps: [AppResourceUsage] = []

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

    // MARK: - GPU Data

    public private(set) var gpuData: GPUData = GPUData()
    public private(set) var gpuHistory: [Double] = []

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

    // MARK: - Private Properties

    /// Background queue for heavy data fetching work to avoid blocking the main thread
    private let monitoringQueue = DispatchQueue(label: "com.tonic.widgetdata.monitoring", qos: .utility)

    private var updateTimer: DispatchSourceTimer?
    private var lastNetworkStats: (upload: UInt64, download: UInt64, timestamp: Date)?
    private var lastDiskReadBytes: UInt64 = 0
    private var lastDiskWriteBytes: UInt64 = 0

    // Enhanced disk tracking for IOPS and activity rates
    private var lastDiskStats: DiskIOStatsSnapshot?
    private let diskStatsLock = NSLock()

    // CPU tracking for delta calculation
    private var previousCPUInfo: processor_info_array_t?
    private var previousNumCpuInfo: mach_msg_type_number_t = 0
    private var previousNumCPUs: UInt32 = 0
    private let cpuLock = NSLock()

    // Process list caching (to avoid frequent process spawning)
    private var cachedTopProcesses: [AppResourceUsage]?
    private var lastProcessFetchDate: Date?

    // Bluetooth reader (placeholder - BluetoothReader implementation needed)
    private var lastBluetoothUpdate: Date?
    private let bluetoothUpdateInterval: TimeInterval = 10.0  // Bluetooth updates less frequently

    // Network enhancement caching
    private var cachedPublicIP: PublicIPInfo?
    private var lastPublicIPFetch: Date?
    private var lastConnectivityCheck: Date?
    private var previousPingLatencies: [Double] = []
    private let publicIPCacheInterval: TimeInterval = 300  // 5 minutes
    private let connectivityCheckInterval: TimeInterval = 30  // 30 seconds

    // MARK: - Initialization

    private init() {
        // Register for reset network usage notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleResetTotalNetworkUsage),
            name: .resetTotalNetworkUsage,
            object: nil
        )
    }

    /// Handle reset total network usage notification
    @objc private func handleResetTotalNetworkUsage() {
        resetTotalNetworkUsage()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    /// Start monitoring system data
    public func startMonitoring() {
        guard !isMonitoring else {
            logger.warning("Already monitoring, skipping startMonitoring")
            logToFile("Already monitoring, skipping startMonitoring")
            return
        }
        isMonitoring = true
        let interval = WidgetPreferences.shared.updateInterval.timeInterval
        logger.info("🔵 Starting monitoring with interval: \(interval)s")
        logToFile("🔵 STARTING MONITORING with interval: \(interval)s")

        // Use background queue for data fetching to avoid blocking the main thread
        // The timer fires immediately (.now()) so no need for a separate initial call
        updateTimer = DispatchSource.makeTimerSource(queue: monitoringQueue)
        updateTimer?.schedule(deadline: .now() + 0.1, repeating: .seconds(Int(interval)))
        updateTimer?.setEventHandler { [weak self] in
            self?.updateAllData()
        }
        updateTimer?.resume()

        logger.info("🔵 Monitoring started, first update will occur in 0.1s on background queue")
        logToFile("🔵 Monitoring started on background queue")
    }

    /// Stop monitoring system data
    public func stopMonitoring() {
        isMonitoring = false
        updateTimer?.cancel()
        updateTimer = nil
    }

    /// Update the monitoring interval based on preferences
    public func updateInterval() {
        if isMonitoring {
            stopMonitoring()
            startMonitoring()
        }
    }

    // MARK: - Data Updates

    private var updateCounter = 0

    private func updateAllData() {
        logger.debug("🔄 updateAllData called")
        logToFile("🔄 updateAllData called")
        updateCPUData()
        updateMemoryData()
        updateDiskData()
        updateNetworkData()
        updateGPUData()
        updateBatteryData()
        updateSensorsData()
        updateBluetoothData()

        // Update top apps less frequently (every 3rd update - effectively every 3s)
        updateCounter += 1
        if updateCounter >= 3 {
            updateCounter = 0
            // Run on background queue to avoid blocking main thread
            Task.detached { [weak self] in
                await self?.updateTopCPUApps()
                await self?.updateTopMemoryApps()
            }
        }

        logger.info("✅ updateAllData complete - CPU: \(Int(self.cpuData.totalUsage))%, Memory: \(Int(self.memoryData.usagePercentage))%")
        logToFile("✅ updateAllData complete - CPU: \(Int(self.cpuData.totalUsage))%, Memory: \(Int(self.memoryData.usagePercentage))%, Disk: \(self.diskVolumes.first?.usagePercentage ?? 0)%")
    }

    // MARK: - CPU Monitoring

    private func updateCPUData() {
        // Fetch data on background thread
        let usage = getCPUUsage()
        let perCore = getPerCoreCPUUsage()

        // Get E/P core usage distribution (Apple Silicon only)
        let (eCores, pCores) = getEPCores(from: perCore)

        // Get enhanced CPU data
        let (frequency, eCoreFreq, pCoreFreq) = getCPUFrequency()
        let temperature = getCPUTemperature()
        let thermalLimit = getThermalLimit()
        let averageLoad = getAverageLoad()

        // Get System/User/Idle split
        let (systemUsage, userUsage, idleUsage) = getCPUUsageSplit()

        // Get system uptime
        let uptime = getSystemUptime()

        let newCPUData = CPUData(
            totalUsage: usage,
            perCoreUsage: perCore,
            eCoreUsage: eCores,
            pCoreUsage: pCores,
            frequency: frequency,
            eCoreFrequency: eCoreFreq,
            pCoreFrequency: pCoreFreq,
            temperature: temperature,
            thermalLimit: thermalLimit,
            averageLoad: averageLoad,
            systemUsage: systemUsage,
            userUsage: userUsage,
            idleUsage: idleUsage,
            uptime: uptime
        )

        // Dispatch property updates to main thread for @Observable
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.cpuData = newCPUData
            // Performance optimization: Use circular buffer for O(1) history add
            self.cpuCircularBuffer.add(usage)
            self.cpuHistory = self.cpuCircularBuffer.toArray()

            // Check notification thresholds
            NotificationManager.shared.checkThreshold(widgetType: .cpu, value: usage)
        }

        if isDebugLoggingEnabled {
            logger.debug("🔵 CPU updated: \(Int(usage))% (\(perCore.count) cores)")
            logToFile("🔵 CPU updated: \(Int(usage))% (\(perCore.count) cores), perCore: \(perCore.prefix(3))")
        }
    }

    private func getCPUUsage() -> Double {
        var _: UInt32 = 0
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

        guard result == KERN_SUCCESS else { return 0 }

        cpuLock.lock()
        defer { cpuLock.unlock() }

        var usage = 0.0

        if let prevInfo = previousCPUInfo, previousNumCPUs > 0 {
            let prevUser = prevInfo[Int(CPU_STATE_USER)]
            let prevSystem = prevInfo[Int(CPU_STATE_SYSTEM)]
            let prevIdle = prevInfo[Int(CPU_STATE_IDLE)]
            let prevNice = prevInfo[Int(CPU_STATE_NICE)]

            let currentUser = cpuInfo?[Int(CPU_STATE_USER)] ?? 0
            let currentSystem = cpuInfo?[Int(CPU_STATE_SYSTEM)] ?? 0
            let currentIdle = cpuInfo?[Int(CPU_STATE_IDLE)] ?? 0
            let currentNice = cpuInfo?[Int(CPU_STATE_NICE)] ?? 0

            let prevTotal = prevUser + prevSystem + prevIdle + prevNice
            let currentTotal = currentUser + currentSystem + currentIdle + currentNice

            let diffTotal = currentTotal - prevTotal
            let diffIdle = currentIdle - prevIdle

            if diffTotal > 0 {
                usage = (1.0 - Double(diffIdle) / Double(diffTotal)) * 100.0
            }
        }

        // Store current for next iteration
        if let prevInfo = previousCPUInfo {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: prevInfo)),
                vm_size_t(Int(previousNumCpuInfo) * MemoryLayout<integer_t>.size)
            )
        }

        previousCPUInfo = cpuInfo
        previousNumCpuInfo = numCpuInfo
        previousNumCPUs = numTotalCpu

        return max(0, min(100, usage))
    }

    private func getPerCoreCPUUsage() -> [Double] {
        var coreUsages: [Double] = []
        var _: UInt32 = 0
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
            return []
        }

        let CPU_STATE_MAX = 4
        for i in 0..<Int(numTotalCpu) {
            let base = i * Int(CPU_STATE_MAX)

            let user = UInt32(info[base + Int(CPU_STATE_USER)])
            let system = UInt32(info[base + Int(CPU_STATE_SYSTEM)])
            let idle = UInt32(info[base + Int(CPU_STATE_IDLE)])
            let nice = UInt32(info[base + Int(CPU_STATE_NICE)])

            let total = user + system + idle + nice
            let usage = total > 0 ? Double(user + system) / Double(total) * 100.0 : 0.0
            coreUsages.append(max(0, min(100, usage)))
        }

        return coreUsages
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
        guard let config = getCPUCoreConfig() else {
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
        #endif

        return (nil, nil, nil)
    }

    /// Get CPU temperature in Celsius
    private func getCPUTemperature() -> Double? {
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

    /// Get average load (1, 5, 15 minute averages)
    private func getAverageLoad() -> [Double]? {
        let task = Process()
        task.launchPath = "/usr/bin/uptime"

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8),
                  let line = output.split(separator: "\n").first else {
                return nil
            }

            // Parse load averages from uptime output
            // Format: "load averages: 0.5 0.3 0.1" or "load average: 0.50, 0.30, 0.10"
            if let range = line.range(of: "load average")?.upperBound ?? line.range(of: "load averages")?.upperBound {
                let loadString = String(line[range...])
                let components = loadString.components(separatedBy: CharacterSet(charactersIn: " ,"))
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .compactMap { Double($0.replacingOccurrences(of: ",", with: ".")) }

                if components.count >= 3 {
                    return Array(components.prefix(3))
                }
            }
        } catch {
            logger.warning("Failed to get average load: \(error.localizedDescription)")
        }

        return nil
    }

    /// Get CPU usage split (System, User, Idle percentages)
    private func getCPUUsageSplit() -> (system: Double, user: Double, idle: Double) {
        // Use host_processor_info to get CPU load info
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
            return (0, 0, 100)
        }

        // Sum up all the ticks from all cores
        var totalUserTicks: UInt64 = 0
        var totalSystemTicks: UInt64 = 0
        var totalIdleTicks: UInt64 = 0
        var totalNiceTicks: UInt64 = 0

        let CPU_STATE_MAX = 4
        for i in 0..<Int(numTotalCpu) {
            let base = i * Int(CPU_STATE_MAX)
            totalUserTicks += UInt64(info[base + Int(CPU_STATE_USER)])
            totalSystemTicks += UInt64(info[base + Int(CPU_STATE_SYSTEM)])
            totalIdleTicks += UInt64(info[base + Int(CPU_STATE_IDLE)])
            totalNiceTicks += UInt64(info[base + Int(CPU_STATE_NICE)])
        }

        let totalTicks = totalUserTicks + totalSystemTicks + totalIdleTicks + totalNiceTicks

        guard totalTicks > 0 else {
            return (0, 0, 100)
        }

        let user = (Double(totalUserTicks + totalNiceTicks) / Double(totalTicks)) * 100.0
        let system = (Double(totalSystemTicks) / Double(totalTicks)) * 100.0
        let idle = (Double(totalIdleTicks) / Double(totalTicks)) * 100.0

        return (system, user, idle)
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

        let pageSize = UInt64(vm_kernel_page_size)

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

        // Get top memory processes (async - we'll use cached value)
        let topProcesses = getTopMemoryProcesses()

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

    /// Get top memory-consuming processes using top command (Stats Master pattern)
    /// Uses cached result to avoid frequent process spawning
    /// Returns [AppResourceUsage] to integrate with existing UI components
    private func getTopMemoryProcesses(limit: Int = 8) -> [AppResourceUsage]? {
        // Use a simple cache to avoid spawning commands too frequently
        let now = Date()
        if let cachedDate = lastProcessFetchDate,
           now.timeIntervalSince(cachedDate) < 2.0,
           let cached = cachedTopProcesses {
            return cached
        }

        // Use top command following Stats Master pattern
        // top -l 1 -o mem -n <limit> -stats pid,command,mem
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/top")
        task.arguments = ["-l", "1", "-o", "mem", "-n", "\(limit)", "-stats", "pid,command,mem"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8),
                  task.terminationStatus == 0 else {
                return nil
            }

            let processes = parseTopOutput(output, limit: limit)
            lastProcessFetchDate = now
            cachedTopProcesses = processes
            return processes
        } catch {
            return nil
        }
    }

    /// Parse top command output to extract process info
    /// Stats Master pattern: matches lines like "12345* processname 100M"
    private func parseTopOutput(_ output: String, limit: Int) -> [AppResourceUsage]? {
        var processes: [AppResourceUsage] = []

        output.enumerateLines { line, stop in
            // Skip non-process lines (headers, stats, etc.)
            guard self.lineMatchesProcessPattern(line) else { return }

            if let process = self.parseProcessLine(line) {
                processes.append(process)
            }

            if processes.count >= limit {
                stop = true
            }
        }

        return processes.isEmpty ? nil : processes
    }

    /// Check if line matches the process output pattern
    /// Pattern: starts with digits (PID), ends with memory size (digits followed by K/M/G)
    private func lineMatchesProcessPattern(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }

        // Check if line starts with a number (PID)
        guard let firstChar = trimmed.first, firstChar.isNumber else { return false }

        // Check if line ends with memory size pattern (digits + optional suffix)
        let pattern = "\\d+[KMG]?\\+?\\-?\\s*$"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: trimmed.utf16.count)
            return regex.firstMatch(in: trimmed, options: [], range: range) != nil
        }

        return false
    }

    /// Parse a single process line from top output
    /// Format: "PID[*] COMMAND MEM" where MEM is like "100M", "1G", "500K"
    private func parseProcessLine(_ line: String) -> AppResourceUsage? {
        var str = line.trimmingCharacters(in: .whitespaces)

        // Extract PID (first numeric sequence)
        guard let pidMatch = str.range(of: "^\\d+", options: .regularExpression) else { return nil }
        let pidString = String(str[pidMatch])
        guard let pid = Int32(pidString) else { return nil }

        // Remove PID and any asterisk marker
        str = String(str[pidMatch.upperBound...]).trimmingCharacters(in: .whitespaces)
        if str.hasPrefix("*") {
            str = String(str.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        // Split remaining into parts
        var parts = str.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2 else { return nil }

        // Last part is memory usage
        let memString = String(parts.removeLast())

        // Remaining parts form the command name
        let command = parts.joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " +", with: "", options: .regularExpression)
            .replacingOccurrences(of: " -", with: "", options: .regularExpression)

        // Parse memory value (convert to bytes)
        let memoryBytes = parseMemoryString(memString)

        // Try to get app name from NSRunningApplication
        var name = command
        if let app = NSRunningApplication(processIdentifier: pid),
           let appName = app.localizedName {
            name = appName
        }

        // Try to get app icon
        let appIcon = getAppIconForProcess(pid: pid, name: name)
        let bundleId = getBundleIdentifier(for: name)

        return AppResourceUsage(
            name: name.isEmpty ? "Unknown" : name,
            bundleIdentifier: bundleId,
            icon: appIcon,
            cpuUsage: 0,
            memoryBytes: memoryBytes
        )
    }

    /// Parse memory string like "100M", "1G", "500K" to bytes
    private func parseMemoryString(_ str: String) -> UInt64 {
        let cleaned = str.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "+", with: "")
            .replacingOccurrences(of: "-", with: "")

        guard !cleaned.isEmpty else { return 0 }

        // Get last character and check if it's a unit suffix
        guard let lastCharacter = cleaned.last else { return 0 }
        let lastChar = lastCharacter.uppercased()

        // Determine if last character is numeric or a unit suffix
        let hasUnitSuffix = !lastCharacter.isNumber
        let numericString: String
        if hasUnitSuffix {
            numericString = String(cleaned.dropLast())
        } else {
            numericString = cleaned
        }

        guard let value = Double(numericString) else { return 0 }

        if hasUnitSuffix {
            switch lastChar {
            case "G":
                return UInt64(value * 1024 * 1024 * 1024)
            case "M":
                return UInt64(value * 1024 * 1024)
            case "K":
                return UInt64(value * 1024)
            default:
                // Unknown suffix, assume megabytes
                return UInt64(value * 1024 * 1024)
            }
        } else {
            // No suffix, assume megabytes (top default)
            return UInt64(value * 1024 * 1024)
        }
    }

    /// Get app icon for a process by PID
    private func getAppIconForProcess(pid: Int32, name: String) -> NSImage? {
        // Try to get the app's bundle from the process
        var pathBuffer = [Int8](repeating: 0, count: Int(MAXPATHLEN))
        let result = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))

        guard result > 0,
              let path = String(cString: pathBuffer) as String? else {
            return nil
        }

        // Check if this is an app bundle
        if path.contains(".app/") {
            if let appPath = path.components(separatedBy: ".app/").first?.appending(".app"),
               let bundle = Bundle(path: appPath) {
                // Try to get the app icon from Info.plist
                if let iconFile = bundle.infoDictionary?["CFBundleIconFile"] as? String,
                   let iconPath = bundle.path(forResource: iconFile.replacingOccurrences(of: ".icns", with: ""), ofType: "icns") {
                    return NSImage(contentsOfFile: iconPath)
                }
            }
        }

        return nil
    }

    /// Get bundle identifier for a process name
    private func getBundleIdentifier(for name: String) -> String? {
        // Common apps bundle identifiers
        let knownApps: [String: String] = [
            "Safari": "com.apple.Safari",
            "Finder": "com.apple.finder",
            "Activity Monitor": "com.apple.ActivityMonitor",
            "Calendar": "com.apple.iCal",
            "Mail": "com.apple.Mail",
            "Messages": "com.apple.iChat",
            "Music": "com.apple.Music",
            "Photos": "com.apple.Photos",
            "Notes": "com.apple.Notes",
            "Reminders": "com.apple.Reminders",
            "Terminal": "com.apple.Terminal",
            "Xcode": "com.apple.dt.Xcode",
            "Firefox": "org.mozilla.firefox",
            "Chrome": "com.google.Chrome",
            "Chrome Renderer": "com.google.Chrome",
            "Chrome Helper": "com.google.Chrome.helper",
            "Slack": "com.tinyspeck.slackmacgap",
            "Discord": "com.hnc.Discord",
            "Zoom": "us.zoom.xos",
            "Visual Studio Code": "com.microsoft.VSCode",
            "Atom": "com.github.atom",
            "Sublime Text": "com.sublimetext.3",
            "iTunes": "com.apple.iTunes",
            "TV": "com.apple.TV",
            "News": "com.apple.News",
            "FaceTime": "com.apple.FaceTime"
        ]

        return knownApps[name]
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

        // Get SMART data for the boot volume (typically NVMe on modern Macs)
        let bootVolumeSMART = getNVMeSMARTData()

        // Get top disk I/O processes
        let topDiskProcesses = getTopDiskProcesses()

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

                // Track read/write rate history for PerDiskContainer charts
                // Use MB/s for history tracking (normalized values)
                let readMBps = (primaryVolume.readBytesPerSecond ?? 0) / (1024 * 1024)
                let writeMBps = (primaryVolume.writeBytesPerSecond ?? 0) / (1024 * 1024)
                self.diskReadCircularBuffer.add(readMBps)
                self.diskWriteCircularBuffer.add(writeMBps)
                self.diskReadHistory = self.diskReadCircularBuffer.toArray()
                self.diskWriteHistory = self.diskWriteCircularBuffer.toArray()

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

        var nvmeService: io_service_t = IOIteratorNext(iterator)
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

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard task.terminationStatus == 0,
                  let output = String(data: data, encoding: .utf8) else {
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

    /// Get top processes by disk I/O usage
    /// Uses proc_pid_rusage to get per-process disk statistics
    private func getTopDiskProcesses(limit: Int = 8) -> [ProcessUsage]? {
        var processes: [ProcessUsage] = []

        // Get list of all PIDs
        var pids: [Int32] = []
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-ax", "-o", "pid"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return nil
            }

            // Parse PIDs (skip header)
            for line in output.components(separatedBy: "\n").dropFirst() {
                guard let pid = Int32(line.trimmingCharacters(in: .whitespaces)), pid > 0 else {
                    continue
                }
                pids.append(pid)
            }
        } catch {
            return nil
        }

        // Get disk I/O stats for each PID using proc_pid_rusage
        for pid in pids {
            var rusage = rusage_info_v2()
            let result = proc_pid_rusage(pid, RUSAGE_INFO_V2, &rusage)

            guard result == 0 else {
                continue
            }

            // Only include processes with actual disk I/O
            guard rusage.ri_diskio_bytesread > 0 || rusage.ri_diskio_byteswritten > 0 else {
                continue
            }

            // Get process name
            var pathBuffer = [Int8](repeating: 0, count: Int(MAXPATHLEN))
            let pathResult = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))

            guard pathResult > 0,
                  let path = String(cString: pathBuffer) as String? else {
                continue
            }

            let processName = (path as NSString).lastPathComponent

            // Get icon if possible
            let icon = getAppIconForProcess(pid: pid, name: processName)

            processes.append(ProcessUsage(
                id: pid,
                name: processName,
                iconData: nil, // Will be set later if needed
                cpuUsage: nil,
                memoryUsage: nil,
                diskReadBytes: rusage.ri_diskio_bytesread,
                diskWriteBytes: rusage.ri_diskio_byteswritten
            ))
        }

        // Sort by total disk I/O (read + write)
        processes.sort { (p1, p2) -> Bool in
            let p1Total = (p1.diskReadBytes ?? 0) + (p1.diskWriteBytes ?? 0)
            let p2Total = (p2.diskReadBytes ?? 0) + (p2.diskWriteBytes ?? 0)
            return p1Total > p2Total
        }

        // Take top N processes and add icons
        let topProcesses = Array(processes.prefix(limit))
        return topProcesses.map { process in
            let icon = getAppIconForProcess(pid: process.id, name: process.name)
            return process.withIcon(icon)
        }
    }

    // MARK: - Network Monitoring

    private struct NetworkStats {
        let bytesIn: UInt64
        let bytesOut: UInt64
    }

    private func updateNetworkData() {
        let stats = getNetworkStats()
        let now = Date()

        var uploadRate: Double = 0
        var downloadRate: Double = 0
        var isConnected = true

        if let last = lastNetworkStats {
            let timeDelta = now.timeIntervalSince(last.timestamp)

            if timeDelta > 0 {
                uploadRate = Double(stats.bytesOut - last.upload) / timeDelta
                downloadRate = Double(stats.bytesIn - last.download) / timeDelta
            }

            isConnected = (stats.bytesIn != last.download || stats.bytesOut != last.upload) || timeDelta < 5.0
        }

        lastNetworkStats = (upload: stats.bytesOut, download: stats.bytesIn, timestamp: now)

        // Get connection info
        let connectionType = getConnectionType()
        let ssid = getWiFiSSID()
        let ipAddress = getLocalIPAddress()

        // Get enhanced network data
        let wifiDetails = getWiFiDetails()
        let publicIP = getPublicIP()
        let connectivity = getConnectivityInfo()
        let topProcesses = getTopNetworkProcesses()

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
            topProcesses: topProcesses
        )

        // Dispatch property updates to main thread for @Observable
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.networkData = newNetworkData

            // Performance optimization: Use circular buffers for O(1) history add
            self.networkUploadCircularBuffer.add(uploadRate / 1024) // KB/s
            self.networkDownloadCircularBuffer.add(downloadRate / 1024)
            self.networkUploadHistory = self.networkUploadCircularBuffer.toArray()
            self.networkDownloadHistory = self.networkDownloadCircularBuffer.toArray()

            // Update cumulative totals (for Details section)
            self.totalUploadBytes += Int64(max(0, uploadRate))
            self.totalDownloadBytes += Int64(max(0, downloadRate))

            // Update connectivity history (for grid visualization)
            self.connectivityHistory.append(isConnected)
            if self.connectivityHistory.count > 90 {
                self.connectivityHistory.removeFirst()
            }

            // Check notification thresholds for network speed (total in MB/s)
            let totalSpeedMBps = (uploadRate + downloadRate) / 1_000_000
            NotificationManager.shared.checkThreshold(widgetType: .network, value: totalSpeedMBps)
        }
    }

    private func getNetworkStats() -> NetworkStats {
        var totalBytesIn: UInt64 = 0
        var totalBytesOut: UInt64 = 0

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
                    totalBytesIn += ifm.ifm_data.ifi_ibytes
                    totalBytesOut += ifm.ifm_data.ifi_obytes
                }

                offset += Int(ifm.ifm_msglen)
            }
        }

        return NetworkStats(bytesIn: totalBytesIn, bytesOut: totalBytesOut)
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
                        address = String(cString: hostname)
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

        // Get channel information
        var channel = 0
        if let channelInfo = interface.wlanChannel() {
            channel = channelInfo.channelNumber
            _ = channelInfo.channelBand  // Available for future use
        }

        // Get security type
        let security = getSecurityType(from: interface)

        // Get BSSID
        let bssid = interface.bssid() ?? "Unknown"

        return WiFiDetails(
            ssid: ssid,
            rssi: rssi,
            channel: channel,
            security: security,
            bssid: bssid
        )
    }

    /// Get security type from WiFi interface
    private func getSecurityType(from interface: CWInterface) -> String {
        // CoreWLAN security detection via system_profiler
        // This is the most reliable method without requiring additional entitlements
        return getSecurityTypeFromSystemProfiler()
    }

    /// Get security type from system_profiler (fallback)
    private func getSecurityTypeFromSystemProfiler() -> String {
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
                return "WPA3"
            } else if output.contains("WPA2") {
                return "WPA2"
            } else if output.contains("WPA") {
                return "WPA"
            } else if output.contains("WEP") {
                return "WEP"
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

    /// Fetch public IP from external APIs with fallback
    private func fetchPublicIPFromAPI() async -> PublicIPInfo? {
        // Try multiple APIs for reliability
        let apis: [String] = [
            "https://api.ipify.org?format=text",           // Simple IP
            "https://icanhazip.com",                        // Simple IP
            "https://ifconfig.me/ip",                       // Simple IP
        ]

        for api in apis {
            if let ip = await fetchIPFrom(url: api) {
                // For simple IP APIs, we don't get geo info
                return PublicIPInfo(ipAddress: ip.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        return nil
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

        // Only check connectivity every 30 seconds to avoid excessive pings
        if let lastCheck = lastConnectivityCheck,
           now.timeIntervalSince(lastCheck) < connectivityCheckInterval {
            return nil  // Return nil to use cached value from UI
        }

        lastConnectivityCheck = now

        // Perform ping test to 8.8.8.8 (Google DNS)
        let pingResults = performPingTest(host: "8.8.8.8", count: 5)

        guard let avgLatency = pingResults.average, !pingResults.latencies.isEmpty else {
            return ConnectivityInfo(latency: 0, jitter: 0, isReachable: false)
        }

        // Calculate jitter (standard deviation of latencies)
        let jitter = calculateJitter(latencies: pingResults.latencies)

        return ConnectivityInfo(
            latency: avgLatency,
            jitter: jitter,
            isReachable: pingResults.isReachable
        )
    }

    /// Ping test result structure
    private struct PingResult {
        let latencies: [Double]
        let isReachable: Bool
        let average: Double?
    }

    /// Perform ICMP ping test to a host
    private func performPingTest(host: String, count: Int) -> PingResult {
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

        do {
            try task.run()
            task.waitUntilExit()

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
            logger.warning("Ping test failed: \(error.localizedDescription)")
            return PingResult(latencies: [], isReachable: false, average: nil)
        }
    }

    /// Calculate jitter (standard deviation of latencies)
    private func calculateJitter(latencies: [Double]) -> Double {
        guard latencies.count > 1 else { return 0 }

        let avg = latencies.reduce(0, +) / Double(latencies.count)
        let variance = latencies.map { pow($0 - avg, 2) }.reduce(0, +) / Double(latencies.count)
        return sqrt(variance)
    }

    /// Get top processes by network usage
    private func getTopNetworkProcesses(limit: Int = 8) -> [ProcessNetworkUsage]? {
        // Use nettop command to get network usage per process
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        task.arguments = [
            "-P",           // Parseable output
            "-L", "1",      // Single sample
            "-n",           // No DNS resolution
            "-k", "time,interface,state,rx_dupe,rx_ooo,re-tx,rtt_avg,rcvsize,rcvsize_max,tcpi_win_mrcv,tcpi_win_snd,tcpi_rcv_wnd,tcpi_snd_wnd,snd_wnd,snd_wnd_max,tcpi_snd_bwnd,tcpi_rttcur,tcpi_rttcur,srtt,srtt_var,rtt_var,rtt_min,rtt_max,rtt_cnt,rtt_tot,rtt_tot_sec,rx_win,tx_win,tx_win_max,tx_win_una,tx_win_una_max,tx_win_nxt,tx_win_nxt_max,tx_win_cnt,tx_win_cnt_max,tx_win_tot,tx_win_tot_max,tx_win_sec,tx_win_sec_max,tx_win_usec,tx_win_usec_max,tx_win_usec_tot,tx_win_usec_tot_max,tcpi_rcv_oopack,tcpi_rcv_ovpack,tcpi_snd_zerowin,tcpi_rcv_zerowin,tcpi_snd_dupack,tcpi_snd_zerowin_probe,tcpi_rcv_zerowin_probe,tcpi_rexmt_lim,tcpi_rexmt_cnt,tcpi_rexmt_tot,tcpi_rexmt_tot_sec,tcpi_pmtu,tcpi_snd_bwnd_1,tcpi_snd_bwnd_2,tcpi_snd_bwnd_3,tcpi_snd_bwnd_4,tcpi_snd_bwnd_5,tcpi_snd_bwnd_6,tcpi_snd_bwnd_7,tcpi_snd_bwnd_8,tcpi_snd_bwnd_9,tcpi_snd_bwnd_10,tcpi_snd_bwnd_11,tcpi_snd_bwnd_12,tcpi_snd_bwnd_13,tcpi_snd_bwnd_14,tcpi_snd_bwnd_15,tcpi_snd_bwnd_16,tcpi_snd_bwnd_17,tcpi_snd_bwnd_18,tcpi_snd_bwnd_19,tcpi_snd_bwnd_20,tcpi_snd_bwnd_21,tcpi_snd_bwnd_22,tcpi_snd_bwnd_23,tcpi_snd_bwnd_24,tcpi_snd_bwnd_25,tcpi_snd_bwnd_26,tcpi_snd_bwnd_27,tcpi_snd_bwnd_28,tcpi_snd_bwnd_29,tcpi_snd_bwnd_30,tcpi_snd_bwnd_31,tcpi_snd_bwnd_32,tcpi_snd_bwnd_33,tcpi_snd_bwnd_34,tcpi_snd_bwnd_35,tcpi_snd_bwnd_36,tcpi_snd_bwnd_37,tcpi_snd_bwnd_38,tcpi_snd_bwnd_39,tcpi_snd_bwnd_40,tcpi_snd_bwnd_41,tcpi_snd_bwnd_42,tcpi_snd_bwnd_43,tcpi_snd_bwnd_44,tcpi_snd_bwnd_45,tcpi_snd_bwnd_46,tcpi_snd_bwnd_47,tcpi_snd_bwnd_48,tcpi_snd_bwnd_49,tcpi_snd_bwnd_50,tcpi_snd_bwnd_51,tcpi_snd_bwnd_52,tcpi_snd_bwnd_53,tcpi_snd_bwnd_54,tcpi_snd_bwnd_55,tcpi_snd_bwnd_56,tcpi_snd_bwnd_57,tcpi_snd_bwnd_58,tcpi_snd_bwnd_59,tcpi_snd_bwnd_60,tcpi_snd_bwnd_61,tcpi_snd_bwnd_62,tcpi_snd_bwnd_63,tcpi_snd_bwnd_64,tcpi_snd_bwnd_65,tcpi_snd_bwnd_66,tcpi_snd_bwnd_67,tcpi_snd_bwnd_68,tcpi_snd_bwnd_69,tcpi_snd_bwnd_70,tcpi_snd_bwnd_71,tcpi_snd_bwnd_72,tcpi_snd_bwnd_73,tcpi_snd_bwnd_74,tcpi_snd_bwnd_75,tcpi_snd_bwnd_76,tcpi_snd_bwnd_77,tcpi_snd_bwnd_78,tcpi_snd_bwnd_79,tcpi_snd_bwnd_80,tcpi_snd_bwnd_81,tcpi_snd_bwnd_82,tcpi_snd_bwnd_83,tcpi_snd_bwnd_84,tcpi_snd_bwnd_85,tcpi_snd_bwnd_86,tcpi_snd_bwnd_87,tcpi_snd_bwnd_88,tcpi_snd_bwnd_89,tcpi_snd_bwnd_90,tcpi_snd_bwnd_91,tcpi_snd_bwnd_92,tcpi_snd_bwnd_93,tcpi_snd_bwnd_94,tcpi_snd_bwnd_95,tcpi_snd_bwnd_96,tcpi_snd_bwnd_97,tcpi_snd_bwnd_98,tcpi_snd_bwnd_99,tcpi_snd_bwnd_100,tcpi_snd_bwnd_101,tcpi_snd_bwnd_102,tcpi_snd_bwnd_103,tcpi_snd_bwnd_104,tcpi_snd_bwnd_105,tcpi_snd_bwnd_106,tcpi_snd_bwnd_107,tcpi_snd_bwnd_108,tcpi_snd_bwnd_109,tcpi_snd_bwnd_110,tcpi_snd_bwnd_111,tcpi_snd_bwnd_112,tcpi_snd_bwnd_113,tcpi_snd_bwnd_114,tcpi_snd_bwnd_115,tcpi_snd_bwnd_116,tcpi_snd_bwnd_117,tcpi_snd_bwnd_118,tcpi_snd_bwnd_119,tcpi_snd_bwnd_120,tcpi_snd_bwnd_121,tcpi_snd_bwnd_122,tcpi_snd_bwnd_123,tcpi_snd_bwnd_124,tcpi_snd_bwnd_125,tcpi_snd_bwnd_126,tcpi_snd_bwnd_127,tcpi_snd_bwnd_128,tcpi_snd_bwnd_129,tcpi_snd_bwnd_130,tcpi_snd_bwnd_131,tcpi_snd_bwnd_132,tcpi_snd_bwnd_133,tcpi_snd_bwnd_134,tcpi_snd_bwnd_135,tcpi_snd_bwnd_136,tcpi_snd_bwnd_137,tcpi_snd_bwnd_138,tcpi_snd_bwnd_139,tcpi_snd_bwnd_140,tcpi_snd_bwnd_141,tcpi_snd_bwnd_142,tcpi_snd_bwnd_143,tcpi_snd_bwnd_144,tcpi_snd_bwnd_145,tcpi_snd_bwnd_146,tcpi_snd_bwnd_147,tcpi_snd_bwnd_148,tcpi_snd_bwnd_149,tcpi_snd_bwnd_150,tcpi_snd_bwnd_151,tcpi_snd_bwnd_152,tcpi_snd_bwnd_153,tcpi_snd_bwnd_154,tcpi_snd_bwnd_155,tcpi_snd_bwnd_156,tcpi_snd_bwnd_157,tcpi_snd_bwnd_158,tcpi_snd_bwnd_159,tcpi_snd_bwnd_160,tcpi_snd_bwnd_161,tcpi_snd_bwnd_162,tcpi_snd_bwnd_163,tcpi_snd_bwnd_164,tcpi_snd_bwnd_165,tcpi_snd_bwnd_166,tcpi_snd_bwnd_167,tcpi_snd_bwnd_168,tcpi_snd_bwnd_169,tcpi_snd_bwnd_170,tcpi_snd_bwnd_171,tcpi_snd_bwnd_172,tcpi_snd_bwnd_173,tcpi_snd_bwnd_174,tcpi_snd_bwnd_175,tcpi_snd_bwnd_176,tcpi_snd_bwnd_177,tcpi_snd_bwnd_178,tcpi_snd_bwnd_179,tcpi_snd_bwnd_180,tcpi_snd_bwnd_181,tcpi_snd_bwnd_182,tcpi_snd_bwnd_183,tcpi_snd_bwnd_184,tcpi_snd_bwnd_185,tcpi_snd_bwnd_186,tcpi_snd_bwnd_187,tcpi_snd_bwnd_188,tcpi_snd_bwnd_189,tcpi_snd_bwnd_190,tcpi_snd_bwnd_191,tcpi_snd_bwnd_192,tcpi_snd_bwnd_193,tcpi_snd_bwnd_194,tcpi_snd_bwnd_195,tcpi_snd_bwnd_196,tcpi_snd_bwnd_197,tcpi_snd_bwnd_198,tcpi_snd_bwnd_199,tcpi_snd_bwnd_200,tcpi_snd_bwnd_201,tcpi_snd_bwnd_202,tcpi_snd_bwnd_203,tcpi_snd_bwnd_204,tcpi_snd_bwnd_205,tcpi_snd_bwnd_206,tcpi_snd_bwnd_207,tcpi_snd_bwnd_208,tcpi_snd_bwnd_209,tcpi_snd_bwnd_210,tcpi_snd_bwnd_211,tcpi_snd_bwnd_212,tcpi_snd_bwnd_213,tcpi_snd_bwnd_214,tcpi_snd_bwnd_215,tcpi_snd_bwnd_216,tcpi_snd_bwnd_217,tcpi_snd_bwnd_218,tcpi_snd_bwnd_219,tcpi_snd_bwnd_220,tcpi_snd_bwnd_221,tcpi_snd_bwnd_222,tcpi_snd_bwnd_223,tcpi_snd_bwnd_224,tcpi_snd_bwnd_225,tcpi_snd_bwnd_226,tcpi_snd_bwnd_227,tcpi_snd_bwnd_228,tcpi_snd_bwnd_229,tcpi_snd_bwnd_230,tcpi_snd_bwnd_231,tcpi_snd_bwnd_232,tcpi_snd_bwnd_233,tcpi_snd_bwnd_234,tcpi_snd_bwnd_235,tcpi_snd_bwnd_236,tcpi_snd_bwnd_237,tcpi_snd_bwnd_238,tcpi_snd_bwnd_239,tcpi_snd_bwnd_240,tcpi_snd_bwnd_241,tcpi_snd_bwnd_242,tcpi_snd_bwnd_243,tcpi_snd_bwnd_244,tcpi_snd_bwnd_245,tcpi_snd_bwnd_246,tcpi_snd_bwnd_247,tcpi_snd_bwnd_248,tcpi_snd_bwnd_249,tcpi_snd_bwnd_250,tcpi_snd_bwnd_251,tcpi_snd_bwnd_252,tcpi_snd_bwnd_253,tcpi_snd_bwnd_254,tcpi_snd_bwnd_255"
        ]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard task.terminationStatus == 0,
                  let output = String(data: data, encoding: .utf8) else {
                return parseNettopOutputAlternative()
            }

            return parseNettopOutput(output, limit: limit)
        } catch {
            logger.warning("nettop failed: \(error.localizedDescription)")
            return parseNettopOutputAlternative()
        }
    }

    /// Parse nettop output to extract process network usage
    private func parseNettopOutput(_ output: String, limit: Int) -> [ProcessNetworkUsage]? {
        var processes: [ProcessNetworkUsage] = []
        let lines = output.components(separatedBy: .newlines)

        // nettop parseable format has columns separated by commas
        // First line is header, skip it
        for line in lines.dropFirst() where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            guard processes.count < limit else { break }

            // Parse: command,pid,rx_bytes,tx_bytes,...
            let components = line.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard components.count >= 4,
                  let pid = Int(components[1]),
                  let rxBytes = UInt64(components[2]),
                  let txBytes = UInt64(components[3]) else {
                continue
            }

            let processName = components[0]

            processes.append(ProcessNetworkUsage(
                pid: pid,
                name: processName,
                uploadBytes: txBytes,
                downloadBytes: rxBytes
            ))
        }

        // Sort by total bytes
        processes.sort { $0.totalBytes > $1.totalBytes }

        return processes.isEmpty ? nil : Array(processes.prefix(limit))
    }

    /// Alternative method using lsof to get network connections by process
    private func parseNettopOutputAlternative() -> [ProcessNetworkUsage]? {
        // Use lsof to count network connections per process as a proxy
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-i", "-n", "-P", "-c", ""]
        task.arguments = ["-i", "-n", "-P"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard task.terminationStatus == 0,
                  let output = String(data: data, encoding: .utf8) else {
                return nil
            }

            // Count connections per process
            var processConnections: [String: (pid: Int, tx: UInt64, rx: UInt64)] = [:]
            let lines = output.components(separatedBy: .newlines)

            for line in lines.dropFirst() {  // Skip header
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 2,
                      let pid = Int(parts[1]) else { continue }

                let name = String(parts[0])
                if let existing = processConnections[name] {
                    processConnections[name] = (pid: existing.pid, tx: existing.tx + 1, rx: existing.rx + 1)
                } else {
                    processConnections[name] = (pid: pid, tx: 1, rx: 1)
                }
            }

            // Convert to ProcessNetworkUsage
            let processes = processConnections.map { name, data in
                ProcessNetworkUsage(pid: data.pid, name: name, uploadBytes: data.tx, downloadBytes: data.rx)
            }.sorted { $0.totalBytes > $1.totalBytes }.prefix(8)

            return Array(processes)
        } catch {
            return nil
        }
    }

    // MARK: - GPU Monitoring

    private func updateGPUData() {
        #if arch(arm64)
        // Apple Silicon GPU monitoring
        var usage: Double? = nil
        var usedMemory: UInt64? = nil
        var totalMemory: UInt64? = nil
        var temperature: Double? = nil

        // Get total unified memory available to GPU
        if let physMemory = getPhysicalMemory() {
            // On Apple Silicon, GPU can access all unified memory
            // Reserve some for system (typically 2-3GB)
            let gpuAccessibleMemory = physMemory - (2 * 1024 * 1024 * 1024) // Reserve 2GB
            totalMemory = gpuAccessibleMemory
        }

        // Try to get GPU activity from IORegistry
        // Apple AGX GPU registers under IOService:/AppleARMIODevice/AGX
        let gpuService = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOGPU"))
        if gpuService != 0 {
            // Try to read GPU stats
            if let properties = IORegistryEntryCreateCFProperty(gpuService, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
                // Parse GPU stats if available
                if let activity = properties["ActivityLevel"] as? Double {
                    usage = activity * 100
                }
            }
            IOObjectRelease(gpuService)
        }

        // Alternative: Try IOAccelerator
        if usage == nil {
            var iterator: io_iterator_t = 0
            if IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS {
                while true {
                    let service = IOIteratorNext(iterator)
                    guard service != 0 else { break }
                    // Check if this is an Apple GPU
                    if let name = IORegistryEntryCreateCFProperty(service, "IOName" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String,
                       name.contains("AGX") || name.contains("AppleGPU") {
                        // Found Apple Silicon GPU
                        // Try to get performance statistics
                        if let stats = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
                            if let activity = stats["DeviceUtilization"] as? Double {
                                usage = activity * 100
                            }
                        }
                    }
                    IOObjectRelease(service)
                }
                IOObjectRelease(iterator)
            }
        }

        // Try to get GPU temperature from IOPM (power management)
        if let thermals = getThermalInfo() {
            temperature = thermals.gpuTemperature
        }

        // Estimate GPU memory usage from system memory pressure
        // On unified memory, GPU + CPU share the same pool
        // GPU typically uses 5-15% when idle, up to 50%+ under load
        if let total = totalMemory {
            let memPercent = memoryData.usagePercentage
            // Estimate GPU memory based on activity and system memory pressure
            // This is an approximation since Apple doesn't expose exact GPU memory allocation
            let estimatedGPUMemoryPercent = usage ?? 10.0 // Default 10% idle
            usedMemory = UInt64(Double(total) * (estimatedGPUMemoryPercent / 100.0))
        }

        let newGPUData = GPUData(
            usagePercentage: usage,
            usedMemory: usedMemory,
            totalMemory: totalMemory,
            temperature: temperature,
            timestamp: Date()
        )
        // Dispatch property updates to main thread for @Observable
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.gpuData = newGPUData

            // Track history for line charts
            if let gpuUsage = usage {
                // Performance optimization: Use circular buffer for O(1) history add
                self.gpuCircularBuffer.add(gpuUsage)
                self.gpuHistory = self.gpuCircularBuffer.toArray()

                // Check notification thresholds
                NotificationManager.shared.checkThreshold(widgetType: .gpu, value: gpuUsage)
            }
        }
        #else
        // Intel Macs - GPU monitoring not supported (discrete GPU)
        // Return empty GPU data to indicate no GPU available
        let emptyGPUData = GPUData(timestamp: Date())
        DispatchQueue.main.async { [weak self] in
            self?.gpuData = emptyGPUData
        }
        #endif
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
        let thermalZones = [
            "TC0E", // CPU
            "TC0F", // CPU
            "TC0c", // CPU
            "TG0E", // GPU (if available)
            "TG0P"  // GPU
        ]

        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            if let properties = IORegistryEntryCreateCFProperty(service, kIOPropertyThermalInformationKey as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
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
                DispatchQueue.main.async { [weak self] in
                    self?.batteryData = noBatteryData
                }
                return
            }

            let currentState = info[kIOPSPowerSourceStateKey] as? String
            let isCharging = currentState == kIOPSACPowerValue
            let isCharged = info[kIOPSIsChargedKey] as? Bool ?? false

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
                chargingVoltage: chargingVoltage
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
            return
        }

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

    /// Get temperature sensors using IOKit
    private func getSMCTemperatures() -> [SensorReading] {
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

        return readings
    }

    /// Get power sensors
    private func getSMCPower() -> [SensorReading] {
        var readings: [SensorReading] = []

        #if arch(arm64)
        // Apple Silicon: Try IOReport for Energy Model
        // Note: This requires privileged access on some systems
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
        batteryHistory = batteryCircularBuffer.toArray()
        sensorsHistory = sensorsCircularBuffer.toArray()
        bluetoothHistory = bluetoothCircularBuffer.toArray()
    }

    /// Update top apps by CPU usage
    public func updateTopCPUApps() {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-axro", "pid,pcpu,rss,comm", "-c"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                topCPUApps = []
                return
            }

            var apps: [AppResourceUsage] = []
            let lines = output.components(separatedBy: "\n").dropFirst() // Skip header

            for line in lines where !line.isEmpty {
                let components = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                guard components.count >= 4,
                      let cpuUsage = Double(components[1]),
                      let memKB = UInt64(components[2]) else { continue }

                let name = components.dropFirst(3).joined(separator: " ")

                // Skip system processes with very low CPU
                guard cpuUsage >= 0.1 else { continue }

                // Try to get app icon
                let icon = getAppIcon(for: name)

                apps.append(AppResourceUsage(
                    name: name,
                    bundleIdentifier: nil,
                    icon: icon,
                    cpuUsage: cpuUsage,
                    memoryBytes: memKB * 1024
                ))
            }

            // Sort by CPU and take top 5
            topCPUApps = apps.sorted { $0.cpuUsage > $1.cpuUsage }.prefix(10).map { $0 }
        } catch {
            logger.warning("Failed to get top CPU apps: \(error.localizedDescription)")
            topCPUApps = []
        }
    }

    /// Update top apps by memory usage
    public func updateTopMemoryApps() {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-axro", "pid,rss,pcpu,comm", "-c"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                topMemoryApps = []
                return
            }

            var apps: [AppResourceUsage] = []
            let lines = output.components(separatedBy: "\n").dropFirst() // Skip header

            for line in lines where !line.isEmpty {
                let components = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                guard components.count >= 4,
                      let memKB = UInt64(components[1]),
                      let cpuUsage = Double(components[2]) else { continue }

                let name = components.dropFirst(3).joined(separator: " ")

                // Skip processes with very little memory (< 10MB)
                guard memKB >= 10 * 1024 else { continue }

                // Try to get app icon
                let icon = getAppIcon(for: name)

                apps.append(AppResourceUsage(
                    name: name,
                    bundleIdentifier: nil,
                    icon: icon,
                    cpuUsage: cpuUsage,
                    memoryBytes: memKB * 1024
                ))
            }

            // Sort by memory and take top 5
            topMemoryApps = apps.sorted { $0.memoryBytes > $1.memoryBytes }.prefix(10).map { $0 }
        } catch {
            logger.warning("Failed to get top memory apps: \(error.localizedDescription)")
            topMemoryApps = []
        }
    }

    /// Get app icon for a process name
    private func getAppIcon(for processName: String) -> NSImage? {
        // Try to find the app in /Applications
        let appName = processName.replacingOccurrences(of: " Helper", with: "")
            .replacingOccurrences(of: " Renderer", with: "")
        
        let possiblePaths = [
            "/Applications/\(appName).app",
            "/System/Applications/\(appName).app",
            "/Applications/Utilities/\(appName).app"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return NSWorkspace.shared.icon(forFile: path)
            }
        }

        // Try running apps
        for app in NSWorkspace.shared.runningApplications {
            if app.localizedName == processName || app.executableURL?.lastPathComponent == processName {
                return app.icon
            }
        }

        return nil
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
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let bluetoothDict = json["SPBluetoothDataType"] as? [String: Any] {

                // Parse connected devices
                if let controllerDict = bluetoothDict.first?.value as? [String: Any],
                   let connectedDevices = controllerDict["device_connected"] as? [[String: Any]] {
                    for deviceInfo in connectedDevices {
                        if let name = deviceInfo["device_name"] as? String {
                            let battery = deviceInfo["device_batteryLevel"] as? Int
                            devices.append(BluetoothDevice(
                                name: name,
                                deviceType: .unknown,
                                isConnected: true,
                                isPaired: true,
                                primaryBatteryLevel: battery
                            ))
                        }
                    }
                }

                // Also check for device_title for devices that are "connected" but might be in a different format
                if let controllerDict = bluetoothDict.first?.value as? [String: Any],
                   let allDevices = controllerDict["device_title"] as? [[String: Any]] {
                    for deviceInfo in allDevices {
                        if let name = deviceInfo["device_name"] as? String,
                           let connectionStatus = deviceInfo["device_connectionStatus"] as? String,
                           connectionStatus.contains("Connected") {
                            let battery = deviceInfo["device_batteryLevel"] as? Int
                            devices.append(BluetoothDevice(
                                name: name,
                                deviceType: .unknown,
                                isConnected: true,
                                isPaired: true,
                                primaryBatteryLevel: battery
                            ))
                        }
                    }
                }
            }
        } catch {
            // Silently fail - Bluetooth not available or permission denied
        }

        return devices
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
