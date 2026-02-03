# fn-6-i4g.15 Bluetooth Module Implementation

## Description
Implement the Bluetooth module to display connected device information and battery levels in the menu bar widget system. This adds Tonic's 9th data source (matching Stats Master's module count).

**Size:** M
**Files:**
- `Tonic/Tonic/Services/WidgetReader/BluetoothReader.swift` (new)
- `Tonic/Tonic/Models/WidgetConfiguration.swift` (add `.bluetooth` case)
- `Tonic/Tonic/MenuBarWidgets/BluetoothWidgetView.swift` (new)
- `Tonic/Tonic/Services/WidgetDataManager.swift` (add bluetooth data)

## Approach

- Create `BluetoothReader` conforming to existing `WidgetReader` protocol at `Services/WidgetReader/WidgetReader.swift:4-14`
- Use `IOBluetooth` framework (not CoreBluetooth) to access paired device info without user prompts
- Follow pattern from `BatteryReader.swift` for IOKit-style device enumeration
- Add `.bluetooth` case to `WidgetType` enum following pattern at `Models/WidgetConfiguration.swift:14-63`
- Compatible visualizations: `stack` (device battery levels), `mini` (single device), `state` (connected indicator)

## Key Context

**IOBluetooth vs CoreBluetooth**: Use IOBluetooth for reading device properties without triggering Bluetooth permission dialogs. CoreBluetooth requires entitlements and user prompts.

**Data structure from PRD**:
```swift
struct BluetoothDevice {
    id: UUID
    name: String
    address: String
    deviceType: BluetoothDeviceType  // .mouse, .keyboard, .headphones, .other
    isConnected: Bool
    isPaired: Bool
    batteryLevel: Int?             // 0-100%
    rssi: Int?                     // Signal strength dBm
}
```
## Acceptance
- [ ] `BluetoothReader` reads all paired Bluetooth devices
- [ ] Device battery levels display for HID devices (keyboard, mouse, trackpad)
- [ ] Connection status (connected/paired/disconnected) for each device
- [ ] Device type icons (SF Symbols: keyboard, mouse, headphones, speaker)
- [ ] `stack` visualization shows multiple device batteries
- [ ] `mini` visualization shows single device (user-selectable)
- [ ] `state` visualization shows connected/disconnected dot
- [ ] Widget appears in widget configuration UI
- [ ] No Bluetooth permission dialog triggered on read
- [ ] Graceful handling when Bluetooth disabled
## Done summary
Implemented Bluetooth widget data source with BluetoothReader for IORegistry device discovery, BluetoothStatusItem for menu bar display, and integrated with WidgetDataManager. Supports stack, mini, and state visualizations showing connected devices and battery levels.
## Evidence
- Commits: cbad35a1a5f4c1e6e58caa9a0ed5acd85ee5ed58
- Tests: Manual verification - Xcode project needs new files added
- PRs: