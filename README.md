<div align="center">
  <p>
    <img src="Tonic/docs/assets/app-icon.png" alt="Tonic App Icon" width="128" height="128" />
  </p>
  <h1>Tonic</h1>
  <p><em>Beautiful native macOS system management.</em></p>
</div>


## Overview

Tonic is a native macOS system management app focused on cleanup, monitoring, storage intelligence, and app lifecycle management. It combines Smart Scan, Storage Scan, menu bar monitoring, and App Manager into a single SwiftUI experience.

Tonic provides a true native Mac experience with:
- **Real-time system monitoring** with live menu bar widgets
- **One-click smart scanning** that identifies junk and reclaimable space
- **Deep cleaning** across 10 categories of system clutter
- **Storage Scan (Storage Intelligence Hub)** with path browser, orbit map, and treemap visualization
- **App inventory** with uninstall and update capabilities

## Documentation

- [Design Doc](ARCHITECTURE.md)
- [Product Requirements Document (PRD)](PRD.md)
- [Store Security, Scopes, and Build Matrix Guide](STORE_SECURITY_SCOPES_AND_BUILDS.md)
- [Development Setup](SETUP.md)
- [Testing Guide](TESTING_GUIDE.md)

## Features

### Dashboard
The main dashboard provides an at-a-glance view of your Mac's health with:
- System health score (0-100) with color-coded rating
- Smart Scan-first primary action flow
- Contextual action states (Run Smart Scan, Stop Scan, Run Smart Clean, Review, Export report)
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

## Store Edition Security and Scope Access

Tonic supports dual distribution targets and uses a scope-first model for Mac App Store safety.
For more implementation detail, see [Store Security, Scopes, and Build Matrix Guide](STORE_SECURITY_SCOPES_AND_BUILDS.md).

### Distribution flavors

- **Direct target (`Tonic`)**
  - Compile flavor: `.direct`
  - Sparkle updater support: enabled
  - Privileged flows: allowed by capability flags
- **Store target (`TonicStore`)**
  - Compile flag: `TONIC_STORE`
  - Compile flavor: `.store`
  - Sparkle updater support: disabled
  - Update channel: App Store-managed
  - Scope-based access required for full coverage

### Store access model

Store edition replaces broad-machine assumptions with explicit user-granted scopes:

- Home
- Applications
- Startup disk (for "Full Mac" coverage)
- Additional folders or external volumes

Access is represented by strongly typed models (`AccessScope`, `ScopeAccessState`, `ScopeBlockedReason`) and persisted as security-scoped bookmarks.

### Scoped bookmark lifecycle

`AccessBroker` manages bookmark lifecycle:

1. Capture user-selected URL (open panel or drag/drop).
2. Canonicalize and deduplicate path roots.
3. Save bookmark data (`.withSecurityScope`) to app container storage (`access_scopes_v1.json`).
4. Revalidate on launch and status refresh.
5. Resolve stale/disconnected/invalid states with user remediation.

### Runtime enforcement

`ScopedFileSystem` is the enforcement boundary for Store-safe I/O:

- Scope coverage evaluation (`ready`, `needsAccess`, `limited`)
- Authorized-path filtering for scans and cleanups
- Read/write access wrappers with balanced security-scope start/stop
- Scoped metadata reads via `resourceValues(...)`
- Typed blocked-reason mapping for UI and service errors

### Coverage tiers

Store coverage is surfaced as:

- `Minimal`
- `Standard`
- `Full Mac`

The dashboard, onboarding, Storage Hub, and Smart Scan surfaces use this state to drive CTAs and messaging (`Grant Access`, `Needs access`, `Limited by macOS`).

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
- **Inventory + Activity Surface** - Unified view across discovered apps, extensions, login items, launch services, and background activities
- **Operational Filters** - Search, tab/category filters, quick filters, and sort controls
- **Two-pass scan behavior** - Fast discovery first, followed by optional size enrichment
- **Selection workflows** - Multi-select and task-oriented review
- **Safe uninstall flow** - Removes app bundle and associated files with protection checks
- **Update awareness** - Update availability checks for discovered apps

### Notification Rules
Create custom alerts based on:
- CPU usage (above threshold)
- Memory pressure (warning/critical)
- Disk space (low free percentage)
- Network connectivity (disconnected)
- Weather conditions (temperature extremes)

## Quick Start


### First Launch
1. Open Tonic from Applications or Spotlight
2. Complete the onboarding flow (7 guided screens)
3. Grant access:
   - Store build: authorize scopes (Home + Applications; optionally startup disk for full coverage)
   - Direct build: grant **Full Disk Access** in System Settings → Privacy (recommended for full scan surface)
4. Optionally enable **Notifications** for threshold alerts
5. Start with a Smart Scan from the dashboard

### Requirements
- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel Mac
- Access scopes (Store) or Full Disk Access (Direct) recommended for full functionality

## Architecture

```text
Tonic/
└── Tonic/
    ├── TonicApp.swift                    # App entry point
    ├── Views/                            # SwiftUI feature surfaces
    │   ├── DashboardHomeView.swift       # Smart Scan-first dashboard + action lane
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
    │   ├── NotificationRuleEngine.swift  # Rule evaluation + trigger history
    │   └── NotificationManager.swift     # Notification delivery/settings bridge
    ├── MenuBarWidgets/                   # Widget runtime, popovers, settings
    ├── Models/                           # Data models and persisted config
    ├── Design/                           # Design tokens/components/motion
    └── Utilities/                        # Scanning and system helpers
```

### Build Matrix (Direct + Store)

```bash
# Direct distribution target (Debug)
xcodebuild \
  -project Tonic/Tonic.xcodeproj \
  -scheme Tonic \
  -configuration Debug \
  -destination 'platform=macOS' \
  build CODE_SIGNING_ALLOWED=NO

# Store distribution target (Debug)
xcodebuild \
  -project Tonic/Tonic.xcodeproj \
  -scheme TonicStore \
  -configuration Debug \
  -destination 'platform=macOS' \
  build CODE_SIGNING_ALLOWED=NO

# Direct distribution target (Release)
xcodebuild \
  -project Tonic/Tonic.xcodeproj \
  -scheme Tonic \
  -configuration Release \
  -destination 'platform=macOS' \
  build

# Store distribution target (Release)
xcodebuild \
  -project Tonic/Tonic.xcodeproj \
  -scheme TonicStore \
  -configuration Release \
  -destination 'platform=macOS' \
  build
```

### Migration-Critical Test Runs

```bash
# Full test suite
xcodebuild \
  -project Tonic/Tonic.xcodeproj \
  -scheme Tonic \
  -configuration Debug \
  -destination 'platform=macOS' \
  test CODE_SIGNING_ALLOWED=NO

# Scope and access focused suites
xcodebuild \
  -project Tonic/Tonic.xcodeproj \
  -scheme Tonic \
  -configuration Debug \
  -destination 'platform=macOS' \
  test CODE_SIGNING_ALLOWED=NO \
  -only-testing:TonicTests/AccessScopeModelsTests \
  -only-testing:TonicTests/ScopeResolverTests \
  -only-testing:TonicTests/ServiceErrorHandlingTests
```

### Run
```bash
# Open the app
open Tonic/Tonic.xcodeproj
# Then press Cmd+R in Xcode
```

### Security and Scope Notes for Developers

- Avoid raw file I/O in Store-sensitive paths after only `canRead` checks.
- Route file operations and metadata reads through `ScopedFileSystem`.
- Preserve blocked reason taxonomy (`missingScope`, `staleBookmark`, `disconnectedScope`, `sandbox*Denied`, `macOSProtected`) through service and UI layers.
- Keep direct target behavior unchanged unless the refactor is explicitly no-op for direct mode.
- For App Store submission behavior and demo script, review `Tonic/APP_STORE_REVIEW_NOTES.md`.


## Acknowledgments

Built with:
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - Native UI framework
- [Sparkle](https://sparkle-project.org/) - Software update framework
- [IOKit](https://developer.apple.com/documentation/iokit) - Hardware access
- [CoreLocation](https://developer.apple.com/documentation/corelocation) - Weather location
