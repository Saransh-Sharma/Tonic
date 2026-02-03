# Fix Critical Build Errors

## Description
Fix two critical build errors that prevent the project from compiling:
1. **PlaceholderDetailView** - Referenced in 3 StatusItem files but doesn't exist
2. **SensorsReader syntax error** - Memory binding issue in SMCReader.swift

**Size:** S

**Files:**
- `Tonic/Tonic/MenuBarWidgets/ChartStatusItems/SpeedStatusItem.swift` (references PlaceholderDetailView)
- `Tonic/Tonic/MenuBarWidgets/ChartStatusItems/TachometerStatusItem.swift` (references PlaceholderDetailView)
- `Tonic/Tonic/MenuBarWidgets/ChartStatusItems/PieChartStatusItem.swift` (references PlaceholderDetailView)
- `Tonic/Tonic/Services/SMCReader.swift` (potential syntax error around lines 112-117)

## Approach

### PlaceholderDetailView Fix
Two options:
1. Create a simple placeholder detail view
2. Replace with inline detail views (follow pattern from other StatusItem files)

Check existing StatusItem implementations (e.g., `MiniChartStatusItem.swift`) for the correct pattern.

### SensorsReader Fix
Examine `SMCReader.swift` lines 112-117 for memory binding issues. The audit mentioned a syntax error but initial exploration didn't find it — verify the actual issue.

## Key Context

**Production Architecture**: WidgetDataManager with inline methods is the working system.

**Dead Code Nearby**: Services/WidgetReader/ directory contains unused reader implementations — do not reference these.

**Pattern Reference**: Check other ChartStatusItems like `LineChartStatusItem.swift` or `BarChartStatusItem.swift` for correct detail view implementation.

## Acceptance
- [ ] PlaceholderDetailView references resolved (created view or inline implementation)
- [ ] SpeedStatusItem.swift builds without errors
- [ ] TachometerStatusItem.swift builds without errors
- [ ] PieChartStatusItem.swift builds without errors
- [ ] SMCReader.swift syntax error fixed (if present)
- [ ] Project builds successfully (xcodebuild -scheme Tonic -configuration Debug build)
- [ ] All three chart status items display correctly in menu bar

## Done summary
- Task completed
## Evidence
- Commits:
- Tests:
- PRs: