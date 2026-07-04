//
//  KeyboardShortcutRecorder.swift
//  Tonic
//
//  Inline recorder for a global shortcut slot. Click to record, type a combo
//  with ⌘/⌃/⌥, Esc cancels, Delete clears. Backed by HotkeySettingsStore.
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

public struct KeyboardShortcutRecorder: View {
    let action: HotkeyAction

    @State private var store = HotkeySettingsStore.shared
    @State private var hotkeys = GlobalHotkeyManager.shared
    @State private var isRecording = false
    @State private var monitor = MonitorBox()

    /// Local-monitor token lives outside SwiftUI state diffing.
    final class MonitorBox {
        var token: Any?
    }

    /// Defaults to the console slot so the existing PopupSettings call site
    /// keeps working after generalization.
    public init(action: HotkeyAction = .toggleConsole) {
        self.action = action
    }

    private var currentDisplay: String? {
        store.spec(for: action)?.displayString
    }

    private var registrationFailed: Bool {
        hotkeys.registrationFailures.contains(action)
    }

    public var body: some View {
        HStack(spacing: TonicDS.Space.sm) {
            if registrationFailed {
                Text("In use by another app")
                    .tonicType(.caption)
                    .foregroundStyle(TonicDS.Colors.statusWarning)
            }
            Button {
                isRecording ? stopRecording() : startRecording()
            } label: {
                Text(isRecording ? "Type shortcut…" : (currentDisplay ?? "Record Shortcut"))
                    .tonicType(.monoLabel)
                    .foregroundStyle(isRecording ? TonicDS.Colors.accentCoral : TonicDS.Colors.textPrimary)
                    .frame(minWidth: 110)
                    .padding(.vertical, 5)
                    .padding(.horizontal, TonicDS.Space.sm)
                    .background(
                        RoundedRectangle(cornerRadius: TonicDS.Radius.xs)
                            .strokeBorder(isRecording ? TonicDS.Colors.accentCoral : TonicDS.Colors.hairline)
                    )
            }
            .buttonStyle(.plain)
            .tonicPointerCursor()
            .accessibilityLabel(currentDisplay.map { "Shortcut: \($0). Activate to change." } ?? "Record shortcut")

            if currentDisplay != nil, !isRecording {
                Button {
                    clearShortcut()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(TonicDS.Colors.textMuted)
                }
                .buttonStyle(.plain)
                .tonicPointerCursor()
                .accessibilityLabel("Clear shortcut")
            }
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        monitor.token = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil // swallow the keystroke while recording
        }
    }

    private func stopRecording() {
        isRecording = false
        if let token = monitor.token {
            NSEvent.removeMonitor(token)
            monitor.token = nil
        }
    }

    private func handle(_ event: NSEvent) {
        defer { stopRecording() }
        switch Int(event.keyCode) {
        case kVK_Escape:
            return
        case kVK_Delete, kVK_ForwardDelete:
            clearShortcut()
        default:
            guard let spec = ShortcutSpec(event: event) else { return }
            store.setShortcut(spec, for: action)
            GlobalHotkeyManager.shared.applyAll()
        }
    }

    private func clearShortcut() {
        store.setShortcut(nil, for: action)
        GlobalHotkeyManager.shared.applyAll()
    }
}
