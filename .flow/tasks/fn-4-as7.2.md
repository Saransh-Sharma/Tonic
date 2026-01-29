# fn-4-as7.2 Create MetricRow shared component

## Description
TBD

## Acceptance
# Create MetricRow shared component

Create a reusable MetricRow component for displaying metrics with icon, title, value, and optional sparkline.

## Specs
- HStack: Icon | Title+Value (VStack) | Sparkline (optional)
- Fixed height: 44pt
- Monospaced number alignment
- Title: Typography.subhead, Value: Typography.body

## Acceptance
- [ ] Component exists in DesignComponents or separate file
- [ ] Fixed height 44pt
- [ ] Monospaced number alignment
- [ ] Optional sparkline rendering

## Deps: fn-4-as7.1


## Done summary
Added MetricRow shared component to DesignComponents.swift with HStack layout (Icon | Title+Value VStack | optional Sparkline), fixed 44pt height, monospaced number alignment using Typography.monoBody, and SwiftUI Previews for visual testing.
## Evidence
- Commits: 96833935b9667566d55b130e34dbe836bfe40a04
- Tests: xcodebuild -scheme Tonic -configuration Debug build
- PRs: