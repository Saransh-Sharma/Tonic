- [ ] All enums have explicit `Sendable` conformance (except VisualizationType which already has it)
- [ ] SpeedTestService closure capture warning fixed
- [ ] WidgetDataManager deinit no longer uses Task { await }
- [ ] WidgetHistoryStore nonisolated(unsafe) warning fixed
- [ ] No new `@unchecked Sendable` without proper locks
- [ ] No Sendable-conformance warnings remain
- [ ] Build succeeds

## Test Commands
```bash
xcodebuild -project Tonic/Tonic.xcodeproj -scheme Tonic build 2>&1 | grep -E "Sendable" | wc -l
```
