import AppKit
import CryptoKit
import ScreenCaptureKit

public struct MenuBarCapturedUpdate: Sendable {
    public var digest: String
    public var thumbnail: Data?
}

public actor MenuBarUpdateCaptureActor {
    public static let shared = MenuBarUpdateCaptureActor()

    public func capture(windowID: CGWindowID) async throws -> MenuBarCapturedUpdate? {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let window = content.windows.first(where: { $0.windowID == windowID }) else { return nil }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.width = max(16, min(160, Int(window.frame.width * 2)))
        configuration.height = max(16, min(80, Int(window.frame.height * 2)))
        configuration.showsCursor = false
        configuration.captureResolution = .best
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        guard let raw = image.dataProvider?.data as Data? else { return nil }
        let digest = SHA256.hash(data: raw).map { String(format: "%02x", $0) }.joined()
        let bitmap = NSBitmapImageRep(cgImage: image)
        let thumbnail = bitmap.representation(using: .png, properties: [:]).flatMap { $0.count <= 32 * 1_024 ? $0 : nil }
        return MenuBarCapturedUpdate(digest: digest, thumbnail: thumbnail)
    }
}

@MainActor
public final class MenuBarUpdateWatcherCoordinator {
    public static let shared = MenuBarUpdateWatcherCoordinator()
    private var timer: Timer?
    private var captureInFlight = false
    private init() {}

    public func refresh() {
        let shouldRun = !MenuBarUpdateWatchStore.shared.watchedKeys.isEmpty
            && MenuBarManagerSettingsStore.shared.settings.isEnabled
        if shouldRun, timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
                Task { @MainActor in await MenuBarUpdateWatcherCoordinator.shared.captureWatchedItems() }
            }
            Task { await captureWatchedItems() }
        } else if !shouldRun {
            timer?.invalidate(); timer = nil
        }
    }

    private func captureWatchedItems() async {
        guard !captureInFlight, CGPreflightScreenCaptureAccess() else { return }
        captureInFlight = true; defer { captureInFlight = false }
        let store = MenuBarUpdateWatchStore.shared
        let watched = store.watchedKeys
        for item in MenuBarManager.shared.items where watched.contains(item.stableKey) {
            guard let capture = try? await MenuBarUpdateCaptureActor.shared.capture(windowID: item.windowID) else { continue }
            store.recordDigest(capture.digest, thumbnail: capture.thumbnail, for: item.stableKey)
        }
    }
}
