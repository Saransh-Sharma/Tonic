//
//  WidgetStatusItem.swift
//  Tonic
//
//  Base NSStatusItem wrapper for menu bar widgets
//  Task ID: fn-2.3
//

import AppKit
import SwiftUI
import os

// MARK: - Widget Status Item

/// Base class for managing a single widget's NSStatusItem
/// Each widget type creates its own instance to manage its menu bar presence
@MainActor
public class WidgetStatusItem: NSObject, ObservableObject, NSPopoverDelegate {

    private let logger = Logger(subsystem: "com.tonic.app", category: "WidgetStatusItem")

    // MARK: - Properties

    /// The NSStatusItem for this widget
    public private(set) var statusItem: NSStatusItem?

    /// The widget type this item represents
    public let widgetType: WidgetType

    /// Configuration for this widget
    @Published public var configuration: WidgetConfiguration

    /// Whether this widget is visible in the menu bar
    @Published public var isVisible: Bool = false

    /// Popover for showing detail view
    private var popover: NSPopover?

    /// Hosting controller for the compact view (type-erased)
    private var anyHostingController: NSHostingController<AnyView>?

    /// Data manager reference
    private var dataManager: WidgetDataManager {
        WidgetDataManager.shared
    }

    // MARK: - Initialization

    public init(widgetType: WidgetType, configuration: WidgetConfiguration) {
        self.widgetType = widgetType
        self.configuration = configuration

        logger.info("🔵 Initializing widget: \(widgetType.rawValue), enabled: \(configuration.isEnabled)")
        super.init()
        setupStatusItem()
        setupPopover()
        // Note: WidgetDataManager (@Observable) triggers SwiftUI view updates automatically
    }

    deinit {
        // Clean up status item on main thread
        MainActor.assumeIsolated {
            if let statusItem = self.statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
        }
    }

    // MARK: - Setup

    private func setupStatusItem() {
        guard self.configuration.isEnabled else {
            self.logger.warning("⚠️ setupStatusItem skipped - widget disabled: \(self.widgetType.rawValue)")
            return
        }

        self.logger.info("➕ setupStatusItem for \(self.widgetType.rawValue)")
        // Create status item with variable length based on display mode
        let length = self.configuration.displayMode.estimatedWidth

        self.statusItem = NSStatusBar.system.statusItem(withLength: length)
        self.logger.info("✅ StatusItem created for \(self.widgetType.rawValue), length: \(length)")

        if let button = self.statusItem?.button {
            button.target = self
            button.action = #selector(statusBarButtonClicked)

            // Set up the compact view
            self.updateCompactView()
            self.logger.info("✅ Button configured for \(self.widgetType.rawValue)")
        } else {
            self.logger.error("❌ Failed to get button for \(self.widgetType.rawValue)")
        }

        self.isVisible = true
    }

    private func setupPopover() {
        popover = NSPopover()
        popover?.behavior = .transient
        // Disable animation to prevent _NSWindowTransformAnimation crashes.
        // Transient popovers auto-dismiss when another window gains focus;
        // the close animation's dealloc can race with the popover window's
        // deallocation, causing EXC_BAD_ACCESS in objc_release.
        popover?.animates = false
        popover?.delegate = self

        // Content will be set by subclasses
    }

    // MARK: - View Updates

    private func updateCompactView() {
        guard let button = statusItem?.button else { return }

        // Create SwiftUI compact view (override in subclasses)
        let compactView = createCompactView()

        anyHostingController = NSHostingController(rootView: AnyView(compactView))

        // Embed in button
        if let hostedView = anyHostingController?.view {
            hostedView.translatesAutoresizingMaskIntoConstraints = false
            button.subviews.forEach { $0.removeFromSuperview() }
            button.addSubview(hostedView)

            NSLayoutConstraint.activate([
                hostedView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                hostedView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                hostedView.topAnchor.constraint(equalTo: button.topAnchor),
                hostedView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
            ])
        }

        // Log the update with data values
        logCurrentData()
    }

    private func logCurrentData() {
        let dataManager = WidgetDataManager.shared
        switch self.widgetType {
        case .cpu:
            self.logger.debug("🔄 \(self.widgetType.rawValue) view updated - CPU: \(Int(dataManager.cpuData.totalUsage))%")
        case .memory:
            self.logger.debug("🔄 \(self.widgetType.rawValue) view updated - Memory: \(Int(dataManager.memoryData.usagePercentage))%")
        case .disk:
            if let primary = dataManager.diskVolumes.first {
                self.logger.debug("🔄 \(self.widgetType.rawValue) view updated - Disk: \(Int(primary.usagePercentage))%")
            } else {
                self.logger.debug("🔄 \(self.widgetType.rawValue) view updated - No disk data")
            }
        case .network:
            self.logger.debug("🔄 \(self.widgetType.rawValue) view updated - Connected: \(dataManager.networkData.isConnected), Download: \(dataManager.networkData.downloadString)")
        case .gpu:
            if let usage = dataManager.gpuData.usagePercentage {
                self.logger.debug("🔄 \(self.widgetType.rawValue) view updated - GPU: \(Int(usage))%")
            } else {
                self.logger.debug("🔄 \(self.widgetType.rawValue) view updated - No GPU data")
            }
        case .battery:
            self.logger.debug("🔄 \(self.widgetType.rawValue) view updated - Battery: \(Int(dataManager.batteryData.chargePercentage))%, Present: \(dataManager.batteryData.isPresent)")
        case .weather:
            self.logger.debug("🔄 \(self.widgetType.rawValue) view updated")
        case .sensors:
            self.logger.debug("🔄 \(self.widgetType.rawValue) view updated - Sensors: \(dataManager.sensorsData.temperatures.count) temps")
        case .bluetooth:
            self.logger.debug("🔄 \(self.widgetType.rawValue) view updated - Bluetooth: \(dataManager.bluetoothData.connectedDevices.count) connected, enabled: \(dataManager.bluetoothData.isBluetoothEnabled)")
        case .clock:
            self.logger.debug("🔄 \(self.widgetType.rawValue) view updated - Clock: \(ClockPreferences.shared.enabledEntries.count) timezones")
        }
    }

    /// Create the compact view for this widget (override in subclasses)
    open func createCompactView() -> AnyView {
        AnyView(
            WidgetCompactView(
                widgetType: widgetType,
                configuration: configuration
            )
        )
    }

    /// Update the status item width based on display mode
    public func updateWidth() {
        let newLength = configuration.displayMode.estimatedWidth
        statusItem?.length = newLength
    }

    /// Update the configuration and refresh the view
    public func updateConfiguration(_ newConfig: WidgetConfiguration) {
        let oldFormat = configuration.valueFormat.rawValue
        let oldMode = configuration.displayMode.rawValue

        configuration = newConfig

        logger.info("🔧 updateConfiguration for \(self.widgetType.rawValue): format \(oldFormat)→\(newConfig.valueFormat.rawValue), mode \(oldMode)→\(newConfig.displayMode.rawValue)")

        if newConfig.isEnabled && !isVisible {
            // Widget was re-enabled
            logger.info("🔄 Widget re-enabled, setting up status item")
            setupStatusItem()
        } else if !newConfig.isEnabled && isVisible {
            // Widget was disabled
            logger.info("🔄 Widget disabled, removing status item")
            removeStatusItem()
        } else if isVisible, let button = statusItem?.button {
            // Configuration changed - force view refresh
            // Early return if not visible or no button (avoid work for hidden widgets)
            objectWillChange.send()

            // Use centralized view update method
            updateCompactView()

            // Update width based on display mode
            updateWidth()

            // Force NSView redraw - fixes menu bar refresh bug where objectWillChange.send()
            // doesn't trigger NSView to update properly
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                // Force redraw of the button in its own coordinate space
                button.setNeedsDisplay(button.bounds)
                button.displayIfNeeded()

                // Also force redraw the button's subviews directly
                for subview in button.subviews {
                    subview.setNeedsDisplay(subview.bounds)
                    subview.displayIfNeeded()
                }

                // Force window content view to redraw if available
                if let contentView = button.window?.contentView {
                    contentView.setNeedsDisplay(contentView.bounds)
                    contentView.displayIfNeeded()
                }

                self.logger.debug("🔄 Forced NSView redraw for \(self.widgetType.rawValue)")
            }

            logger.info("✏️ Updated widget \(self.widgetType.rawValue): displayMode=\(newConfig.displayMode.rawValue), valueFormat=\(newConfig.valueFormat.rawValue)")
        }
    }

    // MARK: - Popover Management

    private func showPopover() {
        guard let button = statusItem?.button,
              let popover = popover else { return }

        // Update popover content with latest data
        popover.contentViewController = NSHostingController(
            rootView: createDetailView()
        )

        dataManager.setPopupVisible(for: widgetType, isVisible: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func hidePopover() {
        dataManager.setPopupVisible(for: widgetType, isVisible: false)
        popover?.performClose(nil)
    }

    /// Explicitly close the popover and update data manager state.
    /// Used before opening another window (e.g. Settings) to ensure the
    /// popover is fully dismissed before focus changes.
    public func closePopoverImmediately() {
        guard let popover = popover, popover.isShown else { return }
        dataManager.setPopupVisible(for: widgetType, isVisible: false)
        popover.performClose(nil)
    }

    /// Create the detail view for this widget (to be overridden by subclasses)
    open func createDetailView() -> AnyView {
        AnyView(WidgetDetailViewPlaceholder(widgetType: widgetType))
    }

    // MARK: - Actions

    @objc private func statusBarButtonClicked() {
        if let popover = popover, popover.isShown {
            hidePopover()
        } else {
            showPopover()
        }
    }

    // MARK: - Lifecycle

    private func removeStatusItem() {
        dataManager.setPopupVisible(for: widgetType, isVisible: false)
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
        isVisible = false
    }

    /// Show this widget in the menu bar
    public func show() {
        guard !isVisible else { return }
        setupStatusItem()
    }

    /// Hide this widget from the menu bar
    public func hide() {
        guard isVisible else { return }
        removeStatusItem()
    }

    /// Refresh the widget display with latest data
    public func refresh() {
        guard let button = statusItem?.button else { return }

        objectWillChange.send()
        updateCompactView()

        // Force NSView redraw - ensures menu bar updates with latest data
        Task { @MainActor in
            // button is guaranteed to be non-nil from the guard above
            // Redraw of the button in its own coordinate space

            // Force redraw of the button in its own coordinate space
            button.setNeedsDisplay(button.bounds)
            button.displayIfNeeded()

            // Also force redraw the button's subviews directly
            for subview in button.subviews {
                subview.setNeedsDisplay(subview.bounds)
                subview.displayIfNeeded()
            }

            // Force window content view to redraw if available
            if let contentView = button.window?.contentView {
                contentView.setNeedsDisplay(contentView.bounds)
                contentView.displayIfNeeded()
            }
        }
    }

    public func popoverDidClose(_ notification: Notification) {
        dataManager.setPopupVisible(for: widgetType, isVisible: false)
    }
}

// MARK: - Widget Compact View

/// The compact menu bar view for a widget
struct WidgetCompactView: View {
    let widgetType: WidgetType
    let configuration: WidgetConfiguration
    @State private var dataManager = WidgetDataManager.shared

    private var snapshot: WidgetMetricSnapshot {
        WidgetMetricSnapshot(widgetType: widgetType, configuration: configuration, dataManager: dataManager)
    }

    var body: some View {
        HStack(spacing: TonicDS.Space.xxs) {
            Image(systemName: widgetType.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(snapshot.iconColor)

            Text(snapshot.value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(snapshot.color)
                .contentTransition(.numericText())

            if configuration.showLabel {
                Text(widgetType.displayName)
                    .font(.system(size: 10))
                    .foregroundStyle(TonicDS.Colors.textMuted)
            }

            if configuration.displayMode == .detailed, !snapshot.history.isEmpty {
                CompactSparkline(data: snapshot.history, color: snapshot.color)
                    .frame(width: 36, height: 14)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: TonicDS.Layout.MenuBar.compactHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(widgetType.displayName), \(snapshot.value)")
    }
}

private struct CompactSparkline: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard data.count > 1 else { return }
                let stepX = geometry.size.width / CGFloat(data.count - 1)
                let maxY = data.max() ?? 1
                let minY = data.min() ?? 0
                let range = max(maxY - minY, 0.1)

                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = geometry.size.height * (1 - ((value - minY) / range))
                    index == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
        }
    }
}

private struct EditorialWidgetPopoverView: View {
    let widgetType: WidgetType
    let configuration: WidgetConfiguration
    @State private var dataManager = WidgetDataManager.shared

    private var snapshot: WidgetMetricSnapshot {
        WidgetMetricSnapshot(widgetType: widgetType, configuration: configuration, dataManager: dataManager)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: TonicDS.Space.xs) {
                Image(systemName: widgetType.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TonicDS.Colors.onDarkMuted)
                MonoLabel(widgetType.displayName, color: TonicDS.Colors.onDarkMuted)
                Spacer()
                Metric(snapshot.value, color: snapshot.color)
                    .scaleEffect(0.72, anchor: .trailing)
                Button {
                    SettingsDeepLinkNavigator.openModuleSettings(widgetType)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(TonicDS.Colors.onDarkMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(widgetType.displayName) settings")
                .tonicPointerCursor()
            }
            .padding(.horizontal, TonicDS.Space.md)
            .frame(height: 44)

            TonicHairline(color: TonicDS.Colors.hairlineOnDark)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !snapshot.history.isEmpty {
                        NetworkSparklineChart(
                            data: snapshot.history,
                            color: snapshot.color,
                            height: TonicDS.Layout.MenuBar.chartHeight,
                            showArea: true,
                            lineWidth: 1.5
                        )
                        .padding(TonicDS.Space.md)
                        TonicHairline(color: TonicDS.Colors.hairlineOnDark)
                    } else {
                        popoverEmptyHistory
                        TonicHairline(color: TonicDS.Colors.hairlineOnDark)
                    }

                    ForEach(snapshot.rows) { row in
                        PopoverMetricRow(row: row)
                        TonicHairline(color: TonicDS.Colors.hairlineOnDark)
                    }
                }
            }
        }
        .frame(width: TonicDS.Layout.MenuBar.width)
        .frame(maxHeight: TonicDS.Layout.MenuBar.maxHeight)
        .background(TonicDS.Colors.console)
        .environment(\.colorScheme, .dark)
    }

    private var popoverEmptyHistory: some View {
        HStack(spacing: TonicDS.Space.sm) {
            TonicSkeleton(height: 34, width: 48, radius: TonicDS.Radius.xs)
            VStack(alignment: .leading, spacing: TonicDS.Space.xxs) {
                MonoLabel("HISTORY", color: TonicDS.Colors.onDarkMuted)
                Text("Waiting for live samples")
                    .tonicType(.caption)
                    .foregroundStyle(TonicDS.Colors.onDarkMuted)
            }
            Spacer()
        }
        .padding(TonicDS.Space.md)
    }
}

private struct PopoverMetricRow: View {
    let row: WidgetPopoverRow

    var body: some View {
        HStack(spacing: TonicDS.Space.sm) {
            if let color = row.statusColor {
                Circle().fill(color).frame(width: 6, height: 6)
            }
            Text(row.label)
                .tonicType(.caption)
                .foregroundStyle(TonicDS.Colors.onDarkMuted)
            Spacer(minLength: TonicDS.Space.sm)
            Text(row.value)
                .tonicType(.monoLabel)
                .monospacedDigit()
                .foregroundStyle(row.statusColor ?? TonicDS.Colors.onDark)
        }
        .frame(height: TonicDS.Layout.MenuBar.rowHeight)
        .padding(.horizontal, TonicDS.Space.md)
        .accessibilityElement(children: .combine)
    }
}

private struct WidgetPopoverRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    var statusColor: Color?
}

private struct WidgetMetricSnapshot {
    let value: String
    let color: Color
    let iconColor: Color
    let history: [Double]
    let rows: [WidgetPopoverRow]

    @MainActor
    init(widgetType: WidgetType, configuration: WidgetConfiguration, dataManager: WidgetDataManager) {
        let usePercent = configuration.valueFormat == .percentage
        self.iconColor = TonicDS.Colors.textMuted

        switch widgetType {
        case .cpu:
            let usage = dataManager.cpuData.totalUsage
            value = usePercent ? "\(Int(usage))%" : String(format: "%.1fGHz", 3.0 * usage / 100)
            color = TonicDS.Chart.utilization(usage)
            history = Array(dataManager.cpuHistory.suffix(30))
            rows = [
                WidgetPopoverRow(label: "Total", value: "\(Int(usage))%", statusColor: color),
                WidgetPopoverRow(label: "User", value: "\(Int(dataManager.cpuData.userUsage))%", statusColor: TonicDS.Chart.cpuUser),
                WidgetPopoverRow(label: "System", value: "\(Int(dataManager.cpuData.systemUsage))%", statusColor: TonicDS.Chart.cpuSystem),
                WidgetPopoverRow(label: "Idle", value: "\(Int(max(0, 100 - usage)))%", statusColor: TonicDS.Chart.cpuIdle)
            ]
        case .memory:
            let usage = dataManager.memoryData.usagePercentage
            let usedGB = Double(dataManager.memoryData.usedBytes) / 1_073_741_824
            let totalGB = Double(dataManager.memoryData.totalBytes) / 1_073_741_824
            value = usePercent ? "\(Int(usage))%" : String(format: "%.1fGB", usedGB)
            color = TonicDS.Chart.utilization(usage)
            history = Array(dataManager.memoryHistory.suffix(30))
            rows = [
                WidgetPopoverRow(label: "Used", value: String(format: "%.1f GB", usedGB), statusColor: color),
                WidgetPopoverRow(label: "Total", value: String(format: "%.0f GB", totalGB)),
                WidgetPopoverRow(label: "Pressure", value: "\(Int(usage))%", statusColor: color)
            ]
        case .disk:
            if let primary = dataManager.diskVolumes.first {
                let freeGB = primary.freeBytes / 1_073_741_824
                let usage = primary.usagePercentage
                value = usePercent ? "\(Int(usage))%" : "\(freeGB)GB"
                color = TonicDS.Chart.utilization(usage)
                history = []
                rows = [
                    WidgetPopoverRow(label: primary.name, value: "\(Int(usage))%", statusColor: color),
                    WidgetPopoverRow(label: "Free", value: "\(freeGB) GB"),
                    WidgetPopoverRow(label: "Read", value: primary.readThroughputString ?? "--", statusColor: TonicDS.Chart.read),
                    WidgetPopoverRow(label: "Write", value: primary.writeThroughputString ?? "--", statusColor: TonicDS.Chart.write)
                ]
            } else {
                value = "--"; color = TonicDS.Colors.textMuted; history = []
                rows = [WidgetPopoverRow(label: "Disk", value: "No data")]
            }
        case .network:
            value = dataManager.networkData.downloadString
            color = dataManager.networkData.isConnected ? TonicDS.Chart.download : TonicDS.Colors.statusWarning
            history = Array(dataManager.networkDownloadHistory.suffix(30))
            rows = [
                WidgetPopoverRow(label: "Download", value: dataManager.networkData.downloadString, statusColor: TonicDS.Chart.download),
                WidgetPopoverRow(label: "Upload", value: dataManager.networkData.uploadString, statusColor: TonicDS.Chart.upload),
                WidgetPopoverRow(label: "State", value: dataManager.networkData.isConnected ? "Connected" : "Offline", statusColor: color)
            ]
        case .gpu:
            if let usage = dataManager.gpuData.usagePercentage {
                value = usePercent ? "\(Int(usage))%" : String(format: "%.1fGHz", 1.0 + usage / 100)
                color = TonicDS.Chart.utilization(usage)
                history = Array(dataManager.gpuHistory.suffix(30))
                rows = [
                    WidgetPopoverRow(label: "Utilization", value: "\(Int(usage))%", statusColor: color),
                    WidgetPopoverRow(label: "Temperature", value: Self.temperatureValue(dataManager.gpuData.temperature), statusColor: dataManager.gpuData.temperature.map(TonicDS.Chart.temperature))
                ]
            } else {
                value = "--"; color = TonicDS.Colors.textMuted; history = []
                rows = [WidgetPopoverRow(label: "GPU", value: "No live sample")]
            }
        case .weather:
            value = "--"; color = TonicDS.Colors.textMuted; history = []
            rows = [WidgetPopoverRow(label: "Weather", value: "Not configured")]
        case .battery:
            let battery = dataManager.batteryData
            if battery.isPresent {
                value = usePercent ? "\(Int(battery.chargePercentage))%" : Self.remainingTime(minutes: battery.estimatedMinutesRemaining)
                color = TonicDS.Chart.battery(level: battery.chargePercentage, isCharging: battery.isCharging)
                history = Array(dataManager.batteryHistory.suffix(30))
                rows = [
                    WidgetPopoverRow(label: "Charge", value: "\(Int(battery.chargePercentage))%", statusColor: color),
                    WidgetPopoverRow(label: "Power", value: battery.isCharging ? "Charging" : "Battery", statusColor: color),
                    WidgetPopoverRow(label: "Remaining", value: Self.remainingTime(minutes: battery.estimatedMinutesRemaining))
                ]
            } else {
                value = "--"; color = TonicDS.Colors.textMuted; history = []
                rows = [WidgetPopoverRow(label: "Battery", value: "Not present")]
            }
        case .sensors:
            if let hottest = dataManager.sensorsData.temperatures.map(\.value).max() {
                value = "\(Int(hottest))°"
                color = TonicDS.Chart.temperature(hottest)
            } else if let fan = dataManager.sensorsData.fans.map(\.rpm).max() {
                value = "\(fan)RPM"
                color = TonicDS.Colors.statusInfo
            } else {
                value = "--"
                color = TonicDS.Colors.textMuted
            }
            history = Array(dataManager.sensorsHistory.suffix(30))
            rows = [
                WidgetPopoverRow(label: "Temperature Sensors", value: "\(dataManager.sensorsData.temperatures.count)"),
                WidgetPopoverRow(label: "Fans", value: "\(dataManager.sensorsData.fans.count)"),
                WidgetPopoverRow(label: "Peak", value: value, statusColor: color)
            ]
        case .bluetooth:
            if dataManager.bluetoothData.isBluetoothEnabled {
                let count = dataManager.bluetoothData.connectedDevices.count
                if let device = dataManager.bluetoothData.devicesWithBattery.first,
                   let battery = device.primaryBatteryLevel {
                    value = "\(battery)%"
                    color = TonicDS.Chart.battery(level: Double(battery))
                } else {
                    value = "\(count)"
                    color = count > 0 ? TonicDS.Colors.statusInfo : TonicDS.Colors.textMuted
                }
                rows = [
                    WidgetPopoverRow(label: "Connected", value: "\(count)", statusColor: color),
                    WidgetPopoverRow(label: "Battery Devices", value: "\(dataManager.bluetoothData.devicesWithBattery.count)")
                ]
            } else {
                value = "Off"; color = TonicDS.Colors.statusWarning
                rows = [WidgetPopoverRow(label: "Bluetooth", value: "Off", statusColor: color)]
            }
            history = []
        case .clock:
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            value = formatter.string(from: Date())
            color = TonicDS.Colors.onDark
            history = []
            rows = ClockPreferences.shared.enabledEntries.map {
                WidgetPopoverRow(label: $0.name, value: Self.timeString(for: $0.timezone))
            }
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

    private static func temperatureValue(_ value: Double?) -> String {
        guard let value else { return "--" }
        return "\(Int(value))°C"
    }
}

// MARK: - Detail Placeholder

/// Base console placeholder shown until a widget subclass supplies its own detail view.
private struct WidgetDetailViewPlaceholder: View {
    let widgetType: WidgetType

    var body: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
            MonoLabel(widgetType.displayName, color: TonicDS.Colors.onDarkMuted)
            HStack(spacing: TonicDS.Space.sm) {
                Image(systemName: widgetType.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(TonicDS.Colors.onDarkMuted)
                Text("Waiting for live samples")
                    .tonicType(.caption)
                    .foregroundStyle(TonicDS.Colors.onDarkMuted)
            }
        }
        .padding(TonicDS.Space.md)
        .frame(width: TonicDS.Layout.MenuBar.width, alignment: .leading)
        .background(TonicDS.Colors.console)
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Widget Coordinator

/// Coordinates multiple widget status items
@MainActor
public final class WidgetCoordinator: ObservableObject {

    public static let shared = WidgetCoordinator()

    private let logger = Logger(subsystem: "com.tonic.app", category: "WidgetCoordinator")

    /// All active widget status items
    @Published public private(set) var activeWidgets: [WidgetType: WidgetStatusItem] = [:]

    /// The unified OneView status item (when in unified mode)
    private var oneViewStatusItem: OneViewStatusItem?

    /// Whether the widget system is active
    @Published public private(set) var isActive = false

    /// Single unified view refresh timer (replaces 7 per-widget timers)
    private var viewRefreshTimer: Timer?

    /// Observer for configuration change notifications
    private var configChangeObserver: NSObjectProtocol?

    private init() {
        setupConfigurationObserver()
    }

    // MARK: - Widget Management

    /// Start showing enabled widgets in the menu bar
    public func start() {
        guard !isActive else {
            logger.warning("⚠️ Already active, skipping start()")
            print("⚠️ [WidgetCoordinator] Already active, skipping start()")
            return
        }
        logger.info("🚀 Starting WidgetCoordinator")
        print("🚀 [WidgetCoordinator] Starting WidgetCoordinator")
        isActive = true

        // Start data monitoring
        logger.info("📊 Calling WidgetDataManager.shared.startMonitoring()")
        print("📊 [WidgetCoordinator] Calling WidgetDataManager.shared.startMonitoring()")
        WidgetDataManager.shared.startMonitoring()

        // Create status items for enabled widgets
        logger.info("🔄 Refreshing widgets...")
        print("🔄 [WidgetCoordinator] Refreshing widgets...")
        refreshWidgets()

        // Start single unified view refresh timer (replaces 7 per-widget timers)
        // This is a key performance improvement: 1 timer instead of 7
        startViewRefreshTimer()

        logger.info("✅ WidgetCoordinator started with \(self.activeWidgets.count) active widgets")
        print("✅ [WidgetCoordinator] Started with \(self.activeWidgets.count) active widgets")
    }

    // MARK: - Configuration Observer

    /// Set up observer for configuration changes
    private func setupConfigurationObserver() {
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .widgetConfigurationDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleConfigurationChange(notification)
        }
        logger.info("📡 Configuration observer registered")
    }

    /// Handle configuration change notification
    /// Performance optimization: Debounce rapid configuration changes
    private nonisolated func handleConfigurationChange(_ notification: Notification) {
        // Invalidate existing debounce timer
        Task { @MainActor [weak self] in
            self?.configChangeDebounceTimer?.invalidate()

            // Extract widget type early to avoid Sendable issues
            let widgetTypeRaw = notification.userInfo?["widgetType"] as? String
            let widgetType = widgetTypeRaw.flatMap { WidgetType(rawValue: $0) }

            // Schedule debounced refresh (100ms delay to batch rapid changes)
            await MainActor.run { [weak self] in
                self?.configChangeDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
                    // Hop to main actor for refreshWidgets call
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }

                        if widgetType == nil {
                            // If no specific type or invalid type, refresh all widgets
                            self.logger.info("🔄 Configuration changed - refreshing all widgets")
                            self.refreshWidgets()
                        } else {
                            self.logger.info("🔄 Configuration changed for \(widgetType!.rawValue) - refreshing")
                            self.refreshWidgets()
                        }
                    }
                }
            }
        }
    }

    /// Refresh widgets based on current preferences and mode
    public func refreshWidgets() {
        let preferences = WidgetPreferences.shared
        let enabledConfigs = preferences.enabledWidgets
        logger.info("🔄 refreshWidgets - unified mode: \(preferences.unifiedMenuBarMode), enabled configs: \(enabledConfigs.count)")

        if preferences.unifiedMenuBarMode {
            // Unified mode: show OneView, hide individual widgets
            refreshUnifiedMode()
        } else {
            // Individual mode: show each widget separately
            refreshIndividualWidgets()
        }
    }

    /// Refresh widgets in unified OneView mode
    private func refreshUnifiedMode() {
        // Remove all individual widgets
        for (type, widget) in activeWidgets {
            logger.info("🔻 Removing individual widget for unified mode: \(type.rawValue)")
            widget.hide()
            activeWidgets.removeValue(forKey: type)
        }

        // Create or update OneView
        if oneViewStatusItem == nil {
            logger.info("➕ Creating OneView status item")
            oneViewStatusItem = OneViewStatusItem()
        }

        // Update the OneView to reflect current widget list
        oneViewStatusItem?.refreshWidgetList()

        logger.info("✅ OneView mode active")
    }

    /// Refresh widgets in individual mode
    private func refreshIndividualWidgets() {
        // Remove OneView if active
        if let oneView = oneViewStatusItem {
            logger.info("🔻 Removing OneView for individual mode")
            oneView.hide()
            oneViewStatusItem = nil
        }

        let enabledConfigs = WidgetPreferences.shared.enabledWidgets

        // Remove widgets that are no longer enabled
        let activeTypes = Set(activeWidgets.keys)
        let enabledTypes = Set(enabledConfigs.map { $0.type })
        let toRemove = activeTypes.subtracting(enabledTypes)

        for type in toRemove {
            logger.info("🔻 Removing widget: \(type.rawValue)")
            activeWidgets[type]?.hide()
            activeWidgets.removeValue(forKey: type)
        }

        // Add or update enabled widgets
        for config in enabledConfigs {
            if let existing = activeWidgets[config.type] {
                logger.info("🔄 Updating existing widget: \(config.type.rawValue)")
                existing.updateConfiguration(config)
            } else {
                logger.info("➕ Creating new widget: \(config.type.rawValue)")
                let widget = createWidget(for: config.type, configuration: config)
                activeWidgets[config.type] = widget
            }
        }

        let widgetTypes = self.activeWidgets.keys.map { $0.rawValue }
        logger.info("✅ Individual mode active - \(self.activeWidgets.count) widgets: \(widgetTypes)")
    }

    /// Performance optimization: Throttle configuration changes to avoid excessive updates
    private var configChangeDebounceTimer: Timer?

    /// Start single unified timer for all widget view updates
    /// This replaces the previous pattern of 7 individual per-widget timers
    /// Performance optimization: Uses adaptive refresh rate based on widget count
    private func startViewRefreshTimer() {
        viewRefreshTimer?.invalidate()
        logger.info("⏰ Starting unified view refresh timer (1 timer for all widgets)")

        // Performance: Adaptive refresh rate - fewer widgets = slower refresh
        let adaptiveInterval: TimeInterval = activeWidgets.count > 5 ? 0.5 : 1.0

        viewRefreshTimer = Timer.scheduledTimer(withTimeInterval: adaptiveInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAllWidgetViews()
            }
        }
    }

    /// Refresh all active widget views at once
    /// Performance optimization: Skip refresh if no data changes detected
    private func refreshAllWidgetViews() {
        // Refresh individual widgets only if needed
        for widget in activeWidgets.values {
            widget.refresh()
        }

        // Also refresh OneView if active
        oneViewStatusItem?.refresh()
    }

    /// Stop showing widgets
    public func stop() {
        isActive = false

        // Stop unified view refresh timer
        viewRefreshTimer?.invalidate()
        viewRefreshTimer = nil

        // Remove configuration observer
        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            configChangeObserver = nil
        }

        // Remove all status items including OneView
        oneViewStatusItem?.hide()
        oneViewStatusItem = nil
        activeWidgets.values.forEach { $0.hide() }
        activeWidgets.removeAll()

        // Stop data monitoring
        WidgetDataManager.shared.stopMonitoring()
    }

    /// Create the appropriate widget subclass for the given type and visualization
    private func createWidget(for type: WidgetType, configuration: WidgetConfiguration) -> WidgetStatusItem {
        // Use the new WidgetFactory which handles both data source type and visualization type
        return WidgetFactory.createWidget(
            for: type,
            visualization: configuration.visualizationType,
            configuration: configuration
        )
    }

    /// Update a specific widget's configuration
    public func updateWidget(type: WidgetType, configuration: WidgetConfiguration) {
        if let widget = activeWidgets[type] {
            widget.updateConfiguration(configuration)
        }
    }

    /// Close all open popovers immediately (no animation).
    /// Call before activating another window to prevent the transient-popover
    /// deallocation-during-animation crash.
    public func closeAllPopovers() {
        for widget in activeWidgets.values {
            widget.closePopoverImmediately()
        }
        oneViewStatusItem?.closePopoverImmediately()
    }

    /// Get the status item for a specific widget type
    public func widget(for type: WidgetType) -> WidgetStatusItem? {
        activeWidgets[type]
    }

    deinit {
        // Clean up observer
        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
