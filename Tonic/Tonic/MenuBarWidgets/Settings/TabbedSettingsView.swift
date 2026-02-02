//
//  TabbedSettingsView.swift
//  Tonic
//
//  Stats Master-style tabbed settings container
//  540×480 layout with segmented tab switcher
//  Task ID: fn-8-v3b.14
//

import SwiftUI

// MARK: - Settings Tab

/// Settings tab identifiers
public enum SettingsTab: String, CaseIterable, Identifiable {
    case module = "Module"
    case widgets = "Widgets"
    case popup = "Popup"
    case notifications = "Notifications"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .module: return "slider.horizontal.3"
        case .widgets: return "square.grid.3x3"
        case .popup: return "rectangle.on.rectangle"
        case .notifications: return "bell"
        }
    }
}

// MARK: - Tabbed Settings View

/// Stats Master-style tabbed settings container with:
/// - Segmented tab switcher (Module, Widgets, Popup, Notifications)
/// - 540×480 fixed size content area
/// - Tab state persistence
/// - Standardized spacing and typography
public struct TabbedSettingsView: View {

    // MARK: - Properties

    @State private var selectedTab: SettingsTab = .module
    @AppStorage("tonic.settings.selectedTab") private var savedTab: String = SettingsTab.module.rawValue

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header with title
            headerView

            Divider()

            // Tab switcher
            tabSwitcher

            Divider()

            // Tab content
            tabContent
        }
        .frame(width: 540, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            loadSavedTab()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "gearshape.fill")
                .font(.title3)
                .foregroundColor(DesignTokens.Colors.accent)

            Text("Settings")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Spacer()
        }
        .padding(DesignTokens.Spacing.md)
    }

    // MARK: - Tab Switcher

    private var tabSwitcher: some View {
        Picker("", selection: $selectedTab) {
            ForEach(SettingsTab.allCases) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(DesignTokens.Spacing.md)
        .onChange(of: selectedTab) { _, newTab in
            saveTab(newTab)
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case .module:
                ModuleSettingsView()
            case .widgets:
                WidgetsSettingsView()
            case .popup:
                PopupSettingsView()
            case .notifications:
                NotificationsSettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - State Management

    private func loadSavedTab() {
        if let tab = SettingsTab(rawValue: savedTab) {
            selectedTab = tab
        }
    }

    private func saveTab(_ tab: SettingsTab) {
        savedTab = tab.rawValue
    }
}

// MARK: - Module Settings View (Imported from ModuleSettingsView.swift)

/// Reimplemented in ModuleSettingsView.swift (fn-8-v3b.15)
/// This file now imports the full implementation

// MARK: - Widgets Settings View

/// Reuses existing WidgetsPanelView content
public struct WidgetsSettingsView: View {
    public init() {}

    public var body: some View {
        // Use the existing WidgetsPanelView
        WidgetsPanelView()
    }
}

// MARK: - Popup Settings View (Imported from PopupSettingsView.swift)

/// Reimplemented in PopupSettingsView.swift (fn-8-v3b.16)
/// This file now imports the full implementation

// MARK: - Notifications Settings View

/// Notification threshold settings
public struct NotificationsSettingsView: View {
    @State private var notificationsEnabled = true
    @State private var respectDND = true
    @State private var minimumInterval = 5

    private let notificationManager = NotificationManager.shared

    public init() {
        // Load initial values from NotificationManager
        _notificationsEnabled = State(initialValue: NotificationManager.shared.config.notificationsEnabled)
        _respectDND = State(initialValue: NotificationManager.shared.config.respectDoNotDisturb)
        _minimumInterval = State(initialValue: Int(NotificationManager.shared.config.minimumInterval / 60))
    }

    public var body: some View {
        Form {
            Section {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        notificationManager.toggleNotifications()
                    }

                Toggle("Respect Do Not Disturb", isOn: $respectDND)
                    .onChange(of: respectDND) { _, newValue in
                        notificationManager.toggleRespectDoNotDisturb()
                    }

                Button("Request Permission") {
                    notificationManager.requestPermission()
                }
                .disabled(notificationManager.hasPermission)

                if !notificationManager.hasPermission {
                    Text("Notification permission not granted")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            } header: {
                Text("General")
            }

            Section {
                Picker("Minimum Interval", selection: $minimumInterval) {
                    Text("1 minute").tag(1)
                    Text("5 minutes").tag(5)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                }
                .onChange(of: minimumInterval) { _, newValue in
                    notificationManager.setMinimumInterval(TimeInterval(newValue * 60))
                }

                Text("Notifications for the same type won't be shown more frequently than this interval.")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Button("Send Test Notification") {
                    notificationManager.sendTestNotification()
                }
            } header: {
                Text("Frequency")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Preview

#Preview("Tabbed Settings") {
    TabbedSettingsView()
}

#Preview("Module Settings") {
    ModuleSettingsView()
        .frame(width: 540, height: 480)
}

#Preview("Widgets Settings") {
    WidgetsSettingsView()
        .frame(width: 540, height: 480)
}

#Preview("Popup Settings") {
    PopupSettingsView()
        .frame(width: 540, height: 480)
}

#Preview("Notifications Settings") {
    NotificationsSettingsView()
        .frame(width: 540, height: 480)
}
