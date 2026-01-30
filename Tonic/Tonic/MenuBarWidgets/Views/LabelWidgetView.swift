//
//  LabelWidgetView.swift
//  Tonic
//
//  Label, State, and Text widget views
//  Matches Stats Master's Label, State, and Text widgets
//  Task ID: fn-5-v8r.10
//

import SwiftUI

// MARK: - Label Widget

/// Config for label widget display
public struct LabelConfig: Sendable, Equatable {
    public let text: String
    public let fontSize: CGFloat
    public let fontWeight: Font.Weight
    public let textColor: Color
    public let backgroundColor: Color?

    public init(
        text: String,
        fontSize: CGFloat = 11,
        fontWeight: Font.Weight = .medium,
        textColor: Color = .primary,
        backgroundColor: Color? = nil
    ) {
        self.text = text
        self.fontSize = max(8, fontSize)
        self.fontWeight = fontWeight
        self.textColor = textColor
        self.backgroundColor = backgroundColor
    }
}

/// Label widget for displaying custom text
public struct LabelWidgetView: View {
    let config: LabelConfig

    public init(config: LabelConfig) {
        self.config = config
    }

    public init(text: String, fontSize: CGFloat = 11, fontWeight: Font.Weight = .medium) {
        self.config = LabelConfig(text: text, fontSize: fontSize, fontWeight: fontWeight)
    }

    public var body: some View {
        Text(config.text)
            .font(.system(size: config.fontSize, weight: config.fontWeight))
            .foregroundColor(config.textColor)
            .padding(.horizontal, config.backgroundColor != nil ? 6 : 4)
            .padding(.vertical, config.backgroundColor != nil ? 2 : 0)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(config.backgroundColor ?? Color.clear)
            )
            .frame(height: 22)
    }
}

// MARK: - State Widget

/// Config for state widget display
public struct StateConfig: Sendable, Equatable {
    public let isOn: Bool
    public let onColor: Color
    public let offColor: Color
    public let showLabel: Bool
    public let label: String
    public let style: StateStyle

    public init(
        isOn: Bool = true,
        onColor: Color = .green,
        offColor: Color = .secondary,
        showLabel: Bool = false,
        label: String = "",
        style: StateStyle = .dot
    ) {
        self.isOn = isOn
        self.onColor = onColor
        self.offColor = offColor
        self.showLabel = showLabel
        self.label = label
        self.style = style
    }
}

/// Visual style for state indicator
public enum StateStyle: String, Sendable, Equatable {
    case dot
    case pill
    case indicator
    case toggle
}

/// State widget for binary on/off indication
public struct StateWidgetView: View {
    let config: StateConfig

    public init(config: StateConfig) {
        self.config = config
    }

    public init(isOn: Bool, style: StateStyle = .dot) {
        self.config = StateConfig(isOn: isOn, style: style)
    }

    public var body: some View {
        HStack(spacing: 6) {
            stateIndicator

            if config.showLabel && !config.label.isEmpty {
                Text(config.label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var stateIndicator: some View {
        let color = config.isOn ? config.onColor : config.offColor

        switch config.style {
        case .dot:
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

        case .pill:
            Text(config.isOn ? "ON" : "OFF")
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(color)
                )

        case .indicator:
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.3))
                .frame(width: 24, height: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: config.isOn ? 16 : 8, height: 6)
                        .animation(.easeInOut(duration: 0.2), value: config.isOn)
                )

        case .toggle:
            ZStack(alignment: config.isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.3))
                    .frame(width: 32, height: 18)

                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
                    .padding(2)
            }
            .animation(.easeInOut(duration: 0.2), value: config.isOn)
        }
    }
}

// MARK: - Text Widget

/// Config for text widget display
public struct TextWidgetConfig: Sendable, Equatable {
    public let template: String
    public let fontSize: CGFloat
    public let fontWeight: Font.Weight
    public let monospaced: Bool

    public init(
        template: String = "{value}",
        fontSize: CGFloat = 11,
        fontWeight: Font.Weight = .medium,
        monospaced: Bool = true
    ) {
        self.template = template
        self.fontSize = max(8, fontSize)
        self.fontWeight = fontWeight
        self.monospaced = monospaced
    }

    /// Format template with values
    public func format(_ values: [String: Any]) -> String {
        var result = template
        for (key, value) in values {
            let placeholder = "{\(key)}"
            result = result.replacingOccurrences(of: placeholder, with: "\(value)")
        }
        return result
    }
}

/// Text widget for template-based formatted values
public struct TextWidgetView: View {
    let config: TextWidgetConfig
    let values: [String: Any]

    public init(config: TextWidgetConfig = TextWidgetConfig(), values: [String: Any]) {
        self.config = config
        self.values = values
    }

    public init(text: String, fontSize: CGFloat = 11, monospaced: Bool = true) {
        self.config = TextWidgetConfig(template: text, fontSize: fontSize, monospaced: monospaced)
        self.values = [:]
    }

    public var body: some View {
        Text(displayText)
            .font(
                config.monospaced
                    ? .system(size: config.fontSize, weight: config.fontWeight, design: .monospaced)
                    : .system(size: config.fontSize, weight: config.fontWeight)
            )
            .foregroundColor(.primary)
            .frame(height: 22)
            .padding(.horizontal, 4)
    }

    private var displayText: String {
        if values.isEmpty {
            return config.template
        }
        return config.format(values)
    }
}

// MARK: - Dynamic Text (Live updating)

@Observable
@MainActor
public final class DynamicTextState {
    public var config: TextWidgetConfig
    private var _values: [String: Any] = [:]

    public var values: [String: Any] {
        get { _values }
        set {
            _values = newValue
            updateText()
        }
    }

    public var displayText: String = ""

    public init(config: TextWidgetConfig = TextWidgetConfig()) {
        self.config = config
        self.displayText = config.template
    }

    public func setValue(_ value: Any, forKey key: String) {
        _values[key] = value
        updateText()
    }

    private func updateText() {
        displayText = config.format(_values)
    }
}

/// Dynamic text widget with live updates
public struct DynamicTextWidgetView: View {
    @State private var state: DynamicTextState

    public init(state: DynamicTextState) {
        self._state = State(initialValue: state)
    }

    public var body: some View {
        Text(state.displayText)
            .font(
                state.config.monospaced
                    ? .system(size: state.config.fontSize, weight: state.config.fontWeight, design: .monospaced)
                    : .system(size: state.config.fontSize, weight: state.config.fontWeight)
            )
            .foregroundColor(.primary)
            .frame(height: 22)
            .padding(.horizontal, 4)
            .animation(.none, value: state.displayText)
    }
}

// MARK: - Preview

#Preview("Label/State/Text Widgets") {
    VStack(spacing: 20) {
        // Label widgets
        VStack(alignment: .leading, spacing: 8) {
            Text("Label Widgets")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                LabelWidgetView(text: "CPU")
                LabelWidgetView(text: "MEM", fontSize: 10)
                LabelWidgetView(text: "NET", fontWeight: .bold)
                LabelWidgetView(
                    text: "BAT",
                    backgroundColor: Color.accentColor.opacity(0.2)
                )
            }
        }

        // State widgets
        VStack(alignment: .leading, spacing: 8) {
            Text("State Widgets")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                StateWidgetView(isOn: true, style: .dot)
                StateWidgetView(isOn: false, style: .dot)
                StateWidgetView(isOn: true, style: .pill)
                StateWidgetView(isOn: false, style: .pill)
            }

            HStack(spacing: 12) {
                StateWidgetView(isOn: true, style: .indicator)
                StateWidgetView(isOn: false, style: .indicator)
                StateWidgetView(isOn: true, style: .toggle)
                StateWidgetView(isOn: false, style: .toggle)
            }

            HStack(spacing: 12) {
                StateWidgetView(
                    config: StateConfig(
                        isOn: true,
                        showLabel: true,
                        label: "Connected",
                        onColor: .green,
                        offColor: .red
                    )
                )
            }
        }

        // Text widgets
        VStack(alignment: .leading, spacing: 8) {
            Text("Text Widgets")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                TextWidgetView(text: "45%")
                TextWidgetView(text: "1.2 GB", monospaced: false)
                TextWidgetView(
                    config: TextWidgetConfig(template: "{value}/{max}"),
                    values: ["value": "8", "max": "16"]
                )
                TextWidgetView(
                    config: TextWidgetConfig(template: "{name}: {val}%"),
                    values: ["name": "CPU", "val": "45"]
                )
            }
        }

        // Dynamic text
        VStack(alignment: .leading, spacing: 8) {
            Text("Dynamic Text Widget")
                .font(.caption)
                .foregroundColor(.secondary)

            DynamicTextWidgetView(
                state: {
                    let s = DynamicTextState()
                    s.values = ["cpu": "45", "mem": "67"]
                    s.config = TextWidgetConfig(template: "CPU: {cpu}% | MEM: {mem}%")
                    return s
                }()
            )
        }
    }
    .padding()
}
