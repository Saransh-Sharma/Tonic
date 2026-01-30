import Foundation

@Observable
@MainActor
final class WidgetReaderManager {
    static let shared = WidgetReaderManager()

    private var readers: [String: any WidgetReader] = [:]
    private var cache: [String: (value: Any, timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval = 30.0

    private init() {}

    /// Register a reader for a specific key
    func register<R: WidgetReader>(_ reader: R, forKey key: String) {
        readers[key] = reader
    }

    /// Get cached value or read fresh if cache expired
    func getValue<R: WidgetReader>(forKey key: String, type: R.Type) async throws -> R.Output {
        // Check cache first
        if let cached = cache[key],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL,
           let typedValue = cached.value as? R.Output {
            return typedValue
        }

        // Cache miss or expired - read fresh
        guard let reader = readers[key] as? R else {
            throw ReaderError.unavailable("No reader registered for key: \(key)")
        }

        let value = try await reader.read()
        cache[key] = (value, Date())
        return value
    }

    /// Refresh all readers
    func refreshReaders() async {
        for (key, reader) in readers {
            do {
                // Type-erased read - we store the result but don't return it
                _ = try await reader.read()
                cache[key] = (reader, Date())  // Placeholder - actual value stored in typed cache
            } catch {
                print("Warning: Failed to refresh reader for \(key): \(error)")
            }
        }
    }
}
