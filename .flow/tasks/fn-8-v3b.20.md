# fn-8-v3b.20 Update CLAUDE.md with popover architecture documentation

## Description
Update CLAUDE.md and Design.md with new popover architecture patterns, fan control documentation, and new component references.

**Size:** S

**Files:**
- `CLAUDE.md`
- `Tonic/docs/Design.md` (if exists, or create)
- `README.md`

## Approach

1. Update CLAUDE.md:
   - Add new components to Key Components section
   - Document fan control architecture and SMC integration
   - Add pressure gauge documentation
   - Update settings architecture section
   - Document popover constants and measurements

2. Update Design.md:
   - Add new gauge types (PressureGaugeView, HalfCircleGaugeView)
   - Document new container components (PerGpuContainer, PerDiskContainer)
   - Add chart components (DualLineChartView, CombinedCPUChartView)
   - Document FanControlView with sliders and modes

3. Update README.md:
   - Enhance menu bar widgets section with new features
   - Add fan control capabilities
   - Mention memory pressure gauge
   - Document multi-GPU monitoring
   - Add battery electrical metrics

## Key Context

Documentation gaps identified by docs-gap-scout:
- Popover architecture patterns
- Fan control additions
- New data properties in WidgetDataManager
- Settings UI changes

Follow existing documentation format and style.
## Acceptance
- [ ] CLAUDE.md updated with new popover patterns
- [ ] CLAUDE.md documents fan control architecture
- [ ] CLAUDE.md lists new components with file locations
- [ ] Design.md updated with new gauge types
- [ ] Design.md updated with new container components
- [ ] README.md enhanced with new feature descriptions
- [ ] All code references include file paths and line numbers
- [ ] Documentation follows existing format and style
## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
