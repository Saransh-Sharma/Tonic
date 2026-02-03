# fn-8-v3b.1 Update PopoverConstants with Stats Master measurements

## Description
Update `PopoverConstants.swift` to match exact Stats Master measurements for layout parity.

**Size:** S

**Files:**
- `Tonic/Tonic/MenuBarWidgets/Popovers/PopoverConstants.swift`

## Approach

Follow Stats Master baseline measurements:
- Width: 280px (already set, verify)
- Dashboard height: 90px
- Header row height: 22px
- Detail row height: 16px
- Process row height: 22px
- Fonts: 9pt (small), 11pt (medium), 13pt (large)
- Margins: 10px (currently using `DesignTokens.Spacing.sm` which is 16px)

Add new constants:
```swift
public struct FontSizes {
    public static let small: CGFloat = 9
    public static let medium: CGFloat = 11
    public static let large: CGFloat = 13
}

public struct StatsMasterSpacing {
    public static let margins: CGFloat = 10
    public static let separatorHeight: CGFloat = 22
}
```

## Key Context

The `PopoverConstants` file currently uses `DesignTokens.Spacing.sm` (16pt) for margins. Stats Master uses 10px margins. This affects actual content width calculation.

Current width at line ~20: `public static let width: CGFloat = 280` - verify this is correct.
## Acceptance
- [ ] Font sizes constant added: 9pt, 11pt, 13pt
- [ ] StatsMasterSpacing added with 10px margins
- [ ] Section heights defined: dashboard 90px, header 22px, detail 16px, process 22px
- [ ] All popovers reference these constants (not hardcoded values)
- [ ] Popover width verified as 280px
## Done summary
- Task completed
## Evidence
- Commits:
- Tests:
- PRs: