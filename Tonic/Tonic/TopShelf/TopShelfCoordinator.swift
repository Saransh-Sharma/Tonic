import AppKit
import Observation

@MainActor
@Observable
public final class TopShelfCoordinator {
    public static let shared = TopShelfCoordinator()

    public private(set) var snapshots: [TopShelfModuleSnapshot] = []
    public private(set) var isRefreshing = false
    public private(set) var lastPresentedAt: Date?

    private let store: TopShelfStore
    private var modules: [String: any TopShelfModule] = [:]
    private var refreshTask: Task<Void, Never>?
    private var lastAmbientEventIDs: [String: String] = [:]

    public init(store: TopShelfStore = .shared, modules: [any TopShelfModule]? = nil) {
        self.store = store
        let builtins: [any TopShelfModule] = modules ?? [
            Self.nowPlayingModule(), TopShelfSystemHealthModule(), TopShelfRecommendationsModule(),
            TopShelfWeatherModule(), TopShelfCalendarModule(), TopShelfClipboardModule(),
            TopShelfNotesModule(), TopShelfTimerModule(), TopShelfFilesModule(),
            TopShelfShortcutsModule(), TopShelfProviderCardsModule()
        ]
        self.modules = Dictionary(uniqueKeysWithValues: builtins.map { ($0.descriptor.id, $0) })
    }

    public var descriptors: [TopShelfModuleDescriptor] {
        orderedModules().map(\.descriptor)
    }

    public func register(_ module: any TopShelfModule) { modules[module.descriptor.id] = module }

    public func requestCalendarAccess() async -> Bool {
        await TopShelfCalendarModule().requestAccess()
    }

    public func deliberateOpen() {
        lastPresentedAt = Date()
        refresh(context: .init(isDeliberateOpen: true, activeDisplayName: activeScreen?.localizedName))
        TopShelfPanelController.shared.show()
    }

    public func ambientPresent(moduleID: String, eventID: String? = nil) {
        let policy = store.state.ambientPolicy
        guard policy.hasConfirmedRecommendedSet,
              policy.enabledModuleIDs.contains(moduleID),
              modules[moduleID]?.descriptor.allowsAmbientPresentation == true,
              !isSuppressed,
              Date().timeIntervalSince(lastPresentedAt ?? .distantPast) >= policy.cooldownSeconds else { return }
        if let eventID, lastAmbientEventIDs[moduleID] == eventID { return }
        if let eventID { lastAmbientEventIDs[moduleID] = eventID }
        lastPresentedAt = Date()
        refresh(context: .init(isDeliberateOpen: false, isAmbient: true,
                               activeDisplayName: activeScreen?.localizedName),
                moduleIDs: [moduleID])
        TopShelfPanelController.shared.show(ambient: true)
    }

    public func clearAmbientEvent(moduleID: String) {
        lastAmbientEventIDs.removeValue(forKey: moduleID)
    }

    public func ambientSnapshot(moduleID: String, now: Date = Date()) async -> TopShelfModuleSnapshot? {
        guard let module = modules[moduleID], module.descriptor.allowsAmbientPresentation else { return nil }
        return await module.snapshot(in: .init(isDeliberateOpen: false, isAmbient: true,
                                               activeDisplayName: activeScreen?.localizedName, now: now))
    }

    public func refresh(context: TopShelfPresentationContext, moduleIDs: Set<String>? = nil) {
        refreshTask?.cancel()
        let selected = orderedModules().filter {
            store.state.enabledModuleIDs.contains($0.descriptor.id)
                && (moduleIDs == nil || moduleIDs?.contains($0.descriptor.id) == true)
        }
        isRefreshing = true
        refreshTask = Task { [weak self] in
            var values: [TopShelfModuleSnapshot] = []
            await withTaskGroup(of: TopShelfModuleSnapshot.self) { group in
                for module in selected { group.addTask { await module.snapshot(in: context) } }
                for await value in group { values.append(value) }
            }
            guard !Task.isCancelled, let self else { return }
            let order = Dictionary(uniqueKeysWithValues: selected.enumerated().map { ($1.descriptor.id, $0) })
            snapshots = values.sorted { order[$0.moduleID, default: .max] < order[$1.moduleID, default: .max] }
            isRefreshing = false
        }
    }

    public func perform(_ action: TopShelfAction) {
        switch action {
        case .refresh:
            refresh(context: .init(isDeliberateOpen: true, activeDisplayName: activeScreen?.localizedName))
        case .openURL(let url): NSWorkspace.shared.open(url)
        case .openTonicDestination(let destination):
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: .navigateToTonicHub, object: nil, userInfo: ["hub": destination])
        case .removeNote(let id): store.removeNote(id)
        case .runShortcut(let name):
            if let value = URL(string: "shortcuts://run-shortcut?name=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                NSWorkspace.shared.open(value)
            }
        case .startTimer(let id):
            store.update { state in
                guard let index = state.timers.firstIndex(where: { $0.id == id }) else { return }
                state.timers[index].startedAt = Date()
            }
        case .pauseTimer(let id):
            store.update { state in
                guard let index = state.timers.firstIndex(where: { $0.id == id }) else { return }
                state.timers[index].startedAt = nil
            }
        case .nowPlaying(let command):
            #if !TONIC_STORE
            Task { _ = await PrivateSystemNowPlayingAdapter.shared.send(command) }
            #else
            break
            #endif
        case .openRecentFile(let id):
            guard let file = store.state.recentFiles.first(where: { $0.id == id }) else { return }
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: file.bookmark,
                options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale), !stale else {
                store.removeRecentFile(id); return
            }
            let scoped = url.startAccessingSecurityScopedResource()
            NSWorkspace.shared.open(url)
            if scoped { url.stopAccessingSecurityScopedResource() }
        }
    }

    private static func nowPlayingModule() -> any TopShelfModule {
        #if TONIC_STORE
        TopShelfNowPlayingModule()
        #else
        PrivateSystemNowPlayingModule()
        #endif
    }

    private func orderedModules() -> [any TopShelfModule] {
        let explicit = store.state.layout.orderedModuleIDs
        let rank = Dictionary(uniqueKeysWithValues: explicit.enumerated().map { ($1, $0) })
        return modules.values
            .filter { !store.state.layout.hiddenModuleIDs.contains($0.descriptor.id) }
            .sorted {
                let lhs = rank[$0.descriptor.id]
                let rhs = rank[$1.descriptor.id]
                if let lhs, let rhs { return lhs < rhs }
                if lhs != nil { return true }
                if rhs != nil { return false }
                return $0.descriptor.title.localizedStandardCompare($1.descriptor.title) == .orderedAscending
            }
    }

    private var activeScreen: NSScreen? {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
    }

    private var isSuppressed: Bool {
        NSApp.presentationOptions.contains(.fullScreen) || TopShelfScreenSharingDetector.isActive
    }
}

enum TopShelfAmbientEvaluator {
    static func isActionable(_ snapshot: TopShelfModuleSnapshot) -> Bool {
        switch snapshot.moduleID {
        case "system-health", "calendar":
            snapshot.status == .attention || snapshot.status == .critical
        case "now-playing":
            snapshot.status != .unavailable && !snapshot.primaryText.isEmpty
        default:
            false
        }
    }

    static func eventID(for snapshot: TopShelfModuleSnapshot) -> String {
        [snapshot.moduleID, snapshot.primaryText, snapshot.secondaryText ?? "", snapshot.status.rawValue]
            .joined(separator: "\u{1F}")
    }
}

/// Evaluates only the explicitly approved ambient set. It reads module
/// snapshots in memory, deduplicates stable events, and never requests a
/// permission or persists Calendar/Now Playing content.
@MainActor
final class TopShelfAmbientMonitor {
    static let shared = TopShelfAmbientMonitor()
    private var task: Task<Void, Never>?

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.evaluate()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func evaluate(now: Date = Date()) async {
        let state = TopShelfStore.shared.state
        guard TopShelfStore.shared.didLoad, state.ambientPolicy.hasConfirmedRecommendedSet else { return }
        for moduleID in ["system-health", "calendar", "now-playing"]
            where state.ambientPolicy.enabledModuleIDs.contains(moduleID) {
            guard let snapshot = await TopShelfCoordinator.shared.ambientSnapshot(moduleID: moduleID, now: now),
                  TopShelfAmbientEvaluator.isActionable(snapshot) else {
                TopShelfCoordinator.shared.clearAmbientEvent(moduleID: moduleID)
                continue
            }
            TopShelfCoordinator.shared.ambientPresent(
                moduleID: moduleID,
                eventID: TopShelfAmbientEvaluator.eventID(for: snapshot)
            )
        }
    }
}

/// macOS has no single public "the screen is being shared" switch. This
/// deliberately conservative detector uses only public, on-screen window
/// metadata and suppresses ambient content when a system sharing surface or a
/// well-known conferencing sharing indicator is actually visible. It never
/// inspects pixels or uploads window metadata.
private enum TopShelfScreenSharingDetector {
    static var isActive: Bool {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                 kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.contains { window in
            let owner = (window[kCGWindowOwnerName as String] as? String ?? "").lowercased()
            let title = (window[kCGWindowName as String] as? String ?? "").lowercased()
            if owner == "screen sharing" || owner == "screensharingd" || owner == "screencaptureui" {
                return true
            }
            let conferencingOwner = owner.contains("zoom") || owner.contains("microsoft teams")
                || owner.contains("webex") || owner.contains("slack") || owner.contains("meet")
            return conferencingOwner && (title.contains("sharing") || title.contains("presenting"))
        }
    }
}
