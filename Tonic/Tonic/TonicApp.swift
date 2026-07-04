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

    var body: some Scene {
        WindowGroup {
            ContentView(showCommandPalette: $showCommandPalette)
        }
        .commands {
            // Primary navigation lives in the View menu with ⌘1–⌘5, like every
            // sidebar-driven native Mac app.
            CommandGroup(after: .sidebar) {
                Divider()
                navigationCommand("Home", .dashboard, "1")
                navigationCommand("Clean", .systemCleanup, "2")
                navigationCommand("Apps", .appManager, "3")
                navigationCommand("Monitor", .liveMonitoring, "4")
                navigationCommand("Settings", .settings, "5")
            }

            CommandMenu("Tools") {
                Button("Run Smart Scan") {
                    NotificationCenter.default.post(name: .runSmartScanCommand, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Scan Folder…") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.allowsMultipleSelection = false
                    panel.prompt = "Scan"
                    if panel.runModal() == .OK, let url = panel.url {
                        NotificationCenter.default.post(
                            name: .scanFolderCommand, object: nil,
                            userInfo: ["path": url.path]
                        )
                    }
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                Divider()
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

    private func navigationCommand(_ title: String, _ destination: NavigationDestination,
                                   _ key: KeyEquivalent) -> some View {
        Button(title) {
            NotificationCenter.default.post(
                name: .navigateToDestination, object: nil,
                userInfo: ["destination": destination.rawValue]
            )
        }
        .keyboardShortcut(key, modifiers: .command)
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
        let version = Bundle.main.appVersion
        let build = Bundle.main.buildNumber
        ActivityLogStore.shared.recordInstallIfNeeded(version: version, build: build)
        ActivityLogStore.shared.recordUpdateIfNeeded(version: version, build: build)

        // Daily disk-usage sample for the storage timeline and forecast.
        // Cheap no-op when today's sample already exists.
        Task.detached(priority: .utility) {
            DiskUsageHistoryStore.shared.recordSampleIfNeeded()
        }

        // Actionable notifications (Review / Open Apps) and the scheduled-
        // maintenance timer. The scheduler is a no-op while cadence is Off.
        NotificationDelegate.shared.install()
        MaintenanceScheduler.shared.start()

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

    func applicationDidBecomeActive(_ notification: Notification) {
        // Catch-up sample for instances that stay running across days.
        Task.detached(priority: .utility) {
            DiskUsageHistoryStore.shared.recordSampleIfNeeded()
        }
    }

    /// Folders dropped onto the Dock icon open the folder scan report.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.isFileURL {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(
                name: .scanFolderCommand, object: nil,
                userInfo: ["path": url.path]
            )
            return // one report at a time
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

        // Global console shortcut (Carbon hotkey; no-op until one is recorded).
        GlobalHotkeyManager.shared.start()

        // Bartender-style menu bar management (no-op until enabled in Monitor › Menu Bar).
        MenuBarManager.shared.start()
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
        let version = Bundle.main.appVersion
        let build = Bundle.main.buildNumber

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
