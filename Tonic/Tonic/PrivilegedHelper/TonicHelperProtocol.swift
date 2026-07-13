import Foundation

public enum TonicPrivilegedOperation: Codable, Equatable, Sendable {
    case deleteLocalTimeMachineSnapshots
    case purgeStaleDocumentRevisions(minimumAgeDays: Int)
    case refreshDNS
    case renewPrimaryNetworkService
    case rebuildSpotlight(scope: TonicVolumeScope)
    case rebuildLaunchServices
    case restartSystemService(service: TonicSystemService)
    case purgeStaleSystemData(domain: TonicCleanupDomain, minimumAgeDays: Int)
    case setFanMode(fanID: Int, automatic: Bool, sessionID: UUID)
    case setFanTargetRPM(fanID: Int, rpm: Int, sessionID: UUID)
    case renewFanSession(sessionID: UUID)
    case restoreAutomaticFanControl(sessionID: UUID)
}

public struct TonicHelperRequest: Codable, Equatable, Sendable {
    public static let currentVersion = 2
    public var version: Int
    public var requestID: UUID
    public var operation: TonicPrivilegedOperation

    public init(version: Int = Self.currentVersion, requestID: UUID = UUID(),
                operation: TonicPrivilegedOperation) {
        self.version = version
        self.requestID = requestID
        self.operation = operation
    }
}

public enum TonicHelperError: String, Codable, Equatable, Sendable, Error {
    case malformedRequest
    case requestTooLarge
    case unsupportedVersion
    case unauthorizedClient
    case invalidArgument
    case operationFailed
    case helperUnavailable
    case staleSession
}

public struct TonicHelperResult: Codable, Equatable, Sendable {
    public var requestID: UUID
    public var succeeded: Bool
    public var detail: String
    public var affectedItems: Int
    public var error: TonicHelperError?

    public init(requestID: UUID, succeeded: Bool, detail: String,
                affectedItems: Int = 0, error: TonicHelperError? = nil) {
        self.requestID = requestID
        self.succeeded = succeeded
        self.detail = detail
        self.affectedItems = affectedItems
        self.error = error
    }
}

@objc public protocol TonicHelperXPCProtocol {
    func perform(requestData: Data, withReply reply: @escaping (Data) -> Void)
}

public enum TonicHelperPolicy {
    public static let machServiceName = "com.saransh.tonic.helper"
    public static let daemonPlistName = "com.saransh.tonic.helper.plist"
    public static let maximumRequestBytes = 32 * 1024
    public static let minimumRevisionAgeDays = 1
    public static let maximumRevisionAgeDays = 365
    public static let minimumFanRPM = 0
    public static let maximumFanRPM = 6_000
    public static let minimumCleanupAgeDays = 7
    public static let maximumCleanupAgeDays = 365

    public static func validated(_ request: TonicHelperRequest) -> TonicHelperError? {
        guard request.version == TonicHelperRequest.currentVersion else { return .unsupportedVersion }
        switch request.operation {
        case .purgeStaleDocumentRevisions(let days):
            guard (minimumRevisionAgeDays...maximumRevisionAgeDays).contains(days) else { return .invalidArgument }
        case .setFanMode(let fanID, _, _):
            guard (0...15).contains(fanID) else { return .invalidArgument }
        case .setFanTargetRPM(let fanID, let rpm, _):
            guard (0...15).contains(fanID), (minimumFanRPM...maximumFanRPM).contains(rpm) else { return .invalidArgument }
        case .purgeStaleSystemData(_, let days):
            guard (minimumCleanupAgeDays...maximumCleanupAgeDays).contains(days) else { return .invalidArgument }
        case .deleteLocalTimeMachineSnapshots, .refreshDNS, .renewPrimaryNetworkService,
             .rebuildSpotlight, .rebuildLaunchServices, .restartSystemService,
             .renewFanSession, .restoreAutomaticFanControl:
            break
        }
        return nil
    }
}
