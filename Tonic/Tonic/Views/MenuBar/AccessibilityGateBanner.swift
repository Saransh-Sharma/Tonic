//
//  AccessibilityGateBanner.swift
//  Tonic
//
//  Shown when a control feature (moving/activating items) needs Accessibility
//  permission that hasn't been granted. Polls AXIsProcessTrusted while visible
//  so it disappears the moment the user grants access.
//

import AppKit
import SwiftUI

struct AccessibilityGateBanner: View {
    @State private var trusted = AXIsProcessTrusted()
    @State private var pollTimer: Timer?

    var body: some View {
        Group {
            if !trusted {
                banner
            }
        }
        .onAppear { startPolling() }
        .onDisappear { stopPolling() }
    }

    private var banner: some View {
        HStack(alignment: .top, spacing: TonicDS.Space.md) {
            Image(systemName: "lock.shield")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(TonicDS.Colors.statusWarning)
            VStack(alignment: .leading, spacing: TonicDS.Space.xxs) {
                Text("Accessibility access required")
                    .tonicType(.cardHeading)
                    .foregroundStyle(TonicDS.Colors.textPrimary)
                Text("Tonic needs Accessibility permission to hide, show, and open other apps' menu bar items. Discovery works without it.")
                    .tonicType(.caption)
                    .foregroundStyle(TonicDS.Colors.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: TonicDS.Space.sm)
            TextAction("Grant Access", systemImage: "arrow.up.forward",
                       color: TonicDS.Colors.linkBlue) {
                _ = PermissionManager.shared.requestAccessibility()
            }
        }
        .padding(TonicDS.Space.md)
        .background(
            RoundedRectangle(cornerRadius: TonicDS.Radius.card, style: .continuous)
                .fill(TonicDS.Colors.statusWarning.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TonicDS.Radius.card, style: .continuous)
                .strokeBorder(TonicDS.Colors.statusWarning.opacity(0.3), lineWidth: 1)
        )
    }

    private func startPolling() {
        trusted = AXIsProcessTrusted()
        guard !trusted else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            let now = AXIsProcessTrusted()
            Task { @MainActor in
                trusted = now
                if now { stopPolling() }
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
