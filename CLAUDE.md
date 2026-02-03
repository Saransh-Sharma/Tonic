# Tonic - AI Assistant Context

> Beautiful native macOS system management application.

## Project Overview

**Tonic** is a native macOS utility application built with SwiftUI for system management and optimization. It provides disk cleanup, performance monitoring, app management, and menu bar widgets through a polished native interface.

- **Platform**: macOS 14.0 (Sonoma) or later
- **Language**: Swift
- **UI Framework**: SwiftUI
- **Architecture**: MVVM with Observable pattern (macOS 14+)

## Quick Reference

### Key Directories

| Directory | Purpose |
|-----------|---------|
| `Tonic/Tonic/` | Main app source code |
| `Tonic/Tonic/Views/` | SwiftUI views (Dashboard, Scan, Disk Analysis, etc.) |
| `Tonic/Tonic/Services/` | Business logic (SmartScanEngine, DeepCleanEngine, etc.) |
| `Tonic/Tonic/Models/` | Data types and enums |
| `Tonic/Tonic/Design/` | Design tokens, components, animations |
| `Tonic/Tonic/MenuBarWidgets/` | Menu bar widget implementations |
| `Tonic/Tonic/MenuBarWidgets/ChartStatusItems/` | Chart-based widget status items |
| `Tonic/Tonic/MenuBarWidgets/Popovers/` | Stats Master-style popover views |
| `Tonic/Tonic/MenuBarWidgets/Views/` | Chart view components |
| `Tonic/Tonic/Utilities/` | Helper utilities |
| `TonicHelperTool/` | Privileged helper for root operations |

### Entry Points

- **App Entry**: `Tonic/Tonic/TonicApp.swift` - Main app with `@main` attribute
- **Navigation**: `Tonic/Tonic/Views/ContentView.swift` - NavigationSplitView container
- **Sidebar**: `Tonic/Tonic/Views/SidebarView.swift` - Navigation destinations

## Key Services (Singletons)

```swift
WidgetPreferences.shared        // Widget configuration (enabled, position, color, mode)
WidgetCoordinator.shared        // Menu bar widget lifecycle (OneView/Individual mode)
WidgetDataManager.shared        // Central data source for all widget metrics (@Observable)
NotificationManager.shared      // Threshold-based notifications
PermissionManager.shared        // Permission checks
PrivilegedHelperManager.shared  // Root operations (including SMC write for fan control)
CollectorBin.shared             // Deletion staging
WeatherService.shared           // Weather data
SparkleUpdater.shared           // App updates
SMCReader.shared                // SMC sensor readings (temperature, fan, voltage) + fan write control
```

### Fan Control Architecture (`SMCReader.swift`, `PrivilegedHelperManager.swift`)
Tonic supports full fan control for advanced users:
- **Read Operations**: Get current fan speeds, mode (Automatic/Forced/Manual), minimum/maximum speeds via SMC
- **Write Operations**: Set fan mode, set specific RPM, set percentage speed (requires helper tool)
- **FanControlView**: UI with per-fan sliders, mode selection (Manual/Auto/System), min/max indicators
- **Privileged Operations**: Fan write commands go through `TonicHelperTool` for root-level SMC access

### Settings Architecture (`MenuBarWidgets/Settings/TabbedSettingsView.swift`)
Tabbed settings UI following Stats Master's 4-tab pattern:
- **Module Tab**: Per-module settings (update intervals, top process count, visualization options)
- **Widgets Tab**: Widget selector with drag-drop reorder, enable/disable toggles
- **Popup Tab**: Global popover settings (keyboard shortcut, chart history, scaling, colors)
- **Notifications Tab**: Threshold configuration, debounce settings, Do Not Disturb respect

## Key Models

- **WidgetConfiguration.swift**: `WidgetType`, `WidgetDisplayMode`, `WidgetValueFormat`, `WidgetAccentColor`, `WidgetConfiguration`
- **VisualizationType.swift**: `VisualizationType` (14 visualization types), `ChartConfiguration`, `ScalingMode`
- **WidgetStatusItem.swift**: Base class for menu bar status items (NSStatusItem wrapper)
- **WidgetFactory.swift**: Creates status items based on data source + visualization

## State Management Patterns

### 1. `@Observable` (macOS 14+)
Primary pattern for new code:
```swift
@Observable
final class SmartScanEngine: @unchecked Sendable {
    var isScanning: Bool = false
    var scanProgress: Double = 0.0
}
```

### 2. `@StateObject` / `ObservableObject`
Legacy pattern in some views:
```swift
@MainActor
class SmartScanManager: ObservableObject {
    @Published var isScanning = false
}
```

### 3. `@AppStorage`
User Defaults wrapper:
```swift
@AppStorage("launchAtLogin") private var launchAtLogin = false
```

## Design System

Located in `Tonic/Tonic/Design/`:

- **DesignTokens.swift**: Colors, spacing, typography, animations
- **DesignComponents.swift**: Reusable UI components (Card, PrimaryButton, StatusLevel)
- **DesignAnimations.swift**: View modifiers (shimmer, fadeIn, scaleIn, skeleton)

### Key Tokens
```swift
DesignTokens.Colors.accent      // Primary accent color
DesignTokens.Colors.surface     // Background for cards
DesignTokens.Spacing.md         // 16pt standard spacing
DesignTokens.CornerRadius.large // 12pt rounded corners
```

## Navigation Structure

```swift
enum NavigationDestination: String, CaseIterable {
    case dashboard          // DashboardView.swift
    case systemCleanup      // SmartScanView.swift
    case appManager         // AppInventoryView.swift
    case diskAnalysis       // DiskAnalysisView.swift
    case liveMonitoring     // SystemStatusDashboard.swift
    case menuBarWidgets     // WidgetsPanelView.swift
    case developerTools     // DeveloperToolsView.swift
    case settings           // PreferencesView.swift
}
```

## Core Features

### 1. Smart Scan (`SmartScanEngine.swift`)
Multi-stage system analysis:
- Stage 1: Preparing - Initialize scan
- Stage 2: Scanning Disk - Cache, logs, temp files
- Stage 3: Checking Apps - Unused apps, duplicates
- Stage 4: Analyzing System - Hidden space, performance issues

### 2. Deep Clean (`DeepCleanEngine.swift`)
10 cleanup categories:
- System Cache, User Cache, Log Files, Temp Files
- Browser Cache, Downloads, Trash
- Development Artifacts, Docker, Xcode

### 3. System Monitoring (`WidgetDataManager.swift`)
Centralized data manager for all menu bar widget metrics using inline methods:
- **CPU Data**: Total usage, per-core usage, E-core/P-core breakdown, frequency, temperature, thermal limit, load averages, scheduler/speed limits, uptime
- **Memory Data**: Used/total bytes, pressure level (with gauge support), compressed/swap bytes, free memory, swap usage, top processes
- **Disk Data**: Usage per volume, read/write rates, I/O statistics, SMART data, detailed disk stats, I/O timing
- **Network Data**: Upload/download bandwidth, WiFi info (RSSI, noise, SNR, band, channel width), DNS servers, IP addresses, interface names, public IP
- **GPU Data**: Usage (Apple Silicon unified memory), dynamic memory allocation, per-GPU metrics (temperature, utilization, render/tiler, fan, clock, memory)
- **Battery Data**: Level, charging state, time remaining, cycle count, health, temperature, power adapter info (current, voltage), capacity (current/max/designed), amperage, wattage
- **Sensors Data**: Temperature readings via SMC (SMCReader), fan speeds (with write control), voltage, power
- **Bluetooth Data**: Connected devices, multi-battery levels for devices like AirPods (case, left, right)
- **History Tracking**: Per-widget history (60-180 samples depending on widget type) for charts and sparklines

All data collection is inline within `WidgetDataManager` using `@Observable` pattern for automatic SwiftUI updates.

### 4. Menu Bar Widgets (`WidgetCoordinator`)
Stats Master-parity widget system with flexible visualizations:
- **Data Sources** (10 types): CPU, GPU, Memory, Disk, Network, Battery, Weather, Sensors, Bluetooth, Clock
- **Visualization Types** (14 types): mini, lineChart, barChart, pieChart, tachometer, stack, speed, networkChart, batteryDetails, label, state, text, memory, battery
- **Display Modes**: Compact (icon+value), Detailed (adds sparkline for mini visualization)
- **OneView Mode**: Unified menu bar item showing all widgets in a horizontal grid (toggleable)
- **WidgetFactory**: Creates appropriate status items based on data source + visualization
- **Chart Components**: `ChartStatusItems/` directory contains specialized status items for each visualization
- **Notification Thresholds**: Per-widget configurable alerts via `NotificationManager`
- **Color System**: 30+ color options including utilization-based auto-coloring (green->yellow->orange->red)
- **Per-Widget Popovers**: Stats Master-style detail views for each widget type

#### Popover Views (`MenuBarWidgets/Popovers/`)
Each widget type has a dedicated popover view with Stats Master parity:
- **CPUPopoverView.swift**: Total usage gauge, E-core/P-core charts, per-core bar chart, scheduler/speed limits, uptime, load averages, top processes
- **MemoryPopoverView.swift**: Pressure gauge (3-color arc with needle), usage charts, swap section, top processes
- **GPUPopoverView.swift**: Per-GPU containers, temp/utilization/render/tiler gauges, line charts, expandable details, fan/clock/memory info
- **DiskPopoverView.swift**: Per-disk containers, dual-line read/write charts, I/O stats, expandable details, top I/O processes
- **NetworkPopoverView.swift**: Bandwidth charts, connectivity grid, WiFi details (RSSI, noise, SNR, band, width), DNS servers, public IP, interface info
- **BatteryPopoverView.swift**: Battery visual, electrical metrics (amperage, voltage, power), adapter section, capacity breakdown, time formatting
- **SensorsPopoverView.swift**: Temperature readings, **FanControlView** with sliders and modes (Manual/Auto/System), per-fan speed control
- **BluetoothPopoverView.swift**: Connection status, history chart, device list with multi-battery support (case/left/right)

Visualization Type Details:
- **mini**: Icon + value, optional sparkline in detailed mode
- **lineChart**: Real-time history graph with 60-120 samples
- **barChart**: Per-core/per-zone bar display
- **pieChart**: Circular progress indicator
- **tachometer**: Gauge with needle
- **stack**: Multiple sensor readings stacked
- **speed**: Network up/down speed display
- **networkChart**: Dual-line upload/download chart
- **batteryDetails**: Extended battery info with health
- **label/state/text**: Simple text displays
- **memory**: Two-row used/total memory display
- **battery**: Battery icon with fill level

### 5. Weather (`WeatherService.swift`)
- Uses Open-Meteo API (free, no key required)
- CoreLocation for position
- Current conditions + 7-day forecast

### 6. Notification System (`NotificationManager.swift`)
Threshold-based alert system for menu bar widgets:
- **Per-widget thresholds**: CPU, Memory, Disk, GPU, Battery, Network, Sensors
- **Threshold types**: Greater than, less than, equal to conditions
- **Debouncing**: Configurable minimum interval between notifications (default 5 minutes)
- **Do Not Disturb**: Option to respect macOS Focus modes
- **Notification types**: Usage alerts, low battery warnings, temperature warnings
- **Permission management**: Built-in request and settings integration

## Permissions

Required permissions managed by `PermissionManager.swift`:
- **Full Disk Access**: Scan all files, uninstall apps
- **Accessibility**: System optimizations
- **Notifications**: Scan alerts, system warnings
- **Location**: Weather widget

## Build Commands

```bash
# Generate Xcode project (requires XcodeGen)
xcodegen generate

# Build debug
xcodebuild -scheme Tonic -configuration Debug build

# Build release
xcodebuild -scheme Tonic -configuration Release build

# Build helper tool
xcodebuild -scheme TonicHelperTool -configuration Release build
```

## Key File Locations

```
~/Library/Application Support/Tonic/  # App data
~/Library/Caches/com.tonic.Tonic/     # Cache
~/Library/Logs/com.tonic.Tonic/       # Logs
/Library/PrivilegedHelperTools/       # Helper binary
```

## Development Notes

### Threading
- Use `@MainActor` for UI-related classes
- Services marked with `@unchecked Sendable` for concurrent access
- Async/await for file operations and network calls

### Privileged Operations
- Install `TonicHelperTool` for root-level file operations
- Uses XPC for communication between app and helper
- SMJobSubmit for installation (requires admin auth)

### Styling Conventions
- Use `DesignTokens` instead of hardcoded values
- Use `PopoverConstants` for popover-specific spacing and typography
- Prefer `DesignComponents` (Card, PrimaryButton) over raw views
- Apply animations from `DesignAnimations` for consistency
- Use reusable popover components from `PopoverTemplate.swift` (ProcessRow, IconLabelRow, SectionHeader, etc.)

### Popover Design System (Stats Master Parity)
Located in `Tonic/Tonic/MenuBarWidgets/Popovers/`:

#### PopoverConstants.swift
Standardized spacing, typography, and sizes for all widget popovers:
- **Dimensions**: Width 280px, maxHeight 600px (matches Stats Master)
- **Typography**: 9pt (small), 11pt (default), 13pt (header) - using `DesignTokens`
- **Spacing**: Uses 8-point grid (4, 8, 12, 16, 24pt values)
- **Corner Radius**: 6pt for inner cards, 10pt for popover
- **Icons**: SF Symbols with consistent sizing
- **Colors**: Helper functions for percentage (green/yellow/orange/red), temperature, battery
- **Animations**: fast (0.15s), normal (0.25s), slow (0.35s)

#### PopoverTemplate.swift
Reusable components for consistent popover UI:
- `PopoverTemplate`: Standard template with header, content, action button
- `PopoverSection` / `TitledPopoverSection`: Section containers with consistent padding
- `PopoverDetailRow` / `PopoverDetailGrid`: Key-value displays for metrics
- `ProcessRow`: Standardized process list row (PID, name, CPU%, memory, kill button)
- `IconLabelRow`: Icon + label + value row with alignment
- `SectionHeader`: Section title with optional icon
- `EmptyStateView`: Empty state placeholder with icon and message
- `MetricCard`: Metric display with label and value
- `CircularProgress`, `UsageBar`, `MetricDisplay`: Visual components

#### Gauge Components
Located in `Tonic/Tonic/Views/`:
- `PressureGaugeView.swift`: 3-color arc gauge with needle for memory pressure (green 0-50%, yellow 50-80%, red 80-100%)
- `TachometerView.swift`: Half-circle gauge with needle for CPU/GPU utilization

## Common Tasks

### Adding a New Widget
1. Add `WidgetType` case in `Models/WidgetConfiguration.swift` with compatible visualizations
2. Add data collection methods to `WidgetDataManager` for new metrics
3. Create chart status item in `MenuBarWidgets/ChartStatusItems/` if new visualization type needed
4. Update `WidgetFactory.createWidget()` to handle new type
5. Add icon and display name to `WidgetType`
6. Update `VisualizationType` enum if adding new visualization

Note: Data collection is centralized in `WidgetDataManager` using inline methods (no separate reader files).

### Configuring Notification Thresholds
1. Access via `NotificationManager.shared`
2. Use `updateThreshold()` to add/update a threshold for a widget type
3. Set threshold value, condition (greater/less than), and enabled state
4. Configure minimum interval and Do Not Disturb respect via `NotificationConfig`

### Enabling OneView Mode
1. Set `WidgetPreferences.shared.unifiedMenuBarMode = true`
2. Widgets will display in single horizontal menu bar item
3. Clicking shows unified popover with all widget details
4. Toggle via Widgets Panel in app preferences

### Adding a New Cleanup Category
1. Add case to `DeepCleanCategory` in `DeepCleanEngine.swift`
2. Implement `scanCategory()` and `cleanCategory()` methods
3. Add icon and description to category enum

### Adding Navigation Destination
1. Add case to `NavigationDestination` enum
2. Create view file in `Views/`
3. Add to ContentView switch statement
4. Add sidebar icon (SF Symbol)

## Testing Notes

- No test suite currently exists
- Manual testing via Xcode
- Test permissions on clean macOS install
- Test helper tool installation/uninstallation

## Known Limitations

- Some features require Full Disk Access
- Helper tool requires admin authentication
- Weather requires location permission
- Menu bar widgets persist after window close (by design)
