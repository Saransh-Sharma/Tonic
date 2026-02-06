# Tonic Architecture

High-level architecture documentation for the Tonic macOS system management application.

## System Overview

Tonic is a native macOS application built with SwiftUI that provides system monitoring, disk cleanup, and menu bar widgets. The application follows an MVVM architecture pattern with the `@Observable` pattern (Swift 6.0).

```
┌─────────────────────────────────────────────────────────────┐
│                         Tonic App                           │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Views     │  │   Models    │  │     Services        │ │
│  │  (SwiftUI)  │◄─┤  (Data)     │◄─┤  (Business Logic)   │ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────────────┘ │
│         │                │                │                 │
│         └────────────────┴────────────────┘                 │
│                          │                                  │
│                   ┌──────▼──────┐                           │
│                   │ Design      │                           │
│                   │ System      │                           │
│                   └─────────────┘                           │
└─────────────────────────────────────────────────────────────┘
         │                                    │
         ▼                                    ▼
┌─────────────────┐                ┌─────────────────────┐
│ Menu Bar        │                │ TonicHelperTool     │
│ Widgets         │◄───────────────│ (Privileged Helper) │
│ (NSStatusItem)  │   XPC Channel  │ (Root Operations)   │
└─────────────────┘                └─────────────────────┘
```

## Core Components

### 1. App Entry & Navigation

**TonicApp.swift** (`@main`)
- App lifecycle management
- Initial service setup
- Permission requests

**ContentView.swift**
- NavigationSplitView container
- Sidebar navigation
- Detail view routing

**SidebarView.swift**
- Navigation destinations enum
- Sidebar item selection

### 2. View Layer (Views/)

#### Main Views
| View | Purpose |
|------|---------|
| `DashboardView` | Main dashboard with system overview |
| `SmartScanView` | System scanning interface |
| `AppInventoryView` | Application management |
| `DiskAnalysisView` | Disk usage analysis |
| `SystemStatusDashboard` | Live system monitoring |
| `WidgetsPanelView` | Menu bar widget configuration |
| `PreferencesView` | App settings |

#### Widget Popovers (MenuBarWidgets/Popovers/)
Each widget type has a dedicated popover view:
- `CPUPopoverView` - CPU metrics, per-core breakdown, top processes
- `MemoryPopoverView` - Memory pressure gauge, swap info, top processes
- `GPUPopoverView` - Per-GPU metrics, temperature, utilization
- `DiskPopoverView` - Per-disk I/O, storage usage, top I/O processes
- `NetworkPopoverView` - Bandwidth charts, WiFi details, connectivity
- `BatteryPopoverView` - Battery health, electrical metrics, capacity
- `SensorsPopoverView` - Temperature readings, fan control UI
- `BluetoothPopoverView` - Connected devices, multi-battery support

### 3. Service Layer (Services/)

All services are singletons using `@Observable` pattern.

#### Core Services

| Service | Responsibility |
|---------|----------------|
| `WidgetDataManager` | Central data source for all widget metrics |
| `WidgetCoordinator` | Menu bar widget lifecycle management |
| `WidgetPreferences` | Widget configuration persistence |
| `NotificationManager` | Threshold-based notifications |
| `PermissionManager` | Permission checks and requests |
| `PrivilegedHelperManager` | XPC communication with helper tool |
| `WeatherService` | Weather data via Open-Meteo API |
| `SparkleUpdater` | App update management |
| `SMCReader` | SMC sensor readings (temp, fan, voltage) |
| `CollectorBin` | Deletion staging area |

#### Engine Services

| Engine | Purpose |
|--------|---------|
| `SmartScanEngine` | Multi-stage system analysis |
| `DeepCleanEngine` | 10-category cleanup system |

### 4. Data Layer (Models/)

| Model | Purpose |
|-------|---------|
| `WidgetConfiguration` | Widget type, display mode, color, format |
| `VisualizationType` | 14 visualization types and chart config |
| `WidgetStatusItem` | NSStatusItem wrapper base class |
| `NavigationDestination` | App navigation enum |

### 5. Design System (Design/)

| Component | Purpose |
|-----------|---------|
| `DesignTokens` | Colors, spacing, typography, animation constants |
| `DesignComponents` | Reusable UI components (Card, Button, etc.) |
| `DesignAnimations` | View modifiers (shimmer, fade, scale, skeleton) |
| `PopoverConstants` | Popover-specific spacing and typography |
| `PopoverTemplate` | Reusable popover components |

## Data Flow Patterns

### Widget Data Flow

```
┌─────────────────────┐
│ WidgetDataManager   │
│  (@Observable)      │
└──────────┬──────────┘
           │
           │ 1. Collect metrics (inline methods)
           │ 2. Update history (60-180 samples)
           │ 3. Notify observers
           │
           ▼
┌─────────────────────┐
│  WidgetStatusItem   │
│  (NSStatusItem)     │
└──────────┬──────────┘
           │
           │ 1. Read current value
           │ 2. Update button title
           │ 3. Redraw charts
           │
           ▼
┌─────────────────────┐
│  Menu Bar Display   │
└─────────────────────┘
```

### Fan Control Data Flow

```
┌─────────────────┐          ┌──────────────────────┐
│  FanControlView │─────────►│ PrivilegedHelperMgr  │
│   (UI)          │ XPC      │   (XPC Client)       │
└─────────────────┘          └──────────┬───────────┘
                                         │
                                         │ 1. Send command
                                         │ 2. Authenticate
                                         │
                                         ▼
                              ┌──────────────────────┐
                              │  TonicHelperTool     │
                              │  (Root SMC Access)   │
                              └──────────────────────┘
```

### Scan Engine Data Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  SmartScanView  │────►│ SmartScanEngine │────►│  Scan Results   │
│   (UI)          │     │  (Orchestrator) │     │   (Models)      │
└─────────────────┘     └────────┬────────┘     └─────────────────┘
                                 │
                                 │ 1. Scan directories
                                 │ 2. Calculate sizes
                                 │ 3. Categorize files
                                 │
                        ┌────────▼────────┐
                        │ DeepCleanEngine │
                        │  (Cleaner)      │
                        └─────────────────┘
```

## State Management

### @Observable Pattern (Swift 6.0+)

Primary pattern for new code:

```swift
@Observable
final class MyService: @unchecked Sendable {
    var state: State = .idle

    func updateState() {
        state = .loading
        // Automatic UI updates
    }
}
```

### @StateObject / ObservableObject

Legacy pattern in some views:

```swift
@MainActor
class MyViewModel: ObservableObject {
    @Published var value: String = ""
}
```

### @AppStorage

User Defaults wrapper for simple values:

```swift
@AppStorage("launchAtLogin") private var launchAtLogin = false
```

## Threading Model

| Context | Usage |
|---------|-------|
| `@MainActor` | UI-related classes, view models |
| `@unchecked Sendable` | Services with concurrent access |
| `async/await` | File operations, network calls |

## Key Architectural Decisions

### 1. Inline Data Collection in WidgetDataManager

**Decision**: All metric collection is implemented as inline methods rather than separate reader classes.

**Rationale**:
- Simpler call sites
- Easier to add new metrics
- Direct access to shared state
- Better performance (no inter-class overhead)

### 2. NSStatusItem per Widget vs Unified View

**Decision**: Support both individual mode (one NSStatusItem per widget) and OneView mode (single unified item).

**Rationale**:
- User preference for menu bar space
- Stats Master parity
- Flexibility for different use cases

### 3. Privileged Helper for Fan Control

**Decision**: Fan write operations require TonicHelperTool for root-level SMC access.

**Rationale**:
- macOS security model requires root for SMC writes
- Safe isolation of privileged operations
- XPC for secure communication

### 4. Custom Popover Components

**Decision**: Create reusable PopoverTemplate components instead of raw SwiftUI.

**Rationale**:
- Consistency across widget popovers
- DRY principle
- Easier maintenance
- Stats Master visual parity

## Security Considerations

### Privileged Helper
- XPC communication with helper tool
- SMJobSubmit for installation
- Admin authentication required

### Permissions
| Permission | Purpose | Required For |
|------------|---------|--------------|
| Full Disk Access | File system scanning | Smart Scan, Deep Clean |
| Accessibility | System optimizations | Performance features |
| Notifications | Alerts and warnings | Threshold notifications |
| Location | Weather data | Weather widget |

### PII Handling
- Log scrubbing for file paths, emails, IPs
- User consent for crash reports
- Local-only data processing (no cloud sync)

## Extension Points

### Adding a New Widget
1. Add `WidgetType` case to enum
2. Add data collection methods to `WidgetDataManager`
3. Create chart status item (if new visualization)
4. Update `WidgetFactory.createWidget()`
5. Create popover view in `Popovers/`

### Adding a New Cleanup Category
1. Add case to `DeepCleanCategory` enum
2. Implement `scanCategory()` and `cleanCategory()` in `DeepCleanEngine`
3. Add icon and description

### Adding a Navigation Destination
1. Add case to `NavigationDestination` enum
2. Create view file in `Views/`
3. Update `ContentView` switch statement
4. Add sidebar icon (SF Symbol)

## Performance Considerations

### Widget Update Frequency
- CPU: 1 second default
- Memory: 2 second default
- Network: 1 second default
- Disk: 5 second default
- Battery: 30 second default
- Weather: 10 minute minimum

### History Buffer Sizes
- CPU: 120 samples (2 minutes at 1s interval)
- Memory: 60 samples
- Network: 120 samples
- Disk: 60 samples
- Battery: 60 samples

### Memory Management
- `@Observable` automatic KVO
- Weak delegate references
- Cleanup in deinit
- Image caching with limits

## Dependencies

### External Frameworks
- **SwiftUI** - UI framework
- **XcodeGen** - Project generation (dev tool only)
- **Sparkle** - App updates (embedded)

### System Frameworks
- Foundation
- SwiftUI
- AppKit
- IOKit (SMC access)
- CoreLocation (weather)
- os.log (logging)

## Known Limitations

- No CI/CD automation
- Manual testing only (no automated tests currently)
- Helper tool requires admin auth
- Some features require Full Disk Access
- Menu bar widgets persist after window close (by design)
