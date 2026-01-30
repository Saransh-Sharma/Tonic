# fn-4-as7.22 Implement feedback and crash reporting

## Description
TBD

## Acceptance
# Implement feedback and crash reporting

Add ways for users to report issues and automatic crash reporting.

## Specs
- "Give Feedback" button in Settings/Help menu
- Per-screen "Report Issue" option
- Crash reporting integration

## Acceptance
- [ ] Feedback button in Settings
- [ ] Report Issue on each screen
- [ ] Crash reporting integrated
- [ ] All feedback mechanisms work

## Deps: fn-4-as7.6


## Done summary
Implemented feedback and crash reporting mechanisms for Tonic. Added FeedbackService with support for multiple feedback types (bug, feature request, performance, crash, general), crash reporting integration with uncaught exception handler, GitHub issue integration with pre-filled templates, and a new Settings > Help section with feedback form and support links.
## Evidence
- Commits: 8fef48a0eb2cf9cd2fc2a50c7f52167f77c94d0e
- Tests: xcodebuild -scheme Tonic -configuration Debug build
- PRs: