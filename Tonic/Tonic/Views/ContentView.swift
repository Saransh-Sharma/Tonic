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
    @State private var showFeatureTour = false
    @State private var showPermissionPrompt = false
    @State private var missingPermissionFor: PermissionManager.Feature?
    @State private var showWidgetOnboarding = false
    @Binding var showCommandPalette: Bool
    @Environment(\.isHighContrast) private var isHighContrast

    @State private var permissionManager = PermissionManager.shared
    @State private var hasSeenOnboardingValue = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")

    var hasSeenOnboarding: Bool {
        get { hasSeenOnboardingValue }
        set { hasSeenOnboardingValue = newValue }
    }

    var body: some View {
        ZStack {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(selectedDestination: $selectedDestination)
            } detail: {
                DetailView(
                    item: selectedDestination,
                    onPermissionNeeded: { feature in
                        missingPermissionFor = feature
                        showPermissionPrompt = true
                    }
                )
            }
            .navigationTitle("Tonic")
            .frame(minWidth: 800, minHeight: 500)
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(isPresented: $showOnboarding)
            }
            .sheet(isPresented: $showFeatureTour) {
                OnboardingTourView(isPresented: $showFeatureTour)
            }
            .sheet(isPresented: $showPermissionPrompt) {
                PermissionPromptView(
                    feature: missingPermissionFor,
                    isPresented: $showPermissionPrompt
                )
            }
            .sheet(isPresented: $showWidgetOnboarding) {
                WidgetOnboardingView()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowWidgetOnboarding"))) { _ in
                showWidgetOnboarding = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowWidgetCustomization"))) { _ in
                // Open preferences to Widgets tab
                selectedDestination = .settings
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
                    selectedDestination: $selectedDestination
                )
            }
        }
    }

    private func checkFirstLaunch() {
        if !hasSeenOnboarding {
            showOnboarding = true
        } else {
            // Show feature tour for first app launch after permissions are set up
            let hasSeenFeatureTour = UserDefaults.standard.bool(forKey: "hasSeenFeatureTour")
            if !hasSeenFeatureTour {
                // Delay showing tour to allow UI to render first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showFeatureTour = true
                }
            }
        }

        // Check permissions on app launch
        Task {
            await permissionManager.checkAllPermissions()
        }
    }
}

struct DetailView: View {
    let item: NavigationDestination
    let onPermissionNeeded: (PermissionManager.Feature) -> Void

    @State private var permissionManager = PermissionManager.shared
    @State private var checkedPermissions = false

    var body: some View {
        Group {
            if !checkedPermissions {
                ProgressView("Checking permissions...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .task {
                        await permissionManager.checkAllPermissions()
                        checkedPermissions = true
                    }
            } else {
                contentForItem
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var contentForItem: some View {
        switch item {
        case .dashboard:
            DashboardView()
        case .systemCleanup:
            MaintenanceView()
        case .appManager:
            if permissionManager.hasFullDiskAccess {
                AppInventoryView()
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
            if permissionManager.hasFullDiskAccess {
                DiskAnalysisView()
            } else {
                PermissionRequiredView(
                    icon: "externaldrive.fill",
                    title: "Full Disk Access Required",
                    description: "Disk Analysis needs Full Disk Access to scan all directories on your Mac.",
                    onGrantPermission: {
                        onPermissionNeeded(.diskScan)
                    }
                )
            }
        case .liveMonitoring:
            SystemStatusDashboard()
        case .menuBarWidgets:
            WidgetsPanelWrapper()
        case .developerTools:
            DeveloperToolsView()
        case .designSandbox:
            DesignSandboxView()
        case .settings:
            PreferencesView()
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
                .foregroundColor(TonicColors.warning)

            Text("Permission Required")
                .font(.title)
                .fontWeight(.semibold)

            Text(messageText)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            VStack(alignment: .leading, spacing: 12) {
                permissionRow(TonicPermission.fullDiskAccess)
                permissionRow(TonicPermission.accessibility)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Button("Open System Settings") {
                    grantPermission()
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 500, height: 400)
    }

    private var messageText: String {
        switch feature {
        case .diskScan, .appManager:
            return "Tonic needs Full Disk Access to scan all files and applications on your Mac."
        case .smartScan:
            return "Smart Scan requires Full Disk Access to perform a comprehensive system scan."
        case .systemOptimization:
            return "System optimization requires the privileged helper tool to be installed."
        case .basicScan, nil:
            return "Tonic needs additional permissions to function properly."
        }
    }

    private func permissionRow(_ permission: TonicPermission) -> some View {
        let status = permissionManager.permissionStatuses[permission] ?? .notDetermined

        return HStack {
            Image(systemName: permission.icon)
                .foregroundColor(status == .authorized ? .green : TonicColors.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(permission.rawValue)
                    .font(.subheadline)
                Text(permission.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                if status == .authorized {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Granted")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("Required")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }

    private func grantPermission() {
        // Open Full Disk Access in System Settings
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
                .foregroundColor(TonicColors.warning)

            Text(title)
                .font(.title)
                .fontWeight(.semibold)

            Text(description)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button("Grant Permission") {
                onGrantPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("You can also grant this permission later in System Settings > Privacy & Security > Full Disk Access")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 350)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Views that use SystemCleanupView

struct AppManagerView: View {
    var body: some View {
        AppInventoryView()
    }
}

struct MonitoringView: View {
    var body: some View {
        SystemStatusDashboard()
    }
}

struct DeveloperToolsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Developer Tools")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Clean up development artifacts and project files.")
                .foregroundColor(.secondary)

            // Add project artifact cleanup options
            VStack(alignment: .leading, spacing: 12) {
                Text("Supported Tools")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                toolRow("Node.js", icon: "shippingbox.fill")
                toolRow("Python", icon: "python")
                toolRow("Docker", icon: "shippingbox.fill")
                toolRow("Xcode", icon: "xcodes")
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
        }
        .padding()
    }

    private func toolRow(_ name: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(name)
                .font(.body)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Widgets Panel Wrapper
// Note: WidgetsPanelView is now defined in WidgetsPanelView.swift
// This wrapper handles onboarding before showing the main panel

struct WidgetsPanelWrapper: View {
    @State private var showWidgetOnboarding = false

    var body: some View {
        Group {
            // Content
            if WidgetPreferences.shared.hasCompletedOnboarding {
                // Use the working widget customization view
                // WidgetsPanelView in WidgetsPanelView.swift shows the new Stats Master-parity UI
                // but still needs integration work, so we use WidgetCustomizationView for now
                WidgetCustomizationView()
            } else {
                widgetOnboardingPrompt
            }
        }
        .sheet(isPresented: $showWidgetOnboarding) {
            WidgetOnboardingView()
        }
    }

    private var widgetOnboardingPrompt: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 60))
                .foregroundStyle(.linearGradient(
                    colors: [TonicColors.accent, TonicColors.pro],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            VStack(spacing: 12) {
                Text("Menu Bar Widgets")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("Monitor your system at a glance with customizable widgets")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "8E8E93"))
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 16) {
                featureRow("cpu.fill", "CPU & Memory", "Real-time system resource monitoring")
                featureRow("internaldrive.fill", "Disk", "Track disk usage and activity")
                featureRow("wifi", "Network", "Monitor network connections and speed")
                featureRow("cloud.sun.fill", "Weather", "Current conditions and forecasts")
            }
            .padding()
            .background(Color(hex: "1C1C1E"))
            .cornerRadius(12)

            Button {
                showWidgetOnboarding = true
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(TonicColors.accent)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "0D0E11"))
    }

    private func featureRow(_ icon: String, _ title: String, _ description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(TonicColors.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(Color(hex: "8E8E93"))
            }

            Spacer()
        }
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

    private let allDestinations = NavigationDestination.allCases

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
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(DesignTokens.Colors.textSecondary)

                    TextField("Search screens...", text: $searchText)
                        .font(DesignTokens.Typography.body)
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
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                        .accessibilityHint("Clears the search field")
                    }
                }
                .padding(DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.backgroundSecondary)

                Divider()

                // Results list
                ScrollViewReader { scrollProxy in
                    List(selection: $selectedIndex) {
                        ForEach(Array(filteredDestinations.enumerated()), id: \.offset) { index, destination in
                            HStack(spacing: DesignTokens.Spacing.sm) {
                                Image(systemName: destination.systemImage)
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(width: 20)
                                    .foregroundColor(DesignTokens.Colors.textSecondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(destination.displayName)
                                        .font(DesignTokens.Typography.body)
                                        .foregroundColor(DesignTokens.Colors.textPrimary)

                                    Text(destination.rawValue)
                                        .font(DesignTokens.Typography.caption)
                                        .foregroundColor(DesignTokens.Colors.textTertiary)
                                }

                                Spacer()

                                if index == selectedIndex {
                                    Text("↵")
                                        .font(.caption)
                                        .foregroundColor(DesignTokens.Colors.textSecondary)
                                }
                            }
                            .tag(index)
                            .contentShape(Rectangle())
                            .accessibilityLabel("\(destination.displayName), \(destination.rawValue)")
                            .accessibilityHint(index == selectedIndex ? "Currently selected. Press enter to navigate" : "Press enter to navigate")
                            .onTapGesture {
                                selectedIndex = index
                                navigateToSelected()
                            }
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: selectedIndex) { oldValue, newValue in
                        scrollProxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
            .frame(width: 500, height: 450)
            .background(DesignTokens.Colors.background)
            .cornerRadius(DesignTokens.CornerRadius.large)
            .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 6)
            .onAppear {
                isSearchFocused = true
                selectedIndex = 0
            }
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
