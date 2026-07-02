//
//  ContentView.swift
//  Tonic
//
//  Main view with sidebar navigation
//  Integrated with onboarding and permission checks
//

import SwiftUI
import AppKit

struct ContentView: View {
    @State private var selectedDestination: NavigationDestination = .dashboard
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showOnboarding = false
    @State private var showPermissionPrompt = false
    @State private var missingPermissionFor: PermissionManager.Feature?
    @State private var featureFlagsRefreshID = UUID()
    @Binding var showCommandPalette: Bool

    @State private var permissionManager = PermissionManager.shared
    @State private var appUpdater = AppUpdater.shared
    @State private var dismissedBanners: Set<String> = []
    @State private var hasSeenOnboardingValue = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    @StateObject private var smartCareSession = SmartCareSessionStore()
    @StateObject private var dashboardScanSession = SmartScanManager()

    var hasSeenOnboarding: Bool {
        get { hasSeenOnboardingValue }
        set { hasSeenOnboardingValue = newValue }
    }

    // MARK: - Global alert banner (spec §alert-banner)

    private struct GlobalBanner {
        let id: String
        let message: String
        let actionTitle: String
        let action: () -> Void
    }

    /// Highest-priority global system state, or nil. Dismissible per session.
    private var activeBanner: GlobalBanner? {
        if !BuildCapabilities.current.requiresScopeAccess,
           !permissionManager.hasFullDiskAccess,
           !dismissedBanners.contains("fda") {
            return GlobalBanner(
                id: "fda",
                message: "Full Disk Access required to scan and manage apps.",
                actionTitle: "Grant"
            ) {
                missingPermissionFor = nil
                showPermissionPrompt = true
            }
        }
        if appUpdater.updateCount > 0, !dismissedBanners.contains("updates") {
            let n = appUpdater.updateCount
            return GlobalBanner(
                id: "updates",
                message: "\(n) app update\(n == 1 ? "" : "s") available.",
                actionTitle: "Review"
            ) {
                selectedDestination = .appManager
            }
        }
        return nil
    }

    var body: some View {
        ZStack {
            // Editorial: a flat canvas / obsidian field. No ambient world canvas.
            TonicDS.Colors.canvas
                .ignoresSafeArea()

            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(selectedDestination: $selectedDestination)
                    .id(featureFlagsRefreshID)
            } detail: {
                VStack(spacing: 0) {
                    // Spec §alert-banner: thin near-black strip for global system states.
                    if let banner = activeBanner {
                        AlertBanner(
                            message: banner.message,
                            actionTitle: banner.actionTitle,
                            onAction: banner.action,
                            onDismiss: { dismissedBanners.insert(banner.id) }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    DetailView(
                        selectedDestination: $selectedDestination,
                        onPermissionNeeded: { feature in
                            missingPermissionFor = feature
                            showPermissionPrompt = true
                        },
                        smartCareSession: smartCareSession,
                        dashboardScanSession: dashboardScanSession
                    )
                }
                .animation(TonicDS.Motion.present, value: activeBanner?.id)
            }
            .navigationTitle("Tonic")
            .frame(minWidth: 800, minHeight: 500)
            .animation(TonicDS.Motion.present, value: selectedDestination)
            .sheet(isPresented: $showOnboarding) {
                UnifiedOnboardingView(isPresented: $showOnboarding)
            }
            .sheet(isPresented: $showPermissionPrompt) {
                PermissionPromptView(
                    feature: missingPermissionFor,
                    isPresented: $showPermissionPrompt
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowWidgetCustomization"))) { _ in
                // Open preferences to Widgets tab
                selectedDestination = .settings
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .openSettingsSection,
                        object: nil,
                        userInfo: [SettingsDeepLinkUserInfoKey.section: SettingsSection.modules.rawValue]
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openAppManagerFromStorageHub)) { _ in
                selectedDestination = .appManager
            }
            .onReceive(NotificationCenter.default.publisher(for: .openLiveMonitor)) { _ in
                selectedDestination = .liveMonitoring
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToDestination)) { note in
                guard let raw = note.userInfo?["destination"] as? String,
                      let destination = NavigationDestination(rawValue: raw) else { return }
                selectedDestination = destination
            }
            .onReceive(NotificationCenter.default.publisher(for: .runSmartScanCommand)) { _ in
                selectedDestination = .systemCleanup
                smartCareSession.startScan()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showModuleSettings)) { notification in
                guard let rawModule = notification.userInfo?[SettingsDeepLinkUserInfoKey.module] as? String,
                      let _ = WidgetType(rawValue: rawModule) else {
                    return
                }

                // Navigate to Settings in the main window
                selectedDestination = .settings

                // After navigation completes, post the module selection notifications
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .openSettingsSection,
                        object: nil,
                        userInfo: [SettingsDeepLinkUserInfoKey.section: SettingsSection.modules.rawValue]
                    )

                    // Small delay to ensure ModulesSettingsContent is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        NotificationCenter.default.post(
                            name: .openModuleSettings,
                            object: nil,
                            userInfo: notification.userInfo
                        )
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TonicDidCompleteReset"))) { _ in
                // App was reset — re-read onboarding flag and trigger onboarding
                hasSeenOnboardingValue = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
                showOnboarding = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .featureFlagsDidChange)) { _ in
                featureFlagsRefreshID = UUID()
                selectedDestination = NavigationDestination.sanitize(selectedDestination)
            }
            .onChange(of: selectedDestination) { _, newValue in
                let sanitized = NavigationDestination.sanitize(newValue)
                if sanitized != newValue {
                    selectedDestination = sanitized
                }
            }
            .onAppear {
                selectedDestination = NavigationDestination.sanitize(selectedDestination)
                checkFirstLaunch()
            }

            // Command Palette Overlay
            if showCommandPalette {
                CommandPaletteView(
                    isPresented: $showCommandPalette,
                    selectedDestination: $selectedDestination
                )
            }
        }
    }

    private func checkFirstLaunch() {
        if !hasSeenOnboarding {
            showOnboarding = true
        }

        // Check permissions on app launch
        Task {
            await permissionManager.checkAllPermissions()
        }
    }
}

struct DetailView: View {
    @Binding var selectedDestination: NavigationDestination
    let onPermissionNeeded: (PermissionManager.Feature) -> Void
    @ObservedObject var smartCareSession: SmartCareSessionStore
    @ObservedObject var dashboardScanSession: SmartScanManager

    @State private var permissionManager = PermissionManager.shared
    @State private var checkedPermissions = false
    /// Destinations that have been visited at least once. They stay mounted in a
    /// keep-alive ZStack so each screen preserves its state (scroll position,
    /// in-progress work) instead of being torn down and re-initialized on every
    /// navigation. Heavy screens pause their work via `isActive` when not selected.
    @State private var visited: Set<NavigationDestination> = []

    var body: some View {
        Group {
            if !checkedPermissions {
                ProgressView("Checking permissions...")
                    .tint(TonicDS.Colors.ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)
                    .task {
                        await permissionManager.checkAllPermissions()
                        checkedPermissions = true
                    }
            } else {
                keepAliveContainer
            }
        }
        .background(Color.clear)
        .onAppear { visited.insert(selectedDestination) }
        .onChange(of: selectedDestination) { _, newValue in
            visited.insert(newValue)
        }
    }

    /// Keeps every visited destination mounted; only the selected one is visible
    /// and interactive. Lazy: a screen isn't built until first visited.
    private var keepAliveContainer: some View {
        ZStack {
            ForEach(NavigationDestination.allCases.filter { visited.contains($0) }, id: \.self) { dest in
                destinationView(dest)
                    .opacity(dest == selectedDestination ? 1 : 0)
                    .allowsHitTesting(dest == selectedDestination)
                    .accessibilityHidden(dest != selectedDestination)
                    .zIndex(dest == selectedDestination ? 1 : 0)
            }
        }
        .animation(TonicDS.Motion.present, value: selectedDestination)
    }

    @ViewBuilder
    private func destinationView(_ destination: NavigationDestination) -> some View {
        switch destination {
        case .dashboard:
            HomeView(scanManager: dashboardScanSession, selectedDestination: $selectedDestination)
        case .systemCleanup:
            CleanView(session: smartCareSession)
        case .appManager:
            if BuildCapabilities.current.requiresScopeAccess || permissionManager.hasFullDiskAccess {
                AppsView()
            } else {
                PermissionRequiredView(
                    icon: "externaldrive.fill",
                    title: "Full Disk Access Required",
                    description: "App Manager needs Full Disk Access to scan all installed applications and their support files.",
                    onGrantPermission: {
                        onPermissionNeeded(.appManager)
                    }
                )
            }
        case .diskAnalysis:
            CleanView(session: smartCareSession, initialTab: .storage)
        case .recentlyCleaned:
            CleanView(session: smartCareSession, initialTab: .history)
        case .liveMonitoring:
            MonitorView(isActive: destination == selectedDestination)
        case .menuBarWidgets:
            SettingsView(initialSection: .modules)
        case .developerTools:
            DeveloperToolsView()
        case .designSandbox:
            DesignGalleryView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Permission Prompt View

struct PermissionPromptView: View {
    let feature: PermissionManager.Feature?
    @Binding var isPresented: Bool

    @State private var permissionManager = PermissionManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(TonicDS.Colors.statusWarning)

            Text("Permission Required")
                .tonicType(.cardHeading)
                .foregroundStyle(TonicDS.Colors.textPrimary)

            Text(messageText)
                .tonicType(.body)
                .foregroundStyle(TonicDS.Colors.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            VStack(alignment: .leading, spacing: 12) {
                permissionRow(TonicPermission.fullDiskAccess)
                permissionRow(TonicPermission.accessibility)
            }
            .padding()
            .background(TonicDS.Colors.surface,
                        in: RoundedRectangle(cornerRadius: TonicDS.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TonicDS.Radius.md, style: .continuous)
                    .strokeBorder(TonicDS.Colors.hairline, lineWidth: 1)
            )

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .tint(TonicDS.Colors.ink)

                Button(BuildCapabilities.current.requiresScopeAccess ? "Add Scope" : "Open System Settings") {
                    grantPermission()
                }
                .buttonStyle(.borderedProminent)
                .tint(TonicDS.Colors.ink)
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 500, height: 400)
        .background(TonicDS.Colors.surface, in: RoundedRectangle(cornerRadius: TonicDS.Radius.lg, style: .continuous)).overlay(RoundedRectangle(cornerRadius: TonicDS.Radius.lg, style: .continuous).strokeBorder(TonicDS.Colors.hairline, lineWidth: 1))
    }

    private var messageText: String {
        let accessTerm = BuildCapabilities.current.requiresScopeAccess ? "authorized locations" : "Full Disk Access"
        switch feature {
        case .diskScan, .appManager:
            return "Tonic needs \(accessTerm) to scan files and applications on your Mac."
        case .smartScan:
            return "Smart Scan requires \(accessTerm) to perform a comprehensive system scan."
        case .basicScan, nil:
            return "Tonic needs additional permissions to function properly."
        }
    }

    private func permissionRow(_ permission: TonicPermission) -> some View {
        let status = permissionManager.permissionStatuses[permission] ?? .notDetermined
        let title = BuildCapabilities.current.requiresScopeAccess && permission == .fullDiskAccess
            ? "Authorized Locations"
            : permission.rawValue

        return HStack {
            Image(systemName: permission.icon)
                .foregroundStyle(status == .authorized ? TonicDS.Colors.statusSuccess : TonicDS.Colors.textMuted)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .tonicType(.body)
                    .foregroundStyle(TonicDS.Colors.textPrimary)
                Text(permissionDescription(permission))
                    .tonicType(.caption)
                    .foregroundStyle(TonicDS.Colors.textMuted)
            }

            Spacer()

            HStack(spacing: 6) {
                if status == .authorized {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(TonicDS.Colors.statusSuccess)
                    Text("Granted")
                        .tonicType(.caption)
                        .foregroundStyle(TonicDS.Colors.statusSuccess)
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(TonicDS.Colors.statusWarning)
                    Text("Required")
                        .tonicType(.caption)
                        .foregroundStyle(TonicDS.Colors.statusWarning)
                }
            }
        }
    }

    private func permissionDescription(_ permission: TonicPermission) -> String {
        if BuildCapabilities.current.requiresScopeAccess && permission == .fullDiskAccess {
            return "Choose the folders or volumes Tonic may analyze."
        }
        return permission.description
    }

    private func grantPermission() {
        if BuildCapabilities.current.requiresScopeAccess {
            _ = AccessBroker.shared.addScopeUsingOpenPanel(
                title: "Grant Access Scope",
                message: "Choose a location for Tonic to analyze."
            )
            Task {
                await permissionManager.checkAllPermissions()
                if permissionManager.hasFullDiskAccess {
                    isPresented = false
                }
            }
            return
        }

        // Open Full Disk Access in System Settings (macOS 14+)
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)

        // Recheck permissions after delay
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await permissionManager.checkAllPermissions()

            // If granted, dismiss
            if permissionManager.hasFullDiskAccess {
                isPresented = false
            }
        }
    }
}

// MARK: - Permission Required View

struct PermissionRequiredView: View {
    let icon: String
    let title: String
    let description: String
    let onGrantPermission: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(TonicDS.Colors.statusWarning)

            Text(title)
                .tonicType(.cardHeading)
                .foregroundStyle(TonicDS.Colors.textPrimary)

            Text(description)
                .tonicType(.body)
                .foregroundStyle(TonicDS.Colors.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button("Grant Permission") {
                onGrantPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(TonicDS.Colors.ink)

            Text(
                BuildCapabilities.current.requiresScopeAccess
                ? "You can also manage authorized locations later in Settings > Permissions."
                : "You can also grant this permission later in System Settings > Privacy & Security > Full Disk Access."
            )
                .tonicType(.caption)
                .foregroundStyle(TonicDS.Colors.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 350)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color.clear)
    }
}

// MARK: - Views that use SystemCleanupView

// AppManagerView is defined in Views/AppManager/AppManagerView.swift

struct DeveloperToolsView: View {
    @State private var flagRefresh = UUID()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
                TonicPageHeader("Developer Tools", subtitle: "Internal diagnostics and feature flags")

                SettingsPanel(title: "Feature flags") {
                    let features = Array(WIPFeature.allCases.enumerated())
                    ForEach(features, id: \.element) { idx, feature in
                        TonicToggleRow(
                            title: feature.displayName,
                            showsDivider: idx < features.count - 1,
                            isOn: Binding(
                                get: { FeatureFlags.isEnabled(feature) },
                                set: { FeatureFlags.set(feature, enabled: $0); flagRefresh = UUID()
                                       NotificationCenter.default.post(name: .featureFlagsDidChange, object: nil) }
                            )
                        )
                    }
                }
                .id(flagRefresh)

                SettingsPanel(title: "Maintenance") {
                    actionRow("Reveal logs in Finder", "doc.text.magnifyingglass") { revealLogs() }
                    actionRow("Reset onboarding", "arrow.counterclockwise", showsDivider: false) {
                        UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
                        NotificationCenter.default.post(name: NSNotification.Name("TonicDidCompleteReset"), object: nil)
                    }
                }
            }
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tonicScreenHPadding()
            .padding(.vertical, TonicDS.Space.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TonicDS.Colors.canvas)
    }

    private func actionRow(_ title: String, _ icon: String, showsDivider: Bool = true, action: @escaping () -> Void) -> some View {
        TonicPreferenceRow(title: title, showsDivider: showsDivider) {
            Button(action: action) {
                Image(systemName: icon).foregroundStyle(TonicDS.Colors.linkBlue)
            }
            .buttonStyle(.plain).tonicPointerCursor()
        }
    }

    private func revealLogs() {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Logs/com.tonic.Tonic")
        if let dir { NSWorkspace.shared.open(dir) }
    }
}

// MARK: - Command Palette View

/// A command palette overlay for quick navigation using Cmd+K
/// Features:
/// - Triggered by Cmd+K keyboard shortcut
/// - Fuzzy search across all screen names
/// - Navigate with arrow keys and Enter, dismiss with Esc
/// - Works from any screen in the app
struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    @Binding var selectedDestination: NavigationDestination

    @State private var searchText = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isSearchFocused: Bool

    private var allDestinations: [NavigationDestination] {
        NavigationDestination.allCases.filter(FeatureFlags.isEnabled)
    }

    /// Filter destinations based on fuzzy search
    private var filteredDestinations: [NavigationDestination] {
        if searchText.isEmpty {
            return allDestinations
        }

        return allDestinations.filter { destination in
            fuzzyMatch(searchText.lowercased(), in: destination.displayName.lowercased())
        }
    }

    /// Fuzzy search: Returns true if all characters in query appear in order within text
    private func fuzzyMatch(_ query: String, in text: String) -> Bool {
        var queryIndex = query.startIndex
        var textIndex = text.startIndex

        while queryIndex < query.endIndex && textIndex < text.endIndex {
            if query[queryIndex] == text[textIndex] {
                queryIndex = query.index(after: queryIndex)
            }
            textIndex = text.index(after: textIndex)
        }

        return queryIndex == query.endIndex
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
                .onKeyPress { press in
                    // Handle Escape key globally
                    if press.key == .escape {
                        dismiss()
                        return .handled
                    }
                    // Handle arrow keys for navigation
                    if press.key == .downArrow {
                        withAnimation(.easeOut(duration: 0.1)) {
                            if selectedIndex < filteredDestinations.count - 1 {
                                selectedIndex += 1
                            }
                        }
                        return .handled
                    }
                    if press.key == .upArrow {
                        withAnimation(.easeOut(duration: 0.1)) {
                            if selectedIndex > 0 {
                                selectedIndex -= 1
                            }
                        }
                        return .handled
                    }
                    return .ignored
                }

            // Command palette card
            VStack(spacing: 0) {
                // Search input
                HStack(spacing: TonicDS.Space.xs) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(TonicDS.Colors.textMuted)

                    TextField("Search screens…", text: $searchText)
                        .tonicType(.bodyLarge)
                        .textFieldStyle(.plain)
                        .focused($isSearchFocused)
                        .onSubmit {
                            navigateToSelected()
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            selectedIndex = 0
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(TonicDS.Colors.textMuted)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(TonicDS.Space.md)

                TonicHairline()

                // Results list (custom rows — quiet selection, no OS accent)
                ScrollViewReader { scrollProxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 2) {
                            ForEach(Array(filteredDestinations.enumerated()), id: \.offset) { index, destination in
                                paletteRow(index: index, destination: destination)
                                    .id(index)
                            }
                        }
                        .padding(TonicDS.Space.xs)
                    }
                    .onChange(of: selectedIndex) { _, newValue in
                        guard filteredDestinations.indices.contains(newValue) else { return }
                        scrollProxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
            .frame(width: 500, height: 450)
            .background(TonicDS.Colors.surface,
                        in: RoundedRectangle(cornerRadius: TonicDS.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TonicDS.Radius.lg, style: .continuous)
                    .strokeBorder(TonicDS.Colors.hairline, lineWidth: 1)
            )
            .onAppear {
                isSearchFocused = true
                selectedIndex = 0
            }
            .onChange(of: filteredDestinations.count) { _, newCount in
                if newCount == 0 {
                    selectedIndex = 0
                } else if selectedIndex >= newCount {
                    selectedIndex = newCount - 1
                }
            }
        }
    }


    @ViewBuilder
    private func paletteRow(index: Int, destination: NavigationDestination) -> some View {
        let isSelected = index == selectedIndex
        HStack(spacing: TonicDS.Space.sm) {
            Image(systemName: destination.systemImage)
                .font(.system(size: 14, weight: .regular))
                .frame(width: 20)
                .foregroundStyle(isSelected ? TonicDS.Colors.textPrimary : TonicDS.Colors.textMuted)

            Text(destination.sidebarDisplayName)
                .tonicType(.body)
                .foregroundStyle(isSelected ? TonicDS.Colors.textPrimary : TonicDS.Colors.textMuted)

            Spacer()

            if isSelected {
                Text("↵").tonicType(.monoLabel).foregroundStyle(TonicDS.Colors.textMuted)
            }
        }
        .padding(.horizontal, TonicDS.Space.sm)
        .frame(height: 36)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous)
                    .fill(TonicDS.Colors.rowHover(0.06))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedIndex = index
            navigateToSelected()
        }
    }

    private func navigateToSelected() {
        guard !filteredDestinations.isEmpty && selectedIndex < filteredDestinations.count else {
            return
        }

        selectedDestination = filteredDestinations[selectedIndex]
        dismiss()
    }

    private func dismiss() {
        searchText = ""
        selectedIndex = 0
        isPresented = false
    }
}

#Preview {
    ContentView(showCommandPalette: .constant(false))
}
