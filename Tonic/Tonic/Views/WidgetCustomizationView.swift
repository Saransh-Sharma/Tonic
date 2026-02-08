//
//  WidgetCustomizationView.swift
//  Tonic
//
//  Menu Bar Widgets screen — modern design system.
//

import SwiftUI

// MARK: - Widget Customization View

struct WidgetCustomizationView: View {

    @State private var preferences = WidgetPreferences.shared
    @State private var draggedWidget: WidgetType?
    @State private var showingResetAlert = false
    @State private var dataManager = WidgetDataManager.shared
    @State private var showingNotificationSettings = false
    @State private var dropTargetType: WidgetType?
    @State private var selectedCategory: WidgetFilterCategory = .all
    @State private var unifiedMode: Bool

    init() {
        _unifiedMode = State(initialValue: WidgetPreferences.shared.unifiedMenuBarMode)
    }

    private var enabledConfigs: [WidgetConfiguration] {
        preferences.enabledWidgets
    }

    private var availableTypes: [WidgetType] {
        let all = WidgetType.parityCases.filter { type in
            preferences.config(for: type)?.isEnabled != true
        }
        switch selectedCategory {
        case .all:
            return all
        case .system:
            return all.filter { [.cpu, .memory, .disk, .gpu, .sensors].contains($0) }
        case .environment:
            return all.filter { [.network, .battery, .weather, .bluetooth, .clock].contains($0) }
        }
    }

    public var body: some View {
        TonicThemeProvider(world: .protectionMagenta) {
            ZStack {
                WorldCanvasBackground()

                VStack(spacing: TonicSpaceToken.three) {
                    // Header
                    PageHeader(
                        title: "Menu Bar Widgets",
                        subtitle: "\(enabledConfigs.count) widget\(enabledConfigs.count == 1 ? "" : "s") active",
                        trailing: AnyView(
                            HStack(spacing: TonicSpaceToken.one) {
                                SecondaryPillButton(title: "Reset") {
                                    showingResetAlert = true
                                }
                            }
                        )
                    )

                    ScrollView {
                        VStack(spacing: TonicSpaceToken.four) {
                            // 1. Hero Module
                            WidgetHeroModule(
                                state: enabledConfigs.isEmpty
                                    ? .idle
                                    : .active(count: enabledConfigs.count),
                                activeIcons: enabledConfigs.map(\.type.icon)
                            )
                            .staggeredReveal(index: 0)

                            // 2. OneView Mode Toggle
                            OneViewModeCard(
                                enabled: $unifiedMode,
                                onToggle: { newValue in
                                    preferences.setUnifiedMenuBarMode(newValue)
                                    WidgetCoordinator.shared.refreshWidgets()
                                }
                            )
                            .staggeredReveal(index: 1)

                            // 3. Active Widgets Section
                            activeWidgetsSection
                                .staggeredReveal(index: 2)

                            // 4. Available Widgets Section
                            availableWidgetsSection
                                .staggeredReveal(index: 3 + enabledConfigs.count)
                        }
                        .padding(.bottom, TonicSpaceToken.three)
                    }

                    // 5. Command Dock
                    WidgetCommandDock(
                        activeWidgets: enabledConfigs,
                        previewValues: enabledConfigs.map { config in
                            (config: config, value: widgetPreviewValue(config), sparkline: sparklineData(for: config.type))
                        },
                        onApply: {
                            WidgetCoordinator.shared.refreshWidgets()
                        },
                        onNotifications: {
                            showingNotificationSettings = true
                        }
                    )
                }
                .padding(.horizontal, TonicSpaceToken.three)
                .padding(.bottom, TonicSpaceToken.three)
            }
        }
        .alert("Reset to Defaults", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                preferences.resetToDefaults()
                unifiedMode = preferences.unifiedMenuBarMode
            }
        } message: {
            Text("This will reset all widget settings to their default values.")
        }
        .sheet(isPresented: $showingNotificationSettings) {
            NotificationSettingsView()
        }
    }

    // MARK: - Active Widgets Section

    private var activeWidgetsSection: some View {
        VStack(spacing: TonicSpaceToken.two) {
            HStack {
                Text("Active Widgets")
                    .font(TonicTypeToken.caption.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)

                Spacer()

                if !enabledConfigs.isEmpty {
                    CounterChip(
                        title: "\(enabledConfigs.count) configured",
                        value: nil,
                        world: .protectionMagenta
                    )
                }
            }

            if enabledConfigs.isEmpty {
                EmptyStatePanel(
                    icon: "square.grid.2x2",
                    title: "No active widgets",
                    message: "Tap a widget below to add it to your menu bar."
                )
            } else {
                VStack(spacing: TonicSpaceToken.one) {
                    ForEach(Array(enabledConfigs.enumerated()), id: \.element.id) { index, config in
                        WidgetCard(
                            config: config,
                            sparklineData: sparklineData(for: config.type),
                            currentValue: widgetPreviewValue(config),
                            isDragging: draggedWidget == config.type,
                            isDropTarget: dropTargetType == config.type,
                            onSettings: {
                                NotificationCenter.default.post(
                                    name: .showModuleSettings,
                                    object: nil,
                                    userInfo: [SettingsDeepLinkUserInfoKey.module: config.type.rawValue]
                                )
                            },
                            onRemove: {
                                withAnimation(TonicMotionToken.stageEnterSpring) {
                                    preferences.setWidgetEnabled(type: config.type, enabled: false)
                                }
                            }
                        )
                        .staggeredReveal(index: 2 + index)
                        .onDrag {
                            draggedWidget = config.type
                            return NSItemProvider(object: config.type.rawValue as NSString)
                        }
                        .onDrop(of: [.text], delegate: WidgetTypeDropDelegate(
                            currentType: config.type,
                            draggedType: $draggedWidget,
                            dropTargetType: $dropTargetType,
                            onDrop: { draggedType in
                                withAnimation(TonicMotionToken.stageEnterSpring) {
                                    preferences.reorderWidgets(move: draggedType, to: config.type)
                                }
                                return true
                            }
                        ))
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .opacity)
                        ))
                    }
                }
            }
        }
        .padding(TonicSpaceToken.three)
        .glassSurface(radius: TonicRadiusToken.container, variant: .raised)
    }

    // MARK: - Available Widgets Section

    private var availableWidgetsSection: some View {
        VStack(spacing: TonicSpaceToken.two) {
            HStack {
                Text("Available Widgets")
                    .font(TonicTypeToken.caption.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)

                Spacer()

                Text("Tap to enable")
                    .font(TonicTypeToken.micro)
                    .foregroundStyle(TonicTextToken.tertiary)
            }

            // Category filter chips
            HStack(spacing: TonicSpaceToken.one) {
                ForEach(WidgetFilterCategory.allCases) { category in
                    Button {
                        withAnimation(.easeInOut(duration: TonicMotionToken.med)) {
                            selectedCategory = category
                        }
                    } label: {
                        GlassChip(
                            title: category.displayName,
                            role: selectedCategory == category
                                ? .world(.protectionMagenta)
                                : .semantic(.neutral),
                            strength: selectedCategory == category ? .strong : .subtle,
                            controlState: selectedCategory == category ? .focused : .default
                        )
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(selectedCategory == category ? 1.02 : 1.0)
                    .animation(TonicMotionToken.springTap, value: selectedCategory)
                }

                Spacer()
            }

            if availableTypes.isEmpty {
                EmptyStatePanel(
                    icon: "checkmark.circle",
                    title: "All widgets active",
                    message: "Every available widget is enabled."
                )
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 160), spacing: TonicSpaceToken.gridGap)
                    ],
                    spacing: TonicSpaceToken.gridGap
                ) {
                    ForEach(Array(availableTypes.enumerated()), id: \.element) { index, type in
                        WidgetSourceTile(
                            type: type,
                            isEnabled: false,
                            description: widgetDescription(for: type),
                            onToggle: {
                                withAnimation(TonicMotionToken.stageEnterSpring) {
                                    toggleWidget(type)
                                }
                            }
                        )
                        .staggeredReveal(index: 4 + enabledConfigs.count + index)
                    }
                }
            }
        }
        .padding(TonicSpaceToken.three)
        .glassSurface(radius: TonicRadiusToken.container, variant: .raised)
    }

    // MARK: - Helper Methods

    private func sparklineData(for type: WidgetType) -> [Double] {
        switch type {
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

    private func toggleWidget(_ type: WidgetType) {
        let currentConfig = preferences.config(for: type)
        let newState = !(currentConfig?.isEnabled ?? false)

        if newState {
            let maxPosition = preferences.widgetConfigs.map { $0.position }.max() ?? 0
            var newConfig = WidgetConfiguration.default(for: type, at: maxPosition + 1)
            newConfig.isEnabled = true
            preferences.updateConfig(for: type) { config in
                config = newConfig
            }
        } else {
            preferences.setWidgetEnabled(type: type, enabled: false)
        }
    }

    private func widgetPreviewValue(_ config: WidgetConfiguration) -> String {
        let usePercent = config.valueFormat == .percentage

        switch config.type {
        case .cpu:
            return "\(Int(dataManager.cpuData.totalUsage))%"
        case .memory:
            if usePercent {
                return "\(Int(dataManager.memoryData.usagePercentage))%"
            } else {
                let usedGB = Double(dataManager.memoryData.usedBytes) / (1024 * 1024 * 1024)
                return String(format: "%.1f GB", usedGB)
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
                return "\(Int(usage))%"
            }
            return "--"
        case .battery:
            return "\(Int(dataManager.batteryData.chargePercentage))%"
        case .weather:
            return "21\u{00B0}C"
        case .sensors:
            return "--"
        case .bluetooth:
            if let device = dataManager.bluetoothData.devicesWithBattery.first,
               let battery = device.primaryBatteryLevel {
                return "\(battery)%"
            }
            return "\(dataManager.bluetoothData.connectedDevices.count)"
        case .clock:
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: Date())
        }
    }

    private func widgetDescription(for type: WidgetType) -> String {
        switch type {
        case .cpu: return "Monitor CPU usage and core activity."
        case .memory: return "Track RAM usage and available memory."
        case .disk: return "Monitor available space on drives."
        case .network: return "Real-time upload and download speeds."
        case .gpu: return "Monitor GPU utilization."
        case .battery: return "Displays charge and time remaining."
        case .weather: return "Current local temperature."
        case .sensors: return "System temperature and fan sensors."
        case .bluetooth: return "Connected Bluetooth device batteries."
        case .clock: return "Current local time."
        }
    }
}

// MARK: - Widget Category

private enum WidgetFilterCategory: String, CaseIterable, Identifiable {
    case all
    case system
    case environment

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All"
        case .system: return "System"
        case .environment: return "Environment"
        }
    }
}

// MARK: - Widget Type Drop Delegate

private struct WidgetTypeDropDelegate: DropDelegate {
    let currentType: WidgetType
    let draggedType: Binding<WidgetType?>
    let dropTargetType: Binding<WidgetType?>
    let onDrop: (WidgetType) -> Bool

    func performDrop(info: DropInfo) -> Bool {
        dropTargetType.wrappedValue = nil
        return onDrop(currentType)
    }

    func dropEntered(info: DropInfo) {
        if draggedType.wrappedValue != currentType {
            dropTargetType.wrappedValue = currentType
            if let dragged = draggedType.wrappedValue {
                _ = onDrop(dragged)
                draggedType.wrappedValue = currentType
            }
        }
    }

    func dropExited(info: DropInfo) {
        if dropTargetType.wrappedValue == currentType {
            dropTargetType.wrappedValue = nil
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

// MARK: - Widget Preferences Extension

extension WidgetPreferences {
    /// Reorder widgets by moving one type to another's position
    func reorderWidgets(move typeToMove: WidgetType, to targetType: WidgetType) {
        guard let fromIndex = widgetConfigs.firstIndex(where: { $0.type == typeToMove }),
              let toIndex = widgetConfigs.firstIndex(where: { $0.type == targetType }),
              typeToMove != targetType else {
            return
        }

        let movedConfig = widgetConfigs[fromIndex]
        widgetConfigs.remove(at: fromIndex)

        var adjustedToIndex = toIndex
        if fromIndex < toIndex {
            adjustedToIndex = toIndex - 1
        }

        widgetConfigs.insert(movedConfig, at: adjustedToIndex)

        for (index, _) in widgetConfigs.enumerated() {
            widgetConfigs[index].position = index
        }

        saveConfigs()

        Task { @MainActor in
            NotificationCenter.default.post(
                name: .widgetConfigurationDidUpdate,
                object: nil,
                userInfo: ["widgetType": "reorder"]
            )
        }
    }
}

// MARK: - Preview

#Preview("Widget Customization") {
    WidgetCustomizationView()
        .frame(width: 960, height: 700)
}
