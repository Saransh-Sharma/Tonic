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
Smart Scan is a three-pillar analysis flow that runs through:
1. **Space** - Cleanup and clutter analysis (cache/temp/log/trash targets, hidden space, old downloads, dev and Xcode leftovers)
2. **Performance** - Login/background maintenance checks and optimization candidates
3. **Apps** - App lifecycle issues (unused apps, large installations, duplicates, orphaned support files)

During scan, Tonic shows live counters for:
- Reclaimable space found
- Performance items flagged
- Apps reviewed

After scan, results are grouped into actionable sections with:
- Per-item safety status (`safe to run`)
- Smart-selected recommendations (preselected quick wins)
- Review-first and one-click Smart Clean execution paths

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

### Apps Scanner
Tonic includes two complementary app-scanning workflows:

- **App Manager Scanner (inventory-first)**
  - Fast discovery of installed app-related items, then optional size enrichment
  - Coverage across apps, extensions, preference panes, quick look plugins, spotlight importers, frameworks, system utilities, and login items
  - Search, category filters, sort controls, update checks, and uninstall flows from one workspace
- **Smart Scan Apps Pillar (issue-first)**
  - Focuses on cleanup/optimization candidates: unused, oversized, duplicate, and orphaned app data
  - Integrates directly into Smart Clean recommendation flow

### Storage Scan
Storage scanning is powered by the **Storage Intelligence Hub** (Disk Analysis) plus cloud provider scanning:

- **Scan modes**: Quick, Full, and Targeted scope
- **Guided permissions**: Full Disk Access checks and setup helpers
- **Explore surfaces**: path navigation, orbit map, and treemap terrain views
- **Action workflows**: Guided Assistant or Cart + Review cleanup modes
- **Insights**: reclaim packs, anomaly detection, trend/history, and forecast narratives
- **Safety model**: risk levels, blocked/protected paths, dry-run style review before execution

Cloud storage scan support includes provider detection and cache sizing for:
- iCloud
- Dropbox
- Google Drive
- OneDrive

### System Monitoring
Real-time metrics for:
- **CPU** - Total usage, per-core activity, active processes
- **Memory** - Used/available, pressure level, swap usage
- **Disk** - Per-volume usage with progress visualization
- **Network** - Upload/download bandwidth, connection type, SSID
- **Battery** - Charge percentage, health, time remaining (portable Macs)

### Menu Bar Widgets
Menu widgets support both **individual status items** and **OneView unified mode**:

- **Core runtime modules**: CPU, GPU, Memory, Disk, Network, Battery, Sensors, Bluetooth, Clock
- **Environment module support**: Weather service integration is available where configured
- **Visualization system**: per-module compatible visualizations (mini, line/bar charts, gauges, stacks, network dual charts, battery detail variants)
- **Popover depth**: detailed drill-down panels per module with process lists, history, and device-specific metrics
- **Advanced controls**:
  - Memory pressure gauge
  - Sensor fan control modes (Manual/Auto/System)
  - Per-GPU and electrical/battery diagnostics
  - Bluetooth multi-battery breakdowns
  - Network quality details (RSSI/noise/SNR/DNS)
- **Settings model**: Module, Widgets, Popup, and Notifications tabs with persisted preferences
- **Alerting**: threshold-based notifications with cooldown/deduplication controls

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
├── TonicApp.swift                    # App entry point
├── Views/                            # SwiftUI feature surfaces
│   ├── DashboardHomeView.swift       # Dashboard and quick actions
│   ├── SmartCareView.swift           # Smart Scan hub + managers
│   ├── SmartScan/                    # Space/Performance/Apps manager screens
│   ├── DiskAnalysisView.swift        # Storage Intelligence Hub
│   ├── AppManager/AppManagerView.swift # App inventory + scanner UI
│   └── PreferencesView.swift         # App settings
├── Services/                         # Core engines and background services
│   ├── SmartCareEngine.swift         # Smart Scan pipeline
│   ├── DeepCleanEngine.swift         # Deep clean categories
│   ├── AppInventoryService.swift     # App scanner/inventory orchestration
│   ├── CloudStorageScanner.swift     # Cloud provider scan
│   ├── WidgetDataManager.swift       # Widget/system metrics
│   └── NotificationManager.swift     # Threshold notification rules
├── MenuBarWidgets/                   # Widget runtime, popovers, settings
├── Models/                           # Data models and persisted config
├── Design/                           # Design tokens/components/motion
└── Utilities/                        # Scanning and system helpers
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
