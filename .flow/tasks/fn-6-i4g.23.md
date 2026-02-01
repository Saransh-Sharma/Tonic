# Add Missing History Tracking (GPU, Battery, Sensors, Disk)

## Description
Add history tracking for 4 widget types that currently don't track historical data. History tracking enables line chart visualizations.

**Size:** S

**Files:**
- `Tonic/Tonic/Services/WidgetDataManager.swift`
  - Line ~2556 in updateGPUData()
  - Line ~2710 in updateBatteryData()
  - Line ~2820 in updateSensorsData()
  - Line ~1625 in updateDiskData()

## Approach

Follow the existing pattern from CPU/Memory/Network history tracking using `addToHistory()`.

### GPU History (after line 2556)
```swift
if let gpuUsage = usage {
    self.addToHistory(&self.gpuHistory, value: gpuUsage, maxPoints: Self.maxHistoryPoints)
}
```

### Battery History (after line 2710)
```swift
self.addToHistory(&self.batteryHistory, value: Double(capacity), maxPoints: Self.maxHistoryPoints)
```

### Sensors History (after line 2820)
```swift
if let maxTemp = newSensorsData.temperatures.map({ $0.value }).max() {
    self.addToHistory(&self.sensorsHistory, value: maxTemp, maxPoints: Self.maxHistoryPoints)
}
```

### Disk History (after line 1625)
```swift
if let primary = self.diskVolumes.first {
    self.addToHistory(&self.diskHistory, value: primary.usagePercentage, maxPoints: Self.maxHistoryPoints)
}
```

## Key Context

**Current History Tracking Status:**
- CPU ✅ (cpuHistory exists)
- Memory ✅ (memoryHistory exists)
- Network ✅ (networkHistory exists)
- GPU ❌ (gpuHistory property exists but not populated)
- Battery ❌ (batteryHistory property exists but not populated)
- Sensors ❌ (sensorsHistory property exists but not populated)
- Disk ❌ (diskHistory property exists but not populated)

**Helper Method**: `addToHistory()` already exists in WidgetDataManager — use it for consistency.

**Pattern Reference**: See updateCPUData() for the correct history tracking pattern.

## Acceptance
- [ ] GPU history tracking added and populated
- [ ] Battery history tracking added and populated
- [ ] Sensors history tracking added and populated (max temp value)
- [ ] Disk history tracking added and populated (primary volume usage)
- [ ] Line chart visualizations work for all 4 widget types
- [ ] History respects maxHistoryPoints limit
- [ ] History arrays are properly maintained over time

## Done summary
- Task completed
## Evidence
- Commits:
- Tests:
- PRs: