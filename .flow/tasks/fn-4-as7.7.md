# fn-4-as7.7 Redesign Dashboard with native layouts

## Description
TBD

## Acceptance
# Redesign Dashboard with native layouts

Redesign DashboardView to use native macOS layouts instead of cards.

## Layout Requirements
- Left column: Health ring, Primary CTA (Smart Scan), Secondary CTAs, Real-time stats
- Right column: Recommendations list (grouped), Recent Activity (collapsed)
- Use MetricRow for real-time stats
- Only ONE primary CTA
- No cards - use native List/Form

## Changes Required
- Replace Card components with native List/Form
- Use MetricRow for CPU/Memory/Disk stats
- Add health score explanation (tooltip/expandable)
- Collapse Recent Activity by default

## Acceptance
- [ ] No Card components used
- [ ] MetricRow used for stats
- [ ] Only one primary CTA visible
- [ ] Recommendations use native List
- [ ] Health score has explanation
- [ ] Light/dark mode both work

## References
- File: Tonic/Tonic/Views/DashboardView.swift
- Spec: Section "Screen-by-Screen → Dashboard" in epic

## Deps: fn-4-as7.2, fn-4-as7.6


## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
