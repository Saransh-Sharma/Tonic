import Foundation

/// Stable identifiers shared by Recovery planning, the direct app, and the
/// privileged helper. These types carry no executable path or command data.
public enum TonicVolumeScope: String, Codable, Hashable, Sendable {
    case startupDisk
}

public enum TonicSystemService: String, Codable, CaseIterable, Hashable, Sendable {
    case dnsResponder
    case audio
    case bluetooth
    case printing
    case timeMachine
}

public enum TonicCleanupDomain: String, Codable, CaseIterable, Hashable, Sendable {
    case systemCaches
    case diagnosticReports
    case packageUpdates
}
