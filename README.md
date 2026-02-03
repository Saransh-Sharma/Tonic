<div align="center">
  <p>
    <img src="Tonic/docs/assets/app-icon.png" alt="Tonic App Icon" width="128" height="128" />
  </p>
  <h1>Tonic</h1>
  <p><em>Beautiful native macOS system management.</em></p>
</div>

<p align="center">
  <img src="https://maas-log-prod.cn-wlcb.ufileos.com/anthropic/2c288d48-308c-407b-96a1-751ec2eddc29/Screenshot%202026-01-28%20at%204.02.01%20PM.png?UCloudPublicKey=TOKEN_e15ba47a-d098-4fbd-9afc-a0dcf0e4e621&Expires=1769598162&Signature=0xb9W3p5QHjVKJ17emyzuE+rAPY=" alt="Tonic App Manager - Login Items" width="1000" />
</p>

## Overview

Tonic is a beautiful, native macOS application for system management and optimization. It combines disk cleanup, performance monitoring, and app management into a single, polished interface built entirely with SwiftUI.

Tonic provides a true native Mac experience with:
- **Real-time system monitoring** with live menu bar widgets
- **One-click smart scanning** that identifies junk and reclaimable space
- **Deep cleaning** across 10 categories of system clutter
- **Disk analysis** with interactive treemap visualization
- **App inventory** with uninstall and update capabilities

## Features

### Dashboard
The main dashboard provides an at-a-glance view of your Mac's health with:
- System health score (0-100) with color-coded rating
- Quick action buttons for common tasks
- Real-time storage, memory, and CPU statistics
- Actionable recommendations for improvement
- Recent activity timeline

### Smart Scan
Four-stage scanning engine that analyzes your system:
1. **Preparing** - Initialize scan and load preferences
2. **Scanning Disk** - Enumerate caches, logs, and temporary files
3. **Checking Apps** - Identify unused applications and duplicates
4. **Analyzing System** - Detect hidden space and optimization opportunities

Results include a health score and categorized recommendations with estimated space to reclaim.

### Deep Clean
Ten cleanup categories:
- System Cache (`/Library/Caches`, `/System/Library/Caches`)
- User Cache (`~/Library/Caches`)
- Log Files (system and application logs)
- Temporary Files (`/tmp`, temp directories)
- Browser Cache (Safari, Chrome, Firefox, Edge)
- Downloads (files older than 30 days)
- Trash (items in ~/.Trash)
- Development Artifacts (npm, yarn, cargo, gradle, maven, Xcode)
- Docker (container data and images)
- Xcode (DerivedData, Archives, DeviceSupport)

### Disk Analysis
- **Directory Browser** - Navigate any folder with back/up controls
- **Large Files View** - Quickly identify space hogs (100MB+)
- **Treemap Visualization** - Visual representation of disk usage by file type
- **Permission Handling** - Guided Full Disk Access setup

### System Monitoring
Real-time metrics for:
- **CPU** - Total usage, per-core activity, active processes
- **Memory** - Used/available, pressure level, swap usage
- **Disk** - Per-volume usage with progress visualization
- **Network** - Upload/download bandwidth, connection type, SSID
- **Battery** - Charge percentage, health, time remaining (portable Macs)

### Menu Bar Widgets
Ten customizable widgets that live in your menu bar with Stats Master-style popovers:
- **CPU Widget** - Usage percentage with optional sparkline, per-core breakdown, scheduler/speed limits, uptime
- **Memory Widget** - Usage with pressure indicator (pressure gauge), swap usage, top processes
- **Disk Widget** - Primary volume usage, I/O statistics, per-disk charts
- **Network Widget** - Bandwidth and connection status, WiFi details (RSSI, noise, SNR), DNS servers
- **GPU Widget** - Apple Silicon unified memory, per-GPU metrics (M-series only), temperature, render/tiler stats
- **Battery Widget** - Charge level, health, electrical metrics (amperage, voltage, wattage), adapter info
- **Weather Widget** - Current conditions and 7-day forecast
- **Sensors Widget** - Temperature readings, **fan control with sliders** (Manual/Auto/System modes)
- **Bluetooth Widget** - Connection status, device list with multi-battery support (case, left, right)
- **Clock Widget** - Multiple timezones with customizable formats

Each widget supports three display modes:
- Icon only (minimal)
- Icon + value
- Icon + value + sparkline

**Advanced Features**:
- **Fan Control**: Adjust fan speeds manually or set modes (Automatic/Forced/System)
- **Pressure Gauge**: Visual memory pressure indicator (3-color arc with needle)
- **Per-GPU Monitoring**: Separate stats for each GPU in multi-GPU systems
- **Multi-Battery Display**: See individual battery levels for AirPods case, left, and right
- **WiFi Details**: Signal strength (RSSI), noise, SNR, band, channel width
- **Electrical Metrics**: Amperage, voltage, and wattage for battery analysis
- **Chart History**: Configurable history depth (60-180 samples) for all charts
- **Tabbed Settings**: Module, Widgets, Popup, and Notifications settings tabs

### App Management
- **App Inventory** - Categorized view of all apps and extensions
- **Login Items** - View and manage launch agents, daemons, and startup items
- **Smart Filtering** - By category, size, last used, install date
- **Batch Operations** - Select multiple apps for actions
- **Complete Uninstall** - Removes app bundle + all associated files
- **Update Checking** - Sparkle-based update detection

### Notification Rules
Create custom alerts based on:
- CPU usage (above threshold)
- Memory pressure (warning/critical)
- Disk space (low free percentage)
- Network connectivity (disconnected)
- Weather conditions (temperature extremes)

## Quick Start

### Download
Download the latest release from [GitHub Releases](https://github.com/tw93/Tonic/releases) and move Tonic.app to `/Applications`.

### First Launch
1. Open Tonic from Applications or Spotlight
2. Complete the onboarding wizard (4 pages)
3. Grant **Full Disk Access** in System Settings → Privacy
4. Optionally install the **Privileged Helper** for system-level operations
5. Start with a Smart Scan from the dashboard

### Requirements
- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel Mac
- Full Disk Access recommended for full functionality

## Architecture

```
Tonic/
├── TonicApp.swift           # App entry point
├── Views/                   # SwiftUI views
│   ├── ContentView.swift    # Navigation split view
│   ├── DashboardView.swift  # Main dashboard
│   ├── SmartScanView.swift  # Scanning UI
│   ├── DiskAnalysisView.swr # Disk browser
│   ├── SystemStatusDashboard.swift  # Real-time monitoring
│   └── PreferencesView.swift # Settings
├── Services/                # Business logic
│   ├── SmartScanEngine.swift
│   ├── DeepCleanEngine.swift
│   ├── WidgetDataManager.swift
│   ├── WeatherService.swift
│   └── NotificationRuleEngine.swift
├── Models/                  # Data types
├── Design/                  # Design system
│   ├── DesignTokens.swift   # Colors, spacing, typography
│   ├── DesignComponents.swift
│   └── DesignAnimations.swift
├── MenuBar/                 # Menu bar integration
├── MenuBarWidgets/          # Widget implementations
└── Utilities/               # Helpers
    ├── DiskScanner.swift
    └── SparkleUpdater.swift
```

## Building from Source

### Prerequisites
- Xcode 15.0 or later
- XcodeGen (`brew install xcodegen`)

### Build

```bash
# Clone the repository
git clone https://github.com/tw93/Tonic.git
cd Tonic

# Generate Xcode project
xcodegen generate

# Build debug version
xcodebuild -scheme Tonic -configuration Debug build

# Build release version
xcodebuild -scheme Tonic -configuration Release build
```

### Run
```bash
# Open the app
open Tonic.xcodeproj
# Then press Cmd+R in Xcode
```

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details on:
- Code style and conventions
- Submitting pull requests
- Reporting issues

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

Built with:
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - Native UI framework
- [Sparkle](https://sparkle-project.org/) - Software update framework
- [IOKit](https://developer.apple.com/documentation/iokit) - Hardware access
- [CoreLocation](https://developer.apple.com/documentation/corelocation) - Weather location
