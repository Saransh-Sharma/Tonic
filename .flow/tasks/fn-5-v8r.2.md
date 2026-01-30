# fn-5-v8r.2 WidgetRefreshScheduler unified timer implementation

## Description
Implement unified refresh scheduler to replace Tonic's per-widget timer architecture. Stats Master uses a single `Repeater` class that coalesces updates. This task implements the equivalent using Swift Concurrency.

Current Tonic issue: Each `WidgetStatusItem` has its own 1-second timer (7 widgets = 7 timers). This causes unnecessary CPU wakeups.

## Implementation

Create `Tonic/Tonic/Services/WidgetRefreshScheduler.swift`:

```swift
@Observable
@MainActor
final class WidgetRefreshScheduler {
    private var updateTask: Task<Void, Never>?
    private var readerManager: WidgetReaderManager
    private var currentInterval: TimeInterval = 2.0

    func startMonitoring()
    func stopMonitoring()
    func updateInterval(_ interval: TimeInterval)

    private func refreshLoop() async
}
```

Key design:
- Single `Task` with `Task.sleep()` for periodic updates
- Coalesce readers by preferred interval
- Suspend when app backgrounds (observe `NSWorkspace.didHideNotification`)
- Resume on `NSWorkspace.didUnhideNotification`

## Acceptance
- [ ] Single scheduler instance replaces per-widget timers
- [ ] Configurable intervals (1, 2, 3, 5, 10, 15, 30, 60s)
- [ ] Background observers suspend/resume correctly
- [ ] No CPU wakeups when all widgets inactive

## Done summary
- Task completed
## Evidence
- Commits:
- Tests:
- PRs:
## References
- Stats Master: `stats-master/Kit/plugins/Repeater.swift:25-72`
- Tonic current: `Tonic/Tonic/MenuBarWidgets/WidgetStatusItem.swift:74-82`
