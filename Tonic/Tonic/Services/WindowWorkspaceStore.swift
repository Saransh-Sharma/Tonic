//
//  WindowWorkspaceStore.swift
//  Tonic
//
//  Persistence for window workspaces (multi-app frame arrangements), display
//  rules (auto-apply on connect), and window behavior preferences. Follows the
//  MenuBarPresetStore UserDefaults-JSON idiom.
//

import Foundation

@Observable
public final class WindowWorkspaceStore: @unchecked Sendable {
    public static let shared = WindowWorkspaceStore()

    private enum Keys {
        static let workspaces = "tonic.windows.workspaces"
        static let displayRules = "tonic.windows.displayRules"
        static let cyclingEnabled = "tonic.windows.cyclingEnabled"
        static let snapEnabled = "tonic.windows.snapEnabled"
    }

    var workspaces: [WindowWorkspace] {
        didSet { persist(workspaces, key: Keys.workspaces) }
    }

    var displayRules: [DisplayRule] {
        didSet { persist(displayRules, key: Keys.displayRules) }
    }

    /// Repeat-press cycling for left/right halves (½ → ⅓ → ⅔).
    var cyclingEnabled: Bool {
        didSet { UserDefaults.standard.set(cyclingEnabled, forKey: Keys.cyclingEnabled) }
    }

    /// Drag-to-screen-edge snapping with the glass zone overlay.
    var snapEnabled: Bool {
        didSet { UserDefaults.standard.set(snapEnabled, forKey: Keys.snapEnabled) }
    }

    private init() {
        workspaces = Self.load([WindowWorkspace].self, key: Keys.workspaces) ?? []
        displayRules = Self.load([DisplayRule].self, key: Keys.displayRules) ?? []
        cyclingEnabled = UserDefaults.standard.object(forKey: Keys.cyclingEnabled) as? Bool ?? true
        snapEnabled = UserDefaults.standard.object(forKey: Keys.snapEnabled) as? Bool ?? true
    }

    // MARK: - Workspaces

    func add(_ workspace: WindowWorkspace) {
        workspaces.append(workspace)
    }

    func update(_ workspace: WindowWorkspace) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspace.id }) else { return }
        workspaces[index] = workspace
    }

    func removeWorkspace(id: UUID) {
        workspaces.removeAll { $0.id == id }
        // Rules pointing at a deleted workspace are dead — drop them too.
        displayRules.removeAll { $0.workspaceID == id }
    }

    func workspace(id: UUID) -> WindowWorkspace? {
        workspaces.first { $0.id == id }
    }

    // MARK: - Display rules

    func add(_ rule: DisplayRule) {
        displayRules.append(rule)
    }

    func update(_ rule: DisplayRule) {
        guard let index = displayRules.firstIndex(where: { $0.id == rule.id }) else { return }
        displayRules[index] = rule
    }

    func removeRule(id: UUID) {
        displayRules.removeAll { $0.id == id }
    }

    /// Enabled rules matching a display by name (resolution/scale may change
    /// between connects; the name is the stable identity).
    func rules(matchingDisplayNamed name: String) -> [DisplayRule] {
        displayRules.filter { $0.isEnabled && $0.display.name == name }
    }

    // MARK: - Persistence

    private func persist(_ value: some Encodable, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
