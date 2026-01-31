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
| `Tonic/Tonic/Services/WidgetReader/` | Reader protocol implementations for data sources |
| `Tonic/Tonic/Utilities/` | Helper utilities |
| `TonicHelperTool/` | Privileged helper for root operations |

### Entry Points

- **App Entry**: `Tonic/Tonic/TonicApp.swift` - Main app with `@main` attribute
- **Navigation**: `Tonic/Tonic/Views/ContentView.swift` - NavigationSplitView container
- **Sidebar**: `Tonic/Tonic/Views/SidebarView.swift` - Navigation destinations

## Key Services (Singletons)

```swift
WidgetPreferences.shared        // Widget configuration
WidgetCoordinator.shared        // Menu bar widget lifecycle (OneView/Individual mode)
NotificationManager.shared      // Threshold-based notifications
PermissionManager.shared        // Permission checks
PrivilegedHelperManager.shared  // Root operations
CollectorBin.shared             // Deletion staging
WeatherService.shared           // Weather data
SparkleUpdater.shared           // App updates
```

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
Real-time metrics via IOKit:
- CPU usage (per-core available)
- Memory usage with pressure level
- Disk usage per volume
- Network bandwidth
- GPU (Apple Silicon unified memory)
- Battery status

### 4. Reader Architecture (`ReaderProtocol.swift`)
Stats Master-inspired reader pattern for modular data collection:
- `Reader<T>` protocol: Async data fetching with lifecycle management
- `BaseReader<T>`: Common implementation with history tracking
- Reader types: `CPUReader`, `MemoryReader`, `DiskReader`, `NetworkReader`, `GPUReader`, `BatteryReader`, `SensorsReader`
- Features: Configurable intervals, optional readers, popup-only mode, history limits
- Unified refresh via `WidgetRefreshScheduler` (single timer instead of per-widget timers)

### 5. Menu Bar Widgets (`WidgetCoordinator`)
Stats Master-parity widget system with flexible visualizations:
- **Data Sources**: CPU, Memory, Disk, Network, GPU, Battery, Weather, Sensors (8 types)
- **Visualization Types**: mini, lineChart, barChart, pieChart, tachometer, stack, speed, networkChart, batteryDetails, label, state, text
- **Display Modes**: Compact (icon+value), Detailed (adds sparkline for mini visualization)
- **OneView Mode**: Unified menu bar item showing all widgets in a horizontal grid (toggleable)
- **WidgetFactory**: Creates appropriate status items based on data source + visualization
- **Notification Thresholds**: Per-widget configurable alerts via `NotificationManager`

### 6. Weather (`WeatherService.swift`)
- Uses Open-Meteo API (free, no key required)
- CoreLocation for position
- Current conditions + 7-day forecast

### 7. Notification System (`NotificationManager.swift`)
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
- Prefer `DesignComponents` (Card, PrimaryButton) over raw views
- Apply animations from `DesignAnimations` for consistency

## Common Tasks

### Adding a New Widget
1. Create widget view in `MenuBarWidgets/` (subclass `WidgetStatusItem`)
2. Add `WidgetType` case in `Models/WidgetConfiguration.swift` with compatible visualizations
3. Create reader in `Services/WidgetReader/` (subclass `BaseReader<T>`)
4. Add data source to `WidgetDataManager` if new metrics needed
5. Update `WidgetFactory.createWidget()` to handle new type
6. Add icon and display name to `WidgetType`

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
