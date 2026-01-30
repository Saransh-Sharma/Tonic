# fn-5-v8r.5 Network and Disk readers with Stats Master parity

## Description
Implement NetworkReader and DiskReader conforming to WidgetReader protocol. Match Stats Master's functionality including interface-specific stats, WiFi details, and volume information.

## Implementation

Create `Tonic/Tonic/Services/WidgetReader/NetworkReader.swift`:
- `NET_RT_IFLIST2` sysctl for interface stats
- CoreWLAN for WiFi SSID
- Upload/download bandwidth

Create `Tonic/Tonic/Services/WidgetReader/DiskReader.swift`:
- IOKit block storage drivers
- Per-volume usage statistics
- Read/write speeds

## Acceptance
- [x] NetworkReader returns bandwidth + connection type
- [x] DiskReader returns per-volume usage
- [x] Both async with proper error handling
- [x] 2s preferred interval

## Done summary
Implemented NetworkReader and DiskReader with Stats Master feature parity.

## Evidence
- Commits:
- Tests:
- PRs:

## References
- Stats Master: `stats-master/Modules/Net/readers.swift:106-200`, `Modules/Disk/readers.swift`
- Tonic current: `Tonic/Tonic/Services/WidgetDataManager.swift:617-803`
