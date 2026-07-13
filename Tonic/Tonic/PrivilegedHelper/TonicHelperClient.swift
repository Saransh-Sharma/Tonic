#if !TONIC_HELPER

import Foundation
import Security
import ServiceManagement

@MainActor
@Observable
public final class TonicHelperClient {
    public static let shared = TonicHelperClient()

    public private(set) var status: SMAppService.Status = .notRegistered
    public private(set) var lastError: String?
    private var connection: NSXPCConnection?
    private let fanSessionID = UUID()
    private var renewalTask: Task<Void, Never>?
    public var hasActiveFanSession: Bool { renewalTask != nil }

    private var service: SMAppService {
        SMAppService.daemon(plistName: TonicHelperPolicy.daemonPlistName)
    }

    private init() { refreshStatus() }

    public func refreshStatus() { status = service.status }

    public func register() throws {
        try service.register()
        refreshStatus()
    }

    public func unregister() async throws {
        try await service.unregister()
        connection?.invalidate()
        connection = nil
        refreshStatus()
    }

    public func perform(_ operation: TonicPrivilegedOperation) async -> TonicHelperResult {
        let request = TonicHelperRequest(operation: operation)
        guard let data = try? JSONEncoder().encode(request) else {
            return TonicHelperResult(requestID: request.requestID, succeeded: false,
                                     detail: "Could not encode the helper request.", error: .malformedRequest)
        }
        let connection = activeConnection()
        let result: TonicHelperResult = await withCheckedContinuation { continuation in
            let proxy = connection.remoteObjectProxyWithErrorHandler { [weak self] error in
                Task { @MainActor in self?.lastError = error.localizedDescription }
                continuation.resume(returning: TonicHelperResult(
                    requestID: request.requestID, succeeded: false,
                    detail: error.localizedDescription, error: .helperUnavailable
                ))
            } as? TonicHelperXPCProtocol
            guard let proxy else {
                continuation.resume(returning: TonicHelperResult(
                    requestID: request.requestID, succeeded: false,
                    detail: "The helper connection is unavailable.", error: .helperUnavailable
                ))
                return
            }
            proxy.perform(requestData: data) { response in
                let result = (try? JSONDecoder().decode(TonicHelperResult.self, from: response))
                    ?? TonicHelperResult(requestID: request.requestID, succeeded: false,
                                         detail: "The helper returned an invalid response.", error: .malformedRequest)
                continuation.resume(returning: result)
            }
        }
        ActionReceiptStore.shared.record(ActionReceipt(
            tool: .smartCare,
            title: result.succeeded ? "Privileged operation completed" : "Privileged operation failed",
            detail: result.detail,
            status: result.succeeded ? .success : .failed,
            affectedItems: result.affectedItems,
            metadata: ["requestID": result.requestID.uuidString,
                       "operation": operation.receiptName,
                       "error": result.error?.rawValue ?? "none"]
        ))
        return result
    }

    public func setFanMode(fanID: Int, automatic: Bool) async -> TonicHelperResult {
        let result = await perform(.setFanMode(fanID: fanID, automatic: automatic, sessionID: fanSessionID))
        if result.succeeded && !automatic { startRenewingFanSession() }
        if automatic { stopRenewingFanSession() }
        return result
    }

    public func setFanTargetRPM(fanID: Int, rpm: Int) async -> TonicHelperResult {
        let result = await perform(.setFanTargetRPM(fanID: fanID, rpm: rpm, sessionID: fanSessionID))
        if result.succeeded { startRenewingFanSession() }
        return result
    }

    public func restoreAutomaticFanControl() async -> TonicHelperResult {
        let result = await perform(.restoreAutomaticFanControl(sessionID: fanSessionID))
        stopRenewingFanSession()
        return result
    }

    private func activeConnection() -> NSXPCConnection {
        if let connection { return connection }
        let created = NSXPCConnection(machServiceName: TonicHelperPolicy.machServiceName, options: .privileged)
        created.remoteObjectInterface = NSXPCInterface(with: TonicHelperXPCProtocol.self)
        created.setCodeSigningRequirement(
            "anchor apple generic and certificate leaf[subject.OU] = \"CJ43UNM3AR\" and identifier \"com.saransh.tonic.helper\""
        )
        created.invalidationHandler = { [weak self] in
            Task { @MainActor in self?.handleConnectionLoss() }
        }
        created.interruptionHandler = { [weak self] in
            Task { @MainActor in self?.handleConnectionLoss() }
        }
        created.resume()
        connection = created
        return created
    }

    private func startRenewingFanSession() {
        guard renewalTask == nil else { return }
        renewalTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self, !Task.isCancelled else { return }
                let result = await self.perform(.renewFanSession(sessionID: self.fanSessionID))
                if !result.succeeded { self.stopRenewingFanSession(); return }
            }
        }
    }

    private func stopRenewingFanSession() { renewalTask?.cancel(); renewalTask = nil }
    private func handleConnectionLoss() { connection = nil; stopRenewingFanSession() }
}

private extension TonicPrivilegedOperation {
    var receiptName: String {
        switch self {
        case .deleteLocalTimeMachineSnapshots: "deleteLocalSnapshots"
        case .purgeStaleDocumentRevisions: "purgeStaleDocumentRevisions"
        case .refreshDNS: "refreshDNS"
        case .renewPrimaryNetworkService: "renewPrimaryNetworkService"
        case .rebuildSpotlight: "rebuildSpotlight"
        case .rebuildLaunchServices: "rebuildLaunchServices"
        case .restartSystemService(let service): "restartSystemService.\(service.rawValue)"
        case .purgeStaleSystemData(let domain, _): "purgeStaleSystemData.\(domain.rawValue)"
        case .setFanMode: "setFanMode"
        case .setFanTargetRPM: "setFanTargetRPM"
        case .renewFanSession: "renewFanSession"
        case .restoreAutomaticFanControl: "restoreAutomaticFanControl"
        }
    }
}

#endif
