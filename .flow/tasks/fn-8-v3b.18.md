# fn-8-v3b.18 Add multi-battery support to BluetoothPopoverView

## Description
Update `BluetoothPopoverView.swift` to support multiple battery levels per device (case, left, right) for AirPods-style devices.

**Size:** S

**Files:**
- `Tonic/Tonic/MenuBarWidgets/Popovers/BluetoothPopoverView.swift`
- `Tonic/Tonic/Services/WidgetDataManager.swift` (update Bluetooth device model)

## Approach

1. Update `BluetoothDevice` model to support multiple batteries:
   ```swift
   public struct BluetoothDevice {
       public let name: String
       public let batteryLevels: [BatteryLevel]  // Multiple per device
       public let isConnected: Bool
   }

   public struct BatteryLevel {
       public let component: String  // "Case", "Left", "Right"
       public let percentage: Int
   }
   ```

2. Update `BluetoothPopoverView` to:
   - Show all battery levels for each device
   - Display component labels (Case, Left, Right)
   - Use mini battery icons or gauges for each component

3. Layout for AirPods:
   - Device name
   - Row of 3 battery indicators: [Case] [Left] [Right]

## Key Context

Current implementation shows single battery per device.

Bluetooth battery data comes from `IOBluetooth` framework or `CoreBluetooth`.
- `IOBluetoothDevice` has `batteryLevel` property (single value)
- For multiple batteries, need to query battery service of each device

Fallback: If only single battery available, show single value.

Stats Master supports this for AirPods Pro/Max with case and individual earbud battery levels.
## Acceptance
- [ ] BluetoothDevice model has batteryLevels array
- [ ] BatteryLevel struct has component and percentage
- [ ] BluetoothPopoverView shows all battery levels
- [ ] Component labels display (Case, Left, Right)
- [ ] Multiple batteries display in horizontal row
- [ ] Single battery devices display correctly (backward compatible)
- [ ] Missing battery data shows "—" or appropriate indicator
## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
