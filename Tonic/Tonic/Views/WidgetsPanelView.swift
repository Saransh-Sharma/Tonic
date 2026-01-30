//
//  WidgetsPanelView.swift
//  Tonic
//
//  Main Widgets Panel configuration UI
//  Matches Stats Master's settings pattern with Tonic's design language
//  Task ID: fn-5-v8r.13
//

import SwiftUI

// MARK: - Widget Type Enum

/// All available widget types matching Stats Master
public enum AvailableWidgetType: String, CaseIterable, Identifiable {
    // System monitoring widgets
    case cpu = "CPU"
    case memory = "Memory"
    case disk = "Disk"
    case network = "Network"
    case battery = "Battery"
    case gpu = "GPU"
    case sensors = "Sensors"

    // Chart widgets
    case lineChart = "Line Chart"
    case barChart = "Bar Chart"
    case pieChart = "Pie Chart"
    case stack = "Stack"
    case tachometer = "Tachometer"

    // Information widgets
    case label = "Label"
    case state = "State"
    case text = "Text"

    // Specialized widgets
    case speed = "Speed Test"
    case batteryDetails = "Battery Details"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .network: return "network"
        case .battery: return "battery.100"
        case .gpu: return "cpu"
        case .sensors: return "thermometer"
        case .lineChart: return "chart.line.uptrend.xyaxis"
        case .barChart: return "chart.bar.fill"
        case .pieChart: return "chart.pie.fill"
        case .stack: return "stack.fill"
        case .tachometer: return "gauge"
        case .label: return "text.alignleft"
        case .state: return "circlebadge"
        case .text: return "textformat"
        case .speed: return "speedometer"
        case .batteryDetails: return "bolt.fill.batteryblock"
        }
    }

    public var category: WidgetCategory {
        switch self {
        case .cpu, .memory, .disk, .network, .battery, .gpu, .sensors:
            return .system
        case .lineChart, .barChart, .pieChart:
            return .chart
        case .stack, .tachometer:
            return .sensor
        case .label, .state, .text:
            return .info
        case .speed, .batteryDetails:
            return .specialized
        }
    }

    public var description: String {
        switch self {
        case .cpu: return "CPU usage per core"
        case .memory: return "Memory usage & pressure"
        case .disk: return "Disk usage per volume"
        case .network: return "Network up/down speed"
        case .battery: return "Battery percentage"
        case .gpu: return "GPU usage (Apple Silicon)"
        case .sensors: return "Temperature & fan speeds"
        case .lineChart: return "Real-time data history"
        case .barChart: return "Multi-value bars"
        case .pieChart: return "Circular progress"
        case .stack: return "Sensor stack display"
        case .tachometer: return "Circular gauge"
        case .label: return "Custom text label"
        case .state: return "Binary on/off indicator"
        case .text: return "Dynamic formatted text"
        case .speed: return "Network speed test"
        case .batteryDetails: return "Extended battery info"
        }
    }
}

public enum WidgetCategory: String, CaseIterable, Identifiable {
    case system = "System"
    case chart = "Charts"
    case sensor = "Sensors"
    case info = "Information"
    case specialized = "Specialized"

    public var id: String { rawValue }
}

// MARK: - Active Widget Model

/// Model for an active widget configuration
@Observable
@MainActor
public final class ActiveWidget: Identifiable, Sendable {
    public let id: UUID
    public var type: AvailableWidgetType
    public var name: String
    public var isEnabled: Bool
    public var order: Int

    public init(
        id: UUID = UUID(),
        type: AvailableWidgetType,
        name: String,
        isEnabled: Bool = true,
        order: Int = 0
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.isEnabled = isEnabled
        self.order = order
    }
}

// MARK: - Widget Panel View Model

@Observable
@MainActor
public final class WidgetPanelViewModel {
    public var availableWidgets: [AvailableWidgetType] = AvailableWidgetType.allCases
    public var activeWidgets: [ActiveWidget] = []

    private let widgetStore = WidgetStore.shared

    public init() {
        loadActiveWidgets()
    }

    public func loadActiveWidgets() {
        activeWidgets = widgetStore.loadAllConfigs().map { config in
            ActiveWidget(
                id: config.id,
                type: .cpu,  // Would map from config
                name: config.name,
                isEnabled: true,
                order: 0
            )
        }.sorted { $0.order < $1.order }
    }

    public func addWidget(_ type: AvailableWidgetType) {
        let widget = ActiveWidget(
            type: type,
            name: type.rawValue,
            order: activeWidgets.count
        )
        activeWidgets.append(widget)
        saveWidgets()
    }

    public func removeWidget(_ widget: ActiveWidget) {
        activeWidgets.removeAll { $0.id == widget.id }
        reorderWidgets()
        saveWidgets()
    }

    public func moveWidget(_ widget: ActiveWidget, to newIndex: Int) {
        guard let index = activeWidgets.firstIndex(where: { $0.id == widget.id }) else { return }
        activeWidgets.remove(at: index)
        activeWidgets.insert(widget, at: min(newIndex, activeWidgets.count))
        reorderWidgets()
        saveWidgets()
    }

    public func toggleWidget(_ widget: ActiveWidget) {
        widget.isEnabled.toggle()
        saveWidgets()
    }

    private func reorderWidgets() {
        for (index, _) in activeWidgets.enumerated() {
            activeWidgets[index].order = index
        }
    }

    private func saveWidgets() {
        // Save to WidgetStore
        _ = widgetStore.saveConfig(WidgetConfiguration(
            id: UUID(),
            name: "Widget",
            type: .cpu,
            displayMode: .iconOnly,
            isEnabled: true,
            refreshInterval: 2.0
        ))
    }
}

// MARK: - Widgets Panel View

/// Main Widgets Panel for widget configuration
/// Following Stats Master's pattern with Tonic's design language
public struct WidgetsPanelView: View {
    @State private var viewModel = WidgetPanelViewModel()
    @State private var selectedCategory: WidgetCategory? = nil

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xl) {
                // Header
                header

                // Available Widgets Section
                availableWidgetsSection

                Divider()
                    .padding(.horizontal, DesignTokens.Spacing.md)

                // Active Widgets Section (Horizontal Layout)
                activeWidgetsSection
            }
            .padding(DesignTokens.Spacing.md)
        }
        .background(DesignTokens.Colors.background)
        .navigationTitle("Menu Bar Widgets")
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Menu Bar Widgets")
                .font(.title)
                .fontWeight(.semibold)

            Text("Add and configure widgets for your menu bar")
                .font(.subheadline)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Available Widgets Section

    private var availableWidgetsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Available Widgets")
                .font(.headline)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            // Category filter
            categoryFilter

            // Widget grid
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 140, maximum: 180), spacing: DesignTokens.Spacing.sm)
                ],
                spacing: DesignTokens.Spacing.sm
            ) {
                ForEach(filteredWidgets) { widget in
                    AvailableWidgetCard(
                        widget: widget,
                        onAdd: { viewModel.addWidget(widget) }
                    )
                }
            }
        }
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                CategoryButton(
                    title: "All",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(WidgetCategory.allCases) { category in
                    CategoryButton(
                        title: category.rawValue,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.xs)
        }
    }

    private var filteredWidgets: [AvailableWidgetType] {
        guard let category = selectedCategory else {
            return viewModel.availableWidgets
        }
        return viewModel.availableWidgets.filter { $0.category == category }
    }

    // MARK: - Active Widgets Section (Horizontal Layout)

    private var activeWidgetsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Text("Active Widgets")
                    .font(.headline)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Spacer()

                Text("\(viewModel.activeWidgets.count) widgets")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            if viewModel.activeWidgets.isEmpty {
                emptyActiveWidgetsState
            } else {
                activeWidgetsScroll
            }
        }
    }

    private var emptyActiveWidgetsState: some View {
        Card(variant: .flat) {
            VStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 32))
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                Text("No Active Widgets")
                    .font(.subheadline)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Text("Add widgets from the available section above")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignTokens.Spacing.lg)
        }
    }

    private var activeWidgetsScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(viewModel.activeWidgets) { widget in
                    ActiveWidgetCard(
                        widget: widget,
                        onRemove: { viewModel.removeWidget(widget) },
                        onToggle: { viewModel.toggleWidget(widget) },
                        onConfigure: { configureWidget(widget) }
                    )
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
        }
        .frame(height: 120)
    }

    private func configureWidget(_ widget: ActiveWidget) {
        // Open configuration sheet
    }
}

// MARK: - Available Widget Card

struct AvailableWidgetCard: View {
    let widget: AvailableWidgetType
    let onAdd: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onAdd) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack {
                    Image(systemName: widget.icon)
                        .font(.system(size: 16))
                        .foregroundColor(DesignTokens.Colors.accent)
                        .frame(width: 24, height: 24)

                    Spacer()

                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DesignTokens.Colors.accent)
                        .opacity(isHovering ? 1 : 0.5)
                }

                Text(widget.rawValue)
                    .font(.subheadline)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text(widget.description)
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineLimit(2)
            }
            .padding(DesignTokens.Spacing.md)
            .frame(height: 72)
            .background(isHovering ? DesignTokens.Colors.selectedContentBackground : DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Active Widget Card

struct ActiveWidgetCard: View {
    let widget: ActiveWidget
    let onRemove: () -> Void
    let onToggle: () -> Void
    let onConfigure: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                Image(systemName: widget.type.icon)
                    .font(.system(size: 14))
                    .foregroundColor(widget.isEnabled ? DesignTokens.Colors.accent : DesignTokens.Colors.textTertiary)

                Spacer()

                if isHovering {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Button(action: onConfigure) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)

                        Button(action: onRemove) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity)
                }
            }

            Text(widget.name)
                .font(.caption)
                .foregroundColor(widget.isEnabled ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textTertiary)

            Toggle("", isOn: Binding(
                get: { widget.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .padding(DesignTokens.Spacing.md)
        .frame(width: 120, height: 100)
        .background(DesignTokens.Colors.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .stroke(widget.isEnabled ? DesignTokens.Colors.accent : DesignTokens.Colors.separator, lineWidth: widget.isEnabled ? 2 : 1)
        )
        .opacity(widget.isEnabled ? 1 : 0.6)
        .onHover { hovering in
            withAnimation {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Category Button

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.backgroundSecondary)
                .foregroundColor(isSelected ? .white : DesignTokens.Colors.textPrimary)
                .cornerRadius(DesignTokens.CornerRadius.full)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Widgets Panel") {
    WidgetsPanelView()
}
