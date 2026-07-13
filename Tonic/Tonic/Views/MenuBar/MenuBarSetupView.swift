//
//  MenuBarSetupView.swift
//  Tonic
//
//  Compact three-step, trust-first setup for Menu Bar management.
//

import ApplicationServices
import SwiftUI

struct MenuBarSetupView: View {
    let items: [MenuBarItemInfo]
    let canMoveForeignItems: Bool
    let onApply: (MenuBarLayoutMode, [MenuBarRecommendation]) -> Void
    let onDefer: () -> Void

    @State private var step = 0
    @State private var mode: MenuBarLayoutMode = .onDemand
    @State private var recommendations: [MenuBarRecommendation] = []
    @State private var selectedKeys = Set<String>()
    @State private var awaitingAccessibility = false
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @Environment(\.scenePhase) private var scenePhase

    private let planner = MenuBarRecommendationPlanner()

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 26, weight: .bold))
                    Text(subtitle).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(step + 1) of 3").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }

            Group {
                switch step {
                case 0: modeStep
                case 1: accessStep
                default: reviewStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack {
                Button(step == 0 ? "Not Now" : "Back") {
                    if step == 0 { onDefer() } else { step -= 1 }
                }
                .buttonStyle(.bordered)
                Spacer()
                PrimaryPill(primaryActionTitle) {
                    if step < 2 { step += 1 } else { apply() }
                }
            }
        }
        .padding(32)
        .frame(minWidth: 680, minHeight: 520)
        .accessibilityIdentifier("menu-bar-setup-step-\(step + 1)")
        .onAppear {
            recommendations = planner.recommendations(for: items.map(candidate))
            selectedKeys = canMoveForeignItems
                ? Set(recommendations.filter(\.isPreselected).map(\.stableKey)) : []
            accessibilityGranted = AXIsProcessTrusted()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            accessibilityGranted = AXIsProcessTrusted()
            if awaitingAccessibility, accessibilityGranted {
                awaitingAccessibility = false
                finishApply()
            }
        }
    }

    private var title: String {
        ["Clean up without losing control", "Access, only when it is needed", "Review every suggestion"][step]
    }

    private var subtitle: String {
        ["Choose how Tonic maintains your layout.", "Discovery works without Screen Recording.",
         "Tonic never recommends Quiet automatically."][step]
    }

    private var modeStep: some View {
        HStack(spacing: 16) {
            modeCard(.onDemand, symbol: "cursorarrow.click", detail: "Tonic moves items only after you review and Apply. Recommended.")
            modeCard(.live, symbol: "arrow.triangle.2.circlepath", detail: "Reapplies after apps change. May briefly interrupt the pointer.")
        }
    }

    private func modeCard(_ value: MenuBarLayoutMode, symbol: String, detail: String) -> some View {
        Button { mode = value } label: {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: symbol).font(.system(size: 28, weight: .medium)).foregroundStyle(.tint)
                Text(value.title).font(.title3.bold())
                Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer()
                Label(mode == value ? "Selected" : "Select",
                      systemImage: mode == value ? "checkmark.circle.fill" : "circle")
            }
            .padding(20).frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(mode == value ? Color.accentColor : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(mode == value ? .isSelected : [])
    }

    private var accessStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            permissionRow(symbol: "eye", title: "Metadata discovery",
                          detail: "Available now. Tonic reads item owner and geometry, not screen contents.", available: true)
            permissionRow(symbol: "accessibility", title: "Accessibility",
                          detail: canMoveForeignItems
                            ? (accessibilityGranted
                               ? "Granted. Tonic can move only the items you approve."
                               : "Requested only when you press Apply, so Tonic can move the reviewed items.")
                            : "The Store edition keeps foreign placement manual; Tonic-owned items still apply normally.",
                          available: canMoveForeignItems && accessibilityGranted)
            permissionRow(symbol: "record.circle", title: "Screen Recording",
                          detail: "Not requested during setup. It is optional for rich imagery and update watching.", available: false)
        }
    }

    private func permissionRow(symbol: String, title: String, detail: String, available: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).frame(width: 28).font(.title3)
                .foregroundStyle(available ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: available ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(available ? Color.green : Color.secondary)
        }
        .padding(16).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }

    private var reviewStep: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(recommendations) { recommendation in
                    Toggle(isOn: recommendationSelection(recommendation)) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: recommendation.target == .hidden ? "eye.slash" : "eye")
                            .frame(width: 22)
                            .foregroundStyle(selectedKeys.contains(recommendation.stableKey) ? Color.accentColor : Color.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(ownerName(for: recommendation.stableKey)).font(.headline)
                            Text(recommendation.reason).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(recommendation.target.displayName).font(.caption.weight(.semibold))
                            Text(confidenceTitle(recommendation.confidence))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    }
                    .toggleStyle(.checkbox)
                    .disabled(recommendation.confidence != .high || !canMoveForeignItems)
                    .padding(12).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                }
                if recommendations.isEmpty {
                    ContentUnavailableView("No items found", systemImage: "menubar.rectangle",
                                           description: Text("Tonic will keep scanning after setup."))
                }
            }
        }
    }

    private func apply() {
        if requiresAccessibility && !AXIsProcessTrusted() {
            awaitingAccessibility = true
            _ = PermissionManager.shared.requestAccessibility()
            return
        }
        finishApply()
    }

    private var requiresAccessibility: Bool {
        canMoveForeignItems && recommendations.contains { selectedKeys.contains($0.stableKey) && $0.target != .visible }
    }

    private var primaryActionTitle: String {
        guard step == 2 else { return "Continue" }
        if !canMoveForeignItems { return "Finish Setup" }
        if awaitingAccessibility { return "Waiting for Accessibility…" }
        return requiresAccessibility && !accessibilityGranted ? "Allow & Apply Cleanup" : "Apply Cleanup"
    }

    private func finishApply() {
        let reviewed = recommendations.map { recommendation in
            var result = recommendation
            result.isPreselected = selectedKeys.contains(recommendation.stableKey)
            return result
        }
        onApply(mode, reviewed)
    }

    private func recommendationSelection(_ recommendation: MenuBarRecommendation) -> Binding<Bool> {
        Binding(get: { selectedKeys.contains(recommendation.stableKey) }, set: { selected in
            if selected { selectedKeys.insert(recommendation.stableKey) }
            else { selectedKeys.remove(recommendation.stableKey) }
        })
    }

    private func confidenceTitle(_ confidence: MenuBarRecommendation.Confidence) -> String {
        switch confidence {
        case .protected: "Protected"
        case .high: "High confidence"
        case .insufficient: "Kept by default"
        }
    }

    private func candidate(_ item: MenuBarItemInfo) -> MenuBarRecommendationCandidate {
        .init(stableKey: item.stableKey, ownerName: item.ownerName,
              bundleIdentifier: item.bundleIdentifier, isSystemControlled: item.isSystemControlled)
    }

    private func ownerName(for key: String) -> String {
        items.first(where: { $0.stableKey == key })?.ownerName ?? "Menu bar item"
    }
}
