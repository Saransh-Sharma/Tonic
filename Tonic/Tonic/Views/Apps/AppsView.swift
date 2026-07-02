//
//  AppsView.swift
//  Tonic
//
//  Editorial app inventory — taxonomy chips, summary cards, a table-scanning list,
//  and a command dock for uninstalling. Drives the preserved AppInventoryService.
//

import SwiftUI
import AppKit

struct AppsView: View {
    @StateObject private var inventory = AppInventoryService.shared
    @State private var confirmUninstall = false
    @State private var uninstallNotice: TonicInlineNotice.Tone?
    @State private var uninstallMessage: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.tonicLayoutWidth) private var layoutWidth
    @State private var appeared = false
    @FocusState private var searchFocused: Bool

    private var isCompact: Bool { TonicDS.Layout.isCompact(layoutWidth) }

    var body: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
            TonicPageHeader(title: "Apps", subtitle: "Installed apps, updates, and reclaimable space") {
                TonicSearchField(placeholder: "Search apps", text: $inventory.searchText,
                                 externalFocus: $searchFocused)
                    .frame(minWidth: 160, idealWidth: 240, maxWidth: 280)
            }
            .tonicAppear(appeared, index: 0, reduceMotion: reduceMotion)

            categoryChips
                .tonicAppear(appeared, index: 1, reduceMotion: reduceMotion)
            summaryCards
                .tonicAppear(appeared, index: 2, reduceMotion: reduceMotion)
            notices
                .tonicAppear(appeared, index: 3, reduceMotion: reduceMotion)
            content
                .tonicAppear(appeared, index: 4, reduceMotion: reduceMotion)
        }
        .frame(maxWidth: TonicDS.Layout.maxContentWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .tonicScreenHPadding()
        .padding(.vertical, TonicDS.Space.xxl)
        .background(TonicDS.Colors.canvas)
        // Invisible command targets: ⌘F focuses search; ⌘A selects every visible
        // app (suppressed while the search field owns the keyboard).
        .background {
            Button("") { searchFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0).frame(width: 0, height: 0)
                .accessibilityHidden(true)
            if !searchFocused {
                Button("") { selectAllVisible() }
                    .keyboardShortcut("a", modifiers: .command)
                    .opacity(0).frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .bottom) { commandDock }
        .animation(reduceMotion ? nil : TonicDS.Motion.present, value: inventory.selectedAppIDs.isEmpty)
        .onAppear {
            if inventory.apps.isEmpty { Task { await inventory.scanApps() } }
            Task { await inventory.checkForUpdates() }
            appeared = true
        }
        .alert("Uninstall \(inventory.selectedAppIDs.count) app\(inventory.selectedAppIDs.count == 1 ? "" : "s")?",
               isPresented: $confirmUninstall) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) {
                Task {
                    let result = await inventory.uninstallSelectedApps()
                    uninstallMessage = uninstallMessage(for: result)
                    uninstallNotice = result.errors.isEmpty ? .success : (result.success ? .warning : .error)
                }
            }
        } message: {
            Text(uninstallAlertMessage)
        }
    }

    /// Name what leaves: the apps by name (up to five) and the total size,
    /// not a generic "selected apps" promise.
    private var uninstallAlertMessage: String {
        let selected = inventory.filteredApps.filter { inventory.selectedAppIDs.contains($0.id) }
        guard !selected.isEmpty else {
            return "The selected apps and their support files will be moved to the Trash."
        }
        let names = selected.prefix(5).map(\.name).joined(separator: ", ")
        let suffix = selected.count > 5 ? " and \(selected.count - 5) more" : ""
        let total = Self.bytes(selected.reduce(0) { $0 + $1.totalSize })
        return "\(names)\(suffix) — about \(total) including support files — will be moved to the Trash."
    }

    // MARK: - Category chips

    private var categoryChips: some View {
        // The one sanctioned place brand coral rides an interactive control: the app
        // taxonomy. Compact size keeps the 28pt hero face from dominating a dense row.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TonicDS.Space.sm) {
                ForEach(inventory.availableQuickFilters) { cat in
                    CategoryFilterChip(title: cat.rawValue,
                                       isActive: inventory.quickFilterCategory == cat,
                                       size: .compact,
                                       neutralWhenInactive: true) {
                        inventory.quickFilterCategory = cat
                        uninstallMessage = nil
                        uninstallNotice = nil
                    }
                    .accessibilityHint("Filter installed apps")
                }
            }
        }
    }

    // MARK: - Summary cards

    private var summaryCards: some View {
        TonicBentoGrid(minTileWidth: 200) {
            summaryCard("Apps", "\(inventory.appsInCurrentTab.count)", nil)
            summaryCard("Total size", Self.bytes(inventory.totalAppsSize), nil)
            summaryCard("Updates", "\(inventory.availableUpdates)", inventory.availableUpdates > 0 ? TonicDS.Colors.statusInfo : nil)
        }
    }

    private func summaryCard(_ label: String, _ value: String, _ color: Color?) -> some View {
        DataCard(lift: false) {
            VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
                MonoLabel(label)
                Metric(value, color: color ?? TonicDS.Colors.textPrimary)
                    .contentTransition(.numericText())
            }
        }
    }

    @ViewBuilder
    private var notices: some View {
        if let message = inventory.errorMessage {
            TonicInlineNotice(message: message, tone: .warning)
        } else if let uninstallMessage, let uninstallNotice {
            TonicInlineNotice(message: uninstallMessage, tone: uninstallNotice)
        } else if inventory.isRefreshing {
            TonicInlineNotice(message: "Refining app sizes in the background.", tone: .info)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if inventory.isLoading && inventory.apps.isEmpty {
            loadingState
        } else if inventory.filteredApps.isEmpty {
            TonicEmptyState(
                systemImage: "app.dashed",
                title: "No apps found",
                message: inventory.searchText.isEmpty ? "Scan to discover installed apps." : "No apps match your search.",
                actionTitle: inventory.searchText.isEmpty ? "Scan for apps" : nil,
                onAction: inventory.searchText.isEmpty ? { Task { await inventory.scanApps() } } : nil
            )
        } else {
            VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                HStack {
                    MonoLabel("\(inventory.filteredApps.count) apps")
                    Spacer()
                    if inventory.selectedAppIDs.count < inventory.filteredApps.count {
                        TextAction("Select all", color: TonicDS.Colors.linkBlue) { selectAllVisible() }
                    }
                }
                .padding(.horizontal, TonicDS.Space.md)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(inventory.filteredApps) { app in
                            appRow(app)
                            TonicHairline()
                        }
                    }
                    .padding(.bottom, 80)
                    .animation(reduceMotion ? nil : TonicDS.Motion.present, value: inventory.filteredApps.count)
                }
            }
        }
    }

    private func selectAllVisible() {
        inventory.selectedAppIDs = Set(inventory.filteredApps.map(\.id))
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
            MonoLabel("Scanning applications…")
                .padding(.horizontal, TonicDS.Space.md)
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { _ in
                        appRowSkeleton
                        TonicHairline()
                    }
                }
            }
        }
        .accessibilityLabel("Scanning applications")
    }

    private var appRowSkeleton: some View {
        HStack(spacing: TonicDS.Space.md) {
            RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous)
                .fill(TonicDS.Colors.hairline).frame(width: 28, height: 28).skeleton()
            VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                RoundedRectangle(cornerRadius: TonicDS.Radius.xs, style: .continuous)
                    .fill(TonicDS.Colors.hairline).frame(width: 168, height: 12).skeleton()
                RoundedRectangle(cornerRadius: TonicDS.Radius.xs, style: .continuous)
                    .fill(TonicDS.Colors.hairline).frame(width: 104, height: 10).skeleton()
            }
            Spacer()
            RoundedRectangle(cornerRadius: TonicDS.Radius.xs, style: .continuous)
                .fill(TonicDS.Colors.hairline).frame(width: 52, height: 12).skeleton()
        }
        .padding(.horizontal, TonicDS.Space.md)
        .frame(minHeight: TonicDS.Layout.minRowHeight)
    }

    private func appRow(_ app: AppMetadata) -> some View {
        let isSelected = inventory.selectedAppIDs.contains(app.id)
        return SystemListRow(
            leading: {
                HStack(spacing: TonicDS.Space.sm) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(isSelected ? TonicDS.Colors.linkBlue : TonicDS.Colors.textMuted)
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.path.path))
                        .resizable().frame(width: 22, height: 22)
                }
            },
            center: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).tonicType(.body).foregroundStyle(TonicDS.Colors.textPrimary).lineLimit(1)
                    Text(app.bundleIdentifier).tonicType(.micro).monospaced()
                        .foregroundStyle(TonicDS.Colors.textMuted).lineLimit(1)
                }
            },
            trailing: {
                HStack(spacing: TonicDS.Space.md) {
                    if app.hasUpdate { StatusChip("Update", color: TonicDS.Colors.statusInfo) }
                    if let v = app.version {
                        Text("v\(v)").tonicType(.monoLabel).foregroundStyle(TonicDS.Colors.textMuted)
                    }
                    Text(Self.bytes(app.totalSize)).tonicType(.monoLabel).monospacedDigit()
                        .foregroundStyle(TonicDS.Colors.textPrimary)
                        .frame(width: isCompact ? nil : 64, alignment: .trailing)
                }
            },
            isSelected: isSelected,
            reflowWhenCompact: true,
            onTap: { toggle(app) }
        )
        .help(app.path.path)
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([app.path])
            }
            Button("Copy Bundle ID") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(app.bundleIdentifier, forType: .string)
            }
            Divider()
            Button("Uninstall…", role: .destructive) {
                inventory.selectedAppIDs.insert(app.id)
                confirmUninstall = true
            }
        }
    }

    private func toggle(_ app: AppMetadata) {
        if inventory.selectedAppIDs.contains(app.id) { inventory.selectedAppIDs.remove(app.id) }
        else { inventory.selectedAppIDs.insert(app.id) }
    }

    // MARK: - Command dock

    @ViewBuilder
    private var commandDock: some View {
        if !inventory.selectedAppIDs.isEmpty {
            HStack(spacing: TonicDS.Space.md) {
                Text("\(inventory.selectedAppIDs.count) selected")
                    .tonicType(.body).foregroundStyle(TonicDS.Colors.onDarkMuted)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : TonicDS.Motion.numeric, value: inventory.selectedAppIDs.count)
                Spacer()
                TextAction("Clear", color: TonicDS.Colors.onDark) { inventory.selectedAppIDs.removeAll() }
                PrimaryPill("Uninstall", systemImage: "trash", onDark: true) { confirmUninstall = true }
            }
            .padding(.horizontal, TonicDS.Space.lg)
            .padding(.vertical, TonicDS.Space.sm)
            .background(TonicDS.Colors.console, in: Capsule(style: .continuous))
            .padding(.bottom, TonicDS.Space.lg)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private static func bytes(_ value: Int64) -> String {
        let f = ByteCountFormatter(); f.allowedUnits = [.useGB, .useMB]; f.countStyle = .file
        return f.string(fromByteCount: value)
    }

    private func uninstallMessage(for result: UninstallResult) -> String {
        if result.success && result.errors.isEmpty {
            return "Moved \(result.appsUninstalled) app\(result.appsUninstalled == 1 ? "" : "s") to Trash · \(result.formattedBytesFreed) reclaimable."
        }
        if result.success {
            return "Moved \(result.appsUninstalled) app\(result.appsUninstalled == 1 ? "" : "s") to Trash · \(result.errors.count) item\(result.errors.count == 1 ? "" : "s") need review."
        }
        if let first = result.errors.first {
            return "Could not uninstall the selected app: \(first.message)"
        }
        return "No apps were selected for uninstall."
    }
}
