# fn-9-co9.7 Phase 6: Logic & Cleanup Warnings

## Description
# Phase 6: Logic & Cleanup Warnings

Fix ~50 minor compiler warnings (unused variables, unreachable code, etc.).

## What to Fix

**Unused variables / var → let:**
- Variables declared `var` but never mutated (should be `let`)
- Variables written to but never read (dead stores)

**Structural issues:**
- Unused results (`let _ = loadAllConfigs()`)
- Redundant `try` on non-throwing functions
- Unreachable `catch` blocks (no errors thrown in `do`)
- Non-optional `??` (nil-coalescing on non-optional)
- Unreachable `default` in switches
- Duplicate switch cases
- Dangling pointer in `PerformanceValidation.swift`

**Size:** M (many files, simple fixes)
**Files:** Distributed across the codebase (check build output for locations)

## Approach

**var → let:**
```swift
// OLD
var url = URL(...)  // Never changed

// NEW
let url = URL(...)
```

**Unused result:**
```swift
// OLD
let _ = loadAllConfigs()  // Warning about unused result

// NEW
loadAllConfigs()  // Fixed if return not needed
```

**Redundant try:**
```swift
// OLD
try nonThrowingFunction()  // Warning

// NEW
nonThrowingFunction()
```

**Unreachable catch:**
```swift
// OLD
do {
    let x = 5  // No throwing
} catch {
    // Unreachable
}

// NEW
let x = 5  // Remove do-catch entirely
```

**Non-optional ??:**
```swift
// MemoryPopoverView.swift specific fix
let value: Int = getInt() ?? 0  // getInt() returns non-optional
let value: Int = getInt()
```

**Dangling pointer (PerformanceValidation.swift):**
```swift
// Use proper scoping
withUnsafeMutablePointer(to: &value) { ptr in
    // Safe scope
}
```

## Key Context

These are purely structural fixes - no behavior changes
- Compile carefully and review each change
- Some "unused" variables may be intentionally unused (use `_` to indicate)
## Acceptance
- [ ] No "unused variable" warnings
- [ ] No "var never mutated" warnings
- [ ] No "unreachable catch" warnings
- [ ] No "redundant try" warnings
- [ ] No "non-optional ??" warnings
- [ ] No "unreachable default" warnings
- [ ] No duplicate switch case warnings
- [ ] Dangling pointer warning fixed
- [ ] Build succeeds

## Test Commands
```bash
xcodebuild -project Tonic/Tonic.xcodeproj -scheme Tonic build 2>&1 | grep -E "unused|unreachable|redundant" | wc -l
```
## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
