# fn-8-v3b.2 Increase chart history to 180 points in WidgetDataManager

## Description
Increase chart history from 60 points to 180 points across all widgets in `WidgetDataManager.swift` for Stats Master parity.

**Size:** M

**Files:**
- `Tonic/Tonic/Services/WidgetDataManager.swift` (~3711 lines)
- All chart components that reference maxHistoryPoints

## Approach

1. Update `maxHistoryPoints` constant at line ~651 from 60 to 180
2. Update `CircularBuffer` initialization sizes for all widget types
3. Verify history arrays sync correctly with new size
4. Profile memory usage (180 × 8 bytes × 10 arrays ≈ 14 KB)

Current circular buffer implementation at line ~656 provides O(1) add operation, so scaling to 180 should not impact performance.

History tracking exists for:
- cpuHistory (line 696)
- memoryHistory (line 704)
- diskHistory (line 711)
- networkUploadHistory / networkDownloadHistory (line 718-719)
- gpuHistory (line 733)
- batteryHistory (line 738)
- sensorsHistory (line 743)
- bluetoothHistory (line 749)

## Key Context

The `connectivityHistory` at line 728 has a separate limit of 90 - this should remain unchanged as it's specific to the grid visualization.

No migration needed - arrays auto-populate to 180 on app restart.
## Acceptance
- [ ] maxHistoryPoints constant changed from 60 to 180
- [ ] All widget circular buffers initialized to 180
- [ ] History access methods return correct 180-point arrays
- [ ] Memory usage under 20 KB for all history arrays
- [ ] No performance regression in chart rendering
## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
