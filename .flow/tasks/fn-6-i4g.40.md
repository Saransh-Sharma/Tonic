# fn-6-i4g.40 Bluetooth Widget Popover Parity

## Description
TBD

## Acceptance
- [ ] TBD

## Done summary
Implemented Stats Master-style Bluetooth popover with connection history, device list showing battery levels and signal strength. Added bluetooth history tracking in WidgetDataManager and updated BluetoothStatusItem to use the new popover.
## Evidence
- Commits: c02f932814c56cb76615bdc315e1d60408455891
- Tests: xcodebuild -scheme Tonic -configuration Debug build
- PRs: