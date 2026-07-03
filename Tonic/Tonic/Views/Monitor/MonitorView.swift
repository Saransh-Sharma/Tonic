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
    private static let initialResourceHistoryRange: ResourceHistoryRange = .live
    #if DEBUG
    static var initialResourceHistoryRangeForTesting: ResourceHistoryRange { initialResourceHistoryRange }
    #endif

    var isActive: Bool = true

    @State private var data = WidgetDataManager.shared
    @State private var history = WidgetHistoryStore.shared
    @State private var selectedRange: ResourceHistoryRange = Self.initialResourceHistoryRange
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var liveStartupDate = Date()
    @State private var liveStartupStalled = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
                TonicPageHeader("Monitor", subtitle: "Live system readout")
                    .tonicAppear(appeared, index: 0, reduceMotion: reduceMotion)

                rangePicker
                    .tonicAppear(appeared, index: 1, reduceMotion: reduceMotion)

                if selectedRange != .live && !hasMonitorSamples {
                    historyEmptyNotice
                        .tonicAppear(appeared, index: 2, reduceMotion: reduceMotion)
                } else {
                    metricsGrid
                        .tonicAppear(appeared, index: 2, reduceMotion: reduceMotion)
                }

                if selectedRange == .live && !hasMonitorSamples {
                    liveStartupCard
                        .tonicAppear(appeared, index: 3, reduceMotion: reduceMotion)
                }

                if hasMonitorSamples {
                    NetworkTrafficCard(
                        label: "Network",
                        downRate: rate(networkDownloadValue),
                        upRate: rate(networkUploadValue),
                        downloadHistory: networkDownloadSeries,
                        uploadHistory: networkUploadSeries,
                        context: networkTrafficCardContext
                    )
                        .tonicAppear(appeared, index: 4, reduceMotion: reduceMotion)
                }

                if selectedRange != .live, hasMonitorSamples {
                    rangeSummary
                        .tonicAppear(appeared, index: 5, reduceMotion: reduceMotion)
                    TextAction("Export CSV", systemImage: "square.and.arrow.up",
                               color: TonicDS.Colors.linkBlue) {
                        MetricsExporter.exportWithPanel(
                            samples: WidgetHistoryStore.shared.samples(for: selectedRange),
                            rangeName: String(describing: selectedRange)
                        )
                    }
                    .tonicAppear(appeared, index: 5, reduceMotion: reduceMotion)
                }

                ProcessExplorerView()
                    .padding(.top, TonicDS.Space.sm)
                    .tonicAppear(appeared, index: 6, reduceMotion: reduceMotion)

                alertHistory
                    .tonicAppear(appeared, index: 7, reduceMotion: reduceMotion)

                MonoLabel("Detail")
                    .padding(.top, TonicDS.Space.sm)
                    .tonicAppear(appeared, index: 8, reduceMotion: reduceMotion)

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
            ensureLiveMonitoring("MonitorView.onAppear")
            setMonitorPopupVisibility(true)
            appeared = true
        }
        .onDisappear {
            setMonitorPopupVisibility(false)
        }
        .onChange(of: isActive) { _, active in
            setMonitorPopupVisibility(active)
            if active {
                ensureLiveMonitoring("MonitorView active")
            }
        }
        .onChange(of: selectedRange) { _, range in
            if range == .live {
                ensureLiveMonitoring("MonitorView live selected")
            }
        }
    }

    /// GPU/Battery/Sensors readers are `popupOnly` in WidgetDataManager (they only sample while a
    /// menu-bar popover for that module is open). MonitorView renders live consoles for those
    /// modules too, so it must opt itself in/out of that visibility set. Bluetooth is excluded —
    /// MonitorView has no Bluetooth console.
    private func setMonitorPopupVisibility(_ visible: Bool) {
        for type: WidgetType in [.gpu, .battery, .sensors] {
            data.setPopupVisible(for: type, isVisible: visible)
        }
    }

    // Editorial range scope: FilterPills instead of the AppKit segmented control,
    // per spec §filter-pill ("monitoring scopes … time ranges").
    private var rangePicker: some View {
        HStack(spacing: TonicDS.Space.xs) {
            ForEach(ResourceHistoryRange.allCases) { range in
                FilterPill(title: range.displayName,
                           isActive: selectedRange == range) {
                    selectedRange = range
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Monitor history range")
    }

    // MARK: - Gauge bento

    @ViewBuilder
    private var metricsGrid: some View {
        if !hasMonitorSamples {
            monitorSkeleton
        } else {
            TonicBentoGrid(minTileWidth: 240) {
                GaugeCard(label: "CPU", fraction: cpu, displayValue: "", metricMode: .percent, history: cpuSeries)
                GaugeCard(label: "Memory", fraction: mem, displayValue: "", metricMode: .percent, history: memorySeries)
                GaugeCard(label: "Disk used", fraction: disk, displayValue: "", metricMode: .percent, supportingText: "\(diskFree) free", history: diskSeries)
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

    private var liveStartupCard: some View {
        DataCard {
            HStack(alignment: .center, spacing: TonicDS.Space.md) {
                VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                    MonoLabel(liveStartupStalled ? "Live data paused" : "Live data starting")
                    Text(liveStartupStalled
                         ? "Sampling hasn't produced data yet. Retry, or check module settings."
                         : "First CPU, memory, disk, and network samples arrive within a few seconds.")
                        .tonicType(.caption)
                        .foregroundStyle(TonicDS.Colors.textMuted)
                }
                Spacer(minLength: TonicDS.Space.md)
                if liveStartupStalled {
                    TextAction("Retry", color: TonicDS.Colors.linkBlue) {
                        ensureLiveMonitoring("MonitorView retry")
                    }
                } else {
                    ProgressView().controlSize(.small)
                }
            }
        }
        // Flip to the stalled state reactively; resets whenever a retry restamps
        // liveStartupDate.
        .task(id: liveStartupDate) {
            liveStartupStalled = false
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled { liveStartupStalled = true }
        }
    }

    private var historyEmptyNotice: some View {
        DataCard {
            VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                MonoLabel("No recorded history")
                Text("Nothing recorded for \(selectedRange.displayName) yet. History accrues while Tonic is running.")
                    .tonicType(.caption)
                    .foregroundStyle(TonicDS.Colors.textMuted)
            }
        }
    }

    /// Recent alerts Tonic has sent — notifications are transient, this list
    /// is the reviewable record (fed by NotificationManager into the log).
    @ViewBuilder
    private var alertHistory: some View {
        let alerts = ActivityLogStore.shared.entries
            .filter { $0.category == .notification }
            .prefix(6)
        if !alerts.isEmpty {
            VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                MonoLabel("Recent alerts")
                VStack(spacing: 0) {
                    ForEach(Array(alerts)) { event in
                        SystemListRow(
                            leading: {
                                Image(systemName: "bell")
                                    .font(.system(size: 13))
                                    .frame(width: 20)
                                    .foregroundStyle(TonicDS.Colors.textMuted)
                            },
                            center: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title).tonicType(.body)
                                        .foregroundStyle(TonicDS.Colors.textPrimary).lineLimit(1)
                                    Text(event.detail).tonicType(.caption)
                                        .foregroundStyle(TonicDS.Colors.textMuted).lineLimit(1)
                                }
                            },
                            trailing: {
                                Text(Self.alertTimeFormatter.string(from: event.timestamp))
                                    .tonicType(.monoLabel)
                                    .foregroundStyle(TonicDS.Colors.textMuted)
                            }
                        )
                        TonicHairline()
                    }
                }
            }
        }
    }

    private static let alertTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d HH:mm"
        return formatter
    }()

    private var rangeSummary: some View {
        TonicBentoGrid(minTileWidth: 240) {
            HistoricSummaryCard(label: "CPU", latest: pctValue(cpuPercentValue), average: pctValue(summary(.cpuPercent).average), peak: pctValue(summary(.cpuPercent).peak))
            HistoricSummaryCard(label: "Memory", latest: pctValue(memoryPercentValue), average: pctValue(summary(.memoryPercent).average), peak: pctValue(summary(.memoryPercent).peak))
            HistoricSummaryCard(label: "Down", latest: rate(networkDownloadValue), average: rate(summary(.networkDownloadBytesPerSecond).average), peak: rate(summary(.networkDownloadBytesPerSecond).peak))
            HistoricSummaryCard(label: "Up", latest: rate(networkUploadValue), average: rate(summary(.networkUploadBytesPerSecond).average), peak: rate(summary(.networkUploadBytesPerSecond).peak))
        }
    }

    // MARK: - Detail console wall

    @ViewBuilder
    private var detailConsoles: some View {
        if !hasAnyDetail {
            consoleSkeleton
                .tonicAppear(appeared, index: 7, reduceMotion: reduceMotion)
        } else {
            // CPU/memory/network consoles need live samples; battery stands alone,
            // so a battery-only startup shows just the battery console (no zeroed rows).
            TonicBentoGrid(minTileWidth: 320) {
                if hasMonitorSamples {
                    cpuConsole
                    memoryConsole
                }
                if gpuConsoleVisible { gpuConsole }
                if sensorsConsoleVisible { sensorsConsole }
                if batteryConsoleVisible { batteryConsole }
                if diskConsoleVisible { diskConsole }
                if hasMonitorSamples {
                    networkConsole
                }
            }
            .tonicAppear(appeared, index: 7, reduceMotion: reduceMotion)
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
                consoleHeader("CPU detail")
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
                    // "CPU limit", not "Thermal" — sits right under the Temperature row
                    // and names the consequence, not the cause.
                    consoleRow("CPU limit", "Throttled", TonicDS.Colors.statusCaution)
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
                consoleHeader("Memory detail")
                consoleRow("Usage", pct(mem) + "%", TonicDS.status(forFraction: mem))

                // Composition over total, using only fields the collector actually populates:
                // used (app+wired) minus compressed · compressed · free.
                let total = max(1, Double(data.memoryData.totalBytes))
                let compressed = Double(data.memoryData.compressedBytes)
                let used = Double(data.memoryData.usedBytes)
                let usedNonCompressed = max(0, used - compressed)
                let free = Double(data.memoryData.freeBytes ?? UInt64(max(0, total - used)))
                ConsoleBreakdownBar(segments: [
                    .init(fraction: usedNonCompressed / total, color: TonicDS.Colors.seriesAppMem),
                    .init(fraction: compressed / total, color: TonicDS.Colors.seriesCompressed),
                    .init(fraction: free / total, color: TonicDS.Colors.onDarkMuted)
                ])
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Memory: \(bytes(UInt64(usedNonCompressed))) used, \(bytes(data.memoryData.compressedBytes)) compressed, \(bytes(UInt64(free))) free")
                ConsoleLegend(items: [
                    .init(label: "Used", value: bytes(UInt64(usedNonCompressed)), color: TonicDS.Colors.seriesAppMem),
                    .init(label: "Compressed", value: bytes(data.memoryData.compressedBytes), color: TonicDS.Colors.seriesCompressed),
                    .init(label: "Free", value: bytes(UInt64(free)), color: TonicDS.Colors.onDarkMuted)
                ])

                consoleRow("Total", bytes(data.memoryData.totalBytes), TonicDS.Colors.onDark)
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
                consoleHeader("GPU detail")
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
                consoleHeader("Sensors & fans")
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
                consoleHeader("Battery detail")
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
                consoleHeader("Disk I/O")
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
                consoleHeader("Network detail")
                consoleRow("Down", rate(data.networkData.downloadBytesPerSecond), TonicDS.Chart.download)
                consoleRow("Up", rate(data.networkData.uploadBytesPerSecond), TonicDS.Chart.upload)
                if !data.networkDownloadHistory.isEmpty || !data.networkUploadHistory.isEmpty {
                    NetworkTrafficChart(
                        downloadData: Array(data.networkDownloadHistory.suffix(40)),
                        uploadData: Array(data.networkUploadHistory.suffix(40)),
                        height: 42,
                        mode: .popover,
                        lineWidth: 1.5
                    )
                    .clipShape(RoundedRectangle(cornerRadius: TonicDS.Radius.xs, style: .continuous))
                }
                Text("Today while open")
                    .tonicType(.caption)
                    .foregroundStyle(TonicDS.Colors.onDarkMuted)
                    .padding(.top, TonicDS.Space.xxs)
                consoleRow("Down total", bytes(data.totalDownloadBytes), TonicDS.Chart.download)
                consoleRow("Up total", bytes(data.totalUploadBytes), TonicDS.Chart.upload)
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

    /// Console annunciator header: mono label over an on-dark hairline — the same
    /// header grammar as the menu-bar popover consoles, so the two console families
    /// read as one surface and the header level stays distinct from the page's
    /// section label.
    private func consoleHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
            MonoLabel(title, color: TonicDS.Colors.onDarkMuted)
            TonicHairline(color: TonicDS.Colors.hairlineOnDark)
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

    private func clusterRow(_ label: String, values: [Double], color: Color) -> some View {
        let avg = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        return HStack(alignment: .center, spacing: TonicDS.Space.sm) {
            Text(label).tonicType(.body).foregroundStyle(TonicDS.Colors.onDarkMuted)
            ConsoleCoreBars(values: values, color: color)
                .frame(maxWidth: 180)
            Spacer(minLength: TonicDS.Space.xs)
            Text("\(Int(avg))%").tonicType(.monoLabel).monospacedDigit()
                .foregroundStyle(TonicDS.Colors.onDark)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), average \(Int(avg)) percent, \(values.count) cores")
    }

    private func consoleSparkline(_ history: [Double], color: Color) -> some View {
        NetworkSparklineChart(data: Array(history.suffix(40)), color: color, height: 34, showArea: true, lineWidth: 1.5)
            .clipShape(RoundedRectangle(cornerRadius: TonicDS.Radius.xs, style: .continuous))
    }

    // MARK: - Derived

    private var hasAnyDetail: Bool {
        hasMonitorSamples || data.batteryData.isPresent
    }

    private var hasMonitorSamples: Bool {
        if selectedRange == .live {
            return data.hasLiveMetricSample
        }
        return !history.samples(for: selectedRange).isEmpty
    }

    private func ensureLiveMonitoring(_ reason: String) {
        liveStartupDate = Date()
        data.ensureLiveMonitoring(reason: reason)
    }

    private var cpuSeries: [Double] {
        selectedRange == .live ? data.cpuHistory : history.chartSeries(for: .cpuPercent, range: selectedRange)
    }

    private var memorySeries: [Double] {
        selectedRange == .live ? data.memoryHistory : history.chartSeries(for: .memoryPercent, range: selectedRange)
    }

    private var diskSeries: [Double] {
        selectedRange == .live ? data.diskHistory : history.chartSeries(for: .diskUsedPercent, range: selectedRange)
    }

    private var networkDownloadSeries: [Double] {
        selectedRange == .live
            ? data.networkDownloadHistory
            : history.chartSeries(for: .networkDownloadBytesPerSecond, range: selectedRange)
    }

    private var networkUploadSeries: [Double] {
        selectedRange == .live
            ? data.networkUploadHistory
            : history.chartSeries(for: .networkUploadBytesPerSecond, range: selectedRange)
    }

    private var networkTrafficCardContext: NetworkTrafficCardContext {
        switch selectedRange {
        case .live:
            return .live(
                downTotal: bytes(data.totalDownloadBytes),
                upTotal: bytes(data.totalUploadBytes)
            )
        case .oneHour, .twentyFourHours:
            return .history(range: selectedRange)
        }
    }

    private var cpuPercentValue: Double {
        selectedRange == .live ? data.cpuData.totalUsage : summary(.cpuPercent).latest
    }

    private var memoryPercentValue: Double {
        selectedRange == .live ? data.memoryData.usagePercentage : summary(.memoryPercent).latest
    }

    private var diskPercentValue: Double {
        selectedRange == .live ? (boot?.usagePercentage ?? 0) : summary(.diskUsedPercent).latest
    }

    private var networkDownloadValue: Double {
        selectedRange == .live ? data.networkData.downloadBytesPerSecond : summary(.networkDownloadBytesPerSecond).latest
    }

    private var networkUploadValue: Double {
        selectedRange == .live ? data.networkData.uploadBytesPerSecond : summary(.networkUploadBytesPerSecond).latest
    }

    private var cpu: Double { min(1, max(0, cpuPercentValue / 100)) }
    private var mem: Double { min(1, max(0, memoryPercentValue / 100)) }
    private var boot: DiskVolumeData? { data.diskVolumes.first(where: { $0.isBootVolume }) ?? data.diskVolumes.first }
    private var disk: Double { min(1, max(0, diskPercentValue / 100)) }
    private var gpu: Double { min(1, max(0, (data.gpuHistory.last ?? 0) / 100)) }
    private var diskFree: String {
        guard let v = boot else { return "—" }
        return Self.fileByteFormatter.string(fromByteCount: Int64(v.freeBytes))
    }

    private func pct(_ f: Double) -> String { "\(Int((f * 100).rounded()))" }

    private func pctValue(_ value: Double) -> String { "\(Int(value.rounded()))%" }

    private func rate(_ bytesPerSecond: Double) -> String {
        Self.rateByteFormatter.string(fromByteCount: Int64(max(0, bytesPerSecond))) + "/s"
    }

    private func bytes(_ value: UInt64) -> String {
        Self.memoryByteFormatter.string(fromByteCount: Int64(value))
    }

    private func bytes(_ value: Int64) -> String {
        Self.memoryByteFormatter.string(fromByteCount: max(0, value))
    }

    private func summary(_ metric: ResourceMetricKind) -> ResourceMetricSummary {
        history.summary(for: metric, range: selectedRange)
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

    private static let rateByteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
        formatter.countStyle = .memory
        return formatter
    }()

    private static let memoryByteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter
    }()

    private static let fileByteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
}

// MARK: - Console primitives

private struct HistoricSummaryCard: View {
    let label: String
    let latest: String
    let average: String
    let peak: String

    var body: some View {
        DataCard {
            VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                MonoLabel(label)
                HStack(spacing: TonicDS.Space.lg) {
                    stat("Now", latest)
                    stat("Avg", average)
                    stat("Peak", peak)
                    Spacer(minLength: 0)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.xxs) {
            Text(title)
                .tonicType(.caption)
                .foregroundStyle(TonicDS.Colors.textMuted)
            Text(value)
                .tonicType(.monoLabel)
                .monospacedDigit()
                .foregroundStyle(TonicDS.Colors.textPrimary)
        }
    }
}

private struct NetworkTrafficCard: View {
    let label: String
    let downRate: String
    let upRate: String
    let downloadHistory: [Double]
    let uploadHistory: [Double]
    let context: NetworkTrafficCardContext

    var body: some View {
        DataCard {
            VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                header

                NetworkTrafficChart(
                    downloadData: downloadHistory,
                    uploadData: uploadHistory,
                    height: 64,
                    mode: .monitorCard,
                    lineWidth: 1.6
                )
                .clipShape(RoundedRectangle(cornerRadius: TonicDS.Radius.xs, style: .continuous))

                footer
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: TonicDS.Space.sm) {
                MonoLabel(label)
                Spacer(minLength: TonicDS.Space.xs)
                trafficMetric("Down", downRate, TonicDS.Chart.download)
                trafficMetric("Up", upRate, TonicDS.Chart.upload)
            }

            VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                MonoLabel(label)
                HStack(spacing: TonicDS.Space.md) {
                    trafficMetric("Down", downRate, TonicDS.Chart.download)
                    trafficMetric("Up", upRate, TonicDS.Chart.upload)
                }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch context.footer {
        case .sessionTotals(let downTotal, let upTotal, let label):
            ViewThatFits(in: .horizontal) {
                HStack(spacing: TonicDS.Space.lg) {
                    totalMetric("Down total", downTotal, TonicDS.Chart.download)
                    totalMetric("Up total", upTotal, TonicDS.Chart.upload)
                    Spacer(minLength: 0)
                    footerLabel(label)
                }

                VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                    HStack(spacing: TonicDS.Space.lg) {
                        totalMetric("Down total", downTotal, TonicDS.Chart.download)
                        totalMetric("Up total", upTotal, TonicDS.Chart.upload)
                    }
                    footerLabel(label)
                }
            }
        case .range(let label):
            footerLabel(label)
        }
    }

    private func trafficMetric(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: TonicDS.Space.xxs) {
            StatusDot(color)
            Text(label)
                .tonicType(.caption)
                .foregroundStyle(TonicDS.Colors.textMuted)
            Metric(value, color: color, role: .metricSmall)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    private func totalMetric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.xxs) {
            Text(label)
                .tonicType(.caption)
                .foregroundStyle(TonicDS.Colors.textMuted)
            Text(value)
                .tonicType(.monoLabel)
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    private func footerLabel(_ label: String) -> some View {
        Text(label)
            .tonicType(.caption)
            .foregroundStyle(TonicDS.Colors.textMuted)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }
}

struct NetworkTrafficCardContext: Equatable {
    enum Footer: Equatable {
        case sessionTotals(downTotal: String, upTotal: String, label: String)
        case range(String)
    }

    let footer: Footer

    var includesSessionTotals: Bool {
        if case .sessionTotals = footer { return true }
        return false
    }

    var rangeLabel: String? {
        if case .range(let label) = footer { return label }
        return nil
    }

    static func live(downTotal: String, upTotal: String) -> NetworkTrafficCardContext {
        NetworkTrafficCardContext(
            footer: .sessionTotals(
                downTotal: downTotal,
                upTotal: upTotal,
                label: "Today while open"
            )
        )
    }

    static func history(range: ResourceHistoryRange) -> NetworkTrafficCardContext {
        NetworkTrafficCardContext(footer: .range("History range: \(range.displayName)"))
    }
}
