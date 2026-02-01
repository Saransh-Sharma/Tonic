# fn-6-i4g.35 Per-Module Settings

## Description
TBD

## Acceptance
- [ ] TBD

## Done summary
Implemented per-module settings for widget customization, adding Stats Master-style module-specific options within Tonic's in-app WidgetCustomizationView. Added ModuleSettings type with configurations for CPU (E/P cores, frequency, temperature, load average), Disk (volume selector, SMART status), Network (interface selector, public IP, WiFi details), Memory (cache, wired display), Sensors (fan speeds, temperature unit), and Battery (optimized charging, cycle count). Updated migration to version 3 and added setWidgetModuleSettings to WidgetPreferences.
## Evidence
- Commits: ae06dec93b92b3399a215f2df0e7a00018a7d1e9
- Tests: xcodebuild build verification
- PRs: