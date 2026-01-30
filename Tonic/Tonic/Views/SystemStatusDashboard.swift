//
//  SystemStatusDashboard.swift
//  Tonic
//
//  Real-time system status dashboard with CPU, memory, disk, network, battery, and uptime
//  Redesigned with MetricRow components in a vertical list layout
//

import SwiftUI
import IOKit.ps
import Darwin.Mach

// MARK: - System Status Models

struct SystemStatus: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date

    // CPU
    let cpuUsage: Double // 0-100
    let activeProcesses: Int
    let totalThreads: Int

    // Memory
    let usedMemory: UInt64
    let totalMemory: UInt64
    let memoryPressure: MemoryPressure

    // Disk
    let diskUsage: [DiskVolume]

    // Network
    let networkBytesIn: UInt64
    let networkBytesOut: UInt64

    // Battery
    let batteryInfo: BatteryInfo?

    // Uptime
    let systemUptime: TimeInterval

    var memoryUsagePercentage: Double {
        guard totalMemory > 0 else { return 0 }
        return Double(usedMemory) / Double(totalMemory) * 100
    }

    static func == (lhs: SystemStatus, rhs: SystemStatus) -> Bool {
        lhs.timestamp == rhs.timestamp
    }
}

struct DiskVolume: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let path: String
    let usedBytes: UInt64
    let totalBytes: UInt64
    let isBootVolume: Bool

    var usagePercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }

    var freeBytes: UInt64 {
        max(0, totalBytes - usedBytes)
    }
}

// MARK: - Battery Info

struct BatteryInfo: Equatable {
    let isPresent: Bool
    let isCharging: Bool
    let isCharged: Bool
    let chargePercentage: Double // 0-100
    let estimatedMinutesRemaining: Int?
    let batteryHealth: BatteryHealth

    var color: Color {
        if chargePercentage > 50 {
            return DesignTokens.Colors.progressLow
        } else if chargePercentage > 20 {
            return DesignTokens.Colors.progressMedium
        } else {
            return DesignTokens.Colors.progressHigh
        }
    }
}

// MARK: - System Monitor

@MainActor
class SystemMonitor: ObservableObject {
    @Published var currentStatus: SystemStatus?
    @Published var isMonitoring = false
    @Published var updateInterval: TimeInterval = 2.0

    // History for sparklines (last 30 data points)
    @Published var cpuHistory: [Double] = Array(repeating: 0, count: 30)
    @Published var memoryHistory: [Double] = Array(repeating: 0, count: 30)
    @Published var networkDownloadHistory: [Double] = Array(repeating: 0, count: 30)
    @Published var networkUploadHistory: [Double] = Array(repeating: 0, count: 30)
    @Published var diskHistory: [Double] = Array(repeating: 0, count: 30)

    private var timer: Timer?
    private var previousNetStats: NetworkStats?
    private var lastNetworkUpdate: Date?

    // CPU usage tracking
    private var previousCPUInfo: processor_info_array_t?
    private var previousNumCpuInfo: mach_msg_type_number_t = 0
    private var previousNumCPUs: UInt32 = 0
    private let cpuLock = NSLock()

    init() {
        startMonitoring()
    }

    deinit {
        timer?.invalidate()
        if let prevInfo = previousCPUInfo, previousNumCpuInfo > 0 {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: prevInfo)),
                vm_size_t(Int(previousNumCpuInfo) * MemoryLayout<Int>.size)
            )
        }
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        updateStatus()
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatus()
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
    }

    func setUpdateInterval(_ interval: TimeInterval) {
        updateInterval = interval
        if isMonitoring {
            stopMonitoring()
            startMonitoring()
        }
    }

    private func updateStatus() {
        let cpuUsage = getCPUUsage()
        let (usedMem, totalMem) = getMemoryUsage()
        let pressure = getMemoryPressure()
        let volumes = getDiskUsage()
        let battery = getBatteryInfo()
        let uptime = getSystemUptime()
        let activeProcs = getActiveProcessCount()

        // Calculate network rates
        let currentNetStats = getNetworkStats()
        var downloadRate: Double = 0
        var uploadRate: Double = 0

        if let prev = previousNetStats, let lastUpdate = lastNetworkUpdate {
            let timeDelta = Date().timeIntervalSince(lastUpdate)
            if timeDelta > 0 {
                downloadRate = Double(currentNetStats.bytesIn - prev.bytesIn) / timeDelta
                uploadRate = Double(currentNetStats.bytesOut - prev.bytesOut) / timeDelta
            }
        }

        previousNetStats = currentNetStats
        lastNetworkUpdate = Date()

        // Update history for sparklines
        cpuHistory.append(cpuUsage / 100.0)
        cpuHistory.removeFirst()

        let memUsage = totalMem > 0 ? Double(usedMem) / Double(totalMem) : 0
        memoryHistory.append(memUsage)
        memoryHistory.removeFirst()

        networkDownloadHistory.append(downloadRate / 1024) // KB/s
        networkDownloadHistory.removeFirst()
        networkUploadHistory.append(uploadRate / 1024) // KB/s
        networkUploadHistory.removeFirst()

        // Update disk history based on boot volume
        if let bootVolume = volumes.first(where: { $0.isBootVolume }) {
            diskHistory.append(bootVolume.usagePercentage / 100.0)
            diskHistory.removeFirst()
        }

        currentStatus = SystemStatus(
            timestamp: Date(),
            cpuUsage: cpuUsage,
            activeProcesses: activeProcs,
            totalThreads: getThreadCount(),
            usedMemory: usedMem,
            totalMemory: totalMem,
            memoryPressure: pressure,
            diskUsage: volumes,
            networkBytesIn: currentNetStats.bytesIn,
            networkBytesOut: currentNetStats.bytesOut,
            batteryInfo: battery,
            systemUptime: uptime
        )
    }

    // MARK: - CPU Monitoring

    private func getCPUUsage() -> Double {
        var numCPUs: UInt32 = 0
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

        if result != KERN_SUCCESS {
            return 0
        }

        cpuLock.lock()
        defer {
            cpuLock.unlock()
        }

        var usage = 0.0

        if let prevInfo = previousCPUInfo, previousNumCPUs > 0,
           let currentInfo = cpuInfo, numCpuInfo > 0 {
            let prevUser = prevInfo[Int(CPU_STATE_USER)]
            let prevSystem = prevInfo[Int(CPU_STATE_SYSTEM)]
            let prevIdle = prevInfo[Int(CPU_STATE_IDLE)]
            let prevNice = prevInfo[Int(CPU_STATE_NICE)]

            let currentUser = currentInfo[Int(CPU_STATE_USER)]
            let currentSystem = currentInfo[Int(CPU_STATE_SYSTEM)]
            let currentIdle = currentInfo[Int(CPU_STATE_IDLE)]
            let currentNice = currentInfo[Int(CPU_STATE_NICE)]

            let prevTotal = prevUser + prevSystem + prevIdle + prevNice
            let currentTotal = currentUser + currentSystem + currentIdle + currentNice

            let diffTotal = currentTotal - prevTotal
            let diffIdle = currentIdle - prevIdle

            if diffTotal > 0 {
                usage = (1.0 - Double(diffIdle) / Double(diffTotal)) * 100.0
            }
        }

        if let prevInfo = previousCPUInfo, previousNumCpuInfo > 0 {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: prevInfo)),
                vm_size_t(Int(previousNumCpuInfo) * MemoryLayout<Int>.size)
            )
        }

        previousCPUInfo = cpuInfo
        previousNumCpuInfo = numCpuInfo
        previousNumCPUs = numTotalCpu

        return max(0, min(100, usage))
    }

    private func getActiveProcessCount() -> Int {
        var count: mach_msg_type_number_t = 0
        var result = task_info(
            mach_task_self_,
            UInt32(TASK_BASIC_INFO),
            nil,
            &count
        )

        var info = task_basic_info()
        result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    UInt32(TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL]
        var mibLen: Int = mib.count
        var size = MemoryLayout<kinfo_proc>.stride
        var procList = [kinfo_proc](repeating: kinfo_proc(), count: 1024)

        sysctl(&mib, UInt32(mibLen), &procList, &size, nil, 0)

        return size / MemoryLayout<kinfo_proc>.stride
    }

    private func getThreadCount() -> Int {
        var count: mach_msg_type_number_t = 0
        var threads: thread_act_array_t?
        let result = task_threads(mach_task_self_, &threads, &count)

        if result == KERN_SUCCESS, let threads = threads {
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threads)), vm_size_t(Int(count) * MemoryLayout<thread_t>.size))
        }

        return Int(count)
    }

    // MARK: - Memory Monitoring

    private func getMemoryUsage() -> (UInt64, UInt64) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (0, 0)
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let used = (UInt64(stats.active_count) + UInt64(stats.wire_count)) * pageSize

        var memSize: Int = 0
        var memSizeLen = MemoryLayout<Int>.size
        sysctlbyname("hw.memsize", &memSize, &memSizeLen, nil, 0)

        return (used, UInt64(memSize))
    }

    private func getMemoryPressure() -> MemoryPressure {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return .normal
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let free = UInt64(stats.free_count) * pageSize
        let total = UInt64(stats.wire_count + stats.active_count + stats.inactive_count + stats.free_count) * pageSize

        let freePercentage = Double(free) / Double(total)

        if freePercentage < 0.05 {
            return .critical
        } else if freePercentage < 0.15 {
            return .warning
        }
        return .normal
    }

    // MARK: - Disk Monitoring

    private func getDiskUsage() -> [DiskVolume] {
        var volumes: [DiskVolume] = []

        let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeIsRootFileSystemKey]

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

                volumes.append(DiskVolume(
                    name: name,
                    path: url.path,
                    usedBytes: UInt64(used),
                    totalBytes: UInt64(total),
                    isBootVolume: isBoot
                ))
            }
        }

        return volumes.sorted { $0.isBootVolume && !$1.isBootVolume }
    }

    // MARK: - Network Monitoring

    struct NetworkStats {
        let bytesIn: UInt64
        let bytesOut: UInt64
    }

    private func getNetworkStats() -> NetworkStats {
        var totalBytesIn: UInt64 = 0
        var totalBytesOut: UInt64 = 0

        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len: Int = 0

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

        buffer.withUnsafeBytes { rawBuffer in
            var offset = 0
            while offset + MemoryLayout<if_msghdr2>.size <= len {
                let msgPtr = rawBuffer.baseAddress!.advanced(by: offset)
                let ifm = msgPtr.assumingMemoryBound(to: if_msghdr2.self).pointee

                guard ifm.ifm_msglen > 0 else { break }

                if Int32(ifm.ifm_type) == RTM_IFINFO2 {
                    totalBytesIn += ifm.ifm_data.ifi_ibytes
                    totalBytesOut += ifm.ifm_data.ifi_obytes
                }

                offset += Int(ifm.ifm_msglen)
            }
        }

        return NetworkStats(bytesIn: totalBytesIn, bytesOut: totalBytesOut)
    }

    // MARK: - Battery Monitoring

    private func getBatteryInfo() -> BatteryInfo? {
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFDictionary]

        guard let powerSources = sources else { return nil }

        for source in powerSources {
            let info = source as NSDictionary

            guard let type = info[kIOPSTypeKey] as? String,
                  type == kIOPSInternalBatteryType else {
                continue
            }

            let isPresent = info[kIOPSIsPresentKey] as? Bool ?? true
            guard isPresent else { return nil }

            let currentState = info[kIOPSPowerSourceStateKey] as? String
            let isCharging = currentState == kIOPSACPowerValue
            let isCharged = info[kIOPSIsChargedKey] as? Bool ?? false

            let capacity = info[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maxCapacity = info[kIOPSMaxCapacityKey] as? Int ?? 100

            let timeToEmpty = info[kIOPSTimeToEmptyKey] as? Int
            let estimatedMinutes = timeToEmpty ?? nil

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

            return BatteryInfo(
                isPresent: isPresent,
                isCharging: isCharging,
                isCharged: isCharged,
                chargePercentage: Double(capacity),
                estimatedMinutesRemaining: estimatedMinutes,
                batteryHealth: health
            )
        }

        return nil
    }

    // MARK: - Uptime

    private func getSystemUptime() -> TimeInterval {
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.size

        sysctlbyname("kern.boottime", &bootTime, &size, nil, 0)

        var currentTime = timeval()
        gettimeofday(&currentTime, nil)

        let bootTimestamp = Double(bootTime.tv_sec) + Double(bootTime.tv_usec) / 1_000_000.0
        let currentTimestamp = Double(currentTime.tv_sec) + Double(currentTime.tv_usec) / 1_000_000.0

        return currentTimestamp - bootTimestamp
    }
}

// MARK: - Main Dashboard View

struct SystemStatusDashboard: View {
    @StateObject private var monitor = SystemMonitor()
    @State private var selectedUpdateInterval: TimeInterval = 2.0

    private let updateIntervals: [(value: TimeInterval, label: String)] = [
        (1.0, "1s"),
        (2.0, "2s"),
        (5.0, "5s"),
        (10.0, "10s")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerView
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.top, DesignTokens.Spacing.lg)
                .padding(.bottom, DesignTokens.Spacing.md)

            Divider()
                .padding(.horizontal, DesignTokens.Spacing.lg)

            // Main content - List of MetricRows
            if let status = monitor.currentStatus {
                List {
                    // CPU Section
                    Section {
                        MetricRow(
                            icon: "cpu",
                            title: "CPU Usage",
                            value: "\(Int(status.cpuUsage))%",
                            iconColor: cpuColor(for: status.cpuUsage),
                            sparklineData: monitor.cpuHistory,
                            sparklineColor: cpuColor(for: status.cpuUsage)
                        )
                        .listRowInsets(EdgeInsets(top: DesignTokens.Spacing.xxs, leading: DesignTokens.Spacing.sm, bottom: DesignTokens.Spacing.xxs, trailing: DesignTokens.Spacing.sm))

                        MetricRow(
                            icon: "gearshape.2",
                            title: "Processes",
                            value: "\(status.activeProcesses)",
                            iconColor: DesignTokens.Colors.textSecondary
                        )
                        .listRowInsets(EdgeInsets(top: DesignTokens.Spacing.xxs, leading: DesignTokens.Spacing.sm, bottom: DesignTokens.Spacing.xxs, trailing: DesignTokens.Spacing.sm))

                        MetricRow(
                            icon: "bolt.horizontal",
                            title: "Threads",
                            value: "\(status.totalThreads)",
                            iconColor: DesignTokens.Colors.textSecondary
                        )
                        .listRowInsets(EdgeInsets(top: DesignTokens.Spacing.xxs, leading: DesignTokens.Spacing.sm, bottom: DesignTokens.Spacing.xxs, trailing: DesignTokens.Spacing.sm))
                    } header: {
                        sectionHeader(title: "Processor")
                    }

                    // Memory Section
                    Section {
                        MetricRow(
                            icon: "memorychip",
                            title: "Memory Usage",
                            value: "\(formatBytes(status.usedMemory)) / \(formatBytes(status.totalMemory))",
                            iconColor: memoryColor(for: status.memoryPressure),
                            sparklineData: monitor.memoryHistory,
                            sparklineColor: memoryColor(for: status.memoryPressure)
                        )
                        .listRowInsets(EdgeInsets(top: DesignTokens.Spacing.xxs, leading: DesignTokens.Spacing.sm, bottom: DesignTokens.Spacing.xxs, trailing: DesignTokens.Spacing.sm))

                        MetricRow(
                            icon: "gauge.with.dots.needle.bottom.50percent",
                            title: "Memory Pressure",
                            value: status.memoryPressure.rawValue,
                            iconColor: memoryColor(for: status.memoryPressure)
                        )
                        .listRowInsets(EdgeInsets(top: DesignTokens.Spacing.xxs, leading: DesignTokens.Spacing.sm, bottom: DesignTokens.Spacing.xxs, trailing: DesignTokens.Spacing.sm))
                    } header: {
                        sectionHeader(title: "Memory")
                    }

                    // Disk Section
                    Section {
                        ForEach(status.diskUsage) { volume in
                            MetricRow(
                                icon: volume.isBootVolume ? "internaldrive.fill" : "externaldrive",
                                title: volume.name + (volume.isBootVolume ? " (Boot)" : ""),
                                value: "\(formatBytes(volume.freeBytes)) free",
                                iconColor: diskColor(for: volume.usagePercentage),
                                sparklineData: volume.isBootVolume ? monitor.diskHistory : nil,
                                sparklineColor: diskColor(for: volume.usagePercentage)
                            )
                            .listRowInsets(EdgeInsets(top: DesignTokens.Spacing.xxs, leading: DesignTokens.Spacing.sm, bottom: DesignTokens.Spacing.xxs, trailing: DesignTokens.Spacing.sm))
                        }
                    } header: {
                        sectionHeader(title: "Storage")
                    }

                    // Network Section
                    Section {
                        MetricRow(
                            icon: "arrow.down.circle",
                            title: "Download",
                            value: formatRate(monitor.networkDownloadHistory.last ?? 0),
                            iconColor: DesignTokens.Colors.success,
                            sparklineData: monitor.networkDownloadHistory,
                            sparklineColor: DesignTokens.Colors.success
                        )
                        .listRowInsets(EdgeInsets(top: DesignTokens.Spacing.xxs, leading: DesignTokens.Spacing.sm, bottom: DesignTokens.Spacing.xxs, trailing: DesignTokens.Spacing.sm))

                        MetricRow(
                            icon: "arrow.up.circle",
                            title: "Upload",
                            value: formatRate(monitor.networkUploadHistory.last ?? 0),
                            iconColor: DesignTokens.Colors.info,
                            sparklineData: monitor.networkUploadHistory,
                            sparklineColor: DesignTokens.Colors.info
                        )
                        .listRowInsets(EdgeInsets(top: DesignTokens.Spacing.xxs, leading: DesignTokens.Spacing.sm, bottom: DesignTokens.Spacing.xxs, trailing: DesignTokens.Spacing.sm))

                        MetricRow(
                            icon: "arrow.down.doc",
                            title: "Total Downloaded",
                            value: formatBytes(status.networkBytesIn),
                            iconColor: DesignTokens.Colors.textSecondary
                        )
                        .listRowInsets(EdgeInsets(top: DesignTokens.Spacing.xxs, leading: DesignTokens.Spacing.sm, bottom: DesignTokens.Spacing.xxs, trailing: DesignTokens.Spacing.sm))

                        MetricRow(
                            icon: "arrow.up.doc",
                            title: "Total Uploaded",
                            value: formatBytes(status.networkBytesOut),
                            iconColor: DesignTokens.Colors.textSecondary
                        )
                        .listRowInsets(EdgeInsets(top: DesignTokens.Spacing.xxs, leading: DesignTokens.Spacing.sm, bottom: DesignTokens.Spacing.xxs, trailing: DesignTokens.Spacing.sm))
                    } header: {
                        sectionHeader(title: "Network")
                    }

                    // Battery Section (if available)
                    if let battery = status.batteryInfo {
                        Section {
                            MetricRow(
                                icon: battery.isCharging ? "battery.100.bolt" : batteryIcon(for: battery.chargePercentage),
                                title: "Battery Level",
                                value: "\(Int(battery.chargePercentage))%",
                                iconColor: battery.color
                            )
                            .listRowInsets(EdgeInsets(top: DesignTokens.Spacing.xxs, leading: DesignTokens.Spacing.sm, bottom: DesignTokens.Spacing.xxs, trailing: DesignTokens.Spacing.sm))

                            MetricRow(
                                icon: battery.isCharging ? "bolt.fill" : "bolt.slash",
                                title: "Power Source",
                                value: battery.isCharging ? "AC Power" : "Battery",
                                iconColor: battery.isCharging ? DesignTokens.Colors.success : DesignTokens.Colors.textSecondary
                            )
                            .listRowInsets(EdgeInsets(top: DesignTokens.Spacing.xxs, leading: DesignTokens.Spacing.sm, bottom: DesignTokens.Spacing.xxs, trailing: DesignTokens.Spacing.sm))

                            if let minutes = battery.estimatedMinutesRemaining, minutes > 0 {
                                MetricRow(
                                    icon: "clock",
                                    title: "Time Remaining",
                                    value: formatBatteryTime(minutes),
                                    iconColor: DesignTokens.Colors.textSecondary
                                )
                                .listRowInsets(EdgeInsets(top: DesignTokens.Spacing.xxs, leading: DesignTokens.Spacing.sm, bottom: DesignTokens.Spacing.xxs, trailing: DesignTokens.Spacing.sm))
                            }

                            MetricRow(
                                icon: "heart.fill",
                                title: "Battery Health",
                                value: battery.batteryHealth.rawValue,
                                iconColor: healthColor(for: battery.batteryHealth)
                            )
                            .listRowInsets(EdgeInsets(top: DesignTokens.Spacing.xxs, leading: DesignTokens.Spacing.sm, bottom: DesignTokens.Spacing.xxs, trailing: DesignTokens.Spacing.sm))
                        } header: {
                            sectionHeader(title: "Battery")
                        }
                    }

                    // System Section
                    Section {
                        MetricRow(
                            icon: "clock.arrow.circlepath",
                            title: "System Uptime",
                            value: formatUptime(status.systemUptime),
                            iconColor: DesignTokens.Colors.accent
                        )
                        .listRowInsets(EdgeInsets(top: DesignTokens.Spacing.xxs, leading: DesignTokens.Spacing.sm, bottom: DesignTokens.Spacing.xxs, trailing: DesignTokens.Spacing.sm))
                    } header: {
                        sectionHeader(title: "System")
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            } else {
                // Loading state
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading system status...")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .padding(.top, DesignTokens.Spacing.md)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(DesignTokens.Colors.background)
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                Text("Activity")
                    .font(DesignTokens.Typography.h1)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text("Real-time system performance")
                    .font(DesignTokens.Typography.subhead)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            Spacer()

            // Update interval picker
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text("Refresh")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Picker("Refresh interval", selection: $selectedUpdateInterval) {
                    ForEach(updateIntervals, id: \.value) { interval in
                        Text(interval.label).tag(interval.value)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                .accessibilityLabel("Update interval")
                .accessibilityHint("Select how frequently to refresh system metrics")
                .onChange(of: selectedUpdateInterval) { _, newValue in
                    monitor.setUpdateInterval(newValue)
                }
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String) -> some View {
        Text(title.uppercased())
            .font(DesignTokens.Typography.caption)
            .foregroundColor(DesignTokens.Colors.textSecondary)
            .padding(.leading, DesignTokens.Spacing.xxs)
    }

    // MARK: - Color Helpers

    private func cpuColor(for usage: Double) -> Color {
        switch usage {
        case 0..<50: return DesignTokens.Colors.success
        case 50..<80: return DesignTokens.Colors.warning
        default: return DesignTokens.Colors.destructive
        }
    }

    private func memoryColor(for pressure: MemoryPressure) -> Color {
        switch pressure {
        case .normal: return DesignTokens.Colors.success
        case .warning: return DesignTokens.Colors.warning
        case .critical: return DesignTokens.Colors.destructive
        }
    }

    private func diskColor(for usagePercentage: Double) -> Color {
        switch usagePercentage {
        case 0..<70: return DesignTokens.Colors.success
        case 70..<90: return DesignTokens.Colors.warning
        default: return DesignTokens.Colors.destructive
        }
    }

    private func healthColor(for health: BatteryHealth) -> Color {
        switch health {
        case .good: return DesignTokens.Colors.success
        case .fair: return DesignTokens.Colors.warning
        case .poor: return DesignTokens.Colors.destructive
        case .unknown: return DesignTokens.Colors.textTertiary
        }
    }

    private func batteryIcon(for percentage: Double) -> String {
        switch percentage {
        case 0..<25: return "battery.25"
        case 25..<50: return "battery.50"
        case 50..<75: return "battery.75"
        default: return "battery.100"
        }
    }

    // MARK: - Formatting Helpers

    private func formatUptime(_ uptime: TimeInterval) -> String {
        let days = Int(uptime) / 86400
        let hours = Int(uptime) % 86400 / 3600
        let minutes = Int(uptime) % 3600 / 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1024 {
            return String(format: "%.1f TB", gb / 1024)
        } else if gb >= 1 {
            return String(format: "%.1f GB", gb)
        } else {
            return String(format: "%.0f MB", Double(bytes) / 1_048_576)
        }
    }

    private func formatRate(_ kbps: Double) -> String {
        if kbps >= 1024 {
            return String(format: "%.1f MB/s", kbps / 1024)
        } else if kbps >= 1 {
            return String(format: "%.1f KB/s", kbps)
        } else {
            return "0 B/s"
        }
    }

    private func formatBatteryTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}

// MARK: - Preview

#Preview {
    SystemStatusDashboard()
        .frame(width: 700, height: 700)
}
