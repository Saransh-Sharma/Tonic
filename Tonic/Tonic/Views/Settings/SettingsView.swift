//
//  SettingsView.swift
//  Tonic
//
//  Consolidated editorial Settings — one system for General, Widgets, Permissions,
//  Updates, and About. Absorbs the former menu-bar tabbed settings. Section rail +
//  panel content, driven by the preserved preference managers.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

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
    @State private var longTermEnabled = LongTermMetricsStore.shared.isEnabled
    @State private var retentionDays = LongTermMetricsStore.shared.retentionDays
    @State private var topShelf = TopShelfStore.shared
    @State private var topShelfCoordinator = TopShelfCoordinator.shared
    @State private var supportCategories = Set(SupportBundleCategory.allCases)
    @State private var supportPreview: SupportBundlePreview?
    @State private var supportMessage: String?
    @State private var showAmbientConfirmation = false
    #if !TONIC_STORE
    @State private var helper = TonicHelperClient.shared
    @State private var helperMessage: String?
    #endif
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
            longTermEnabled = LongTermMetricsStore.shared.isEnabled
            retentionDays = LongTermMetricsStore.shared.retentionDays
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
            ScrollView(showsIndicators: false) {
                VStack(spacing: TonicDS.Space.xxs) {
                    ForEach(SettingsSection.allCases) { s in railRow(s) }
                }
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
        let label = s == .modules ? "Widgets" : s.title
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
        case .topShelf: topShelfSection
        case .shortcuts: shortcutsSection
        case .maintenance: maintenanceSection
        case .notifications: notificationsSection
        case .permissions: permissionsSection
        case .licensing: licensingSection
        case .updates: updatesSection
        case .advanced: advancedSection
        case .support: supportSection
        case .about: aboutSection
        }
    }

    private var topShelfSection: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
            sectionTitle("Top Shelf", "Choose the contextual modules that appear on deliberate open")
            SettingsPanel(title: "Presentation") {
                TonicPreferenceRow(title: "Open Top Shelf",
                    description: "Shows cached content immediately, then refreshes enabled modules without blocking the panel.") {
                    PrimaryPill("Open Now") { topShelfCoordinator.deliberateOpen() }
                }
                TonicPreferenceRow(title: "Layout", description: "Adaptive chooses a calm capsule or expanded instrument panel.") {
                    Picker("Layout", selection: topShelfLayoutMode) {
                        ForEach(TopShelfLayoutMode.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }.labelsHidden().frame(width: 120)
                }
                TonicPreferenceRow(title: "Recommended ambient set",
                    description: topShelf.state.ambientPolicy.hasConfirmedRecommendedSet
                        ? "Enabled only for the independently selected ambient modules below."
                        : "Now Playing, next event, and actionable health warnings require one explicit confirmation.",
                    showsDivider: false) {
                    if topShelf.state.ambientPolicy.hasConfirmedRecommendedSet {
                        StatusChip("Confirmed", level: .success)
                    } else {
                        Button("Review…") { showAmbientConfirmation = true }.buttonStyle(.bordered)
                    }
                }
            }
            SettingsPanel(title: "Modules") {
                ForEach(Array(topShelfCoordinator.descriptors.enumerated()), id: \.element.id) { index, descriptor in
                    TonicPreferenceRow(title: descriptor.title,
                        description: topShelfModuleDescription(descriptor),
                        showsDivider: index < topShelfCoordinator.descriptors.count - 1) {
                        HStack(spacing: 8) {
                            if descriptor.kind == .calendar,
                               topShelf.state.enabledModuleIDs.contains(descriptor.id) == false {
                                Button("Allow…") {
                                    Task {
                                        if await topShelfCoordinator.requestCalendarAccess() {
                                            topShelf.setEnabled(true, moduleID: descriptor.id)
                                        }
                                    }
                                }.buttonStyle(.bordered)
                            }
                            Toggle("Enabled", isOn: topShelfEnabled(descriptor.id))
                                .labelsHidden().toggleStyle(.switch)
                            Button("Earlier", systemImage: "chevron.up") { moveTopShelfModule(descriptor.id, offset: -1) }
                                .labelStyle(.iconOnly).buttonStyle(.borderless)
                            Button("Later", systemImage: "chevron.down") { moveTopShelfModule(descriptor.id, offset: 1) }
                                .labelStyle(.iconOnly).buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .confirmationDialog("Enable recommended ambient modules?", isPresented: $showAmbientConfirmation) {
            Button("Enable Recommended Set") { topShelf.confirmRecommendedAmbientSet() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Top Shelf may appear without taking focus for Now Playing, your next Calendar event, or an actionable health warning. Calendar still asks for access contextually. Clipboard and every other module remain excluded.")
        }
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
            sectionTitle("Support", "Preview and export diagnostics without automatic upload")
            SettingsPanel(title: "Bundle contents") {
                ForEach(Array(SupportBundleCategory.allCases.enumerated()), id: \.element) { index, category in
                    TonicToggleRow(title: supportCategoryTitle(category),
                        description: supportCategoryDescription(category),
                        showsDivider: index < SupportBundleCategory.allCases.count - 1,
                        isOn: supportCategoryBinding(category))
                }
            }
            SettingsPanel(title: "Privacy review") {
                TonicPreferenceRow(title: "Always excluded",
                    description: "Clipboard and Calendar content, notes, file names, secrets, script commands and output, captures, foreign menu text, and raw Space identifiers.") {
                    StatusChip("Local only", level: .success)
                }
                if let supportPreview {
                    TonicPreferenceRow(title: "Preview ready",
                        description: supportPreview.categories.sorted { $0.key.rawValue < $1.key.rawValue }
                            .map { "\(supportCategoryTitle($0.key)): \($0.value)" }.joined(separator: " · ")) {
                        StatusChip("Reviewed", level: .info)
                    }
                }
                if let supportMessage {
                    TonicPreferenceRow(title: "Export status", description: supportMessage) { EmptyView() }
                }
                TonicPreferenceRow(title: "Create support bundle",
                    description: "First preview category counts, then choose a local save location. Tonic never uploads it.",
                    showsDivider: false) {
                    HStack {
                        Button("Preview") { previewSupportBundle() }.buttonStyle(.bordered)
                        PrimaryPill("Export…", isDisabled: supportPreview == nil || supportCategories.isEmpty) {
                            exportSupportBundle()
                        }
                    }
                }
            }
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

            #if !TONIC_STORE
            helperPanel
            #else
            SettingsPanel(title: "Privileged maintenance") {
                TonicPreferenceRow(
                    title: "Report only",
                    description: "The App Store edition explains snapshot reclaim and fan controls but never installs a privileged helper.",
                    showsDivider: false
                ) { StatusChip("Store-safe", level: .info) }
            }
            #endif
        }
    }

    #if !TONIC_STORE
    private var helperPanel: some View {
        SettingsPanel(title: "Privileged helper") {
            TonicPreferenceRow(
                title: helperStatusTitle,
                description: "Version \(TonicHelperRequest.currentVersion) · Installed only when snapshot reclaim or fan control is first chosen."
            ) {
                StatusChip(helperStatusChip, level: helper.status == .enabled ? .success : .info)
            }
            if let helperMessage {
                TonicPreferenceRow(title: "Helper status", description: helperMessage) { EmptyView() }
            }
            TonicPreferenceRow(
                title: "Administrator approval",
                description: "macOS requires approval before the signed launch daemon can bootstrap.",
                showsDivider: false
            ) {
                HStack(spacing: 8) {
                    Button("Refresh") { helper.refreshStatus() }.buttonStyle(.bordered)
                    if helper.status == .notRegistered || helper.status == .notFound {
                        Button("Request Approval") {
                            do {
                                try helper.register()
                                helperMessage = "Registration requested. Approve Tonic in Login Items if macOS asks."
                            } catch {
                                helperMessage = error.localizedDescription
                            }
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button("Remove") {
                            Task {
                                do {
                                    try await helper.unregister()
                                    helperMessage = "Privileged helper removed."
                                } catch {
                                    helperMessage = error.localizedDescription
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var helperStatusTitle: String {
        switch helper.status {
        case .enabled: return "Helper ready"
        case .requiresApproval: return "Approval required"
        case .notRegistered: return "Not installed"
        case .notFound: return "Embedded helper unavailable"
        @unknown default: return "Unknown helper state"
        }
    }

    private var helperStatusChip: String {
        switch helper.status {
        case .enabled: return "Ready"
        case .requiresApproval: return "Approve"
        case .notRegistered: return "On demand"
        case .notFound: return "Unavailable"
        @unknown default: return "Unknown"
        }
    }
    #endif

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
                TonicToggleRow(
                    title: "Long-term history",
                    description: "Stored only on this Mac (\(longTermHistoryStorageSize)). Powers the 24h, 7d, and 30d Monitor charts.",
                    isOn: longTermEnabledBinding
                )
                TonicPreferenceRow(title: "Metric history", description: "Local rolling history used by Monitor charts.") {
                    Picker("Retention", selection: retentionDaysBinding) {
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                    }
                    .labelsHidden()
                    .frame(width: 110)
                }
                TonicPreferenceRow(title: "Clear history",
                                   description: "Deletes every stored resource sample. Charts start over.",
                                   showsDivider: false) {
                    TextAction("Clear", color: TonicDS.Colors.textMuted) {
                        LongTermMetricsStore.shared.clearAll()
                        WidgetHistoryStore.shared.clearHistory()
                    }
                }
            }
        }
    }

    private var longTermEnabledBinding: Binding<Bool> {
        Binding(
            get: { longTermEnabled },
            set: {
                longTermEnabled = $0
                LongTermMetricsStore.shared.isEnabled = $0
            }
        )
    }

    private var retentionDaysBinding: Binding<Int> {
        Binding(
            get: { retentionDays },
            set: {
                retentionDays = $0
                LongTermMetricsStore.shared.retentionDays = $0
            }
        )
    }

    private var longTermHistoryStorageSize: String {
        ByteCountFormatter.string(
            fromByteCount: LongTermMetricsStore.shared.storageSizeBytes,
            countStyle: .file
        )
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

    private var appHotkeyActions: [HotkeyAction] { [.toggleConsole, .quickSearch, .toggleMenuBar, .topShelf] }

    private var windowHotkeyActions: [HotkeyAction] {
        WindowAction.allCases.map(HotkeyAction.window)
    }

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
            sectionTitle("Shortcuts", "Keyboard access to daily controls")

            SettingsPanel(title: "App") {
                ForEach(Array(appHotkeyActions.enumerated()), id: \.element) { index, action in
                    TonicPreferenceRow(title: action.title, description: action.subtitle,
                                       showsDivider: index < appHotkeyActions.count - 1) {
                        KeyboardShortcutRecorder(action: action)
                    }
                }
            }

            SettingsPanel(title: "Window Management") {
                TonicPreferenceRow(
                    title: "Rectangle-style defaults",
                    description: "Bind ⌃⌥ arrows, letters, and ⌃⌥⌘ display moves to every unassigned placement. Never overwrites a combo you set."
                ) {
                    HStack(spacing: TonicDS.Space.sm) {
                        TextAction("Enable Defaults") {
                            HotkeySettingsStore.shared.enableRecommendedWindowDefaults()
                            GlobalHotkeyManager.shared.applyAll()
                        }
                        TextAction("Clear All", color: TonicDS.Colors.textMuted) {
                            HotkeySettingsStore.shared.clearWindowShortcuts()
                            GlobalHotkeyManager.shared.applyAll()
                        }
                    }
                }
                ForEach(Array(windowHotkeyActions.enumerated()), id: \.element) { index, action in
                    TonicPreferenceRow(title: action.title, description: action.subtitle,
                                       showsDivider: index < windowHotkeyActions.count - 1) {
                        KeyboardShortcutRecorder(action: action)
                    }
                }
            }

            Text("Window shortcuts need Accessibility access to move windows. ⌘K is always reserved for All Tools.")
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
            sectionTitle("Edition", "Distribution and capabilities")
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
                TonicPreferenceRow(title: "Access", description: "Tonic 5 includes the complete feature set for everyone.", showsDivider: false) {
                    StatusChip("Full access", level: .success)
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

    private var topShelfLayoutMode: Binding<TopShelfLayoutMode> {
        Binding(
            get: { topShelf.state.layout.mode },
            set: { value in topShelf.update { $0.layout.mode = value } }
        )
    }

    private func topShelfEnabled(_ moduleID: String) -> Binding<Bool> {
        Binding(
            get: { topShelf.state.enabledModuleIDs.contains(moduleID) },
            set: { enabled in topShelf.setEnabled(enabled, moduleID: moduleID) }
        )
    }

    private func moveTopShelfModule(_ moduleID: String, offset: Int) {
        var order = topShelf.state.layout.orderedModuleIDs
        let allIDs = topShelfCoordinator.descriptors.map(\.id)
        if order.isEmpty { order = allIDs }
        for id in allIDs where !order.contains(id) { order.append(id) }
        guard let index = order.firstIndex(of: moduleID) else { return }
        let destination = min(max(index + offset, 0), order.count - 1)
        guard destination != index else { return }
        order.move(fromOffsets: IndexSet(integer: index), toOffset: destination > index ? destination + 1 : destination)
        topShelf.update { $0.layout.orderedModuleIDs = order }
        TonicFeedback.alignment()
    }

    private func topShelfModuleDescription(_ descriptor: TopShelfModuleDescriptor) -> String {
        switch descriptor.kind {
        case .nowPlaying: String(localized: "Compatibility-gated playback context; never claims unsupported control.")
        case .calendar: String(localized: "Reads the next event only after contextual EventKit permission.")
        case .clipboard: String(localized: "Reads text only after a deliberate open and never persists it.")
        case .weather: String(localized: "Uses the existing Tonic weather provider and refresh policy.")
        case .systemHealth: String(localized: "Uses existing live and long-term metric services without duplicate polling.")
        case .recommendations: String(localized: "Evidence-backed Recovery, monitoring, update, and permission suggestions.")
        case .timers: String(localized: "Local timers stored with your Top Shelf layout.")
        case .quickNotes: String(localized: "Short local notes; note content is excluded from support bundles.")
        case .files: String(localized: "User-selected file actions with no background file history.")
        case .shortcuts: String(localized: "Reviewed Apple Shortcut launchers.")
        case .provider: String(localized: "Cards supplied by installed, reviewed data providers.")
        }
    }

    private func supportCategoryBinding(_ category: SupportBundleCategory) -> Binding<Bool> {
        Binding(
            get: { supportCategories.contains(category) },
            set: { included in
                if included { supportCategories.insert(category) }
                else { supportCategories.remove(category) }
                supportPreview = nil
            }
        )
    }

    private func supportCategoryTitle(_ category: SupportBundleCategory) -> String {
        switch category {
        case .application: String(localized: "App and OS")
        case .capabilities: String(localized: "Capability state")
        case .receipts: String(localized: "Redacted action receipts")
        case .helper: String(localized: "Helper status")
        case .providers: String(localized: "Provider health")
        case .compatibility: String(localized: "Compatibility decisions")
        case .logs: String(localized: "Bounded recent logs")
        }
    }

    private func supportCategoryDescription(_ category: SupportBundleCategory) -> String {
        switch category {
        case .application: String(localized: "Version, edition, macOS version, and architecture.")
        case .capabilities: String(localized: "Whether a feature is available; never feature-use analytics.")
        case .receipts: String(localized: "Results and errors with paths, URLs, and sensitive arguments redacted.")
        case .helper: String(localized: "Registration and protocol status without privileged request payloads.")
        case .providers: String(localized: "Provider identity, release, and health without secrets or payloads.")
        case .compatibility: String(localized: "Local allow/deny decisions without raw private identifiers.")
        case .logs: String(localized: "At most 200 local log lines after deterministic redaction.")
        }
    }

    private func makeSupportBuilder() -> SupportBundleBuilder {
        SupportBundleBuilder(
            receipts: {
                await MainActor.run {
                    ActionReceiptStore.shared.receipts.map { receipt in
                        ["tool": receipt.tool.rawValue, "title": receipt.title,
                         "detail": receipt.detail, "status": receipt.status.rawValue,
                         "completed": receipt.completedAt.ISO8601Format()]
                    }
                }
            },
            providers: {
                let manifests = await TonicProviderRegistry.shared.manifests()
                return manifests.map { ["id": $0.id, "name": $0.displayName,
                                        "version": $0.providerVersion] }
            },
            helper: {
                #if TONIC_STORE
                return ["implementation": "physically excluded", "edition": "store"]
                #else
                return await MainActor.run {
                    let client = TonicHelperClient.shared
                    return ["implementation": "direct-only",
                            "registration": String(describing: client.status),
                            "fanSession": client.hasActiveFanSession ? "active" : "inactive",
                            "lastError": client.lastError ?? "none"]
                }
                #endif
            },
            compatibility: {
                #if TONIC_STORE
                return TonicPrivateCapability.allCases.map {
                    ["capability": $0.rawValue, "decision": "excluded from Store edition"]
                }
                #else
                var rows: [[String: String]] = []
                for capability in TonicPrivateCapability.allCases {
                    let decision = await TonicCompatibilityAuthority.shared.decision(for: capability)
                    switch decision {
                    case .enabled(let ruleID):
                        rows.append(["capability": capability.rawValue, "decision": "enabled",
                                     "rule": ruleID])
                    case .disabled(let reason):
                        rows.append(["capability": capability.rawValue, "decision": "disabled",
                                     "reason": reason])
                    }
                }
                return rows
                #endif
            }
        )
    }

    private func previewSupportBundle() {
        let selected = supportCategories
        Task {
            let preview = await makeSupportBuilder().preview(categories: selected)
            await MainActor.run {
                supportPreview = preview
                supportMessage = "Review complete. Nothing has been written or uploaded."
            }
        }
    }

    private func exportSupportBundle() {
        let panel = NSSavePanel()
        panel.title = "Export Tonic Support Bundle"
        panel.nameFieldStringValue = "Tonic-Support-\(Date().ISO8601Format().prefix(10)).zip"
        panel.allowedContentTypes = [.zip]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let selected = supportCategories
        Task {
            do {
                let builder = makeSupportBuilder()
                let payload = await builder.build(categories: selected)
                try await builder.writeArchive(payload, to: url)
                await MainActor.run { supportMessage = "Saved locally to the location you selected." }
            } catch {
                await MainActor.run { supportMessage = "Export failed: \(error.localizedDescription)" }
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
