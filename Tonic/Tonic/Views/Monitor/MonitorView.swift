//
//  MonitorView.swift
//  Tonic
//
//  Live system monitor — the most literal "data is the media" surface. A gauge bento
//  over a wall of near-black monitoring consoles: CPU (E/P clusters + per-core), memory
//  breakdown, GPU, sensors & fans, battery, disk I/O, network. Every value draws from the
//  status scale only; the console chrome stays silent. Driven by WidgetDataManager.
//

import SwiftUI

struct MonitorView: View {
    var isActive: Bool = true

    @State private var data = WidgetDataManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
                TonicPageHeader("Monitor", subtitle: "Live system readout")
                    .tonicAppear(appeared, index: 0, reduceMotion: reduceMotion)

                metricsGrid
                    .tonicAppear(appeared, index: 1, reduceMotion: reduceMotion)

                if !data.networkDownloadHistory.isEmpty {
                    ChartCard(label: "Network ↓",
                              displayValue: lastRate(data.networkDownloadHistory),
                              history: data.networkDownloadHistory)
                        .tonicAppear(appeared, index: 2, reduceMotion: reduceMotion)
                }

                MonoLabel("Detail")
                    .padding(.top, TonicDS.Space.sm)
                    .tonicAppear(appeared, index: 3, reduceMotion: reduceMotion)

                detailConsoles
            }
            .frame(maxWidth: TonicDS.Layout.maxContentWidth)
            .frame(maxWidth: .infinity, alignment: .center)
            .tonicScreenHPadding()
            .padding(.vertical, TonicDS.Space.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TonicDS.Colors.canvas)
        .onAppear {
            if !data.isMonitoring { data.startMonitoring() }
            appeared = true
        }
    }

    // MARK: - Gauge bento

    @ViewBuilder
    private var metricsGrid: some View {
        if data.cpuHistory.isEmpty && data.memoryHistory.isEmpty && data.diskHistory.isEmpty {
            monitorSkeleton
        } else {
            TonicBentoGrid(minTileWidth: 240) {
                GaugeCard(label: "CPU", fraction: cpu, displayValue: "", metricMode: .percent, history: data.cpuHistory)
                GaugeCard(label: "Memory", fraction: mem, displayValue: "", metricMode: .percent, history: data.memoryHistory)
                GaugeCard(label: "Disk used", fraction: disk, displayValue: "", metricMode: .percent, supportingText: "\(diskFree) free", history: data.diskHistory)
                if !data.gpuHistory.isEmpty {
                    GaugeCard(label: "GPU", fraction: gpu, displayValue: "", metricMode: .percent, history: data.gpuHistory)
                }
            }
        }
    }

    private var monitorSkeleton: some View {
        TonicBentoGrid(minTileWidth: 240) {
            ForEach(["CPU", "Memory", "Disk"], id: \.self) { label in
                DataCard {
                    VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                        MonoLabel(label)
                        RoundedRectangle(cornerRadius: TonicDS.Radius.xs, style: .continuous)
                            .fill(TonicDS.Colors.hairline).frame(width: 96, height: 28).skeleton()
                        RoundedRectangle(cornerRadius: TonicDS.Radius.xs, style: .continuous)
                            .fill(TonicDS.Colors.hairline).frame(height: 42).skeleton()
                    }
                }
            }
        }
        .accessibilityLabel("Loading monitor metrics")
    }

    // MARK: - Detail console wall

    @ViewBuilder
    private var detailConsoles: some View {
        if !hasAnyDetail {
            consoleSkeleton
                .tonicAppear(appeared, index: 4, reduceMotion: reduceMotion)
        } else {
            TonicBentoGrid(minTileWidth: 320) {
                cpuConsole
                memoryConsole
                if gpuConsoleVisible { gpuConsole }
                if sensorsConsoleVisible { sensorsConsole }
                if batteryConsoleVisible { batteryConsole }
                if diskConsoleVisible { diskConsole }
                networkConsole
            }
            .tonicAppear(appeared, index: 4, reduceMotion: reduceMotion)
        }
    }

    private var consoleSkeleton: some View {
        TonicBentoGrid(minTileWidth: 320) {
            ForEach(["CPU", "Memory", "Network"], id: \.self) { label in
                MonitoringConsole {
                    VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                        MonoLabel("\(label) detail", color: TonicDS.Colors.onDarkMuted)
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: TonicDS.Radius.xs, style: .continuous)
                                .fill(TonicDS.Colors.hairlineOnDark).frame(height: 12).skeleton()
                        }
                    }
                }
            }
        }
        .accessibilityLabel("Waiting for live samples")
    }

    // MARK: - CPU console

    private var cpuConsole: some View {
        MonitoringConsole {
            VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                MonoLabel("CPU detail", color: TonicDS.Colors.onDarkMuted)
                consoleRow("Usage", pct(cpu) + "%", TonicDS.status(forFraction: cpu))
                consoleRow("User", "\(Int(data.cpuData.userUsage))%", TonicDS.Chart.cpuUser)
                consoleRow("System", "\(Int(data.cpuData.systemUsage))%", TonicDS.Chart.cpuSystem)

                if let e = data.cpuData.eCoreUsage, !e.isEmpty {
                    clusterRow("E-cores", values: e, color: TonicDS.Colors.seriesEcore)
                }
                if let p = data.cpuData.pCoreUsage, !p.isEmpty {
                    clusterRow("P-cores", values: p, color: TonicDS.Colors.seriesPcore)
                }
                if (data.cpuData.eCoreUsage?.isEmpty ?? true),
                   (data.cpuData.pCoreUsage?.isEmpty ?? true),
                   !data.cpuData.perCoreUsage.isEmpty {
                    clusterRow("Cores", values: data.cpuData.perCoreUsage, color: TonicDS.Colors.seriesUser)
                }

                if let t = data.cpuData.temperature {
                    consoleRow("Temperature", String(format: "%.0f°C", t), TonicDS.status(forTempC: t))
                }
                if data.cpuData.thermalLimit == true {
                    consoleRow("Thermal", "THROTTLED", TonicDS.Colors.statusCaution)
                }
                if let f = data.cpuData.frequency {
                    consoleRow("Frequency", String(format: "%.2f GHz", f), TonicDS.Colors.onDark)
                }
                if let load = data.cpuData.averageLoad, load.count >= 3 {
                    consoleRow("Load avg", String(format: "%.2f · %.2f · %.2f", load[0], load[1], load[2]), TonicDS.Colors.onDark)
                }
                consoleRow("Uptime", Self.uptime(data.cpuData.uptime), TonicDS.Colors.onDark)
            }
        }
    }

    // MARK: - Memory console

    private var memoryConsole: some View {
        MonitoringConsole {
            VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                MonoLabel("Memory detail", color: TonicDS.Colors.onDarkMuted)
                consoleRow("Usage", pct(mem) + "%", TonicDS.status(forFraction: mem))

                // Used breakdown: app footprint · compressed · other, over total.
                let total = max(1, Double(data.memoryData.totalBytes))
                let active = Double(data.memoryData.activeBytes ?? 0)
                let compressed = Double(data.memoryData.compressedBytes)
                let used = Double(data.memoryData.usedBytes)
                let other = max(0, used - active - compressed)
                ConsoleBreakdownBar(segments: [
                    .init(fraction: active / total, color: TonicDS.Colors.seriesAppMem),
                    .init(fraction: other / total, color: TonicDS.Colors.seriesWired),
                    .init(fraction: compressed / total, color: TonicDS.Colors.seriesCompressed)
                ])
                ConsoleLegend(items: [
                    .init(label: "App", color: TonicDS.Colors.seriesAppMem),
                    .init(label: "Wired", color: TonicDS.Colors.seriesWired),
                    .init(label: "Compressed", color: TonicDS.Colors.seriesCompressed)
                ])

                consoleRow("Used", "\(bytes(data.memoryData.usedBytes)) / \(bytes(data.memoryData.totalBytes))", TonicDS.Colors.onDark)
                consoleRow("Compressed", bytes(data.memoryData.compressedBytes), TonicDS.Colors.onDark)
                let swapTotal = data.memoryData.swapTotalBytes ?? 0
                let swapFraction = swapTotal > 0 ? Double(data.memoryData.swapBytes) / Double(swapTotal) : 0
                consoleRow("Swap", bytes(data.memoryData.swapBytes), TonicDS.status(forFraction: swapFraction))
            }
        }
    }

    // MARK: - GPU console

    private var gpuConsoleVisible: Bool { data.gpuData.usagePercentage != nil }

    private var gpuConsole: some View {
        MonitoringConsole {
            VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                MonoLabel("GPU detail", color: TonicDS.Colors.onDarkMuted)
                let util = data.gpuData.usagePercentage ?? 0
                consoleRow("Utilization", "\(Int(util))%", TonicDS.Chart.utilization(util))
                if !data.gpuHistory.isEmpty {
                    consoleSparkline(data.gpuHistory, color: TonicDS.Chart.utilization(util))
                }
                if let r = data.gpuData.renderUtilization {
                    consoleRow("Render", "\(Int(r))%", TonicDS.Chart.utilization(r))
                }
                if let t = data.gpuData.tilerUtilization {
                    consoleRow("Tiler", "\(Int(t))%", TonicDS.Chart.utilization(t))
                }
                if let temp = data.gpuData.temperature {
                    consoleRow("Temperature", String(format: "%.0f°C", temp), TonicDS.status(forTempC: temp))
                }
                if let clock = data.gpuData.coreClock, clock > 0 {
                    consoleRow("Core clock", "\(Int(clock)) MHz", TonicDS.Colors.onDark)
                }
                if let mem = data.gpuData.memoryUsagePercentage {
                    consoleRow("VRAM", "\(Int(mem))%", TonicDS.Chart.utilization(mem))
                }
            }
        }
    }

    // MARK: - Sensors & Fans console

    private var sensorsConsoleVisible: Bool {
        !data.sensorsData.temperatures.isEmpty || !data.sensorsData.fans.isEmpty
    }

    private var sensorsConsole: some View {
        MonitoringConsole {
            VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                MonoLabel("Sensors & fans", color: TonicDS.Colors.onDarkMuted)
                ForEach(topTemperatures) { reading in
                    consoleRow(reading.name, String(format: "%.0f°C", reading.value),
                               TonicDS.status(forTempC: reading.value))
                }
                if !data.sensorsData.fans.isEmpty {
                    TonicHairline(color: TonicDS.Colors.hairlineOnDark)
                    ForEach(data.sensorsData.fans) { fan in
                        let frac = (fan.speedPercentage ?? 0) / 100
                        consoleRow(fan.name, "\(fan.rpm) RPM",
                                   fan.maxRPM != nil ? TonicDS.status(forFraction: frac) : TonicDS.Colors.statusInfo)
                    }
                }
            }
        }
    }

    private var topTemperatures: [SensorReading] {
        data.sensorsData.temperatures.sorted { $0.value > $1.value }.prefix(5).map { $0 }
    }

    // MARK: - Battery console

    private var batteryConsoleVisible: Bool { data.batteryData.isPresent }

    private var batteryConsole: some View {
        MonitoringConsole {
            VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                MonoLabel("Battery detail", color: TonicDS.Colors.onDarkMuted)
                let b = data.batteryData
                let level = b.chargePercentage / 100
                consoleRow("Charge", "\(Int(b.chargePercentage))%",
                           TonicDS.status(forBattery: level, isCharging: b.isCharging))
                consoleRow("State", b.isCharging ? "Charging" : "On battery",
                           b.isCharging ? TonicDS.Colors.statusInfo : TonicDS.Colors.onDark)
                consoleRow("Health", b.health.description, TonicDS.Colors.onDark)
                if let cycles = b.cycleCount {
                    consoleRow("Cycles", "\(cycles)", TonicDS.Colors.onDark)
                }
                if let power = b.batteryPower {
                    consoleRow("Power", String(format: "%.1f W", power), TonicDS.Colors.onDark)
                }
                if let volts = b.voltage {
                    consoleRow("Voltage", String(format: "%.2f V", volts), TonicDS.Colors.onDark)
                }
                if let temp = b.temperature {
                    consoleRow("Temperature", String(format: "%.0f°C", temp), TonicDS.status(forTempC: temp))
                }
                if let mins = b.estimatedMinutesRemaining {
                    consoleRow(b.isCharging ? "To full" : "Remaining", Self.remaining(mins), TonicDS.Colors.onDark)
                }
            }
        }
    }

    // MARK: - Disk I/O console

    private var diskConsoleVisible: Bool {
        (boot?.readBytesPerSecond != nil) || !data.diskReadHistory.isEmpty
    }

    private var diskConsole: some View {
        MonitoringConsole {
            VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                MonoLabel("Disk I/O", color: TonicDS.Colors.onDarkMuted)
                consoleRow("Read", rate(boot?.readBytesPerSecond ?? 0), TonicDS.Colors.seriesRead)
                if !data.diskReadHistory.isEmpty {
                    consoleSparkline(data.diskReadHistory, color: TonicDS.Colors.seriesRead)
                }
                consoleRow("Write", rate(boot?.writeBytesPerSecond ?? 0), TonicDS.Colors.seriesWrite)
                if !data.diskWriteHistory.isEmpty {
                    consoleSparkline(data.diskWriteHistory, color: TonicDS.Colors.seriesWrite)
                }
                if let riops = boot?.readIOPS, let wiops = boot?.writeIOPS {
                    consoleRow("IOPS", "\(Int(riops)) r · \(Int(wiops)) w", TonicDS.Colors.onDark)
                }
                consoleRow("Free", diskFree, TonicDS.Colors.onDark)
            }
        }
    }

    // MARK: - Network console

    private var networkConsole: some View {
        MonitoringConsole {
            VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                MonoLabel("Network detail", color: TonicDS.Colors.onDarkMuted)
                consoleRow("Download", rate(data.networkData.downloadBytesPerSecond), TonicDS.Colors.seriesRead)
                consoleRow("Upload", rate(data.networkData.uploadBytesPerSecond), TonicDS.Colors.seriesWrite)
                if let link = data.networkData.linkSpeedMbps, link > 0 {
                    consoleRow("Link", "\(Int(link)) Mbps", TonicDS.Colors.onDark)
                }
                if let iface = data.networkData.interfaceName, !iface.isEmpty {
                    consoleRow("Interface", iface, TonicDS.Colors.onDark)
                }
            }
        }
    }

    // MARK: - Console building blocks

    private func consoleRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label).tonicType(.body).foregroundStyle(TonicDS.Colors.onDarkMuted)
            Spacer()
            Text(value).tonicType(.monoLabel).monospacedDigit().foregroundStyle(color)
                .contentTransition(.numericText())
        }
        .padding(.vertical, 2)
    }

    private func clusterRow(_ label: String, values: [Double], color: Color) -> some View {
        let avg = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        return HStack(alignment: .center, spacing: TonicDS.Space.sm) {
            Text(label).tonicType(.body).foregroundStyle(TonicDS.Colors.onDarkMuted)
            ConsoleCoreBars(values: values, color: color)
            Spacer(minLength: TonicDS.Space.xs)
            Text("\(Int(avg))%").tonicType(.monoLabel).monospacedDigit()
                .foregroundStyle(TonicDS.Colors.onDark)
        }
        .padding(.vertical, 2)
    }

    private func consoleSparkline(_ history: [Double], color: Color) -> some View {
        NetworkSparklineChart(data: Array(history.suffix(40)), color: color, height: 34, showArea: true, lineWidth: 1.5)
            .clipShape(RoundedRectangle(cornerRadius: TonicDS.Radius.xs, style: .continuous))
    }

    // MARK: - Derived

    private var hasAnyDetail: Bool {
        !data.cpuHistory.isEmpty || !data.memoryHistory.isEmpty || data.batteryData.isPresent
    }

    private var cpu: Double { min(1, max(0, data.cpuData.totalUsage / 100)) }
    private var mem: Double { min(1, max(0, data.memoryData.usagePercentage / 100)) }
    private var boot: DiskVolumeData? { data.diskVolumes.first(where: { $0.isBootVolume }) ?? data.diskVolumes.first }
    private var disk: Double { min(1, max(0, (boot?.usagePercentage ?? 0) / 100)) }
    private var gpu: Double { min(1, max(0, (data.gpuHistory.last ?? 0) / 100)) }
    private var diskFree: String {
        guard let v = boot else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(v.freeBytes), countStyle: .file)
    }

    private func pct(_ f: Double) -> String { "\(Int((f * 100).rounded()))" }

    private func lastRate(_ history: [Double]) -> String { rate(history.last ?? 0) }

    private func rate(_ bytesPerSecond: Double) -> String {
        let f = ByteCountFormatter(); f.allowedUnits = [.useMB, .useKB]; f.countStyle = .memory
        return f.string(fromByteCount: Int64(max(0, bytesPerSecond))) + "/s"
    }

    private func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .memory)
    }

    private static func uptime(_ seconds: TimeInterval) -> String {
        let d = Int(seconds) / 86400, h = (Int(seconds) % 86400) / 3600, m = (Int(seconds) % 3600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private static func remaining(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

// MARK: - Console primitives

/// A row of vertical mini-bars for a core cluster. Category-colored (E vs P), never
/// a status hue — the cluster identity is the datum, not utilization.
private struct ConsoleCoreBars: View {
    let values: [Double] // 0...100
    let color: Color
    private let maxHeight: CGFloat = 24

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(color)
                    .frame(width: 5, height: max(2, CGFloat(min(100, max(0, v)) / 100) * maxHeight))
            }
        }
        .frame(height: maxHeight, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

/// A thin stacked breakdown bar (memory composition, etc.). Segments are data-series colors.
private struct ConsoleBreakdownBar: View {
    struct Segment: Identifiable {
        let id = UUID()
        let fraction: Double
        let color: Color
    }
    let segments: [Segment]

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(segments) { seg in
                    Rectangle().fill(seg.color)
                        .frame(width: max(0, geo.size.width * min(1, max(0, seg.fraction))))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 6)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }
}

/// Small legend for a breakdown bar — mono labels with a colored dot.
private struct ConsoleLegend: View {
    struct Item: Identifiable {
        let id = UUID()
        let label: String
        let color: Color
    }
    let items: [Item]

    var body: some View {
        HStack(spacing: TonicDS.Space.md) {
            ForEach(items) { item in
                HStack(spacing: TonicDS.Space.xxs) {
                    Circle().fill(item.color).frame(width: 6, height: 6)
                    Text(item.label.uppercased())
                        .tonicType(.monoLabel)
                        .foregroundStyle(TonicDS.Colors.onDarkMuted)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
