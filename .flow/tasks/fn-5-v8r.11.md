# fn-5-v8r.11 Enhanced Network and Speed widgets

## Description
Enhance existing Network widget to match Stats Master's Speed widget with dual-direction chart, connection type, and SSID display.

## Implementation

Modify existing Network widget to add:
- Network chart mode (dual-direction I/O)
- Display mode options (one/two row)
- Connection type indicator
- SSID for WiFi networks

## Acceptance
- [ ] Network chart shows upload/download separately
- [ ] Connection type displays correctly
- [ ] SSID shows for WiFi
- [ ] Backward compatible with existing widget

## Done summary
Enhanced Network widget with Speed widget features from Stats Master.

## References
- Stats Master: `stats-master/Kit/Widgets/Speed.swift`
- Tonic current: `Tonic/Tonic/MenuBarWidgets/Network*WidgetView.swift`
