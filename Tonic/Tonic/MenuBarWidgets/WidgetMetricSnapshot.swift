//
//  WidgetMetricSnapshot.swift
//  Tonic
//
//  Per-module popover console content: the snapshot reads WidgetDataManager
//  once per render and produces the value, status color, history series, and
//  block sequence the console draws. Blocks keep every module inside the
//  shared console grammar (rows, labels, charts, breakdowns, core bars).
//

import SwiftUI

extension WidgetType {
    /// Whether this module's popover leads with a history chart. Modules without
    /// a meaningful time series (bluetooth, clock, weather) skip the chart slot
    /// entirely instead of showing a permanent "waiting" skeleton.
    var expectsHistory: Bool {
        switch self {
        case .cpu, .memory, .network, .gpu, .battery, .sensors, .disk: return true
        case .bluetooth, .clock, .weather, .tonic: return false
        }
    }
}

/// A paired above/below-centerline history for directional charts:
/// network download/upload or disk read/write.
struct WidgetTrafficHistory {
    let primary: [Double]
    let secondary: [Double]
    let primaryColor: Color
    let secondaryColor: Color

    var isEmpty: Bool { primary.isEmpty && secondary.isEmpty }
}

struct WidgetPopoverRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    var statusColor: Color?
    /// When the color represents a machine-state level, carry it so VoiceOver
    /// hears the state word — color is never the only carrier of meaning.
    var level: TonicDS.StatusLevel?
}

/// One renderable unit of a popover console: a metric row, a mono section label,
/// an inline sparkline, a stacked breakdown bar + legend, or a per-core bar cluster.
/// The console composes these per widget so each module keeps its information
/// density without leaving the shared console grammar.
struct WidgetPopoverBlock: Identifiable {
    enum Kind {
        case row(WidgetPopoverRow)
        case label(String)
        case chart([Double], Color)
        case breakdown([ConsoleBreakdownBar.Segment], [ConsoleLegend.Item])
        case coreBars(String, [Double], Color)
    }

    let id = UUID()
    let kind: Kind

    static func row(_ label: String, _ value: String,
                    color: Color? = nil, level: TonicDS.StatusLevel? = nil) -> WidgetPopoverBlock {
        WidgetPopoverBlock(kind: .row(WidgetPopoverRow(label: label, value: value,
                                                       statusColor: color, level: level)))
    }

    static func label(_ text: String) -> WidgetPopoverBlock {
        WidgetPopoverBlock(kind: .label(text))
    }

    static func chart(_ data: [Double], _ color: Color) -> WidgetPopoverBlock {
        WidgetPopoverBlock(kind: .chart(data, color))
    }

    static func breakdown(_ segments: [ConsoleBreakdownBar.Segment],
                          legend: [ConsoleLegend.Item]) -> WidgetPopoverBlock {
        WidgetPopoverBlock(kind: .breakdown(segments, legend))
    }

    static func coreBars(_ label: String, _ values: [Double], _ color: Color) -> WidgetPopoverBlock {
        WidgetPopoverBlock(kind: .coreBars(label, values, color))
    }
}

struct WidgetMetricSnapshot {
    let value: String
    let color: Color
    let iconColor: Color
    let history: [Double]
    /// Paired directional history (network down/up, disk read/write); nil for
    /// single-series modules.
    let traffic: WidgetTrafficHistory?
    let blocks: [WidgetPopoverBlock]

    @MainActor
    init(widgetType: WidgetType, configuration: WidgetConfiguration, dataManager: WidgetDataManager,
         historyRange: ResourceHistoryRange = .live) {
        let usePercent = configuration.valueFormat == .percentage
        self.iconColor = TonicDS.Colors.textMuted
        // Chart history window from the persisted popover settings (~2s sample cadence
        // while a popover is open), so the Popup settings panel actually drives the chart.
        let keep = max(15, PopupSettingsStore.shared.settings.chartHistoryDuration / 2)
        let longTerm = historyRange == .live ? [] : LongTermMetricsStore.shared.samples(for: historyRange)

        switch widgetType {
        case .network:
            traffic = WidgetTrafficHistory(
                primary: historyRange == .live ? Array(dataManager.networkDownloadHistory.suffix(keep))
                    : longTerm.map(\.networkDownloadBytesPerSecond),
                secondary: historyRange == .live ? Array(dataManager.networkUploadHistory.suffix(keep))
                    : longTerm.map(\.networkUploadBytesPerSecond),
                primaryColor: TonicDS.Chart.download,
                secondaryColor: TonicDS.Chart.upload
            )
        case .disk:
            traffic = WidgetTrafficHistory(
                primary: historyRange == .live ? Array(dataManager.diskReadHistory.suffix(keep))
                    : longTerm.map(\.diskReadBytesPerSecond),
                secondary: historyRange == .live ? Array(dataManager.diskWriteHistory.suffix(keep))
                    : longTerm.map(\.diskWriteBytesPerSecond),
                primaryColor: TonicDS.Chart.read,
                secondaryColor: TonicDS.Chart.write
            )
        default:
            traffic = nil
        }

        switch widgetType {
        case .cpu:
            let cpu = dataManager.cpuData
            let usage = cpu.totalUsage
            value = usePercent ? "\(Int(usage))%" : String(format: "%.1fGHz", 3.0 * usage / 100)
            color = TonicDS.Chart.utilization(usage)
            history = historyRange == .live ? Array(dataManager.cpuHistory.suffix(keep)) : longTerm.map(\.cpuPercent)

            var built: [WidgetPopoverBlock] = [
                .row("Total", "\(Int(usage))%", color: color,
                     level: TonicDS.statusLevel(forFraction: usage / 100)),
                .row("User", "\(Int(cpu.userUsage))%", color: TonicDS.Chart.cpuUser),
                .row("System", "\(Int(cpu.systemUsage))%", color: TonicDS.Chart.cpuSystem),
                .row("Idle", "\(Int(max(0, 100 - usage)))%", color: TonicDS.Chart.cpuIdle)
            ]
            if let e = cpu.eCoreUsage, !e.isEmpty {
                built.append(.coreBars("E-cores", e, TonicDS.Colors.seriesEcore))
            }
            if let p = cpu.pCoreUsage, !p.isEmpty {
                built.append(.coreBars("P-cores", p, TonicDS.Colors.seriesPcore))
            }
            if (cpu.eCoreUsage?.isEmpty ?? true), (cpu.pCoreUsage?.isEmpty ?? true),
               !cpu.perCoreUsage.isEmpty {
                built.append(.coreBars("Cores", cpu.perCoreUsage, TonicDS.Colors.seriesUser))
            }
            if let procs = cpu.topProcesses?.prefix(3), !procs.isEmpty {
                built.append(.label("Top processes"))
                for proc in procs {
                    built.append(.row(proc.name, "\(Int(proc.cpuUsage ?? 0))%"))
                }
            }
            if let t = cpu.temperature {
                built.append(.row("Temperature", "\(Int(t))°C",
                                  color: TonicDS.status(forTempC: t),
                                  level: TonicDS.statusLevel(forTempC: t)))
            }
            if cpu.thermalLimit == true {
                built.append(.row("CPU limit", "Throttled",
                                  color: TonicDS.Colors.statusCaution, level: .caution))
            }
            if let f = cpu.frequency {
                built.append(.row("Frequency", String(format: "%.2f GHz", f)))
            }
            if let load = cpu.averageLoad, load.count >= 3 {
                built.append(.row("Load avg", String(format: "%.2f · %.2f · %.2f", load[0], load[1], load[2])))
            }
            if cpu.uptime > 0 {
                built.append(.row("Uptime", Self.uptime(cpu.uptime)))
            }
            blocks = built

        case .memory:
            let memory = dataManager.memoryData
            let usage = memory.usagePercentage
            let usedGB = Double(memory.usedBytes) / 1_073_741_824
            value = usePercent ? "\(Int(usage))%" : String(format: "%.1fGB", usedGB)
            color = TonicDS.Chart.utilization(usage)
            history = historyRange == .live ? Array(dataManager.memoryHistory.suffix(keep)) : longTerm.map(\.memoryPercent)

            // Composition over total: used-minus-compressed · compressed · free —
            // the same honest segments the Monitor console draws.
            let total = max(1, Double(memory.totalBytes))
            let compressed = Double(memory.compressedBytes)
            let used = Double(memory.usedBytes)
            let usedNonCompressed = max(0, used - compressed)
            let free = Double(memory.freeBytes ?? UInt64(max(0, total - used)))

            var built: [WidgetPopoverBlock] = [
                .breakdown([
                    .init(fraction: usedNonCompressed / total, color: TonicDS.Colors.seriesAppMem),
                    .init(fraction: compressed / total, color: TonicDS.Colors.seriesCompressed),
                    .init(fraction: free / total, color: TonicDS.Colors.onDarkMuted)
                ], legend: [
                    .init(label: "Used", value: Self.bytes(UInt64(usedNonCompressed)), color: TonicDS.Colors.seriesAppMem),
                    .init(label: "Compr", value: Self.bytes(memory.compressedBytes), color: TonicDS.Colors.seriesCompressed),
                    .init(label: "Free", value: Self.bytes(UInt64(free)), color: TonicDS.Colors.onDarkMuted)
                ]),
                .row("Used", Self.bytes(memory.usedBytes), color: color,
                     level: TonicDS.statusLevel(forFraction: usage / 100)),
                .row("Total", Self.bytes(memory.totalBytes)),
                .row("Pressure", memory.pressure.rawValue,
                     color: memory.pressure.color, level: Self.pressureLevel(memory.pressure))
            ]
            let swapTotal = memory.swapTotalBytes ?? 0
            if memory.swapBytes > 0 || swapTotal > 0 {
                let swapFraction = swapTotal > 0 ? Double(memory.swapBytes) / Double(swapTotal) : 0
                built.append(.row("Swap", Self.bytes(memory.swapBytes),
                                  color: TonicDS.status(forFraction: swapFraction),
                                  level: TonicDS.statusLevel(forFraction: swapFraction)))
            }
            if let procs = memory.topProcesses?.prefix(3), !procs.isEmpty {
                built.append(.label("Top processes"))
                for proc in procs {
                    built.append(.row(proc.name, proc.memoryString))
                }
            }
            blocks = built

        case .disk:
            if let primary = dataManager.diskVolumes.first {
                let freeGB = primary.freeBytes / 1_073_741_824
                let usage = primary.usagePercentage
                value = usePercent ? "\(Int(usage))%" : "\(freeGB)GB"
                color = TonicDS.Chart.utilization(usage)
                history = []

                var built: [WidgetPopoverBlock] = []
                for volume in dataManager.diskVolumes.prefix(3) {
                    let fraction = volume.usagePercentage / 100
                    let volumeColor = TonicDS.status(forFraction: fraction)
                    built.append(.label(volume.isBootVolume ? "\(volume.name) · Boot" : volume.name))
                    built.append(.breakdown([
                        .init(fraction: fraction, color: volumeColor)
                    ], legend: [
                        .init(label: "Used", value: Self.bytes(volume.usedBytes), color: volumeColor),
                        .init(label: "Free", value: Self.bytes(volume.freeBytes), color: TonicDS.Colors.onDarkMuted)
                    ]))
                    if let read = volume.readThroughputString {
                        built.append(.row("Read", read, color: TonicDS.Chart.read))
                    }
                    if let write = volume.writeThroughputString {
                        built.append(.row("Write", write, color: TonicDS.Chart.write))
                    }
                    if let riops = volume.readIOPS, let wiops = volume.writeIOPS {
                        built.append(.row("IOPS", "\(Int(riops)) r · \(Int(wiops)) w"))
                    }
                }
                if let procs = dataManager.diskVolumes.first(where: \.isBootVolume)?.topProcesses?.prefix(3),
                   !procs.isEmpty {
                    built.append(.label("Top processes"))
                    for proc in procs {
                        let read = proc.diskReadBytes ?? 0
                        let write = proc.diskWriteBytes ?? 0
                        built.append(.row(proc.name, Self.rate(read + write)))
                    }
                }
                blocks = built
            } else {
                value = "--"; color = TonicDS.Colors.textMuted; history = []
                blocks = [.row("Disk", "No data")]
            }

        case .network:
            let network = dataManager.networkData
            let uploadDominant = network.uploadBytesPerSecond > network.downloadBytesPerSecond
            value = uploadDominant
                ? "↑ \(network.uploadString)"
                : "↓ \(network.downloadString)"
            color = network.isConnected
                ? (uploadDominant ? TonicDS.Chart.upload : TonicDS.Chart.download)
                : TonicDS.Colors.statusWarning
            history = historyRange == .live ? Array(dataManager.networkDownloadHistory.suffix(keep))
                : longTerm.map(\.networkDownloadBytesPerSecond)

            var built: [WidgetPopoverBlock] = [
                .row("Down", network.downloadString, color: TonicDS.Chart.download),
                .row("Up", network.uploadString, color: TonicDS.Chart.upload),
                .row("State", network.isConnected ? "Connected" : "Offline",
                     color: network.isConnected ? TonicDS.Colors.statusInfo : TonicDS.Colors.statusWarning,
                     level: network.isConnected ? .info : .warning)
            ]
            if let procs = network.topProcesses?.prefix(3), !procs.isEmpty {
                built.append(.label("Top apps"))
                for proc in procs {
                    built.append(.row(proc.name,
                                      "↓ \(Self.rate(proc.downloadBytes)) · ↑ \(Self.rate(proc.uploadBytes))"))
                }
            }
            built.append(.label("Today while open"))
            built.append(.row("Down total", Self.bytes(dataManager.totalDownloadBytes), color: TonicDS.Chart.download))
            built.append(.row("Up total", Self.bytes(dataManager.totalUploadBytes), color: TonicDS.Chart.upload))

            if let wifi = network.wifiDetails {
                built.append(.label("Wi-Fi"))
                built.append(.row("Network", wifi.ssid))
                built.append(.row("Signal", "\(wifi.rssi) dBm · SNR \(wifi.rssi - wifi.noise)"))
                built.append(.row("Channel", "\(wifi.channel) · \(wifi.channelWidth) MHz · \(wifi.band.displayName)"))
            }
            if network.ipAddress != nil || network.publicIP != nil || network.interfaceName != nil {
                built.append(.label("Addresses"))
                if let ip = network.ipAddress { built.append(.row("Local IP", ip)) }
                if let publicIP = network.publicIP { built.append(.row("Public IP", publicIP.ipAddress)) }
                if let iface = network.interfaceName, !iface.isEmpty {
                    let link = network.linkSpeedMbps.map { " · \(Int($0)) Mbps" } ?? ""
                    built.append(.row("Interface", iface + link))
                }
            }
            blocks = built

        case .gpu:
            let gpu = dataManager.gpuData
            if let usage = gpu.usagePercentage {
                value = usePercent ? "\(Int(usage))%" : String(format: "%.1fGHz", 1.0 + usage / 100)
                color = TonicDS.Chart.utilization(usage)
                history = historyRange == .live ? Array(dataManager.gpuHistory.suffix(keep))
                    : longTerm.compactMap(\.gpuPercent)

                var built: [WidgetPopoverBlock] = [
                    .row("Utilization", "\(Int(usage))%", color: color,
                         level: TonicDS.statusLevel(forFraction: usage / 100))
                ]
                if let r = gpu.renderUtilization {
                    built.append(.row("Render", "\(Int(r))%", color: TonicDS.Chart.utilization(r)))
                }
                if let t = gpu.tilerUtilization {
                    built.append(.row("Tiler", "\(Int(t))%", color: TonicDS.Chart.utilization(t)))
                }
                if let mem = gpu.memoryUsagePercentage {
                    built.append(.row("VRAM", "\(Int(mem))%", color: TonicDS.Chart.utilization(mem)))
                }
                if let t = gpu.temperature {
                    built.append(.row("Temperature", "\(Int(t))°C",
                                      color: TonicDS.status(forTempC: t),
                                      level: TonicDS.statusLevel(forTempC: t)))
                }
                if let clock = gpu.coreClock, clock > 0 {
                    built.append(.row("Core clock", "\(Int(clock)) MHz"))
                }
                if let fan = gpu.fanSpeed, fan > 0 {
                    built.append(.row("Fan", "\(fan) RPM"))
                }
                if gpu.model != nil || gpu.cores != nil {
                    built.append(.label("Hardware"))
                    if let model = gpu.model { built.append(.row("Model", model)) }
                    if let cores = gpu.cores { built.append(.row("Cores", "\(cores)")) }
                }
                blocks = built
            } else {
                value = "--"; color = TonicDS.Colors.textMuted; history = []
                blocks = [.row("GPU", "Unavailable on this hardware or build")]
            }

        case .weather:
            let service = WeatherService.shared
            if let weather = service.currentWeather {
                let unit = service.temperatureUnit
                let current = weather.current
                value = current.temperature.formattedTemperature(unit: unit)
                color = TonicDS.Colors.onDark
                history = []

                var built: [WidgetPopoverBlock] = [
                    .row("Condition", current.condition.displayName),
                    .row("Feels like", current.feelsLike.formattedTemperature(unit: unit)),
                    .row("Humidity", "\(Int(current.humidity))%"),
                    .row("Wind", "\(Int(current.windSpeed)) km/h")
                ]
                if current.uvIndex > 0 {
                    built.append(.row("UV index", String(format: "%.0f", current.uvIndex)))
                }
                let upcoming = weather.hourly.filter { $0.time > Date() }.prefix(4)
                if !upcoming.isEmpty {
                    built.append(.label("Next hours"))
                    for hour in upcoming {
                        built.append(.row(hour.hourString, hour.temperature.formattedTemperature(unit: unit)))
                    }
                }
                let days = weather.daily.prefix(5)
                if !days.isEmpty {
                    built.append(.label("This week"))
                    for day in days {
                        built.append(.row(day.isToday ? "Today" : day.dayName,
                                          "\(day.highTemp.formattedTemperature(unit: unit)) / \(day.lowTemp.formattedTemperature(unit: unit))"))
                    }
                }
                built.append(.row("Location", current.locationName))
                blocks = built
            } else {
                value = "--"; color = TonicDS.Colors.textMuted; history = []
                blocks = [
                    .row("Status", "Waiting for weather data"),
                    .row("Location access", "Required for local weather")
                ]
            }

        case .battery:
            let battery = dataManager.batteryData
            if battery.isPresent {
                value = usePercent ? "\(Int(battery.chargePercentage))%" : Self.remainingTime(minutes: battery.estimatedMinutesRemaining)
                color = TonicDS.Chart.battery(level: battery.chargePercentage, isCharging: battery.isCharging)
                history = Array(dataManager.batteryHistory.suffix(keep))

                let level = TonicDS.statusLevel(forBattery: battery.chargePercentage / 100,
                                                isCharging: battery.isCharging)
                var built: [WidgetPopoverBlock] = [
                    .row("Charge", "\(Int(battery.chargePercentage))%", color: color, level: level),
                    .row("State", battery.isCharged ? "Charged" : (battery.isCharging ? "Charging" : "On battery"),
                         color: battery.isCharging ? TonicDS.Colors.statusInfo : nil,
                         level: battery.isCharging ? .info : nil),
                    .row(battery.isCharging ? "To full" : "Remaining",
                         Self.remainingTime(minutes: battery.estimatedMinutesRemaining))
                ]

                if battery.batteryPower != nil || battery.amperage != nil || battery.voltage != nil {
                    built.append(.label("Electrical"))
                    if let power = battery.batteryPower {
                        built.append(.row("Power", String(format: "%.1f W", power)))
                    }
                    if let amps = battery.amperage {
                        built.append(.row("Amperage", String(format: "%.0f mA", amps)))
                    }
                    if let volts = battery.voltage {
                        built.append(.row("Voltage", String(format: "%.2f V", volts)))
                    }
                }

                built.append(.label("Capacity"))
                if let maxCap = battery.maxCapacity, let designCap = battery.designedCapacity, designCap > 0 {
                    let healthFraction = Double(maxCap) / Double(designCap)
                    built.append(.row("Health", "\(Int(healthFraction * 100))% of design",
                                      color: TonicDS.status(forBattery: healthFraction, isCharging: false),
                                      level: TonicDS.statusLevel(forBattery: healthFraction, isCharging: false)))
                } else {
                    built.append(.row("Health", battery.health.rawValue))
                }
                if let cycles = battery.cycleCount {
                    built.append(.row("Cycles", "\(cycles)"))
                }
                if let temp = battery.temperature {
                    built.append(.row("Temperature", "\(Int(temp))°C",
                                      color: TonicDS.status(forTempC: temp),
                                      level: TonicDS.statusLevel(forTempC: temp)))
                }

                if battery.isCharging, let watts = battery.chargerWattage {
                    built.append(.label("Adapter"))
                    built.append(.row("Wattage", String(format: "%.0f W", watts)))
                    if let optimized = battery.optimizedCharging {
                        built.append(.row("Optimized charging", optimized ? "On" : "Off"))
                    }
                }
                blocks = built
            } else {
                value = "--"; color = TonicDS.Colors.textMuted; history = []
                blocks = [.row("Battery", "Not present")]
            }

        case .sensors:
            let sensors = dataManager.sensorsData
            if let hottest = sensors.temperatures.map(\.value).max() {
                value = "\(Int(hottest))°"
                color = TonicDS.Chart.temperature(hottest)
            } else if let fan = sensors.fans.map(\.rpm).max() {
                value = "\(fan)RPM"
                color = TonicDS.Colors.statusInfo
            } else {
                value = "--"
                color = TonicDS.Colors.textMuted
            }
            history = historyRange == .live ? Array(dataManager.sensorsHistory.suffix(keep))
                : longTerm.compactMap(\.temperatureC)

            var built: [WidgetPopoverBlock] = []
            let temps = sensors.temperatures.sorted { $0.value > $1.value }.prefix(8)
            if !temps.isEmpty {
                built.append(.label("Temperatures"))
                for reading in temps {
                    built.append(.row(reading.name, "\(Int(reading.value))°C",
                                      color: TonicDS.status(forTempC: reading.value),
                                      level: TonicDS.statusLevel(forTempC: reading.value)))
                }
            }
            if !sensors.fans.isEmpty {
                built.append(.label("Fans"))
                for fan in sensors.fans {
                    let detail = fan.modeString.map { "\(fan.rpm) RPM · \($0)" } ?? "\(fan.rpm) RPM"
                    if let pct = fan.speedPercentage {
                        built.append(.row(fan.name, detail,
                                          color: TonicDS.status(forFraction: pct / 100),
                                          level: TonicDS.statusLevel(forFraction: pct / 100)))
                    } else {
                        built.append(.row(fan.name, detail, color: TonicDS.Colors.statusInfo))
                    }
                }
            }
            if built.isEmpty {
                built.append(.row("Sensors", "Unavailable on this hardware or build"))
            }
            blocks = built

        case .bluetooth:
            let bluetooth = dataManager.bluetoothData
            if bluetooth.isBluetoothEnabled {
                let devices = bluetooth.connectedDevices
                if let device = bluetooth.devicesWithBattery.first,
                   let battery = device.primaryBatteryLevel {
                    value = "\(battery)%"
                    color = TonicDS.Chart.battery(level: Double(battery))
                } else {
                    value = "\(devices.count)"
                    color = devices.count > 0 ? TonicDS.Colors.statusInfo : TonicDS.Colors.textMuted
                }

                if devices.isEmpty {
                    blocks = [.row("Devices", "None connected")]
                } else {
                    var built: [WidgetPopoverBlock] = [.label("Connected")]
                    for device in devices {
                        if device.batteryLevels.isEmpty {
                            built.append(.row(device.name, "Connected"))
                        } else {
                            let detail = device.batteryLevels
                                .map { "\($0.label) \($0.percentage)%" }
                                .joined(separator: " · ")
                            let lowest = Double(device.batteryLevels.map(\.percentage).min() ?? 100)
                            built.append(.row(device.name, detail,
                                              color: TonicDS.Chart.battery(level: lowest),
                                              level: TonicDS.statusLevel(forBattery: lowest / 100, isCharging: false)))
                        }
                    }
                    blocks = built
                }
            } else {
                value = "Off"; color = TonicDS.Colors.statusWarning
                blocks = [.row("Bluetooth", "Off", color: TonicDS.Colors.statusWarning, level: .warning)]
            }
            history = []

        case .clock:
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            value = formatter.string(from: Date())
            color = TonicDS.Colors.onDark
            history = []
            blocks = ClockPreferences.shared.enabledEntries.map {
                .row($0.name, Self.timeString(for: $0.timezone))
            }

        case .tonic:
            // Tonic's own status: health score, space recovered, maintenance.
            let score = HealthScoreHistoryStore.shared.recentScores(days: 30).last?.score
            value = score.map { "\($0)" } ?? "—"
            color = score.map { TonicDS.status(forFraction: 1 - Double($0) / 100) } ?? TonicDS.Colors.onDarkMuted
            history = []
            let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
            let recovered = CleanupHistoryStore.shared.batches
                .filter { $0.date >= cutoff }
                .flatMap(\.entries)
                .reduce(Int64(0)) { $0 + $1.size }
            var built: [WidgetPopoverBlock] = [
                .row("Health score", score.map { "\($0)" } ?? "Run a scan", color: color),
                .row("Recovered · 7d", Self.bytes(recovered)),
            ]
            if let last = MaintenanceScheduler.shared.lastRunDate {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                built.append(.row("Maintenance", formatter.localizedString(for: last, relativeTo: Date())))
            } else {
                built.append(.row("Maintenance", MaintenanceScheduler.shared.cadence == .off ? "Off" : "Scheduled"))
            }
            blocks = built
        }
    }

    private static func remainingTime(minutes: Int?) -> String {
        guard let minutes else { return "--" }
        let hours = minutes / 60
        let mins = minutes % 60
        return hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
    }

    private static func timeString(for timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    private static func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .memory)
    }

    private static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(0, value), countStyle: .memory)
    }

    private static func rate(_ bytesPerSecond: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .memory) + "/s"
    }

    private static func uptime(_ interval: TimeInterval) -> String {
        let days = Int(interval) / 86_400
        let hours = (Int(interval) % 86_400) / 3_600
        let minutes = (Int(interval) % 3_600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private static func pressureLevel(_ pressure: MemoryPressure) -> TonicDS.StatusLevel {
        switch pressure {
        case .normal: return .success
        case .warning: return .warning
        case .critical: return .critical
        }
    }
}
