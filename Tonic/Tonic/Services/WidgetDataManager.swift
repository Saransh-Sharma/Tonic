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

public var RUSAGE_INFO_V2: Int32 { 5 }

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
    public let temperature: Double?        // CPU temperature in Celsius
    public let thermalLimit: Bool?         // Whether CPU is being thermally throttled
    public let averageLoad: [Double]?      // 1-minute, 5-minute, 15-minute load averages
    public let timestamp: Date

    public init(
        totalUsage: Double,
        perCoreUsage: [Double],
        eCoreUsage: [Double]? = nil,
        pCoreUsage: [Double]? = nil,
        frequency: Double? = nil,
        temperature: Double? = nil,
        thermalLimit: Bool? = nil,
        averageLoad: [Double]? = nil,
        timestamp: Date = Date()
    ) {
        self.totalUsage = totalUsage
        self.perCoreUsage = perCoreUsage
        self.eCoreUsage = eCoreUsage
        self.pCoreUsage = pCoreUsage
        self.frequency = frequency
        self.temperature = temperature
        self.thermalLimit = thermalLimit
        self.averageLoad = averageLoad
        self.timestamp = timestamp
    }

    /// Backward-compatible initializer for existing code
    public init(totalUsage: Double, perCoreUsage: [Double], timestamp: Date) {
        self.totalUsage = totalUsage
        self.perCoreUsage = perCoreUsage
        self.eCoreUsage = nil
        self.pCoreUsage = nil
        self.frequency = nil
        self.temperature = nil
        self.thermalLimit = nil
        self.averageLoad = nil
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
    public let topProcesses: [ProcessUsage]?       // Top disk I/O processes

    public init(name: String, path: String, usedBytes: UInt64, totalBytes: UInt64,
                isBootVolume: Bool = false, isInternal: Bool = true, isActive: Bool = false,
                smartData: NVMeSMARTData? = nil,
                readIOPS: Double? = nil, writeIOPS: Double? = nil,
                readBytesPerSecond: Double? = nil, writeBytesPerSecond: Double? = nil,
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

    public init(usagePercentage: Double? = nil, usedMemory: UInt64? = nil,
                totalMemory: UInt64? = nil, temperature: Double? = nil, timestamp: Date = Date()) {
        self.usagePercentage = usagePercentage
        self.usedMemory = usedMemory
        self.totalMemory = totalMemory
        self.temperature = temperature
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
    public let timestamp: Date

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
        self.timestamp = timestamp
    }
}

/// App resource usage
public struct AppResourceUsage: Sendable, Identifiable {
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

/// Data structure for system sensor readings
public struct SensorsData: Sendable, Codable, Equatable {
    public var temperatures: [SensorReading]
    public var fans: [FanReading]
    public var voltages: [SensorReading]
    
    public init(
        temperatures: [SensorReading] = [],
        fans: [FanReading] = [],
        voltages: [SensorReading] = []
    ) {
        self.temperatures = temperatures
        self.fans = fans
        self.voltages = voltages
    }
}

/// Individual sensor reading
public struct SensorReading: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let value: Double
    public let unit: String
    
    public init(id: String, name: String, value: Double, unit: String) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
    }
}

/// Fan sensor reading
public struct FanReading: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let rpm: Int
    public let maxRPM: Int?
    
    public init(id: String, name: String, rpm: Int, maxRPM: Int? = nil) {
        self.id = id
        self.name = name
        self.rpm = rpm
        self.maxRPM = maxRPM
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

    private func logToFile(_ message: String) {
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

    private static let maxHistoryPoints = 60

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

    // MARK: - Network Data

    public private(set) var networkData: NetworkData = NetworkData(
        uploadBytesPerSecond: 0, downloadBytesPerSecond: 0, isConnected: false
    )
    public private(set) var networkUploadHistory: [Double] = []
    public private(set) var networkDownloadHistory: [Double] = []

    // MARK: - GPU Data

    public private(set) var gpuData: GPUData = GPUData()

    // MARK: - Battery Data

    public private(set) var batteryData: BatteryData = BatteryData(isPresent: false)

    // MARK: - Sensors Data

    public private(set) var sensorsData: SensorsData = SensorsData()

    /// Weather data (optional, may be nil if location not available)
    public private(set) var weatherData: WeatherData?

    // MARK: - Monitoring State

    public private(set) var isMonitoring = false

    // MARK: - Private Properties

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

    // Network enhancement caching
    private var cachedPublicIP: PublicIPInfo?
    private var lastPublicIPFetch: Date?
    private var lastConnectivityCheck: Date?
    private var previousPingLatencies: [Double] = []
    private let publicIPCacheInterval: TimeInterval = 300  // 5 minutes
    private let connectivityCheckInterval: TimeInterval = 30  // 30 seconds

    // MARK: - Initialization

    private init() {}

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

        updateTimer = DispatchSource.makeTimerSource(queue: .main)
        updateTimer?.schedule(deadline: .now(), repeating: .seconds(Int(interval)))
        updateTimer?.setEventHandler { [weak self] in
            self?.updateAllData()
        }
        updateTimer?.resume()

        // Initial update
        logger.info("🔵 Triggering initial data update...")
        logToFile("🔵 Triggering initial data update...")
        updateAllData()
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
        let usage = getCPUUsage()
        let perCore = getPerCoreCPUUsage()

        // Get E/P core usage distribution (Apple Silicon only)
        let (eCores, pCores) = getEPCores(from: perCore)

        // Get enhanced CPU data
        let frequency = getCPUFrequency()
        let temperature = getCPUTemperature()
        let thermalLimit = getThermalLimit()
        let averageLoad = getAverageLoad()

        cpuData = CPUData(
            totalUsage: usage,
            perCoreUsage: perCore,
            eCoreUsage: eCores,
            pCoreUsage: pCores,
            frequency: frequency,
            temperature: temperature,
            thermalLimit: thermalLimit,
            averageLoad: averageLoad
        )

        // Update history
        addToHistory(&cpuHistory, value: usage, maxPoints: Self.maxHistoryPoints)

        logger.debug("🔵 CPU updated: \(Int(usage))% (\(perCore.count) cores)")
        logToFile("🔵 CPU updated: \(Int(usage))% (\(perCore.count) cores), perCore: \(perCore.prefix(3))")
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
    private func getCPUFrequency() -> Double? {
        #if arch(arm64)
        // For Apple Silicon, get base frequency from sysctl
        var frequency: Int64 = 0
        var size = MemoryLayout<Int64>.size

        if sysctlbyname("hw.cpufrequency", &frequency, &size, nil, 0) == 0 {
            return Double(frequency) / 1_000_000_000 // Convert Hz to GHz
        }

        // Fallback: try getting frequency for each cluster
        var eFreq: Int64 = 0
        var pFreq: Int64 = 0

        if sysctlbyname("hw.perflevel0.physicalcpu", &eFreq, &size, nil, 0) == 0,
           sysctlbyname("hw.perflevel1.physicalcpu", &pFreq, &size, nil, 0) == 0 {
            // Use P-core frequency as the representative frequency
            if sysctlbyname("hw.perflevel1.cpufrequency", &pFreq, &size, nil, 0) == 0 {
                return Double(pFreq) / 1_000_000_000
            }
        }
        #else
        // Intel Macs - get CPU frequency
        var frequency: Int64 = 0
        var size = MemoryLayout<Int64>.size

        if sysctlbyname("hw.cpufrequency", &frequency, &size, nil, 0) == 0 {
            return Double(frequency) / 1_000_000_000
        }
        #endif

        return nil
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
            memoryData = MemoryData(usedBytes: 0, totalBytes: 0, pressure: .normal)
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

        // Calculate memory pressure
        let free = UInt64(stats.free_count) * pageSize
        let total = UInt64(stats.wire_count + stats.active_count + stats.inactive_count + stats.free_count) * pageSize
        let freePercentage = total > 0 ? Double(free) / Double(total) : 0

        let pressure: MemoryPressure
        if freePercentage < 0.05 {
            pressure = .critical
        } else if freePercentage < 0.15 {
            pressure = .warning
        } else {
            pressure = .normal
        }

        // Calculate pressure value on 0-100 scale
        let pressureValue = getMemoryPressureValue(freePercentage: freePercentage, pressure: pressure)

        // Get top memory processes (async - we'll use cached value)
        let topProcesses = getTopMemoryProcesses()

        let swapBytes = swapUsed ?? 0

        memoryData = MemoryData(
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

        // Update history
        addToHistory(&memoryHistory, value: memoryData.usagePercentage, maxPoints: Self.maxHistoryPoints)
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

    /// Map memory pressure enum and free percentage to a 0-100 scale
    /// - 0-33: Normal (low pressure)
    /// - 34-66: Warning (moderate pressure)
    /// - 67-100: Critical (high pressure)
    private func getMemoryPressureValue(freePercentage: Double, pressure: MemoryPressure) -> Double {
        switch pressure {
        case .normal:
            // Map 0-15% free to 0-33 on pressure scale
            // Higher free = lower pressure
            let normalizedFree = max(0.05, min(0.15, freePercentage))
            return ((0.15 - normalizedFree) / 0.10) * 33.0
        case .warning:
            // Map 5-15% free to 34-66 on pressure scale
            let normalizedFree = max(0.05, min(0.15, freePercentage))
            return ((0.15 - normalizedFree) / 0.10) * 32.0 + 34.0
        case .critical:
            // Map 0-5% free to 67-100 on pressure scale
            let normalizedFree = max(0.0, min(0.05, freePercentage))
            return ((0.05 - normalizedFree) / 0.05) * 33.0 + 67.0
        }
    }

    /// Get top memory-consuming processes
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

        // Use ps command to get process memory info (more reliable than top/libproc)
        // ps format: pid, command (truncated), rss (resident set size in KB)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = [
            "-arc",     // all processes, nice output in user-friendly format, command with args
            "-o", "pid=,comm=,rss="  // Output: PID, command, RSS in KB
        ]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8),
                  task.terminationStatus == 0 else {
                return nil
            }

            let processes = parsePSOutput(output, limit: limit)
            lastProcessFetchDate = now
            cachedTopProcesses = processes
            return processes
        } catch {
            return nil
        }
    }

    /// Parse ps command output to extract process info
    /// Expected format: "PID   COMMAND          RSS"
    private func parsePSOutput(_ output: String, limit: Int) -> [AppResourceUsage]? {
        var processes: [AppResourceUsage] = []
        let lines = output.components(separatedBy: .newlines)

        // Skip header and empty lines
        for line in lines.dropFirst() where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            guard processes.count < limit else { break }

            // Parse: PID, command, rss (columns separated by whitespace)
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 3,
                  let pid = Int32(parts[0]),
                  let rssKb = Double(parts[parts.count - 1]) else {
                continue
            }

            // The command might have spaces, so reconstruct it
            // Format: PID command... RSS
            let commandStart = line.firstIndex(of: " ") ?? line.endIndex
            let commandEnd = line.lastIndex(of: " ") ?? line.endIndex

            guard commandStart < commandEnd else { continue }

            let command = String(line[line.index(after: commandStart)..<commandEnd])
                .trimmingCharacters(in: .whitespaces)

            // RSS is in KB, convert to bytes
            let memoryBytes = UInt64(rssKb * 1024)

            // Try to get app icon for known bundle identifiers
            let appIcon = getAppIconForProcess(pid: pid, name: command)
            let bundleId = getBundleIdentifier(for: command)

            processes.append(AppResourceUsage(
                name: command.isEmpty ? "Unknown" : command,
                bundleIdentifier: bundleId,
                icon: appIcon,
                cpuUsage: 0,
                memoryBytes: memoryBytes
            ))
        }

        return processes.isEmpty ? nil : processes
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
        let (readIOPS, writeIOPS, readBps, writeBps) = getDiskIORates()

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
                    topProcesses: isBoot ? topDiskProcesses : nil,
                    timestamp: now
                ))
            }
        }

        // Sort: boot volume first, then by used bytes
        volumes.sort { $0.isBootVolume && !$1.isBootVolume || ($0.isBootVolume == $1.isBootVolume && $0.usedBytes > $1.usedBytes) }

        diskVolumes = volumes

        // Get disk I/O statistics using IOKit (for activity detection)
        let (readBytes, writeBytes) = getDiskIOStatistics()
        primaryDiskActivity = (readBytes != lastDiskReadBytes || writeBytes != lastDiskWriteBytes)
        lastDiskReadBytes = readBytes
        lastDiskWriteBytes = writeBytes
    }

    // MARK: - Enhanced Disk Readers

    /// Snapshot of disk I/O statistics for delta calculation
    private struct DiskIOStatsSnapshot {
        let readBytes: UInt64
        let writeBytes: UInt64
        let readOperations: UInt64
        let writeOperations: UInt64
        let timestamp: Date
    }

    /// Get disk I/O rates (IOPS and throughput) using delta calculation
    /// Returns: (readIOPS, writeIOPS, readBytesPerSecond, writeBytesPerSecond)
    private func getDiskIORates() -> (Double?, Double?, Double?, Double?) {
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
                timestamp: now
            )
            return (nil, nil, nil, nil)
        }

        let timeDelta = now.timeIntervalSince(previous.timestamp)
        guard timeDelta > 0 else {
            return (nil, nil, nil, nil)
        }

        let readBytesDelta = currentStats.readBytes - previous.readBytes
        let writeBytesDelta = currentStats.writeBytes - previous.writeBytes
        let readOpsDelta = currentStats.readOperations - previous.readOperations
        let writeOpsDelta = currentStats.writeOperations - previous.writeOperations

        let readIOPS = Double(readOpsDelta) / timeDelta
        let writeIOPS = Double(writeOpsDelta) / timeDelta
        let readBps = Double(readBytesDelta) / timeDelta
        let writeBps = Double(writeBytesDelta) / timeDelta

        // Update snapshot for next iteration
        lastDiskStats = DiskIOStatsSnapshot(
            readBytes: currentStats.readBytes,
            writeBytes: currentStats.writeBytes,
            readOperations: currentStats.readOperations,
            writeOperations: currentStats.writeOperations,
            timestamp: now
        )

        return (readIOPS, writeIOPS, readBps, writeBps)
    }

    /// Detailed disk I/O statistics including operation counts
    private struct DetailedDiskStats {
        let readBytes: UInt64
        let writeBytes: UInt64
        let readOperations: UInt64
        let writeOperations: UInt64
    }

    /// Get detailed disk I/O statistics from IORegistry
    private func getDetailedDiskIOStats() -> DetailedDiskStats {
        var totalReadBytes: UInt64 = 0
        var totalWriteBytes: UInt64 = 0
        var totalReadOps: UInt64 = 0
        var totalWriteOps: UInt64 = 0

        // Match IOKit services for block storage drivers
        let matchingDict = IOServiceMatching(kIOBlockStorageDriverClass)
        var serviceIterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &serviceIterator)
        guard result == KERN_SUCCESS else {
            return DetailedDiskStats(readBytes: 0, writeBytes: 0, readOperations: 0, writeOperations: 0)
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
            }
        }

        return DetailedDiskStats(
            readBytes: totalReadBytes,
            writeBytes: totalWriteBytes,
            readOperations: totalReadOps,
            writeOperations: totalWriteOps
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

        // Get enhanced network data
        let wifiDetails = getWiFiDetails()
        let publicIP = getPublicIP()
        let connectivity = getConnectivityInfo()
        let topProcesses = getTopNetworkProcesses()

        networkData = NetworkData(
            uploadBytesPerSecond: max(0, uploadRate),
            downloadBytesPerSecond: max(0, downloadRate),
            isConnected: isConnected,
            connectionType: connectionType,
            ssid: ssid,
            wifiDetails: wifiDetails,
            publicIP: publicIP,
            connectivity: connectivity,
            topProcesses: topProcesses
        )

        // Update history
        addToHistory(&networkUploadHistory, value: uploadRate / 1024, maxPoints: Self.maxHistoryPoints) // KB/s
        addToHistory(&networkDownloadHistory, value: downloadRate / 1024, maxPoints: Self.maxHistoryPoints)
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
            let interface = String(cString: current.pointee.ifa_name)
            let addrFamily = current.pointee.ifa_addr.pointee.sa_family

            // Check for active ethernet interfaces (en0, en1, etc.)
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                if interface.hasPrefix("en") && interface != "en0" {
                    // en0 is typically WiFi on macOS, other en* are ethernet
                    hasEthernet = true
                }
            }

            ptr = current.pointee.ifa_next
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

        gpuData = GPUData(
            usagePercentage: usage,
            usedMemory: usedMemory,
            totalMemory: totalMemory,
            temperature: temperature,
            timestamp: Date()
        )
        #else
        // Intel Macs - GPU monitoring not supported (discrete GPU)
        // Return empty GPU data to indicate no GPU available
        gpuData = GPUData(timestamp: Date())
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

        guard let powerSources = sources else {
            batteryData = BatteryData(isPresent: false)
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
                batteryData = BatteryData(isPresent: false)
                return
            }

            let currentState = info[kIOPSPowerSourceStateKey] as? String
            let isCharging = currentState == kIOPSACPowerValue
            let isCharged = info[kIOPSIsChargedKey] as? Bool ?? false

            let capacity = info[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maxCapacity = info[kIOPSMaxCapacityKey] as? Int ?? 100

            let timeToEmpty = info[kIOPSTimeToEmptyKey] as? Int

            // Battery health
            let designCapacity = info[kIOPSDesignCapacityKey] as? Int
            let health: BatteryHealth
            if let design = designCapacity, design > 0 {
                let healthPercent = Double(maxCapacity) / Double(design) * 100
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

            batteryData = BatteryData(
                isPresent: true,
                isCharging: isCharging,
                isCharged: isCharged,
                chargePercentage: Double(capacity),
                estimatedMinutesRemaining: timeToEmpty,
                health: health
            )
            return
        }

        batteryData = BatteryData(isPresent: false)
    }

    // MARK: - Sensors Monitoring

    private func updateSensorsData() {
        // TODO: Implement SensorsReader to fetch temperature and fan data
        // For now, use empty sensors data
        sensorsData = SensorsData()
    }

    // MARK: - Helper Methods

    private func addToHistory(_ array: inout [Double], value: Double, maxPoints: Int) {
        array.append(value)
        if array.count > maxPoints {
            array.removeFirst()
        }
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
}

// MARK: - C Types

private struct xsw_usage {
    var xsu_total: UInt64
    var xsu_used: UInt64
    var xsu_pagesize: UInt32
    var xsu_encrypted: UInt32
}
