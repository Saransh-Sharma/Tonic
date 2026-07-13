import AppKit
import CoreGraphics
import Foundation

public struct DisplayIdentity: Codable, Hashable, Sendable {
    public var displayID: UInt32
    public var vendor: UInt32
    public var model: UInt32
    public var serial: UInt32
    public var fallbackName: String

    public init(displayID: UInt32, vendor: UInt32, model: UInt32, serial: UInt32,
                fallbackName: String = "Display") {
        self.displayID = displayID; self.vendor = vendor; self.model = model
        self.serial = serial; self.fallbackName = fallbackName
    }

    @MainActor
    public init(screen: NSScreen) {
        let number = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        self.init(displayID: number, vendor: CGDisplayVendorNumber(number), model: CGDisplayModelNumber(number),
                  serial: CGDisplaySerialNumber(number), fallbackName: screen.localizedName)
    }

    /// Stable hardware fields win across display-ID churn; unnamed virtual
    /// displays fall back to the current ID and localized name.
    public func matches(_ other: DisplayIdentity) -> Bool {
        if serial != 0 && other.serial != 0 { return vendor == other.vendor && model == other.model && serial == other.serial }
        return displayID == other.displayID || (vendor == other.vendor && model == other.model && fallbackName == other.fallbackName)
    }
}

public enum MenuBarProfileScope: Codable, Hashable, Sendable {
    case global
    case display(DisplayIdentity)
    case manualContext(UUID)
}

public enum QuickShelfDisplayTarget: Codable, Hashable, Sendable {
    case activeDisplay
    case specific(DisplayIdentity)
}

public struct MenuBarPresentationValues: Codable, Equatable, Sendable {
    public var appearance: MenuBarStyling?
    public var revealBehavior: MenuBarRevealBehaviorSnapshot?
    public var quickShelfTarget: QuickShelfDisplayTarget?
    public var quickShelfPresentation: QuickShelfPresentation?
    public var showsOverflow: Bool?
    public var hidesOnInactiveDisplays: Bool?

    public init(appearance: MenuBarStyling? = nil, revealBehavior: MenuBarRevealBehaviorSnapshot? = nil,
                quickShelfTarget: QuickShelfDisplayTarget? = nil,
                quickShelfPresentation: QuickShelfPresentation? = nil,
                showsOverflow: Bool? = nil, hidesOnInactiveDisplays: Bool? = nil) {
        self.appearance = appearance; self.revealBehavior = revealBehavior
        self.quickShelfTarget = quickShelfTarget; self.quickShelfPresentation = quickShelfPresentation
        self.showsOverflow = showsOverflow; self.hidesOnInactiveDisplays = hidesOnInactiveDisplays
    }

    public func overlaying(_ override: Self) -> Self {
        Self(appearance: override.appearance ?? appearance,
             revealBehavior: override.revealBehavior ?? revealBehavior,
             quickShelfTarget: override.quickShelfTarget ?? quickShelfTarget,
             quickShelfPresentation: override.quickShelfPresentation ?? quickShelfPresentation,
             showsOverflow: override.showsOverflow ?? showsOverflow,
             hidesOnInactiveDisplays: override.hidesOnInactiveDisplays ?? hidesOnInactiveDisplays)
    }
}

public struct MenuBarPresentationProfile: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var scope: MenuBarProfileScope
    public var values: MenuBarPresentationValues
    public init(id: UUID = UUID(), name: String, scope: MenuBarProfileScope,
                values: MenuBarPresentationValues) {
        self.id = id; self.name = name; self.scope = scope; self.values = values
    }
}

public struct MenuBarManualContext: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var symbolName: String
    public init(id: UUID = UUID(), name: String, symbolName: String = "rectangle.3.group") {
        self.id = id; self.name = name; self.symbolName = symbolName
    }
}

public struct MenuBarProfileResolver: Sendable {
    public init() {}
    public func resolve(profiles: [MenuBarPresentationProfile], display: DisplayIdentity?,
                        manualContextID: UUID?) -> MenuBarPresentationValues {
        var resolved = profiles.first(where: { $0.scope == .global })?.values ?? .init()
        if let display, let profile = profiles.first(where: {
            if case .display(let identity) = $0.scope { return identity.matches(display) }
            return false
        }) { resolved = resolved.overlaying(profile.values) }
        if let manualContextID, let profile = profiles.first(where: { $0.scope == .manualContext(manualContextID) }) {
            resolved = resolved.overlaying(profile.values)
        }
        return resolved
    }
}

@MainActor
@Observable
public final class MenuBarProfileStore {
    public static let shared = MenuBarProfileStore()
    private static let key = "tonic.menuBarProfiles.v1"
    private struct Envelope: Codable {
        var version = 1
        var globalForeignLayout: [String: MenuBarSection]
        var profiles: [MenuBarPresentationProfile]
        var manualContexts: [MenuBarManualContext]
        var selectedManualContextID: UUID?
    }

    public private(set) var globalForeignLayout: [String: MenuBarSection]
    public var profiles: [MenuBarPresentationProfile] { didSet { persist() } }
    public var manualContexts: [MenuBarManualContext] { didSet { persist() } }
    public var selectedManualContextID: UUID? { didSet { persist() } }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, migratedLayout: [String: MenuBarSection]? = nil,
         migratedSettings: MenuBarManagerSettings? = nil) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key), let envelope = try? JSONDecoder().decode(Envelope.self, from: data) {
            globalForeignLayout = envelope.globalForeignLayout; profiles = envelope.profiles
            manualContexts = envelope.manualContexts; selectedManualContextID = envelope.selectedManualContextID
        } else {
            let settings = migratedSettings ?? MenuBarManagerSettingsStore.shared.settings
            globalForeignLayout = migratedLayout ?? MenuBarWorkspaceStore.shared.envelope.committed.foreignAssignments
            profiles = [MenuBarPresentationProfile(name: "All Displays", scope: .global,
                values: .init(appearance: settings.styling,
                              revealBehavior: .init(showOnHover: settings.showOnHover,
                                                    showOnClickEmptyMenuBar: settings.showOnClickEmptyMenuBar,
                                                    showOnScroll: settings.showOnScroll, autoRehide: settings.autoRehide,
                                                    quickShelfPresentation: settings.quickShelfPresentation),
                              quickShelfTarget: .activeDisplay,
                              quickShelfPresentation: settings.quickShelfPresentation,
                              showsOverflow: true, hidesOnInactiveDisplays: settings.hideOnInactiveDisplays))]
            manualContexts = []; selectedManualContextID = nil; persist()
        }
    }

    public func selectContext(_ id: UUID?) {
        selectedManualContextID = id
        NotificationCenter.default.post(name: .menuBarPresentationContextDidChange, object: nil)
        #if !TONIC_STORE
        MenuBarStyleOverlayController.shared.apply(MenuBarManagerSettingsStore.shared.settings.styling)
        #endif
    }
    public func addContext(name: String, symbolName: String = "rectangle.3.group") -> MenuBarManualContext {
        let context = MenuBarManualContext(name: name, symbolName: symbolName); manualContexts.append(context)
        profiles.append(MenuBarPresentationProfile(name: name, scope: .manualContext(context.id), values: .init()))
        return context
    }
    public func removeContext(id: UUID) {
        manualContexts.removeAll { $0.id == id }; profiles.removeAll { $0.scope == .manualContext(id) }
        if selectedManualContextID == id { selectedManualContextID = nil }
    }
    public func updateValues(scope: MenuBarProfileScope, name: String,
                             _ update: (inout MenuBarPresentationValues) -> Void) {
        if let index = profiles.firstIndex(where: { Self.scopesMatch($0.scope, scope) }) {
            update(&profiles[index].values)
        } else {
            var values = MenuBarPresentationValues(); update(&values)
            profiles.append(MenuBarPresentationProfile(name: name, scope: scope, values: values))
        }
        NotificationCenter.default.post(name: .menuBarPresentationContextDidChange, object: nil)
        #if !TONIC_STORE
        MenuBarStyleOverlayController.shared.apply(MenuBarManagerSettingsStore.shared.settings.styling)
        #endif
    }
    public func explicitValues(for scope: MenuBarProfileScope) -> MenuBarPresentationValues? {
        profiles.first(where: { Self.scopesMatch($0.scope, scope) })?.values
    }
    public func updateGlobalForeignLayout(_ layout: [String: MenuBarSection]) {
        globalForeignLayout = layout; persist()
    }

    private func persist() {
        let envelope = Envelope(globalForeignLayout: globalForeignLayout, profiles: profiles,
                                manualContexts: manualContexts, selectedManualContextID: selectedManualContextID)
        if let data = try? JSONEncoder().encode(envelope) { defaults.set(data, forKey: Self.key) }
    }

    private static func scopesMatch(_ lhs: MenuBarProfileScope, _ rhs: MenuBarProfileScope) -> Bool {
        switch (lhs, rhs) {
        case (.global, .global): return true
        case (.manualContext(let a), .manualContext(let b)): return a == b
        case (.display(let a), .display(let b)): return a.matches(b)
        default: return false
        }
    }
}

@MainActor
public final class MenuBarProfileCoordinator {
    public static let shared = MenuBarProfileCoordinator()
    private var observers: [NSObjectProtocol] = []
    private init() {}
    public func start() {
        guard observers.isEmpty else { return }
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,
                                               object: nil, queue: .main) { _ in
            NotificationCenter.default.post(name: .menuBarPresentationContextDidChange, object: nil)
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                                object: nil, queue: .main) { _ in
            NotificationCenter.default.post(name: .menuBarPresentationContextDidChange, object: nil)
        })
    }
}

extension Notification.Name {
    static let menuBarPresentationContextDidChange = Notification.Name("tonic.menuBar.presentationContextDidChange")
}
