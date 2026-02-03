# Implementation Review Export: fn-6-i4g.7 (Disk Enhanced Reader)

**Task:** fn-6-i4g.7 - Disk Enhanced Reader
**Branch:** menu-stats-revamp
**Base Commit:** 14483c3ecbe71716ff5b1eadc4a30920099f0965
**Review Commit:** 28371c616a5a3103c335dc03d821bce46c16a514

## Task Description

Implement Stats Master's enhanced disk readers including NVMe SMART data and IOPS tracking.

### Acceptance Criteria
- [x] DiskVolumeData extended with smartData
- [x] DiskVolumeData extended with readIOPS, writeIOPS
- [x] DiskVolumeData extended with readBytesPerSecond, writeBytesPerSecond
- [x] DiskVolumeData extended with topProcesses
- [x] NVMe SMART reader implemented
- [x] Temperature, life percentage, critical warnings captured
- [x] IOPS tracking implemented
- [x] Activity bytes per second calculated
- [x] Process disk I/O via proc_pid_rusage
- [x] Graceful fallback for non-NVMe drives
- [x] All new readers follow Reader protocol

## Changed Files

- `Tonic/Tonic/Services/WidgetReader/DiskReader.swift` (+491, -23 lines)

## Implementation Summary

### 1. NVMe SMART Data Reading

Added `getNVMeSMARTData()` with two approaches:
- **Primary**: `getSMARTFromIORegistry()` - Reads SMART data from IORegistry properties via IONVMeController
- **Fallback**: `getFallbackSMARTData()` - Uses `system_profiler SPNVMeDataType -json` for non-IORegistry systems

Captures:
- Temperature (Composite Temperature)
- Percentage Used (drive life)
- Critical Warning flag
- Power Cycles
- Power On Hours
- Data Units Read/Written

### 2. IOPS Tracking

Added `getIOStatsWithRates()` with delta calculation:
- Reads from IORegistry `kIOBlockStorageDriverClass` services
- Tracks both byte counts AND operation counts
- Calculates IOPS (read/write operations per second) from deltas
- Returns (readIOPS, writeIOPS, readBps, writeBps)

### 3. Activity Bytes Per Second

Enhanced `DiskActivityReader` and main `DiskReader`:
- Fixed IORegistry property key from `kIOPropertyPlaneKey` to `"Statistics"`
- Proper delta calculation between snapshots
- Thread-safe via `statsLock` (NSLock)

### 4. Process Disk I/O Tracking

Added `getTopDiskProcesses()`:
- Uses `/bin/ps -ax -o pid` to enumerate processes
- Calls `proc_pid_rusage()` with `RUSAGE_INFO_CURRENT` for each PID
- Tracks delta from previous snapshot (not just cumulative)
- Sorts by total I/O (read + write delta)
- Retrieves process icons via `NSRunningApplication` or bundle lookup

### 5. Code Quality

- NVMe SMART interface UUIDs defined (for future IOKit plugin use)
- Proper memory management with `defer { IOObjectRelease() }`
- Thread safety via `statsLock` for shared state
- Graceful nil returns for missing data

## Diff

```diff
diff --git a/Tonic/Tonic/Services/WidgetReader/DiskReader.swift b/Tonic/Tonic/Services/WidgetReader/DiskReader.swift
index 0b17c88..1ce0a5a 100644
--- a/Tonic/Tonic/Services/WidgetReader/DiskReader.swift
+++ b/Tonic/Tonic/Services/WidgetReader/DiskReader.swift
@@ -4,36 +4,69 @@
 //  Task ID: fn-6-i4g.7

+import AppKit
+
+// MARK: - NVMe SMART Interface Constants
+private let kIONVMeSMARTUserClientTypeID = CFUUIDGetConstantUUIDWithBytes(...)
+private let kIONVMeSMARTInterfaceID = CFUUIDGetConstantUUIDWithBytes(...)
+private let kIOCFPlugInInterfaceID = CFUUIDGetConstantUUIDWithBytes(...)

+/// Enhanced disk data reader with SMART, IOPS, and process tracking
 @MainActor
 final class DiskReader: WidgetReader {
-    private var previousActivity: [String: (read: UInt64, write: UInt64)] = [:]
-    private let activityLock = NSLock()
+    private var previousIOStats: DiskIOSnapshot?
+    private var previousProcessStats: [Int32: ProcessIOSnapshot] = [:]
+    private let statsLock = NSLock()

     private func getDiskData() async -> [DiskVolumeData] {
+        let (readIOPS, writeIOPS, readBps, writeBps) = getIOStatsWithRates()
+        let smartData = getNVMeSMARTData()
+        let topProcesses = getTopDiskProcesses(limit: 8)

+        // Attach enhanced data to boot/internal volumes only
         let volumeData = DiskVolumeData(
             ...
+            smartData: volumeSMART,
+            readIOPS: volumeReadIOPS,
+            writeIOPS: volumeWriteIOPS,
+            readBytesPerSecond: volumeReadBps,
+            writeBytesPerSecond: volumeWriteBps,
+            topProcesses: volumeTopProcesses,
+            timestamp: now
         )
     }

+    // MARK: - I/O Statistics with IOPS and Throughput
+    private struct DiskIOSnapshot { ... }
+    private func getIOStatsWithRates() -> (Double?, Double?, Double?, Double?) { ... }
+    private func getRawIOStats() -> (readBytes: UInt64, writeBytes: UInt64, readOps: UInt64, writeOps: UInt64) { ... }

+    // MARK: - NVMe SMART Data
+    private func getNVMeSMARTData() -> NVMeSMARTData? { ... }
+    private func getSMARTFromIORegistry() -> NVMeSMARTData? { ... }
+    private func getFallbackSMARTData() -> NVMeSMARTData? { ... }

+    // MARK: - Process Disk I/O Tracking
+    private struct ProcessIOSnapshot { ... }
+    private func getTopDiskProcesses(limit: Int = 8) -> [ProcessUsage]? { ... }
+    private func getAppIconForProcess(pid: Int32, name: String) -> NSImage? { ... }
 }

 // DiskActivityReader also fixed:
 // - Changed property key from kIOPropertyPlaneKey to "Statistics"
 // - Added GB/s formatting tier
```

## Review Prompt for External LLM

Please review this implementation for:

1. **Correctness**: Do the IOKit calls correctly read SMART data and I/O statistics?
2. **Thread Safety**: Is the NSLock usage correct for protecting shared state?
3. **Memory Management**: Are IOKit objects properly released?
4. **Error Handling**: Are edge cases handled gracefully?
5. **Performance**: Is the process enumeration efficient enough for 2-second intervals?
6. **Architecture**: Does this follow the Reader protocol pattern correctly?

Key concerns to evaluate:
- The `proc_pid_rusage` call iterates all processes - is this performant?
- The SMART data fallback uses `system_profiler` which spawns a process - acceptable?
- Are the delta calculations correct for wraparound edge cases?

---

**Build Status:** SUCCESS (xcodebuild -scheme Tonic -configuration Debug build)
