# fn-4-as7.11 Redesign Activity (Live Monitoring) with MetricRow list

## Description
TBD

## Acceptance
# Redesign Activity (Live Monitoring) with MetricRow list

Redesign SystemStatusDashboard to use a vertical list of MetricRows instead of circular gauges.

## Layout Requirements
- Vertical list of MetricRow components
- Metrics: CPU, Memory, Disk, Network, GPU, Battery
- Real-time updates ≤ 2s
- No circular gauges
- No cards

## Changes Required
- Replace circular gauges with MetricRow
- Keep sparkline data for each metric
- Update every 2 seconds max
- Use List (not LazyVStack) for performance

## Acceptance
- [ ] All metrics use MetricRow
- [ ] No circular gauge components
- [ ] Updates every 2 seconds or less
- [ ] Sparklines render correctly
- [ ] List scrolls smoothly
- [ ] Light/dark mode both work

## References
- File: Tonic/Tonic/Views/SystemStatusDashboard.swift
- Spec: Section "Screen-by-Screen → Activity" in epic

## Deps: fn-4-as7.2, fn-4-as7.6


## Done summary
Redesigned SystemStatusDashboard to use MetricRow components in a vertical list layout instead of circular gauges. Implemented real-time monitoring with configurable update intervals, sparkline graphs for key metrics, and semantic color coding for health status indicators across CPU, Memory, Disk, Network, and Battery metrics.
## Evidence
- Commits: 9f6cf702955da78276712a18ac6b85ec0aca3f99
- Tests: xcodebuild -scheme Tonic -configuration Debug build
- PRs: