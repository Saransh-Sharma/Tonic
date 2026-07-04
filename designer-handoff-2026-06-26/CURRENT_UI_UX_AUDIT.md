# Tonic Current UI/UX Audit

Date: 2026-06-26  
Audience: product designer redesigning the presentation layer from scratch  
Screenshot set: `screenshots/INDEX.md` with 86 PNGs across Direct and Store builds

This audit documents the current product, flows, product placement, and UX risks. It intentionally does not propose a new visual design direction.

## Executive Summary

Tonic currently presents itself as a Mac health command center with four major jobs: scan/clean, inspect storage, manage apps, and monitor system metrics through menu bar widgets. The product scope is broad, but the UI often treats every module as equally important. The result is a dense, glass-heavy dashboard and settings system where users have to infer which action matters now.

Highest-impact issues:

- Permission and access surfaces are currently fragile, especially in the Store build. Evidence: `00-app-shell/00-app-shell__store__permission-prompt-full-disk.png`.
- Dashboard product placement is overloaded: Smart Scan, hardware specs, live stats, widgets, and activity compete in the first screen. Evidence: `02-dashboard/02-dashboard__direct__default.png`.
- Settings are split across at least two systems: main Preferences and menu-bar `TabbedSettingsView`. Evidence: `09-preferences/09-preferences__direct__modules.png`, `10-menu-bar-surfaces/10-menu-bar-surfaces__direct__tabbed-widget-settings.png`.
- Several screens use visual spectacle as a structural layer; large ambient shapes and glass panels compete with utilitarian Mac dashboard content. Evidence: most dashboard/settings captures.
- WIP/debug routes are enabled by default in Debug builds and look shippable enough to confuse product scope. Evidence: `11-debug-wip/11-debug-wip__direct__developer-tools.png`, `11-debug-wip/11-debug-wip__direct__design-sandbox.png`.

Issue count by severity: 0 Critical, 7 High, 9 Medium, 5 Low.

## Product Map

Primary navigation destinations from `NavigationDestination`: Dashboard, System Cleanup / Smart Scan, App Manager, Storage Hub, Recently Cleaned, Live Monitoring, Menu Bar Widgets, Developer Tools, Design Sandbox, Settings.

Primary jobs-to-be-done:

- Diagnose Mac health and run Smart Scan.
- Reclaim storage through Smart Scan and Storage Hub.
- Inspect and uninstall apps.
- Configure and use menu bar system widgets.
- Review cleanup history and restore recoverable items.
- Adjust permissions, modules, updates, and appearance.

Entry points and surfaces:

- Main app window: `WindowGroup` wraps `ContentView` in `TonicApp.swift:15`.
- Main sidebar: `NavigationSplitView` in `ContentView.swift:37`.
- Command palette: Tools menu and `Cmd-K` command in `TonicApp.swift:21`.
- Preferences window: custom `PreferencesWindowController` in `PreferencesView.swift:277`.
- Menu bar widgets: started from app launch after `tonic.widget.hasCompletedOnboarding` in `TonicApp.swift:121`.
- Internal notification/deep-link-like paths: module settings, widget customization, Storage Hub to App Manager in `ContentView.swift:63`.

No URL deep-link handler was found in the inspected Swift sources. External reachability appears to be internal notifications and menu commands rather than URL/deep-link navigation.

## Flow Audit

### Onboarding

Evidence: `01-onboarding/01-onboarding__direct__page-01.png` through `01-onboarding/01-onboarding__direct__page-07.png`, plus Store variants.

- The flow has 7 pages (`UnifiedOnboardingView.swift:28`). That is long for a utility whose value depends on getting to the first scan quickly.
- Setup mixes permissions, mode choice, and notifications on one page (`UnifiedOnboardingView.swift:340`, `UnifiedOnboardingView.swift:480`, `UnifiedOnboardingView.swift:543`). The designer should treat this as three separate intent questions even if they remain technically adjacent.
- Direct and Store builds diverge in copy: Full Disk Access vs Authorized Locations (`UnifiedOnboardingView.swift:349`). The current UI does not make that distribution distinction feel like a first-class product concept.
- The Store setup has "Authorized Locations" but still displays "Full Disk Access" in the permissions row label in the prompt capture, creating a promise/scope mismatch.

### Dashboard To Action

Evidence: `02-dashboard/02-dashboard__direct__default.png`, `02-dashboard/02-dashboard__direct__health-popover.png`.

- The first dashboard screen mixes Smart Scan, hardware identity, live stats, widgets, and recent activity. This weakens the hierarchy of the primary action, even though "Run Smart Scan" is present.
- The hardware/spec card is visually prominent and can read like a system profiler rather than a decision-support panel.
- The health explanation is behind an icon-only help button (`DashboardHomeView.swift:114`); the metric model is not self-evident from the dashboard itself.
- The dashboard copy claims "Storage, cleanup, apps, widgets, and live status in one place" (`DashboardHomeView.swift:94`). That is accurate, but it also describes the core UX problem: too many product domains share the same top-level real estate.

### Smart Scan

Evidence: `03-smart-scan/03-smart-scan__direct__ready.png`, `03-smart-scan/03-smart-scan__direct__space-manager-empty.png`, `03-smart-scan/03-smart-scan__direct__performance-manager-empty.png`, `03-smart-scan/03-smart-scan__direct__apps-manager-empty.png`.

- Smart Scan has the clearest product story: scan, review, clean, restore. The manager routes also provide an escape hatch with back navigation.
- The current ready state is still visually heavy for a simple decision. Decorative ambience and glass surfaces take priority over the exact scan scope.
- Empty manager states exist, which is good, but they are structurally similar across Space, Performance, and Apps. The difference between these review domains is not visually or behaviorally sharp enough.

### Storage Hub

Evidence: `04-storage-hub/04-storage-hub__direct__default.png`, `04-storage-hub/04-storage-hub__store__default.png`.

- Storage Hub is a separate product inside the product: tabs for Hub Home, Explore, Act, Insights, History (`DiskAnalysisView.swift:11`), scan modes, root path controls, workflow modes, cart, guided cleanup, filters, preview, and keyboard shortcuts.
- It exposes local paths by default through `rootPath` and `pathJumpText` initialized to the user's home directory (`DiskAnalysisView.swift:39`). Even if expected for a storage tool, the redesign needs a privacy-aware presentation model.
- The Act workflow introduces two cleanup models, "Guided Assistant" and "Cart + Review" (`DiskAnalysisView.swift:21`), which may compete with Smart Scan's own review/clean model.

### App Manager

Evidence: `05-app-manager/05-app-manager__direct__default.png`.

- The App Manager zero state has a clear dock action: "Scan for Apps" (`AppManagerView.swift:72`).
- The list/grid toggle is visual-only unless the user already knows the icons (`AppManagerView.swift:170`). It likely works for experienced Mac users but is weak as first-use guidance.
- The app detail and uninstall sheets are well-scoped as modal flows, but the screenshot package did not force a live app scan to avoid exposing local app inventory.

### Widgets And Menu Bar

Evidence: `08-menu-bar-widgets/08-menu-bar-widgets__direct__customization.png`, `10-menu-bar-surfaces/*`.

- Widget customization is feature-complete but crowded: hero module, OneView mode, active widgets, available widgets, filters, command dock, reset, notifications.
- Copy says "Tap a widget" (`WidgetCustomizationView.swift:148`) in a Mac app. This reads imported from touch UI and weakens platform fit.
- Menu bar popovers are dense and Stats-style. They provide useful detail, but the visual language differs from the main app enough that the product feels like two apps sharing data.
- There is a separate `TabbedSettingsView` with fixed 540x480 layout (`TabbedSettingsView.swift:64`), creating another settings model outside main Preferences.

### Preferences

Evidence: `09-preferences/09-preferences__direct__general.png`, `09-preferences/09-preferences__direct__modules.png`, `09-preferences/09-preferences__direct__permissions.png`, `09-preferences/09-preferences__direct__updates.png`, `09-preferences/09-preferences__direct__about.png`.

- Main Preferences uses a fixed 200pt sidebar (`PreferencesView.swift:140`); labels wrap awkwardly in the captured settings sidebar.
- Preferences include app-specific appearance controls (`PreferencesGeneral.swift:25`) and an explicit theme selector (`PreferencesGeneral.swift:32`). HIG generally expects Mac apps to respect the system appearance unless there is a strong content reason.
- "Luxury Theme System" appears as a settings concept (`PreferencesGeneral.swift:52`) but does not map to a clear user job.
- Debug feature toggles live in General settings in Debug builds (`PreferencesGeneral.swift:102`), which is useful internally but must be clearly excluded from production scope.

## Dashboard Audit

Information hierarchy:

- Primary CTA: Run Smart Scan is visible but not dominant because the dashboard also gives equal weight to system specs and live metrics.
- Status model: "Everything looks stable" is reassuring but vague; it does not state what has or has not been checked.
- Decision support: The dashboard shows many facts, but few are framed as decisions. Live stats, widgets, and hardware specs are adjacent to cleanup recommendations without clear priority.
- Product placement: Widgets and hardware specs are promoted on the dashboard before the user has completed the core scan outcome.
- Data density: The dashboard is dense by Mac standards, but density is applied decoratively rather than as a compact table/dashboard grid.

Designer takeaways:

- The dashboard should be treated as the product's main prioritization problem, not just a visual refresh.
- The redesign needs an explicit rule for when Smart Scan, Storage Hub, App Manager, Widgets, and specs deserve first-screen placement.
- The current visual hierarchy does not distinguish "status," "action," "configuration," and "marketing/product discovery" strongly enough.

## macOS Design Audit

- The app uses `hiddenTitleBar` (`TonicApp.swift:58`) and custom panels throughout. This makes the app feel less like a standard Mac utility and more like a self-contained dashboard shell.
- The app keeps running after the last window closes (`TonicApp.swift:116`), which fits menu bar behavior, but the main window and menu bar modes need clearer conceptual separation.
- Menu commands exist for Command Palette, About, Preferences, Documentation, and Report Issue (`TonicApp.swift:19`). This is a positive Mac-platform anchor.
- App-specific theme controls conflict with platform expectations (`TonicApp.swift:104`, `PreferencesGeneral.swift:25`).
- Touch-language copy appears in Mac surfaces (`WidgetCustomizationView.swift:152`).

## Presentation Audit

Current presentation patterns:

- Large ambient background shapes are present across dashboard, settings, widgets, and permission sheets.
- Glass surfaces and rounded panels are the default container model.
- Many surfaces use icon-plus-card/list repetition.
- The palette reads as dark, purple/blue, and glow-heavy across unrelated jobs.

Risks:

- The visual system can be mistaken for generic AI-dashboard aesthetics because it leans heavily on glassmorphism, gradients, oversized ambience, and repeated card structures.
- The same presentation treatment is used for different product states: diagnosis, configuration, permission, empty state, and debug sandbox.
- Product vocabulary is inconsistent: Smart Scan, System Cleanup, Storage Intelligence Hub, Storage Hub, Disk Space Lens, Space Manager, Menu Bar Widgets, Modules, OneView, Activity, Live Monitoring.

## Severity Findings

| Severity | Finding | Location | Evidence | Impact | Designer Brief Note |
|---|---|---|---|---|---|
| High | Store permission prompt is hard to read and truncates the core message. | `PermissionPromptView`, `ContentView.swift:57`; Store copy from `BuildCapabilities.current.requiresScopeAccess` | `00-app-shell/00-app-shell__store__permission-prompt-full-disk.png` | Users may not understand what access is required or what "Add Scope" does. | Treat access as a product education flow, not just a modal. |
| High | Permission terminology is inconsistent in Store flow: Authorized Locations copy still appears beside "Full Disk Access" labeling. | `UnifiedOnboardingView.swift:349`, `ContentView.swift:408` | `00-app-shell/00-app-shell__store__permission-prompt-full-disk.png`, `01-onboarding/01-onboarding__store__page-06.png` | Users may grant the wrong thing or mistrust the app's privacy model. | Define one distribution-aware vocabulary system. |
| High | Dashboard overloads the first screen with too many product domains. | `DashboardHomeView.swift:37` | `02-dashboard/02-dashboard__direct__default.png` | Primary action and product story compete with specs/widgets/live stats. | Decide what the dashboard is responsible for before visual redesign. |
| High | Settings are split between main Preferences and menu bar tabbed settings. | `PreferencesView.swift:47`, `TabbedSettingsView.swift:40` | `09-preferences/09-preferences__direct__modules.png`, `10-menu-bar-surfaces/10-menu-bar-surfaces__direct__tabbed-widget-settings.png` | Users may not know where widget/module/popup/notification settings belong. | Consolidate the mental model even if implementation remains split. |
| High | Onboarding is long and combines education with permissions, experience mode, and notifications. | `UnifiedOnboardingView.swift:28`, `UnifiedOnboardingView.swift:340` | `01-onboarding/*page-01.png` through `*page-07.png` | First-run users wait too long before reaching product value. | Separate value explanation from required setup decisions. |
| High | Storage Hub presents a full sub-application with tabs, workflows, cart, filters, and paths. | `DiskAnalysisView.swift:11`, `DiskAnalysisView.swift:802` | `04-storage-hub/04-storage-hub__direct__default.png` | The cleanup model can compete with Smart Scan rather than support it. | Clarify whether Storage Hub is advanced inspection, cleanup, or both. |
| High | App-specific appearance controls conflict with expected system appearance behavior. | `TonicApp.swift:104`, `PreferencesGeneral.swift:25` | `09-preferences/09-preferences__direct__general.png` | Users must reason about app theme separately from system theme. | Treat appearance as part of platform fit, not only brand expression. |
| Medium | Settings sidebar is too narrow for labels and descriptions. | `PreferencesView.swift:95`, `PreferencesView.swift:140` | `09-preferences/09-preferences__direct__about.png` | Text wraps awkwardly, reducing polish and scannability. | Reconsider settings IA and navigation density. |
| Medium | Debug/WIP routes are enabled by default in Debug builds. | `NavigationModels.swift:75`, `PreferencesGeneral.swift:102` | `11-debug-wip/11-debug-wip__direct__developer-tools.png`, `11-debug-wip/11-debug-wip__direct__design-sandbox.png` | Handoff can mix intended product with internal experiments. | Keep WIP surfaces labeled and separate from product-critical redesign. |
| Medium | Developer Tools is a visual placeholder without real actions. | `ContentView.swift:436` | `11-debug-wip/11-debug-wip__direct__developer-tools.png` | It is a dead-end-like surface for users if exposed. | Decide whether this is product scope or internal-only. |
| Medium | Command palette has no visible empty/no-results state. | `ContentView.swift:500`, `ContentView.swift:592` | `00-app-shell/00-app-shell__direct__command-palette.png` | Search failure can look like a blank list. | Account for command discovery and failed search states. |
| Medium | Widget customization uses touch vocabulary. | `WidgetCustomizationView.swift:148` | `08-menu-bar-widgets/08-menu-bar-widgets__direct__customization.png` | Mac users expect click/drag/configure language. | Align copy with pointer-first Mac interactions. |
| Medium | Hardware details and storage values expose machine-specific data in ordinary dashboard placement. | `DashboardHomeView.swift:69`, `DiskAnalysisView.swift:39` | `02-dashboard/02-dashboard__direct__default.png`, `04-storage-hub/04-storage-hub__direct__default.png` | Handoff/review contexts can leak local machine information; users may also see specs before action relevance. | Define which machine facts are useful, private, or secondary. |
| Medium | Visual ambience competes with content across utilitarian surfaces. | `ContentView.swift:33`, `DashboardHomeView.swift:40`, `PreferencesView.swift:54` | Dashboard and Preferences captures | Dense operational content becomes lower contrast behind decorative forms. | Treat decoration as subordinate to repeated-use utility workflows. |
| Medium | Menu bar popovers and main app feel like separate product families. | `CPUPopoverView`, `MemoryPopoverView`, `WidgetCustomizationView` | `10-menu-bar-surfaces/*popover.png`, `08-menu-bar-widgets/*customization.png` | Widget configuration and widget consumption have weak visual/IA continuity. | Decide the relationship between main app and menu bar experience. |
| Medium | App Manager first-run state depends on scanning but list/detail states were not safely capturable without local app inventory. | `AppManagerView.swift:72` | `05-app-manager/05-app-manager__direct__default.png` | Designer lacks populated app-list evidence unless a sanitized fixture is created. | Use sanitized app inventory fixtures for the next handoff round. |
| Low | Main shell offscreen capture shows sidebar rendering blank. | `ContentView.swift:37` | `00-app-shell/00-app-shell__direct__main-window-dashboard.png` | Capture artifact, but it exposes fragility in custom shell rendering under nonstandard hosting. | Use direct screen captures when OS permission is available. |
| Low | Clock popover crashed in the renderer; clock detail was captured instead. | `ClockPopoverView` | `10-menu-bar-surfaces/10-menu-bar-surfaces__direct__clock-detail.png` | The package lacks the exact clock popover state. | Treat clock surface coverage as partial. |
| Low | Several icon-only controls rely on interpretation even when accessibility labels exist. | `DashboardHomeView.swift:104`, `AppManagerView.swift:170` | Dashboard/App Manager captures | Visual meaning may be unclear for first-time users. | Audit visible affordances separately from VoiceOver labels. |
| Low | Repeated cards and chips make screens scan similarly. | Multiple design-system components | Most captures | Users may struggle to distinguish setup, status, action, and settings surfaces. | Establish stronger state/category differentiation. |
| Low | `themePreference` default remains `"dark"` in registered defaults. | `TonicApp.swift:146` | Preferences captures | System preference can be overridden unexpectedly depending on appearance preference storage. | Clarify default appearance behavior. |

## Navigation Reachability

- Total primary navigation destinations found: 10.
- Settings sections found: 5.
- Menu bar/settings surfaces captured: 13 direct surface types, with Store duplicates.
- Deep-linkable URL screens found: 0.
- Internal notification-reachable screens: Settings Modules, module detail, App Manager from Storage Hub, Widget customization.
- Widget/menu-bar-reachable surfaces: CPU, Memory, Disk, Network, Battery, Clock, Bluetooth, Weather, Sensors, GPU, OneView, tabbed settings.

## Positive Findings

- The app has broad state coverage: permission states, empty states, setup states, module settings, and menu bar popovers exist.
- Smart Scan has the strongest product narrative and clearer recovery model than the surrounding modules.
- Preferences sections are modularized, which helps future IA work.
- Menu commands for Command Palette, Preferences, About, Documentation, and Report Issue are Mac-appropriate anchors.
- Direct and Store builds already have capability switches for access behavior (`BuildCapabilities`), giving the redesign a real technical basis for distribution-specific UX.

## Capture And Redaction Notes

- OS `screencapture` was unavailable in this session, so screenshots were generated through an offscreen SwiftUI renderer linked against the app debug modules.
- No screenshots intentionally reveal usernames, serial numbers, or personal file paths. Storage and dashboard screens may show hardware/storage values because those are part of the current product surface.
- The package includes both Direct and Store screenshots. Store captures are not all visually different; they are retained so the designer can compare distribution-specific copy and behavior.
- `HandoffRenderer.swift` is included in the handoff folder as the capture utility. It is not app source.
