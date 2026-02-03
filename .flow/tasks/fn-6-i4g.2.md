# fn-6-i4g.2 Enhanced Data Models

## Description
Extend Tonic's existing data models to support Stats Master's enhanced features.

**Size:** M

**Files:**
- `Tonic/Tonic/Models/SystemEnums.swift` (modify)
- `Tonic/Tonic/Models/VisualizationType.swift` (modify)
- `Tonic/Tonic/Models/ProcessUsage.swift` (new)
- `Tonic/Tonic/Models/NetworkDetails.swift` (new)
- `Tonic/Tonic/Models/SensorsFullData.swift` (new)
- `Tonic/Tonic/Models/DiskSMARTData.swift` (new)

Add new data models:

1. **ProcessUsage** - Per-process resource usage
```swift
struct ProcessUsage: Identifiable, Sendable {
    let id: Int32  // PID
    let name: String
    let icon: NSImage?
    let cpuUsage: Double?
    let memoryUsage: UInt64?
    let diskReadBytes: UInt64?
    let diskWriteBytes: UInt64?
    let networkBytes: UInt64?
}
```

2. **WiFiDetails** - Extended network information
```swift
struct WiFiDetails: Sendable {
    let ssid: String
    let rssi: Int  // Signal strength
    let channel: Int
    let security: String
    let bssid: String
}
```

3. **PublicIPInfo** - Public IP tracking
```swift
struct PublicIPInfo: Sendable, Equatable {
    let ipAddress: String
    let country: String?
    let timestamp: Date
}
```

4. **SensorsFullData** - Comprehensive sensor readings
```swift
struct SensorsFullData: Sendable {
    let temperatures: [SensorReading]
    let fans: [FanReading]
    let voltages: [SensorReading]
    let power: [SensorReading]
}

struct SensorReading: Identifiable, Sendable {
    let id: String
    let name: String
    let value: Double
    let unit: String
    let min: Double?
    let max: Double?
}
```

5. **NVMeSMARTData** - Disk health information
```swift
struct NVMeSMARTData: Sendable {
    let temperature: Double
    let percentageUsed: Double?
    let criticalWarning: Bool
    let powerCycles: UInt64
    let powerOnHours: UInt64
}
```

## Approach

1. Add new model files to `Models/` directory
2. Extend existing enums where applicable (e.g., `ConnectionType` in `SystemEnums.swift`)
3. Ensure all new models conform to `Sendable`
4. Add `Codable` conformance for persistence (except `NSImage` in ProcessUsage)
5. Follow existing patterns from `WidgetDataManager.swift:297-340`

## Key Context

Stats Master stores these values differently. We're adapting to Tonic's structured approach. Reference Stats Master's module configs in `stats-master/Modules/*/readers.swift` for the values we need to capture.
## Acceptance
- [ ] ProcessUsage struct defined with all properties
- [ ] WiFiDetails struct defined
- [ ] PublicIPInfo struct defined
- [ ] SensorsFullData struct with nested types
- [ ] NVMeSMARTData struct defined
- [ ] All new models conform to Sendable
- [ ] Relevant models conform to Codable
- [ ] No breaking changes to existing models
## Done summary
Added enhanced data models for Stats Master parity: ProcessUsage for per-process resource tracking, WiFiDetails/PublicIPInfo for extended network info, NVMeSMARTData for disk health, extended SensorsData with power readings and min/max values, and new system enums (PowerSource, ThermalState, ProcessSortOption).
## Evidence
- Commits: 560f5fa95608670e4f3ec2ca2ff8cce6ff3fa093
- Tests: xcodebuild -project /Users/saransh1337/Developer/Projects/TONIC/Tonic/Tonic.xcodeproj -scheme Tonic -configuration Debug -destination 'platform=macOS' build
- PRs: