//
//  MonitorView.swift
//  Tonic
//
//  Live system monitor — the most literal "data is the media" surface. Gauge/chart
//  data cards + a console panel, all colored from the status scale only. Driven by
//  the preserved WidgetDataManager.
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
                    ChartCard(label: "Network ↓", displayValue: lastRate(data.networkDownloadHistory), history: data.networkDownloadHistory)
                        .tonicAppear(appeared, index: 2, reduceMotion: reduceMotion)
                }

                MonoLabel("Detail")
                    .tonicAppear(appeared, index: 3, reduceMotion: reduceMotion)
                TonicBentoGrid(minTileWidth: 320) {
                    cpuConsole
                    memoryConsole
                    networkConsole
                }
                .tonicAppear(appeared, index: 4, reduceMotion: reduceMotion)
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
                            .fill(TonicDS.Colors.hairline)
                            .frame(width: 96, height: 28)
                            .skeleton()
                        RoundedRectangle(cornerRadius: TonicDS.Radius.xs, style: .continuous)
                            .fill(TonicDS.Colors.hairline)
                            .frame(height: 42)
                            .skeleton()
                    }
                }
            }
        }
        .accessibilityLabel("Loading monitor metrics")
    }

    // MARK: - CPU console

    private var cpuConsole: some View {
        MonitoringConsole {
            VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                MonoLabel("CPU detail", color: TonicDS.Colors.onDarkMuted)
                consoleRow("Usage", pct(cpu) + "%", TonicDS.status(forFraction: cpu))
                if let t = data.cpuData.temperature {
                    consoleRow("Temperature", String(format: "%.0f°C", t), TonicDS.status(forTempC: t))
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
                consoleRow("Used", "\(bytes(data.memoryData.usedBytes)) / \(bytes(data.memoryData.totalBytes))", TonicDS.Colors.onDark)
                consoleRow("Compressed", bytes(data.memoryData.compressedBytes), TonicDS.Colors.onDark)
                let swapTotal = data.memoryData.swapTotalBytes ?? 0
                let swapFraction = swapTotal > 0 ? Double(data.memoryData.swapBytes) / Double(swapTotal) : 0
                consoleRow("Swap", bytes(data.memoryData.swapBytes), TonicDS.status(forFraction: swapFraction))
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

    private func consoleRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label).tonicType(.body).foregroundStyle(TonicDS.Colors.onDarkMuted)
            Spacer()
            Text(value).tonicType(.monoLabel).monospacedDigit().foregroundStyle(color)
                .contentTransition(.numericText())
        }
        .padding(.vertical, 2)
    }

    // MARK: - Derived

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

    private func lastRate(_ history: [Double]) -> String {
        rate(history.last ?? 0)
    }

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
}
