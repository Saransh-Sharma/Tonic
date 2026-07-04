//
//  UnifiedOnboardingView.swift
//  Tonic
//
//  Editorial 3-page onboarding: Welcome · Permissions · Ready. Separates value from
//  required setup. Preserves the isPresented contract and completion flags.
//

import SwiftUI

struct UnifiedOnboardingView: View {
    @Binding var isPresented: Bool

    @State private var page = 0
    @State private var permissions = PermissionManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pageCount = 4
    @State private var notificationsRequested = false

    var body: some View {
        VStack(spacing: 0) {
            progress
            Group {
                switch page {
                case 0: welcome
                case 1: permissionsPage
                case 2: careAndAlertsPage
                default: ready
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing)))
        }
        .frame(width: 720, height: 560)
        .background(TonicDS.Colors.canvas)
    }

    // MARK: - Progress

    private var progress: some View {
        HStack(spacing: TonicDS.Space.xs) {
            ForEach(0..<pageCount, id: \.self) { i in
                Capsule()
                    .fill(i == page ? TonicDS.Colors.ink : TonicDS.Colors.hairline)
                    .frame(width: i == page ? 24 : 8, height: 4)
            }
        }
        .padding(.top, TonicDS.Space.xl)
    }

    // MARK: - Pages

    private var welcome: some View {
        VStack(spacing: TonicDS.Space.lg) {
            Spacer()
            Text("Tonic").tonicType(.heroDisplay).foregroundStyle(TonicDS.Colors.textPrimary)
            Text("A calm command center for your Mac's health.")
                .tonicType(.bodyLarge).foregroundStyle(TonicDS.Colors.textMuted)
            HStack(spacing: TonicDS.Space.sm) {
                capability("sparkles", "Clean")
                capability("gauge.with.dots.needle.50percent", "Monitor")
                capability("checkmark.shield", "Protect")
            }
            .padding(.top, TonicDS.Space.sm)
            Spacer()
            PrimaryPill("Get started") { advance() }
            Spacer().frame(height: TonicDS.Space.xxl)
        }
        .padding(TonicDS.Space.xxxl)
    }

    private func capability(_ icon: String, _ label: String) -> some View {
        HStack(spacing: TonicDS.Space.xs) {
            Image(systemName: icon).font(.system(size: 13, weight: .regular))
            Text(label).tonicType(.button)
        }
        .foregroundStyle(TonicDS.Colors.textPrimary)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .overlay(Capsule().strokeBorder(TonicDS.Colors.hairline, lineWidth: 1))
    }

    private var permissionsPage: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
            Spacer()
            Text(BuildCapabilities.current.requiresScopeAccess ? "Authorize locations" : "Grant access")
                .tonicType(.sectionDisplay).foregroundStyle(TonicDS.Colors.textPrimary)
            Text(BuildCapabilities.current.requiresScopeAccess
                 ? "Tonic analyzes only the locations you authorize. You can add or remove them anytime in Settings."
                 : "Tonic needs Full Disk Access to scan files and manage apps. Everything runs locally on your Mac.")
                .tonicType(.bodyLarge).foregroundStyle(TonicDS.Colors.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            // Ask on the page that explains the value, with honest status words.
            VStack(spacing: 0) {
                permissionStatusRow(.fullDiskAccess,
                                    detail: "Scan every corner: caches, mail, backups.")
                TonicHairline()
                permissionStatusRow(.accessibility,
                                    detail: "Needed for a few system optimizations.")
            }
            .background(TonicDS.Colors.surface,
                        in: RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous)
                .strokeBorder(TonicDS.Colors.hairline, lineWidth: 1))

            HStack(spacing: TonicDS.Space.md) {
                PrimaryPill(permissions.hasFullDiskAccess ? "Granted" : "Grant access") {
                    if !permissions.hasFullDiskAccess { _ = permissions.requestFullDiskAccess() }
                    Task { await permissions.checkAllPermissions() }
                }
                TextAction("Skip for now") { advance() }
            }
            Spacer()
            HStack {
                TextAction("Back") { withAnimation(TonicDS.Motion.present) { page = max(0, page - 1) } }
                Spacer()
                PrimaryPill("Continue") { advance() }
            }
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TonicDS.Space.xxxl)
    }

    private func permissionStatusRow(_ permission: TonicPermission, detail: String) -> some View {
        let granted = permissions.permissionStatuses[permission] == .authorized
        return HStack(spacing: TonicDS.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.rawValue).tonicType(.body)
                    .foregroundStyle(TonicDS.Colors.textPrimary)
                Text(detail).tonicType(.caption)
                    .foregroundStyle(TonicDS.Colors.textMuted)
            }
            Spacer()
            StatusChip(granted ? "Granted" : "Not yet", level: granted ? .success : .info)
        }
        .padding(TonicDS.Space.md)
    }

    /// Optional comforts: alert notifications and scheduled care. Both are
    /// opt-in here and adjustable later in Settings.
    private var careAndAlertsPage: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
            Spacer()
            Text("Care on a schedule")
                .tonicType(.sectionDisplay).foregroundStyle(TonicDS.Colors.textPrimary)
            Text("Tonic can clean safe system junk automatically and tell you what it did. Personal files are never touched without your review.")
                .tonicType(.bodyLarge).foregroundStyle(TonicDS.Colors.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: TonicDS.Space.md) {
                PrimaryPill(notificationsRequested ? "Notifications enabled" : "Allow notifications") {
                    guard !notificationsRequested else { return }
                    NotificationManager.shared.requestPermission { granted in
                        Task { @MainActor in notificationsRequested = granted }
                    }
                }
                TextAction(MaintenanceScheduler.shared.cadence == .off
                           ? "Turn on weekly maintenance"
                           : "Weekly maintenance is on") {
                    MaintenanceScheduler.shared.cadence = .weekly
                }
            }
            Text("Both live in Settings → Maintenance if you change your mind.")
                .tonicType(.caption).foregroundStyle(TonicDS.Colors.textMuted)
            Spacer()
            HStack {
                TextAction("Back") { withAnimation(TonicDS.Motion.present) { page = max(0, page - 1) } }
                Spacer()
                PrimaryPill("Continue") { advance() }
            }
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TonicDS.Space.xxxl)
    }

    private var ready: some View {
        VStack(spacing: TonicDS.Space.lg) {
            Spacer()
            Image(systemName: "checkmark.seal").font(.system(size: 44, weight: .thin))
                .foregroundStyle(TonicDS.Colors.statusSuccess)
            Text("You're set.").tonicType(.heroDisplay).foregroundStyle(TonicDS.Colors.textPrimary)
            Text("Run a Smart Scan whenever you want to tidy up.")
                .tonicType(.bodyLarge).foregroundStyle(TonicDS.Colors.textMuted)
            Spacer()
            PrimaryPill("Open Tonic") { finish() }
            Spacer().frame(height: TonicDS.Space.xxl)
        }
        .padding(TonicDS.Space.xxxl)
    }

    // MARK: - Flow

    private func advance() {
        withAnimation(TonicDS.Motion.present) { page = min(pageCount - 1, page + 1) }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        UserDefaults.standard.set(true, forKey: "hasCompletedWidgetOnboarding")
        UserDefaults.standard.set(true, forKey: "hasSeenFeatureTour")
        UserDefaults.standard.set(true, forKey: "tonic.widget.hasCompletedOnboarding")
        WidgetCoordinator.shared.start()
        isPresented = false
    }
}
