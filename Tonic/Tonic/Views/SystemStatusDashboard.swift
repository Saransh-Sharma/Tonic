//
//  SystemStatusDashboard.swift
//  Tonic
//
//  Real-time system status dashboard with CPU, memory, disk, network, battery, and uptime
//  Redesigned with modern visualizations and delightful UX
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

    // History for sparklines
    @Published var networkDownloadHistory: [Double] = Array(repeating: 0, count: 30)
    @Published var networkUploadHistory: [Double] = Array(repeating: 0, count: 30)

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
        networkDownloadHistory.append(downloadRate / 1024) // KB/s
        networkDownloadHistory.removeFirst()
        networkUploadHistory.append(uploadRate / 1024) // KB/s
        networkUploadHistory.removeFirst()

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

// MARK: - Circular Gauge Component

struct CircularGauge: View {
    let value: Double // 0-100
    let icon: String
    let label: String
    let subtitle: String?
    var size: CGFloat = 140

    @State private var animatedValue: Double = 0
    @State private var isHovered = false

    private var gaugeColor: Color {
        switch value {
        case 0..<50: return DesignTokens.Colors.progressLow
        case 50..<80: return DesignTokens.Colors.progressMedium
        default: return DesignTokens.Colors.progressHigh
        }
    }

    private var backgroundColor: Color {
        gaugeColor.opacity(0.15)
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(
                        backgroundColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )

                // Progress ring
                Circle()
                    .trim(from: 0, to: animatedValue / 100)
                    .stroke(
                        gaugeColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: gaugeColor.opacity(0.5), radius: isHovered ? 8 : 4)

                // Center content
                VStack(spacing: DesignTokens.Spacing.xxs) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(gaugeColor)

                    Text("\(Int(animatedValue))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(DesignTokens.Colors.text)
                        .contentTransition(.numericText())
                }
            }
            .frame(width: size, height: size)

            // Label
            VStack(spacing: 2) {
                Text(label)
                    .font(DesignTokens.Typography.headlineSmall)
                    .foregroundColor(DesignTokens.Colors.text)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large)
                .fill(isHovered ? DesignTokens.Colors.surfaceHovered : DesignTokens.Colors.surface)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedValue = value
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animatedValue = newValue
            }
        }
    }
}

// MARK: - Metric Card Component

struct MetricCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String?
    var color: Color = DesignTokens.Colors.accent

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Icon badge
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignTokens.Colors.text)

                Text(title)
                    .font(DesignTokens.Typography.captionMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.captionSmall)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                .fill(isHovered ? DesignTokens.Colors.surfaceHovered : DesignTokens.Colors.surface)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Sparkline Chart Component

struct SparklineChart: View {
    let data: [Double]
    let color: Color
    var height: CGFloat = 40
    var showGradient: Bool = true

    private var normalizedData: [Double] {
        let maxVal = max(data.max() ?? 1, 1)
        return data.map { $0 / maxVal }
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let stepX = width / CGFloat(max(data.count - 1, 1))

            ZStack {
                // Gradient fill
                if showGradient {
                    Path { path in
                        guard !normalizedData.isEmpty else { return }

                        path.move(to: CGPoint(x: 0, y: height))

                        for (index, value) in normalizedData.enumerated() {
                            let x = CGFloat(index) * stepX
                            let y = height - (CGFloat(value) * height * 0.9)

                            if index == 0 {
                                path.addLine(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }

                        path.addLine(to: CGPoint(x: width, y: height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                // Line
                Path { path in
                    guard !normalizedData.isEmpty else { return }

                    for (index, value) in normalizedData.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = height - (CGFloat(value) * height * 0.9)

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Storage Section

struct StorageSection: View {
    let volumes: [DiskVolume]
    @State private var showOtherVolumes = false

    private var bootVolume: DiskVolume? {
        volumes.first(where: { $0.isBootVolume })
    }

    private var otherVolumes: [DiskVolume] {
        volumes.filter { !$0.isBootVolume }
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Header
                HStack {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "internaldrive.fill")
                            .font(.title3)
                            .foregroundColor(DesignTokens.Colors.accent)
                        Text("Storage")
                            .font(DesignTokens.Typography.headlineMedium)
                    }

                    Spacer()

                    if let boot = bootVolume {
                        StatusDot(level: storageStatus(for: boot.usagePercentage))
                    }
                }

                // Boot volume (always visible)
                if let boot = bootVolume {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        HStack {
                            Text(boot.name)
                                .font(DesignTokens.Typography.bodyMedium)
                                .fontWeight(.medium)

                            Badge(text: "Boot", color: DesignTokens.Colors.accent, size: .small)

                            Spacer()

                            Text("\(Int(boot.usagePercentage))% used")
                                .font(DesignTokens.Typography.bodySmall)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }

                        // Gradient progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(DesignTokens.Colors.backgroundSecondary)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: storageGradient(for: boot.usagePercentage),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * CGFloat(boot.usagePercentage / 100))
                            }
                        }
                        .frame(height: 8)

                        // Stats row
                        HStack(spacing: DesignTokens.Spacing.md) {
                            Text("\(formatBytes(boot.usedBytes)) used")
                                .font(DesignTokens.Typography.captionMedium)
                                .foregroundColor(DesignTokens.Colors.textSecondary)

                            Text("•")
                                .foregroundColor(DesignTokens.Colors.textTertiary)

                            Text("\(formatBytes(boot.freeBytes)) free")
                                .font(DesignTokens.Typography.captionMedium)
                                .foregroundColor(DesignTokens.Colors.progressLow)

                            Text("•")
                                .foregroundColor(DesignTokens.Colors.textTertiary)

                            Text("\(formatBytes(boot.totalBytes)) total")
                                .font(DesignTokens.Typography.captionMedium)
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                        }
                    }
                    .padding(DesignTokens.Spacing.md)
                    .background(DesignTokens.Colors.backgroundSecondary.opacity(0.5))
                    .cornerRadius(DesignTokens.CornerRadius.medium)
                }

                // Other volumes (collapsible)
                if !otherVolumes.isEmpty {
                    Button {
                        withAnimation(DesignTokens.Animation.normal) {
                            showOtherVolumes.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: showOtherVolumes ? "chevron.down" : "chevron.right")
                                .font(.caption)
                                .foregroundColor(DesignTokens.Colors.textSecondary)

                            Text("Other Volumes (\(otherVolumes.count))")
                                .font(DesignTokens.Typography.bodySmall)
                                .foregroundColor(DesignTokens.Colors.textSecondary)

                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)

                    if showOtherVolumes {
                        VStack(spacing: DesignTokens.Spacing.sm) {
                            ForEach(otherVolumes) { volume in
                                CompactVolumeRow(volume: volume)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    private func storageStatus(for percentage: Double) -> StatusLevel {
        switch percentage {
        case 0..<70: return .healthy
        case 70..<90: return .warning
        default: return .critical
        }
    }

    private func storageGradient(for percentage: Double) -> [Color] {
        switch percentage {
        case 0..<70:
            return [DesignTokens.Colors.progressLow, DesignTokens.Colors.progressLow.opacity(0.8)]
        case 70..<90:
            return [DesignTokens.Colors.progressMedium, DesignTokens.Colors.progressMedium.opacity(0.8)]
        default:
            return [DesignTokens.Colors.progressHigh, DesignTokens.Colors.progressHigh.opacity(0.8)]
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1024 {
            return String(format: "%.1f TB", gb / 1024)
        }
        return String(format: "%.1f GB", gb)
    }
}

struct CompactVolumeRow: View {
    let volume: DiskVolume

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "externaldrive.fill")
                .font(.caption)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Text(volume.name)
                .font(DesignTokens.Typography.bodySmall)
                .lineLimit(1)

            Spacer()

            Text("\(Int(volume.usagePercentage))%")
                .font(DesignTokens.Typography.captionMedium)
                .foregroundColor(volumeColor)

            // Mini progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DesignTokens.Colors.backgroundSecondary)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(volumeColor)
                        .frame(width: geometry.size.width * CGFloat(volume.usagePercentage / 100))
                }
            }
            .frame(width: 60, height: 4)
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private var volumeColor: Color {
        switch volume.usagePercentage {
        case 0..<70: return DesignTokens.Colors.progressLow
        case 70..<90: return DesignTokens.Colors.progressMedium
        default: return DesignTokens.Colors.progressHigh
        }
    }
}

struct StatusDot: View {
    let level: StatusLevel

    var body: some View {
        Circle()
            .fill(level.color)
            .frame(width: 8, height: 8)
    }
}

// MARK: - Network Section

struct NetworkActivitySection: View {
    let bytesIn: UInt64
    let bytesOut: UInt64
    let downloadHistory: [Double]
    let uploadHistory: [Double]

    private var currentDownloadRate: Double {
        downloadHistory.last ?? 0
    }

    private var currentUploadRate: Double {
        uploadHistory.last ?? 0
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Header
                HStack {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "network")
                            .font(.title3)
                            .foregroundColor(DesignTokens.Colors.accent)
                        Text("Network")
                            .font(DesignTokens.Typography.headlineMedium)
                    }

                    Spacer()

                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Circle()
                            .fill(DesignTokens.Colors.progressLow)
                            .frame(width: 8, height: 8)
                        Text("Online")
                            .font(DesignTokens.Typography.captionMedium)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }

                // Download and Upload cards
                HStack(spacing: DesignTokens.Spacing.md) {
                    // Download
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(DesignTokens.Colors.progressLow)
                            Text("Download")
                                .font(DesignTokens.Typography.captionMedium)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }

                        Text(formatRate(currentDownloadRate))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignTokens.Colors.text)

                        SparklineChart(data: downloadHistory, color: DesignTokens.Colors.progressLow, height: 35)

                        Text("Total: \(formatBytes(bytesIn))")
                            .font(DesignTokens.Typography.captionSmall)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(DesignTokens.Spacing.md)
                    .background(DesignTokens.Colors.backgroundSecondary.opacity(0.5))
                    .cornerRadius(DesignTokens.CornerRadius.medium)

                    // Upload
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.blue)
                            Text("Upload")
                                .font(DesignTokens.Typography.captionMedium)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }

                        Text(formatRate(currentUploadRate))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignTokens.Colors.text)

                        SparklineChart(data: uploadHistory, color: .blue, height: 35)

                        Text("Total: \(formatBytes(bytesOut))")
                            .font(DesignTokens.Typography.captionSmall)
                            .foregroundColor(DesignTokens.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(DesignTokens.Spacing.md)
                    .background(DesignTokens.Colors.backgroundSecondary.opacity(0.5))
                    .cornerRadius(DesignTokens.CornerRadius.medium)
                }
            }
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

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1024 {
            return String(format: "%.2f TB", gb / 1024)
        } else if gb >= 1 {
            return String(format: "%.2f GB", gb)
        } else {
            return String(format: "%.1f MB", Double(bytes) / 1_048_576)
        }
    }
}

// MARK: - Battery Section

struct BatteryStatusSection: View {
    let battery: BatteryInfo
    @State private var pulseAnimation = false

    private var batteryGradient: LinearGradient {
        let colors: [Color]
        switch battery.chargePercentage {
        case 0..<20:
            colors = [DesignTokens.Colors.progressHigh, DesignTokens.Colors.progressHigh.opacity(0.7)]
        case 20..<50:
            colors = [DesignTokens.Colors.progressMedium, DesignTokens.Colors.progressMedium.opacity(0.7)]
        default:
            colors = [DesignTokens.Colors.progressLow, DesignTokens.Colors.progressLow.opacity(0.7)]
        }
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Header
                HStack {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: battery.isCharging ? "battery.100.bolt" : "battery.100")
                            .font(.title3)
                            .foregroundColor(battery.color)
                            .symbolEffect(.pulse, isActive: battery.isCharging)

                        Text("\(Int(battery.chargePercentage))%")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                    }

                    Spacer()

                    if let minutes = battery.estimatedMinutesRemaining, minutes > 0 {
                        Text("\(minutes / 60)h \(minutes % 60)m remaining")
                            .font(DesignTokens.Typography.bodySmall)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }

                // Battery bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(DesignTokens.Colors.backgroundSecondary)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(batteryGradient)
                            .frame(width: geometry.size.width * CGFloat(battery.chargePercentage / 100))
                            .shadow(color: battery.color.opacity(battery.isCharging ? 0.5 : 0), radius: pulseAnimation ? 8 : 4)
                    }
                }
                .frame(height: 12)

                // Status row
                HStack(spacing: DesignTokens.Spacing.md) {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Image(systemName: battery.isCharging ? "bolt.fill" : "bolt.slash")
                            .font(.caption)
                            .foregroundColor(battery.isCharging ? DesignTokens.Colors.progressMedium : DesignTokens.Colors.textTertiary)

                        Text(battery.isCharging ? "Charging" : "On Battery")
                            .font(DesignTokens.Typography.captionMedium)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }

                    Text("•")
                        .foregroundColor(DesignTokens.Colors.textTertiary)

                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundColor(healthColor)

                        Text("Health: \(battery.batteryHealth.rawValue)")
                            .font(DesignTokens.Typography.captionMedium)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }
            }
        }
        .onAppear {
            if battery.isCharging {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            }
        }
    }

    private var healthColor: Color {
        switch battery.batteryHealth {
        case .good: return DesignTokens.Colors.progressLow
        case .fair: return DesignTokens.Colors.progressMedium
        case .poor: return DesignTokens.Colors.progressHigh
        case .unknown: return DesignTokens.Colors.textTertiary
        }
    }
}

// MARK: - Skeleton Loading State

struct SkeletonLoadingView: View {
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Hero section skeleton
            HStack(spacing: DesignTokens.Spacing.lg) {
                SkeletonCircle(size: 140)
                SkeletonCircle(size: 140)

                VStack(spacing: DesignTokens.Spacing.sm) {
                    SkeletonRect(height: 60)
                    SkeletonRect(height: 60)
                    SkeletonRect(height: 60)
                }
                .frame(maxWidth: .infinity)
            }

            // Cards skeleton
            SkeletonRect(height: 150)
            SkeletonRect(height: 180)
            SkeletonRect(height: 100)
        }
        .padding(DesignTokens.Spacing.lg)
    }
}

struct SkeletonCircle: View {
    let size: CGFloat
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(DesignTokens.Colors.surface)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: isAnimating ? size : -size)
            )
            .clipShape(Circle())
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

struct SkeletonRect: View {
    var width: CGFloat? = nil
    let height: CGFloat
    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
            .fill(DesignTokens.Colors.surface)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .overlay(
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.08),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: isAnimating ? geometry.size.width : -geometry.size.width)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Live Monitoring")
                        .font(DesignTokens.Typography.headlineLarge)
                    Text("Real-time system performance")
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }

                Spacer()

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text("Update")
                        .font(DesignTokens.Typography.captionMedium)
                        .foregroundColor(DesignTokens.Colors.textSecondary)

                    Picker("", selection: $selectedUpdateInterval) {
                        ForEach(updateIntervals, id: \.value) { interval in
                            Text(interval.label).tag(interval.value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                    .onChange(of: selectedUpdateInterval) { _, newValue in
                        monitor.setUpdateInterval(newValue)
                    }
                }
            }

            if let status = monitor.currentStatus {
                // Hero Section: Gauges + Stats
                HStack(alignment: .top, spacing: DesignTokens.Spacing.lg) {
                    // CPU Gauge
                    CircularGauge(
                        value: status.cpuUsage,
                        icon: "cpu",
                        label: "CPU",
                        subtitle: pressureLabel(for: status.cpuUsage)
                    )

                    // Memory Gauge
                    CircularGauge(
                        value: status.memoryUsagePercentage,
                        icon: "memorychip",
                        label: "Memory",
                        subtitle: status.memoryPressure.rawValue
                    )

                    // Stats Column
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        MetricCard(
                            icon: "gearshape.2.fill",
                            title: "Processes",
                            value: "\(status.activeProcesses)",
                            subtitle: "Active",
                            color: DesignTokens.Colors.accent
                        )

                        MetricCard(
                            icon: "bolt.horizontal.fill",
                            title: "Threads",
                            value: "\(status.totalThreads)",
                            subtitle: "Running",
                            color: .purple
                        )

                        MetricCard(
                            icon: "clock.fill",
                            title: "Uptime",
                            value: formatUptime(status.systemUptime),
                            subtitle: "Since boot",
                            color: .blue
                        )
                    }
                    .frame(maxWidth: .infinity)
                }

                // Scrollable detail sections
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        // Storage
                        StorageSection(volumes: status.diskUsage)

                        // Network
                        NetworkActivitySection(
                            bytesIn: status.networkBytesIn,
                            bytesOut: status.networkBytesOut,
                            downloadHistory: monitor.networkDownloadHistory,
                            uploadHistory: monitor.networkUploadHistory
                        )

                        // Battery
                        if let battery = status.batteryInfo {
                            BatteryStatusSection(battery: battery)
                        }
                    }
                    .padding(.bottom, DesignTokens.Spacing.lg)
                }
            } else {
                SkeletonLoadingView()
            }
        }
        .padding(DesignTokens.Spacing.lg)
    }

    private func pressureLabel(for usage: Double) -> String {
        switch usage {
        case 0..<50: return "Normal"
        case 50..<80: return "Moderate"
        default: return "High"
        }
    }

    private func formatUptime(_ uptime: TimeInterval) -> String {
        let days = Int(uptime) / 86400
        let hours = Int(uptime) % 86400 / 3600
        let minutes = Int(uptime) % 3600 / 60

        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Preview

#Preview {
    SystemStatusDashboard()
        .frame(width: 900, height: 700)
}
