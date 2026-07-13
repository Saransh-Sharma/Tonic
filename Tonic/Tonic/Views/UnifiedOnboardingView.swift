//
//  UnifiedOnboardingView.swift
//  Tonic
//
//  Goal-first onboarding: choose value, try it, enable only what it needs, begin.
//

import SwiftUI

private enum OnboardingGoal: String, CaseIterable, Identifiable {
    case windows
    case menuBar
    case monitoring
    case storage
    case appCare

    var id: String { rawValue }

    var title: String {
        switch self {
        case .windows: "Arrange windows"
        case .menuBar: "Organize the menu bar"
        case .monitoring: "Understand Mac activity"
        case .storage: "Reclaim storage"
        case .appCare: "Manage apps"
        }
    }

    var detail: String {
        switch self {
        case .windows: "Snap windows and restore workspaces"
        case .menuBar: "Make room without losing menu items"
        case .monitoring: "See processor, memory, network, and energy evidence"
        case .storage: "Find large, old, and recently grown files"
        case .appCare: "Review updates, leftovers, startup, and background activity"
        }
    }

    var symbol: String {
        switch self {
        case .windows: "rectangle.split.3x1"
        case .menuBar: "menubar.rectangle"
        case .monitoring: "waveform.path.ecg"
        case .storage: "internaldrive"
        case .appCare: "square.grid.3x3"
        }
    }
}

struct UnifiedOnboardingView: View {
    @Binding var isPresented: Bool

    @State private var page = 0
    @State private var selectedGoals: Set<OnboardingGoal> = [.windows, .monitoring]
    @State private var previewPlacement: WindowAction = .leftHalf
    @State private var permissions = PermissionManager.shared
    @State private var metrics = WidgetDataManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            progress
            Group {
                switch page {
                case 0: goalsPage
                case 1: previewPage
                case 2: accessPage
                default: readyPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing)))
        }
        .frame(width: 760, height: 620)
        .tonicSheetBackground()
        .task {
            metrics.startMonitoring()
            await permissions.checkAllPermissions()
        }
    }

    private var progress: some View {
        HStack(spacing: TonicDS.Space.xs) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == page ? TonicDS.Colors.brandAccent : TonicDS.Colors.hairline)
                    .frame(width: index == page ? 28 : 8, height: 4)
            }
        }
        .padding(.top, TonicDS.Space.xl)
        .accessibilityLabel("Step \(page + 1) of \(pageCount)")
    }

    private var goalsPage: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
            VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                Text("What should Tonic help with?")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(TonicDS.Colors.textPrimary)
                Text("Choose any goals. Tonic will configure Home and ask only for access those goals need.")
                    .font(.system(size: 14))
                    .foregroundStyle(TonicDS.Colors.textMuted)
            }

            VStack(spacing: TonicDS.Space.xs) {
                ForEach(OnboardingGoal.allCases) { goal in
                    goalRow(goal)
                }
            }

            Spacer()
            HStack {
                Button("Not now", action: finish)
                    .buttonStyle(.borderless)
                Spacer()
                PrimaryPill("Try selected tools", isDisabled: selectedGoals.isEmpty) { advance() }
            }
        }
        .padding(TonicDS.Space.xxxl)
    }

    private func goalRow(_ goal: OnboardingGoal) -> some View {
        let isSelected = selectedGoals.contains(goal)
        return Button {
            if isSelected { selectedGoals.remove(goal) } else { selectedGoals.insert(goal) }
            TonicFeedback.alignment()
        } label: {
            HStack(spacing: TonicDS.Space.md) {
                Image(systemName: goal.symbol)
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.title).font(.system(size: 14, weight: .semibold))
                    Text(goal.detail).font(.system(size: 12)).foregroundStyle(TonicDS.Colors.textMuted)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? TonicDS.Colors.brandAccent : TonicDS.Colors.textMuted)
            }
            .foregroundStyle(TonicDS.Colors.textPrimary)
            .padding(.horizontal, TonicDS.Space.md)
            .frame(height: 58)
            .background(isSelected ? TonicDS.Colors.brandAccentSoft : TonicDS.Colors.canvasSoft, in: RoundedRectangle(cornerRadius: TonicDS.Radius.sm))
            .overlay { RoundedRectangle(cornerRadius: TonicDS.Radius.sm).strokeBorder(isSelected ? TonicDS.Colors.brandAccent : TonicDS.Colors.hairline, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .tonicFocusableControl(radius: TonicDS.Radius.sm)
    }

    private var previewPage: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
            VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                Text("Try the interaction first")
                    .font(.system(size: 34, weight: .medium))
                Text("This sample is fully interactive and changes nothing on your Mac.")
                    .font(.system(size: 14))
                    .foregroundStyle(TonicDS.Colors.textMuted)
            }

            previewInstrument

            Spacer()
            navigationButtons(primary: "Continue")
        }
        .padding(TonicDS.Space.xxxl)
    }

    @ViewBuilder
    private var previewInstrument: some View {
        if selectedGoals.contains(.windows) {
            VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                MonoLabel("Sample workspace")
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(TonicDS.Colors.console)
                    GeometryReader { proxy in
                        let frame = previewPlacement.frame(in: CGRect(origin: .zero, size: proxy.size)).insetBy(dx: 8, dy: 8)
                        RoundedRectangle(cornerRadius: 7)
                            .fill(TonicDS.Colors.brandAccent.opacity(0.78))
                            .frame(width: frame.width, height: frame.height)
                            .offset(x: frame.minX, y: proxy.size.height - frame.maxY)
                            .animation(TonicMotionPolicy(reduceMotion: reduceMotion).layout, value: previewPlacement)
                    }
                    .padding(6)
                }
                .frame(height: 210)
                HStack {
                    previewButton(.leftHalf)
                    previewButton(.maximize)
                    previewButton(.rightHalf)
                }
                Text("The live version previews this exact frame and keeps the previous frame ready to restore.")
                    .font(.system(size: 12))
                    .foregroundStyle(TonicDS.Colors.textMuted)
            }
        } else if selectedGoals.contains(.menuBar) {
            VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                MonoLabel("Sample menu bar")
                HStack(spacing: 8) {
                    ForEach(["wifi", "battery.75percent", "clock", "magnifyingglass"], id: \.self) { symbol in
                        Image(systemName: symbol)
                            .frame(width: 34, height: 30)
                            .background(TonicDS.Colors.softStone, in: RoundedRectangle(cornerRadius: 6))
                    }
                    Spacer()
                    Text("Visible")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(TonicDS.Colors.textMuted)
                }
                .padding(TonicDS.Space.md)
                .background(TonicDS.Colors.canvasSoft, in: RoundedRectangle(cornerRadius: 10))
                Text("In Tonic, edits are staged as you move items between Visible, On Demand, and Quiet, then applied once after review.")
                    .font(.system(size: 12)).foregroundStyle(TonicDS.Colors.textMuted)
            }
        } else {
            MetricConsole(
                title: "Processor · Live basic sample",
                value: String(format: "%.0f", metrics.cpuData.totalUsage),
                unit: "%",
                history: metrics.cpuHistory,
                status: TonicDS.statusLevel(forFraction: metrics.cpuData.totalUsage / 100)
            )
            Text("Basic processor and memory readings work before any additional access is granted.")
                .font(.system(size: 12)).foregroundStyle(TonicDS.Colors.textMuted)
        }
    }

    private func previewButton(_ action: WindowAction) -> some View {
        Button {
            previewPlacement = action
            TonicFeedback.alignment()
        } label: {
            Label(action.title, systemImage: action.symbol)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 38)
        }
        .buttonStyle(.bordered)
        .tint(previewPlacement == action ? TonicDS.Colors.brandAccent : nil)
    }

    private var accessPage: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
            VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                Text("Enable selected capabilities")
                    .font(.system(size: 34, weight: .medium))
                Text("Each request is tied to a visible benefit. You can skip everything and change it later in Access.")
                    .font(.system(size: 14))
                    .foregroundStyle(TonicDS.Colors.textMuted)
            }

            VStack(spacing: 0) {
                if needsAccessibility {
                    accessRow(
                        title: "Arrange windows and menu items",
                        detail: "Accessibility lets Tonic read and change only the window or menu item you act on.",
                        granted: permissions.permissionStatuses[.accessibility] == .authorized,
                        button: "Enable"
                    ) {
                        _ = permissions.requestAccessibility()
                    }
                    TonicHairline()
                }
                if needsFileAccess {
                    accessRow(
                        title: BuildCapabilities.current.requiresScopeAccess ? "Inspect chosen locations" : "Inspect storage and app files",
                        detail: BuildCapabilities.current.requiresScopeAccess
                            ? "Choose the folders or volumes Tonic may analyze. Everything else stays out of scope."
                            : "Full Disk Access enables complete size, leftover, and storage evidence.",
                        granted: permissions.hasFullDiskAccess,
                        button: BuildCapabilities.current.requiresScopeAccess ? "Choose Location" : "Open Settings"
                    ) {
                        _ = permissions.requestFullDiskAccess()
                    }
                }
                if !needsAccessibility && !needsFileAccess {
                    EvidenceRow(symbol: "checkmark.circle", title: "No additional access needed", reason: "Your selected monitoring features work with standard system readings.", metadata: nil) { EmptyView() }
                }
            }
            .background(TonicDS.Colors.canvasSoft, in: RoundedRectangle(cornerRadius: TonicDS.Radius.md))
            .overlay { RoundedRectangle(cornerRadius: TonicDS.Radius.md).strokeBorder(TonicDS.Colors.hairline, lineWidth: 1) }

            Spacer()
            navigationButtons(primary: "Continue")
        }
        .padding(TonicDS.Space.xxxl)
    }

    private func accessRow(title: String, detail: String, granted: Bool, button: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: TonicDS.Space.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(TonicDS.Colors.textMuted)
            }
            Spacer()
            if granted {
                Label("Enabled", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TonicDS.Colors.statusSuccess)
            } else {
                Button(button) {
                    action()
                    Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        await permissions.checkAllPermissions()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(TonicDS.Space.md)
    }

    private var readyPage: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(TonicDS.Colors.statusSuccess)
            Text("Tonic is configured for you.")
                .font(.system(size: 34, weight: .medium))
            Text("Your selected tools are ready in Daily Control and searchable from ⌘K. Permissions you skipped remain available in Access.")
                .font(.system(size: 14))
                .foregroundStyle(TonicDS.Colors.textMuted)
                .frame(maxWidth: 540, alignment: .leading)

            HStack(spacing: TonicDS.Space.xs) {
                ForEach(selectedGoals.sorted { $0.rawValue < $1.rawValue }) { goal in
                    Label(goal.title, systemImage: goal.symbol)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(TonicDS.Colors.softStone, in: Capsule())
                }
            }

            Spacer()
            HStack {
                Button("Back") { retreat() }.buttonStyle(.borderless)
                Spacer()
                PrimaryPill("Open Tonic", action: finish)
            }
        }
        .padding(TonicDS.Space.xxxl)
    }

    private var needsAccessibility: Bool {
        selectedGoals.contains(.windows) || selectedGoals.contains(.menuBar)
    }

    private var needsFileAccess: Bool {
        selectedGoals.contains(.storage) || selectedGoals.contains(.appCare)
    }

    private func navigationButtons(primary: String) -> some View {
        HStack {
            Button("Back", action: retreat).buttonStyle(.borderless)
            Spacer()
            Button("Skip for now") { advance() }.buttonStyle(.borderless)
            PrimaryPill(primary) { advance() }
        }
    }

    private func advance() {
        withAnimation(TonicMotionPolicy(reduceMotion: reduceMotion).transition) {
            page = min(pageCount - 1, page + 1)
        }
    }

    private func retreat() {
        withAnimation(TonicMotionPolicy(reduceMotion: reduceMotion).transition) {
            page = max(0, page - 1)
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        UserDefaults.standard.set(selectedGoals.map(\.rawValue), forKey: "tonic.onboarding.goals")
        UserDefaults.standard.set(true, forKey: "tonic.widget.hasCompletedOnboarding")
        WidgetCoordinator.shared.start()
        isPresented = false
    }
}
