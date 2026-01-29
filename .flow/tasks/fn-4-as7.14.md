# fn-4-as7.14 Accessibility audit and fixes

## Description
TBD

## Acceptance
# Accessibility audit and fixes

Audit all redesigned screens for accessibility and add missing labels.

## Requirements
- Every control has accessibilityLabel
- Keyboard navigation works for all lists
- High-contrast mode verified
- VoiceOver tested for: Sidebar, Tables, Scan flow

## Changes Required
- Add .accessibilityLabel() to all controls
- Ensure list items are focusable
- Verify contrast ratios
- Test with VoiceOver

## Acceptance
- [ ] All buttons have accessibility labels
- [ ] All list items are keyboard navigable
- [ ] High-contrast mode works
- [ ] VoiceOver announces: Sidebar, Tables, Scan flow
- [ ] Focus order is logical
- [ ] No unlabeled icons

## References
- Spec: Section "Accessibility Requirements" in epic

## Deps: fn-4-as7.7,fn-4-as7.8,fn-4-as7.9,fn-4-as7.10,fn-4-as7.11,fn-4-as7.12,fn-4-as7.13


## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
