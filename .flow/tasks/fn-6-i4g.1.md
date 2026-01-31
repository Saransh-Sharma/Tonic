# fn-6-i4g.1 Reader Architecture Foundation

## Description
Create the foundational reader architecture that will support Stats Master-style data reading while maintaining Tonic's `@Observable` and `@MainActor` patterns.

**Size:** M

**Files:** 
- `Tonic/Tonic/Services/ReaderProtocol.swift` (new)
- `Tonic/Tonic/Services/WidgetDataManager.swift` (modify)
- `Tonic/Tonic/Services/Repeater.swift` (new, optional)

Create a `Reader<T>` protocol inspired by Stats Master's `reader.swift:123-149` but adapted for Tonic's architecture:

```swift
protocol Reader {
    associatedtype T: Sendable
    var value: T? { get }
    var interval: TimeInterval? { get }
    var isOptional: Bool { get }
    var isPopupOnly: Bool { get }
    var isActive: Bool { get }
    
    func start()
    func stop()
    func pause()
    func read() -> T?
}
```

The protocol should support:
- Configurable update intervals (1-60 seconds)
- Optional readers (can be disabled without error)
- Popup-only readers (only run when widget popup is open)
- History tracking flag

**Key difference from Stats Master**: Use `@Observable` and `@MainActor` instead of manual `DispatchQueue` synchronization. This keeps Tonic's modern concurrency model.

## Approach

1. Create `ReaderProtocol.swift` in `Services/` directory
2. Define `Reader<T>` protocol with associated type
3. Create base `BaseReader<T>` class with common implementation
4. Use `@MainActor` for UI-related readers
5. Add `history` property: `Int?` (nil = no history, N = store N points)
6. Add `callback` closure for value updates
7. Follow Stats Master's `reader.swift:123-149` for lifecycle methods

Do NOT implement specific readers yet — this is just the protocol and base class.

## Key Context

Stats Master's reader pattern uses `Repeater` class for per-reader timers. Tonic currently uses a unified timer in `WidgetCoordinator`. We're keeping the unified timer for efficiency, but the protocol should support optional per-reader timing for future flexibility.

Reference: `WidgetStatusItem.swift:546-563` for current unified timer pattern.
## Acceptance
- [ ] `Reader<T>` protocol defined in new file
- [ ] `BaseReader<T>` class with common implementation
- [ ] Protocol supports: interval, optional, popupOnly, history, callback
- [ ] Lifecycle methods: start(), stop(), pause() 
- [ ] `@MainActor` isolation for UI-safe readers
- [ ] `Sendable` conformance for associated type T
- [ ] Documentation comments on protocol requirements
- [ ] No specific reader implementations (foundation only)
## Done summary
Implemented the Reader<T> protocol and BaseReader<T> class foundation following Stats Master's reader pattern, adapted for Tonic's @Observable and @MainActor architecture. Added Repeater class for per-reader timers and ReaderRegistry for centralized management. Protocol supports optional readers, popup-only mode, configurable intervals, and history tracking.
## Evidence
- Commits: e40f1c7ca754e760fb43f4bf3b509aea51a0dd26
- Tests: xcodebuild -scheme Tonic -configuration Debug build
- PRs: