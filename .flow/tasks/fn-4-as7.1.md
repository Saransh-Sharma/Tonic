# fn-4-as7.1 Update DesignTokens with 8-point grid spacing and semantic colors

## Description
# Update DesignTokens with 8-point grid spacing and semantic colors

Update DesignTokens.swift to follow the 8-point grid system, add semantic colors, and add custom semantic colors.

## Changes Required

### Spacing
Add explicit 8-point grid values (xxxs=4, xxs=8, xs=12, sm=16, md=24, lg=32, xl=40, xxl=48).

### Semantic Colors (System)
Use NSColor sources for system semantic colors.

### Custom Semantic Colors (NEW)
- success: Color("SuccessGreen") - WCAG AA compliant
- warning: Color("WarningOrange") - WCAG AA compliant
- info: Color("InfoBlue") - WCAG AA compliant

### Typography
Ensure sizes follow: h1=32, h2=24, body=16, subhead=14, caption=12.

## Acceptance
- [ ] All spacing values are multiples of 8 (except xxxs=4)
- [ ] No hardcoded RGB colors in DesignTokens
- [ ] Semantic colors use NSColor sources
- [ ] Custom semantic colors added (success, warning, info)
- [ ] Typography scale matches spec

## References
- File: Tonic/Tonic/Design/DesignTokens.swift
## Acceptance
# Update DesignTokens with 8-point grid spacing and semantic colors

Update DesignTokens.swift to follow the 8-point grid system and unify color usage with semantic colors only.

## Changes Required
- Spacing: xxxs=4, xxs=8, xs=12, sm=16, md=24, lg=32, xl=40, xxl=48
- Colors: Replace custom RGB with NSColor.windowBackgroundColor, .controlBackgroundColor
- Typography: h1=32, h2=24, body=16, subhead=14, caption=12

## Acceptance
- [ ] All spacing values are multiples of 8 (except xxxs=4)
- [ ] No hardcoded RGB colors in DesignTokens
- [ ] Semantic colors use NSColor sources
- [ ] Typography scale matches spec

## References
- File: Tonic/Tonic/Design/DesignTokens.swift


## Done summary
Updated DesignTokens.swift with 8-point grid spacing system and semantic colors using NSColor sources for light/dark mode parity. Added WCAG AA compliant custom colors (success, warning, info) via Asset Catalog, updated typography scale to match spec (h1=32, h2=24, body=16, subhead=14, caption=12), and included backward-compatible deprecated aliases for existing code.
## Evidence
- Commits: 3e5b99e4ac25dd9cbdaf963dd75a747ceb7a30c2
- Tests: xcodebuild -scheme Tonic -configuration Debug build
- PRs: