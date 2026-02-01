# Add Missing Notification Integrations (Network, Bluetooth)

## Description
Integrate notification threshold checking for Network and Bluetooth widgets. The NotificationManager already has notification content defined for both types, but checkThreshold() is never called.

**Size:** S

**Files:**
- `Tonic/Tonic/Services/WidgetDataManager.swift`
  - Line ~2008 in updateNetworkData()
  - Line ~3228 in updateBluetoothData()
- `Tonic/Tonic/Services/NotificationManager.swift` (lines 244-247, 258-261 - already complete)

## Approach

### Network Notification Integration
In `WidgetDataManager.updateNetworkData()` after line ~2008:
```swift
// Check notification thresholds for network speed
let totalSpeedMBps = (uploadRate + downloadRate) / 1_000_000  // Convert to MB/s
NotificationManager.shared.checkThreshold(widgetType: .network, value: totalSpeedMBps)
```

Follow the existing pattern from CPU (line 828), Memory (line 1237), etc.

### Bluetooth Notification Integration
In `WidgetDataManager.updateBluetoothData()` after line ~3228:
```swift
// Check notification thresholds for Bluetooth device batteries
if let lowestBattery = newData.devicesWithBattery
    .filter { $0.isConnected }
    .compactMap { $0.primaryBatteryLevel }
    .min() {
    NotificationManager.shared.checkThreshold(widgetType: .bluetooth, value: Double(lowestBattery))
}
```

## Key Context

**Existing Pattern**: 6 of 8 widget types already have checkThreshold() integrated:
- CPU (line 828) ✅
- Memory (line 1237) ✅
- Disk (line 1625) ✅
- GPU (line 2557) ✅
- Battery (line 2710) ✅
- Sensors (line 2820) ✅
- Network (MISSING) ❌
- Bluetooth (MISSING) ❌

**Notification Content**: Already exists in NotificationManager.swift:
- Network: lines 244-247 ("Network Alert" with MB/s format)
- Bluetooth: lines 258-261 ("Bluetooth Device Alert" with % format)

## Acceptance
- [ ] Network checkThreshold() call added to updateNetworkData()
- [ ] Bluetooth checkThreshold() call added to updateBluetoothData()
- [ ] Network notification fires when speed threshold exceeded
- [ ] Bluetooth notification fires when device battery low
- [ ] Notifications respect debouncing (minimum interval)
- [ ] Notifications respect Do Not Disturb (if configured)
- [ ] All 8 widget types now have notification integration

## Done Summary
Added notification threshold checking for Network and Bluetooth widgets, completing 100% notification coverage across all 8 widget types.

## Evidence
- Commits:
- Tests:
- PRs:
