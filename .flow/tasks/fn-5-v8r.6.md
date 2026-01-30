# fn-5-v8r.6 Battery, GPU and sensors readers with Stats Master parity

## Description
Implement BatteryReader, GPUReader, and SensorsReader conforming to WidgetReader protocol. Battery needs extended details, GPU is Apple Silicon only, sensors support temperature/fans.

## Implementation

Create `Tonic/Tonic/Services/WidgetReader/BatteryReader.swift`:
- IOPowerSources API
- Percentage, time remaining, charging state
- Health, cycle count (for details widget)

Create `Tonic/Tonic/Services/WidgetReader/GPUReader.swift`:
- IOAccelerator for Apple Silicon GPU
- Usage, memory pressure
- `#if arch(arm64)` only

Create `Tonic/Tonic/Services/WidgetReader/SensorsReader.swift`:
- SMC communication for temperature
- Fan speeds via IOKit

## Acceptance
- [x] BatteryReader returns status + health info
- [x] GPUReader works on Apple Silicon
- [x] SensorsReader returns temp/fan data
- [x] All async with proper error handling

## Done summary
Implemented BatteryReader, GPUReader, and SensorsReader with Stats Master feature parity.

## Evidence
- Commits:
- Tests:
- PRs:

## References
- Stats Master: `stats-master/Kit/Widgets/Battery.swift`, `SMC/smc.swift`
- Tonic current: `Tonic/Tonic/Services/WidgetDataManager.swift:807-1007`
