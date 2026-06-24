//
//  PreferencesPermissions.swift
//  Tonic
//
//  Extracted from PreferencesView.swift to keep settings sections modular.
//

import SwiftUI
import AppKit
import UserNotifications

#if canImport(Sparkle)
import Sparkle
#endif

struct PermissionsSettingsContent: View {
    @State private var permissionManager = PermissionManager.shared
    @State private var accessBroker = AccessBroker.shared
    @State private var isRefreshing = false

    var body: some View {
        PreferenceList {
            PreferenceSection(header: "Permissions Status") {
                HStack(spacing: DesignTokens.Spacing.md) {
                    PermissionStatusBadge(
                        count: grantedCount,
                        total: 3,
                        label: "Granted"
                    )

                    if BuildCapabilities.current.requiresScopeAccess {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Coverage")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                            Text(accessBroker.coverageTier.rawValue)
                                .font(DesignTokens.Typography.subhead)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                        }
                    }

                    Spacer()

                    Button {
                        Task { await refreshPermissions() }
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.xxs) {
                            if isRefreshing {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Refresh")
                        }
                        .font(DesignTokens.Typography.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isRefreshing)
                }
                .padding(.vertical, DesignTokens.Spacing.sm)
                .padding(.horizontal, DesignTokens.Spacing.md)
            }

            PreferenceSection(header: "System Access") {
                PermissionStatusRow(
                    title: BuildCapabilities.current.requiresScopeAccess ? "Authorized Locations" : "Full Disk Access",
                    subtitle: BuildCapabilities.current.requiresScopeAccess
                        ? "Grant folders or disks that Tonic can scan and clean"
                        : "Required to scan all files and folders on your Mac",
                    icon: "externaldrive.fill",
                    status: permissionManager.permissionStatuses[.fullDiskAccess] ?? .notDetermined
                )

                PermissionStatusRow(
                    title: "Accessibility",
                    subtitle: "Enables enhanced system monitoring and optimization",
                    icon: "hand.raised.fill",
                    status: permissionManager.permissionStatuses[.accessibility] ?? .notDetermined
                )

                PermissionStatusRow(
                    title: "Notifications",
                    subtitle: "Receive alerts about scan results and system warnings",
                    icon: "bell.fill",
                    status: permissionManager.permissionStatuses[.notifications] ?? .notDetermined,
                    showDivider: false
                )
            }

            if BuildCapabilities.current.requiresScopeAccess {
                PreferenceSection(header: "Access & Permissions") {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Text("Granted Scopes")
                                .font(DesignTokens.Typography.subhead)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                            Spacer()
                            Text("\(accessBroker.activeScopes.count) active")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }

                        if accessBroker.scopes.isEmpty {
                            Text("No scopes added yet. Add Home, Applications, or your startup disk for deeper scans.")
                                .font(DesignTokens.Typography.caption)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                                .padding(.vertical, 4)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(accessBroker.scopes) { scope in
                                    AccessScopeRow(
                                        scope: scope,
                                        status: accessBroker.status(for: scope),
                                        onReauthorize: {
                                            _ = accessBroker.reauthorizeScope(id: scope.id)
                                            Task { await refreshPermissions() }
                                        },
                                        onRemove: {
                                            accessBroker.removeScope(id: scope.id)
                                            Task { await refreshPermissions() }
                                        }
                                    )

                                    if scope.id != accessBroker.scopes.last?.id {
                                        Divider()
                                            .padding(.leading, DesignTokens.Spacing.md)
                                    }
                                }
                            }
                            .background(DesignTokens.Colors.backgroundSecondary.opacity(0.6))
                            .cornerRadius(DesignTokens.CornerRadius.large)
                        }

                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Button("Add Scope") {
                                _ = accessBroker.addScopeUsingOpenPanel()
                                Task { await refreshPermissions() }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)

                            Button("Enable Full Mac Scan") {
                                _ = accessBroker.addStartupDiskScope()
                                Task { await refreshPermissions() }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                }
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .task {
            await permissionManager.checkAllPermissions()
            accessBroker.refreshStatuses()
        }
    }

    private var grantedCount: Int {
        permissionManager.permissionStatuses.values.filter { $0 == .authorized }.count
    }

    private func refreshPermissions() async {
        isRefreshing = true
        await permissionManager.checkAllPermissions()
        try? await Task.sleep(nanoseconds: 300_000_000)
        isRefreshing = false
    }
}

struct AccessScopeRow: View {
    let scope: AccessScope
    let status: AccessScopeStatus
    let onReauthorize: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(scope.displayName)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                Text(scope.rootPath)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(statusLabel)
                .font(DesignTokens.Typography.caption)
                .foregroundColor(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(statusColor.opacity(0.14))
                .cornerRadius(6)

            if status != .active {
                Button("Re-authorize", action: onReauthorize)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            Button("Remove", role: .destructive, action: onRemove)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private var statusLabel: String {
        switch status {
        case .active:
            return "Active"
        case .disconnected:
            return "Not Connected"
        case .staleBookmark:
            return "Needs Reauth"
        case .invalid:
            return "Invalid"
        }
    }

    private var statusColor: Color {
        switch status {
        case .active:
            return TonicColors.success
        case .disconnected:
            return TonicColors.warning
        case .staleBookmark, .invalid:
            return TonicColors.error
        }
    }
}

// MARK: - Permission Status Badge

struct PermissionStatusBadge: View {
    let count: Int
    let total: Int
    let label: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ZStack {
                Circle()
                    .stroke(DesignTokens.Colors.separator, lineWidth: 3)
                    .frame(width: 36, height: 36)

                Circle()
                    .trim(from: 0, to: CGFloat(count) / CGFloat(total))
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))

                Text("\(count)")
                    .font(DesignTokens.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("\(count) of \(total)")
                    .font(DesignTokens.Typography.subhead)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text(label)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
    }

    private var statusColor: Color {
        switch count {
        case 0: return TonicColors.error
        case 1..<total: return TonicColors.warning
        default: return TonicColors.success
        }
    }
}

// MARK: - Permission Card

struct PermissionCard: View {
    let permission: TonicPermission
    let title: String
    let description: String
    let icon: String
    let isCritical: Bool
    let status: PermissionStatus
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(statusColor)
            }

            // Content
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(title)
                        .font(DesignTokens.Typography.subhead)
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    if isCritical {
                        Text("Required")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(TonicColors.accent.opacity(0.8))
                            .cornerRadius(4)
                    }
                }

                Text(description)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            // Status and action
            VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xs) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(statusLabel)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(statusColor)
                }

                if status != .authorized {
                    Button("Grant") {
                        action()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityLabel("Grant \(title.lowercased()) permission")
                    .accessibilityHint("Opens System Settings to grant permission")
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large)
                .fill(isHovered ? DesignTokens.Colors.unemphasizedSelectedContentBackground : DesignTokens.Colors.backgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large)
                .stroke(statusColor.opacity(status == .authorized ? 0.3 : 0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
    }

    private var statusColor: Color {
        switch status {
        case .authorized: return TonicColors.success
        case .denied: return isCritical ? TonicColors.error : TonicColors.warning
        case .notDetermined: return DesignTokens.Colors.textTertiary
        }
    }

    private var statusLabel: String {
        switch status {
        case .authorized: return "Granted"
        case .denied: return "Denied"
        case .notDetermined: return "Not Set"
        }
    }
}

// MARK: - Updates Settings Content

