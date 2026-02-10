//
//  AppManagerView.swift
//  Tonic
//
//  Redesigned App Manager with immersive glass design system.
//  Replaces the legacy AppInventoryView with modern world-colored canvas,
//  glass surfaces, spring animations, and staggered reveals.
//

import SwiftUI
import AppKit

struct AppManagerView: View {
    @StateObject private var inventory = AppInventoryService.shared
    @State private var selection: Set<UUID> = []
    @State private var showingDetail = false
    @State private var showingUninstallFlow = false
    @State private var currentAppForDetail: AppMetadata?
    @State private var cachedTopIcons: [NSImage] = []

    var body: some View {
        TonicThemeProvider(world: .applicationsBlue) {
            ZStack {
                WorldCanvasBackground()

                VStack(spacing: 0) {
                    // Page header
                    PageHeader(
                        title: "App Manager",
                        subtitle: headerSubtitle,
                        searchText: isZeroState ? nil : $inventory.searchText,
                        trailing: isZeroState ? nil : AnyView(headerTrailing)
                    )
                    .staggeredReveal(index: 0)
                    .padding(.horizontal, TonicSpaceToken.three)
                    .padding(.top, TonicSpaceToken.two)

                    // Main scrollable content
                    ScrollView {
                        VStack(spacing: TonicSpaceToken.three) {
                            // Hero module
                            AppHeroModule(
                                state: heroState,
                                topAppIcons: cachedTopIcons
                            )
                            .staggeredReveal(index: 0)

                            if !isZeroState {
                                // Category filter chips
                                categoryFilterChips
                                    .staggeredReveal(index: 1)

                                // Summary tiles row
                                summaryTilesRow
                                    .staggeredReveal(index: 2)

                                // Quick filter chips (only for non-login-items tabs)
                                if inventory.selectedTab != .loginItems {
                                    quickFilterChips
                                        .staggeredReveal(index: 3)
                                }

                                // App list section
                                appListSection
                            }
                        }
                        .padding(.top, TonicSpaceToken.two)
                        .padding(.horizontal, TonicSpaceToken.three)
                        .padding(.bottom, !selection.isEmpty ? 100 : TonicSpaceToken.four)
                    }

                    // Scan dock (before first scan)
                    if !inventory.hasScannedThisSession && inventory.apps.isEmpty && !inventory.isLoading && selection.isEmpty {
                        HStack {
                            Text("Scan to discover installed apps and available updates.")
                                .font(TonicTypeToken.caption)
                                .foregroundStyle(TonicTextToken.secondary)

                            Spacer()

                            PrimaryActionButton(title: "Scan for Apps", icon: "magnifyingglass") {
                                Task { await inventory.scanApps() }
                            }
                        }
                        .padding(.horizontal, TonicSpaceToken.three)
                        .padding(.vertical, TonicSpaceToken.two)
                        .glassSurface(radius: TonicRadiusToken.container, variant: .raised)
                        .padding(.horizontal, TonicSpaceToken.three)
                        .padding(.bottom, TonicSpaceToken.two)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 20)),
                            removal: .opacity.combined(with: .offset(y: 20))
                        ))
                    }

                    // Command dock (when items selected)
                    if !selection.isEmpty {
                        AppCommandDock(
                            selectedCount: selection.count,
                            selectedSize: formatBytes(selectedSize),
                            onUninstall: { showingUninstallFlow = true },
                            onReveal: { revealSelectedInFinder() }
                        )
                        .padding(.horizontal, TonicSpaceToken.three)
                        .padding(.bottom, TonicSpaceToken.two)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 20)),
                            removal: .opacity.combined(with: .offset(y: 20))
                        ))
                    }
                }
            }
        }
        .sheet(isPresented: $showingDetail) {
            if let app = currentAppForDetail {
                AppDetailSheet(
                    app: app,
                    onUninstall: {
                        selection = [app.id]
                        showingUninstallFlow = true
                    }
                )
            }
        }
        .sheet(isPresented: $showingUninstallFlow) {
            UninstallFlowSheet(
                inventory: inventory,
                isPresented: $showingUninstallFlow,
                onComplete: {
                    showingUninstallFlow = false
                    selection.removeAll()
                    inventory.selectedAppIDs.removeAll()
                }
            )
        }
        .onChange(of: selection) { _, newValue in
            inventory.selectedAppIDs = newValue
        }
        // Persist view mode
        .onChange(of: inventory.viewMode) { _, newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "appManagerViewMode")
        }
        .task(id: inventory.apps.count) {
            cachedTopIcons = await loadTopAppIcons()
        }
    }

    // MARK: - Header

    private var isZeroState: Bool {
        !inventory.hasScannedThisSession && inventory.apps.isEmpty && !inventory.isLoading
    }

    private var headerSubtitle: String? {
        if isZeroState { return "Ready" }
        if inventory.isLoading { return "Scanning..." }
        if inventory.isRefreshing { return "Calculating sizes..." }
        if !selection.isEmpty { return "\(selection.count) selected · \(formatBytes(selectedSize))" }
        if let date = inventory.lastScanDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Scanned \(formatter.localizedString(for: date, relativeTo: Date()))"
        }
        return nil
    }

    @ViewBuilder
    private var headerTrailing: some View {
        HStack(spacing: TonicSpaceToken.one) {
            // List/Grid toggle
            HStack(spacing: 2) {
                IconOnlyButton(systemName: "list.bullet") {
                    withAnimation(TonicMotionToken.springTap) {
                        inventory.viewMode = .list
                    }
                }
                .opacity(inventory.viewMode == .list ? 1.0 : 0.5)

                IconOnlyButton(systemName: "square.grid.2x2") {
                    withAnimation(TonicMotionToken.springTap) {
                        inventory.viewMode = .grid
                    }
                }
                .opacity(inventory.viewMode == .grid ? 1.0 : 0.5)
            }

            SortMenuButton(selected: $inventory.sortOption)

            if inventory.isLoading {
                SecondaryPillButton(title: "Cancel") {
                    inventory.cancelScan()
                }
            } else {
                SecondaryPillButton(title: "Rescan") {
                    Task { await inventory.scanApps() }
                }
            }
        }
    }

    // MARK: - Hero State

    private var heroState: AppHeroState {
        if isZeroState {
            return .ready
        }
        if inventory.isLoading {
            return .scanning(progress: inventory.progress)
        }
        return .idle(
            appCount: inventory.apps.count,
            totalSize: inventory.totalAppsSize,
            updatesAvailable: inventory.availableUpdates
        )
    }

    private func loadTopAppIcons() async -> [NSImage] {
        let topApps = Array(
            inventory.apps
                .filter { ($0.itemType == "app" || $0.itemType.isEmpty) && $0.totalSize >= 100 * 1024 }
                .sorted { $0.totalSize > $1.totalSize }
                .prefix(5)
        )

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .default).async {
                let icons = topApps.compactMap { app -> NSImage? in
                    let icon = NSWorkspace.shared.icon(forFile: app.path.path)
                    return icon.isValid ? icon : nil
                }
                continuation.resume(returning: icons)
            }
        }
    }

    // MARK: - Category Filter Chips

    private var categoryFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TonicSpaceToken.one) {
                ForEach(ItemType.allCases) { tab in
                    Button {
                        withAnimation(TonicMotionToken.springTap) {
                            inventory.selectedTab = tab
                            inventory.quickFilterCategory = .all
                            inventory.loginItemFilter = .all
                            selection.removeAll()
                        }
                    } label: {
                        GlassChip(
                            title: tab.rawValue,
                            icon: tab.icon,
                            role: inventory.selectedTab == tab ? .world(.applicationsBlue) : .semantic(.neutral),
                            strength: inventory.selectedTab == tab ? .strong : .subtle
                        )
                    }
                    .buttonStyle(.plain)
                    .calmHover()
                }
            }
        }
    }

    // MARK: - Summary Tiles

    private var summaryTilesRow: some View {
        HStack(spacing: TonicSpaceToken.two) {
            SummaryTile(
                title: "In Current View",
                value: "\(inventory.filteredApps.count)",
                icon: "square.grid.2x2",
                world: .applicationsBlue
            )

            SummaryTile(
                title: "Total Size",
                value: formatBytes(inventory.appsInCurrentTab.lazy.reduce(0) { $0 + $1.totalSize }),
                icon: "externaldrive",
                world: .cleanupGreen
            )

            if inventory.availableUpdates > 0 {
                SummaryTile(
                    title: "Updates Available",
                    value: "\(inventory.availableUpdates)",
                    icon: "arrow.down.circle",
                    world: .performanceOrange
                )
            }
        }
    }

    // MARK: - Quick Filter Chips

    private var quickFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TonicSpaceToken.one) {
                ForEach(inventory.availableQuickFilters) { filter in
                    Button {
                        withAnimation(TonicMotionToken.springTap) {
                            inventory.quickFilterCategory = filter
                        }
                    } label: {
                        GlassChip(
                            title: filter.rawValue,
                            icon: filter.icon,
                            role: inventory.quickFilterCategory == filter ? .world(.applicationsBlue) : .semantic(.neutral),
                            strength: inventory.quickFilterCategory == filter ? .strong : .subtle
                        )
                    }
                    .buttonStyle(.plain)
                    .calmHover()
                }
            }
        }
    }

    // MARK: - App List Section

    private let gridColumns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    @ViewBuilder
    private var appListSection: some View {
        if inventory.selectedTab == .loginItems {
            loginItemsSection
        } else if inventory.isLoading && inventory.filteredApps.isEmpty {
            ScanLoadingState(message: "Discovering applications...")
                .staggeredReveal(index: 4)
        } else if inventory.filteredApps.isEmpty {
            EmptyStatePanel(
                icon: "app.dashed",
                title: "No Applications Found",
                message: inventory.searchText.isEmpty
                    ? "Tap Rescan to discover installed applications."
                    : "No results match your search."
            )
            .emptyStateFloat()
            .staggeredReveal(index: 4)
        } else if inventory.viewMode == .grid {
            LazyVGrid(columns: gridColumns, spacing: TonicSpaceToken.two) {
                ForEach(inventory.filteredApps) { app in
                    AppItemGridCard(
                        app: app,
                        isSelected: selection.contains(app.id),
                        hasUpdate: inventory.hasUpdate(for: app.bundleIdentifier),
                        isProtected: ProtectedApps.isProtectedFromUninstall(app.bundleIdentifier),
                        formattedSize: ByteCountFormatter.string(fromByteCount: app.totalSize, countStyle: .file),
                        onTap: { toggleSelection(for: app) },
                        onDetail: { showDetail(for: app) },
                        onReveal: { NSWorkspace.shared.activateFileViewerSelecting([app.path]) }
                    )
                }
            }
        } else {
            LazyVStack(spacing: TonicSpaceToken.two) {
                ForEach(inventory.filteredApps) { app in
                    AppItemCard(
                        app: app,
                        isSelected: selection.contains(app.id),
                        hasUpdate: inventory.hasUpdate(for: app.bundleIdentifier),
                        isProtected: ProtectedApps.isProtectedFromUninstall(app.bundleIdentifier),
                        formattedSize: ByteCountFormatter.string(fromByteCount: app.totalSize, countStyle: .file),
                        onTap: { toggleSelection(for: app) },
                        onDetail: { showDetail(for: app) },
                        onReveal: { NSWorkspace.shared.activateFileViewerSelecting([app.path]) }
                    )
                }
            }
        }
    }

    // MARK: - Login Items Section

    @ViewBuilder
    private var loginItemsSection: some View {
        let allLoginItems = loginItemsList

        if allLoginItems.isEmpty {
            EmptyStatePanel(
                icon: "person.2",
                title: "No Login Items Found",
                message: "Login items are applications and services that launch automatically when you log in."
            )
            .emptyStateFloat()
            .staggeredReveal(index: 4)
        } else {
            // Login item sub-filter chips
            if inventory.selectedTab == .loginItems {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: TonicSpaceToken.one) {
                        ForEach(LoginItemFilter.allCases) { filter in
                            Button {
                                withAnimation(TonicMotionToken.springTap) {
                                    inventory.loginItemFilter = filter
                                }
                            } label: {
                                GlassChip(
                                    title: filter.rawValue,
                                    icon: filter.icon,
                                    role: inventory.loginItemFilter == filter ? .world(.applicationsBlue) : .semantic(.neutral),
                                    strength: inventory.loginItemFilter == filter ? .strong : .subtle
                                )
                            }
                            .buttonStyle(.plain)
                            .calmHover()
                        }
                    }
                }
                .staggeredReveal(index: 3)
            }

            LazyVStack(spacing: TonicSpaceToken.two) {
                ForEach(Array(allLoginItems.enumerated()), id: \.element.id) { index, item in
                    let row = LoginItemRow(item: item) {
                        showDetail(for: item)
                    }

                    if index < 15 {
                        row.staggeredReveal(index: 4 + index)
                    } else {
                        row
                    }
                }
            }
        }
    }

    private var loginItemsList: [AppMetadata] {
        var allItems = inventory.filteredApps + loginItemsAsApps

        switch inventory.loginItemFilter {
        case .all:
            break
        case .launchAgents:
            allItems = allItems.filter { $0.itemType.contains("LaunchAgent") || $0.itemType.contains("login") }
        case .daemons:
            allItems = allItems.filter { $0.itemType.contains("LaunchDaemon") || $0.itemType.contains("Daemon") }
        }

        return allItems
    }

    private var loginItemsAsApps: [AppMetadata] {
        var result: [AppMetadata] = []

        for item in inventory.loginItems {
            let app = AppMetadata(
                bundleIdentifier: item.bundleIdentifier,
                appName: item.name,
                path: item.path,
                version: nil,
                totalSize: 0,
                installDate: nil,
                category: .other,
                itemType: "loginItem"
            )
            result.append(app)
        }

        for service in inventory.launchServices {
            let app = AppMetadata(
                bundleIdentifier: service.bundleIdentifier,
                appName: service.name,
                path: service.path,
                version: nil,
                totalSize: 0,
                installDate: nil,
                category: .other,
                itemType: service.serviceType.rawValue
            )
            result.append(app)
        }

        return result
    }

    // MARK: - Helpers

    private var selectedSize: Int64 {
        inventory.filteredApps
            .filter { selection.contains($0.id) }
            .reduce(0) { $0 + $1.totalSize }
    }

    private func toggleSelection(for app: AppMetadata) {
        withAnimation(TonicMotionToken.springTap) {
            if selection.contains(app.id) {
                selection.remove(app.id)
            } else {
                selection.insert(app.id)
            }
        }
    }

    private func showDetail(for app: AppMetadata) {
        currentAppForDetail = app
        showingDetail = true
    }

    private func revealSelectedInFinder() {
        let urls = inventory.filteredApps
            .filter { selection.contains($0.id) }
            .map { $0.path }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    private func formatBytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }
}

// MARK: - Preview

#Preview {
    AppManagerView()
        .frame(width: 900, height: 700)
}
