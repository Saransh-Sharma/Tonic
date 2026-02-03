# Delete Dead Scheduler and Reader Protocol Files

## Description
Remove two additional files containing ~716 lines of never-used code: WidgetRefreshScheduler.swift and ReaderProtocol.swift.

**Size:** XS

**Files to DELETE:**
- `Tonic/Tonic/Services/WidgetRefreshScheduler.swift` (122 lines)
- `Tonic/Tonic/Services/ReaderProtocol.swift` (594 lines)

**Total: ~716 lines of dead code**

## Approach

### WidgetRefreshScheduler.swift (122 lines)
1. Verify startMonitoring() is never called:
   ```bash
   grep -r "WidgetRefreshScheduler" Tonic/Tonic/ --exclude-dir=Services
   ```
   Should return no results

2. Verify no references to refreshScheduler
3. Delete file

### ReaderProtocol.swift (594 lines)
1. Verify no class conforms to Reader<T>:
   ```bash
   grep -r ": Reader<" Tonic/Tonic/
   ```
   Should only return the definition itself

2. Verify no references to BaseReader, Repeater, ReaderRegistry
3. Delete file

### Combined Cleanup
After deleting both files, build project to verify no broken references.

## Key Context

**WidgetRefreshScheduler.swift:**
- Has startMonitoring() method but is NEVER started
- Was intended to replace per-widget timers
- Works with the (now-deleted) WidgetReader protocol

**ReaderProtocol.swift:**
- Defines Reader<T> protocol and BaseReader<T> class
- Has ZERO conformances in the codebase
- The Repeater class inside is never instantiated
- The ReaderRegistry is never used

**Combined with Task 24:** Total dead code removed = ~3,321 lines

**Risk:** ZERO — Neither file was ever executed in production.

## Acceptance
- [x] Verified WidgetRefreshScheduler is never referenced (deleted in task 24)
- [x] Verified ReaderProtocol has no conformances
- [x] WidgetRefreshScheduler.swift deleted (in task 24)
- [x] ReaderProtocol.swift deleted
- [x] Project builds without errors (no new errors introduced)
- [x] All widgets still function correctly
- [x] ~591 lines of dead code removed (ReaderProtocol.swift)

## Done summary
- Task completed
## Evidence
- Commits:
- Tests:
- PRs: