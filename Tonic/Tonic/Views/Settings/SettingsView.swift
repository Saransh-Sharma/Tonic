//
//  SettingsView.swift
//  Tonic
//
//  Consolidated editorial Settings — one system for General, Widgets, Permissions,
//  Updates, and About. Absorbs the former menu-bar tabbed settings. Section rail +
//  panel content, driven by the preserved preference managers.
//

import SwiftUI

struct SettingsView: View {
    var initialSection: SettingsSection = .general

    @State private var section: SettingsSection = .general
    @State private var didInit = false
    @State private var permissions = PermissionManager.shared
    @State private var accessBroker = AccessBroker.shared
    @State private var scheduler = MaintenanceScheduler.shared
    @State private var appearance = AppearancePreferences.shared
    @State private var powerUser = UserDefaults.standard.bool(forKey: TonicUserDefaultsKey.powerUserModeEnabled)
    /// Bumped when a Labs flag changes so the toggles re-read FeatureFlags.
    @State private var labsRevision = 0
    @AppStorage("tonic.general.compactDensity") private var compactDensity = false
    @AppStorage("tonic.general.metricUnits") private var metricUnits = true
    @AppStorage("tonic.general.retentionDays") private var retentionDays = 7
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            rail
            TonicHairline().frame(width: 1)
            ScrollView(showsIndicators: false) {
                content
                    .frame(maxWidth: 640, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tonicScreenHPadding()
                    .padding(.vertical, TonicDS.Space.xxxl)
                    .id(section)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(reduceMotion ? nil : TonicDS.Motion.present, value: section)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tonicCanvas()
        .onAppear {
            if !didInit { section = initialSection; didInit = true }
            Task { await permissions.checkAllPermissions() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsSection)) { note in
            if let raw = note.userInfo?[SettingsDeepLinkUserInfoKey.section] as? String,
               let s = SettingsSection(rawValue: raw) { section = s }
        }
    }

    // MARK: - Rail

    private var rail: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.xxs) {
            Text("Settings").tonicType(.featureHeading).foregroundStyle(TonicDS.Colors.textPrimary)
                .padding(.horizontal, TonicDS.Space.sm)
                .padding(.bottom, TonicDS.Space.sm)
            ForEach(SettingsSection.allCases) { s in
                railRow(s)
            }
            Spacer()
            Text("Version \(Self.appVersion)").tonicType(.monoLabel).foregroundStyle(TonicDS.Colors.textMuted)
                .padding(.horizontal, TonicDS.Space.sm)
        }
        .padding(TonicDS.Space.md)
        .frame(width: 220, alignment: .topLeading)
        .tonicCanvas(flatFill: TonicDS.Colors.canvasSoft)
    }

    private func railRow(_ s: SettingsSection) -> some View {
        let isSel = s == section
        let label = s == .modules ? "Widgets" : s.rawValue
        return Button { section = s } label: {
            HStack(spacing: TonicDS.Space.sm) {
                Image(systemName: s.icon).font(.system(size: 13)).frame(width: 18)
                    .foregroundStyle(isSel ? TonicDS.Colors.textPrimary : TonicDS.Colors.textMuted)
                Text(label).tonicType(.body)
                    .foregroundStyle(isSel ? TonicDS.Colors.textPrimary : TonicDS.Colors.textMuted)
                Spacer()
            }
            .padding(.horizontal, TonicDS.Space.sm)
            .frame(height: TonicDS.Layout.minControlTarget)
            .background {
                if isSel {
                    RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous)
                        .fill(TonicDS.Colors.surface)
                        .overlay(RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous)
                            .strokeBorder(TonicDS.Colors.hairline, lineWidth: 1))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tonicFocusableControl(radius: TonicDS.Radius.sm)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSel ? .isSelected : AccessibilityTraits())
        .tonicPointerCursor()
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch section {
        case .general: generalSection
        case .modules: widgetsSection
        case .shortcuts: shortcutsSection
        case .maintenance: maintenanceSection
        case .notifications: notificationsSection
        case .permissions: permissionsSection
        case .licensing: licensingSection
        case .updates: updatesSection
        case .advanced: advancedSection
        case .about: aboutSection
        }
    }

    private var maintenanceSection: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
            sectionTitle("Maintenance", "Let Tonic clean safe system junk on a schedule")

            SettingsPanel(title: "Schedule") {
                TonicPreferenceRow(
                    title: "Automatic maintenance",
                    description: "Cleans caches, logs, and temp files that Smart Scan marks safe."
                ) {
                    HStack(spacing: TonicDS.Space.xs) {
                        ForEach(MaintenanceCadence.allCases) { cadence in
                            FilterPill(title: cadence.displayName,
                                       isActive: scheduler.cadence == cadence) {
                                scheduler.cadence = cadence
                            }
                        }
                    }
                }
                TonicToggleRow(
                    title: "Respect quiet hours",
                    description: "Defers scheduled runs between 22:00 and 08:00.",
                    isOn: Binding(get: { scheduler.respectQuietHours },
                                  set: { scheduler.respectQuietHours = $0 })
                )
                TonicToggleRow(
                    title: "Bundle alerts into a digest",
                    description: "Threshold alerts collect into one periodic summary. Maintenance and update notifications still arrive individually.",
                    isOn: Binding(get: { NotificationManager.shared.digestEnabled },
                                  set: { NotificationManager.shared.digestEnabled = $0 })
                )
                TonicPreferenceRow(
                    title: "Personal files",
                    description: "Downloads, backups, and mail attachments are never cleaned automatically — only through the review sheet.",
                    showsDivider: false
                ) {
                    StatusChip("Never automatic", level: .info)
                }
            }

            SettingsPanel(title: "Last run") {
                TonicPreferenceRow(
                    title: scheduler.lastRunDate.map { Self.maintenanceDateFormatter.string(from: $0) } ?? "Never run",
                    description: scheduler.lastRunSummary ?? "Scheduled maintenance hasn't run yet.",
                    showsDivider: false
                ) {
                    if scheduler.isRunning {
                        HStack(spacing: TonicDS.Space.xs) {
                            ProgressView().controlSize(.small)
                            Text("Running…").tonicType(.caption)
                                .foregroundStyle(TonicDS.Colors.textMuted)
                        }
                    } else {
                        Button {
                            Task { await scheduler.runNow() }
                        } label: {
                            Text("Run Now").tonicType(.button)
                                .foregroundStyle(TonicDS.Colors.linkBlue)
                        }
                        .buttonStyle(.plain)
                        .tonicPointerCursor()
                    }
                }
            }
        }
    }

    private static let maintenanceDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
            sectionTitle("General", "Behavior, units, and local data")

            SettingsPanel(title: "Interface") {
                TonicPreferenceRow(title: "Appearance", description: "Follow macOS or force a fixed appearance.") {
                    HStack(spacing: TonicDS.Space.xs) {
                        ForEach(ThemeMode.allCases) { mode in
                            FilterPill(title: mode.rawValue,
                                       isActive: appearance.themeMode == mode) {
                                appearance.setThemeMode(mode)
                            }
                        }
                    }
                }
                TonicPreferenceRow(title: "Window glass",
                                   description: appearance.glassIntensity.caption) {
                    HStack(spacing: TonicDS.Space.xs) {
                        ForEach(GlassIntensity.allCases) { intensity in
                            FilterPill(title: intensity.rawValue,
                                       isActive: appearance.glassIntensity == intensity) {
                                appearance.setGlassIntensity(intensity)
                            }
                        }
                    }
                }
                TonicToggleRow(title: "Reduce transparency",
                               description: "Render solid surfaces everywhere, matching the macOS accessibility setting.",
                               isOn: Binding(get: { appearance.reduceTransparency },
                                             set: { appearance.setReduceTransparency($0) }))
                TonicToggleRow(title: "Compact data density", description: "Use tighter rows in tables and inspectors.", showsDivider: false,
                               isOn: $compactDensity)
            }

            SettingsPanel(title: "Measurements") {
                TonicToggleRow(title: "Metric units", description: "Use GB, °C, and metric network units.",
                               isOn: $metricUnits)
                TonicPreferenceRow(title: "Metric history", description: "Local rolling history used by Monitor charts.", showsDivider: false) {
                    Picker("Retention", selection: $retentionDays) {
                        Text("1 day").tag(1)
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                    }
                    .labelsHidden()
                    .frame(width: 110)
                }
            }
        }
    }

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
            sectionTitle("Advanced", "Expert controls and diagnostics")

            SettingsPanel(title: "Expert controls") {
                TonicToggleRow(title: "Power User mode",
                               description: "Reveals developer caches, path-level detail, and advanced scan context.",
                               showsDivider: false,
                               isOn: Binding(get: { powerUser }, set: {
                                   powerUser = $0
                                   UserDefaults.standard.set($0, forKey: TonicUserDefaultsKey.powerUserModeEnabled)
                               }))
            }

            SettingsPanel(title: "Labs") {
                labsToggle(.activity,
                           description: "Full-window live monitoring with history and a process explorer.",
                           showsDivider: true)
                labsToggle(.storageHub,
                           description: "Deep storage exploration with treemap and guided cleanup.",
                           showsDivider: false)
            }
        }
    }

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
            sectionTitle("Shortcuts", "Keyboard access to daily controls")
            SettingsPanel(title: "Global") {
                ForEach(Array(HotkeyAction.allCases.enumerated()), id: \.element.rawValue) { index, action in
                    TonicPreferenceRow(title: action.title, description: action.subtitle, showsDivider: index < HotkeyAction.allCases.count - 1) {
                        Text(HotkeySettingsStore.shared.spec(for: action)?.displayString ?? "Not set")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(TonicDS.Colors.textMuted)
                    }
                }
            }
            Text("Record or change menu-bar shortcuts from Organize → Menu Bar. ⌘K is always reserved for All Tools.")
                .font(.system(size: 12))
                .foregroundStyle(TonicDS.Colors.textMuted)
        }
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
            sectionTitle("Notifications", "Alerts are quiet until you configure them")
            SettingsPanel(title: "Delivery") {
                TonicPreferenceRow(title: "System permission", description: "Required only for alerts and automation run notices.") {
                    let granted = permissions.permissionStatuses[.notifications] == .authorized
                    if granted {
                        StatusChip("Granted", level: .success)
                    } else {
                        Button("Allow") { NotificationManager.shared.requestPermission() }
                            .buttonStyle(.borderless)
                    }
                }
                TonicToggleRow(
                    title: "Bundle threshold alerts",
                    description: "Collect non-urgent metric alerts into a digest.",
                    showsDivider: false,
                    isOn: Binding(get: { NotificationManager.shared.digestEnabled }, set: { NotificationManager.shared.digestEnabled = $0 })
                )
            }
        }
    }

    private var licensingSection: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
            sectionTitle("Licensing", "Your edition and verified entitlement")
            SettingsPanel(title: "Installed product") {
                TonicPreferenceRow(
                    title: DistributionEdition.current == .direct ? "Tonic Direct" : "Tonic for the Mac App Store",
                    description: DistributionEdition.current == .direct
                        ? "Includes direct updates and supported capabilities outside App Sandbox."
                        : "Sandboxed edition with scoped file access and App Store updates.",
                    showsDivider: true
                ) {
                    StatusChip(DistributionEdition.current == .direct ? "Direct" : "Store", level: .info)
                }
                TonicPreferenceRow(title: "License", description: "Purchasing controls appear only after a signed entitlement is available.", showsDivider: false) {
                    StatusChip(LicenseManager.shared.currentTier.rawValue, level: .info)
                }
            }
        }
    }

    /// A Labs feature toggle. Changing it updates the sidebar on next launch
    /// of the destination list, so we also nudge navigation to refresh.
    private func labsToggle(_ feature: WIPFeature, description: String, showsDivider: Bool) -> some View {
        TonicToggleRow(
            title: feature.displayName,
            description: description,
            showsDivider: showsDivider,
            isOn: Binding(
                get: { FeatureFlags.isEnabled(feature) },
                set: { enabled in
                    FeatureFlags.set(feature, enabled: enabled)
                    labsRevision += 1
                }
            )
        )
    }

    private var widgetsSection: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
            sectionTitle("Widgets", "Configure your menu-bar widgets")
            WidgetsPanelView()
                .frame(minHeight: 480)
        }
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
            sectionTitle("Access", "Purpose, current state, and recovery in one place")
            SettingsPanel(title: "Capabilities") {
                ForEach(Array(TonicPermission.allCases.enumerated()), id: \.element) { idx, perm in
                    permissionRow(perm, showsDivider: idx < TonicPermission.allCases.count - 1)
                }
            }
            if BuildCapabilities.current.requiresScopeAccess {
                SettingsPanel(title: "Authorized locations") {
                    if accessBroker.scopes.isEmpty {
                        TonicPreferenceRow(title: "No locations authorized", description: "Care continues with basic system information until you choose a folder or volume.", showsDivider: false) {
                            Button("Add") { _ = accessBroker.addScopeUsingOpenPanel() }
                                .buttonStyle(.borderless)
                        }
                    } else {
                        ForEach(Array(accessBroker.scopes.enumerated()), id: \.element.id) { index, scope in
                            TonicPreferenceRow(title: scope.displayName, description: scope.rootPath, showsDivider: index < accessBroker.scopes.count - 1) {
                                Button("Remove") { accessBroker.removeScope(id: scope.id) }
                                    .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }
        }
    }

    private func permissionRow(_ perm: TonicPermission, showsDivider: Bool) -> some View {
        let status = permissions.permissionStatuses[perm] ?? .notDetermined
        let granted = status == .authorized
        // Symmetric rows: every permission states its status; only ungranted ones
        // add the action. No row looks like it still needs attention once granted.
        let purpose: String
        switch perm {
        case .fullDiskAccess: purpose = BuildCapabilities.current.requiresScopeAccess ? "Inspect only the folders and volumes you choose." : "Build complete storage and app evidence."
        case .accessibility: purpose = "Arrange windows and manage supported menu-bar items."
        case .notifications: purpose = "Deliver alerts and automation run notices you configure."
        }
        return TonicPreferenceRow(title: perm.rawValue, description: "\(purpose) Checked this session.", showsDivider: showsDivider) {
            HStack(spacing: TonicDS.Space.sm) {
                if granted {
                    StatusChip("Granted", level: .success)
                } else {
                    StatusChip("Required", level: .warning)
                    Button {
                        switch perm {
                        case .fullDiskAccess: _ = permissions.requestFullDiskAccess()
                        case .accessibility: _ = permissions.requestAccessibility()
                        case .notifications: NotificationManager.shared.requestPermission()
                        }
                        Task { await permissions.checkAllPermissions() }
                    } label: {
                        Text("Grant").tonicType(.button).foregroundStyle(TonicDS.Colors.linkBlue)
                    }
                    .buttonStyle(.plain).tonicPointerCursor()
                    .accessibilityLabel("Grant \(perm.rawValue)")
                }
            }
        }
    }

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
            sectionTitle("Updates", "Keep Tonic up to date")
            SettingsPanel {
                TonicPreferenceRow(title: "Current version", description: "Tonic \(Self.appVersion) (\(Self.appBuild))", showsDivider: true) {
                    EmptyView()
                }
                #if TONIC_STORE
                TonicPreferenceRow(title: "Updates", description: "Updates are delivered through the Mac App Store.", showsDivider: false) {
                    StatusChip("App Store", color: TonicDS.Colors.statusInfo)
                }
                #else
                TonicPreferenceRow(title: "Check for updates", description: "Direct build — updates download in-app via Sparkle.", showsDivider: false) {
                    PrimaryPill("Check Now") { SparkleUpdater.shared.checkForUpdates() }
                }
                #endif
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
            sectionTitle("About", "Tonic — a calm command center for system health")
            SettingsPanel {
                TonicPreferenceRow(title: "Version", description: "\(Self.appVersion) (\(Self.appBuild))", showsDivider: true) { EmptyView() }
                TonicPreferenceRow(
                    title: "Local by design",
                    description: "Scans, cleanup previews, and live metrics stay on this Mac.",
                    showsDivider: true
                ) { EmptyView() }
                TonicPreferenceRow(title: "Built with", description: "SwiftUI · Native macOS", showsDivider: true) { EmptyView() }
                TonicPreferenceRow(title: "Links", description: "Documentation and issue tracker.", showsDivider: false) {
                    HStack(spacing: TonicDS.Space.md) {
                        TextAction("Website", color: TonicDS.Colors.linkBlue) {
                            if let url = URL(string: "https://github.com/Saransh-Sharma/PreTonic") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        TextAction("Report an issue", color: TonicDS.Colors.linkBlue) {
                            if let url = URL(string: "https://github.com/Saransh-Sharma/PreTonic/issues") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }
        }
    }

    private func sectionTitle(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.xxs) {
            Text(title).tonicType(.cardHeading).foregroundStyle(TonicDS.Colors.textPrimary)
            Text(subtitle).tonicType(.body).foregroundStyle(TonicDS.Colors.textMuted)
        }
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    static var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
