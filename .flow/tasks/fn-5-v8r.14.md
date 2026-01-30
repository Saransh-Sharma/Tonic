# fn-5-v8r.14 WidgetConfigurationSheet per-widget settings

## Description
Create per-widget configuration sheet following Stats Master's pattern. Exposes all widget-specific options: display mode, colors, labels, alignment, history size, refresh interval.

## Implementation

Create `Tonic/Tonic/Views/WidgetConfigurationSheet.swift`:

```swift
struct WidgetConfigurationSheet: View {
    @Bindable var config: WidgetConfig

    var body: some View {
        Form {
            DisplayModePicker()
            ColorSchemePicker()  // 20+ colors from Stats Master
            Toggle("Show Label", isOn: $config.showLabel)
            AlignmentPicker()
            if config.supportsHistory {
                HistorySizePicker()  // 30-120
            }
            RefreshIntervalPicker()  // 1-60s
        }
    }
}
```

## Acceptance
- [ ] All config options from Stats Master available
- [ ] Changes save immediately to WidgetStore
- [ ] Defaults match Stats Master
- [ ] Tonic design tokens applied

## Done summary
Implemented per-widget configuration sheet with Stats Master feature parity.

## References
- Stats Master: `stats-master/Kit/module/settings.swift:196-242`
