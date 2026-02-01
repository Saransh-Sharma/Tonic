//
//  WidgetsPanelView.swift
//  Tonic
//
//  Main Widgets Panel configuration UI
//  Uses the unified WidgetType + VisualizationType system for Stats Master parity
//

import SwiftUI

// MARK: - Widget Category

/// Categories for organizing widget data sources
public enum WidgetCategory: String, CaseIterable, Identifiable {
    case system = "System"
    case environment = "Environment"

    public var id: String { rawValue }

    public var widgetTypes: [WidgetType] {
        switch self {
        case .system:
            return [.cpu, .gpu, .memory, .disk, .network, .battery, .sensors]
        case .environment:
            return [.weather]
        }
    }
}

// MARK: - Widget Panel View Model

@Observable
@MainActor
public final class WidgetPanelViewModel {
    public var activeConfigs: [WidgetConfiguration] = []
    public var showingAddSheet = false
    public var showingConfigSheet = false
    public var selectedConfigForEdit: WidgetConfiguration?

    // Add sheet state
    public var selectedDataSource: WidgetType = .cpu
    public var selectedVisualization: VisualizationType = .mini

    public init() {
        loadActiveWidgets()
    }

    public func loadActiveWidgets() {
        activeConfigs = WidgetPreferences.shared.widgetConfigs
            .filter { $0.isEnabled }
            .sorted { $0.position < $1.position }
    }

    public func addWidget() {
        let position = WidgetPreferences.shared.widgetConfigs.count
        var newConfig = WidgetConfiguration(
            type: selectedDataSource,
            visualizationType: selectedVisualization,
            isEnabled: true,
            position: position,
            displayMode: .compact,
            showLabel: false,
            valueFormat: selectedDataSource.defaultValueFormat,
            refreshInterval: .balanced,
            accentColor: .system,
            chartConfig: selectedVisualization.supportsHistory ? ChartConfiguration.default : nil
        )

        // Add to preferences
        WidgetPreferences.shared.widgetConfigs.append(newConfig)
        WidgetPreferences.shared.saveConfigs()

        // Refresh the widget coordinator
        WidgetCoordinator.shared.refreshWidgets()

        // Reload local state
        loadActiveWidgets()

        // Reset add sheet state
        selectedDataSource = .cpu
        selectedVisualization = .mini
        showingAddSheet = false
    }

    public func removeWidget(_ config: WidgetConfiguration) {
        // Find and disable the widget
        WidgetPreferences.shared.setWidgetEnabled(type: config.type, enabled: false)

        // Refresh coordinator
        WidgetCoordinator.shared.refreshWidgets()

        // Reload local state
        loadActiveWidgets()
    }

    public func toggleWidget(_ config: WidgetConfiguration) {
        WidgetPreferences.shared.toggleWidget(type: config.type)
        WidgetCoordinator.shared.refreshWidgets()
        loadActiveWidgets()
    }

    public func updateVisualization(for config: WidgetConfiguration, to visualization: VisualizationType) {
        WidgetPreferences.shared.setWidgetVisualization(type: config.type, visualization: visualization)
        WidgetCoordinator.shared.refreshWidgets()
        loadActiveWidgets()
    }

    public func reorderWidgets(from source: IndexSet, to destination: Int) {
        var configs = activeConfigs
        configs.move(fromOffsets: source, toOffset: destination)

        // Update positions
        for (index, var config) in configs.enumerated() {
            if let existingIndex = WidgetPreferences.shared.widgetConfigs.firstIndex(where: { $0.id == config.id }) {
                WidgetPreferences.shared.widgetConfigs[existingIndex].position = index
            }
        }

        WidgetPreferences.shared.saveConfigs()
        WidgetCoordinator.shared.refreshWidgets()
        loadActiveWidgets()
    }

    /// Called when data source changes in add sheet
    public func onDataSourceChanged() {
        // Reset to default visualization for new data source
        selectedVisualization = selectedDataSource.defaultVisualization
    }
}

// MARK: - Widgets Panel View

/// Main Widgets Panel for widget configuration
/// Uses the unified WidgetType + VisualizationType system
public struct WidgetsPanelView: View {
    @State private var viewModel = WidgetPanelViewModel()
    @State private var selectedCategory: WidgetCategory? = nil

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xl) {
                // Header
                header

                // Active Widgets Section
                activeWidgetsSection

                Divider()
                    .padding(.horizontal, DesignTokens.Spacing.md)

                // Available Data Sources Section
                availableDataSourcesSection
            }
            .padding(DesignTokens.Spacing.md)
        }
        .background(DesignTokens.Colors.background)
        .navigationTitle("Menu Bar Widgets")
        .sheet(isPresented: $viewModel.showingAddSheet) {
            AddWidgetSheet(viewModel: viewModel)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                Text("Menu Bar Widgets")
                    .font(.title)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { viewModel.showingAddSheet = true }) {
                    Label("Add Widget", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }

            Text("Configure widgets for your menu bar. Each data source can use different visualizations.")
                .font(.subheadline)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Active Widgets Section

    private var activeWidgetsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Text("Active Widgets")
                    .font(.headline)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Spacer()

                Text("\(viewModel.activeConfigs.count) active")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            if viewModel.activeConfigs.isEmpty {
                emptyActiveWidgetsState
            } else {
                activeWidgetsList
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

                Text("Click 'Add Widget' to add widgets to your menu bar")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .multilineTextAlignment(.center)

                Button(action: { viewModel.showingAddSheet = true }) {
                    Label("Add Widget", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .padding(.top, DesignTokens.Spacing.xs)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignTokens.Spacing.lg)
        }
    }

    private var activeWidgetsList: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(viewModel.activeConfigs) { config in
                ActiveWidgetRow(
                    config: config,
                    onRemove: { viewModel.removeWidget(config) },
                    onToggle: { viewModel.toggleWidget(config) },
                    onVisualizationChange: { viz in
                        viewModel.updateVisualization(for: config, to: viz)
                    }
                )
            }
        }
    }

    // MARK: - Available Data Sources Section

    private var availableDataSourcesSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Data Sources")
                .font(.headline)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            // Category filter
            categoryFilter

            // Data source grid
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 140, maximum: 180), spacing: DesignTokens.Spacing.sm)
                ],
                spacing: DesignTokens.Spacing.sm
            ) {
                ForEach(filteredDataSources, id: \.self) { type in
                    DataSourceCard(
                        type: type,
                        isEnabled: viewModel.activeConfigs.contains { $0.type == type },
                        onTap: {
                            viewModel.selectedDataSource = type
                            viewModel.selectedVisualization = type.defaultVisualization
                            viewModel.showingAddSheet = true
                        }
                    )
                }
            }
        }
    }

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

    private var filteredDataSources: [WidgetType] {
        guard let category = selectedCategory else {
            return WidgetType.allCases
        }
        return category.widgetTypes
    }
}

// MARK: - Add Widget Sheet

struct AddWidgetSheet: View {
    @Bindable var viewModel: WidgetPanelViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Widget")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content
            Form {
                // Data Source Picker
                Section("Data Source") {
                    Picker("Type", selection: $viewModel.selectedDataSource) {
                        ForEach(WidgetType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .onChange(of: viewModel.selectedDataSource) { _, _ in
                        viewModel.onDataSourceChanged()
                    }

                    Text(dataSourceDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Visualization Picker
                Section("Visualization Style") {
                    Picker("Style", selection: $viewModel.selectedVisualization) {
                        ForEach(viewModel.selectedDataSource.compatibleVisualizations, id: \.self) { viz in
                            Label(viz.displayName, systemImage: viz.icon)
                                .tag(viz)
                        }
                    }

                    Text(viewModel.selectedVisualization.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Preview
                Section("Preview") {
                    HStack {
                        Spacer()
                        widgetPreview
                        Spacer()
                    }
                    .padding(.vertical, DesignTokens.Spacing.md)
                }
            }
            .formStyle(.grouped)

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Add Widget") {
                    viewModel.addWidget()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400, height: 500)
    }

    private var dataSourceDescription: String {
        switch viewModel.selectedDataSource {
        case .cpu: return "CPU usage per core and total utilization"
        case .memory: return "Memory usage, pressure, and allocation"
        case .disk: return "Disk usage per volume"
        case .network: return "Network upload and download speeds"
        case .gpu: return "GPU usage (Apple Silicon only)"
        case .battery: return "Battery level and charging status"
        case .sensors: return "Temperature and fan speed readings"
        case .weather: return "Current weather conditions"
        case .bluetooth: return "Bluetooth device battery levels"
        case .clock: return "Current time display"
        }
    }

    @ViewBuilder
    private var widgetPreview: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: viewModel.selectedDataSource.icon)
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)

                Text(viewModel.selectedVisualization.displayName)
                    .font(.system(size: 12, weight: .medium))

                Image(systemName: viewModel.selectedVisualization.icon)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)

            Text("Menu bar preview")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Active Widget Row

struct ActiveWidgetRow: View {
    let config: WidgetConfiguration
    let onRemove: () -> Void
    let onToggle: () -> Void
    let onVisualizationChange: (VisualizationType) -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: DesignTokens.Spacing.md) {
                // Icon
                Image(systemName: config.type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(config.accentColor.colorValue(for: config.type))
                    .frame(width: 32)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(config.type.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(config.visualizationType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Visualization picker
                Menu {
                    ForEach(config.type.compatibleVisualizations, id: \.self) { viz in
                        Button(action: { onVisualizationChange(viz) }) {
                            Label(viz.displayName, systemImage: viz.icon)
                        }
                    }
                } label: {
                    Image(systemName: config.visualizationType.icon)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 32)

                // Toggle
                Toggle("", isOn: Binding(
                    get: { config.isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
                .labelsHidden()

                // Remove
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.md)
        }
        .background(DesignTokens.Colors.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.medium)
    }
}

// MARK: - Data Source Card

struct DataSourceCard: View {
    let type: WidgetType
    let isEnabled: Bool
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack {
                    Image(systemName: type.icon)
                        .font(.system(size: 16))
                        .foregroundColor(isEnabled ? DesignTokens.Colors.accent : DesignTokens.Colors.textSecondary)
                        .frame(width: 24, height: 24)

                    Spacer()

                    if isEnabled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 14))
                    } else {
                        Image(systemName: "plus.circle")
                            .foregroundColor(DesignTokens.Colors.accent)
                            .font(.system(size: 14))
                            .opacity(isHovering ? 1 : 0.5)
                    }
                }

                Text(type.displayName)
                    .font(.subheadline)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text("\(type.compatibleVisualizations.count) visualizations")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .padding(DesignTokens.Spacing.md)
            .frame(height: 72)
            .background(isHovering ? DesignTokens.Colors.selectedContentBackground : DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                    .stroke(isEnabled ? DesignTokens.Colors.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
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
                .cornerRadius(DesignTokens.CornerRadius.round)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Widgets Panel") {
    WidgetsPanelView()
}
