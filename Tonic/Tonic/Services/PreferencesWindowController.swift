//
//  PreferencesWindowController.swift
//  Tonic
//
//  Hosts the consolidated Settings in a standalone window (Cmd+,). Extracted from the
//  legacy PreferencesView during the presentation-layer rewrite; now hosts SettingsView.
//

import SwiftUI
import AppKit

@MainActor
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func showWindow() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Settings"
        win.minSize = NSSize(width: 760, height: 520)
        win.contentView = NSHostingView(rootView: SettingsView())
        win.center()
        win.delegate = self
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = win
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
