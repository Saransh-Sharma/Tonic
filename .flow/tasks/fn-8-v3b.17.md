# fn-8-v3b.17 Update NetworkPopoverView with DNS and WiFi details

## Description
Update `NetworkPopoverView.swift` to add DNS servers field and extended WiFi tooltip (RSSI, noise, band, width).

**Size:** S

**Files:**
- `Tonic/Tonic/MenuBarWidgets/Popovers/NetworkPopoverView.swift` (~547 lines)

## Approach

1. Add DNS servers field:
   - Show in interface section
   - Expandable with toggle button
   - Read from `/etc/resolv.conf` or `res_ninit()`
   - Format: comma-separated list

2. Add extended WiFi tooltip:
   - RSSI (signal strength in dBm)
   - Noise level (dBm)
   - Channel number
   - Band (2.4 GHz / 5 GHz / 6 GHz)
   - Channel width (20/40/80/160 MHz)

3. Add configurable process count for network processes:
   - From `NetworkModuleSettings.topProcessCount`
   - Default to 8, range 3-20

## Key Context

WiFi data comes from `CWInterface` (CoreWLAN framework):
- `rssi()` - signal strength
- `noise()` - noise level
- `channel()` - channel info with band and width
- `ssid()` - network name

DNS servers from system configuration:
- `SCDynamicStoreCopyConsoleUser` or read `/etc/resolv.conf`
- Fallback to "Unknown" if unavailable

NetworkPopoverView already has comprehensive stats at ~547 lines. Just need to add these specific fields.

Reference: Stats Master Network module at `stats-master/Modules/Net/popup.swift`.
## Acceptance
- [ ] DNS servers field shows in interface section
- [ ] DNS section expands/collapses via toggle
- [ ] Extended WiFi tooltip shows RSSI, noise, channel, band, width
- [ ] WiFi tooltip appears on hover over WiFi info
- [ ] Top network processes count is configurable
- [ ] Process count setting persists in NetworkModuleSettings
- [ ] Missing DNS/WiFi data shows "Unknown" fallback
## Done summary
- Task completed
## Evidence
- Commits:
- Tests:
- PRs: