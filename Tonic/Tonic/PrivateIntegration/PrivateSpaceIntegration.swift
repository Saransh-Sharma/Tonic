#if !TONIC_STORE

import AppKit
import CryptoKit
import Darwin
import Foundation
import Observation
import Security

public struct PrivateSpaceIdentity: Hashable, Sendable {
    fileprivate var rawValue: UInt64
    public var display: DisplayIdentity?
    public var observedAt: Date

    fileprivate init(rawValue: UInt64, display: DisplayIdentity?, observedAt: Date = Date()) {
        self.rawValue = rawValue; self.display = display; self.observedAt = observedAt
    }
}

public struct SpaceContextBinding: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var opaqueDigest: String
    public var display: DisplayIdentity?
    public var contextID: UUID
    public var contextName: String
    public var lastValidatedAt: Date
    public var osBuild: String

    public init(id: UUID = UUID(), opaqueDigest: String, display: DisplayIdentity?, contextID: UUID,
                contextName: String, lastValidatedAt: Date = Date(),
                osBuild: String = CompatibilityRuntime.current.osBuild) {
        self.id = id; self.opaqueDigest = opaqueDigest; self.display = display
        self.contextID = contextID; self.contextName = contextName
        self.lastValidatedAt = lastValidatedAt; self.osBuild = osBuild
    }
}

public protocol PrivateSpaceObserver: Sendable {
    func currentIdentity() async -> PrivateSpaceIdentity?
}

public actor QuarantinedPrivateSpaceObserver: PrivateSpaceObserver {
    public typealias Authorization = @Sendable () async -> Bool
    private let authorization: Authorization

    public init(authorization: @escaping Authorization) { self.authorization = authorization }

    public func currentIdentity() async -> PrivateSpaceIdentity? {
        guard await authorization(), let raw = Self.readActiveSpace(), raw != 0 else { return nil }
        let display = await MainActor.run { NSScreen.main.map(DisplayIdentity.init) }
        return PrivateSpaceIdentity(rawValue: raw, display: display)
    }

    public nonisolated static func runtimePreflight() -> Bool {
        guard let handle = dlopen(nil, RTLD_NOW) else { return false }
        defer { dlclose(handle) }
        return dlsym(handle, "CGSMainConnectionID") != nil && dlsym(handle, "CGSGetActiveSpace") != nil
    }

    private nonisolated static func readActiveSpace() -> UInt64? {
        guard runtimePreflight(), let handle = dlopen(nil, RTLD_NOW) else { return nil }
        defer { dlclose(handle) }
        typealias MainConnection = @convention(c) () -> Int32
        typealias ActiveSpace = @convention(c) (Int32) -> UInt64
        guard let connectionSymbol = dlsym(handle, "CGSMainConnectionID"),
              let spaceSymbol = dlsym(handle, "CGSGetActiveSpace") else { return nil }
        let connection = unsafeBitCast(connectionSymbol, to: MainConnection.self)
        let activeSpace = unsafeBitCast(spaceSymbol, to: ActiveSpace.self)
        return activeSpace(connection())
    }
}

public actor PrivateSpaceBindingStore {
    private let store: VersionedAtomicStore<[SpaceContextBinding]>
    private let salt: Data
    private(set) var bindings: [SpaceContextBinding] = []

    public init(fileURL: URL) {
        store = VersionedAtomicStore(fileURL: fileURL)
        self.salt = PrivateSpaceSalt.loadOrCreate()
    }

    public init(fileURL: URL, salt: Data) {
        store = VersionedAtomicStore(fileURL: fileURL)
        self.salt = salt
    }

    public func load() async { bindings = await store.loadOrDefault([]) }

    public func bind(_ identity: PrivateSpaceIdentity, context: MenuBarManualContext) async {
        let digest = digest(identity)
        bindings.removeAll { $0.opaqueDigest == digest }
        bindings.append(SpaceContextBinding(opaqueDigest: digest, display: identity.display,
            contextID: context.id, contextName: context.name))
        try? await store.save(bindings)
    }

    public func contextID(for identity: PrivateSpaceIdentity) -> UUID? {
        let currentBuild = CompatibilityRuntime.current.osBuild
        return bindings.first { binding in
            binding.opaqueDigest == digest(identity) && binding.osBuild == currentBuild
                && (binding.display == nil || identity.display.map { binding.display?.matches($0) == true } == true)
        }?.contextID
    }

    public func invalidateForTopologyChange(validDisplays: [DisplayIdentity]) async {
        bindings.removeAll { binding in
            guard let display = binding.display else { return false }
            return !validDisplays.contains { display.matches($0) }
        }
        try? await store.save(bindings)
    }

    private func digest(_ identity: PrivateSpaceIdentity) -> String {
        var input = salt
        withUnsafeBytes(of: identity.rawValue.bigEndian) { input.append(contentsOf: $0) }
        if let display = identity.display {
            input.append(Data("\(display.vendor):\(display.model):\(display.serial)".utf8))
        }
        return SHA256.hash(data: input).map { String(format: "%02x", $0) }.joined()
    }
}

private enum PrivateSpaceSalt {
    private static let service = "com.saransh.tonic.private-space"
    static func loadOrCreate() -> Data {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service,
                                   kSecAttrAccount as String: "binding-salt"]
        var query = base
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data, data.count == 32 { return data }
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let data = Data(bytes)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        _ = SecItemAdd(add as CFDictionary, nil)
        return data
    }
}

@MainActor
@Observable
public final class PrivateSpaceCoordinator {
    public static let shared: PrivateSpaceCoordinator = {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tonic/PrivateContexts", isDirectory: true)
        let observer = QuarantinedPrivateSpaceObserver(authorization: {
            let decision = await TonicCompatibilityAuthority.shared.decision(for: .automaticSpaceContexts)
            return decision.isEnabled && QuarantinedPrivateSpaceObserver.runtimePreflight()
        })
        return PrivateSpaceCoordinator(observer: observer,
            store: PrivateSpaceBindingStore(fileURL: root.appendingPathComponent("bindings-v1.json")))
    }()

    private let observer: any PrivateSpaceObserver
    private let store: PrivateSpaceBindingStore
    private var token: NSObjectProtocol?
    private var topologyToken: NSObjectProtocol?
    public private(set) var compatibilityStatus = "Checking signed compatibility…"
    public private(set) var activeBindingName: String?
    private var currentIdentityValue: PrivateSpaceIdentity?

    public init(observer: any PrivateSpaceObserver, store: PrivateSpaceBindingStore) {
        self.observer = observer; self.store = store
    }

    public func start() {
        guard token == nil else { return }
        Task {
            await TonicCompatibilityAuthority.shared.start()
            await store.load()
            await refreshStatus()
        }
        token = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { _ in Task { @MainActor in await PrivateSpaceCoordinator.shared.spaceChanged() } }
        topologyToken = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { _ in Task { @MainActor in await PrivateSpaceCoordinator.shared.topologyChanged() } }
    }

    public func refreshStatus() async {
        let decision = await TonicCompatibilityAuthority.shared.decision(for: .automaticSpaceContexts)
        guard decision.isEnabled else {
            if case .disabled(let reason) = decision { compatibilityStatus = reason }
            activeBindingName = nil
            currentIdentityValue = nil
            return
        }
        guard QuarantinedPrivateSpaceObserver.runtimePreflight() else {
            compatibilityStatus = "The automatic Space adapter failed its runtime preflight. Manual contexts remain available."
            activeBindingName = nil
            currentIdentityValue = nil
            return
        }
        guard let identity = await observer.currentIdentity() else {
            compatibilityStatus = "No validated Space identity is available. Manual contexts remain available."
            activeBindingName = nil
            currentIdentityValue = nil
            return
        }
        currentIdentityValue = identity
        let contextID = await store.contextID(for: identity)
        activeBindingName = contextID.flatMap { id in
            MenuBarProfileStore.shared.manualContexts.first(where: { $0.id == id })?.name
        }
        compatibilityStatus = activeBindingName.map { "Automatically resolved to \($0)." }
            ?? "Compatible. Bind this Space to one of your named contexts."
    }

    public func bindCurrentSpace(to context: MenuBarManualContext) async {
        let identity: PrivateSpaceIdentity
        if let currentIdentityValue { identity = currentIdentityValue }
        else if let observed = await observer.currentIdentity() { identity = observed }
        else { await refreshStatus(); return }
        await store.bind(identity, context: context)
        activeBindingName = context.name
        compatibilityStatus = "Automatically resolved to \(context.name)."
        MenuBarProfileStore.shared.selectContext(context.id)
        NotificationCenter.default.post(name: .menuBarPresentationContextDidChange, object: nil)
    }

    private func spaceChanged() async {
        await refreshStatus()
        guard let identity = currentIdentityValue,
              let contextID = await store.contextID(for: identity) else { return }
        MenuBarProfileStore.shared.selectContext(contextID)
        NotificationCenter.default.post(name: .menuBarPresentationContextDidChange, object: nil)
    }

    private func topologyChanged() async {
        await store.invalidateForTopologyChange(validDisplays: NSScreen.screens.map(DisplayIdentity.init))
        await refreshStatus()
    }
}

#endif
