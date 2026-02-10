# Product Requirements Document (PRD)

## Tonic - Native macOS System Management

**Version:** 1.0  
**Status:** In Development  
**Last Updated:** February 2026

---

## Table of Contents

1. [Product Overview](#1-product-overview)
2. [Problem Statement](#2-problem-statement)
3. [Product Vision](#3-product-vision)
4. [Target Users](#4-target-users)
5. [Core Features](#5-core-features)
6. [Feature Specifications](#6-feature-specifications)
7. [Technical Requirements](#7-technical-requirements)
8. [User Experience](#8-user-experience)
9. [Current State](#9-current-state)
10. [Success Metrics](#10-success-metrics)
11. [Freemium Model](#11-freemium-model)

---

## 1. Product Overview

Tonic is a native macOS application that provides comprehensive system management capabilities through a beautiful, modern interface. It combines disk cleanup, performance monitoring, app management, and real-time menu bar widgets into a single, polished application.

Unlike CLI-based tools or web utilities, Tonic leverages native macOS frameworks (SwiftUI, IOKit, CoreLocation) to provide:
- True native performance and responsiveness
- Deep integration with macOS system services
- Real-time hardware monitoring without external dependencies
- Safe, reversible cleanup operations with preview capabilities

### Product Positioning

```
┌─────────────────────────────────────────────────────────────┐
│                    Tonic Position                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   Simple Tools                    Tonic                    │Commercial Suites
│   (CleanMyMac X,                   →                        │  (MacKeeper,  │
│    DaisyDisk, etc.)                    Native macOS         │   Dr. Cleaner)│
│                                           Excellence        │               │
│                                                             │
│   • CLI-based or            • Native SwiftUI               │   • Bloated    │
│     web-based               • Real-time widgets           │   • Upselling  │
│   • Limited polish          • Deep macOS integration      │   • Subscription│
│   • Fragmented features     • One-time purchase option    │     fatigue    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Problem Statement

### The Problem

macOS users face several challenges in maintaining their systems:

1. **Hidden Disk Consumption**
   - Cache files accumulate silently (browser caches, app caches, system caches)
   - Log files grow unbounded over time
   - Development artifacts (node_modules, build outputs) consume gigabytes
   - Old iOS device backups, Xcode derived data, and Docker images hide in obscure locations

2. **Lack of Visibility**
   - No native way to see what's consuming disk space
   - Real-time system monitoring requires multiple tools or Terminal commands
   - Menu bar widgets for system stats are either absent or require separate installations
   - Memory pressure and CPU usage aren't visible without launching Activity Monitor

3. **Unsafe Cleanup Tools**
   - CLI tools require command-line expertise and risk permanent data loss
   - Existing apps lack proper safety mechanisms (whitelists, previews)
   - No granular control over what gets deleted
   - Orphaned app files persist after uninstallation

4. **Fragmented User Experience**
   - Multiple apps needed for different maintenance tasks
   - No unified dashboard for system health
   - Settings scattered across System Settings
   - Menu bar widgets require separate installations

### User Pain Points

| Pain Point | Current Workaround | User Frustration |
|------------|-------------------|------------------|
| "My disk is full but I don't know what's taking space" | DaisyDisk, Disk Inventory X | Third-party tool, paid, or CLI |
| "I want to see CPU/Memory in my menu bar" | iStatMenus, Stats | Paid apps, menu bar clutter |
| "I accidentally deleted important files" | Time Machine restore | No preview before cleanup |
| "Apps leave behind files after uninstall" | AppCleaner, manual deletion | Additional tool needed |

---

## 3. Product Vision

### Vision Statement

> "Create the single, indispensable tool for Mac users to maintain, optimize, and monitor their systems with a beautiful native experience that respects user data and privacy."

### Core Values

1. **Native Excellence** - Every feature built with native macOS technologies for optimal performance and integration
2. **Safety First** - All destructive operations include preview, confirmation, and undo capabilities
3. **Transparency** - Users see exactly what will be cleaned, why, and how much space will be reclaimed
4. **Performance** - Fast scans, low memory footprint, no background processes unless needed
5. **Privacy** - No data collection, no cloud processing of personal files, local-first architecture

### Product Principles

- **Single Window** - Most tasks accessible from the main dashboard
- **Progressive Disclosure** - Simple by default, powerful when needed
- **Safe Defaults** - Conservative cleanup recommendations, protected system files
- **Instant Feedback** - Real-time progress, clear success/error states

---

## 4. Target Users

### Primary Users

#### Power Users and Developers
- **Demographics**: 25-45 years old, technical profession
- **Devices**: MacBook Pro/Mac Studio, typically Apple Silicon
- **Needs**:
  - Clean development artifacts (node_modules, build folders, Docker)
  - Real-time system monitoring during development
  - Complete app uninstallation including preferences
  - Customizable menu bar widgets

**User Story:**
> "As a developer, I want to quickly identify and clean up large development folders so I can free up disk space for new projects without manually hunting through my file system."

#### Creative Professionals
- **Demographics**: 20-50 years old, design/video/music production
- **Devices**: MacBook Pro, iMac Pro, Mac Studio
- **Needs**:
  - Large file identification and management
  - Cache cleanup for creative applications
  - Disk usage visualization (treemap)
  - System performance monitoring during rendering

**User Story:**
> "As a video editor, I want to see which projects are taking the most space and quickly clean up cache files so I can continue working without disk space warnings."

#### General Mac Users
- **Demographics**: All ages, non-technical background
- **Devices**: Any Mac running macOS 14+
- **Needs**:
  - Simple, one-click cleanup
  - Clear explanations of what will be cleaned
  - Safe operation without risk of data loss
  - Health score showing system condition

**User Story:**
> "As a casual Mac user, I want a simple way to clean up my Mac without understanding technical details so I can keep my computer running smoothly."

### Secondary Users

- **IT Administrators** - Deployable to managed Macs for standardization
- **Family Tech Support** - Recommended to less technical family members
- **Small Business Owners** - Free alternative to paid system management suites

---

## 5. Core Features

### Feature Overview

| Feature | Status | Description |
|---------|--------|-------------|
| Dashboard | Implemented | System health score, Smart Scan action lane, and recommendation surfaces |
| Smart Scan | Implemented | Three-pillar scan (Space, Performance, Apps) with actionable run flow |
| Deep Clean | Implemented | Multi-category cleanup with progress and safety checks |
| Storage Scan (Storage Intelligence Hub) | Implemented | Quick/Full/Targeted local storage analysis with guided cleanup |
| Cloud Storage Scan | Partially Implemented | Provider detection and cache sizing available; deeper selective cleanup is limited |
| System Monitoring | Implemented | Real-time CPU, Memory, Disk, Network, GPU, and Battery metrics |
| Menu Bar Widgets | Implemented | Customizable multi-module widgets with OneView unified mode |
| Apps Scanner | Implemented | Fast app inventory scan plus size enrichment and issue-focused app analysis in Smart Scan |
| App Management | Implemented | Categorized inventory, login/background item visibility, uninstall flows |
| Notification Rules | Implemented | Threshold alerts with cooldown and permission-aware behavior |
| Preferences | Implemented | Theme, modules, permissions, and update controls |
| Onboarding | Implemented | First-run flow for permissions and setup |

### Feature Groupings

#### System Cleanup
- Smart Scan (Space, Performance, Apps pillars)
- Deep Clean (category-driven cleanup)
- Hidden Space analysis
- Cloud storage scan (provider-level detection and cache metrics)
- Collector Bin (staging and restore path)

#### System Monitoring
- Real-time Dashboard
- System Status Dashboard
- Menu Bar Widgets (individual items + OneView unified mode)
- Notification Rules Engine

#### App Management
- App Manager Scanner (inventory-first discovery + optional size enrichment)
- Smart Scan Apps pillar (unused/large/duplicate/orphaned issue surfacing)
- App uninstallation and associated file cleanup
- App update checks

#### Storage Intelligence
- Storage scan modes (Quick, Full, Targeted)
- Explore views (path browser, orbit map, treemap)
- Act workflows (Guided Assistant, Cart + Review)
- Insights and history (reclaim packs, anomaly/trend/forecast signals)

---

## 6. Feature Specifications

### 6.1 Dashboard

**Description:** Main entry point showing system health score, Smart Scan action lane, real-time stats, and recommendations.

**User Flow:**
1. User opens Tonic
2. Sees health score (0-100) with color-coded rating
3. Uses the primary Smart Scan action to start, stop, or continue system review
4. Reviews contextual actions after scan results (run Smart Clean, review details, export report)
5. Checks recommendations and recent activity timeline

**Requirements:**

| Requirement | Priority | Description |
|-------------|----------|-------------|
| Health Score Display | Must Have | Show 0-100 score with circular progress indicator |
| Smart Scan Action Lane | Must Have | Primary Smart Scan CTA with state-aware actions (scan, stop, run, review, export) |
| Real-time Stats | Must Have | Storage, Memory, CPU percentages update every 2s |
| Recommendations | Must Have | Actionable items with space estimates |
| Activity Timeline | Should Have | Show recent scan/clean operations |

**Acceptance Criteria:**
- [ ] Health score displays within 1 second of app launch
- [ ] Smart Scan action lane reflects scan state and exposes correct follow-up actions
- [ ] Stats update in real-time without lag
- [ ] Recommendations show potential space reclamation

**Technical Notes:**
- Health and recommendation scoring is derived from Smart Scan findings, runnable safety, and aggregated cleanup impact
- Stats fetched from `WidgetDataManager.shared`

---

### 6.2 Smart Scan

**Description:** Smart Scan is the guided analysis and execution experience that scans Space, Performance, and Apps pillars, then lets users run recommended actions safely.

**User Flow:**
1. User clicks "Smart Scan" from dashboard
2. Scan runs through three pillars with live counters and stage timeline
3. Results show grouped findings by Space, Performance, and Apps
4. User can review by pillar or trigger quick actions from result tiles
5. User runs Smart Clean for recommended runnable items or selects custom items

**Scanning Stages:**

| Stage | Purpose | Representative Output |
|-------|---------|-----------------------|
| Space | Detect reclaimable storage and clutter | Reclaimable bytes, cleanup groups, safe-to-run items |
| Performance | Detect maintenance and startup/background friction | Flagged maintenance/login/background items |
| Apps | Detect app lifecycle issues | Unused/large/duplicate/orphaned app findings |

**Requirements:**

| Requirement | Priority | Description |
|-------------|----------|-------------|
| Stage Progression | Must Have | Show current stage and completed stages for Space/Performance/Apps |
| Live Counters | Must Have | Show space found, performance flags, and app scan count during execution |
| Cancel Operation | Must Have | Allow user to stop scan or run in progress |
| Selective Execution | Must Have | Let user run only selected runnable items after review |
| Smart Recommendations | Must Have | Preselect safe, high-value actions for one-click Smart Clean |
| Drill-down Managers | Should Have | Per-pillar review screens for manual inspection and selection |

**Acceptance Criteria:**
- [ ] Smart Scan surfaces all three pillars in order with visible progression
- [ ] Live counters update while scanning and reflect final result totals
- [ ] Canceling scan/run leaves app responsive and returns control to user
- [ ] Smart Clean executes only safe runnable actions unless user overrides by explicit selection
- [ ] Results provide clear per-item reclaim estimates and actionability

---

### 6.3 Deep Clean

**Description:** Comprehensive cleanup across 10 categories with detailed progress tracking.

**Cleanup Categories:**

| Category | Scan Time | Typical Space |
|----------|-----------|---------------|
| System Cache | Fast | 1-5 GB |
| User Cache | Medium | 5-20 GB |
| Log Files | Fast | 0.5-2 GB |
| Temporary Files | Fast | 0.5-2 GB |
| Browser Cache | Fast | 1-5 GB |
| Downloads | Fast | Variable |
| Trash | Fast | Variable |
| Development | Slow | 10-50 GB |
| Docker | Medium | 5-20 GB |
| Xcode | Slow | 10-30 GB |

**Requirements:**

| Requirement | Priority | Description |
|-------------|----------|-------------|
| Category Selection | Must Have | Toggle individual categories |
| Pre-scan Display | Must Have | Show items to be cleaned before execution |
| Progress Tracking | Must Have | Real-time progress during cleanup |
| Space Freed | Must Have | Display total bytes freed after completion |
| Whitelist Support | Should Have | Exclude user-specified paths |

**Acceptance Criteria:**
- [ ] Each category can be independently enabled/disabled
- [ ] Pre-scan shows item count and total size
- [ ] Progress updates every 500ms during cleanup
- [ ] Final result shows accurate bytes freed

---

### 6.4 System Monitoring

**Description:** Real-time display of system metrics with configurable refresh rates.

**Metrics Monitored:**

| Metric | Source | Update Frequency |
|--------|--------|------------------|
| CPU Usage | `host_processor_info()` | 1-5s configurable |
| Memory Usage | `vm_statistics64()` | 1-5s configurable |
| Disk Usage | `getfsstat()` | 5-10s |
| Network Activity | `sysctl` NET_RT_IFLIST2 | 1-5s configurable |
| GPU Stats | IOKit (Apple Silicon) | 2s |
| Battery | IOKit `IOPS` | 5s |

**Requirements:**

| Requirement | Priority | Description |
|-------------|----------|-------------|
| Metric Display | Must Have | Show current value with unit |
| History Graph | Should Have | Sparkline showing recent values |
| Process List | Should Have | Top CPU/memory consuming processes |
| Customizable Interval | Could Have | User-settable refresh rate |

**Acceptance Criteria:**
- [ ] Metrics update within 1 second of actual change
- [ ] Values match Activity Monitor within 1% tolerance
- [ ] No memory leak during extended monitoring sessions

---

### 6.5 Menu Bar Widgets

**Description:** Real-time system modules displayed in the menu bar, available as individual status items or as a unified OneView status item.

**Widget Modules:**

| Module | Scope | Notes |
|--------|-------|-------|
| CPU | Core/system usage | Supports chart/gauge style visualizations |
| GPU | Apple Silicon focused metrics | Platform-dependent visibility |
| Memory | Usage and pressure | Includes pressure-focused views |
| Disk | Capacity and I/O | Includes speed/chart representations |
| Network | Throughput/connectivity | Dual upload/download visualization options |
| Battery | Power and health | Portable-Mac dependent visibility |
| Sensors | Temperature/fans | Includes fan control modes |
| Bluetooth | Device connectivity/battery | Multi-device summary views |
| Clock | Timezone/time display | Stack/label-style views |
| Weather | Environment integration | Optional module shown when weather/location integration is configured |

**Requirements:**

| Requirement | Priority | Description |
|-------------|----------|-------------|
| Individual + Unified Modes | Must Have | Support per-widget status items and OneView unified mode |
| Visualization Compatibility | Must Have | Enforce per-module compatible visualization options |
| Customization | Must Have | Enable/disable, reorder, color, refresh, and module settings |
| Popover Drill-down | Must Have | Clicking widgets opens detail popovers with contextual metrics |
| Settings Persistence | Must Have | Widget configuration persists across restarts and migration versions |
| Threshold Notifications | Should Have | Per-widget alert thresholds with cooldown/de-dup behavior |

**Acceptance Criteria:**
- [ ] Enabled modules appear correctly in individual mode and in unified OneView mode
- [ ] Incompatible visualization selections are prevented or normalized safely
- [ ] Settings changes are reflected in runtime without app restart
- [ ] Popovers open reliably with module-specific details
- [ ] Notification thresholds respect cooldown settings and permission state

---

### 6.6 App Management

**Description:** App Management combines inventory scanning, filtering, update awareness, and uninstall operations into one workflow.

**Scanner Model:**

| Scanner Path | Behavior | User Outcome |
|--------------|----------|--------------|
| App Manager Scanner | Fast discovery first, optional size enrichment pass | Quick inventory load with progressively better size accuracy |
| Smart Scan Apps Pillar | Issue-oriented app checks during Smart Scan | Cleanup-ready app recommendations in Smart Scan results |

**Inventory Categories:**

| Category | Examples |
|----------|----------|
| Apps | Standard `.app` bundles |
| App Extensions | Finder/Safari/system extensions |
| Preference Panes | `.prefPane` bundles |
| Quick Look Plugins | `.qlgenerator` bundles |
| Spotlight Importers | `.mdimporter` bundles |
| Frameworks | `.framework` and runtime artifacts |
| System Utilities | Helper and utility bundles |
| Login Items | Launch agents/daemons/login entries |

**Requirements:**

| Requirement | Priority | Description |
|-------------|----------|-------------|
| App Listing | Must Have | Show categorized items with counts and sizes |
| Search + Sort + Filter | Must Have | Search by name/bundle ID; sort/filter for usage and category workflows |
| Login/Background Visibility | Must Have | Expose startup/background item inventory in app context |
| Update Awareness | Should Have | Surface available app update counts and status |
| Safe Uninstall | Must Have | Remove app bundle and associated files with safety checks |
| Batch Selection | Should Have | Support multi-item selection for workflow efficiency |

**Acceptance Criteria:**
- [ ] Initial scan populates inventory quickly before full size enrichment completes
- [ ] Category filters, search, and sort produce consistent results
- [ ] Login/background-related entries are visible and filterable
- [ ] Uninstall flow honors protected-item rules and reports outcomes clearly
- [ ] Smart Scan app issues map cleanly into App Management review context

---

### 6.7 Storage Scan

**Description:** Storage Scan (Storage Intelligence Hub) provides local storage analysis plus action-oriented cleanup workflows, with optional cloud provider scan context.

**Local Storage Modes:**

| Mode | Scope | Purpose |
|------|-------|---------|
| Quick | Reduced depth/priority pass | Fast overview for immediate decisions |
| Full | Comprehensive path indexing | Maximum fidelity for cleanup planning |
| Targeted | User-selected paths | Focused analysis for known hot spots |

**Requirements:**

| Requirement | Priority | Description |
|-------------|----------|-------------|
| Permission Handling | Must Have | Guide users through Full Disk Access requirements |
| Explore Views | Must Have | Provide browser, orbit map, and treemap views for scanned nodes |
| Action Workflows | Must Have | Support Guided Assistant and Cart + Review cleanup modes |
| Insight Surfaces | Should Have | Show reclaim packs, anomalies, trends, and forecast narratives |
| History Tracking | Should Have | Persist scan history and trend context for repeat scans |
| Safety Guardrails | Must Have | Risk-level labeling, blocked/protected paths, and pre-execution review |

**Cloud Storage Scan Requirements:**

| Requirement | Priority | Description |
|-------------|----------|-------------|
| Provider Detection | Must Have | Detect iCloud, Dropbox, Google Drive, and OneDrive presence |
| Usage Summary | Must Have | Report cache size and synced file counts per detected provider |
| Cache Cleanup | Should Have | Support cache clearing where provider paths are known and safe |

**Acceptance Criteria:**
- [ ] Quick/Full/Targeted modes execute and report progress/state transitions
- [ ] Users can navigate scan results and select cleanup candidates before execution
- [ ] Cleanup workflow reports estimated reclaim and blocked-path reasons
- [ ] Repeat scans on similar scopes contribute to trend/history views
- [ ] Cloud scan returns provider-level summaries when provider paths exist

---

### 6.8 Notification Rules

**Description:** User-configurable alerts based on system metrics.

**Supported Metrics:**

| Metric | Conditions | Example |
|--------|------------|---------|
| CPU Usage | > 80% for 5 min | "CPU is running hot" |
| Memory Pressure | = Critical | "Memory is critically low" |
| Disk Space | < 10% free | "Disk is almost full" |
| Network | Disconnected | "No network connection" |
| Weather | > 35°C or < 0°C | "Extreme temperature" |

**Requirements:**

| Requirement | Priority | Description |
|-------------|----------|-------------|
| Rule Creation | Must Have | Create custom rules |
| Preset Rules | Must Have | Common rules pre-configured |
| Cooldown | Must Have | Prevent notification spam |
| Trigger History | Should Have | Log of triggered rules |

**Acceptance Criteria:**
- [ ] Rules trigger within 30 seconds of condition met
- [ ] Cooldown prevents duplicate notifications
- [ ] Trigger history shows last 100 entries

---

## 7. Technical Requirements

### System Requirements

| Requirement | Specification |
|-------------|---------------|
| macOS Version | 14.0 (Sonoma) or later |
| Architecture | Apple Silicon (arm64) and Intel (x86_64) |
| Memory | 8 GB minimum, 16 GB recommended |
| Storage | 50 MB for app, variable for cache |

### Permission Requirements

| Permission | Purpose | Required For |
|------------|---------|--------------|
| Full Disk Access | Scan and clean all files | Disk scanning, cleanup, app uninstall |
| Accessibility | Automate system tasks | System optimization, launch services rebuild |
| Notifications | Alert users | Scan completion, low disk space, alerts |
| Location (When In Use) | Weather widget | Local weather and environment module context |

### Technical Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| SwiftUI | macOS 14+ | User interface framework |
| IOKit | System | Hardware monitoring (CPU, memory, battery, GPU) |
| CoreLocation | System | Location services for weather |
| Sparkle | 2.x | Software update framework |
| Security | System | Keychain access, privileged operations |

### Performance Requirements

| Operation | Target Time | Measured By |
|-----------|-------------|-------------|
| App Launch | < 2 seconds | Time to first frame |
| Smart Scan | < 30 seconds | Total scan time on typical system |
| Deep Clean Scan | < 60 seconds | Category enumeration |
| Widget Update | < 100ms | UI refresh latency |
| Memory Footprint | < 100 MB | Idle state memory usage |

### Security Requirements

- No data collection or telemetry
- All file operations local only
- Privileged helper for root operations (optional)
- Whitelist protection for critical system paths
- Protected apps cannot be uninstalled
- Confirmation required before permanent deletion

---

## 8. User Experience

### Onboarding Flow

**7-Screen Guided Flow:**

| Page | Title | Content |
|------|-------|---------|
| 1 | Welcome | Product intro and value framing |
| 2 | Smart Scan | Space/Performance/Apps overview |
| 3 | Storage Lens | Storage intelligence and visual analysis intro |
| 4 | App Manager | App inventory and uninstall value framing |
| 5 | Menu Widgets | Real-time monitoring and alerting intro |
| 6 | Setup | Full Disk Access + Notifications setup guidance |
| 7 | Ready | Final summary and launch action |

**UX Principles:**
- Clear value proposition on each page
- Skip buttons for advanced users
- Non-blocking permission requests
- Clear success/error states

### Safety Guarantees

1. **Preview Before Clean**
   - All cleanup operations show what's being deleted
   - Total size displayed before confirmation
   - Individual items can be deselected

2. **Collector Bin**
   - Deleted items staged in Collector Bin first
   - Restore/remove workflow before permanent deletion
   - Capacity guardrails enforced by item count and total staged size limits
   - Permanent deletion requires explicit confirmation

3. **Whitelist**
   - User-defined paths protected from cleaning
   - Development directories protected by default
   - System-critical paths always protected

4. **Confirmation Dialogs**
   - All destructive operations require confirmation
   - Clear wording: "This will permanently delete X files"
   - Option to require password for permanent deletion

### Accessibility

- Full VoiceOver support
- Keyboard navigation throughout
- High contrast mode support
- Scalable text sizes
- Reduced motion option

### Theming

- Dark mode (default)
- Light mode
- System-following mode
- Accent color customization

---

## 9. Current State

### Implemented Features

| Feature | Status | Notes |
|---------|--------|-------|
| Dashboard | Complete | Health score, Smart Scan action lane, stats, recommendations |
| Smart Scan | Complete | Three-pillar scan (Space/Performance/Apps), runnable recommendations |
| Deep Clean | Complete | Category-driven cleanup with progress and summaries |
| Storage Scan (Storage Intelligence Hub) | Complete | Quick/Full/Targeted scans, explore/act/insights/history surfaces |
| Disk Treemap/Orbit Views | Complete | Visual storage terrain for scanned nodes |
| System Monitoring | Complete | CPU, Memory, Disk, Network, GPU, Battery metrics |
| Menu Bar Widgets | Complete | Individual + OneView runtime modes with persistent customization |
| App Manager Scanner | Complete | Fast inventory scan with optional size enrichment and category workflows |
| App Uninstall | Complete | Bundle + associated files removal with protection checks |
| Notification Rules | Complete | Threshold alerts with cooldown controls |
| Preferences | Complete | Theme, updates, permissions, module configuration |
| Onboarding | Complete | 7-screen guided setup flow |
| Collector Bin | Complete | Staging, restore, permanent delete |

### Partially Implemented

| Feature | Status | Missing |
|---------|--------|---------|
| App Updates | Partial | Detection is present; full end-to-end batch update workflow is incomplete |
| Cloud Storage Scan | Partial | Provider scan and summary work; fine-grained selective cleanup is limited |

### Not Yet Implemented

| Feature | Priority | Description |
|---------|----------|-------------|
| Docker/VM Deep Clean | Medium | Container/image management UI |
| Duplicate Finder | Low | Find and merge duplicate files |
| Time Machine Management | Low | Local snapshots cleanup UI |
| iOS Device Backup Manager | Low | iPhone/iPad backup visualization |

### Known Issues

See [GitHub Issues](https://github.com/tw93/Tonic/issues) for current bugs and known limitations.

---

## 10. Success Metrics

### User Acquisition Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| GitHub Stars | 1,000 in 6 months | GitHub repository |
| Downloads | 10,000 in 6 months | GitHub Releases |
| Community Engagement | 1,000 contributors/participants in 6 months | Issues, discussions, and feedback participation |

### Engagement Metrics

| Metric | Target | Description |
|--------|--------|-------------|
| Smart Scan Completion | > 70% | Users who start a scan complete it |
| Clean Conversion | > 50% | Scans that result in cleanup action |
| Widget Adoption | > 30% of users | Users with at least one menu bar widget |
| Return Rate | > 40% | Users who open app again after 7 days |

### Performance Metrics

| Metric | Target | Description |
|--------|--------|-------------|
| App Launch Time | < 2 seconds | Time to first frame |
| Scan Completion | < 30 seconds | Smart scan on typical system |
| Crash Rate | < 0.1% | Sessions ending in crash |

### User Satisfaction

| Metric | Target | Measurement |
|--------|--------|-------------|
| App Store Rating | 4.5+ stars | Future distribution |
| GitHub Issues | < 10 open bugs | Maintain clean issue tracker |
| Response Time | < 48 hours | Issue response on GitHub |

---

## 11. Freemium Model

> **Note:** Freemium support is partially modeled in internal licensing logic, but production packaging and purchase UX are still being finalized.

### Tiers

| Feature | Basic (Free) | Pro (Paid) |
|---------|--------------|------------|
| **Dashboard** | ✓ | ✓ |
| **Smart Scan** | ✓ | ✓ |
| **System Monitoring** | ✓ | ✓ |
| **Menu Bar Widgets** | Core subset | Full module set + advanced customization |
| **App Scanner / Inventory** | View and scan | Advanced actions, uninstall, expanded workflows |
| **Deep Clean** | Core categories | Full category set |
| **Storage Scan (Hub)** | Basic scan + browse | Full workflows (guided/cart/insights/history) |
| **Notification Rules** | Presets | Custom rules (unlimited) |
| **Cloud Storage Scan** | Provider detection summary | Expanded cleanup controls (planned) |
| **App Updates** | - | ✓ |
| **Priority Support** | - | ✓ |

### Free Tier (Tonic Basic)

**Purpose:** Deliver essential cleanup and monitoring value with safe defaults.

**Included Features:**
- Dashboard with health indicators
- Smart Scan core recommendations
- Real-time monitoring and core menu modules
- App scanning and inventory visibility
- Basic storage scan and browsing
- Preset notification rules

**Limitations:**
- Advanced uninstall and batch remediation workflows may be restricted
- Full storage insight/action workflows may be restricted
- Fine-grained cloud cleanup controls may be restricted

### Pro Tier (Tonic Pro)

**Purpose:** Unlock full power-user workflows and advanced automation/safety controls.

**Additional Features:**
- Full widget module and visualization configuration
- Expanded Smart Scan and Deep Clean controls
- Advanced app remediation/uninstall workflows
- Full Storage Hub workflow surface (guided, cart, insights, history)
- Expanded cloud storage cleanup controls
- App updater workflows

**Implementation Notes:**
- StoreKit-backed productization is planned; current codebase includes tier/limit scaffolding
- Final purchase model (subscription, lifetime, or mixed) is still under product decision
- No forced subscription objective remains

### Upgrade UX

- Non-intrusive upgrade prompts
- Feature comparison visible before attempting locked features
- Clear value proposition for Pro
- No degraded experience for free users

---

## Appendix A: Glossary

| Term | Definition |
|------|------------|
| Apps Scanner | Combined app discovery workflows in App Manager and Smart Scan app issue analysis |
| Collector Bin | Staging area for items marked for deletion, with restore path before permanent delete |
| Deep Clean | Category-driven cleanup workflow for reclaimable system and app clutter |
| Health Score | 0-100 rating of system condition based on scan findings and actionability |
| Menu Bar Widget | Real-time system module displayed in menu bar (individual or unified OneView mode) |
| Smart Scan | Three-pillar analysis flow (Space, Performance, Apps) with runnable recommendations |
| Storage Scan | Storage Intelligence Hub analysis workflow for local storage and cleanup planning |
| Treemap | Area-based visualization that represents hierarchical size distribution |
| Whitelist | User-specified paths protected from cleanup operations |

---

## Appendix B: File Structure Reference

```
~/Library/Application Support/Tonic/
├── CollectorBin/
│   └── bin_items.json          # Collector Bin staged item metadata
└── (feature data persisted via UserDefaults keys)

~/Library/Caches/com.pretonic.tonic/
└── appcache.json               # App inventory scan cache

~/Library/Logs/Tonic/
└── tonic.log                   # Application logs

UserDefaults keys (representative):
- tonic.widget.store.configs
- tonic.history.*
- tonic.notificationRules.*
- tonic.activity.log
- tonic.license.*
```

---

## Appendix C: API References

| API | Purpose | Documentation |
|-----|---------|---------------|
| IOKit | Hardware monitoring | developer.apple.com/documentation/iokit |
| CoreLocation | Location services | developer.apple.com/documentation/corelocation |
| SwiftUI | UI framework | developer.apple.com/documentation/swiftui |
| Sparkle | Software updates | sparkle-project.org/documentation |
| Open-Meteo | Weather data | open-meteo.com/docs |

---

*Document Version: 1.0*  
*Last Updated: February 2026*  
*Next Review: April 2026*
