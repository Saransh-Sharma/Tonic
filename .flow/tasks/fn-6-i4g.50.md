# fn-6-i4g.50 Add Temperature Unit Toggle

## Description

Add global temperature unit toggle (°C/°F) to General settings. Applies to all temperature displays: CPU, GPU, Sensors, Battery.

**REFERENCE**: Read `stats-master/Kit/plugins/Store.swift` - settings storage pattern

## Files to Modify

1. **Tonic/Tonic/Models/WidgetConfiguration.swift** - add temperatureUnit preference
2. **Tonic/Tonic/Views/Refactored/GeneralPreferencesSection.swift** - add toggle UI
3. **All views displaying temperature** - use unit conversion helper

## Implementation

### Step 1: Add Temperature Preference

```swift
// File: Tonic/Tonic/Models/WidgetConfiguration.swift

public enum TemperatureUnit: String, Sendable, CaseIterable {
    case celsius = "C"
    case fahrenheit = "F"

    public var symbol: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }
}

@Observable
public class WidgetPreferences {
    // ... existing properties

    @AppStorage("temperatureUnit") public var temperatureUnit: TemperatureUnit = .celsius
}
```

### Step 2: Add Conversion Helper

```swift
// File: Tonic/Tonic/Utilities/TemperatureConverter.swift (NEW)

import Foundation

public struct TemperatureConverter {
    public static func celsiusToFahrenheit(_ celsius: Double) -> Double {
        return (celsius * 9/5) + 32
    }

    public static func fahrenheitToCelsius(_ fahrenheit: Double) -> Double {
        return (fahrenheit - 32) * 5/9
    }

    public static func display(_ celsius: Double, unit: TemperatureUnit) -> Double {
        switch unit {
        case .celsius:
            return celsius
        case .fahrenheit:
            return celsiusToFahrenheit(celsius)
        }
    }

    public static func displayString(_ celsius: Double, unit: TemperatureUnit) -> String {
        let value = display(celsius, unit: unit)
        return "\(Int(value))\(unit.symbol)"
    }
}
```

### Step 3: Add UI Toggle

```swift
// File: Tonic/Tonic/Views/Refactored/GeneralPreferencesSection.swift

struct GeneralPreferencesSection: View {
    @AppStorage("temperatureUnit") private var temperatureUnit: TemperatureUnit = .celsius

    var body: some View {
        Section("General") {
            // ... existing toggles

            Picker("Temperature Unit", selection: $temperatureUnit) {
                Text("Celsius (°C)").tag(TemperatureUnit.celsius)
                Text("Fahrenheit (°F)").tag(TemperatureUnit.fahrenheit)
            }
            .pickerStyle(.segmented)
            .help("Temperature display unit for all widgets")
        }
    }
}
```

### Step 4: Update Temperature Displays

```swift
// In all views that show temperature (CPU popover, Sensors popover, etc.)

// BEFORE:
Text("\(Int(dataManager.cpuData.temperature ?? 0))°C")

// AFTER:
Text(TemperatureConverter.displayString(
    dataManager.cpuData.temperature ?? 0,
    unit: WidgetPreferences.shared.temperatureUnit
))

// For gauge components that need raw value in correct unit:
HalfCircleGaugeView(
    value: TemperatureConverter.display(
        dataManager.cpuData.temperature ?? 0,
        unit: WidgetPreferences.shared.temperatureUnit
    ),
    maxValue: WidgetPreferences.shared.temperatureUnit == .fahrenheit ? 212 : 100,  // 212°F = 100°C
    label: "Temp",
    unit: WidgetPreferences.shared.temperatureUnit.symbol,
    color: temperatureColor(...)
)
```

## Affected Views

| View | File | Temperature Display |
|------|------|---------------------|
| CPU Popover | CPUPopoverView.swift | Temp gauge, frequency section |
| GPU Popover | GPUPopoverView.swift | Temperature |
| Sensors Popover | SensorsPopoverView.swift | All sensor readings |
| Battery Popover | BatteryPopoverView.swift | Temperature |
| Dashboard Widgets | Various | Mini displays |

## Acceptance

- [ ] Toggle appears in General Preferences section
- [ ] Toggle is segmented picker (Celsius | Fahrenheit)
- [ ] Setting persists across app restarts (@AppStorage)
- [ ] All CPU temperature displays update immediately
- [ ] All Sensors temperature displays update immediately
- [ ] Half-circle gauges show correct max value (100°C vs 212°F)
- [ ] Temperature color coding still works (green/yellow/orange/red based on unit)
- [ ] Unit symbol (°C/°F) displays correctly

## Done Summary

Added global temperature unit toggle to General settings. Toggle persists via @AppStorage and applies to all temperature displays across CPU, GPU, Sensors, and Battery widgets. TemperatureConverter helper provides conversion and display formatting.

## Evidence

- Commits:
- Tests:
- PRs:

## Reference Implementation

**Stats Master**: `stats-master/Stats/Views/Settings.swift`
- Temperature unit toggle implementation (General section)
