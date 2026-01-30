# fn-4-as7.8 Create unified Maintenance view with tabs

## Description
TBD

## Acceptance
# Create unified Maintenance view with tabs

Combine Smart Scan and Deep Clean into a single Maintenance view with tabs.

## Structure
- Tab 1: Scan (multi-stage progress, cancel, summary)
- Tab 2: Clean (grouped categories, expandable previews, total reclaim)
- Use Picker/SegmentedControl for tab switching

## Changes Required
- Merge SmartScanView and DeepCleanView logic
- Add tab control at top
- Use PreferenceList for clean categories
- Add expandable previews for file lists
- Preserve Collector Bin functionality

## Acceptance
- [ ] Single view with two tabs
- [ ] Scan tab shows stage progress
- [ ] Clean tab shows grouped categories
- [ ] Categories expand to show files
- [ ] Total reclaim always visible
- [ ] Collector Bin preserved

## References
- File: Tonic/Tonic/Views/SmartScanView.swift
- File: Tonic/Tonic/Services/DeepCleanEngine.swift
- Spec: Section "Screen-by-Screen → Maintenance" in epic

## Deps: fn-4-as7.3, fn-4-as7.6


## Done summary
- Task completed
## Evidence
- Commits:
- Tests:
- PRs: