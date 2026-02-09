//
//  TonicApp.swift
//  Tonic
//
//  Native macOS system management utility
//

import SwiftUI

@main
struct TonicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showCommandPalette = false
    @State private var appIsHighContrast = false

    var body: some Scene {
        WindowGroup {
            ContentView(showCommandPalette: $showCommandPalette)
                .supportHighContrast()
        }
        .commands {
            // Command Palette
            CommandMenu("Tools") {
                Button("Command Palette") {
                    showCommandPalette = true
                }
                .keyboardShortcut("k", modifiers: .command)
            }

            // Replace default About menu item
            CommandGroup(replacing: .appInfo) {
                Button("About Tonic") {
                    appDelegate.showAbout()
                }
            }

            // Replace default Preferences menu item
            CommandGroup(replacing: .appSettings) {
                Button("Preferences...") {
                    appDelegate.showPreferences()
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            // Add application-specific commands
            CommandMenu("Help") {
                Divider()
                Button("Tonic Documentation") {
                    if let url = URL(string: "https://github.com/Saransh-Sharma/PreTonic") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("Report an Issue") {
                    if let url = URL(string: "https://github.com/Saransh-Sharma/PreTonic/issues") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set app activation policy to accessory for menu bar behavior
        // Use .regular for now to keep dock icon visible
        NSApp.setActivationPolicy(.regular)
        if let dockIcon = TonicBrandAssets.appNSImage()?.copy() as? NSImage {
            NSApp.applicationIconImage = dockIcon
        }

        // Initialize user defaults
        setupUserDefaults()

        // Log install/update activity
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        ActivityLogStore.shared.recordInstallIfNeeded(version: version, build: build)
        ActivityLogStore.shared.recordUpdateIfNeeded(version: version, build: build)

        // Apply saved theme preference
        applyThemePreference()

        // Start widget system after a brief delay to allow the UI to appear first
        // This prevents blocking the main thread during app launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.startWidgetSystem()
        }

        // Listen for theme changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: NSNotification.Name("TonicThemeDidChange"),
            object: nil
        )
    }

    @objc func themeDidChange() {
        applyThemePreference()
    }

    private func applyThemePreference() {
        let mode = AppearancePreferences.shared.themeMode
        switch mode {
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .system:
            NSApp.appearance = nil
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running when window is closed (menu bar app behavior)
        return false
    }

    @MainActor
    private func startWidgetSystem() {
        // Check if user has completed widget onboarding
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "tonic.widget.hasCompletedOnboarding")

        print("🔵 [TonicApp] startWidgetSystem called, hasCompletedOnboarding: \(hasCompletedOnboarding)")

        if hasCompletedOnboarding {
            // Start the widget coordinator to show menu bar widgets
            print("🔵 [TonicApp] Calling WidgetCoordinator.shared.start()")
            WidgetCoordinator.shared.start()
            print("🔵 [TonicApp] WidgetCoordinator.shared.start() completed")
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Show window when clicking dock icon
        if !flag {
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }

    func setupUserDefaults() {
        let defaults = UserDefaults.standard

        // Register default values
        defaults.register(defaults: [
            "firstLaunch": true,
            "scanEnabled": true,
            "notificationsEnabled": true,
            "autoCleanEnabled": false,
            "themePreference": "dark"
        ])
    }

    func showAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

        let alert = NSAlert()
        alert.messageText = "Tonic for Mac"
        alert.informativeText = """
        Version \(version) (Build \(build))

        A modern macOS system management utility.

        Monitor your system with customizable menu bar widgets,
        clean up disk space, and optimize your Mac's performance.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func showPreferences() {
        PreferencesWindowController.shared.showWindow()
    }

    func handleQuickScan() {
        // Trigger quick scan from menu bar
        print("Quick scan requested from menu bar")
    }

    func handleQuickClean() {
        // Trigger quick clean from menu bar
        print("Quick clean requested from menu bar")
    }
}
