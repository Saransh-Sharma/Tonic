# fn-5-v8r.9 Stack/Sensors and Tachometer widgets implementation

## Description
Implement Stack (Sensors) widget for multiple related values in one widget, and Tachometer for circular gauge display.

## Implementation

Create `StackWidgetView.swift`:
- Vertical stack of multiple sensor values
- Temperature, fan speeds in one widget
- Configurable sensor selection

Create `TachometerWidgetView.swift`:
- Circular gauge with needle
- Arc-based value indicator
- RPM or percentage display

## Acceptance
- [ ] Stack widget displays multiple sensors
- [ ] Tachometer renders circular gauge correctly
- [ ] Tonic design tokens applied

## Done summary
Implemented Stack/Sensors and Tachometer widgets.

## References
- Stats Master: `stats-master/Kit/Widgets/Stack.swift`, `Tachometer.swift`
