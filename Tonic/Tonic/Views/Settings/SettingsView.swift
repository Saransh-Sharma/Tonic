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
    @State private var appearance = AppearancePreferences.shared
    @State private var permissions = PermissionManager.shared
    @State private var scheduler = MaintenanceScheduler.shared
    @State private var powerUser = UserDefaults.standard.bool(forKey: TonicUserDefaultsKey.powerUserModeEnabled)
    /// Bumped when a Labs flag changes so the toggles re-read FeatureFlags.
    @State private var labsRevision = 0
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
        .background(TonicDS.Colors.canvas)
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
        .background(TonicDS.Colors.canvasSoft)
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
        case .maintenance: maintenanceSection
        case .permissions: permissionsSection
        case .updates: updatesSection
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
            sectionTitle("General", "Customize how Tonic looks and behaves")

            SettingsPanel(title: "Appearance") {
                TonicPreferenceRow(title: "Theme", description: "Match the system or force light/dark.") {
                    HStack(spacing: TonicDS.Space.xs) {
                        ForEach(ThemeMode.allCases) { mode in
                            FilterPill(title: mode.rawValue, isActive: appearance.themeMode == mode) {
                                appearance.setThemeMode(mode)
                                NotificationCenter.default.post(name: NSNotification.Name("TonicThemeDidChange"), object: nil)
                            }
                        }
                    }
                }
                TonicToggleRow(title: "Reduce transparency", description: "Replace transparency with solid colors.",
                               isOn: Binding(get: { appearance.reduceTransparency }, set: { appearance.setReduceTransparency($0) }))
                TonicToggleRow(title: "Reduce motion", description: "Minimize animation effects.", showsDivider: false,
                               isOn: Binding(get: { appearance.reduceMotion }, set: { appearance.setReduceMotion($0) }))
            }

            SettingsPanel(title: "Advanced") {
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
            sectionTitle("Permissions", "System access Tonic needs to work")
            SettingsPanel(title: "Access") {
                ForEach(Array(TonicPermission.allCases.enumerated()), id: \.element) { idx, perm in
                    permissionRow(perm, showsDivider: idx < TonicPermission.allCases.count - 1)
                }
            }
        }
    }

    private func permissionRow(_ perm: TonicPermission, showsDivider: Bool) -> some View {
        let status = permissions.permissionStatuses[perm] ?? .notDetermined
        let granted = status == .authorized
        // Symmetric rows: every permission states its status; only ungranted ones
        // add the action. No row looks like it still needs attention once granted.
        return TonicPreferenceRow(title: perm.rawValue, description: perm.description, showsDivider: showsDivider) {
            HStack(spacing: TonicDS.Space.sm) {
                if granted {
                    StatusChip("Granted", level: .success)
                } else {
                    StatusChip("Required", level: .warning)
                    Button {
                        if perm == .fullDiskAccess { _ = permissions.requestFullDiskAccess() }
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
