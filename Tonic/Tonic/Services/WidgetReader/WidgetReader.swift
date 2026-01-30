import Foundation

/// Protocol for widget data sources following Stats Master's reader pattern
protocol WidgetReader {
    associatedtype Output: Sendable

    /// Preferred refresh interval in seconds
    var preferredInterval: TimeInterval { get }

    /// Read current value asynchronously
    /// - Returns: Current data value
    /// - Throws: ReaderError if data unavailable
    func read() async throws -> Output
}

enum ReaderError: Error {
    case unavailable(String)
    case permissionDenied(String)
    case timeout
    case invalidData
}
