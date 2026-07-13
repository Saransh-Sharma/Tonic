//
//  WindowManagementView.swift
//  Tonic
//

import SwiftUI

struct WindowManagementView: View {
    @State private var service = WindowManagementService.shared
    @State private var store = WindowWorkspaceStore.shared
    @State private var hotkeyStore = HotkeySettingsStore.shared
    @State private var newWorkspaceName = ""
    @State private var ruleDisplayName: String?
    @State private var ruleWorkspaceID: UUID?
    @State private var showsFinerSizes = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let quickActions: [WindowAction] = [
        .topLeft, .topHalf, .topRight,
        .leftHalf, .maximize, .rightHalf,
        .bottomLeft, .bottomHalf, .bottomRight
    ]

    private let sixthActions: [WindowAction] = [
        .topLeftSixth, .topCenterSixth, .topRightSixth,
        .bottomLeftSixth, .bottomCenterSixth, .bottomRightSixth
    ]

    var body: some View {
        TonicScreenScaffold {
            content
        }
        .task {
            service.refresh()
            SnapDragController.shared.refresh()
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.xl) {
            InstrumentHeader("Windows", state: "Arrange the focused window with proof and one-step restore") {
                Button {
                    service.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }

            displayMap

            if service.isAccessibilityGranted {
                workspace
                workspacesCard
                displayRulesCard
                behaviorCard
            } else {
                permissionJourney
            }

            latestAction

            if let error = service.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 13))
                    .foregroundStyle(TonicDS.Colors.statusCritical)
                    .accessibilityLabel("Window action failed. \(error)")
            }
        }
        .animation(TonicMotionPolicy(reduceMotion: reduceMotion).proof, value: service.lastReceipt?.id)
    }

    @ViewBuilder
    private var latestAction: some View {
        if let receipt = service.lastReceipt {
            VStack(alignment: .leading, spacing: 0) {
                MonoLabel("Latest action")
                    .padding(.bottom, TonicDS.Space.xs)
                TonicHairline()
                ActionReceiptView(
                    receipt: receipt,
                    undo: service.canRestore ? { service.restoreLast() } : nil
                )
            }
            .transition(.opacity)
        }
    }

    private var displayMap: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
            HStack {
                MonoLabel("Displays")
                Spacer()
                Text("\(service.displays.count) connected")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(TonicDS.Colors.textMuted)
            }
            HStack(alignment: .bottom, spacing: TonicDS.Space.sm) {
                ForEach(service.displays) { display in
                    VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                        ZStack {
                            RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous)
                                .fill(TonicDS.Colors.console)
                            RoundedRectangle(cornerRadius: TonicDS.Radius.xs, style: .continuous)
                                .fill(TonicDS.Colors.brandAccent.opacity(display.isMain ? 0.32 : 0.13))
                                .padding(8)
                            Image(systemName: display.isMain ? "macbook" : "display")
                                .foregroundStyle(TonicDS.Colors.onDark)
                        }
                        .frame(width: display.isMain ? 190 : 150, height: display.isMain ? 108 : 86)
                        Text(display.name)
                            .font(.system(size: 12, weight: .medium))
                        Text("\(Int(display.frame.width))×\(Int(display.frame.height)) · \(display.scale, specifier: "%.0f")×")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(TonicDS.Colors.textMuted)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TonicDS.Space.md)
            .background(TonicDS.Colors.softStone, in: RoundedRectangle(cornerRadius: TonicDS.Radius.md))
        }
    }

    private var workspace: some View {
        HStack(alignment: .top, spacing: TonicDS.Space.xl) {
            VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
                MonoLabel("Spatial command HUD")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: TonicDS.Space.xs), count: 3), spacing: TonicDS.Space.xs) {
                    ForEach(quickActions) { action in
                        layoutButton(action)
                    }
                }
                HStack(spacing: TonicDS.Space.xs) {
                    layoutButton(.centered)
                    layoutButton(.leftTwoThirds)
                    layoutButton(.rightTwoThirds)
                }
                HStack(spacing: TonicDS.Space.xs) {
                    layoutButton(.leftThird)
                    layoutButton(.centerThird)
                    layoutButton(.rightThird)
                }
                if service.displays.count > 1 {
                    HStack(spacing: TonicDS.Space.xs) {
                        layoutButton(.previousDisplay)
                        layoutButton(.nextDisplay)
                    }
                }

                Button {
                    showsFinerSizes.toggle()
                } label: {
                    HStack(spacing: TonicDS.Space.xxs) {
                        Image(systemName: showsFinerSizes ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Sixths grid")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(TonicDS.Colors.textMuted)
                }
                .buttonStyle(.plain)
                .tonicPointerCursor()
                .accessibilityLabel(showsFinerSizes ? "Hide sixths grid" : "Show sixths grid")

                if showsFinerSizes {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: TonicDS.Space.xs), count: 3),
                              spacing: TonicDS.Space.xs) {
                        ForEach(sixthActions) { action in
                            layoutButton(action)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: 520)
            .animation(TonicMotionPolicy(reduceMotion: reduceMotion).transition, value: showsFinerSizes)

            VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                MonoLabel("Focused window")
                if let appName = service.focusedAppName {
                    VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                        Text(appName)
                            .font(.system(size: 17, weight: .semibold))
                        Text(service.focusedWindowTitle ?? "Untitled window")
                            .font(.system(size: 13))
                            .foregroundStyle(TonicDS.Colors.textMuted)
                        if let frame = service.focusedFrame {
                            Text("\(Int(frame.width))×\(Int(frame.height))  x \(Int(frame.minX))  y \(Int(frame.minY))")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(TonicDS.Colors.textMuted)
                        }
                    }
                } else {
                    Text("Focus a standard app window, then choose a placement.")
                        .font(.system(size: 13))
                        .foregroundStyle(TonicDS.Colors.textMuted)
                }

                TonicHairline()

                VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
                    Text("The exact resulting frame is shown before placement.")
                    Text("Your previous frame remains available until the next window action.")
                }
                .font(.system(size: 12))
                .foregroundStyle(TonicDS.Colors.textMuted)

                if service.canRestore {
                    Button("Restore previous frame", action: service.restoreLast)
                        .buttonStyle(.bordered)
                }
            }
            .padding(TonicDS.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TonicDS.Colors.canvasSoft, in: RoundedRectangle(cornerRadius: TonicDS.Radius.md))
        }
    }

    // MARK: - Workspaces

    private var workspacesCard: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
            MonoLabel("Workspaces")

            SettingsPanel(title: nil) {
                TonicPreferenceRow(
                    title: "Capture current arrangement",
                    description: "Saves the frame of every standard window so the whole desk can be restored later.",
                    showsDivider: !store.workspaces.isEmpty
                ) {
                    HStack(spacing: TonicDS.Space.xs) {
                        TextField("Workspace name", text: $newWorkspaceName)
                            .textFieldStyle(.plain)
                            .tonicType(.body)
                            .frame(width: 160)
                            .padding(.horizontal, TonicDS.Space.sm)
                            .frame(height: TonicDS.Layout.inputHeight)
                            .tonicSurface(.surface,
                                          in: RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous),
                                          flatStroke: TonicDS.Colors.hairline)
                        PrimaryPill("Capture") {
                            let name = newWorkspaceName.trimmingCharacters(in: .whitespaces)
                            guard !name.isEmpty else { return }
                            if service.captureWorkspace(named: name) != nil {
                                newWorkspaceName = ""
                            }
                        }
                    }
                }

                ForEach(Array(store.workspaces.enumerated()), id: \.element.id) { index, workspace in
                    TonicPreferenceRow(
                        title: workspace.name,
                        description: workspaceSummary(workspace),
                        showsDivider: index < store.workspaces.count - 1
                    ) {
                        HStack(spacing: TonicDS.Space.sm) {
                            Button {
                                service.apply(workspace)
                            } label: {
                                Text("Apply").tonicType(.button)
                                    .foregroundStyle(TonicDS.Colors.linkBlue)
                            }
                            .buttonStyle(.plain)
                            .tonicPointerCursor()
                            Button {
                                store.removeWorkspace(id: workspace.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundStyle(TonicDS.Colors.textMuted)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete workspace \(workspace.name)")
                            .tonicPointerCursor()
                        }
                    }
                }
            }
        }
    }

    private func workspaceSummary(_ workspace: WindowWorkspace) -> String {
        let apps = workspace.appNames
        let shown = apps.prefix(3).joined(separator: ", ")
        let more = apps.count > 3 ? " + \(apps.count - 3) more" : ""
        return "\(workspace.windows.count) windows · \(shown)\(more)"
    }

    // MARK: - Display rules

    @ViewBuilder
    private var displayRulesCard: some View {
        if !store.workspaces.isEmpty {
            VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
                MonoLabel("Display rules")

                SettingsPanel(title: nil) {
                    ForEach(Array(store.displayRules.enumerated()), id: \.element.id) { index, rule in
                        TonicPreferenceRow(
                            title: "When \(rule.display.name) connects",
                            description: "Apply \u{201C}\(store.workspace(id: rule.workspaceID)?.name ?? "deleted workspace")\u{201D}",
                            showsDivider: true
                        ) {
                            HStack(spacing: TonicDS.Space.sm) {
                                Toggle("", isOn: Binding(
                                    get: { rule.isEnabled },
                                    set: { enabled in
                                        var updated = rule
                                        updated.isEnabled = enabled
                                        store.update(updated)
                                    }
                                ))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .tint(TonicDS.Colors.ink)
                                Button {
                                    store.removeRule(id: rule.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundStyle(TonicDS.Colors.textMuted)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Delete rule for \(rule.display.name)")
                                .tonicPointerCursor()
                            }
                        }
                    }

                    TonicPreferenceRow(
                        title: "Add rule",
                        description: "Auto-apply a workspace when a display connects.",
                        showsDivider: false
                    ) {
                        HStack(spacing: TonicDS.Space.xs) {
                            Picker("Display", selection: $ruleDisplayName) {
                                Text("Display…").tag(String?.none)
                                ForEach(service.displays) { display in
                                    Text(display.name).tag(String?.some(display.name))
                                }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                            Picker("Workspace", selection: $ruleWorkspaceID) {
                                Text("Workspace…").tag(UUID?.none)
                                ForEach(store.workspaces) { workspace in
                                    Text(workspace.name).tag(UUID?.some(workspace.id))
                                }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                            Button {
                                addRule()
                            } label: {
                                Text("Add").tonicType(.button)
                                    .foregroundStyle(TonicDS.Colors.linkBlue)
                            }
                            .buttonStyle(.plain)
                            .disabled(ruleDisplayName == nil || ruleWorkspaceID == nil)
                            .tonicPointerCursor()
                        }
                    }
                }
            }
        }
    }

    private func addRule() {
        guard let name = ruleDisplayName,
              let workspaceID = ruleWorkspaceID,
              let display = service.displays.first(where: { $0.name == name }) else { return }
        store.add(DisplayRule(
            display: DisplaySignature(name: display.name,
                                      width: Int(display.frame.width),
                                      height: Int(display.frame.height),
                                      scale: Double(display.scale)),
            workspaceID: workspaceID
        ))
        ruleDisplayName = nil
        ruleWorkspaceID = nil
    }

    // MARK: - Behavior

    private var behaviorCard: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
            MonoLabel("Behavior")
            SettingsPanel(title: nil) {
                TonicToggleRow(
                    title: "Cycle sizes on repeat",
                    description: "Pressing Left or Right Half again steps through ½ → ⅓ → ⅔.",
                    isOn: Binding(get: { store.cyclingEnabled },
                                  set: { store.cyclingEnabled = $0 })
                )
                TonicToggleRow(
                    title: "Snap by dragging to screen edges",
                    description: "Drag a window to an edge or corner to preview and place it in that zone.",
                    isOn: Binding(get: { store.snapEnabled },
                                  set: { enabled in
                                      store.snapEnabled = enabled
                                      SnapDragController.shared.refresh()
                                  })
                )
                TonicPreferenceRow(
                    title: "Gap between windows",
                    description: "Breathing room around tiled windows. Zero keeps them flush.",
                    showsDivider: true
                ) {
                    HStack(spacing: TonicDS.Space.sm) {
                        WindowGapPreview(gap: store.windowGap)
                        Slider(
                            value: windowGapBinding,
                            in: 0...WindowWorkspaceStore.maxWindowGap,
                            step: 2
                        )
                        .frame(width: 140)
                        .accessibilityLabel("Gap between windows")
                        Text("\(Int(store.windowGap)) pt")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(TonicDS.Colors.textMuted)
                            .frame(width: 38, alignment: .trailing)
                    }
                }
                if !hasAnyWindowShortcut {
                    TonicPreferenceRow(
                        title: "Recommended shortcuts",
                        description: "Fill only unbound placements with the familiar ⌃⌥ layout. Existing shortcuts are never replaced."
                    ) {
                        TextAction("Enable") {
                            HotkeySettingsStore.shared.enableRecommendedWindowDefaults()
                            GlobalHotkeyManager.shared.applyAll()
                            TonicFeedback.alignment()
                        }
                    }
                }
                TonicPreferenceRow(
                    title: "Keyboard shortcuts",
                    description: "Every placement is bindable. Record combos or enable the ⌃⌥ defaults in Settings → Shortcuts.",
                    showsDivider: false
                ) {
                    TextAction("Open Shortcuts") {
                        NotificationCenter.default.post(
                            name: .navigateToDestination,
                            object: nil,
                            userInfo: ["destination": NavigationDestination.settings.rawValue]
                        )
                        NotificationCenter.default.post(
                            name: .openSettingsSection,
                            object: nil,
                            userInfo: [SettingsDeepLinkUserInfoKey.section: SettingsSection.shortcuts.rawValue]
                        )
                    }
                }
            }
        }
    }

    private var windowGapBinding: Binding<Double> {
        Binding(get: { store.windowGap }, set: { store.windowGap = $0 })
    }

    private var hasAnyWindowShortcut: Bool {
        WindowAction.allCases.contains { hotkeyStore.spec(for: .window($0)) != nil }
    }

    private func layoutButton(_ action: WindowAction) -> some View {
        let isPreviewed = service.previewAction == action
        return Button {
            service.perform(action)
        } label: {
            VStack(spacing: TonicDS.Space.xxs) {
                Image(systemName: action.symbol)
                    .font(.system(size: 19, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                Text(action.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                if let shortcut = hotkeyStore.spec(for: .window(action))?.displayString {
                    Text(shortcut)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(isPreviewed ? TonicDS.Colors.onDarkMuted : TonicDS.Colors.textMuted)
                }
            }
            .foregroundStyle(isPreviewed ? TonicDS.Colors.onDark : TonicDS.Colors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(
                isPreviewed ? TonicDS.Colors.deepGreen : TonicDS.Colors.softStone,
                in: RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous)
                    .strokeBorder(isPreviewed ? TonicDS.Colors.brandAccent : TonicDS.Colors.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(TonicPressStyle())
        .tonicFocusableControl(radius: TonicDS.Radius.sm)
        .onHover { service.setPreview($0 ? action : nil) }
        .accessibilityHint("Moves the focused window to \(action.title.lowercased()). The previous frame can be restored.")
    }

    private var permissionJourney: some View {
        EmptyLesson(
            title: "Let Tonic arrange your windows",
            message: "Accessibility lets Tonic read the focused window's frame and move it when you choose a layout. Monitoring and Care continue to work if you decline."
        ) {
            HStack(spacing: 8) {
                ForEach([WindowAction.leftHalf, .rightHalf], id: \.self) { action in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(TonicDS.Colors.brandAccent.opacity(0.22))
                        .overlay(Image(systemName: action.symbol).foregroundStyle(TonicDS.Colors.brandAccent))
                }
            }
            .padding(8)
            .background(TonicDS.Colors.console, in: RoundedRectangle(cornerRadius: 10))
            .frame(width: 180)
        } actions: {
            HStack {
                PrimaryPill("Open Accessibility Settings") {
                    service.requestAccessibility()
                }
                Button("Check Again") { service.refresh() }
                    .buttonStyle(.bordered)
            }
        }
    }
}

private struct WindowGapPreview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let gap: Double

    private var scaledGap: CGFloat { CGFloat(gap) * 0.28 }

    var body: some View {
        HStack(spacing: scaledGap) {
            previewPane
            previewPane
        }
        .padding(scaledGap + 3)
        .frame(width: 78, height: 46)
        .background(TonicDS.Colors.console,
                    in: RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TonicDS.Radius.sm, style: .continuous)
                .strokeBorder(TonicDS.Colors.hairlineOnDark)
        }
        .animation(TonicMotionPolicy(reduceMotion: reduceMotion).morph, value: gap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Window gap preview, \(Int(gap)) points")
    }

    private var previewPane: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(TonicDS.Colors.brandAccent.opacity(0.72))
    }
}
