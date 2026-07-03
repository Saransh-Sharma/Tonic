//
//  StartupItemsView.swift
//  Tonic
//
//  The Startup tab of the Apps screen: everything that launches without the
//  user asking — login-item apps, user launch agents (toggle + remove),
//  and read-only global agents/daemons (changing those needs admin rights,
//  so Tonic doesn't pretend it can).
//

import SwiftUI
import AppKit

struct StartupItemsView: View {
    @ObservedObject var inventory: AppInventoryService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmRemove: LaunchService?
    @State private var actionMessage: String?
    @State private var danglingPaths: Set<String> = []

    private var manager: LoginItemsManager { .shared }

    private var userAgents: [LaunchService] {
        inventory.launchServices.filter {
            $0.serviceType == .agent && $0.path.path.hasPrefix(NSHomeDirectory())
        }
    }

    private var systemServices: [LaunchService] {
        inventory.launchServices.filter {
            !($0.serviceType == .agent && $0.path.path.hasPrefix(NSHomeDirectory()))
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
                if let actionMessage {
                    TonicInlineNotice(message: actionMessage, tone: .info)
                }

                if inventory.loginItems.isEmpty && inventory.launchServices.isEmpty {
                    TonicEmptyState(
                        systemImage: "power",
                        title: "Nothing starts automatically",
                        message: "Login items and launch agents will appear here.",
                        actionTitle: "Scan Now",
                        onAction: { Task { await refresh() } }
                    )
                } else {
                    loginItemsSection
                    userAgentsSection
                    systemServicesSection
                }
            }
            .padding(.bottom, 80)
        }
        .onAppear {
            Task { await refresh() }
        }
        .alert("Remove \(confirmRemove?.name ?? "launch agent")?",
               isPresented: Binding(get: { confirmRemove != nil },
                                    set: { if !$0 { confirmRemove = nil } })) {
            Button("Cancel", role: .cancel) {}
            Button("Unload & Remove", role: .destructive) {
                if let service = confirmRemove { Task { await remove(service) } }
            }
        } message: {
            Text("The agent is unloaded and its configuration file moves to the Trash. The app that installed it may recreate it.")
        }
    }

    private func refresh() async {
        await inventory.refreshLoginItems()
        await inventory.refreshLaunchServices()
        danglingPaths = Set(
            SystemIntegrityScanner.shared.scanDanglingLaunchAgents().map(\.plistPath)
        )
    }

    // MARK: - Login items

    @ViewBuilder
    private var loginItemsSection: some View {
        if !inventory.loginItems.isEmpty {
            VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                MonoLabel("Login items · \(inventory.loginItems.count)")
                Text("Apps with a built-in launch-at-login helper. Turn them off inside each app or in System Settings → General → Login Items.")
                    .tonicType(.caption)
                    .foregroundStyle(TonicDS.Colors.textMuted)
                VStack(spacing: 0) {
                    ForEach(inventory.loginItems) { item in
                        SystemListRow(
                            leading: {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: item.path.path))
                                    .resizable().frame(width: 22, height: 22)
                            },
                            center: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).tonicType(.body)
                                        .foregroundStyle(TonicDS.Colors.textPrimary).lineLimit(1)
                                    Text(item.bundleIdentifier).tonicType(.micro).monospaced()
                                        .foregroundStyle(TonicDS.Colors.textMuted).lineLimit(1)
                                }
                            },
                            trailing: {
                                StatusChip("LOGIN ITEM", color: TonicDS.Colors.statusInfo)
                            }
                        )
                        .contextMenu {
                            Button("Reveal in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([item.path])
                            }
                            Button("Open Login Items Settings") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                        TonicHairline()
                    }
                }
            }
        }
    }

    // MARK: - User launch agents

    @ViewBuilder
    private var userAgentsSection: some View {
        if !userAgents.isEmpty {
            VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                MonoLabel("Your launch agents · \(userAgents.count)")
                Text("Installed in your user account — Tonic can turn these off or remove them.")
                    .tonicType(.caption)
                    .foregroundStyle(TonicDS.Colors.textMuted)
                VStack(spacing: 0) {
                    ForEach(userAgents) { service in
                        agentRow(service, editable: true)
                        TonicHairline()
                    }
                }
            }
        }
    }

    // MARK: - System agents & daemons

    @ViewBuilder
    private var systemServicesSection: some View {
        if !systemServices.isEmpty {
            VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                MonoLabel("System agents & daemons · \(systemServices.count)")
                Text("Installed system-wide. Changing these requires administrator rights, so Tonic shows them read-only.")
                    .tonicType(.caption)
                    .foregroundStyle(TonicDS.Colors.textMuted)
                VStack(spacing: 0) {
                    ForEach(systemServices) { service in
                        agentRow(service, editable: false)
                        TonicHairline()
                    }
                }
            }
        }
    }

    // MARK: - Rows

    private func agentRow(_ service: LaunchService, editable: Bool) -> some View {
        let isDangling = danglingPaths.contains(service.path.path)
        return SystemListRow(
            leading: {
                Image(systemName: service.serviceType == .daemon ? "gearshape.2" : "person.crop.circle.badge.clock")
                    .font(.system(size: 14))
                    .frame(width: 22)
                    .foregroundStyle(TonicDS.Colors.textMuted)
            },
            center: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.name).tonicType(.body)
                        .foregroundStyle(TonicDS.Colors.textPrimary).lineLimit(1)
                    Text(service.serviceType == .daemon ? "Launch daemon" : "Launch agent")
                        .tonicType(.micro)
                        .foregroundStyle(TonicDS.Colors.textMuted)
                }
            },
            trailing: {
                HStack(spacing: TonicDS.Space.sm) {
                    if isDangling {
                        StatusChip("BROKEN", color: TonicDS.Colors.statusWarning)
                            .help("Points at an app that no longer exists")
                    }
                    if service.isEnabled {
                        StatusChip("LOADED", color: TonicDS.Colors.statusSuccess)
                    } else {
                        StatusChip("NOT LOADED", color: TonicDS.Colors.statusInfo)
                    }
                    if editable {
                        TextAction(service.isEnabled ? "Disable" : "Enable",
                                   color: TonicDS.Colors.linkBlue) {
                            Task { await toggle(service) }
                        }
                        TextAction("Remove…", color: TonicDS.Colors.statusCritical) {
                            confirmRemove = service
                        }
                    }
                }
            }
        )
        .help(service.path.path)
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([service.path])
            }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(service.path.path, forType: .string)
            }
        }
    }

    // MARK: - Actions

    private func toggle(_ service: LaunchService) async {
        do {
            if service.isEnabled {
                try await manager.unloadLaunchService(service)
                actionMessage = "\(service.name) disabled — it won't start next login."
            } else {
                try await manager.loadLaunchService(service)
                actionMessage = "\(service.name) enabled."
            }
        } catch {
            actionMessage = "Couldn't change \(service.name): \(error.localizedDescription)"
        }
        await refresh()
    }

    private func remove(_ service: LaunchService) async {
        do {
            if service.isEnabled {
                try? await manager.unloadLaunchService(service)
            }
            // Trash, not delete: recoverable like every other Tonic removal.
            var trashedURL: NSURL?
            try FileManager.default.trashItem(at: service.path, resultingItemURL: &trashedURL)
            actionMessage = "\(service.name) removed — its file is in the Trash."
        } catch {
            actionMessage = "Couldn't remove \(service.name): \(error.localizedDescription)"
        }
        confirmRemove = nil
        await refresh()
    }
}
