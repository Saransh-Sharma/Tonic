# fn-6-i4g.6 Network Enhanced Reader

## Description
Implement Stats Master's enhanced network readers including WiFi details, public IP, and connectivity testing.

**Size:** M

**Files:**
- `Tonic/Tonic/Services/WidgetDataManager.swift` (modify)
- `Tonic/Tonic/Models/NetworkDetails.swift` (new - from Task 2)
- `Tonic/Tonic/Models/SystemEnums.swift` (modify - extend NetworkData)

Extend network data reading to include:
1. **WiFi details** - SSID, RSSI, channel, security type, BSSID
2. **Public IP** tracking with change detection
3. **Connectivity test** - ICMP ping with latency and jitter
4. **Top processes by network** usage

Extend `NetworkData` struct:
```swift
public struct NetworkData: Sendable {
    let uploadBytesPerSecond: Double
    let downloadBytesPerSecond: Double
    let isConnected: Bool
    let connectionType: ConnectionType
    let ssid: String?
    let wifiDetails: WiFiDetails?  // NEW
    let publicIP: PublicIPInfo?    // NEW
    let connectivity: ConnectivityInfo?  // NEW
    let topProcesses: [ProcessUsage]?    // NEW
}
```

## Approach

1. Study Stats Master's network readers at `stats-master/Modules/Net/readers.swift`
2. **WiFi details**: Use `CWWiFiClient` from CoreWLAN framework
3. **Public IP**: Query external API (Stats Master uses specific API, verify and adapt)
4. **Connectivity**: Implement ICMP ping via `CFSocket` or `NWConnection`
5. **Process network**: Parse `nettop -P -L 1 -n -k time,interface,state,rx_dupe,...`
6. Cache public IP with 5-minute refresh interval
7. Detect IP changes and trigger notification if enabled

## Key Context

CoreWLAN requires entitlement `com.apple.security.network.client` — ensure this is in entitlements file.

Public IP API: Stats Master uses external services. Consider using multiple fallback services (e.g., ipify.org, icanhazip.com).

Ping implementation: Stats Master uses raw sockets. For modern macOS, consider `NWConnection` or simple `NWPathMonitor` for connectivity status.

Reference: Existing network code at `WidgetDataManager.swift:760-802`.
## Acceptance
- [ ] NetworkData extended with wifiDetails
- [ ] NetworkData extended with publicIP
- [ ] NetworkData extended with connectivity info
- [ ] NetworkData extended with topProcesses
- [ ] WiFi reader implemented via CWWiFiClient
- [ ] SSID, RSSI, channel, security correctly captured
- [ ] Public IP reader implemented with fallback APIs
- [ ] IP change detection works
- [ ] ICMP ping implementation for connectivity
- [ ] Latency and jitter calculated
- [ ] Process network usage via nettop
- [ ] All new readers follow Reader protocol
## Done summary
Implemented Stats Master's enhanced network readers including WiFi details (SSID, RSSI, channel, security, BSSID), public IP tracking with 5-minute caching, ICMP ping connectivity testing with latency/jitter calculation, and top network processes via nettop/lsof.
## Evidence
- Commits: 677833c
- Tests: xcodebuild -scheme Tonic -configuration Debug build
- PRs: