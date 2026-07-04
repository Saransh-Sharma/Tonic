//
//  WidgetsPanelView.swift
//  Tonic
//
//  Editorial menu-bar widget configuration UI.
//

import SwiftUI

public enum WidgetCategory: String, CaseIterable, Identifiable {
    case system = "System"
    case environment = "Environment"

    public var id: String { rawValue }

    public var widgetTypes: [WidgetType] {
        switch self {
        case .system:
            return WidgetType.parityCases
        case .environment:
            return [.weather]
        }
    }
}

@Observable
@MainActor
public final class WidgetPanelViewModel {
    public var activeConfigs: [WidgetConfiguration] = []
    public var showingAddSheet = false
    public var selectedDataSource: WidgetType = .cpu
    public var selectedVisualization: VisualizationType = .mini

    public init() {
        loadActiveWidgets()
    }

    public func loadActiveWidgets() {
        activeConfigs = WidgetPreferences.shared.widgetConfigs
            .filter(\.isEnabled)
            .sorted { $0.position < $1.position }
    }

    public func addWidget() {
        let position = WidgetPreferences.shared.widgetConfigs.count
        let newConfig = WidgetConfiguration(
            type: selectedDataSource,
            visualizationType: selectedVisualization,
            isEnabled: true,
            position: position,
            displayMode: .compact,
            showLabel: false,
            valueFormat: selectedDataSource.defaultValueFormat,
            refreshInterval: .balanced,
            chartConfig: selectedVisualization.supportsHistory ? ChartConfiguration.default : nil
        )

        if let index = WidgetPreferences.shared.widgetConfigs.firstIndex(where: { $0.type == selectedDataSource }) {
            WidgetPreferences.shared.widgetConfigs[index] = newConfig
        } else {
            WidgetPreferences.shared.widgetConfigs.append(newConfig)
        }

        WidgetPreferences.shared.saveConfigs()
        WidgetCoordinator.shared.refreshWidgets()
        loadActiveWidgets()
        selectedDataSource = .cpu
        selectedVisualization = .mini
        showingAddSheet = false
    }

    public func toggleWidget(_ config: WidgetConfiguration) {
        WidgetPreferences.shared.toggleWidget(type: config.type)
        WidgetCoordinator.shared.refreshWidgets()
        loadActiveWidgets()
    }

    public func removeWidget(_ config: WidgetConfiguration) {
        WidgetPreferences.shared.setWidgetEnabled(type: config.type, enabled: false)
        WidgetCoordinator.shared.refreshWidgets()
        loadActiveWidgets()
    }

    public func updateVisualization(for config: WidgetConfiguration, to visualization: VisualizationType) {
        WidgetPreferences.shared.setWidgetVisualization(type: config.type, visualization: visualization)
        WidgetCoordinator.shared.refreshWidgets()
        loadActiveWidgets()
    }

    public func onDataSourceChanged() {
        selectedVisualization = selectedDataSource.defaultVisualization
    }
}

public struct WidgetsPanelView: View {
    @State private var viewModel = WidgetPanelViewModel()
    @State private var selectedCategory: WidgetCategory = .system

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TonicDS.Space.xl) {
                TonicPageHeader(title: "Menu Bar Widgets", subtitle: "Visibility, cadence, labels, and visual formats for compact system readouts.") {
                    PrimaryPill("Add Widget", systemImage: "plus") {
                        viewModel.showingAddSheet = true
                    }
                }

                SettingsPanel(title: "ACTIVE") {
                    if viewModel.activeConfigs.isEmpty {
                        TonicEmptyState(
                            systemImage: "menubar.rectangle",
                            title: "No Active Widgets",
                            message: "Add a data source to start showing menu-bar readouts.",
                            actionTitle: "Add Widget"
                        ) {
                            viewModel.showingAddSheet = true
                        }
                        .frame(height: 220)
                    } else {
                        ForEach(Array(viewModel.activeConfigs.enumerated()), id: \.element.id) { index, config in
                            ActiveWidgetRow(config: config, viewModel: viewModel, showsDivider: index != viewModel.activeConfigs.count - 1)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
                    HStack(spacing: TonicDS.Space.xs) {
                        ForEach(WidgetCategory.allCases) { category in
                            FilterPill(title: category.rawValue, isActive: selectedCategory == category) {
                                selectedCategory = category
                            }
                        }
                    }

                    SettingsPanel(title: "DATA SOURCES") {
                        ForEach(Array(selectedCategory.widgetTypes.enumerated()), id: \.element.id) { index, type in
                            DataSourceRow(type: type, showsDivider: index != selectedCategory.widgetTypes.count - 1) {
                                viewModel.selectedDataSource = type
                                viewModel.onDataSourceChanged()
                                viewModel.showingAddSheet = true
                            }
                        }
                    }
                }
            }
            .padding(TonicDS.Space.xl)
        }
        .background(TonicDS.Colors.canvas)
        .navigationTitle("Menu Bar Widgets")
        .sheet(isPresented: $viewModel.showingAddSheet) {
            AddWidgetSheet(viewModel: viewModel)
        }
    }
}

private struct ActiveWidgetRow: View {
    let config: WidgetConfiguration
    let viewModel: WidgetPanelViewModel
    let showsDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            SystemListRow {
                Image(systemName: config.type.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(TonicDS.Colors.textMuted)
                    .frame(width: 24)
            } center: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(config.type.displayName)
                        .tonicType(.body)
                        .foregroundStyle(TonicDS.Colors.textPrimary)
                    Text("\(config.visualizationType.displayName) · \(config.refreshInterval.displayName)")
                        .tonicType(.caption)
                        .foregroundStyle(TonicDS.Colors.textMuted)
                }
            } trailing: {
                HStack(spacing: TonicDS.Space.xs) {
                    Picker("", selection: Binding(
                        get: { config.visualizationType },
                        set: { viewModel.updateVisualization(for: config, to: $0) }
                    )) {
                        ForEach(config.type.compatibleVisualizations) { visualization in
                            Text(visualization.shortName).tag(visualization)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)

                    Toggle("", isOn: Binding(
                        get: { config.isEnabled },
                        set: { _ in viewModel.toggleWidget(config) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(TonicDS.Colors.ink)
                    .accessibilityLabel("\(config.type.displayName) enabled")

                    Button {
                        viewModel.removeWidget(config)
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(TonicDS.Colors.textMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(config.type.displayName)")
                    .tonicPointerCursor()
                }
            }
            if showsDivider { TonicHairline().padding(.leading, TonicDS.Space.md) }
        }
    }
}

private struct DataSourceRow: View {
    let type: WidgetType
    let showsDivider: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SystemListRow {
                Image(systemName: type.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(TonicDS.Colors.textMuted)
                    .frame(width: 24)
            } center: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .tonicType(.body)
                        .foregroundStyle(TonicDS.Colors.textPrimary)
                    Text(type.compatibleVisualizations.map(\.shortName).joined(separator: ", "))
                        .tonicType(.caption)
                        .foregroundStyle(TonicDS.Colors.textMuted)
                }
            } trailing: {
                TextAction("Add", systemImage: "plus", color: TonicDS.Colors.linkBlue, action: action)
            } onTap: {
                action()
            }
            if showsDivider { TonicHairline().padding(.leading, TonicDS.Space.md) }
        }
    }
}

private struct AddWidgetSheet: View {
    @Bindable var viewModel: WidgetPanelViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetChrome(title: "Add Widget", onClose: { dismiss() }) {
            VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
                SettingsPanel(title: "DATA SOURCE") {
                    ForEach(Array(WidgetType.parityCases.enumerated()), id: \.element.id) { index, type in
                        SystemListRow {
                            Image(systemName: type.icon)
                                .foregroundStyle(TonicDS.Colors.textMuted)
                                .frame(width: 24)
                        } center: {
                            Text(type.displayName)
                                .tonicType(.body)
                                .foregroundStyle(TonicDS.Colors.textPrimary)
                        } trailing: {
                            if viewModel.selectedDataSource == type {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(TonicDS.Colors.ink)
                            }
                        } onTap: {
                            viewModel.selectedDataSource = type
                            viewModel.onDataSourceChanged()
                        }
                        if index != WidgetType.parityCases.count - 1 {
                            TonicHairline().padding(.leading, TonicDS.Space.md)
                        }
                    }
                }

                SettingsPanel(title: "VISUALIZATION") {
                    ForEach(Array(viewModel.selectedDataSource.compatibleVisualizations.enumerated()), id: \.element.id) { index, visualization in
                        SystemListRow {
                            Image(systemName: visualization.icon)
                                .foregroundStyle(TonicDS.Colors.textMuted)
                                .frame(width: 24)
                        } center: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(visualization.displayName)
                                    .tonicType(.body)
                                    .foregroundStyle(TonicDS.Colors.textPrimary)
                                Text(visualization.description)
                                    .tonicType(.caption)
                                    .foregroundStyle(TonicDS.Colors.textMuted)
                            }
                        } trailing: {
                            if viewModel.selectedVisualization == visualization {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(TonicDS.Colors.ink)
                            }
                        } onTap: {
                            viewModel.selectedVisualization = visualization
                        }
                        if index != viewModel.selectedDataSource.compatibleVisualizations.count - 1 {
                            TonicHairline().padding(.leading, TonicDS.Space.md)
                        }
                    }
                }
            }
            .frame(width: 480)
        } footer: {
            TextAction("Cancel") { dismiss() }
            PrimaryPill("Add Widget", systemImage: "plus") {
                viewModel.addWidget()
                dismiss()
            }
        }
    }
}
