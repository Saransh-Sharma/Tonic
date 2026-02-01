# Delete Dead WidgetReader Directory

## Description
Remove the entire Services/WidgetReader/ directory containing ~2,605 lines of never-used code. This was part of an aborted architecture migration — the production system uses WidgetDataManager's inline methods.

**Size:** S

**Files to DELETE:**
- `Tonic/Tonic/Services/WidgetReader/WidgetReader.swift` (22 lines)
- `Tonic/Tonic/Services/WidgetReader/WidgetReaderManager.swift` (51 lines)
- `Tonic/Tonic/Services/WidgetReader/CPUReader.swift` (116 lines)
- `Tonic/Tonic/Services/WidgetReader/MemoryReader.swift` (393 lines)
- `Tonic/Tonic/Services/WidgetReader/DiskReader.swift` (745 lines)
- `Tonic/Tonic/Services/WidgetReader/NetworkReader.swift` (228 lines)
- `Tonic/Tonic/Services/WidgetReader/GPUReader.swift` (~150 lines)
- `Tonic/Tonic/Services/WidgetReader/BatteryReader.swift` (~200 lines)
- `Tonic/Tonic/Services/WidgetReader/SensorsReader.swift` (~300 lines)
- `Tonic/Tonic/Services/WidgetReader/BluetoothReader.swift` (~400 lines)

**Total: ~2,605 lines of dead code**

## Approach

1. Verify no code references any WidgetReader classes:
   ```bash
   grep -r "WidgetReader" Tonic/Tonic/ --exclude-dir=WidgetReader
   ```
   Should return no results (except the directory itself)

2. Verify no code imports from WidgetReader:
   ```bash
   grep -r "import.*WidgetReader" Tonic/Tonic/
   ```

3. Delete entire directory:
   ```bash
   rm -rf Tonic/Tonic/Services/WidgetReader/
   ```

4. Build project to verify no broken references

## Key Context

**Why This Is Dead Code:**
- No readers are ever registered with WidgetReaderManager
- WidgetRefreshScheduler (intended to work with these readers) is never started
- Production system uses WidgetDataManager with inline update methods
- The read() methods in these readers are NEVER called

**Critical Bug in Dead Code:** WidgetReaderManager has a type casting bug that would always fail:
```swift
guard let reader = readers[key] as? R else { ... }
```
The cast fails because `readers` stores type-erased `any WidgetReader`.

**Risk:** ZERO — This code was never executed in production.

## Acceptance
- [ ] Verified no references to WidgetReader classes exist
- [ ] Verified no imports from WidgetReader directory
- [ ] Entire WidgetReader directory deleted
- [ ] Project builds without errors
- [ ] All widgets still function correctly
- [ ] ~2,605 lines of dead code removed

## Done summary
Removed dead WidgetReader directory (~2,605 lines) and WidgetRefreshScheduler.swift from an aborted architecture migration. Total of 3,579 lines of dead code deleted.
## Evidence
- Commits: 0b80bcc7ee153db81d1042e013547c8ac5e7ffc2
- Tests:
- PRs: