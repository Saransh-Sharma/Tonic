//
//  DiskAnalysisView.swift
//  Tonic
//
//  Storage Intelligence Hub 2.0
//

import SwiftUI
import AppKit

enum StorageHubTab: String, CaseIterable, Identifiable {
    case home = "Hub Home"
    case explore = "Explore"
    case act = "Act"
    case insights = "Insights"
    case history = "History"

    var id: String { rawValue }
}

enum CleanupWorkflowMode: String, CaseIterable, Identifiable {
    case guided = "Guided Assistant"
    case cart = "Cart + Review"

    var id: String { rawValue }
}

struct DiskAnalysisView: View {
    private enum FocusField: Hashable {
        case rootPath
        case search
        case pathJump
    }

    @State private var engine = StorageIntelligenceEngine()
    @State private var selectedTab: StorageHubTab = .home
    @State private var workflowMode: CleanupWorkflowMode = .guided
    @State private var scanMode: StorageScanMode = .quick
    @State private var rootPath: String = FileManager.default.homeDirectoryForCurrentUser.path
    @State private var pathJumpText: String = FileManager.default.homeDirectoryForCurrentUser.path
    @State private var backStack: [String] = []
    @State private var forwardStack: [String] = []
    @State private var isScanning = false
    @State private var isCheckingPermissions = false
    @State private var hasFullDiskAccess = false
    @State private var permissionManager = PermissionManager.shared
    @State private var latestProgressPath: String = ""
    @State private var latestProgressBytes: Int64 = 0
    @State private var latestProgressFiles: Int64 = 0
    @State private var scanPhase: String = "Idle"
    @State private var recentScannedPaths: [String] = []
    @State private var scanWarning: String?
    @State private var cleanupResult: CleanupExecutionResult?
    @State private var showingPreview = false
    @State private var keyMonitor: Any?
    @FocusState private var focusedField: FocusField?

    private var selectedNode: StorageNode? {
        engine.selectedNode
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()

            if isCheckingPermissions {
                ProgressView("Checking permissions…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !hasFullDiskAccess {
                permissionRequiredView
            } else {
                tabBar

                Divider()

                VStack(spacing: 0) {
                    if isScanning {
                        scanProgressPanel
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        Divider()
                    }

                    contentView
                }
            }
        }
        .sheet(isPresented: $showingPreview) {
            previewSheet
        }
        .task {
            await checkPermissions()
            pathJumpText = engine.currentPath
            installKeyMonitorIfNeeded()
        }
        .onChange(of: engine.currentPath) { _, newValue in
            pathJumpText = newValue
        }
        .onDisappear {
            engine.setLiveMonitoring(enabled: false)
            removeKeyMonitor()
        }
    }

    private var headerBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Label("Storage Intelligence Hub", systemImage: "internaldrive.fill")
                    .font(.system(size: 20, weight: .semibold))

                Spacer()

                Picker("Scan Mode", selection: $scanMode) {
                    ForEach(StorageScanMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 270)

                Button {
                    if isScanning {
                        stopScan()
                    } else {
                        startScan()
                    }
                } label: {
                    Label(isScanning ? "Stop" : "Scan", systemImage: isScanning ? "stop.circle.fill" : "play.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }

            HStack(spacing: 8) {
                TextField("Root path", text: $rootPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .focused($focusedField, equals: .rootPath)

                Button("Use Home") {
                    rootPath = FileManager.default.homeDirectoryForCurrentUser.path
                }
                .buttonStyle(.bordered)

                Button("Use Current") {
                    rootPath = engine.currentPath
                }
                .buttonStyle(.bordered)

                Spacer()

                if let session = engine.session {
                    Label("Confidence \(Int(session.confidence * 100))%", systemImage: "shield.checkered")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 14) {
                Label(scanPhaseStatusText, systemImage: "gauge.with.dots.needle.bottom.50percent")
                    .foregroundStyle(isScanning ? .blue : .secondary)
                Label("\(ByteCountFormatter.string(fromByteCount: latestProgressBytes, countStyle: .file)) scanned", systemImage: "externaldrive")
                Label("\(NumberFormatter.localizedString(from: NSNumber(value: latestProgressFiles), number: .decimal)) items", systemImage: "doc")

                if !latestProgressPath.isEmpty {
                    Text(latestProgressPath)
                        .font(.system(.caption2, design: .monospaced))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let warning = scanWarning ?? engine.lastWarning {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var scanProgressPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.regular)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Scanning your storage")
                        .font(.headline)
                    Text("Step \(scanPhaseStep) of 3 • \(scanPhaseStatusText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            ProgressView(value: scanStageProgress)
                .progressViewStyle(.linear)

            HStack(spacing: 14) {
                Label("\(ByteCountFormatter.string(fromByteCount: latestProgressBytes, countStyle: .file)) scanned", systemImage: "externaldrive.fill")
                Label("\(NumberFormatter.localizedString(from: NSNumber(value: latestProgressFiles), number: .decimal)) items", systemImage: "doc.badge.gearshape")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let session = engine.session, isScanning {
                let elapsed = Date().timeIntervalSince(session.startAt)
                Text("Throughput \(formattedRate(session.filesPerSecond))/s • Dirs \(formattedRate(session.directoriesPerSecond))/s • Elapsed \(formattedDuration(elapsed)) • Energy \(session.energyMode.capitalized)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if scanPhaseStatusText.lowercased().contains("index") {
                Text("Building tree map from scanned directories • \(formattedCount(engine.session?.indexedDirectories ?? 0)) directories • \(formattedCount(engine.session?.indexedNodes ?? 0)) items indexed")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !latestProgressPath.isEmpty {
                Text("Now scanning: \(abbreviatedPath(latestProgressPath))")
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }

            if hasEstimatedNodeSizes {
                Label("Some deep sizes are estimated; open a folder to resolve exact values.", systemImage: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let longScanWarning {
                Label(longScanWarning, systemImage: "bolt.horizontal.circle")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            if !recentScannedPaths.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(recentScannedPaths.suffix(4).reversed()), id: \.self) { path in
                            Text(abbreviatedPath(path))
                                .font(.system(.caption2, design: .monospaced))
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }

    private var tabBar: some View {
        HStack {
            Picker("Tab", selection: $selectedTab) {
                ForEach(StorageHubTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 520)

            Spacer()

            if selectedTab == .explore {
                Button("Focus", action: focusOnSelection)
                    .keyboardShortcut("f", modifiers: [.command])
                Button("Toggle Cart", action: toggleSelectionInCart)
                    .keyboardShortcut("a", modifiers: [.command])
                Button("Guided", action: sendSelectionToGuided)
                    .keyboardShortcut("g", modifiers: [.command])
                Button("Preview", action: openPreview)
                    .keyboardShortcut(.space, modifiers: [])
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .home:
            hubHomeView
        case .explore:
            exploreView
        case .act:
            actView
        case .insights:
            insightsView
        case .history:
            historyView
        }
    }

    private var permissionRequiredView: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Full Disk Access Required")
                .font(.title3.weight(.semibold))

            Text("Storage Intelligence Hub needs Full Disk Access to provide accurate hidden-space analysis and safe cleanup recommendations.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)

            HStack {
                Button("Open System Settings") {
                    _ = permissionManager.requestFullDiskAccess()
                }
                .buttonStyle(.borderedProminent)

                Button("Re-check") {
                    Task { await checkPermissions() }
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    private var hubHomeView: some View {
        ScrollView {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Storage Storyboard")
                        .font(.headline)
                    Text(engine.storyboardHeadline)
                        .font(.title3.weight(.semibold))
                    if let forecast = engine.forecast {
                        HStack(spacing: 8) {
                            Label(forecastNarrative(forecast), systemImage: "chart.line.uptrend.xyaxis")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(Int(forecast.confidence * 100))% confidence")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                HStack(spacing: 12) {
                    summaryCard(
                        title: "Reclaimable",
                        value: ByteCountFormatter.string(fromByteCount: engine.totalReclaimableBytes, countStyle: .file),
                        subtitle: "Safe opportunities from packs",
                        tint: .green
                    )

                    summaryCard(
                        title: "Current Scope",
                        value: abbreviatedPath(engine.currentPath),
                        subtitle: "Actively explored path",
                        tint: .blue
                    )

                    summaryCard(
                        title: "Cart",
                        value: "\(engine.cartCandidates.count) items",
                        subtitle: "Selected for cleanup",
                        tint: .orange
                    )
                }

                HStack(spacing: 12) {
                    summaryCard(
                        title: "Top Domain",
                        value: dominantDomainLabel,
                        subtitle: "Largest storage concentration",
                        tint: .purple
                    )

                    summaryCard(
                        title: "Scan Status",
                        value: engine.session?.status.rawValue.capitalized ?? "Idle",
                        subtitle: engine.session?.mode.rawValue ?? "Quick",
                        tint: .teal
                    )

                    summaryCard(
                        title: "Last Run",
                        value: historyHeadline,
                        subtitle: "Most recent scan completion",
                        tint: .pink
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Reclaim Packs")
                        .font(.headline)

                    if engine.reclaimPacks.isEmpty {
                        PlaceholderStatePanel(title: "No packs yet", message: "Run a scan to generate reclaim packs like Downloads old files, Browser caches, and Xcode artifacts.")
                    } else {
                        ForEach(engine.reclaimPacks.prefix(6)) { pack in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pack.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(pack.rationale)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(ByteCountFormatter.string(fromByteCount: pack.reclaimableBytes, countStyle: .file))
                                    .font(.system(.caption, design: .monospaced))

                                Button("Add") {
                                    engine.addPackToCart(pack)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .top, spacing: 12) {
                    forecastCard
                    anomalyCard
                }
            }
            .padding(12)
        }
    }

    private var exploreView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: navigateBack) {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
                .disabled(backStack.isEmpty)

                Button(action: navigateForward) {
                    Label("Forward", systemImage: "chevron.right")
                }
                .buttonStyle(.bordered)
                .disabled(forwardStack.isEmpty)

                Button(action: navigateUp) {
                    Label("Up", systemImage: "chevron.up")
                }
                .buttonStyle(.bordered)

                breadcrumbBar
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextField("Jump to path", text: $pathJumpText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 260)
                    .focused($focusedField, equals: .pathJump)
                    .onSubmit { jumpToPath() }

                Button("Go", action: jumpToPath)
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, 12)

            HStack(spacing: 8) {
                TextField("Filter path or name", text: Binding(
                    get: { engine.filters.searchText },
                    set: { value in engine.setFilter { $0.searchText = value } }
                ))
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .search)
                .frame(width: 240)

                Menu {
                    Button("Show all sizes") { engine.setFilter { $0.minBytes = 0 } }
                    Button("> 50 MB") { engine.setFilter { $0.minBytes = 50 * 1024 * 1024 } }
                    Button("> 500 MB") { engine.setFilter { $0.minBytes = 500 * 1024 * 1024 } }
                    Button("> 2 GB") { engine.setFilter { $0.minBytes = 2 * 1024 * 1024 * 1024 } }
                } label: {
                    Label("Size", systemImage: "line.3.horizontal.decrease")
                }
                .menuStyle(.button)

                Menu {
                    Button("Any age") { engine.setFilter { $0.minAgeDays = nil } }
                    Button("Older than 7 days") { engine.setFilter { $0.minAgeDays = 7 } }
                    Button("Older than 30 days") { engine.setFilter { $0.minAgeDays = 30 } }
                    Button("Older than 90 days") { engine.setFilter { $0.minAgeDays = 90 } }
                } label: {
                    Label("Age", systemImage: "clock.arrow.circlepath")
                }
                .menuStyle(.button)

                Menu {
                    Button("Any last-opened") { engine.setFilter { $0.lastOpenedWindow = .any } }
                    Button("Opened in last 7 days") { engine.setFilter { $0.lastOpenedWindow = .last7Days } }
                    Button("Opened in last 30 days") { engine.setFilter { $0.lastOpenedWindow = .last30Days } }
                    Button("Opened in last 90 days") { engine.setFilter { $0.lastOpenedWindow = .last90Days } }
                    Button("Older than 90 days") { engine.setFilter { $0.lastOpenedWindow = .olderThan90Days } }
                    Divider()
                    Toggle("Strict access-date only", isOn: Binding(
                        get: { engine.filters.lastOpenedIsStrict },
                        set: { value in engine.setFilter { $0.lastOpenedIsStrict = value } }
                    ))
                } label: {
                    Label("Last Opened", systemImage: "clock")
                }
                .menuStyle(.button)

                Menu {
                    Button("All types") { engine.setFilter { $0.fileTypes = Set(StorageFileType.allCases) } }
                    Divider()
                    ForEach(StorageFileType.allCases) { fileType in
                        Toggle(fileType.rawValue, isOn: Binding(
                            get: { engine.filters.fileTypes.contains(fileType) },
                            set: { isOn in
                                engine.setFilter { state in
                                    if isOn {
                                        state.fileTypes.insert(fileType)
                                    } else {
                                        state.fileTypes.remove(fileType)
                                    }
                                    if state.fileTypes.isEmpty {
                                        state.fileTypes = Set(StorageFileType.allCases)
                                    }
                                }
                            }
                        ))
                    }
                } label: {
                    Label("File Type", systemImage: "doc.text")
                }
                .menuStyle(.button)

                Menu {
                    Button("All volumes") { engine.setFilter { $0.volumes = [] } }
                    Divider()
                    ForEach(engine.availableVolumes, id: \.self) { volume in
                        Toggle(volume, isOn: Binding(
                            get: { engine.filters.volumes.contains(volume) },
                            set: { isOn in
                                engine.setFilter { state in
                                    if isOn {
                                        state.volumes.insert(volume)
                                    } else {
                                        state.volumes.remove(volume)
                                    }
                                }
                            }
                        ))
                    }
                } label: {
                    Label("Volume", systemImage: "externaldrive")
                }
                .menuStyle(.button)

                Menu {
                    Button("All owners") { engine.setFilter { $0.ownerApps = [] } }
                    ForEach(engine.ownerApps, id: \.self) { owner in
                        Button(owner) { engine.setFilter { $0.ownerApps = Set([owner]) } }
                    }
                } label: {
                    Label("Owner", systemImage: "person.crop.circle")
                }
                .menuStyle(.button)

                Toggle("Hidden", isOn: Binding(
                    get: { engine.filters.includeHidden },
                    set: { value in engine.setFilter { $0.includeHidden = value } }
                ))
                .toggleStyle(.switch)
                .frame(width: 90)

                Toggle("System", isOn: Binding(
                    get: { engine.filters.includeSystem },
                    set: { value in engine.setFilter { $0.includeSystem = value } }
                ))
                .toggleStyle(.switch)
                .frame(width: 90)

                Toggle("Reclaimable", isOn: Binding(
                    get: { engine.filters.onlyReclaimable },
                    set: { value in engine.setFilter { $0.onlyReclaimable = value } }
                ))
                .toggleStyle(.switch)
                .frame(width: 120)

                Toggle("Live", isOn: Binding(
                    get: { engine.liveMonitoringEnabled },
                    set: { value in engine.setLiveMonitoring(enabled: value) }
                ))
                .toggleStyle(.switch)
                .frame(width: 80)
            }
            .padding(.horizontal, 12)

            if engine.visibleNodes.isEmpty {
                PlaceholderStatePanel(
                    title: isScanning ? "Scanning storage…" : "No indexed nodes",
                    message: isScanning ? "Scan is running. Visual explorer will appear as soon as indexing completes." : "Run a scan to explore storage terrain with orbit, treemap, and ranked list."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
            } else {
                let visualNodes = Array(engine.visibleNodes.prefix(400))
                HSplitView {
                    StorageOrbitMapView(
                        nodes: visualNodes,
                        selectedNodeID: engine.selectedNodeID,
                        growthByDomain: growthByDomain,
                        onSelect: { node in
                            engine.selectNode(node)
                        },
                        onDrill: { node in
                            Task {
                                await drillInto(node)
                            }
                        },
                        onPreview: { node in
                            engine.selectNode(node)
                            showingPreview = true
                        },
                        onToggleCart: { node in
                            engine.toggleCart(node)
                        },
                        onGuided: { node in
                            engine.addToCart(node)
                            selectedTab = .act
                            workflowMode = .guided
                        }
                    )
                    .frame(minWidth: 300)

                    StorageTreemapView(
                        nodes: visualNodes,
                        selectedNodeID: engine.selectedNodeID,
                        onSelect: { node in
                            engine.selectNode(node)
                        },
                        onDrill: { node in
                            Task {
                                await drillInto(node)
                            }
                        }
                    )
                    .frame(minWidth: 360)

                    rankedListPanel
                        .frame(minWidth: 360)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)

                if engine.liveMonitoringEnabled {
                    liveMonitoringPanel
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rankedListPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Ranked List")
                    .font(.headline)

                Spacer()

                Text("\(engine.visibleNodes.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)

            List(engine.visibleNodes, id: \.id) { node in
                StorageNodeRow(
                    node: node,
                    isSelected: node.id == engine.selectedNodeID,
                    inCart: engine.cartNodeIDs.contains(node.id),
                    onSelect: { engine.selectNode(node) },
                    onDrill: {
                        Task {
                            await drillInto(node)
                        }
                    },
                    onToggleCart: { engine.toggleCart(node) },
                    onReveal: { revealInFinder(node.path) }
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
        }
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var actView: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Picker("Workflow", selection: $workflowMode) {
                        ForEach(CleanupWorkflowMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 360)

                    Spacer()

                    Text("Default action: Move to Trash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if workflowMode == .guided {
                    guidedAssistantPanel
                } else {
                    cartPanel
                }

                safetyCenterPanel
            }
            .padding(12)
        }
    }

    private var guidedAssistantPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Guided Cleanup")
                .font(.headline)

            if engine.guidedSteps.isEmpty {
                PlaceholderStatePanel(title: "No guided steps", message: "Run a scan to generate guided bundles and cleanup steps.")
            } else {
                let steps = engine.guidedSteps
                let stepIndex = min(engine.activeGuidedStep, max(steps.count - 1, 0))
                let step = steps[stepIndex]
                let reviewPlan = engine.prepareCleanupPlan(mode: .moveToTrash)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(step.title)
                            .font(.title3.weight(.semibold))
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: step.totalBytes, countStyle: .file))
                            .font(.system(.caption, design: .monospaced))
                    }

                    Text(step.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if stepIndex < steps.count - 1 {
                        ForEach(step.packs) { pack in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pack.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(pack.rationale)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(ByteCountFormatter.string(fromByteCount: pack.reclaimableBytes, countStyle: .file))
                                    .font(.system(.caption, design: .monospaced))

                                Button("Accept") {
                                    engine.addPackToCart(pack)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    } else {
                        finalReviewPanel(for: reviewPlan)
                    }

                    HStack {
                        Button("Previous") { engine.previousGuidedStep() }
                            .disabled(stepIndex == 0)
                        Button("Next") { engine.nextGuidedStep() }
                            .disabled(stepIndex >= steps.count - 1)

                        Spacer()

                        Button("Move selected to Trash") {
                            Task {
                                cleanupResult = await engine.executeCleanup(plan: reviewPlan)
                                await refreshAfterCleanup()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(engine.cartCandidates.isEmpty)
                    }
                }
                .padding(10)
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            cleanupResultPanel
        }
    }

    private var cartPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Cart + Review")
                    .font(.headline)
                Spacer()
                Text("\(engine.cartCandidates.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if engine.cartCandidates.isEmpty {
                PlaceholderStatePanel(title: "Cart is empty", message: "Add nodes from Explore using the cart button, A shortcut, or guided pack actions.")
            } else {
                ForEach(engine.groupedCartCandidates) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(group.domain.rawValue) • \(group.actionType == .moveToTrash ? "Move to Trash" : group.actionType.rawValue)")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: group.reclaimableBytes, countStyle: .file))
                                .font(.system(.caption2, design: .monospaced))
                        }

                        ForEach(group.items, id: \.id) { candidate in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(candidate.path)
                                        .font(.system(.caption, design: .monospaced))
                                        .lineLimit(1)

                                    Text(candidate.safeReason)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    if let blocked = candidate.blockedReason {
                                        Text(blocked)
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                }

                                Spacer()

                                Text(ByteCountFormatter.string(fromByteCount: candidate.estimatedReclaimBytes, countStyle: .file))
                                    .font(.system(.caption, design: .monospaced))
                            }
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(8)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                HStack {
                    Button("Exclude Selected Paths") {
                        Task {
                            let plan = engine.prepareCleanupPlan(mode: .excludeForever)
                            cleanupResult = await engine.executeCleanup(plan: plan)
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Move to Trash") {
                        Task {
                            let plan = engine.prepareCleanupPlan(mode: .moveToTrash)
                            cleanupResult = await engine.executeCleanup(plan: plan)
                            await refreshAfterCleanup()
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }
            }

            cleanupResultPanel
        }
    }

    private var safetyCenterPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Safety Center")
                .font(.headline)

            HStack(spacing: 10) {
                safetyBadge(title: "Low", count: riskCount(.low), color: .green)
                safetyBadge(title: "Medium", count: riskCount(.medium), color: .orange)
                safetyBadge(title: "High", count: riskCount(.high), color: .red)
                safetyBadge(title: "Protected", count: riskCount(.protected), color: .gray)
            }

            Text("Protected paths policy: /System, /usr, /bin, /sbin, /private, /Library, and app bundles in /Applications cannot be cleaned through one-click actions.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var insightsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Storage Insights")
                    .font(.headline)

                if engine.insights.isEmpty {
                    PlaceholderStatePanel(title: "No insights yet", message: "Run a scan to generate hidden, purgeable, and domain-level storage insights.")
                } else {
                    ForEach(engine.insights) { insight in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(insight.category.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: insight.bytes, countStyle: .file))
                                    .font(.system(.caption, design: .monospaced))
                                Text("\(Int(insight.confidence * 100))%")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Text(insight.explanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if !insight.recommendedActions.isEmpty {
                                Text(insight.recommendedActions.joined(separator: " • "))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if insight.recommendedActions.contains("Open in App Manager"), let selectedNode {
                                    Button("Open in App Manager") {
                                        engine.openInAppManager(for: selectedNode)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                timeShiftPanel
                forecastPanel
                anomalyPanel
                personaBundlesPanel
                hygieneRoutinesPanel
            }
            .padding(12)
        }
    }

    private var historyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Scan History")
                    .font(.headline)

                if engine.history.isEmpty {
                    PlaceholderStatePanel(title: "No history yet", message: "Completed scans will appear here with confidence and reclaimed space trends.")
                } else {
                    ForEach(engine.history) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(abbreviatedPath(entry.rootPath))
                                    .font(.system(.caption, design: .monospaced))
                                Text("\(entry.mode.rawValue) • confidence \(Int(entry.confidence * 100))%")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(ByteCountFormatter.string(fromByteCount: entry.reclaimedBytes, countStyle: .file))
                                    .font(.system(.caption, design: .monospaced))
                                Text(RelativeDateTimeFormatter().localizedString(for: entry.finishedAt, relativeTo: Date()))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    historyTrendPanel
                }
            }
            .padding(12)
        }
    }

    private var cleanupResultPanel: some View {
        Group {
            if let result = cleanupResult {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Cleanup complete", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: result.cleanedBytes, countStyle: .file))
                            .font(.system(.caption, design: .monospaced))
                    }

                    Text("Reclaimed \(ByteCountFormatter.string(fromByteCount: result.cleanedBytes, countStyle: .file)) • \(result.cleanedItems) cleaned • \(result.excludedItems) excluded")
                        .font(.caption)

                    if let before = result.beforeUsedBytes, let after = result.afterUsedBytes {
                        let delta = max(before - after, 0)
                        Text("Before: \(ByteCountFormatter.string(fromByteCount: before, countStyle: .file)) used • After: \(ByteCountFormatter.string(fromByteCount: after, countStyle: .file)) used • Delta: \(ByteCountFormatter.string(fromByteCount: delta, countStyle: .file))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if result.failedItems > 0 {
                        Text("\(result.failedItems) items could not be completed. Review failures before retry.")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }

                    if engine.lastCleanupPlan?.undoToken != nil {
                        Button("Undo Last Cleanup") {
                            Task {
                                let undone = await engine.undoLastCleanupPlan()
                                if undone {
                                    cleanupResult = nil
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(10)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var previewSheet: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let node = selectedNode {
                Text("Quick Preview")
                    .font(.headline)

                Text(node.name)
                    .font(.title3.weight(.semibold))

                Text(node.path)
                    .font(.system(.caption, design: .monospaced))

                Divider()

                Text("Size: \(node.displayBytes)")
                Text("Reclaimable: \(node.displayReclaimableBytes)")
                Text("Risk: \(node.riskLevel.rawValue.capitalized)")
                Text("Domain: \(node.domain.rawValue)")

                HStack {
                    Button("Reveal in Finder") { revealInFinder(node.path) }
                    if node.ownerApp != nil || node.domain == .applications {
                        Button("Open in App Manager") {
                            engine.openInAppManager(for: node)
                        }
                    }
                    Button("Add to Cart") { engine.addToCart(node) }
                        .buttonStyle(.borderedProminent)
                }

                Spacer()
            } else {
                PlaceholderStatePanel(title: "No selection", message: "Select a storage node in Explore to preview details.")
            }
        }
        .padding(14)
        .frame(width: 420, height: 320)
    }

    private var dominantDomainLabel: String {
        let grouped = Dictionary(grouping: engine.visibleNodes, by: { $0.domain })
            .mapValues { $0.reduce(0) { $0 + $1.logicalBytes } }
        return grouped.max(by: { $0.value < $1.value })?.key.rawValue ?? "—"
    }

    private var growthByDomain: [StorageDomain: Int64] {
        guard let shift = engine.timeShiftSummary else { return [:] }
        return shift.domainDeltas.reduce(into: [StorageDomain: Int64]()) { partialResult, delta in
            partialResult[delta.domain] = delta.bytesDelta
        }
    }

    private var breadcrumbSegments: [(title: String, path: String)] {
        let currentURL = URL(fileURLWithPath: engine.currentPath)
        let components = currentURL.standardized.pathComponents
        guard !components.isEmpty else { return [] }

        var segments: [(String, String)] = []
        var runningPath = ""
        for component in components {
            if component == "/" {
                runningPath = "/"
                segments.append(("Root", runningPath))
                continue
            }
            if runningPath == "/" {
                runningPath += component
            } else {
                runningPath += "/\(component)"
            }
            segments.append((component, runningPath))
        }
        return segments
    }

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(breadcrumbSegments.enumerated()), id: \.offset) { index, segment in
                    Button(segment.title) {
                        Task {
                            await navigate(to: segment.path)
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundStyle(index == breadcrumbSegments.count - 1 ? .primary : .secondary)

                    if index < breadcrumbSegments.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private var historyHeadline: String {
        guard let latest = engine.history.first else { return "Never" }
        return RelativeDateTimeFormatter().localizedString(for: latest.finishedAt, relativeTo: Date())
    }

    private var forecastCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Space Forecast")
                .font(.headline)
            if let forecast = engine.forecast {
                Text(forecast.estimatedDaysToFull.map { "Disk full in ~\($0) days" } ?? "No saturation projected")
                    .font(.subheadline.weight(.semibold))
                Text(forecast.narrative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Growth: \(ByteCountFormatter.string(fromByteCount: forecast.avgDailyGrowthBytes, countStyle: .file))/day")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Run multiple scans to unlock trend-based forecasting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var anomalyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Anomalies")
                .font(.headline)
            if engine.anomalies.isEmpty {
                Text("No major spikes detected in the latest scan.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(engine.anomalies.prefix(2)) { anomaly in
                    HStack {
                        Circle()
                            .fill(severityColor(anomaly.severity))
                            .frame(width: 8, height: 8)
                        Text(anomaly.likelyCause)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(signedBytes(anomaly.bytesDelta))
                            .font(.system(.caption2, design: .monospaced))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var liveMonitoringPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Live Monitoring Overlay")
                    .font(.headline)
                Spacer()
                if let latest = engine.ioVolumeHistory.last {
                    Text("R \(String(format: "%.1f", latest.readMBps)) MB/s • W \(String(format: "%.1f", latest.writeMBps)) MB/s")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if engine.liveHotspots.isEmpty {
                Text("Sampling active paths. Hotspots appear as disk footprint changes are detected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(engine.liveHotspots.prefix(4)) { hotspot in
                    HStack {
                        Text(abbreviatedPath(hotspot.path))
                            .font(.system(.caption2, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        HStack(spacing: 4) {
                            Text(hotspot.sourceConfidence.rawValue.capitalized)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(hotspot.bytesPerSecond >= 0 ? "+\(ByteCountFormatter.string(fromByteCount: hotspot.bytesPerSecond, countStyle: .file))/s" : "-\(ByteCountFormatter.string(fromByteCount: abs(hotspot.bytesPerSecond), countStyle: .file))/s")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(hotspot.bytesPerSecond >= 0 ? .orange : .blue)
                        }
                    }
                }
            }

            if !engine.processDeltas.isEmpty {
                Divider()
                Text("Process Sources")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(Array(engine.processDeltas.prefix(3))) { delta in
                    HStack {
                        Text(delta.processName)
                            .font(.caption2)
                        Text(delta.sourceConfidence.rawValue.capitalized)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: delta.bytesPerSecond, countStyle: .file) + "/s")
                            .font(.system(.caption2, design: .monospaced))
                    }
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var timeShiftPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time-Shift View")
                .font(.headline)
            if let shift = engine.timeShiftSummary {
                Text(shift.narrative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Net change: \(signedBytes(shift.totalBytesDelta)) • Reclaimable: \(signedBytes(shift.reclaimableBytesDelta))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(shift.domainDeltas.prefix(5)) { delta in
                    HStack {
                        Text(delta.domain.rawValue)
                            .font(.caption)
                        Spacer()
                        Text(signedBytes(delta.bytesDelta))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(delta.bytesDelta >= 0 ? .orange : .green)
                    }
                }
            } else {
                Text("Run another scan on the same scope to compare growth and shrink trends.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var forecastPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Forecasting")
                .font(.headline)
            if let forecast = engine.forecast {
                Text(forecast.narrative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let projectedDate = forecast.projectedFullDate {
                    Text("Projected full date: \(projectedDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("Confidence: \(Int(forecast.confidence * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("No forecast available yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var anomalyPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Anomaly Detection")
                .font(.headline)
            if engine.anomalies.isEmpty {
                Text("No anomaly spikes detected from current and historical scans.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(engine.anomalies) { anomaly in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Circle()
                                .fill(severityColor(anomaly.severity))
                                .frame(width: 8, height: 8)
                            Text(anomaly.likelyCause)
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(signedBytes(anomaly.bytesDelta))
                                .font(.system(.caption2, design: .monospaced))
                        }
                        Text(anomaly.recommendation)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var personaBundlesPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Smart Bundles by Persona")
                .font(.headline)
            if engine.personaBundles.isEmpty {
                Text("No persona bundles yet for this scope.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(engine.personaBundles) { bundle in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(bundle.persona.rawValue): \(bundle.title)")
                                .font(.caption.weight(.semibold))
                            Text(bundle.rationale)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: bundle.reclaimableBytes, countStyle: .file))
                            .font(.system(.caption2, design: .monospaced))
                        Button("Add") {
                            engine.addPersonaBundleToCart(bundle)
                            selectedTab = .act
                            workflowMode = .cart
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var hygieneRoutinesPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Automated Hygiene Routines")
                .font(.headline)
            ForEach(engine.hygieneRoutines) { routine in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(routine.title)
                                .font(.caption.weight(.semibold))
                            Text(routine.description)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { routine.isEnabled },
                            set: { _ in engine.toggleHygieneRoutine(routine.id) }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }

                    HStack {
                        Text("Frequency: \(routine.frequency.rawValue)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let nextRun = routine.nextRunAt {
                            Text("Next: \(nextRun.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Button("Run now") {
                            Task {
                                cleanupResult = await engine.runHygieneRoutineNow(routine.id)
                                await refreshAfterCleanup()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var historyTrendPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reclaim Trend")
                .font(.headline)
            let trend = Array(engine.trendHistory.suffix(8))
            if trend.isEmpty {
                Text("Need additional scans to build trend history.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                let peak = max(trend.map(\.reclaimedBytes).max() ?? 1, 1)
                ForEach(trend) { entry in
                    HStack {
                        Text(entry.finishedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 90, alignment: .leading)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue.opacity(0.65))
                                .frame(width: max(8, geo.size.width * CGFloat(Double(entry.reclaimedBytes) / Double(peak))), height: 8)
                        }
                        .frame(height: 8)
                        Text(ByteCountFormatter.string(fromByteCount: entry.reclaimedBytes, countStyle: .file))
                            .font(.system(.caption2, design: .monospaced))
                            .frame(width: 90, alignment: .trailing)
                    }
                    .frame(height: 12)
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func finalReviewPanel(for plan: CleanupPlan) -> some View {
        let dryRun = plan.dryRunResult
        return VStack(alignment: .leading, spacing: 6) {
            Text("Final Review")
                .font(.subheadline.weight(.semibold))
            Text("Dry run estimates reclaim and flags blocked paths before execution.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let dryRun {
                Text("Estimated reclaim: \(ByteCountFormatter.string(fromByteCount: dryRun.cleanedBytes, countStyle: .file))")
                    .font(.caption2)
                Text("Estimated cleaned: \(dryRun.cleanedItems) • blocked: \(dryRun.failedItems)")
                    .font(.caption2)
            }

            Text("Undo is available for trash-based operations. Secure delete cannot be rolled back.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func forecastNarrative(_ forecast: StorageForecast) -> String {
        if let days = forecast.estimatedDaysToFull {
            return "Disk full in about \(days) days at current growth."
        }
        return "No saturation date projected from current trend."
    }

    private func signedBytes(_ value: Int64) -> String {
        let magnitude = ByteCountFormatter.string(fromByteCount: abs(value), countStyle: .file)
        return value >= 0 ? "+\(magnitude)" : "-\(magnitude)"
    }

    private var hasEstimatedNodeSizes: Bool {
        engine.nodesByPath.values.contains { nodes in
            nodes.contains(where: \.sizeIsEstimated)
        }
    }

    private func formattedCount(_ value: Int64) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }

    private func formattedRate(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds.rounded()), 0)
        let minutes = total / 60
        let remaining = total % 60
        return "\(minutes)m \(remaining)s"
    }

    private var longScanWarning: String? {
        guard isScanning, let startAt = engine.session?.startAt else { return nil }
        let elapsed = Date().timeIntervalSince(startAt)
        guard elapsed >= 300 else { return nil }
        return "This scan is taking longer than expected. Try targeted scope, exclude cloud/dev paths, or re-run with Full Disk Access."
    }

    private func severityColor(_ severity: StorageAnomalySeverity) -> Color {
        switch severity {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }

    private func summaryCard(title: String, value: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .lineLimit(1)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func safetyBadge(title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption)
            Text("\(count)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(Capsule())
    }

    private func abbreviatedPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.replacingOccurrences(of: home, with: "~")
    }

    private func riskCount(_ level: StorageRiskLevel) -> Int {
        engine.visibleNodes.filter { $0.riskLevel == level }.count
    }

    private func startScan() {
        scanWarning = nil
        cleanupResult = nil
        isScanning = true
        scanPhase = "Preparing"
        backStack.removeAll()
        forwardStack.removeAll()
        latestProgressPath = ""
        latestProgressBytes = 0
        latestProgressFiles = 0
        recentScannedPaths.removeAll()

        let normalizedRoot: String
        var targetedPaths: [String] = []
        if scanMode == .targeted, let selectedNode {
            normalizedRoot = selectedNode.path
            targetedPaths = [selectedNode.path]
        } else {
            normalizedRoot = rootPath
            if scanMode == .targeted {
                targetedPaths = [rootPath]
            }
        }

        Task {
            for await event in engine.startScan(mode: scanMode, rootPath: normalizedRoot, targetedPaths: targetedPaths) {
                switch event {
                case .phaseStarted(let phase):
                    scanPhase = phase
                case .progress(let filesScanned, let bytesScanned, let currentPath):
                    latestProgressFiles = filesScanned
                    latestProgressBytes = bytesScanned
                    latestProgressPath = currentPath
                    updateRecentScannedPaths(with: currentPath)
                case .nodeIndexed:
                    continue
                case .nodeIndexedBatch:
                    continue
                case .insightReady:
                    continue
                case .warning(let warning):
                    scanWarning = warning
                case .completed:
                    isScanning = false
                    scanPhase = "Completed"
                    pathJumpText = engine.currentPath
                    selectedTab = .explore
                case .cancelled:
                    isScanning = false
                    scanPhase = "Cancelled"
                }
            }
            isScanning = false
        }
    }

    private func stopScan() {
        scanPhase = "Cancelling"
        engine.cancelActiveScan()
        isScanning = false
    }

    private var scanPhaseStatusText: String {
        let phase = scanPhase.trimmingCharacters(in: .whitespacesAndNewlines)
        if phase.isEmpty || phase == "Idle" {
            return isScanning ? "Scanning" : "Idle"
        }
        return phase
    }

    private var scanPhaseStep: Int {
        let lowered = scanPhaseStatusText.lowercased()
        if lowered.contains("prepar") { return 1 }
        if lowered.contains("scan") { return 2 }
        if lowered.contains("index") { return 3 }
        if lowered.contains("complet") { return 3 }
        if lowered.contains("cancel") { return 2 }
        return isScanning ? 2 : 1
    }

    private var scanStageProgress: Double {
        let filesMomentum = min(Double(max(latestProgressFiles, 0)) / 25_000.0, 1.0)
        switch scanPhaseStep {
        case 1:
            return 0.18
        case 2:
            return min(0.35 + filesMomentum * 0.45, 0.8)
        case 3:
            if scanPhaseStatusText.lowercased().contains("complet") {
                return 1.0
            }
            return min(0.82 + filesMomentum * 0.16, 0.98)
        default:
            return isScanning ? 0.4 : 0
        }
    }

    private func updateRecentScannedPaths(with path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if recentScannedPaths.last == trimmed { return }
        recentScannedPaths.append(trimmed)
        if recentScannedPaths.count > 20 {
            recentScannedPaths.removeFirst(recentScannedPaths.count - 20)
        }
    }

    private func focusOnSelection() {
        guard let selectedNode else { return }
        Task {
            await navigate(to: selectedNode.path)
            _ = await engine.loadChildrenIfNeeded(for: selectedNode, forceRefresh: true)
        }
    }

    private func toggleSelectionInCart() {
        guard let selectedNode else { return }
        engine.toggleCart(selectedNode)
    }

    private func sendSelectionToGuided() {
        guard let selectedNode else { return }
        engine.addToCart(selectedNode)
        selectedTab = .act
        workflowMode = .guided
    }

    private func openPreview() {
        guard selectedNode != nil else { return }
        showingPreview = true
    }

    private func drillInto(_ node: StorageNode) async {
        engine.selectNode(node)
        guard node.isDirectory else { return }
        if node.path != engine.currentPath {
            backStack.append(engine.currentPath)
            forwardStack.removeAll()
        }
        engine.setCurrentPath(node.path)
        _ = await engine.loadChildrenIfNeeded(for: node)
    }

    private func navigateUp() {
        let parent = (engine.currentPath as NSString).deletingLastPathComponent
        guard !parent.isEmpty, parent != engine.currentPath else { return }
        Task { await navigate(to: parent) }
    }

    private func navigateBack() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(engine.currentPath)
        Task {
            await navigate(to: previous, trackHistory: false)
        }
    }

    private func navigateForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(engine.currentPath)
        Task {
            await navigate(to: next, trackHistory: false)
        }
    }

    private func jumpToPath() {
        Task { await navigate(to: pathJumpText) }
    }

    private func navigate(to path: String, trackHistory: Bool = true) async {
        let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        guard !normalizedPath.isEmpty else { return }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: normalizedPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            scanWarning = "Path not found or not a directory: \(normalizedPath)"
            return
        }

        if trackHistory, normalizedPath != engine.currentPath {
            backStack.append(engine.currentPath)
            forwardStack.removeAll()
        }

        engine.setCurrentPath(normalizedPath)
        pathJumpText = normalizedPath
        _ = await engine.loadPathIfNeeded(normalizedPath)
    }

    private func revealInFinder(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func checkPermissions() async {
        isCheckingPermissions = true
        let status = await permissionManager.checkPermission(.fullDiskAccess)
        hasFullDiskAccess = (status == .authorized)
        isCheckingPermissions = false
    }

    private func refreshAfterCleanup() async {
        if let node = selectedNode {
            _ = await engine.loadChildrenIfNeeded(for: node, forceRefresh: true)
        }
        _ = await engine.loadPathIfNeeded(engine.currentPath, forceRefresh: true)
    }

    private func installKeyMonitorIfNeeded() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard selectedTab == .explore, focusedField == nil else { return event }

            let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
            let hasCommand = event.modifierFlags.contains(.command)

            if !hasCommand {
                switch chars {
                case "f":
                    focusOnSelection()
                    return nil
                case "a":
                    toggleSelectionInCart()
                    return nil
                case "g":
                    sendSelectionToGuided()
                    return nil
                default:
                    break
                }

                if event.keyCode == 49 {
                    openPreview()
                    return nil
                }
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        keyMonitor = nil
    }
}

private struct StorageNodeRow: View {
    let node: StorageNode
    let isSelected: Bool
    let inCart: Bool
    let onSelect: () -> Void
    let onDrill: () -> Void
    let onToggleCart: () -> Void
    let onReveal: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                    .foregroundStyle(node.isDirectory ? Color.blue : Color.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(node.name)
                        .font(.subheadline)
                        .lineLimit(1)

                    Text(node.path)
                        .font(.system(.caption2, design: .monospaced))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                RiskPill(level: node.riskLevel)

                Text(node.displayBytes)
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 92, alignment: .trailing)

                Button {
                    onToggleCart()
                } label: {
                    Image(systemName: inCart ? "cart.fill.badge.minus" : "cart.badge.plus")
                }
                .buttonStyle(.plain)

                Button {
                    onReveal()
                } label: {
                    Image(systemName: "arrow.right.circle")
                }
                .buttonStyle(.plain)
            }
            .padding(6)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
            .onTapGesture(count: 2, perform: onDrill)
            .contextMenu {
                Button("Select", action: onSelect)
                if node.isDirectory {
                    Button("Open Folder", action: onDrill)
                }
                Button(inCart ? "Remove from Cart" : "Add to Cart", action: onToggleCart)
                Button("Reveal in Finder", action: onReveal)
            }
        }
    }
}

private struct RiskPill: View {
    let level: StorageRiskLevel

    private var color: Color {
        switch level {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .protected: return .gray
        }
    }

    var body: some View {
        Text(level.rawValue.capitalized)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

private struct StorageOrbitMapView: View {
    let nodes: [StorageNode]
    let selectedNodeID: String?
    let growthByDomain: [StorageDomain: Int64]
    let onSelect: (StorageNode) -> Void
    let onDrill: (StorageNode) -> Void
    let onPreview: (StorageNode) -> Void
    let onToggleCart: (StorageNode) -> Void
    let onGuided: (StorageNode) -> Void

    @State private var hoveredNode: StorageNode?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Orbit Map")
                .font(.headline)
                .padding(.horizontal, 8)

            GeometryReader { geometry in
                let domainSegments = makeDomainSegments(nodes: nodes)
                let nodeSegments = makeNodeSegments(nodes: nodes)

                ZStack {
                    ForEach(domainSegments) { segment in
                        OrbitSlice(
                            startAngle: .degrees(segment.startAngle),
                            endAngle: .degrees(segment.endAngle),
                            innerRatio: 0.14,
                            outerRatio: 0.42
                        )
                        .fill(segment.color.opacity(selectedNodeID == segment.node.id ? 0.95 : 0.65))
                        .overlay(
                            OrbitSlice(
                                startAngle: .degrees(segment.startAngle),
                                endAngle: .degrees(segment.endAngle),
                                innerRatio: 0.14,
                                outerRatio: 0.42
                            )
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .onTapGesture { onSelect(segment.node) }
                        .onTapGesture(count: 2) { onDrill(segment.node) }
                        .onHover { isHovering in
                            hoveredNode = isHovering ? segment.node : nil
                        }
                    }

                    ForEach(nodeSegments) { segment in
                        OrbitSlice(
                            startAngle: .degrees(segment.startAngle),
                            endAngle: .degrees(segment.endAngle),
                            innerRatio: 0.48,
                            outerRatio: 0.92
                        )
                        .fill(segment.color.opacity(selectedNodeID == segment.node.id ? 0.95 : 0.62))
                        .overlay(
                            OrbitSlice(
                                startAngle: .degrees(segment.startAngle),
                                endAngle: .degrees(segment.endAngle),
                                innerRatio: 0.48,
                                outerRatio: 0.92
                            )
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.7)
                        )
                        .onTapGesture { onSelect(segment.node) }
                        .onTapGesture(count: 2) { onDrill(segment.node) }
                        .onHover { isHovering in
                            hoveredNode = isHovering ? segment.node : nil
                        }
                    }

                    Circle()
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .frame(width: min(geometry.size.width, geometry.size.height) * 0.22)

                    Text("Storage\nTerrain")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    if let hoveredNode {
                        orbitHoverCard(for: hoveredNode)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 10)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(8)
    }

    private func makeDomainSegments(nodes: [StorageNode]) -> [OrbitSegment] {
        let grouped = Dictionary(grouping: nodes, by: { $0.domain })
        var totals: [(domain: StorageDomain, bytes: Int64, representative: StorageNode?)] = []
        totals.reserveCapacity(grouped.count)

        for (domain, values) in grouped {
            let bytes = values.reduce(0) { partialResult, value in
                partialResult + value.logicalBytes
            }
            let representative = values.max { lhs, rhs in
                lhs.logicalBytes < rhs.logicalBytes
            }
            totals.append((domain: domain, bytes: bytes, representative: representative))
        }

        totals = totals.filter { entry in
            entry.bytes > 0 && entry.representative != nil
        }
        .sorted { lhs, rhs in
            lhs.bytes > rhs.bytes
        }

        let totalBytes = totals.reduce(0) { $0 + $1.bytes }
        guard totalBytes > 0 else { return [] }

        var cursor: Double = -90
        return totals.compactMap { item in
            guard let node = item.representative else { return nil }
            let span = Double(item.bytes) / Double(totalBytes) * 360
            defer { cursor += span }
            return OrbitSegment(
                id: "domain-\(item.domain.rawValue)",
                node: node,
                startAngle: cursor,
                endAngle: cursor + span,
                color: colorForDomain(item.domain)
            )
        }
    }

    private func makeNodeSegments(nodes: [StorageNode]) -> [OrbitSegment] {
        let topNodes = nodes.sorted { $0.logicalBytes > $1.logicalBytes }.prefix(16)
        let totalBytes = topNodes.reduce(0) { $0 + $1.logicalBytes }
        guard totalBytes > 0 else { return [] }

        var cursor: Double = -90
        return topNodes.map { node in
            let span = Double(node.logicalBytes) / Double(totalBytes) * 360
            defer { cursor += span }
            return OrbitSegment(
                id: node.id,
                node: node,
                startAngle: cursor,
                endAngle: cursor + span,
                color: colorForRisk(node.riskLevel)
            )
        }
    }

    private func colorForRisk(_ risk: StorageRiskLevel) -> Color {
        switch risk {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .protected: return .gray
        }
    }

    private func colorForDomain(_ domain: StorageDomain) -> Color {
        switch domain {
        case .system: return .blue
        case .applications: return .indigo
        case .userFiles: return .mint
        case .developer: return .purple
        case .cloud: return .cyan
        case .other: return .gray
        }
    }

    private func orbitHoverCard(for node: StorageNode) -> some View {
        let growth = growthByDomain[node.domain] ?? 0
        return VStack(alignment: .leading, spacing: 4) {
            Text(node.name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text(node.displayBytes)
                .font(.system(.caption2, design: .monospaced))
            Text("Growth: \(signedBytes(growth))")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Risk: \(node.riskLevel.rawValue.capitalized) • Owner: \(node.ownerApp ?? "Unknown")")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(spacing: 6) {
                Button("Preview") { onPreview(node) }
                    .buttonStyle(.bordered)
                Button("Cart") { onToggleCart(node) }
                    .buttonStyle(.bordered)
                Button("Guided") { onGuided(node) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func signedBytes(_ value: Int64) -> String {
        let magnitude = ByteCountFormatter.string(fromByteCount: abs(value), countStyle: .file)
        return value >= 0 ? "+\(magnitude)" : "-\(magnitude)"
    }
}

private struct OrbitSegment: Identifiable {
    let id: String
    let node: StorageNode
    let startAngle: Double
    let endAngle: Double
    let color: Color
}

private struct OrbitSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRatio: CGFloat
    let outerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = min(rect.width, rect.height) * 0.5
        let inner = maxRadius * innerRatio
        let outer = maxRadius * outerRatio

        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}

struct TreemapLayoutEngine {
    static func sliceAndDice(weights: [Int64], in rect: CGRect) -> [CGRect] {
        guard !weights.isEmpty, rect.isFiniteRect, rect.width > 0, rect.height > 0 else { return [] }
        let sanitized = weights.map { max($0, 0) }
        let total = max(sanitized.reduce(0, +), 1)

        var output: [CGRect] = []
        var remainingRect = rect
        var remainingTotal = CGFloat(total)

        for weight in sanitized where remainingTotal > 0 {
            let fraction = max(0, min(CGFloat(weight) / remainingTotal, 1))
            let sliceRect: CGRect

            if remainingRect.width > remainingRect.height {
                let width = remainingRect.width * fraction
                sliceRect = CGRect(x: remainingRect.minX, y: remainingRect.minY, width: width, height: remainingRect.height)
                remainingRect = CGRect(
                    x: remainingRect.minX + width,
                    y: remainingRect.minY,
                    width: max(0, remainingRect.width - width),
                    height: remainingRect.height
                )
            } else {
                let height = remainingRect.height * fraction
                sliceRect = CGRect(x: remainingRect.minX, y: remainingRect.minY, width: remainingRect.width, height: height)
                remainingRect = CGRect(
                    x: remainingRect.minX,
                    y: remainingRect.minY + height,
                    width: remainingRect.width,
                    height: max(0, remainingRect.height - height)
                )
            }

            if sliceRect.isFiniteRect, sliceRect.width > 0, sliceRect.height > 0 {
                output.append(sliceRect)
            }
            remainingTotal -= CGFloat(weight)
        }

        return output
    }
}

private struct StorageTreemapView: View {
    let nodes: [StorageNode]
    let selectedNodeID: String?
    let onSelect: (StorageNode) -> Void
    let onDrill: (StorageNode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Treemap Grid")
                .font(.headline)
                .padding(.horizontal, 8)

            GeometryReader { geometry in
                let rects = calculateTreemap(nodes: nodes, rect: CGRect(origin: .zero, size: geometry.size))

                ZStack(alignment: .topLeading) {
                    ForEach(rects) { item in
                        TreemapCell(
                            node: item.node,
                            rect: item.rect,
                            isSelected: selectedNodeID == item.node.id,
                            onSelect: { onSelect(item.node) },
                            onDrill: { onDrill(item.node) }
                        )
                    }
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(8)
    }

    private func calculateTreemap(nodes: [StorageNode], rect: CGRect) -> [TreemapRectNode] {
        guard !nodes.isEmpty, rect.isFiniteRect, rect.width > 0, rect.height > 0 else { return [] }
        let sortedNodes = nodes.sorted { $0.logicalBytes > $1.logicalBytes }
        let layoutRects = TreemapLayoutEngine.sliceAndDice(
            weights: sortedNodes.map(\.logicalBytes),
            in: rect
        )
        return zip(sortedNodes, layoutRects).compactMap { node, nodeRect in
            guard nodeRect.isFiniteRect, nodeRect.width > 0, nodeRect.height > 0 else { return nil }
            return TreemapRectNode(node: node, rect: nodeRect)
        }
    }
}

private extension CGRect {
    var isFiniteRect: Bool {
        origin.x.isFinite && origin.y.isFinite && width.isFinite && height.isFinite
    }
}

private struct TreemapRectNode: Identifiable {
    let id = UUID()
    let node: StorageNode
    let rect: CGRect
}

private struct TreemapCell: View {
    let node: StorageNode
    let rect: CGRect
    let isSelected: Bool
    let onSelect: () -> Void
    let onDrill: () -> Void

    private var fillColor: Color {
        switch node.riskLevel {
        case .low: return Color.green.opacity(0.7)
        case .medium: return Color.orange.opacity(0.7)
        case .high: return Color.red.opacity(0.7)
        case .protected: return Color.gray.opacity(0.7)
        }
    }

    var body: some View {
        let safeWidth = rect.width.isFinite ? max(0, rect.width - 2) : 0
        let safeHeight = rect.height.isFinite ? max(0, rect.height - 2) : 0
        let safeMidX = rect.midX.isFinite ? rect.midX : 0
        let safeMidY = rect.midY.isFinite ? rect.midY : 0
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 5)
                .fill(fillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isSelected ? Color.white : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 0.8)
                )

            if rect.width > 70 && rect.height > 40 {
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(node.displayBytes)
                        .font(.caption2)
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(6)
            }
        }
        .frame(width: safeWidth, height: safeHeight)
        .position(x: safeMidX, y: safeMidY)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onTapGesture(count: 2, perform: onDrill)
    }
}

#Preview {
    DiskAnalysisView()
        .frame(width: 1180, height: 760)
}
