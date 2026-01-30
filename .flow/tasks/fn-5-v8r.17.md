# fn-5-v8r.17 Performance validation and optimization

## Description
Validate CPU/memory usage within ±5% of Stats Master. Profile with Instruments, identify and fix bottlenecks. Ensure no memory leaks across refresh cycles.

## Implementation

1. **Baseline Measurement**:
   - Profile Stats Master with equivalent widget set
   - Record idle CPU, active CPU, memory baseline

2. **Tonic Measurement**:
   - Profile Tonic with same widgets
   - Compare against baseline

3. **Optimization Targets** (if needed):
   - Eliminate per-widget timers
   - Reduce IOKit main-thread blocking
   - Fix memory leaks in observers/streams

4. **Validation**:
   - Instruments Time Profiler for CPU
   - Allocations for leak detection
   - 30-minute idle test
   - 1-hour refresh cycle test

## Acceptance
- [ ] Idle CPU within ±5% of Stats Master
- [ ] Memory stable over 60 refresh cycles
- [ ] No memory leaks detected
- - [ ] Single unified scheduler (no per-widget timers)
- [ ] Cold start widget readiness matches Stats Master

## Done summary
Validated and optimized performance to match Stats Master baseline.

## References
- Risk analysis: flow-gap-analyst output
- Tonic current: `Tonic/Tonic/Services/WidgetDataManager.swift`
