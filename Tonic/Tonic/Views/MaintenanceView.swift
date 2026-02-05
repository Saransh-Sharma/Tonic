//
//  MaintenanceView.swift
//  Tonic
//
//  Unified Maintenance view combining Smart Care and Deep Clean
//

import SwiftUI

// MARK: - Maintenance Tab

enum MaintenanceTab: String, CaseIterable, Identifiable {
    case scan = "Scan"
    case clean = "Clean"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .scan: return "sparkles"
        case .clean: return "trash"
        }
    }
}

// MARK: - Maintenance View

struct MaintenanceView: View {
    @State private var selectedTab: MaintenanceTab = .scan

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Group {
                switch selectedTab {
                case .scan:
                    SmartCareView()
                case .clean:
                    CleanTabView()
                }
            }
        }
        .background(DesignTokens.Colors.background)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Label("Maintenance", systemImage: "wrench.and.screwdriver")
                .font(DesignTokens.Typography.bodyEmphasized)

            Spacer()

            Picker("Tab", selection: $selectedTab) {
                ForEach(MaintenanceTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.backgroundSecondary)
    }
}

// MARK: - Clean Tab View

struct CleanTabView: View {
    @State private var deepCleanEngine = DeepCleanEngine.shared
    @State private var collectorBin = CollectorBin.shared
    @State private var scanResults: [DeepCleanResult] = []
    @State private var selectedCategories: Set<DeepCleanCategory> = []
    @State private var expandedCategories: Set<DeepCleanCategory> = []
    @State private var isScanning = false
    @State private var isCleaning = false
    @State private var showConfirmation = false

    private var totalReclaimSize: Int64 {
        scanResults
            .filter { selectedCategories.contains($0.category) }
            .reduce(0) { $0 + $1.totalSize }
    }

    private var formattedTotalReclaim: String {
        ByteCountFormatter.string(fromByteCount: totalReclaimSize, countStyle: .file)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isScanning {
                scanningView
            } else if scanResults.isEmpty {
                initialView
            } else {
                resultsView
            }

            if !scanResults.isEmpty && !isScanning {
                totalReclaimFooter
            }
        }
        .alert("Confirm Cleanup", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clean", role: .destructive) {
                Task { await performClean() }
            }
        } message: {
            Text("This will permanently delete \(formattedTotalReclaim) of data from \(selectedCategories.count) categories. Items will be moved to the Collector Bin first.")
        }
    }

    // MARK: - Initial View

    private var initialView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()

            Image(systemName: "trash")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [DesignTokens.Colors.warning, DesignTokens.Colors.error],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: DesignTokens.Spacing.xxs) {
                Text("Deep Clean")
                    .font(DesignTokens.Typography.h2)

                Text("Scan for and remove unnecessary files to free up disk space")
                    .font(DesignTokens.Typography.subhead)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Categories")
                    .font(DesignTokens.Typography.captionEmphasized)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignTokens.Spacing.xxs) {
                    ForEach(DeepCleanCategory.allCases) { category in
                        HStack(spacing: DesignTokens.Spacing.xxs) {
                            Image(systemName: category.icon)
                                .foregroundColor(DesignTokens.Colors.accent)
                                .frame(width: 16)
                            Text(category.rawValue)
                                .font(DesignTokens.Typography.caption)
                            Spacer()
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.large)

            Button {
                Task { await scanCategories() }
            } label: {
                Label("Scan for Junk", systemImage: "magnifyingglass")
                    .font(DesignTokens.Typography.bodyEmphasized)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding(DesignTokens.Spacing.lg)
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            VStack(spacing: DesignTokens.Spacing.xxs) {
                Text("Scanning...")
                    .font(DesignTokens.Typography.bodyEmphasized)

                if let category = deepCleanEngine.currentScanningCategory {
                    Text(category)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Results View

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.sm) {
                HStack {
                    Button("Select All") {
                        selectedCategories = Set(scanResults.map { $0.category })
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Deselect All") {
                        selectedCategories.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()

                    Button {
                        Task { await scanCategories() }
                    } label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)

                PreferenceList {
                    ForEach(groupedResults, id: \.key) { group, results in
                        PreferenceSection(header: group) {
                            ForEach(results) { result in
                                cleanCategoryRow(result)
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
    }

    private var groupedResults: [(key: String, value: [DeepCleanResult])] {
        let systemCategories: [DeepCleanCategory] = [.systemCache, .userCache, .logFiles, .tempFiles]
        let appCategories: [DeepCleanCategory] = [.browserCache, .downloads, .trash]
        let devCategories: [DeepCleanCategory] = [.development, .docker, .xcode]

        var groups: [(key: String, value: [DeepCleanResult])] = []

        let system = scanResults.filter { systemCategories.contains($0.category) }
        if !system.isEmpty { groups.append(("System", system)) }

        let apps = scanResults.filter { appCategories.contains($0.category) }
        if !apps.isEmpty { groups.append(("Applications", apps)) }

        let dev = scanResults.filter { devCategories.contains($0.category) }
        if !dev.isEmpty { groups.append(("Development", dev)) }

        return groups
    }

    @ViewBuilder
    private func cleanCategoryRow(_ result: DeepCleanResult) -> some View {
        let isSelected = selectedCategories.contains(result.category)
        let isExpanded = expandedCategories.contains(result.category)

        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Button {
                    toggleSelection(result.category)
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.textSecondary)
                }
                .buttonStyle(.plain)

                Image(systemName: result.category.icon)
                    .foregroundColor(DesignTokens.Colors.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.category.rawValue)
                        .font(DesignTokens.Typography.body)

                    Text(result.category.description)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(result.formattedSize)
                        .font(DesignTokens.Typography.monoSubhead)
                        .foregroundColor(result.totalSize > 0 ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textTertiary)

                    Text("\(result.itemCount) items")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }

                if !result.paths.isEmpty {
                    Button {
                        toggleExpansion(result.category)
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, DesignTokens.Spacing.sm)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .background(isSelected ? DesignTokens.Colors.accent.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture { toggleSelection(result.category) }

            if isExpanded {
                expandedFileList(result)
            }

            Divider()
                .padding(.leading, DesignTokens.Spacing.md + 24 + DesignTokens.Spacing.sm)
        }
    }

    private func expandedFileList(_ result: DeepCleanResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(result.paths.prefix(10).enumerated()), id: \.offset) { _, path in
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Image(systemName: "doc")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Colors.textTertiary)

                    Text(shortenPath(path))
                        .font(DesignTokens.Typography.monoCaption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()
                }
                .padding(.vertical, DesignTokens.Spacing.xxxs)
                .padding(.horizontal, DesignTokens.Spacing.xl)
            }

            if result.paths.count > 10 {
                Text("+ \(result.paths.count - 10) more files")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .padding(.horizontal, DesignTokens.Spacing.xl)
                    .padding(.vertical, DesignTokens.Spacing.xxxs)
            }
        }
        .padding(.bottom, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.backgroundTertiary.opacity(0.5))
    }

    private func shortenPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    // MARK: - Total Reclaim Footer

    private var totalReclaimFooter: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Total to Clean")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                Text(formattedTotalReclaim)
                    .font(DesignTokens.Typography.h3)
                    .monospacedDigit()
            }

            Spacer()

            Button {
                showConfirmation = true
            } label: {
                Label("Clean Selected", systemImage: "trash")
                    .font(DesignTokens.Typography.bodyEmphasized)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedCategories.isEmpty || isCleaning)
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.backgroundSecondary)
    }

    // MARK: - Actions

    private func toggleSelection(_ category: DeepCleanCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    private func toggleExpansion(_ category: DeepCleanCategory) {
        withAnimation(DesignTokens.Animation.fast) {
            if expandedCategories.contains(category) {
                expandedCategories.remove(category)
            } else {
                expandedCategories.insert(category)
            }
        }
    }

    private func scanCategories() async {
        isScanning = true
        scanResults = []
        selectedCategories = []
        expandedCategories = []

        scanResults = await deepCleanEngine.scanAllCategories()
        selectedCategories = Set(scanResults.filter { $0.totalSize > 0 }.map { $0.category })

        isScanning = false
    }

    private func performClean() async {
        isCleaning = true

        let pathsToClean = scanResults
            .filter { selectedCategories.contains($0.category) }
            .flatMap { $0.paths }

        let _ = await collectorBin.addToBin(atPaths: pathsToClean)
        let categoriesToClean = Array(selectedCategories)
        let _ = await deepCleanEngine.cleanCategories(categoriesToClean)

        await scanCategories()
        isCleaning = false
    }
}

// MARK: - Preview

#Preview("Maintenance View") {
    MaintenanceView()
        .frame(width: 800, height: 600)
}

#Preview("Clean Tab") {
    CleanTabView()
        .frame(width: 700, height: 500)
}
