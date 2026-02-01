# fn-6-i4g.41 Visual Polish and Spacing

## Description
TBD

## Acceptance
- [ ] TBD

## Done summary
Applied visual polish and consistent spacing across all widget popovers. Enhanced PopoverConstants with DesignTokens 8-point grid integration, added reusable components (PopoverSectionHeader, IndicatorDot, IconLabelRow, ProcessRow, EmptyStateView, MetricCard), and standardized spacing/typography across CPU, GPU, Battery, Disk, Sensors, and Bluetooth popovers.
## Evidence
- Commits: 
- Tests: xcodebuild -scheme Tonic -configuration Debug build -destination 'platform=macOS'
- PRs: