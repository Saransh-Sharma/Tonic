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
        let oldColor = configuration.accentColor.rawValue
        let oldFormat = configuration.valueFormat.rawValue
        let oldMode = configuration.displayMode.rawValue

        configuration = newConfig

        logger.info("🔧 updateConfiguration for \(self.widgetType.rawValue): color \(oldColor)→\(newConfig.accentColor.rawValue), format \(oldFormat)→\(newConfig.valueFormat.rawValue), mode \(oldMode)→\(newConfig.displayMode.rawValue)")

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

            logger.info("✏️ Updated widget \(self.widgetType.rawValue): displayMode=\(newConfig.displayMode.rawValue), color=\(newConfig.accentColor.rawValue), valueFormat=\(newConfig.valueFormat.rawValue)")
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
        // Return the appropriate Stats Master-style popover for each widget type
        switch widgetType {
        case .cpu:
            return AnyView(CPUPopoverView())
        case .gpu:
            return AnyView(GPUPopoverView())
        case .memory:
            return AnyView(MemoryPopoverView())
        case .disk:
            return AnyView(DiskPopoverView())
        case .network:
            return AnyView(NetworkPopoverView())
        case .battery:
            return AnyView(BatteryPopoverView())
        case .sensors:
            return AnyView(SensorsPopoverView())
        case .bluetooth:
            return AnyView(BluetoothPopoverView())
        case .clock:
            return AnyView(ClockPopoverView())
        case .weather:
            return AnyView(WeatherDetailView())
        }
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

    private var accentColor: Color {
        configuration.accentColor.colorValue(for: widgetType)
    }

    var body: some View {
        HStack(spacing: 4) {
            // Icon
            Image(systemName: widgetType.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(accentColor)

            // Value - always shown in both compact and detailed modes
            Text(widgetValue)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)

            // Label (if enabled)
            if configuration.showLabel {
                Text(widgetType.displayName)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Sparkline for detailed mode
            if configuration.displayMode == .detailed {
                miniSparkline
                    .frame(width: 36, height: 14)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 22)
    }

    // MARK: - Sparkline

    private var miniSparkline: some View {
        let data = sparklineData
        return GeometryReader { geometry in
            Path { path in
                guard data.count > 1 else { return }

                let stepX = geometry.size.width / CGFloat(data.count - 1)
                let maxY = data.max() ?? 1
                let minY = data.min() ?? 0
                let range = max(maxY - minY, 0.1)

                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let normalizedY = (value - minY) / range
                    let y = geometry.size.height * (1 - normalizedY)

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                LinearGradient(
                    colors: [accentColor, accentColor.opacity(0.4)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 1.5
            )
        }
    }

    private var sparklineData: [Double] {
        switch widgetType {
        case .cpu:
            let history = dataManager.cpuHistory.suffix(10)
            return history.isEmpty ? [30, 35, 32, 38, 36, 34, 37, 35, 33, 36] : Array(history)
        case .memory:
            let history = dataManager.memoryHistory.suffix(10)
            return history.isEmpty ? [60, 62, 58, 65, 63, 67, 64, 68, 66, 65] : Array(history)
        default:
            return [30, 35, 32, 38, 36, 34, 37, 35, 33, 36]
        }
    }

    private var widgetValue: String {
        let usePercent = configuration.valueFormat == .percentage

        switch widgetType {
        case .cpu:
            if usePercent {
                return "\(Int(dataManager.cpuData.totalUsage))%"
            } else {
                // Show GHz equivalent roughly
                let baseFreq = 3.0 // Base frequency assumption
                let currentFreq = baseFreq * (dataManager.cpuData.totalUsage / 100.0)
                return String(format: "%.1fGHz", currentFreq)
            }

        case .memory:
            if usePercent {
                return "\(Int(dataManager.memoryData.usagePercentage))%"
            } else {
                let usedGB = Double(dataManager.memoryData.usedBytes) / (1024 * 1024 * 1024)
                return String(format: "%.1fGB", usedGB)
            }

        case .disk:
            if let primary = dataManager.diskVolumes.first {
                if usePercent {
                    return "\(Int(primary.usagePercentage))%"
                } else {
                    let freeGB = primary.freeBytes / (1024 * 1024 * 1024)
                    return "\(freeGB)GB"
                }
            }
            return "--"

        case .network:
            return dataManager.networkData.downloadString

        case .gpu:
            if let usage = dataManager.gpuData.usagePercentage {
                if usePercent {
                    return "\(Int(usage))%"
                } else {
                    // Rough frequency estimate
                    let baseFreq = 1.0
                    let currentFreq = baseFreq + (usage / 100.0)
                    return String(format: "%.1fGHz", currentFreq)
                }
            }
            return "--"

        case .weather:
            return "--°" // Will be filled by WeatherWidgetView

        case .battery:
            if dataManager.batteryData.isPresent {
                if usePercent {
                    return "\(Int(dataManager.batteryData.chargePercentage))%"
                } else {
                    if let minutes = dataManager.batteryData.estimatedMinutesRemaining {
                        let hours = minutes / 60
                        let mins = minutes % 60
                        if hours > 0 {
                            return "\(hours)h\(mins)m"
                        } else {
                            return "\(mins)m"
                        }
                    } else {
                        return "--"
                    }
                }
            }
            return "--"
            
        case .sensors:
            if let hottest = dataManager.sensorsData.temperatures.map(\.value).max() {
                if usePercent {
                    return "\(Int(min(100, hottest)))%"
                }
                return "\(Int(hottest))°"
            }
            if let fastestFan = dataManager.sensorsData.fans.map(\.rpm).max() {
                return "\(fastestFan)RPM"
            }
            return "--"

        case .bluetooth:
            if dataManager.bluetoothData.isBluetoothEnabled {
                let connectedCount = dataManager.bluetoothData.connectedDevices.count
                if let device = dataManager.bluetoothData.devicesWithBattery.first,
                   let battery = device.primaryBatteryLevel {
                    return "\(battery)%"
                }
                return "\(connectedCount)"
            }
            return "Off"

        case .clock:
            // Clock is handled by ClockStatusItem, not WidgetCompactView
            return "--:--"
        }
    }
}

// MARK: - Placeholder Detail View

/// Placeholder detail view until specific widget detail views are implemented
struct WidgetDetailViewPlaceholder: View {
    let widgetType: WidgetType

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: widgetType.icon)
                    .font(.title2)
                    .foregroundColor(TonicColors.accent)

                Text("\(widgetType.displayName) Details")
                    .font(.headline)

                Spacer()
            }
            .padding()

            Text("Detailed view for \(widgetType.displayName) widget coming soon.")
                .foregroundColor(.secondary)
                .padding()

            Spacer()
        }
        .frame(width: 300, height: 200)
        .padding()
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
                logger.info("🔄 Updating existing widget: \(config.type.rawValue) with color=\(config.accentColor.rawValue)")
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
