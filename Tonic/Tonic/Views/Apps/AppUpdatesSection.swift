//
//  AppUpdatesSection.swift
//  Tonic
//
//  The Updates tab of the Apps screen. Lists apps with newer versions, shows
//  where each update comes from (Sparkle / App Store / Homebrew), applies
//  updates with per-row progress, and streams Homebrew output into a console.
//
//  Editorial rules: mono for versions and timestamps, status color only on
//  state words, one PrimaryPill (Update All) — row actions stay text actions.
//

import SwiftUI
import AppKit

struct AppUpdatesSection: View {
    @ObservedObject var inventory: AppInventoryService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expandedConsoles: Set<String> = []
    @State private var showIgnored = false

    private var applier: AppUpdateApplier { .shared }
    private var preferences: UpdatePreferences { .shared }

    var body: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.md) {
            header
            preferencesRow
            checkErrors
            content
        }
    }

    // MARK: - Preferences

    /// Quiet one-line controls: auto-check cadence and update notifications.
    private var preferencesRow: some View {
        HStack(spacing: TonicDS.Space.sm) {
            MonoLabel("AUTO-CHECK")
            ForEach(UpdateCheckCadence.allCases) { cadence in
                FilterPill(title: cadence.displayName, isActive: preferences.cadence == cadence) {
                    preferences.cadence = cadence
                }
            }
            Spacer()
            TextAction(
                preferences.notifyOnUpdates ? "Notifications on" : "Notifications off",
                systemImage: preferences.notifyOnUpdates ? "bell" : "bell.slash",
                color: TonicDS.Colors.linkBlue
            ) {
                preferences.notifyOnUpdates.toggle()
            }
            .accessibilityHint("Toggle notifications when app updates are found")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: TonicDS.Space.md) {
            if inventory.isCheckingUpdates {
                ProgressView().controlSize(.small)
                MonoLabel("CHECKING…")
            } else if let checked = inventory.lastUpdateCheck {
                MonoLabel("LAST CHECKED \(Self.relative(checked))")
            } else {
                MonoLabel("NOT CHECKED YET")
            }

            TextAction("Check Now", color: TonicDS.Colors.linkBlue) {
                Task { await inventory.checkForUpdates() }
            }
            .disabled(inventory.isCheckingUpdates)

            Spacer()

            if inventory.pendingUpdates.count > 1 {
                PrimaryPill("Update All") { Task { await updateAll() } }
            }
        }
    }

    // MARK: - Errors

    @ViewBuilder
    private var checkErrors: some View {
        if !inventory.updateCheckErrors.isEmpty {
            let failedNames = inventory.updateCheckErrors
                .prefix(4)
                .map { $0.appName ?? $0.bundleIdentifier }
                .joined(separator: ", ")
            let more = inventory.updateCheckErrors.count > 4
                ? " and \(inventory.updateCheckErrors.count - 4) more" : ""
            TonicInlineNotice(
                message: "\(inventory.updateCheckErrors.count) app\(inventory.updateCheckErrors.count == 1 ? "" : "s") couldn't be checked (\(failedNames)\(more)). Check Now retries.",
                tone: .warning
            )
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if inventory.pendingUpdates.isEmpty && !inventory.isCheckingUpdates {
            TonicEmptyState(
                systemImage: "checkmark.seal",
                title: "Everything is current.",
                message: inventory.lastUpdateCheck != nil
                    ? "No newer versions were found for your apps."
                    : "Run a check to look for newer versions."
            )
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(inventory.pendingUpdates) { update in
                        updateRow(update)
                        TonicHairline()
                    }
                    ignoredSection
                }
                .padding(.bottom, 80)
            }
        }
    }

    // MARK: - Ignored

    /// Updates hidden by ignore/skip preferences, collapsed but recoverable —
    /// hiding them silently forever would be dishonest.
    @ViewBuilder
    private var ignoredSection: some View {
        if !inventory.ignoredUpdates.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                TextAction(
                    showIgnored
                        ? "Hide ignored (\(inventory.ignoredUpdates.count))"
                        : "Ignored (\(inventory.ignoredUpdates.count))",
                    color: TonicDS.Colors.textMuted
                ) {
                    showIgnored.toggle()
                }
                .padding(.horizontal, TonicDS.Space.md)
                .padding(.vertical, TonicDS.Space.sm)

                if showIgnored {
                    ForEach(inventory.ignoredUpdates) { update in
                        SystemListRow(
                            leading: {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: update.appPath.path))
                                    .resizable().frame(width: 22, height: 22)
                                    .opacity(0.5)
                            },
                            center: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(update.appName).tonicType(.body)
                                        .foregroundStyle(TonicDS.Colors.textMuted).lineLimit(1)
                                    Text(ignoredReason(for: update))
                                        .tonicType(.micro)
                                        .foregroundStyle(TonicDS.Colors.textMuted)
                                }
                            },
                            trailing: {
                                TextAction("Show again", color: TonicDS.Colors.linkBlue) {
                                    preferences.unignore(update.bundleIdentifier)
                                    preferences.clearSkippedVersion(for: update.bundleIdentifier)
                                    inventory.applyUpdatePreferences()
                                }
                            }
                        )
                        TonicHairline()
                    }
                }
            }
        }
    }

    private func ignoredReason(for update: AppUpdate) -> String {
        if preferences.isIgnored(update.bundleIdentifier) {
            return "All updates ignored"
        }
        return "Skipping version \(update.latestVersion)"
    }

    // MARK: - Rows

    @ViewBuilder
    private func updateRow(_ update: AppUpdate) -> some View {
        let state = applier.state(for: update.bundleIdentifier)
        let method = applier.method(for: update)

        VStack(alignment: .leading, spacing: 0) {
            SystemListRow(
                leading: {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: update.appPath.path))
                        .resizable().frame(width: 22, height: 22)
                },
                center: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(update.appName).tonicType(.body)
                            .foregroundStyle(TonicDS.Colors.textPrimary).lineLimit(1)
                        HStack(spacing: TonicDS.Space.xs) {
                            Text("\(update.currentVersion ?? "?") → \(update.latestVersion)")
                                .tonicType(.monoLabel)
                                .foregroundStyle(TonicDS.Colors.textMuted)
                                .contentTransition(.numericText())
                            if let notesURL = releaseNotesURL(for: update) {
                                TextAction("What's new", color: TonicDS.Colors.linkBlue) {
                                    NSWorkspace.shared.open(notesURL)
                                }
                            }
                        }
                    }
                },
                trailing: {
                    HStack(spacing: TonicDS.Space.md) {
                        StatusChip(update.source.displayName.uppercased(), color: TonicDS.Colors.statusInfo)
                        actionControl(for: update, state: state, method: method)
                    }
                },
                isSelected: false,
                reflowWhenCompact: true,
                onTap: {}
            )
            .help(method.explanation)
            .contextMenu {
                Button("Skip Version \(update.latestVersion)") {
                    preferences.skipVersion(update.latestVersion, for: update.bundleIdentifier)
                    inventory.applyUpdatePreferences()
                }
                Button("Ignore Updates for This App") {
                    preferences.ignore(update.bundleIdentifier)
                    inventory.applyUpdatePreferences()
                }
                Divider()
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([update.appPath])
                }
            }

            consolePanel(for: update)
            resultCaption(for: update, state: state)
        }
        .animation(reduceMotion ? nil : TonicDS.Motion.present, value: stateKey(state))
    }

    @ViewBuilder
    private func actionControl(for update: AppUpdate, state: UpdateApplyState, method: UpdateApplyMethod) -> some View {
        switch state {
        case .idle:
            TextAction(method.actionLabel, color: TonicDS.Colors.linkBlue) {
                Task { await applier.apply(update) }
            }
        case .running:
            HStack(spacing: TonicDS.Space.xs) {
                ProgressView().controlSize(.small)
                MonoLabel("WORKING")
            }
        case .succeeded:
            HStack(spacing: TonicDS.Space.xs) {
                StatusChip("DONE", color: TonicDS.Colors.statusSuccess)
                TextAction("Dismiss", color: TonicDS.Colors.textMuted) {
                    applier.reset(update.bundleIdentifier)
                }
            }
        case .failed:
            HStack(spacing: TonicDS.Space.xs) {
                StatusChip("FAILED", color: TonicDS.Colors.statusCritical)
                TextAction("Retry", color: TonicDS.Colors.linkBlue) {
                    applier.reset(update.bundleIdentifier)
                    Task { await applier.apply(update) }
                }
            }
        }
    }

    /// Streamed Homebrew output, rendered on the signature console surface.
    @ViewBuilder
    private func consolePanel(for update: AppUpdate) -> some View {
        let bundleId = update.bundleIdentifier
        if let lines = applier.consoleLines[bundleId], !lines.isEmpty {
            let isExpanded = expandedConsoles.contains(bundleId)
            VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                TextAction(isExpanded ? "Hide output" : "Show output (\(lines.count) lines)",
                           color: TonicDS.Colors.linkBlue) {
                    if isExpanded { expandedConsoles.remove(bundleId) }
                    else { expandedConsoles.insert(bundleId) }
                }
                if isExpanded {
                    MonitoringConsole {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(lines.suffix(12).enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .tonicType(.micro).monospaced()
                                    .foregroundStyle(TonicDS.Colors.onDarkMuted)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, TonicDS.Space.md)
            .padding(.bottom, TonicDS.Space.sm)
        }
    }

    @ViewBuilder
    private func resultCaption(for update: AppUpdate, state: UpdateApplyState) -> some View {
        switch state {
        case .succeeded(let message), .failed(let message):
            Text(message)
                .tonicType(.caption)
                .foregroundStyle(TonicDS.Colors.textMuted)
                .padding(.horizontal, TonicDS.Space.md)
                .padding(.bottom, TonicDS.Space.sm)
        case .running(let detail):
            if let detail {
                Text(detail)
                    .tonicType(.micro).monospaced()
                    .foregroundStyle(TonicDS.Colors.textMuted)
                    .lineLimit(1)
                    .padding(.horizontal, TonicDS.Space.md)
                    .padding(.bottom, TonicDS.Space.sm)
            }
        case .idle:
            EmptyView()
        }
    }

    // MARK: - Update All

    /// Applies every pending update. In-app mechanisms run sequentially; App
    /// Store items open Apple's Updates page once rather than N store pages.
    private func updateAll() async {
        var openedAppStore = false
        for update in inventory.pendingUpdates {
            switch applier.method(for: update) {
            case .openAppStore:
                if !openedAppStore, let url = URL(string: "macappstore://showUpdatesPage") {
                    NSWorkspace.shared.open(url)
                    openedAppStore = true
                }
            default:
                if case .idle = applier.state(for: update.bundleIdentifier) {
                    await applier.apply(update)
                }
            }
        }
    }

    // MARK: - Helpers

    private func releaseNotesURL(for update: AppUpdate) -> URL? {
        guard let notes = update.releaseNotes,
              notes.hasPrefix("http"),
              let url = URL(string: notes.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return nil }
        return url
    }

    private func stateKey(_ state: UpdateApplyState) -> String {
        switch state {
        case .idle: return "idle"
        case .running: return "running"
        case .succeeded: return "succeeded"
        case .failed: return "failed"
        }
    }

    private static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date()).uppercased()
    }
}
