# fn-5-v8r.4 CPU and Memory readers with Stats Master parity

## Description
Implement CPUReader and MemoryReader conforming to WidgetReader protocol. Match Stats Master's data collection including per-core CPU, P-core/E-core distinction, and memory pressure zones.

## Implementation

Create `Tonic/Tonic/Services/WidgetReader/CPUReader.swift`:
- `host_processor_info()` for total usage
- Per-core breakdown
- P-core/E-core for Apple Silicon

Create `Tonic/Tonic/Services/WidgetReader/MemoryReader.swift`:
- `vm_statistics64` for usage
- Memory pressure levels (normal/warning/critical)
- Compressed/swap memory

Both follow existing `WidgetDataManager.swift` patterns but conform to `WidgetReader`.

## Acceptance
- [ ] CPUReader returns total + per-core usage
- [ ] MemoryReader returns usage + pressure level
- [ ] Both async with proper error handling
- [ ] 2s preferred interval

## Done summary
Implemented CPUReader and MemoryReader with Stats Master feature parity.

## References
- Stats Master: `stats-master/Modules/CPU/readers.swift:15-150`
- Tonic current: `Tonic/Tonic/Services/WidgetDataManager.swift:408-564`
