//
//  DiskAnalysisView.swift
//  Tonic
//
//  Disk analysis view with segmented control for List/Treemap/Hybrid views
//  Redesigned to use native components and bar chart visualizations
//

import SwiftUI

// MARK: - View Mode

/// Available view modes for disk analysis
enum DiskViewMode: String, CaseIterable, Identifiable {
    case list = "List"
    case treemap = "Treemap"
    case hybrid = "Hybrid"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .treemap: return "square.grid.2x2"
        case .hybrid: return "square.split.1x2"
        }
    }
}

// MARK: - DiskAnalysisView

struct DiskAnalysisView: View {
    @State private var scanner = DiskScanner()
    @State private var currentPath: String = FileManager.default.homeDirectoryForCurrentUser.path
    @State private var scanResult: DiskScanResult?
    @State private var overviewEntries: [DirectoryOverviewEntry] = []
    @State private var isScanning = false
    @State private var errorMessage: String?
    @State private var viewMode: DiskViewMode = .list
    @State private var selectedPath: String?
    @State private var selectedPaths: Set<String> = []
    @State private var scanProgress: DiskScanProgress?
    @State private var navigationPath: [String] = []
    @State private var permissionManager = PermissionManager.shared
    @State private var hasFullDiskAccess: Bool = false
    @State private var isCheckingPermissions: Bool = false

    private let homePath = FileManager.default.homeDirectoryForCurrentUser.path

    var body: some View {
        VStack(spacing: 0) {
            // Header with path and controls
            header

            Divider()

            // Content area
            if isCheckingPermissions {
                permissionCheckView
            } else if !hasFullDiskAccess {
                permissionRequiredView
            } else if isScanning {
                progressView
            } else if let error = errorMessage {
                errorView(error)
            } else if scanResult != nil {
                resultsView
            } else {
                initialView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Colors.background)
        .task {
            await checkPermissions()
        }
    }

    // MARK: - Permission Check View

    private var permissionCheckView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Checking permissions...")
                .font(DesignTokens.Typography.subhead)
                .foregroundColor(DesignTokens.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Permission Required View

    private var permissionRequiredView: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.md) {
                Spacer()
                    .frame(height: DesignTokens.Spacing.xl)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 56))
                    .foregroundColor(DesignTokens.Colors.warning)

                VStack(spacing: DesignTokens.Spacing.xs) {
                    Text("Full Disk Access Required")
                        .font(DesignTokens.Typography.h3)
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    Text("Disk Analysis needs Full Disk Access to scan all folders and files on your Mac")
                        .font(DesignTokens.Typography.subhead)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DesignTokens.Spacing.xl)

                // Benefits section
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    permissionBenefit(icon: "checkmark.circle.fill", text: "Scan your entire home directory")
                    permissionBenefit(icon: "checkmark.circle.fill", text: "Access system folders and applications")
                    permissionBenefit(icon: "checkmark.circle.fill", text: "Find large files anywhere on your disk")
                    permissionBenefit(icon: "checkmark.circle.fill", text: "No annoying permission pop-ups during scan")
                }
                .padding(DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.large)

                // Step-by-step instructions
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("How to grant Full Disk Access:")
                        .font(DesignTokens.Typography.subheadEmphasized)
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    permissionStep(number: 1, text: "Click the button below to open System Settings")
                    permissionStep(number: 2, text: "Click the lock icon and enter your Mac password")
                    permissionStep(number: 3, text: "Find \"Tonic\" in the applications list")
                    permissionStep(number: 4, text: "Toggle the switch next to Tonic to enable it")
                    permissionStep(number: 5, text: "Quit System Settings and click \"I've Granted Access\" below")
                }
                .padding(DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.warning.opacity(0.1))
                .cornerRadius(DesignTokens.CornerRadius.large)

                // Action buttons
                VStack(spacing: DesignTokens.Spacing.xs) {
                    Button {
                        grantFullDiskAccess()
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.xxs) {
                            Image(systemName: "gear")
                            Text("Open System Settings")
                        }
                        .font(DesignTokens.Typography.bodyEmphasized)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background(DesignTokens.Colors.accent)
                        .cornerRadius(DesignTokens.CornerRadius.medium)
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task {
                            await checkPermissions()
                        }
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.xxxs) {
                            Image(systemName: "checkmark.circle")
                            Text("I've Granted Access")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        Task {
                            await checkPermissions()
                        }
                    } label: {
                        Text("Re-check Permissions")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .underline()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DesignTokens.Spacing.md)

                Spacer()
                    .frame(height: DesignTokens.Spacing.md)
            }
            .padding()
        }
    }

    private func permissionBenefit(icon: String, text: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: icon)
                .foregroundColor(DesignTokens.Colors.success)
            Text(text)
                .font(DesignTokens.Typography.subhead)
                .foregroundColor(DesignTokens.Colors.textPrimary)
        }
    }

    private func permissionStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.xs) {
            Text("\(number)")
                .font(DesignTokens.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(DesignTokens.Colors.warning))

            Text(text)
                .font(DesignTokens.Typography.subhead)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            // Navigation buttons
            HStack(spacing: DesignTokens.Spacing.xxxs) {
                Button {
                    navigateBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(navigationPath.isEmpty)

                Button {
                    navigateUp()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(currentPath == homePath)

                Button {
                    Task { await refreshScan() }
                } label: {
                    Image(systemName: isScanning ? "stop.circle.fill" : "arrow.clockwise")
                }
                .disabled(isScanning || !hasFullDiskAccess)
            }
            .buttonStyle(.borderless)

            // Current path
            Text(displayPath)
                .font(DesignTokens.Typography.monoSubhead)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .lineLimit(1)

            Spacer()

            // View mode segmented control
            Picker("View Mode", selection: $viewMode) {
                ForEach(DiskViewMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isScanning || scanResult == nil)
            .frame(width: 220)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(DesignTokens.Colors.backgroundSecondary)
    }

    // MARK: - Progress View

    private var progressView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            if let progress = scanProgress {
                VStack(spacing: DesignTokens.Spacing.xxs) {
                    Text("Scanning...")
                        .font(DesignTokens.Typography.bodyEmphasized)
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    Text(progress.currentPath)
                        .font(DesignTokens.Typography.monoCaption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: 500)

                    HStack(spacing: DesignTokens.Spacing.md) {
                        Label("\(progress.formattedFilesScanned) items", systemImage: "doc")
                        Label("\(progress.formattedBytesScanned)", systemImage: "externaldrive")
                    }
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                }
            }

            // Cancel button
            Button("Cancel Scan") {
                scanner.cancelScan()
                isScanning = false
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Cancel scan")
            .accessibilityHint("Stops the disk analysis scan")

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(DesignTokens.Colors.warning)

            Text("Scan Error")
                .font(DesignTokens.Typography.bodyEmphasized)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Text(error)
                .font(DesignTokens.Typography.subhead)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)

            // Check if it's a permission error
            if error.contains("Full Disk Access") || error.contains("permission") || error.contains("Access denied") {
                Button("Grant Permissions") {
                    grantFullDiskAccess()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Grant full disk access")
                .accessibilityHint("Opens System Settings to enable full disk access")
            }

            Button("Try Again") {
                Task { await refreshScan() }
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Try again")
            .accessibilityHint("Retries the disk analysis scan")

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results View

    private var resultsView: some View {
        VStack(spacing: 0) {
            // Summary bar
            if let result = scanResult {
                summaryBar(result)
            }

            Divider()

            // Content based on view mode
            switch viewMode {
            case .list:
                listView
            case .treemap:
                treemapView
            case .hybrid:
                hybridView
            }
        }
    }

    private func summaryBar(_ result: DiskScanResult) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Label(result.formattedTotalSize, systemImage: "externaldrive.fill")
                .font(DesignTokens.Typography.subhead)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Label("\(result.formattedFileCount) items", systemImage: "doc.fill")
                .font(DesignTokens.Typography.subhead)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            Spacer()

            Text(String(format: "%.1fs", result.scanDuration))
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .background(DesignTokens.Colors.backgroundSecondary)
    }

    // MARK: - List View (Bar Chart Rows)

    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if let result = scanResult {
                    ForEach(result.entries) { entry in
                        BarChartRow(
                            entry: entry,
                            maxSize: result.entries.first?.size ?? entry.size,
                            totalSize: result.totalSize,
                            isSelected: selectedPath == entry.path,
                            onTap: {
                                selectedPath = entry.path
                                if entry.isDir {
                                    navigateTo(entry.path)
                                }
                            },
                            onReveal: {
                                revealInFinder(entry.path)
                            }
                        )
                    }

                    // Large files section
                    if !result.largeFiles.isEmpty {
                        Section {
                            ForEach(result.largeFiles) { file in
                                LargeFileBarRow(
                                    file: file,
                                    maxSize: result.largeFiles.first?.size ?? file.size,
                                    isSelected: selectedPath == file.path,
                                    onTap: {
                                        selectedPath = file.path
                                    },
                                    onReveal: {
                                        revealInFinder(file.path)
                                    }
                                )
                            }
                        } header: {
                            HStack {
                                Text("Large Files")
                                    .font(DesignTokens.Typography.captionEmphasized)
                                    .foregroundColor(DesignTokens.Colors.textSecondary)
                                Spacer()
                            }
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, DesignTokens.Spacing.xxs)
                            .background(DesignTokens.Colors.backgroundSecondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Treemap View

    private var treemapView: some View {
        GeometryReader { geometry in
            if let result = scanResult {
                TreemapView(
                    entries: result.entries,
                    size: geometry.size,
                    selectedPath: $selectedPath,
                    onNavigate: { path in
                        navigateTo(path)
                    },
                    onReveal: { path in
                        revealInFinder(path)
                    }
                )
            }
        }
        .padding(DesignTokens.Spacing.sm)
    }

    // MARK: - Hybrid View (Bar + Treemap)

    private var hybridView: some View {
        HSplitView {
            // Left: Bar chart list
            ScrollView {
                LazyVStack(spacing: 0) {
                    if let result = scanResult {
                        ForEach(result.entries.prefix(20)) { entry in
                            BarChartRow(
                                entry: entry,
                                maxSize: result.entries.first?.size ?? entry.size,
                                totalSize: result.totalSize,
                                isSelected: selectedPath == entry.path,
                                onTap: {
                                    selectedPath = entry.path
                                    if entry.isDir {
                                        navigateTo(entry.path)
                                    }
                                },
                                onReveal: {
                                    revealInFinder(entry.path)
                                }
                            )
                        }
                    }
                }
            }
            .frame(minWidth: 300)

            // Right: Treemap
            GeometryReader { geometry in
                if let result = scanResult {
                    TreemapView(
                        entries: result.entries,
                        size: geometry.size,
                        selectedPath: $selectedPath,
                        onNavigate: { path in
                            navigateTo(path)
                        },
                        onReveal: { path in
                            revealInFinder(path)
                        }
                    )
                }
            }
            .frame(minWidth: 300)
        }
    }

    // MARK: - Initial View

    private var initialView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Spacer()

            Image(systemName: "externaldrive.fill")
                .font(.system(size: 48))
                .foregroundColor(DesignTokens.Colors.accent)

            Text("Disk Analysis")
                .font(DesignTokens.Typography.h3)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Text("Analyze disk usage and find large files")
                .font(DesignTokens.Typography.subhead)
                .foregroundColor(DesignTokens.Colors.textSecondary)

            if !overviewEntries.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Quick Scan")
                        .font(DesignTokens.Typography.subheadEmphasized)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .padding(.horizontal, DesignTokens.Spacing.sm)

                    ForEach(overviewEntries) { entry in
                        OverviewEntryRow(entry: entry) {
                            navigateTo(entry.path)
                        }
                    }
                }
                .padding(DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.large)
            }

            Button("Scan Current Folder") {
                Task { await scanCurrentPath() }
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Navigation

    private var displayPath: String {
        if currentPath == homePath {
            return "~"
        }
        return currentPath.replacingOccurrences(of: homePath, with: "~")
    }

    private func navigateBack() {
        guard !navigationPath.isEmpty else { return }
        currentPath = navigationPath.removeLast()
        Task { await scanCurrentPath() }
    }

    private func navigateUp() {
        let parent = (currentPath as NSString).deletingLastPathComponent
        guard !parent.isEmpty, parent != currentPath else { return }
        navigateTo(parent)
    }

    private func navigateTo(_ path: String) {
        navigationPath.append(currentPath)
        currentPath = path
        Task { await scanCurrentPath() }
    }

    private func revealInFinder(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    // MARK: - Permissions

    private func checkPermissions() async {
        isCheckingPermissions = true
        let status = await permissionManager.checkPermission(.fullDiskAccess)
        hasFullDiskAccess = (status == .authorized)
        isCheckingPermissions = false
    }

    private func grantFullDiskAccess() {
        _ = permissionManager.requestFullDiskAccess()
    }

    // MARK: - Scanning

    private func scanCurrentPath() async {
        guard hasFullDiskAccess else {
            errorMessage = "Full Disk Access is required for disk scanning"
            return
        }

        isScanning = true
        errorMessage = nil
        scanResult = nil
        selectedPath = nil

        do {
            let result = try await scanner.scanPath(currentPath) { progress in
                scanProgress = progress
            }
            scanResult = result
            let detail = "Scanned \(currentPath) · \(result.formattedFileCount) items · Total \(result.formattedTotalSize) · Duration \(formatDuration(result.scanDuration))"
            let event = ActivityEvent(
                category: .disk,
                title: "Disk analysis completed",
                detail: detail,
                impact: .low
            )
            ActivityLogStore.shared.record(event)
        } catch {
            errorMessage = error.localizedDescription
            let event = ActivityEvent(
                category: .disk,
                title: "Disk analysis failed",
                detail: "Error: \(error.localizedDescription)",
                impact: .medium
            )
            ActivityLogStore.shared.record(event)
        }

        isScanning = false
    }

    private func refreshScan() async {
        // Re-check permissions before scanning
        await checkPermissions()

        if hasFullDiskAccess {
            await scanCurrentPath()
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        String(format: "%.1fs", seconds)
    }
}

// MARK: - Bar Chart Row

struct BarChartRow: View {
    let entry: DirEntry
    let maxSize: Int64
    let totalSize: Int64
    let isSelected: Bool
    let onTap: () -> Void
    let onReveal: () -> Void

    @State private var isHovered = false

    private var percentage: Double {
        guard totalSize > 0 else { return 0 }
        return Double(entry.size) / Double(totalSize) * 100
    }

    private var barWidth: CGFloat {
        guard maxSize > 0 else { return 0 }
        return CGFloat(entry.size) / CGFloat(maxSize)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                // Icon
                Image(systemName: entry.isDir ? "folder.fill" : "doc.fill")
                    .font(.system(size: 16))
                    .foregroundColor(entry.isDir ? .blue : DesignTokens.Colors.textTertiary)
                    .frame(width: 20)

                // Name
                Text(entry.name)
                    .font(DesignTokens.Typography.subhead)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)
                    .frame(minWidth: 150, alignment: .leading)

                // Bar chart
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        Rectangle()
                            .fill(DesignTokens.Colors.separator.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)

                        // Fill
                        Rectangle()
                            .fill(barColor)
                            .frame(width: geometry.size.width * barWidth, height: 8)
                            .cornerRadius(4)
                            .animation(DesignTokens.Animation.fast, value: barWidth)
                    }
                    .frame(height: 8)
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 8)

                // Size
                Text(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))
                    .font(DesignTokens.Typography.monoCaption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 70, alignment: .trailing)

                // Percentage
                Text(String(format: "%.1f%%", percentage))
                    .font(DesignTokens.Typography.monoCaption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .frame(width: 50, alignment: .trailing)

                // Reveal button
                Button {
                    onReveal()
                } label: {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 14))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xxs)
            .background(rowBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("Reveal in Finder") {
                onReveal()
            }
            if entry.isDir {
                Button("Open Folder") {
                    onTap()
                }
            }
        }
    }

    private var rowBackground: some View {
        Group {
            if isSelected {
                DesignTokens.Colors.selectedContentBackground
            } else if isHovered {
                DesignTokens.Colors.unemphasizedSelectedContentBackground.opacity(0.5)
            } else {
                Color.clear
            }
        }
    }

    private var barColor: Color {
        if percentage >= 50 {
            return DesignTokens.Colors.warning
        } else if percentage >= 25 {
            return DesignTokens.Colors.info
        } else {
            return DesignTokens.Colors.accent
        }
    }
}

// MARK: - Large File Bar Row

struct LargeFileBarRow: View {
    let file: LargeFile
    let maxSize: Int64
    let isSelected: Bool
    let onTap: () -> Void
    let onReveal: () -> Void

    @State private var isHovered = false

    private var barWidth: CGFloat {
        guard maxSize > 0 else { return 0 }
        return CGFloat(file.size) / CGFloat(maxSize)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                // Icon
                Image(systemName: "doc.fill")
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.Colors.warning)
                    .frame(width: 20)

                // Name and path
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(DesignTokens.Typography.subhead)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)

                    Text((file.path as NSString).deletingLastPathComponent)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .lineLimit(1)
                }
                .frame(minWidth: 150, alignment: .leading)

                Spacer()

                // Bar chart
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(DesignTokens.Colors.separator.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)

                        Rectangle()
                            .fill(DesignTokens.Colors.warning)
                            .frame(width: geometry.size.width * barWidth, height: 8)
                            .cornerRadius(4)
                    }
                    .frame(height: 8)
                }
                .frame(width: 100, height: 8)

                // Size
                Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                    .font(DesignTokens.Typography.monoCaption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 70, alignment: .trailing)

                // Reveal button
                Button {
                    onReveal()
                } label: {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 14))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xxs)
            .background(rowBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("Reveal in Finder") {
                onReveal()
            }
        }
    }

    private var rowBackground: some View {
        Group {
            if isSelected {
                DesignTokens.Colors.selectedContentBackground
            } else if isHovered {
                DesignTokens.Colors.unemphasizedSelectedContentBackground.opacity(0.5)
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - Treemap View

struct TreemapView: View {
    let entries: [DirEntry]
    let size: CGSize
    @Binding var selectedPath: String?
    let onNavigate: (String) -> Void
    let onReveal: (String) -> Void

    var body: some View {
        let rects = calculateTreemap(entries: entries, rect: CGRect(origin: .zero, size: size))

        ZStack {
            ForEach(Array(zip(entries.indices, rects)), id: \.0) { index, rect in
                let entry = entries[index]
                TreemapCell(
                    entry: entry,
                    rect: rect,
                    isSelected: selectedPath == entry.path,
                    onTap: {
                        selectedPath = entry.path
                        if entry.isDir {
                            onNavigate(entry.path)
                        }
                    },
                    onReveal: {
                        onReveal(entry.path)
                    }
                )
            }
        }
        .frame(width: size.width, height: size.height)
    }

    /// Calculate treemap rectangles using squarified algorithm
    private func calculateTreemap(entries: [DirEntry], rect: CGRect) -> [CGRect] {
        guard !entries.isEmpty else { return [] }

        let totalSize = entries.reduce(0) { $0 + $1.size }
        guard totalSize > 0 else { return entries.map { _ in CGRect.zero } }

        var rects: [CGRect] = []
        var remainingEntries = entries.sorted { $0.size > $1.size }
        var remainingRect = rect

        while !remainingEntries.isEmpty {
            let (row, rest, rowRect, newRemainingRect) = squarify(
                entries: remainingEntries,
                rect: remainingRect,
                totalSize: totalSize
            )

            // Layout row
            let rowRects = layoutRow(entries: row, rect: rowRect, totalSize: totalSize)
            rects.append(contentsOf: rowRects)

            remainingEntries = rest
            remainingRect = newRemainingRect
        }

        return rects
    }

    /// Squarify algorithm step
    private func squarify(
        entries: [DirEntry],
        rect: CGRect,
        totalSize: Int64
    ) -> (row: [DirEntry], rest: [DirEntry], rowRect: CGRect, remainingRect: CGRect) {
        guard !entries.isEmpty else {
            return ([], [], .zero, rect)
        }

        var row: [DirEntry] = []
        var rest = entries
        var bestAspectRatio: CGFloat = .infinity

        let isHorizontal = rect.width > rect.height

        while !rest.isEmpty {
            let candidate = rest[0]
            let testRow = row + [candidate]

            let rowSize = testRow.reduce(0) { $0 + $1.size }
            let rowFraction = CGFloat(rowSize) / CGFloat(totalSize)

            let rowDimension: CGFloat
            let crossDimension: CGFloat

            if isHorizontal {
                rowDimension = rect.width * rowFraction
                crossDimension = rect.height
            } else {
                rowDimension = rect.height * rowFraction
                crossDimension = rect.width
            }

            // Calculate worst aspect ratio in row
            var worstRatio: CGFloat = 0
            for entry in testRow {
                let entryFraction = CGFloat(entry.size) / CGFloat(rowSize)
                let entryDimension = crossDimension * entryFraction
                let ratio = max(rowDimension / entryDimension, entryDimension / rowDimension)
                worstRatio = max(worstRatio, ratio)
            }

            if worstRatio <= bestAspectRatio || row.isEmpty {
                row = testRow
                rest.removeFirst()
                bestAspectRatio = worstRatio
            } else {
                break
            }
        }

        // Calculate row rect and remaining rect
        let rowSize = row.reduce(0) { $0 + $1.size }
        let rowFraction = CGFloat(rowSize) / CGFloat(totalSize)

        let rowRect: CGRect
        let remainingRect: CGRect

        if isHorizontal {
            let rowWidth = rect.width * rowFraction
            rowRect = CGRect(x: rect.minX, y: rect.minY, width: rowWidth, height: rect.height)
            remainingRect = CGRect(x: rect.minX + rowWidth, y: rect.minY, width: rect.width - rowWidth, height: rect.height)
        } else {
            let rowHeight = rect.height * rowFraction
            rowRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rowHeight)
            remainingRect = CGRect(x: rect.minX, y: rect.minY + rowHeight, width: rect.width, height: rect.height - rowHeight)
        }

        return (row, rest, rowRect, remainingRect)
    }

    /// Layout entries in a row
    private func layoutRow(entries: [DirEntry], rect: CGRect, totalSize: Int64) -> [CGRect] {
        guard !entries.isEmpty else { return [] }

        let rowSize = entries.reduce(0) { $0 + $1.size }
        guard rowSize > 0 else { return entries.map { _ in CGRect.zero } }

        var rects: [CGRect] = []
        var offset: CGFloat = 0

        let isHorizontal = rect.width <= rect.height

        for entry in entries {
            let entryFraction = CGFloat(entry.size) / CGFloat(rowSize)

            let entryRect: CGRect
            if isHorizontal {
                let width = rect.width * entryFraction
                entryRect = CGRect(x: rect.minX + offset, y: rect.minY, width: width, height: rect.height)
                offset += width
            } else {
                let height = rect.height * entryFraction
                entryRect = CGRect(x: rect.minX, y: rect.minY + offset, width: rect.width, height: height)
                offset += height
            }

            rects.append(entryRect)
        }

        return rects
    }
}

// MARK: - Treemap Cell

struct TreemapCell: View {
    let entry: DirEntry
    let rect: CGRect
    let isSelected: Bool
    let onTap: () -> Void
    let onReveal: () -> Void

    @State private var isHovered = false

    private var cellColor: Color {
        if entry.isDir {
            return Color.blue.opacity(0.6)
        } else {
            return DesignTokens.Colors.warning.opacity(0.6)
        }
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small)
                    .fill(cellColor)

                // Border
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small)
                    .stroke(
                        isSelected ? DesignTokens.Colors.accent : Color.white.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )

                // Label (only if cell is large enough)
                if rect.width > 60 && rect.height > 40 {
                    VStack(spacing: 2) {
                        Image(systemName: entry.isDir ? "folder.fill" : "doc.fill")
                            .font(.system(size: min(16, rect.height * 0.3)))
                            .foregroundColor(.white)

                        Text(entry.name)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 4)

                        if rect.height > 60 {
                            Text(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))
                                .font(DesignTokens.Typography.monoCaption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            }
            .frame(width: max(0, rect.width - 2), height: max(0, rect.height - 2))
            .position(x: rect.midX, y: rect.midY)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(DesignTokens.Animation.fast, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Reveal in Finder") {
                onReveal()
            }
            if entry.isDir {
                Button("Open Folder") {
                    onTap()
                }
            }
        }
        .help("\(entry.name)\n\(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))")
    }
}

// MARK: - Overview Entry Row

struct OverviewEntryRow: View {
    let entry: DirectoryOverviewEntry
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                    .frame(width: 20)

                Text(entry.name)
                    .font(DesignTokens.Typography.subhead)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Spacer()

                Text(entry.displaySize)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(entry.isScanned ? DesignTokens.Colors.textSecondary : DesignTokens.Colors.warning)
            }
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, DesignTokens.Spacing.xxxs)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DiskAnalysisView()
        .frame(width: 900, height: 600)
}
