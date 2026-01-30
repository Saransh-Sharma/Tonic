# fn-4-as7.18 Improve Card component with 3 variants

## Description
TBD

## Acceptance
# Improve Card component with 3 variants

Create 3 Card variants and fix color styling.

## Variants
1. Elevated - Shadow for depth (primary content)
2. Flat - No shadow, border only (secondary content)
3. Inset - Inset border for grouped content

## Changes Required
- Fix existing Card color styling
- Integrate with DesignTokens properly
- Fix dark mode issues
- Fix light mode issues

## Acceptance
- [ ] Three Card variants exist
- [ ] Cards use semantic DesignTokens colors
- [ ] Cards work correctly in light mode
- [ ] Cards work correctly in dark mode
- [ ] No hardcoded RGB colors in Card

## Deps: fn-4-as7.1


## Done summary
Successfully improved the Card component with three semantic variants (Elevated, Flat, Inset) and fixed color styling to use DesignTokens for proper light/dark mode support. The component now works correctly in both light and dark modes without any hardcoded colors.
## Evidence
- Commits: 630e8160155dd9d949c336da263d4dabe69a3633
- Tests: xcodebuild -scheme Tonic -configuration Debug build
- PRs: