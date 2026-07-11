//
//  ContentView.swift
//  Tonic
//
//  Main view with sidebar navigation
//  Integrated with onboarding and permission checks
//

import SwiftUI
import AppKit

/// Folder chosen for a one-shot scan report (File ▸ Scan Folder… / Dock drop).
private struct FolderScanTarget: Identifiable {
    let path: String
    var id: String { path }
}

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReducesMotion
    @State private var route: TonicRoute = .hub(.home)
    @State private var folderScanTarget: FolderScanTarget?
    @State private var showOnboarding = false
    @State private var showPermissionPrompt = false
    @State private var missingPermissionFor: PermissionManager.Feature?
    @Binding var showCommandPalette: Bool
    @AppStorage(RailPinPreference.key) private var isRailPinned = false

    @State private var permissionManager = PermissionManager.shared
    @State private var appUpdater = AppUpdater.shared
    @State private var dismissedBanners: Set<String> = []
    @State private var hasSeenOnboardingValue = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    @StateObject private var smartCareSession = SmartCareSessionStore()

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

    /// Banner + routed detail — the app's content column, shared by both shells.
    private var mainColumn: some View {
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
                route: $route,
                onPermissionNeeded: { feature in
                    missingPermissionFor = feature
                    showPermissionPrompt = true
                },
                smartCareSession: smartCareSession
            )
            .padding(.leading, isRailPinned ? TonicDS.Glass.Shell.pinnedContentInset : 0)
            .animation(TonicMotionPolicy(reduceMotion: systemReducesMotion).layout,
                       value: isRailPinned)
        }
        .animation(TonicDS.Motion.present, value: activeBanner?.id)
    }

    /// One transparent host window with two visually independent surfaces. The
    /// geometry never changes under Reduce Transparency; only materials resolve
    /// from adaptive glass to solid accessibility fills.
    private var shell: some View {
        ZStack(alignment: .leading) {
            Color.clear.ignoresSafeArea()

            TonicGlassSlab {
                mainColumn
            }
            .padding(.leading, TonicDS.Glass.Shell.slabLeadingInset)
            .padding([.top, .trailing, .bottom], TonicDS.Glass.Shell.outerInset)

            FloatingRailView(route: $route, isPinned: $isRailPinned) {
                showCommandPalette = true
            }
            .padding(.leading, TonicDS.Glass.Shell.railLeadingInset)
        }
    }

    /// Highest-priority global system state, or nil. Dismissible per session.
    private var activeBanner: GlobalBanner? {
        if appUpdater.updateCount > 0, !dismissedBanners.contains("updates") {
            let n = appUpdater.updateCount
            return GlobalBanner(
                id: "updates",
                message: "\(n) app update\(n == 1 ? "" : "s") available.",
                actionTitle: "Review"
            ) {
                route = .tool(.apps)
            }
        }
        return nil
    }

    var body: some View {
        ZStack {
            shell
            .navigationTitle("Tonic")
            .frame(minWidth: 920, minHeight: 620)
            .animation(TonicDS.Motion.present, value: route)
            // Transparent NSWindow so the behind-window blur reaches the desktop.
            .background(WindowConfigurator())
            // In-app Light/Dark/System selector — load-bearing under glass.
            .preferredColorScheme(AppearancePreferences.shared.themeMode.colorScheme)
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
                route = .tool(.widgets)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .openSettingsSection,
                        object: nil,
                        userInfo: [SettingsDeepLinkUserInfoKey.section: SettingsSection.modules.rawValue]
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openAppManagerFromStorageHub)) { _ in
                route = .tool(.apps)
            }
            .onReceive(NotificationCenter.default.publisher(for: .openLiveMonitor)) { _ in
                route = .tool(.systemMonitor)
            }
            .onReceive(NotificationCenter.default.publisher(for: .openMenuBarManagement)) { _ in
                route = .tool(.menuBar)
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToDestination)) { note in
                guard let raw = note.userInfo?["destination"] as? String,
                      let destination = NavigationDestination(rawValue: raw) else { return }
                route = route(for: destination)
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToTonicHub)) { note in
                guard let raw = note.userInfo?["hub"] as? String,
                      let hub = TonicHub(rawValue: raw) else { return }
                route = .hub(hub)
            }
            .onReceive(NotificationCenter.default.publisher(for: .runSmartScanCommand)) { _ in
                route = .tool(.smartCare)
                smartCareSession.startScan()
            }
            .onReceive(NotificationCenter.default.publisher(for: .scanFolderCommand)) { note in
                if let path = note.userInfo?["path"] as? String {
                    folderScanTarget = FolderScanTarget(path: path)
                }
            }
            .sheet(item: $folderScanTarget) { target in
                FolderScanReportView(folderPath: target.path) { folderScanTarget = nil }
            }
            // tonic:// deep links (notification actions, Shortcuts, external tools):
            // tonic://scan · tonic://clean · tonic://apps · tonic://monitor · tonic://settings
            .onOpenURL { url in
                guard url.scheme == "tonic" else { return }
                switch url.host?.lowercased() {
                case "scan":
                    route = .tool(.smartCare)
                    smartCareSession.startScan()
                case "clean":
                    route = .tool(.smartCare)
                case "apps", "updates":
                    route = .tool(.apps)
                case "monitor":
                    route = .tool(.systemMonitor)
                case "menubar":
                    route = .tool(.menuBar)
                case "windows":
                    route = .tool(.windows)
                case "settings":
                    route = .settings
                default:
                    break
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .showModuleSettings)) { notification in
                guard let rawModule = notification.userInfo?[SettingsDeepLinkUserInfoKey.module] as? String,
                      let _ = WidgetType(rawValue: rawModule) else {
                    return
                }

                route = .tool(.widgets)

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
            .onAppear {
                checkFirstLaunch()
            }

            // Command Palette Overlay
            if showCommandPalette {
                CommandPaletteView(
                    isPresented: $showCommandPalette,
                    route: $route
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

    private func route(for destination: NavigationDestination) -> TonicRoute {
        switch destination {
        case .dashboard: .hub(.home)
        case .systemCleanup: .tool(.smartCare)
        case .appManager: .tool(.apps)
        case .diskAnalysis: .tool(.storage)
        case .recentlyCleaned: .tool(.actionHistory)
        case .liveMonitoring: .tool(.systemMonitor)
        case .menuBarManager: .tool(.menuBar)
        case .menuBarWidgets: .tool(.widgets)
        case .developerTools, .designSandbox, .settings: .settings
        }
    }
}

struct DetailView: View {
    @Binding var route: TonicRoute
    let onPermissionNeeded: (PermissionManager.Feature) -> Void
    @ObservedObject var smartCareSession: SmartCareSessionStore

    @State private var permissionManager = PermissionManager.shared
    @State private var checkedPermissions = false

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
                destinationView
                    .id(route)
                    .transition(.opacity)
            }
        }
        .background(Color.clear)
        .animation(TonicDS.Motion.present, value: route)
    }

    @ViewBuilder
    private var destinationView: some View {
        switch route {
        case .hub(.home), .tool(.actionHistory):
            TonicHomeView(route: $route)
        case .hub(.care):
            CareHubView(smartCareSession: smartCareSession, onPermissionNeeded: onPermissionNeeded)
        case .tool(let tool) where tool.hub == .care:
            CareHubView(initialTool: tool, smartCareSession: smartCareSession, onPermissionNeeded: onPermissionNeeded)
        case .hub(.organize):
            OrganizeHubView()
        case .tool(let tool) where tool.hub == .organize:
            OrganizeHubView(initialTool: tool)
        case .hub(.monitor):
            MonitorHubView()
        case .tool(let tool) where tool.hub == .monitor:
            MonitorHubView(initialTool: tool)
        case .hub(.automate), .tool(.automations):
            AutomationHubView()
        case .settings:
            SettingsView()
        default:
            TonicHomeView(route: $route)
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

            HStack(spacing: TonicDS.Space.md) {
                TextAction("Cancel") {
                    isPresented = false
                }
                PrimaryPill(BuildCapabilities.current.requiresScopeAccess ? "Add Scope" : "Open System Settings") {
                    grantPermission()
                }
            }

            Spacer()
        }
        .padding(TonicDS.Space.lg)
        .frame(minWidth: 360, idealWidth: 500, maxWidth: 560,
               minHeight: 340, idealHeight: 400, maxHeight: 460)
        .tonicSheetBackground()
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

            PrimaryPill("Grant Permission") {
                onGrantPermission()
            }

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
        .tonicCanvas()
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
    @Binding var route: TonicRoute

    @State private var searchText = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isSearchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var allCommands: [CommandDescriptor] {
        let hubCommands = TonicHub.allCases.map { hub in
            CommandDescriptor(
                id: "open.hub.\(hub.rawValue)",
                title: "Open \(hub.title)",
                subtitle: "Hub",
                symbol: hub.symbol,
                route: .hub(hub),
                aliases: []
            )
        }
        return CommandDescriptor.windowCommands + CommandDescriptor.toolCommands + hubCommands
    }

    private var filteredCommands: [CommandDescriptor] {
        if searchText.isEmpty {
            return allCommands
        }

        let query = searchText.lowercased()
        return allCommands.filter { command in
            fuzzyMatch(query, in: command.title.lowercased())
                || command.aliases.contains { fuzzyMatch(query, in: $0.lowercased()) }
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
            // Dimmed background — the one sanctioned scrim token.
            TonicDS.Colors.overlayDim
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
                    // Handle arrow keys for navigation (no movement under Reduce Motion)
                    if press.key == .downArrow {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.1)) {
                            if selectedIndex < filteredCommands.count - 1 {
                                selectedIndex += 1
                            }
                        }
                        return .handled
                    }
                    if press.key == .upArrow {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.1)) {
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

                    TextField("Run an action or open a tool…", text: $searchText)
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
                            if filteredCommands.isEmpty {
                                Text("No actions match \u{201C}\(searchText)\u{201D}")
                                    .tonicType(.caption)
                                    .foregroundStyle(TonicDS.Colors.textMuted)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, TonicDS.Space.lg)
                            } else {
                                ForEach(Array(filteredCommands.enumerated()), id: \.offset) { index, command in
                                    paletteRow(index: index, command: command)
                                        .id(index)
                                }
                            }
                        }
                        .padding(TonicDS.Space.xs)
                    }
                    .onChange(of: selectedIndex) { _, newValue in
                        guard filteredCommands.indices.contains(newValue) else { return }
                        scrollProxy.scrollTo(newValue, anchor: .center)
                    }
                }

                TonicHairline()
                HStack {
                    MonoLabel("\(filteredCommands.count) result\(filteredCommands.count == 1 ? "" : "s")")
                    Spacer()
                    MonoLabel("↑↓ Navigate · ↵ Open · Esc Close")
                }
                .padding(.horizontal, TonicDS.Space.md)
                .padding(.vertical, TonicDS.Space.xs)
            }
            .frame(minWidth: 320, idealWidth: 500, maxWidth: 560,
                   minHeight: 280, idealHeight: 450, maxHeight: 500)
            .tonicSurface(.overlay,
                          in: RoundedRectangle(cornerRadius: TonicDS.Radius.lg, style: .continuous),
                          flatFill: TonicDS.Colors.surface,
                          flatStroke: TonicDS.Colors.hairline)
            .onAppear {
                isSearchFocused = true
                selectedIndex = 0
            }
            .onChange(of: filteredCommands.count) { _, newCount in
                if newCount == 0 {
                    selectedIndex = 0
                } else if selectedIndex >= newCount {
                    selectedIndex = newCount - 1
                }
            }
        }
    }


    @ViewBuilder
    private func paletteRow(index: Int, command: CommandDescriptor) -> some View {
        let isSelected = index == selectedIndex
        Button {
            selectedIndex = index
            navigateToSelected()
        } label: {
            HStack(spacing: TonicDS.Space.sm) {
                Image(systemName: command.symbol)
                    .font(.system(size: 14, weight: .regular))
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? TonicDS.Colors.textPrimary : TonicDS.Colors.textMuted)

                VStack(alignment: .leading, spacing: 2) {
                    Text(command.title)
                        .tonicType(.body)
                        .foregroundStyle(isSelected ? TonicDS.Colors.textPrimary : TonicDS.Colors.textMuted)
                    Text(command.subtitle)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(TonicDS.Colors.textMuted)
                }

                Spacer()

                if isSelected {
                    Text("↵").tonicType(.monoLabel).foregroundStyle(TonicDS.Colors.textMuted)
                }
            }
            .padding(.horizontal, TonicDS.Space.sm)
            .frame(height: TonicDS.Layout.minControlTarget)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous)
                        .fill(TonicDS.Colors.rowHover(0.06))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .tonicPointerCursor()
    }

    private func navigateToSelected() {
        guard !filteredCommands.isEmpty && selectedIndex < filteredCommands.count else {
            return
        }

        let command = filteredCommands[selectedIndex]
        if let action = command.windowAction {
            WindowManagementService.shared.perform(action)
        }
        route = command.route
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
