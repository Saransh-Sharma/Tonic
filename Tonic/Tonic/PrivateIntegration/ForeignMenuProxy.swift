#if !TONIC_STORE

import AppKit
import ApplicationServices
import Foundation
import SwiftUI

public struct ForeignMenuProxyItem: Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var isEnabled: Bool
    public var isSecure: Bool
    fileprivate var path: [Int]

    public init(id: UUID = UUID(), title: String, isEnabled: Bool, isSecure: Bool = false,
                path: [Int] = []) {
        self.id = id; self.title = title; self.isEnabled = isEnabled
        self.isSecure = isSecure; self.path = path
    }
}

public enum ForeignMenuProxyError: LocalizedError, Equatable, Sendable {
    case capabilityDisabled
    case permissionDenied
    case itemNotEnabled
    case secureItem
    case unsupportedItem
    case ambiguousMapping
    case sessionExpired

    public var errorDescription: String? {
        switch self {
        case .capabilityDisabled: "Foreign-menu proxying is not approved for this macOS build."
        case .permissionDenied: "Accessibility and Screen Recording are required for this item."
        case .itemNotEnabled: "Enable proxying for this item before opening its menu."
        case .secureItem: "This menu contains secure or oversized content and cannot be proxied."
        case .unsupportedItem: "This item does not expose a usable menu."
        case .ambiguousMapping: "The original menu changed, so Tonic did not forward the action."
        case .sessionExpired: "The transient proxy session expired. Open it again."
        }
    }
}

public actor ForeignMenuProxySession {
    public static let maximumItems = 100
    public static let maximumTextBytes = 32 * 1_024
    public static let maximumDuration: TimeInterval = 30

    public let id = UUID()
    public let stableItemKey: String
    public let openedAt: Date
    public private(set) var items: [ForeignMenuProxyItem] = []
    private var isClosed = false
    private let activateOriginal: @Sendable () async -> Bool
    private let capabilityAllowed: @Sendable () async -> Bool
    private let permissionsAllowed: @Sendable () -> Bool

    public init(stableItemKey: String, activateOriginal: @escaping @Sendable () async -> Bool,
                capabilityAllowed: @escaping @Sendable () async -> Bool = {
                    (await TonicCompatibilityAuthority.shared.decision(for: .foreignMenuProxy)).isEnabled
                },
                permissionsAllowed: @escaping @Sendable () -> Bool = {
                    AXIsProcessTrusted() && CGPreflightScreenCaptureAccess()
                },
                openedAt: Date = Date()) {
        self.stableItemKey = stableItemKey; self.activateOriginal = activateOriginal
        self.capabilityAllowed = capabilityAllowed; self.permissionsAllowed = permissionsAllowed
        self.openedAt = openedAt
    }

    public func open(accessibilityItems: [ForeignMenuProxyItem]) async throws -> [ForeignMenuProxyItem] {
        try await open { accessibilityItems }
    }

    public func open(
        loadAccessibilityItems: @escaping @Sendable () async -> [ForeignMenuProxyItem]
    ) async throws -> [ForeignMenuProxyItem] {
        guard await capabilityAllowed() else { throw ForeignMenuProxyError.capabilityDisabled }
        guard permissionsAllowed() else { throw ForeignMenuProxyError.permissionDenied }
        guard !isClosed, Date().timeIntervalSince(openedAt) <= Self.maximumDuration else {
            throw ForeignMenuProxyError.sessionExpired
        }
        guard await activateOriginal() else { throw ForeignMenuProxyError.unsupportedItem }
        try? await Task.sleep(for: .milliseconds(120))
        let accessibilityItems = await loadAccessibilityItems()
        guard !accessibilityItems.isEmpty else { throw ForeignMenuProxyError.unsupportedItem }
        guard accessibilityItems.count <= Self.maximumItems,
              accessibilityItems.allSatisfy({ !$0.isSecure }),
              accessibilityItems.reduce(0, { $0 + $1.title.utf8.count }) <= Self.maximumTextBytes else {
            throw ForeignMenuProxyError.secureItem
        }
        items = accessibilityItems.map {
            ForeignMenuProxyItem(id: $0.id, title: String($0.title.prefix(256)),
                                 isEnabled: $0.isEnabled, path: $0.path)
        }
        return items
    }

    public func activate(_ itemID: UUID, forward: @Sendable ([Int]) async -> Bool) async throws {
        guard !isClosed, Date().timeIntervalSince(openedAt) <= Self.maximumDuration else {
            throw ForeignMenuProxyError.sessionExpired
        }
        guard let item = items.first(where: { $0.id == itemID }), item.isEnabled, !item.isSecure else {
            throw ForeignMenuProxyError.ambiguousMapping
        }
        guard await forward(item.path) else { throw ForeignMenuProxyError.ambiguousMapping }
        close()
    }

    public func close() {
        items.removeAll(keepingCapacity: false)
        isClosed = true
    }
}

@MainActor
public final class ForeignMenuProxyPreferenceStore {
    public static let shared = ForeignMenuProxyPreferenceStore()
    private static let key = "tonic.foreignMenuProxy.enabledKeys.v1"
    private var keys: Set<String>

    public init(defaults: UserDefaults = .standard) {
        let values = defaults.stringArray(forKey: Self.key) ?? []
        keys = Set(values)
        self.defaults = defaults
    }

    private let defaults: UserDefaults

    public func isEnabled(_ stableKey: String) -> Bool { keys.contains(stableKey) }

    public func setEnabled(_ enabled: Bool, for stableKey: String) {
        if enabled { keys.insert(stableKey) } else { keys.remove(stableKey) }
        defaults.set(keys.sorted(), forKey: Self.key)
    }
}

/// Main-actor bridge from a Quick Shelf item to a bounded, non-persistent AX
/// menu session. If any mapping becomes ambiguous the original menu remains
/// the fallback and no action is synthesized.
@MainActor
public final class ForeignMenuProxyCoordinator {
    public static let shared = ForeignMenuProxyCoordinator()

    public func present(for item: MenuBarItemInfo) {
        guard ForeignMenuProxyPreferenceStore.shared.isEnabled(item.stableKey) else {
            MenuBarManager.shared.lastActionError = ForeignMenuProxyError.itemNotEnabled.localizedDescription
            return
        }
        Task {
            let session = ForeignMenuProxySession(stableItemKey: item.stableKey) {
                do {
                    try await MenuBarItemActivator().activate(item)
                    return true
                } catch { return false }
            }
            do {
                let items = try await session.open {
                    await MainActor.run { MenuBarItemActivator.openMenuItems(for: item) }
                }
                ForeignMenuProxyPanelController.shared.show(items: items, source: item, session: session)
                MenuBarManager.shared.lastActionError = nil
            } catch {
                await session.close()
                MenuBarManager.shared.lastActionError = error.localizedDescription
            }
        }
    }
}

@MainActor
private final class ForeignMenuProxyPanelController {
    static let shared = ForeignMenuProxyPanelController()
    private var panel: NSPanel?

    func show(items: [ForeignMenuProxyItem], source: MenuBarItemInfo,
              session: ForeignMenuProxySession) {
        let panel = panel ?? makePanel()
        self.panel = panel
        panel.contentView = NSHostingView(rootView: ForeignMenuProxyView(
            sourceName: source.displayName,
            items: items,
            activate: { proxyItem in
                Task {
                    do {
                        try await session.activate(proxyItem.id) { path in
                            await MainActor.run {
                                MenuBarItemActivator.performOpenMenuPath(for: source, path: path)
                            }
                        }
                        await MainActor.run {
                            MenuBarUpdateWatchStore.shared.acknowledge(source.stableKey)
                            self.hide()
                        }
                    } catch {
                        await MainActor.run { MenuBarManager.shared.lastActionError = error.localizedDescription }
                    }
                }
            }, close: {
                Task { await session.close() }
                self.hide()
            }
        ))
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let height = min(CGFloat(420), max(CGFloat(120), CGFloat(items.count) * 34 + 64))
        let width: CGFloat = 340
        panel.setFrame(NSRect(x: min(max(NSEvent.mouseLocation.x - width / 2, visible.minX + 8),
                                      visible.maxX - width - 8),
                              y: visible.maxY - height - 8, width: width, height: height), display: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func hide() { panel?.orderOut(nil) }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero,
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.level = .statusBar
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        return panel
    }
}

private struct ForeignMenuProxyView: View {
    let sourceName: String
    let items: [ForeignMenuProxyItem]
    let activate: (ForeignMenuProxyItem) -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sourceName).font(.headline)
                    Text("Transient menu proxy").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close", action: close).buttonStyle(.plain)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(items) { item in
                        Button { activate(item) } label: {
                            Text(item.title).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10).padding(.vertical, 7)
                        }
                        .buttonStyle(.plain)
                        .disabled(!item.isEnabled)
                        .accessibilityHint("Forwards this action to the original menu item")
                    }
                }
            }
            Text("Menu text and mappings are discarded when this panel closes.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(14)
        .tonicSurface(.overlay,
            in: RoundedRectangle(cornerRadius: TonicDS.Radius.md, style: .continuous),
            flatFill: TonicDS.Colors.canvas,
            flatStroke: TonicDS.Colors.hairline)
    }
}

// MARK: - Compatibility-gated system Now Playing

public struct PrivateSystemNowPlayingModule: TopShelfModule {
    public let descriptor = TopShelfModuleDescriptor(
        id: "now-playing", kind: .nowPlaying, title: String(localized: "Now Playing"),
        symbol: "play.circle", allowsAmbientPresentation: true
    )

    public init() {}

    public func snapshot(in context: TopShelfPresentationContext) async -> TopShelfModuleSnapshot {
        let decision = await TonicCompatibilityAuthority.shared.decision(for: .systemNowPlaying)
        guard decision.isEnabled, PrivateSystemNowPlayingAdapter.runtimePreflight else {
            let reason: String
            if case .disabled(let value) = decision { reason = value }
            else { reason = String(localized: "The MediaRemote adapter failed its runtime preflight.") }
            return TopShelfModuleSnapshot(moduleID: descriptor.id, title: descriptor.title,
                primaryText: String(localized: "No supported playback session"), secondaryText: reason,
                symbol: descriptor.symbol, status: .unavailable)
        }
        guard let value = await PrivateSystemNowPlayingAdapter.shared.snapshot() else {
            return TopShelfModuleSnapshot(moduleID: descriptor.id, title: descriptor.title,
                primaryText: String(localized: "Nothing is playing"), secondaryText: String(localized: "Start playback in a media app."),
                symbol: descriptor.symbol, status: .unavailable)
        }
        return TopShelfModuleSnapshot(moduleID: descriptor.id, title: descriptor.title,
            primaryText: value.title, secondaryText: value.artist,
            symbol: value.isPlaying ? "pause.circle" : "play.circle",
            actions: [.nowPlaying(.previousTrack), .nowPlaying(.togglePlayPause), .nowPlaying(.nextTrack)])
    }
}

public struct PrivateNowPlayingSnapshot: Equatable, Sendable {
    public var title: String
    public var artist: String?
    public var isPlaying: Bool
}

private final class PrivateNowPlayingContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<PrivateNowPlayingSnapshot?, Never>?

    init(_ continuation: CheckedContinuation<PrivateNowPlayingSnapshot?, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: PrivateNowPlayingSnapshot?) {
        let pending = lock.withLock { () -> CheckedContinuation<PrivateNowPlayingSnapshot?, Never>? in
            defer { continuation = nil }
            return continuation
        }
        pending?.resume(returning: value)
    }
}

public actor PrivateSystemNowPlayingAdapter {
    public static let shared = PrivateSystemNowPlayingAdapter()
    private static let frameworkPath = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
    private let handle: UnsafeMutableRawPointer?

    private typealias InfoCallback = @convention(block) (CFDictionary?) -> Void
    private typealias GetInfo = @convention(c) (DispatchQueue, @escaping InfoCallback) -> Void
    private typealias SendCommand = @convention(c) (UInt32, CFDictionary?) -> Bool

    public init() { handle = dlopen(Self.frameworkPath, RTLD_NOW | RTLD_LOCAL) }

    public nonisolated static var runtimePreflight: Bool {
        guard let handle = dlopen(frameworkPath, RTLD_NOW | RTLD_LOCAL) else { return false }
        defer { dlclose(handle) }
        return dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") != nil
            && dlsym(handle, "MRMediaRemoteSendCommand") != nil
    }

    public func snapshot() async -> PrivateNowPlayingSnapshot? {
        guard let handle, let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") else { return nil }
        let function = unsafeBitCast(symbol, to: GetInfo.self)
        return await withCheckedContinuation { continuation in
            let gate = PrivateNowPlayingContinuationGate(continuation)
            let callback: InfoCallback = { dictionary in
                guard let values = dictionary as? [String: Any] else {
                    gate.resume(nil); return
                }
                let title = (values["kMRMediaRemoteNowPlayingInfoTitle"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard let title, !title.isEmpty else { gate.resume(nil); return }
                let artist = values["kMRMediaRemoteNowPlayingInfoArtist"] as? String
                let rate = (values["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? NSNumber)?.doubleValue ?? 0
                gate.resume(PrivateNowPlayingSnapshot(
                    title: String(title.prefix(160)),
                    artist: artist.map { String($0.prefix(160)) },
                    isPlaying: rate > 0
                ))
            }
            function(DispatchQueue.main, callback)
            Task.detached {
                try? await Task.sleep(for: .seconds(1))
                gate.resume(nil)
            }
        }
    }

    @discardableResult
    public func send(_ command: TopShelfPlaybackCommand) -> Bool {
        guard let handle, let symbol = dlsym(handle, "MRMediaRemoteSendCommand") else { return false }
        let function = unsafeBitCast(symbol, to: SendCommand.self)
        let raw: UInt32 = switch command {
        case .togglePlayPause: 2
        case .nextTrack: 4
        case .previousTrack: 5
        }
        return function(raw, nil)
    }
}

#endif
