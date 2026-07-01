import AppKit
import CoreGraphics
import Foundation
import SwiftUI

struct ScreenshotRecord {
    let path: String
    let build: String
    let label: String
    let width: Int
    let height: Int
    let method: String
    let notes: String
}

@MainActor
final class HandoffRun {
    private let base: URL
    private let buildLabel: String
    private var records: [ScreenshotRecord] = []

    init(base: URL, buildLabel: String) {
        self.base = base
        self.buildLabel = buildLabel
    }

    func run() async throws {
        setSafeDefaults()
        seedSanitizedFixtures()

        try await captureNativeWindow(
            "00-app-shell/00-app-shell__\(buildLabel)__native-main-window.png",
            label: "Native Main Window",
            size: CGSize(width: 1280, height: 820),
            notes: "Native NSWindow capture for shell/window fidelity",
            content: HandoffShellView()
        )
        try await capture(
            "00-app-shell/00-app-shell__\(buildLabel)__main-window-dashboard.png",
            label: "Main Window Dashboard",
            content: HandoffShellView()
        )
        try await capture(
            "00-app-shell/00-app-shell__\(buildLabel)__command-palette.png",
            label: "Command Palette",
            content: CommandPaletteView(isPresented: .constant(true), selectedDestination: .constant(.dashboard))
        )
        try await capture(
            "00-app-shell/00-app-shell__\(buildLabel)__permission-prompt-access.png",
            label: "Permission Prompt Access",
            size: CGSize(width: 560, height: 440),
            content: PermissionPromptView(feature: .diskScan, isPresented: .constant(true))
        )
        try await capture(
            "00-app-shell/00-app-shell__\(buildLabel)__permission-required-app-manager.png",
            label: "Permission Required App Manager",
            content: PermissionRequiredView(
                icon: "externaldrive.fill",
                title: BuildCapabilities.current.requiresScopeAccess ? "Authorized Location Required" : "Full Disk Access Required",
                description: BuildCapabilities.current.requiresScopeAccess
                    ? "App Manager needs an authorized location before it can inspect apps and support files."
                    : "App Manager needs Full Disk Access to scan installed applications and support files.",
                onGrantPermission: {}
            )
        )

        try await captureOnboarding()

        let dashboardReady = SmartScanManager()
        try await capture(
            "02-home-dashboard/02-home-dashboard__\(buildLabel)__ready.png",
            label: "Home Ready",
            content: HomeView(scanManager: dashboardReady, selectedDestination: .constant(.dashboard))
        )
        let dashboardResults = SmartScanManager()
        seedDashboard(dashboardResults)
        try await capture(
            "02-home-dashboard/02-home-dashboard__\(buildLabel)__with-recommendations.png",
            label: "Home With Recommendations",
            content: HomeView(scanManager: dashboardResults, selectedDestination: .constant(.dashboard))
        )

        let cleanReady = SmartCareSessionStore()
        try await capture(
            "03-clean/03-clean__\(buildLabel)__smart-scan-ready.png",
            label: "Clean Smart Scan Ready",
            content: CleanView(session: cleanReady)
        )
        let cleanScanning = SmartCareSessionStore()
        seedScanning(cleanScanning)
        try await capture(
            "03-clean/03-clean__\(buildLabel)__smart-scan-progress.png",
            label: "Clean Smart Scan Progress",
            content: CleanView(session: cleanScanning)
        )
        let cleanResults = SmartCareSessionStore()
        seedCleanResults(cleanResults)
        try await capture(
            "03-clean/03-clean__\(buildLabel)__smart-scan-results.png",
            label: "Clean Smart Scan Results",
            content: CleanView(session: cleanResults)
        )
        let cleanStorage = SmartCareSessionStore()
        seedCleanResults(cleanStorage)
        try await capture(
            "03-clean/03-clean__\(buildLabel)__storage-results.png",
            label: "Clean Storage Results",
            content: CleanView(session: cleanStorage, initialTab: .storage)
        )
        try await capture(
            "03-clean/03-clean__\(buildLabel)__history-empty.png",
            label: "Clean History Empty",
            content: CleanView(session: SmartCareSessionStore(), initialTab: .history)
        )

        try await capture(
            "04-apps/04-apps__\(buildLabel)__populated.png",
            label: "Apps Populated",
            content: AppsView()
        )
        try await capture(
            "05-monitor/05-monitor__\(buildLabel)__live-monitoring.png",
            label: "Live Monitoring",
            content: MonitorView(isActive: true)
        )
        try await capture(
            "06-widgets/06-widgets__\(buildLabel)__widgets-panel.png",
            label: "Widgets Panel",
            content: WidgetsPanelView()
        )
        try await capture(
            "06-widgets/06-widgets__\(buildLabel)__legacy-tabbed-settings.png",
            label: "Legacy Tabbed Widget Settings",
            size: CGSize(width: 540, height: 480),
            notes: "Legacy menu-bar settings surface retained for redesign comparison",
            content: TabbedSettingsView()
        )

        try await captureSettings()
        try await captureMenuBarSurfaces()

        try await capture(
            "09-debug-wip/09-debug-wip__\(buildLabel)__developer-tools.png",
            label: "Developer Tools Internal",
            notes: "Debug/WIP surface",
            content: DeveloperToolsView()
        )
        try await capture(
            "09-debug-wip/09-debug-wip__\(buildLabel)__design-gallery.png",
            label: "Design Gallery Internal",
            notes: "Debug/WIP design-system surface",
            content: DesignGalleryView()
        )

        try writeManifest()
    }

    private func captureOnboarding() async throws {
        let host = CaptureHost(size: CGSize(width: 720, height: 560), styleMask: [.borderless], content: UnifiedOnboardingView(isPresented: .constant(true)))
        host.show()
        await settle(0.8)
        for index in 1...3 {
            let path = "01-onboarding/01-onboarding__\(buildLabel)__page-\(String(format: "%02d", index)).png"
            let dimensions = try host.snapshot(to: base.appendingPathComponent(path))
            records.append(ScreenshotRecord(
                path: path,
                build: buildName,
                label: "Onboarding Page \(String(format: "%02d", index))",
                width: dimensions.width,
                height: dimensions.height,
                method: "swiftui-renderer",
                notes: accessNotes
            ))
            if index < 3 {
                await host.click(x: 360, yFromTop: index == 1 ? 476 : 504)
            }
        }
        host.close()
    }

    private func captureSettings() async throws {
        for section in SettingsSection.allCases {
            let slug = section.rawValue.lowercased().replacingOccurrences(of: " ", with: "-")
            try await capture(
                "07-settings/07-settings__\(buildLabel)__\(slug).png",
                label: "Settings \(section.rawValue)",
                size: CGSize(width: 1120, height: 760),
                content: SettingsView(initialSection: section)
            )
        }

        try await captureInteractive(
            "07-settings/07-settings__\(buildLabel)__module-cpu-detail.png",
            label: "Settings Module CPU Detail",
            size: CGSize(width: 1120, height: 760),
            content: SettingsView(initialSection: .modules)
        ) { _ in
            NotificationCenter.default.post(
                name: .openModuleSettings,
                object: nil,
                userInfo: [SettingsDeepLinkUserInfoKey.module: WidgetType.cpu.rawValue]
            )
            await settle(0.5)
        }

        try await captureNativeWindow(
            "07-settings/07-settings__\(buildLabel)__native-settings-window.png",
            label: "Native Settings Window",
            size: CGSize(width: 1120, height: 760),
            notes: "Native NSWindow capture for settings/window fidelity",
            content: SettingsView()
        )
    }

    private func captureMenuBarSurfaces() async throws {
        let popoverSize = CGSize(width: 360, height: 620)
        try await capture("08-menu-bar-surfaces/08-menu-bar-surfaces__\(buildLabel)__oneview-compact.png", label: "OneView Compact", size: CGSize(width: 560, height: 260), notes: "Live metrics may vary", content: OneViewContentView())
        try await capture("08-menu-bar-surfaces/08-menu-bar-surfaces__\(buildLabel)__cpu-popover.png", label: "CPU Popover", size: popoverSize, notes: "Live metrics may vary", content: CPUPopoverView())
        try await capture("08-menu-bar-surfaces/08-menu-bar-surfaces__\(buildLabel)__memory-popover.png", label: "Memory Popover", size: popoverSize, notes: "Live metrics may vary", content: MemoryPopoverView())
        try await capture("08-menu-bar-surfaces/08-menu-bar-surfaces__\(buildLabel)__disk-popover.png", label: "Disk Popover", size: popoverSize, notes: "Live metrics may vary", content: DiskPopoverView())
        try await capture("08-menu-bar-surfaces/08-menu-bar-surfaces__\(buildLabel)__network-popover.png", label: "Network Popover", size: popoverSize, notes: "Live metrics may vary", content: NetworkPopoverView())
        try await capture("08-menu-bar-surfaces/08-menu-bar-surfaces__\(buildLabel)__battery-popover.png", label: "Battery Popover", size: popoverSize, notes: "Live metrics may vary", content: BatteryPopoverView())
        try await capture("08-menu-bar-surfaces/08-menu-bar-surfaces__\(buildLabel)__clock-popover.png", label: "Clock Popover", size: popoverSize, notes: "Live metrics may vary", content: ClockPopoverView())
        try await capture("08-menu-bar-surfaces/08-menu-bar-surfaces__\(buildLabel)__bluetooth-popover.png", label: "Bluetooth Popover", size: popoverSize, notes: "Live metrics may vary", content: BluetoothPopoverView())
        try await capture("08-menu-bar-surfaces/08-menu-bar-surfaces__\(buildLabel)__weather-detail.png", label: "Weather Detail", size: popoverSize, notes: "Live metrics may vary", content: WeatherDetailView())
        try await capture("08-menu-bar-surfaces/08-menu-bar-surfaces__\(buildLabel)__sensors-popover.png", label: "Sensors Popover", size: popoverSize, notes: "Live metrics may vary", content: SensorsPopoverView())
        try await capture("08-menu-bar-surfaces/08-menu-bar-surfaces__\(buildLabel)__gpu-popover.png", label: "GPU Popover", size: popoverSize, notes: "Live metrics may vary", content: GPUPopoverView())
    }

    private func capture<Content: View>(
        _ relativePath: String,
        label: String,
        size: CGSize = CGSize(width: 1280, height: 820),
        notes: String? = nil,
        content: Content
    ) async throws {
        log("capture \(relativePath)")
        let host = CaptureHost(size: size, styleMask: [.borderless], content: content)
        host.show()
        await settle()
        let dimensions = try host.snapshot(to: base.appendingPathComponent(relativePath))
        host.close()
        records.append(ScreenshotRecord(
            path: relativePath,
            build: buildName,
            label: label,
            width: dimensions.width,
            height: dimensions.height,
            method: "swiftui-renderer",
            notes: notes ?? accessNotes
        ))
    }

    private func captureInteractive<Content: View>(
        _ relativePath: String,
        label: String,
        size: CGSize,
        notes: String? = nil,
        content: Content,
        actions: (CaptureHost<Content>) async throws -> Void
    ) async throws {
        log("capture \(relativePath)")
        let host = CaptureHost(size: size, styleMask: [.borderless], content: content)
        host.show()
        await settle()
        try await actions(host)
        let dimensions = try host.snapshot(to: base.appendingPathComponent(relativePath))
        host.close()
        records.append(ScreenshotRecord(
            path: relativePath,
            build: buildName,
            label: label,
            width: dimensions.width,
            height: dimensions.height,
            method: "swiftui-renderer",
            notes: notes ?? accessNotes
        ))
    }

    private func captureNativeWindow<Content: View>(
        _ relativePath: String,
        label: String,
        size: CGSize,
        notes: String,
        content: Content
    ) async throws {
        log("capture \(relativePath)")
        let host = CaptureHost(size: size, styleMask: [.titled, .closable, .miniaturizable, .resizable], content: content)
        host.show()
        await settle(1.0)
        let dimensions = try host.windowSnapshot(to: base.appendingPathComponent(relativePath))
        host.close()
        records.append(ScreenshotRecord(
            path: relativePath,
            build: buildName,
            label: label,
            width: dimensions.width,
            height: dimensions.height,
            method: "native-window-host",
            notes: notes
        ))
    }

    private var buildName: String {
        BuildCapabilities.current.requiresScopeAccess ? "TonicStore / Store" : "Tonic / Direct"
    }

    private var accessNotes: String {
        BuildCapabilities.current.requiresScopeAccess
            ? "Store flavor; authorized-location/scope wording where applicable"
            : "Direct flavor; Full Disk Access wording where applicable"
    }

    private func writeManifest() throws {
        let manifest = base.appendingPathComponent("manifest.tsv")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let rows = records.map {
            [$0.path, $0.build, $0.label, "\($0.width)x\($0.height)", $0.method, $0.notes]
                .map { $0.replacingOccurrences(of: "\t", with: " ") }
                .joined(separator: "\t")
        }.joined(separator: "\n")
        let header = "path\tbuild\tlabel\tdimensions\tmethod\tnotes\n"
        if FileManager.default.fileExists(atPath: manifest.path) {
            let handle = try FileHandle(forWritingTo: manifest)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(("\n" + rows).utf8))
        } else {
            try Data((header + rows).utf8).write(to: manifest)
        }
    }
}

@MainActor
final class CaptureHost<Content: View> {
    private let window: NSWindow
    private let host: NSHostingView<AnyView>
    let size: CGSize

    init(size: CGSize, styleMask: NSWindow.StyleMask, content: Content) {
        self.size = size
        self.host = NSHostingView(rootView: AnyView(
            content
                .frame(width: size.width, height: size.height)
                .environment(\.colorScheme, .dark)
        ))
        self.host.frame = NSRect(origin: .zero, size: size)
        self.window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        self.window.title = "Tonic"
        self.window.contentView = host
        self.window.backgroundColor = .windowBackgroundColor
        self.window.isReleasedWhenClosed = false
        self.window.center()
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.displayIfNeeded()
    }

    func close() {
        window.orderOut(nil)
        window.close()
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

    func snapshot(to url: URL) throws -> (width: Int, height: Int) {
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw RendererError.snapshotFailed("Could not allocate bitmap representation")
        }
        rep.size = host.bounds.size
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw RendererError.snapshotFailed("Could not encode PNG")
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
        return (rep.pixelsWide, rep.pixelsHigh)
    }

    func windowSnapshot(to url: URL) throws -> (width: Int, height: Int) {
        window.displayIfNeeded()
        let cgWindowID = CGWindowID(window.windowNumber)
        _ = cgWindowID
        return try snapshot(to: url)
    }
}

enum RendererError: Error {
    case snapshotFailed(String)
}

struct HandoffShellView: View {
    @State private var selectedDestination: NavigationDestination = .dashboard
    @StateObject private var scanManager = SmartScanManager()

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedDestination: $selectedDestination)
        } detail: {
            HomeView(scanManager: scanManager, selectedDestination: $selectedDestination)
        }
        .frame(width: 1280, height: 820)
        .background(TonicDS.Colors.canvas)
        .onAppear {
            seedDashboard(scanManager)
        }
    }
}

@MainActor
func settle(_ seconds: Double = 0.75) async {
    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    NSApp.windows.forEach { $0.displayIfNeeded() }
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
    defaults.set("System", forKey: "tonic.appearance.themeMode")
    defaults.set(false, forKey: "tonic.appearance.reduceTransparency")
    defaults.set(false, forKey: "tonic.appearance.reduceMotion")
    defaults.set(false, forKey: TonicUserDefaultsKey.powerUserModeEnabled)
    WIPFeature.allCases.forEach { FeatureFlags.set($0, enabled: true) }
}

@MainActor
func seedSanitizedFixtures() {
    seedWidgets()
    seedApps()
}

@MainActor
func seedWidgets() {
    let configs: [WidgetConfiguration] = [
        WidgetConfiguration(type: .cpu, visualizationType: .mini, isEnabled: true, position: 0, displayMode: .compact, valueFormat: .percentage),
        WidgetConfiguration(type: .memory, visualizationType: .lineChart, isEnabled: true, position: 1, displayMode: .compact, valueFormat: .percentage),
        WidgetConfiguration(type: .disk, visualizationType: .barChart, isEnabled: true, position: 2, displayMode: .compact, valueFormat: .percentage),
        WidgetConfiguration(type: .network, visualizationType: .speed, isEnabled: true, position: 3, displayMode: .compact, valueFormat: .valueWithUnit),
        WidgetConfiguration(type: .battery, visualizationType: .batteryDetails, isEnabled: true, position: 4, displayMode: .compact, valueFormat: .percentage)
    ]
    WidgetPreferences.shared.widgetConfigs = configs
    WidgetPreferences.shared.hasCompletedOnboarding = true
    WidgetPreferences.shared.unifiedMenuBarMode = false
    WidgetPreferences.shared.saveConfigs()
}

@MainActor
func seedApps() {
    var apps = [
        AppMetadata(bundleIdentifier: "com.example.editor", appName: "Studio Editor", path: URL(fileURLWithPath: "/Applications/Studio Editor.app"), version: "4.8", totalSize: 2_900_000_000, lastUsed: Date().addingTimeInterval(-12 * 86_400), installDate: Date().addingTimeInterval(-180 * 86_400), category: .creativity),
        AppMetadata(bundleIdentifier: "com.example.ide", appName: "Code Lab", path: URL(fileURLWithPath: "/Applications/Code Lab.app"), version: "12.1", totalSize: 5_600_000_000, lastUsed: Date().addingTimeInterval(-2 * 86_400), installDate: Date().addingTimeInterval(-250 * 86_400), category: .development),
        AppMetadata(bundleIdentifier: "com.example.chat", appName: "Team Chat", path: URL(fileURLWithPath: "/Applications/Team Chat.app"), version: "9.2", totalSize: 830_000_000, lastUsed: Date().addingTimeInterval(-5 * 86_400), installDate: Date().addingTimeInterval(-90 * 86_400), category: .communication),
        AppMetadata(bundleIdentifier: "com.example.archive", appName: "Archive Utility Pro", path: URL(fileURLWithPath: "/Applications/Archive Utility Pro.app"), version: "2.4", totalSize: 410_000_000, lastUsed: Date().addingTimeInterval(-160 * 86_400), installDate: Date().addingTimeInterval(-400 * 86_400), category: .utilities)
    ]
    apps[1].hasUpdate = true
    let inventory = AppInventoryService.shared
    inventory.apps = apps
    inventory.availableUpdates = 1
    inventory.lastScanDate = Date().addingTimeInterval(-3_600)
    inventory.recomputeFilteredApps()
}

@MainActor
func seedDashboard(_ manager: SmartScanManager) {
    manager.hasScanResult = true
    manager.lastScanDate = Date().addingTimeInterval(-3_600)
    manager.lastReclaimableBytes = 7_800_000_000
    manager.healthScore = 82
    manager.recommendations = [
        Recommendation(
            scanRecommendation: ScanRecommendation(
                type: .cache,
                title: "Developer caches",
                description: "Build products and derived data can be reviewed.",
                actionable: true,
                safeToFix: true,
                spaceToReclaim: 4_300_000_000,
                affectedPaths: ["/Users/Shared/Sample/DeveloperCache"],
                scoreImpact: 8
            ),
            type: .clean,
            category: .cache,
            priority: .high,
            actionText: "Review"
        ),
        Recommendation(
            scanRecommendation: ScanRecommendation(
                type: .largeApps,
                title: "Large applications",
                description: "Several apps have not been opened recently.",
                actionable: true,
                safeToFix: false,
                spaceToReclaim: 3_500_000_000,
                affectedPaths: ["/Applications/Sample.app"],
                scoreImpact: 5
            ),
            type: .clean,
            category: .apps,
            priority: .medium,
            actionText: "Inspect"
        )
    ]
}

@MainActor
func seedScanning(_ session: SmartCareSessionStore) {
    session.hubMode = .scanning
    session.scanProgress = 0.58
    session.currentStage = .performance
    session.completedStages = [.space]
    session.liveCounters = SmartScanLiveCounters(spaceBytesFound: 3_900_000_000, performanceFlaggedCount: 2, appsScannedCount: 18)
    session.currentScanItem = "/Users/Shared/Sample/Caches"
}

@MainActor
func seedCleanResults(_ session: SmartCareSessionStore) {
    let result = makeSmartCareResult()
    session.scanResult = result
    session.hubMode = .results
    session.scanProgress = 1
    session.currentStage = .apps
    session.completedStages = SmartScanStage.allCases
    session.liveCounters = SmartScanLiveCounters(
        spaceBytesFound: result.domainResults[.cleanup]?.totalSize ?? 0,
        performanceFlaggedCount: result.domainResults[.performance]?.totalUnitCount ?? 0,
        appsScannedCount: result.domainResults[.applications]?.totalUnitCount ?? 0
    )
    session.recommendedItemIDs = Set(result.domainResults.values.flatMap { $0.items }.filter { $0.isSmartSelected }.map(\.id))
}

func makeSmartCareResult() -> SmartCareResult {
    let cleanupItems = [
        SmartCareItem(domain: .cleanup, groupId: UUID(), title: "Build caches", subtitle: "Sample developer cache files", size: 4_200_000_000, count: 1_240, safeToRun: true, isSmartSelected: true, action: .delete(paths: ["/Users/Shared/Sample/BuildCaches"]), paths: ["/Users/Shared/Sample/BuildCaches"], scoreImpact: 8),
        SmartCareItem(domain: .cleanup, groupId: UUID(), title: "Old logs", subtitle: "Rotated local diagnostic logs", size: 620_000_000, count: 311, safeToRun: true, isSmartSelected: true, action: .delete(paths: ["/Users/Shared/Sample/Logs"]), paths: ["/Users/Shared/Sample/Logs"], scoreImpact: 3),
        SmartCareItem(domain: .cleanup, groupId: UUID(), title: "Large downloads", subtitle: "Personal files requiring review", size: 2_700_000_000, count: 4, safeToRun: true, isSmartSelected: false, action: .delete(paths: ["/Users/Shared/Sample/Downloads"]), paths: ["/Users/Shared/Sample/Downloads"], scoreImpact: 4, dataClass: .personal)
    ]
    let performanceItems = [
        SmartCareItem(domain: .performance, groupId: UUID(), title: "Login item review", subtitle: "Background utilities start at login", size: 0, count: 3, safeToRun: false, isSmartSelected: false, action: .none, paths: [], scoreImpact: 3),
        SmartCareItem(domain: .performance, groupId: UUID(), title: "DNS cache", subtitle: "Network cache can be refreshed", size: 0, count: 1, safeToRun: true, isSmartSelected: true, action: .runOptimization(.flushDNS), paths: [], scoreImpact: 2)
    ]
    let appItems = [
        SmartCareItem(domain: .applications, groupId: UUID(), title: "Unused creative app", subtitle: "Not opened in 160 days", size: 1_900_000_000, count: 1, safeToRun: false, isSmartSelected: false, action: .none, paths: ["/Applications/Sample Creative.app"], scoreImpact: 4),
        SmartCareItem(domain: .applications, groupId: UUID(), title: "App leftovers", subtitle: "Support files from removed apps", size: 980_000_000, count: 27, safeToRun: true, isSmartSelected: true, action: .delete(paths: ["/Users/Shared/Sample/Application Support/RemovedApp"]), paths: ["/Users/Shared/Sample/Application Support/RemovedApp"], scoreImpact: 5, dataClass: .personal)
    ]
    return SmartCareResult(
        timestamp: Date().addingTimeInterval(-3_600),
        duration: 12.4,
        domainResults: [
            .cleanup: SmartCareDomainResult(domain: .cleanup, groups: [SmartCareGroup(domain: .cleanup, title: "Recoverable space", description: "Sanitized sample cleanup findings", items: cleanupItems)]),
            .performance: SmartCareDomainResult(domain: .performance, groups: [SmartCareGroup(domain: .performance, title: "Performance", description: "Sanitized sample performance findings", items: performanceItems)]),
            .applications: SmartCareDomainResult(domain: .applications, groups: [SmartCareGroup(domain: .applications, title: "Applications", description: "Sanitized sample app findings", items: appItems)])
        ]
    )
}

@main
struct HandoffRenderer {
    @MainActor
    static func main() async {
        guard CommandLine.arguments.count >= 3 else {
            fputs("usage: HandoffRenderer <screenshots-dir> <direct|store>\n", stderr)
            exit(2)
        }
        NSApplication.shared.setActivationPolicy(.accessory)
        let base = URL(fileURLWithPath: CommandLine.arguments[1])
        let run = HandoffRun(base: base, buildLabel: CommandLine.arguments[2])
        do {
            try await run.run()
        } catch {
            fputs("HandoffRenderer failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
