//
//  HubViews.swift
//  Tonic
//
//  Five-hub product shell and high-signal hub landing experiences.
//

import SwiftUI

struct TonicHomeView: View {
    @Binding var route: TonicRoute
    @State private var metrics = WidgetDataManager.shared
    @State private var receiptStore = ActionReceiptStore.shared
    @State private var snapshot: SystemSnapshot?

    private var cpuFraction: Double { min(max(metrics.cpuData.totalUsage / 100, 0), 1) }
    private var memoryFraction: Double {
        guard metrics.memoryData.totalBytes > 0 else { return 0 }
        return min(Double(metrics.memoryData.usedBytes) / Double(metrics.memoryData.totalBytes), 1)
    }
    private var diskFraction: Double {
        guard let disk = metrics.diskVolumes.first(where: \.isBootVolume) ?? metrics.diskVolumes.first else { return 0 }
        return min(disk.usagePercentage / 100, 1)
    }

    private var narrative: String {
        if diskFraction > 0.90 { return "Storage needs attention." }
        if memoryFraction > 0.85 { return "Memory pressure is elevated." }
        if cpuFraction > 0.85 { return "Your Mac is working unusually hard." }
        return "Everything is running normally."
    }

    private var evidence: String {
        if diskFraction > 0.90 { return "Your startup disk is more than 90% full. Review what is using space before removing anything." }
        if memoryFraction > 0.85 { return "Memory use is above 85%. Monitor can identify the processes contributing right now." }
        if cpuFraction > 0.85 { return "Processor use is above 85%. Open Monitor to inspect the current contributors." }
        return "Tonic found no urgent storage, memory, processor, or connectivity issue in the latest live sample."
    }

    var body: some View {
        TonicScreenScaffold {
            VStack(alignment: .leading, spacing: TonicDS.Space.xl) {
                InstrumentHeader("Home", state: "A concise view of what matters now") {
                    Button {
                        route = .tool(.systemMonitor)
                    } label: {
                        Label("Open Monitor", systemImage: "waveform.path.ecg")
                    }
                    .buttonStyle(.bordered)
                }

                StatusNarrative(narrative, evidence: evidence)

                machineStrip

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: TonicDS.Space.sm)], spacing: TonicDS.Space.sm) {
                    MetricConsole(
                        title: "Processor",
                        value: String(format: "%.0f", cpuFraction * 100),
                        unit: "%",
                        history: metrics.cpuHistory,
                        status: TonicDS.statusLevel(forFraction: cpuFraction)
                    )
                    MetricConsole(
                        title: "Memory",
                        value: String(format: "%.0f", memoryFraction * 100),
                        unit: "%",
                        history: metrics.memoryHistory,
                        status: TonicDS.statusLevel(forFraction: memoryFraction)
                    )
                    MetricConsole(
                        title: "Storage",
                        value: String(format: "%.0f", diskFraction * 100),
                        unit: "%",
                        history: metrics.diskHistory,
                        status: TonicDS.statusLevel(forFraction: diskFraction)
                    )
                    MetricConsole(
                        title: "Network",
                        value: metrics.networkData.isConnected ? "Online" : "Offline",
                        unit: nil,
                        history: metrics.networkDownloadHistory,
                        status: metrics.networkData.isConnected ? .success : .critical
                    )
                }

                needsAttention
                favorites
                recentChanges
            }
        }
        .task {
            snapshot = try? SystemSnapshotProvider.fetch()
            metrics.startMonitoring()
        }
    }

    private var machineStrip: some View {
        HStack(spacing: 0) {
            machineValue("Mac", snapshot?.deviceDisplayName ?? "This Mac")
            machineValue("Chip", snapshot?.processorSummary ?? "Reading…")
            machineValue("Memory", snapshot?.memorySummary ?? "Reading…")
            machineValue("Displays", "\(NSScreen.screens.count) connected")
            machineValue("Network", metrics.networkData.isConnected ? metrics.networkData.connectionType.rawValue : "Offline")
        }
        .padding(.vertical, TonicDS.Space.sm)
        .tonicSurface(.surface,
                      in: RoundedRectangle(cornerRadius: TonicDS.Radius.md, style: .continuous),
                      tint: TonicDS.Colors.canvasSoft,
                      flatFill: TonicDS.Colors.canvasSoft,
                      flatStroke: TonicDS.Colors.hairline)
    }

    private func machineValue(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            MonoLabel(label)
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .help(value)
        }
        .padding(.horizontal, TonicDS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var needsAttention: some View {
        VStack(alignment: .leading, spacing: 0) {
            MonoLabel("Needs attention")
                .padding(.bottom, TonicDS.Space.xs)
            TonicHairline()
            if diskFraction > 0.90 {
                EvidenceRow(symbol: "internaldrive", title: "Startup disk is nearly full", reason: "Review large and recently grown files before taking action.", metadata: String(format: "%.0f%% used", diskFraction * 100)) {
                    Button("Inspect") { route = .tool(.storage) }.buttonStyle(.borderless)
                }
            } else if cpuFraction > 0.85 || memoryFraction > 0.85 {
                EvidenceRow(symbol: "waveform.path.ecg", title: "Live resource use is elevated", reason: "Inspect the process evidence behind the current reading.", metadata: nil) {
                    Button("Inspect") { route = .tool(.systemMonitor) }.buttonStyle(.borderless)
                }
            } else {
                EvidenceRow(symbol: "checkmark.circle", title: "No urgent findings", reason: "Tonic will surface evidence here when the underlying state materially changes.", metadata: "Live sample") {
                    EmptyView()
                }
            }
        }
    }

    private var favorites: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
            MonoLabel("Daily control")
            HStack(spacing: TonicDS.Space.sm) {
                favorite(.windows, "Arrange a window")
                favorite(.menuBar, "Make menu bar room")
                favorite(.systemMonitor, "Inspect live activity")
                favorite(.smartCare, "Run Smart Care")
            }
        }
    }

    private func favorite(_ tool: TonicToolID, _ subtitle: String) -> some View {
        Button { route = .tool(tool) } label: {
            VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
                Image(systemName: tool.symbol)
                    .font(.system(size: 18, weight: .medium))
                Text(tool.title).font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(TonicDS.Colors.textMuted)
                    .lineLimit(2)
            }
            .foregroundStyle(TonicDS.Colors.textPrimary)
            .padding(TonicDS.Space.md)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .background(TonicDS.Colors.softStone, in: RoundedRectangle(cornerRadius: TonicDS.Radius.md))
        }
        .buttonStyle(TonicPressStyle())
        .tonicFocusableControl(radius: TonicDS.Radius.md)
    }

    private var recentChanges: some View {
        VStack(alignment: .leading, spacing: 0) {
            MonoLabel("Recent changes")
                .padding(.bottom, TonicDS.Space.xs)
            TonicHairline()
            if receiptStore.receipts.isEmpty {
                EvidenceRow(symbol: "clock", title: "No Tonic actions yet", reason: "Completed window, menu bar, automation, and Care actions will leave proof here.", metadata: nil) { EmptyView() }
            } else {
                ForEach(receiptStore.receipts.prefix(4)) { receipt in
                    ActionReceiptView(receipt: receipt)
                    TonicHairline()
                }
            }
        }
    }
}

struct CareHubView: View {
    @State private var tool: TonicToolID
    let onPermissionNeeded: (PermissionManager.Feature) -> Void
    @ObservedObject var smartCareSession: SmartCareSessionStore
    @State private var permissionManager = PermissionManager.shared

    init(initialTool: TonicToolID = .smartCare, smartCareSession: SmartCareSessionStore, onPermissionNeeded: @escaping (PermissionManager.Feature) -> Void) {
        _tool = State(initialValue: initialTool)
        self.smartCareSession = smartCareSession
        self.onPermissionNeeded = onPermissionNeeded
    }

    var body: some View {
        VStack(spacing: 0) {
            hubSwitcher(title: "Care", selection: $tool, tools: [.smartCare, .storage, .apps])
            Group {
                switch tool {
                case .storage:
                    CleanView(session: smartCareSession, initialTab: .storage)
                case .apps:
                    if BuildCapabilities.current.requiresScopeAccess || permissionManager.hasFullDiskAccess {
                        AppsView()
                    } else {
                        PermissionRequiredView(icon: "externaldrive", title: "Choose what Tonic can inspect", description: "Authorize app locations so Tonic can calculate complete footprints and preview uninstall impact.") {
                            onPermissionNeeded(.appManager)
                        }
                    }
                default:
                    CleanView(session: smartCareSession)
                }
            }
        }
        .onChange(of: tool) { _, _ in TonicFeedback.alignment() }
    }
}

struct OrganizeHubView: View {
    @State private var tool: TonicToolID

    init(initialTool: TonicToolID = .windows) {
        _tool = State(initialValue: initialTool)
    }

    var body: some View {
        VStack(spacing: 0) {
            hubSwitcher(title: "Organize", selection: $tool, tools: [.windows, .menuBar])
            if tool == .menuBar {
                MenuBarDashboardView(isActive: true)
            } else {
                WindowManagementView()
            }
        }
        .onChange(of: tool) { _, _ in TonicFeedback.alignment() }
    }
}

struct MonitorHubView: View {
    @State private var tool: TonicToolID

    init(initialTool: TonicToolID = .systemMonitor) {
        _tool = State(initialValue: initialTool)
    }

    var body: some View {
        VStack(spacing: 0) {
            hubSwitcher(title: "Monitor", selection: $tool, tools: [.systemMonitor, .widgets])
            if tool == .widgets {
                SettingsView(initialSection: .modules)
            } else {
                MonitorView(isActive: true)
            }
        }
    }
}

struct AutomationHubView: View {
    var body: some View {
        AutomationsView()
    }
}

/// Liquid Tonic Z3: a floating glass capsule bar instead of a full-bleed strip.
/// It hugs its content and leaves the desktop light visible around it.
@MainActor
private func hubSwitcher(title: String, selection: Binding<TonicToolID>, tools: [TonicToolID]) -> some View {
    HStack {
        GlassEffectContainer {
            HStack(spacing: TonicDS.Space.md) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Picker(title, selection: selection) {
                    ForEach(tools) { tool in
                        Label(tool.title, systemImage: tool.symbol).tag(tool)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 480)
            }
            .padding(.horizontal, TonicDS.Space.lg)
            .frame(height: 44)
            .tonicSurface(.chrome, in: Capsule())
        }
        Spacer()
    }
    .padding(.leading, TonicDS.Glass.Shell.trafficLightContentClearance)
    .padding(.trailing, TonicDS.Space.lg)
    .padding(.top, TonicDS.Space.sm)
    .padding(.bottom, TonicDS.Space.xs)
}
