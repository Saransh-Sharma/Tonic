import AppKit
import Foundation
import SwiftUI
@testable import Tonic

@MainActor
final class CaptureHost<Content: View> {
    private let window: NSWindow
    private let host: NSHostingView<AnyView>
    let size: CGSize

    init(size: CGSize, content: Content) {
        self.size = size
        self.host = NSHostingView(rootView: AnyView(
            content
                .frame(width: size.width, height: size.height)
                .environment(\.colorScheme, .dark)
        ))
        self.host.frame = NSRect(origin: .zero, size: size)
        self.window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.window.contentView = host
        self.window.backgroundColor = .windowBackgroundColor
        self.window.isReleasedWhenClosed = false
    }

    func show() {
        window.orderFrontRegardless()
        window.displayIfNeeded()
    }

    func click(x: CGFloat, yFromTop: CGFloat) async {
        let point = NSPoint(x: x, y: size.height - yFromTop)
        let down = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: point,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )
        let up = NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: point,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 0
        )
        if let down { NSApp.sendEvent(down) }
        if let up { NSApp.sendEvent(up) }
        await settle(0.5)
    }

    func snapshot(to url: URL) throws {
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw NSError(domain: "HandoffRenderer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not allocate bitmap representation"])
        }
        rep.size = host.bounds.size
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "HandoffRenderer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }
}

@MainActor
func settle(_ seconds: Double = 0.75) async {
    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    NSApp.windows.forEach { $0.displayIfNeeded() }
}

@MainActor
func capture<Content: View>(_ relativePath: String, size: CGSize = CGSize(width: 1280, height: 820), base: URL, content: Content) async throws {
    log("capture \(relativePath)")
    let host = CaptureHost(size: size, content: content)
    host.show()
    await settle()
    try host.snapshot(to: base.appendingPathComponent(relativePath))
    await host.click(x: -1000, yFromTop: -1000)
}

@MainActor
func captureInteractive<Content: View>(_ relativePath: String, size: CGSize, base: URL, content: Content, actions: (CaptureHost<Content>) async throws -> Void) async throws {
    log("capture \(relativePath)")
    let host = CaptureHost(size: size, content: content)
    host.show()
    await settle()
    try await actions(host)
    try host.snapshot(to: base.appendingPathComponent(relativePath))
}

func log(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
}

@MainActor
func setSafeDefaults() {
    let defaults = UserDefaults.standard
    defaults.set(true, forKey: "hasSeenOnboarding")
    defaults.set(true, forKey: "hasCompletedWidgetOnboarding")
    defaults.set(true, forKey: "hasSeenFeatureTour")
    defaults.set(true, forKey: "tonic.widget.hasCompletedOnboarding")
    defaults.set("Dark", forKey: "tonic.appearance.themeMode")
    defaults.set(true, forKey: "tonic.appearance.reduceTransparency")
    defaults.set(false, forKey: TonicUserDefaultsKey.powerUserModeEnabled)
    WIPFeature.allCases.forEach { FeatureFlags.set($0, enabled: true) }
}

@main
struct HandoffRenderer {
    @MainActor
    static func main() async {
        guard CommandLine.arguments.count > 1 else {
            fputs("usage: HandoffRenderer <screenshots-dir>\n", stderr)
            exit(2)
        }

        NSApplication.shared.setActivationPolicy(.accessory)
        setSafeDefaults()

        let base = URL(fileURLWithPath: CommandLine.arguments[1])

        do {
            try await capture("00-app-shell/00-app-shell__direct__main-window-dashboard.png", base: base, content: ContentView(showCommandPalette: .constant(false)))
            try await capture("00-app-shell/00-app-shell__direct__command-palette.png", base: base, content: CommandPaletteView(isPresented: .constant(true), selectedDestination: .constant(.dashboard)))
            try await capture("00-app-shell/00-app-shell__direct__permission-prompt-full-disk.png", size: CGSize(width: 560, height: 440), base: base, content: PermissionPromptView(feature: .diskScan, isPresented: .constant(true)))
            try await capture("00-app-shell/00-app-shell__direct__permission-required-full-disk.png", base: base, content: PermissionRequiredView(icon: "externaldrive.fill", title: "Full Disk Access Required", description: "Storage Intelligence Hub needs Full Disk Access to scan all directories on your Mac.", onGrantPermission: {}))

            let onboarding = CaptureHost(size: CGSize(width: 580, height: 640), content: UnifiedOnboardingView(isPresented: .constant(true)))
            onboarding.show()
            await settle(1.0)
            for index in 1...7 {
                try onboarding.snapshot(to: base.appendingPathComponent("01-onboarding/01-onboarding__direct__page-\(String(format: "%02d", index)).png"))
                if index < 7 {
                    await onboarding.click(x: 522, yFromTop: 603)
                }
            }

            try await capture("02-dashboard/02-dashboard__direct__default.png", base: base, content: DashboardHomeView(scanManager: SmartScanManager(), selectedDestination: .constant(.dashboard)))
            try await captureInteractive("02-dashboard/02-dashboard__direct__health-popover.png", size: CGSize(width: 1280, height: 820), base: base, content: DashboardHomeView(scanManager: SmartScanManager(), selectedDestination: .constant(.dashboard))) { host in
                await host.click(x: 1155, yFromTop: 80)
            }

            let smartCareSession = SmartCareSessionStore()
            try await capture("03-smart-scan/03-smart-scan__direct__ready.png", base: base, content: SmartCareView(smartCareSession: smartCareSession))
            try await capture("03-smart-scan/03-smart-scan__direct__space-manager-empty.png", base: base, content: SpaceManagerView(domainResult: nil, focus: .spaceRoot, selectedItemIDs: .constant([]), onBack: {}, onRunSelected: { _ in }))
            try await capture("03-smart-scan/03-smart-scan__direct__performance-manager-empty.png", base: base, content: PerformanceManagerView(domainResult: nil, focus: .root(), selectedItemIDs: .constant([]), onBack: {}, onRunSelected: { _ in }))
            try await capture("03-smart-scan/03-smart-scan__direct__apps-manager-empty.png", base: base, content: AppsManagerView(domainResult: nil, focus: .root(), selectedItemIDs: .constant([]), onBack: {}, onRunSelected: { _ in }))

            try await capture("04-storage-hub/04-storage-hub__direct__default.png", base: base, content: DiskAnalysisView())
            try await capture("05-app-manager/05-app-manager__direct__default.png", base: base, content: AppManagerView())
            try await capture("06-recently-cleaned/06-recently-cleaned__direct__empty-or-current.png", base: base, content: RecentlyCleanedView())
            try await capture("07-activity/07-activity__direct__live-monitoring.png", base: base, content: SystemStatusDashboard(isActive: true))
            try await capture("08-menu-bar-widgets/08-menu-bar-widgets__direct__customization.png", base: base, content: WidgetCustomizationView())
            try await captureInteractive("08-menu-bar-widgets/08-menu-bar-widgets__direct__reset-alert.png", size: CGSize(width: 1280, height: 820), base: base, content: WidgetCustomizationView()) { host in
                await host.click(x: 1195, yFromTop: 64)
            }
            try await captureInteractive("08-menu-bar-widgets/08-menu-bar-widgets__direct__notification-settings-sheet.png", size: CGSize(width: 1280, height: 820), base: base, content: WidgetCustomizationView()) { host in
                await host.click(x: 1160, yFromTop: 780)
            }

            let preferences = CaptureHost(size: CGSize(width: 1120, height: 760), content: PreferencesView())
            preferences.show()
            await settle()
            for section in SettingsSection.allCases {
                NotificationCenter.default.post(name: .openSettingsSection, object: nil, userInfo: [SettingsDeepLinkUserInfoKey.section: section.rawValue])
                await settle(0.5)
                let slug = section.rawValue.lowercased().replacingOccurrences(of: " ", with: "-")
                try preferences.snapshot(to: base.appendingPathComponent("09-preferences/09-preferences__direct__\(slug).png"))
            }

            try await capture("10-menu-bar-surfaces/10-menu-bar-surfaces__direct__oneview-compact.png", size: CGSize(width: 560, height: 260), base: base, content: OneViewContentView())
            try await capture("10-menu-bar-surfaces/10-menu-bar-surfaces__direct__cpu-popover.png", size: CGSize(width: 360, height: 620), base: base, content: CPUPopoverView())
            try await capture("10-menu-bar-surfaces/10-menu-bar-surfaces__direct__memory-popover.png", size: CGSize(width: 360, height: 620), base: base, content: MemoryPopoverView())
            try await capture("10-menu-bar-surfaces/10-menu-bar-surfaces__direct__disk-popover.png", size: CGSize(width: 360, height: 620), base: base, content: DiskPopoverView())
            try await capture("10-menu-bar-surfaces/10-menu-bar-surfaces__direct__network-popover.png", size: CGSize(width: 360, height: 620), base: base, content: NetworkPopoverView())
            try await capture("10-menu-bar-surfaces/10-menu-bar-surfaces__direct__battery-popover.png", size: CGSize(width: 360, height: 620), base: base, content: BatteryPopoverView())
            try await capture("10-menu-bar-surfaces/10-menu-bar-surfaces__direct__clock-detail.png", size: CGSize(width: 360, height: 620), base: base, content: ClockDetailView())
            try await capture("10-menu-bar-surfaces/10-menu-bar-surfaces__direct__bluetooth-popover.png", size: CGSize(width: 360, height: 620), base: base, content: BluetoothPopoverView())
            try await capture("10-menu-bar-surfaces/10-menu-bar-surfaces__direct__weather-detail.png", size: CGSize(width: 360, height: 620), base: base, content: WeatherDetailView())
            try await capture("10-menu-bar-surfaces/10-menu-bar-surfaces__direct__sensors-popover.png", size: CGSize(width: 360, height: 620), base: base, content: SensorsPopoverView())
            try await capture("10-menu-bar-surfaces/10-menu-bar-surfaces__direct__gpu-popover.png", size: CGSize(width: 360, height: 620), base: base, content: GPUPopoverView())
            try await capture("10-menu-bar-surfaces/10-menu-bar-surfaces__direct__tabbed-widget-settings.png", size: CGSize(width: 540, height: 480), base: base, content: TabbedSettingsView())

            try await capture("11-debug-wip/11-debug-wip__direct__developer-tools.png", base: base, content: DeveloperToolsView())
            try await capture("11-debug-wip/11-debug-wip__direct__design-sandbox.png", base: base, content: DesignSandboxView())
        } catch {
            fputs("HandoffRenderer failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
