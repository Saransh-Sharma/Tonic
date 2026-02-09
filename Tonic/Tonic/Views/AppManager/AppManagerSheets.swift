//
//  AppManagerSheets.swift
//  Tonic
//
//  Modernized app detail and uninstall flow sheets for App Manager.
//

import SwiftUI
import AppKit

// MARK: - App Detail Sheet

struct AppDetailSheet: View {
    let app: AppMetadata
    let onUninstall: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.tonicTheme) private var theme
    @State private var appIcon: NSImage?

    var body: some View {
        TonicThemeProvider(world: .applicationsBlue) {
            ZStack {
                WorldCanvasBackground()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        IconOnlyButton(systemName: "xmark") {
                            dismiss()
                        }
                        Spacer()
                    }
                    .padding(.horizontal, TonicSpaceToken.three)
                    .padding(.vertical, TonicSpaceToken.two)

                    ScrollView {
                        VStack(spacing: TonicSpaceToken.four) {
                            // App identity
                            GlassPanel(radius: TonicRadiusToken.container, variant: .raised) {
                                HStack(spacing: TonicSpaceToken.three) {
                                    // Large icon
                                    Group {
                                        if let icon = appIcon {
                                            Image(nsImage: icon)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                        } else {
                                            Image(systemName: "app.fill")
                                                .font(.system(size: 48))
                                                .foregroundStyle(TonicTextToken.tertiary)
                                        }
                                    }
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                                    VStack(alignment: .leading, spacing: TonicSpaceToken.one) {
                                        Text(app.name)
                                            .font(TonicTypeToken.title)
                                            .foregroundStyle(TonicTextToken.primary)

                                        Text(app.bundleIdentifier)
                                            .font(TonicTypeToken.caption)
                                            .foregroundStyle(TonicTextToken.tertiary)

                                        HStack(spacing: TonicSpaceToken.one) {
                                            if let version = app.version {
                                                GlassChip(title: "v\(version)", role: .semantic(.neutral))
                                            }
                                            GlassChip(title: app.category.rawValue, role: .world(.applicationsBlue), strength: .subtle)
                                        }
                                    }

                                    Spacer()
                                }
                            }

                            // Size details
                            GlassCard(radius: TonicRadiusToken.l) {
                                VStack(alignment: .leading, spacing: TonicSpaceToken.two) {
                                    HStack(spacing: TonicSpaceToken.one) {
                                        Image(systemName: "externaldrive")
                                            .foregroundStyle(TonicTextToken.secondary)
                                        Text("Size")
                                            .font(TonicTypeToken.caption.weight(.semibold))
                                            .foregroundStyle(TonicTextToken.primary)
                                    }

                                    Text(ByteCountFormatter.string(fromByteCount: app.totalSize, countStyle: .file))
                                        .font(TonicTypeToken.tileMetric)
                                        .foregroundStyle(TonicTextToken.primary)
                                        .contentTransition(.numericText())
                                }
                            }
                            .depthLift()

                            // Info rows
                            GlassCard(radius: TonicRadiusToken.l) {
                                VStack(spacing: TonicSpaceToken.two) {
                                    DetailRow(label: "Location", value: app.path.path)
                                    Divider().opacity(0.3)
                                    DetailRow(label: "Version", value: app.version ?? "Unknown")
                                    Divider().opacity(0.3)
                                    DetailRow(label: "Category", value: app.category.rawValue)
                                    if let installDate = app.installDate {
                                        Divider().opacity(0.3)
                                        DetailRow(label: "Installed", value: installDate.formatted(date: .abbreviated, time: .omitted))
                                    }
                                    if let lastUsed = app.lastUsed {
                                        Divider().opacity(0.3)
                                        DetailRow(label: "Last Used", value: lastUsed.formatted(date: .abbreviated, time: .omitted))
                                    }
                                }
                            }
                            .depthLift()

                            // Actions
                            GlassCard(radius: TonicRadiusToken.l) {
                                VStack(spacing: TonicSpaceToken.two) {
                                    SecondaryPillButton(title: "Reveal in Finder") {
                                        NSWorkspace.shared.activateFileViewerSelecting([app.path])
                                    }

                                    if !ProtectedApps.isProtectedFromUninstall(app.bundleIdentifier) {
                                        PrimaryActionButton(
                                            title: "Uninstall App",
                                            icon: "trash",
                                            action: {
                                                dismiss()
                                                onUninstall()
                                            }
                                        )
                                    } else {
                                        GlassChip(title: "Protected App", icon: "lock.fill", role: .semantic(.success))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, TonicSpaceToken.three)
                        .padding(.bottom, TonicSpaceToken.four)
                    }
                }
            }
        }
        .frame(width: 600, height: 520)
        .task {
            appIcon = await loadIconAsync(for: app.path)
        }
    }

    private func loadIconAsync(for path: URL) async -> NSImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let icon = NSWorkspace.shared.icon(forFile: path.path)
                if icon.isValid && icon.representations.count > 0 {
                    continuation.resume(returning: icon)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(TonicTypeToken.caption)
                .foregroundStyle(TonicTextToken.tertiary)
            Spacer()
            Text(value)
                .font(TonicTypeToken.caption.weight(.medium))
                .foregroundStyle(TonicTextToken.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

// MARK: - Uninstall Flow Sheet

struct UninstallFlowSheet: View {
    @ObservedObject var inventory: AppInventoryService
    @Binding var isPresented: Bool
    let onComplete: () -> Void

    @State private var flowState: FlowState = .confirmation
    @State private var progressState: ProgressData?
    @State private var resultState: UninstallResult?

    enum FlowState {
        case confirmation
        case progress
        case summary
    }

    struct ProgressData {
        let total: Int
        let completed: Int
        let currentAppName: String
        let bytesFreed: Int64

        var progress: Double {
            guard total > 0 else { return 0 }
            return Double(completed) / Double(total)
        }
    }

    private var appsToDelete: [AppMetadata] {
        inventory.selectedApps.sorted { $0.totalSize > $1.totalSize }
    }

    private var totalSize: Int64 {
        appsToDelete.reduce(0) { $0 + $1.totalSize }
    }

    var body: some View {
        TonicThemeProvider(world: .applicationsBlue) {
            ZStack {
                WorldCanvasBackground()

                VStack(spacing: 0) {
                    header
                    Divider().opacity(0.3)

                    ScrollView {
                        VStack(spacing: TonicSpaceToken.four) {
                            switch flowState {
                            case .confirmation:
                                confirmationContent
                            case .progress:
                                progressContent
                            case .summary:
                                summaryContent
                            }
                        }
                        .padding(TonicSpaceToken.four)
                    }

                    Divider().opacity(0.3)
                    footer
                }
            }
        }
        .frame(width: 560, height: 600)
        .onAppear {
            flowState = .confirmation
            progressState = nil
            resultState = nil
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: TonicSpaceToken.two) {
            Image(systemName: headerIcon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(headerColor)
                .frame(width: 36, height: 36)
                .background(headerColor.opacity(0.15))
                .clipShape(Circle())

            Text(headerTitle)
                .font(TonicTypeToken.caption.weight(.semibold))
                .foregroundStyle(TonicTextToken.primary)

            Spacer()

            if flowState != .progress {
                IconOnlyButton(systemName: "xmark") {
                    isPresented = false
                }
            }
        }
        .padding(.horizontal, TonicSpaceToken.three)
        .padding(.vertical, TonicSpaceToken.two)
    }

    private var headerIcon: String {
        switch flowState {
        case .confirmation: return "trash.fill"
        case .progress: return "arrow.triangle.2.circlepath"
        case .summary: return resultState?.success == true ? "checkmark" : "exclamationmark"
        }
    }

    private var headerColor: Color {
        switch flowState {
        case .confirmation: return TonicStatusPalette.text(.danger)
        case .progress: return TonicStatusPalette.text(.info)
        case .summary: return resultState?.success == true ? TonicStatusPalette.text(.success) : TonicStatusPalette.text(.warning)
        }
    }

    private var headerTitle: String {
        switch flowState {
        case .confirmation: return "Confirm Uninstall"
        case .progress: return "Uninstalling Apps"
        case .summary: return resultState?.success == true ? "Uninstall Complete" : "Uninstall Finished"
        }
    }

    // MARK: - Confirmation

    private var confirmationContent: some View {
        VStack(spacing: TonicSpaceToken.four) {
            // Warning
            GlassCard(radius: TonicRadiusToken.l) {
                HStack(spacing: TonicSpaceToken.two) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(TonicStatusPalette.text(.warning))
                        .font(.system(size: 20))
                    Text("These apps will be moved to Trash. This action cannot be undone.")
                        .font(TonicTypeToken.caption)
                        .foregroundStyle(TonicTextToken.secondary)
                    Spacer()
                }
            }

            // App list
            VStack(spacing: TonicSpaceToken.two) {
                ForEach(appsToDelete) { app in
                    UninstallAppRow(app: app)
                }
            }

            // Total size
            VStack(spacing: TonicSpaceToken.one) {
                MicroText("Total Space to be Freed")
                Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                    .font(TonicTypeToken.tileMetric)
                    .foregroundStyle(TonicStatusPalette.text(.danger))
                    .contentTransition(.numericText())
            }
        }
    }

    // MARK: - Progress

    private var progressContent: some View {
        VStack(spacing: TonicSpaceToken.five) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(TonicGlassToken.stroke, lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: progressState?.progress ?? 0)
                    .stroke(
                        TonicStatusPalette.text(.info),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progressState?.progress ?? 0)

                VStack(spacing: 4) {
                    Text("\(Int((progressState?.progress ?? 0) * 100))%")
                        .font(TonicTypeToken.tileMetric)
                        .foregroundStyle(TonicTextToken.primary)
                        .contentTransition(.numericText())

                    Text("\(progressState?.completed ?? 0) of \(progressState?.total ?? 0)")
                        .font(TonicTypeToken.micro)
                        .foregroundStyle(TonicTextToken.tertiary)
                }
            }

            if let progress = progressState, !progress.currentAppName.isEmpty {
                VStack(spacing: TonicSpaceToken.one) {
                    ScanningDotsView()
                    CaptionText("Removing")
                    Text(progress.currentAppName)
                        .font(TonicTypeToken.caption.weight(.semibold))
                        .foregroundStyle(TonicTextToken.primary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Summary

    private var summaryContent: some View {
        VStack(spacing: TonicSpaceToken.five) {
            Spacer()

            // Success icon with completion burst
            Image(systemName: resultState?.success == true ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(resultState?.success == true ? TonicStatusPalette.text(.success) : TonicStatusPalette.text(.warning))
                .completionBurst(active: resultState?.success == true)

            // Stats
            VStack(spacing: TonicSpaceToken.three) {
                VStack(spacing: TonicSpaceToken.one) {
                    MicroText("Space Freed")
                    Text(ByteCountFormatter.string(fromByteCount: resultState?.bytesFreed ?? 0, countStyle: .file))
                        .font(TonicTypeToken.tileMetric)
                        .foregroundStyle(TonicStatusPalette.text(.success))
                        .contentTransition(.numericText())
                }

                HStack(spacing: TonicSpaceToken.four) {
                    CounterChip(title: "Removed", value: "\(resultState?.appsUninstalled ?? 0)", world: .cleanupGreen)

                    if let errors = resultState?.errors, !errors.isEmpty {
                        CounterChip(title: "Failed", value: "\(errors.count)", world: .performanceOrange)
                    }
                }
            }

            // Errors
            if let errors = resultState?.errors, !errors.isEmpty {
                GlassCard(radius: TonicRadiusToken.l) {
                    VStack(alignment: .leading, spacing: TonicSpaceToken.one) {
                        CaptionText("Could not remove these apps:")
                        ForEach(errors) { error in
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(TonicStatusPalette.text(.warning))
                                Text((error.path as NSString).lastPathComponent)
                                    .font(TonicTypeToken.micro)
                                    .foregroundStyle(TonicTextToken.secondary)
                                Spacer()
                                Text(error.message)
                                    .font(TonicTypeToken.micro)
                                    .foregroundStyle(TonicTextToken.tertiary)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: TonicSpaceToken.two) {
            if flowState == .confirmation {
                SecondaryPillButton(title: "Cancel") {
                    isPresented = false
                }
                PrimaryActionButton(title: "Uninstall", icon: "trash", action: startUninstall)
            } else if flowState == .summary {
                PrimaryActionButton(title: "Done", icon: "checkmark") {
                    onComplete()
                    isPresented = false
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, TonicSpaceToken.three)
        .padding(.vertical, TonicSpaceToken.two)
    }

    // MARK: - Uninstall Logic

    private func startUninstall() {
        flowState = .progress

        Task {
            let totalApps = appsToDelete.count
            var bytesFreed: Int64 = 0
            var completed = 0
            var errors: [UninstallError] = []
            var successfullyRemovedIDs: Set<UUID> = []

            for (index, app) in appsToDelete.enumerated() {
                await MainActor.run {
                    progressState = ProgressData(
                        total: totalApps,
                        completed: index,
                        currentAppName: app.name,
                        bytesFreed: bytesFreed
                    )
                }

                if ProtectedApps.isProtectedFromUninstall(app.bundleIdentifier) {
                    errors.append(UninstallError(path: app.path.path, message: "Protected app"))
                    continue
                }

                let result = await inventory.fileOps.moveFilesToTrash(atPaths: [app.path.path])
                if result.success && result.filesProcessed > 0 {
                    successfullyRemovedIDs.insert(app.id)
                    bytesFreed += app.totalSize
                } else if let error = result.errors.first {
                    errors.append(UninstallError(path: app.path.path, message: error.errorDescription ?? "Unknown error"))
                }

                completed += 1
            }

            await MainActor.run {
                inventory.apps = inventory.apps.filter { !successfullyRemovedIDs.contains($0.id) }
                inventory.selectedAppIDs.removeAll()
            }

            let finalResult = UninstallResult(
                success: completed > 0,
                appsUninstalled: completed,
                bytesFreed: bytesFreed,
                errors: errors
            )

            inventory.cache.saveApps(inventory.apps)

            try? await Task.sleep(nanoseconds: 500_000_000)

            await MainActor.run {
                resultState = finalResult
                flowState = .summary
            }
        }
    }
}

// MARK: - Uninstall App Row

private struct UninstallAppRow: View {
    let app: AppMetadata
    @State private var appIcon: NSImage?

    var body: some View {
        HStack(spacing: TonicSpaceToken.two) {
            Group {
                if let icon = appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(TonicTextToken.tertiary)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(TonicTypeToken.caption.weight(.semibold))
                    .foregroundStyle(TonicTextToken.primary)

                Text(app.bundleIdentifier)
                    .font(TonicTypeToken.micro)
                    .foregroundStyle(TonicTextToken.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text(ByteCountFormatter.string(fromByteCount: app.totalSize, countStyle: .file))
                .font(TonicTypeToken.caption.weight(.semibold))
                .foregroundStyle(TonicStatusPalette.text(.danger))
        }
        .padding(TonicSpaceToken.two)
        .glassSurface(radius: TonicRadiusToken.l, variant: .base)
        .task {
            appIcon = await loadIconAsync(for: app.path)
        }
    }

    private func loadIconAsync(for path: URL) async -> NSImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let icon = NSWorkspace.shared.icon(forFile: path.path)
                if icon.isValid && icon.representations.count > 0 {
                    continuation.resume(returning: icon)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
