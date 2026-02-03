- [x] All enums have explicit `Sendable` conformance (except VisualizationType which already has it)
- [x] SpeedTestService closure capture warning fixed
- [x] WidgetDataManager deinit no longer uses Task { await }
- [x] WidgetHistoryStore nonisolated(unsafe) warning fixed
- [x] No new `@unchecked Sendable` without proper locks
- [x] No Sendable-conformance warnings remain
- [x] Build succeeds

## Test Commands
```bash
xcodebuild -project Tonic/Tonic.xcodeproj -scheme Tonic build 2>&1 | grep -E "Sendable" | wc -l
```

## Done summary
- Task completed
## Evidence
- Commits:
- Tests:
- PRs: