# fn-5-v8r.1 WidgetReader protocol and base architecture

## Description
Define the `WidgetReader` protocol and create the base architecture for the new widget system. This establishes the foundation for all widget types and replaces the per-widget timer architecture with a unified approach.

Stats Master uses a modular reader pattern where each data source is an independent reader with declared preferred refresh interval, async `read()` method, error handling, and background-aware execution. Tonic's current implementation has per-widget timers which cause CPU overuse.

## Implementation

### Protocol Definition

Create `Tonic/Tonic/Services/WidgetReader/WidgetReader.swift`:

```swift
protocol WidgetReader {
    associatedtype Output: Sendable
    var preferredInterval: TimeInterval { get }
    func read() async throws -> Output
}

enum ReaderError: Error {
    case unavailable(String)
    case permissionDenied(String)
    case timeout
    case invalidData
}
```

### WidgetReaderManager

Create `Tonic/Tonic/Services/WidgetReader/WidgetReaderManager.swift`:

```swift
@Observable
@MainActor
final class WidgetReaderManager {
    private var readers: [String: any WidgetReader] = [:]
    private var cache: [String: (value: Any, timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval = 30.0
    func register<R: WidgetReader>(_ reader: R, forKey key: String)
    func getValue<R: WidgetReader>(forKey key: String, type: R.Type) async throws -> R.Output
    func refreshReaders() async
}
```

### New Files
- `Tonic/Tonic/Services/WidgetReader/WidgetReader.swift`
- `Tonic/Tonic/Services/WidgetReader/WidgetReaderManager.swift`

## Acceptance
- [ ] `WidgetReader` protocol defined with required members
- [ ] `WidgetReaderManager` compiles with `@Observable` and `@MainActor`
- [ ] Cache implemented with 30s TTL
- [ ] Unit tests pass for reader registration and retrieval
- [ ] No regressions in existing code (new code only)

## Done summary
- Task completed
## Evidence
- Commits:
- Tests:
- PRs:
## References
- Stats Master: `stats-master/Kit/module/reader.swift:123-149`
- Tonic existing: `Tonic/Tonic/Services/WidgetDataManager.swift:235-1151`
