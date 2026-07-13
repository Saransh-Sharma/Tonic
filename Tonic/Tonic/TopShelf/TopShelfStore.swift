import Foundation
import Observation

@MainActor
@Observable
public final class TopShelfStore {
    public static let shared = TopShelfStore()

    public private(set) var state = TopShelfState()
    public private(set) var didLoad = false

    private let store: VersionedAtomicStore<TopShelfState>

    public init(store: VersionedAtomicStore<TopShelfState>? = nil) {
        if let store {
            self.store = store
        } else {
            let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Tonic/TopShelf", isDirectory: true)
            self.store = VersionedAtomicStore(fileURL: root.appendingPathComponent("state-v1.json"))
        }
        Task { await load() }
    }

    public func load() async {
        state = await store.loadOrDefault(TopShelfState())
        didLoad = true
    }

    public func update(_ mutation: (inout TopShelfState) -> Void) {
        mutation(&state)
        let snapshot = state
        Task { try? await store.save(snapshot) }
    }

    public func setEnabled(_ enabled: Bool, moduleID: String) {
        update { state in
            if enabled { state.enabledModuleIDs.insert(moduleID) }
            else {
                state.enabledModuleIDs.remove(moduleID)
                state.ambientPolicy.enabledModuleIDs.remove(moduleID)
            }
        }
    }

    public func confirmRecommendedAmbientSet() {
        update {
            let recommended: Set<String> = ["now-playing", "calendar", "system-health"]
            $0.ambientPolicy.hasConfirmedRecommendedSet = true
            $0.ambientPolicy.enabledModuleIDs = recommended
            $0.enabledModuleIDs.formUnion(recommended)
        }
    }

    public func addNote(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        update { $0.notes.insert(TopShelfQuickNote(text: trimmed), at: 0) }
    }

    public func removeNote(_ id: UUID) { update { $0.notes.removeAll { $0.id == id } } }

    public func addTimer(title: String = "Timer", duration: TimeInterval = 300) {
        update { $0.timers.insert(TopShelfTimer(title: title, duration: duration), at: 0) }
    }

    public func removeTimer(_ id: UUID) { update { $0.timers.removeAll { $0.id == id } } }

    @discardableResult
    public func addRecentFile(_ url: URL) -> Bool {
        guard url.isFileURL,
              let bookmark = try? url.bookmarkData(options: [.withSecurityScope],
                                                   includingResourceValuesForKeys: nil,
                                                   relativeTo: nil) else { return false }
        update { state in
            state.recentFiles.removeAll { $0.displayName == url.lastPathComponent }
            state.recentFiles.insert(TopShelfRecentFile(displayName: url.lastPathComponent,
                                                        bookmark: bookmark), at: 0)
            state.recentFiles = Array(state.recentFiles.prefix(10))
        }
        return true
    }

    public func removeRecentFile(_ id: UUID) {
        update { $0.recentFiles.removeAll { $0.id == id } }
    }
}
