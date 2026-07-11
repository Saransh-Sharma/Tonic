//
//  NativeInstrumentComponents.swift
//  Tonic
//
//  Calm, reusable task components for the Native Instrument design language.
//

import AppKit
import SwiftUI

struct TonicMotionPolicy {
    let reduceMotion: Bool

    init(reduceMotion: Bool, appReducesMotion: Bool = AppearancePreferences.shared.reduceMotion) {
        self.reduceMotion = Self.shouldReduceMotion(
            systemReducesMotion: reduceMotion,
            appReducesMotion: appReducesMotion
        )
    }

    static func shouldReduceMotion(systemReducesMotion: Bool, appReducesMotion: Bool) -> Bool {
        systemReducesMotion || appReducesMotion
    }

    var feedback: Animation? { reduceMotion ? nil : .easeOut(duration: TonicDS.Motion.feedback) }
    var transition: Animation? { reduceMotion ? nil : .easeOut(duration: TonicDS.Motion.transition) }
    var layout: Animation? { reduceMotion ? nil : .easeOut(duration: TonicDS.Motion.layout) }
    var proof: Animation? { reduceMotion ? nil : .easeOut(duration: TonicDS.Motion.proof) }
}

@MainActor
enum TonicFeedback {
    static func alignment() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    static func levelChange() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}

struct InstrumentHeader<Actions: View>: View {
    let title: String
    let state: String?
    @ViewBuilder let actions: () -> Actions

    init(_ title: String, state: String? = nil, @ViewBuilder actions: @escaping () -> Actions = { EmptyView() }) {
        self.title = title
        self.state = state
        self.actions = actions
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: TonicDS.Space.md) {
            VStack(alignment: .leading, spacing: TonicDS.Space.xxs) {
                Text(title)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(TonicDS.Colors.textPrimary)
                if let state {
                    Text(state)
                        .font(.system(size: 13))
                        .foregroundStyle(TonicDS.Colors.textMuted)
                }
            }
            Spacer(minLength: TonicDS.Space.lg)
            actions()
        }
        .accessibilityElement(children: .contain)
    }
}

struct StatusNarrative: View {
    let eyebrow: String
    let narrative: String
    let evidence: String?

    init(_ narrative: String, eyebrow: String = "Current state", evidence: String? = nil) {
        self.eyebrow = eyebrow
        self.narrative = narrative
        self.evidence = evidence
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
            MonoLabel(eyebrow)
            Text(narrative)
                .font(.system(size: 38, weight: .medium))
                .tracking(-0.7)
                .foregroundStyle(TonicDS.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let evidence {
                Text(evidence)
                    .font(.system(size: 14))
                    .foregroundStyle(TonicDS.Colors.textMuted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct MetricConsole: View {
    let title: String
    let value: String
    let unit: String?
    let history: [Double]
    let status: TonicDS.StatusLevel

    var body: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
            HStack {
                MonoLabel(title, color: TonicDS.Colors.onDarkMuted)
                Spacer()
                Circle()
                    .fill(status.color)
                    .frame(width: 7, height: 7)
                Text(status.word)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(TonicDS.Colors.onDarkMuted)
            }
            Metric(value, unit: unit, color: TonicDS.Colors.onDark)
            if history.count > 1 {
                NetworkSparklineChart(
                    data: Array(history.suffix(60)),
                    color: status.color,
                    height: 40,
                    showArea: true,
                    lineWidth: 1.5
                )
                .accessibilityHidden(true)
            } else {
                Capsule()
                    .fill(TonicDS.Colors.hairlineOnDark)
                    .frame(height: 2)
            }
        }
        .padding(TonicDS.Space.md)
        .tonicSurface(.smoked, in: RoundedRectangle(cornerRadius: TonicDS.Radius.md, style: .continuous))
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value) \(unit ?? ""), \(status.word)")
    }
}

struct EvidenceRow<Trailing: View>: View {
    let symbol: String
    let title: String
    let reason: String
    let metadata: String?
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .top, spacing: TonicDS.Space.sm) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 22, height: 22)
                .foregroundStyle(TonicDS.Colors.textMuted)
            VStack(alignment: .leading, spacing: TonicDS.Space.xxs) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TonicDS.Colors.textPrimary)
                Text(reason)
                    .font(.system(size: 12))
                    .foregroundStyle(TonicDS.Colors.textMuted)
                if let metadata {
                    Text(metadata)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(TonicDS.Colors.textMuted)
                }
            }
            Spacer(minLength: TonicDS.Space.md)
            trailing()
        }
        .padding(.vertical, TonicDS.Space.sm)
        .contentShape(Rectangle())
    }
}

struct ActionReceiptView: View {
    let receipt: ActionReceipt
    var undo: (() -> Void)?

    var body: some View {
        EvidenceRow(
            symbol: receipt.status == .restored ? "arrow.uturn.backward.circle" : "checkmark.circle",
            title: receipt.title,
            reason: receipt.detail,
            metadata: receipt.completedAt.formatted(date: .abbreviated, time: .shortened)
        ) {
            if let impact = receipt.impact {
                Text(impact)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(TonicDS.Colors.textPrimary)
            }
            if case .available = receipt.undo, let undo {
                Button("Undo", action: undo)
                    .buttonStyle(.borderless)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct EmptyLesson<Preview: View, Actions: View>: View {
    let title: String
    let message: String
    @ViewBuilder let preview: () -> Preview
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(spacing: TonicDS.Space.md) {
            preview()
                .frame(height: 96)
            Text(title)
                .font(.system(size: 17, weight: .semibold))
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(TonicDS.Colors.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            actions()
        }
        .frame(maxWidth: .infinity)
        .padding(TonicDS.Space.xl)
    }
}

struct EditionAvailabilityNotice: View {
    let capability: String

    var body: some View {
        Label("\(capability) is available in Tonic Direct.", systemImage: "shippingbox")
            .font(.system(size: 12))
            .foregroundStyle(TonicDS.Colors.textMuted)
            .padding(TonicDS.Space.sm)
            .background(TonicDS.Colors.softStone, in: RoundedRectangle(cornerRadius: TonicDS.Radius.sm))
    }
}

struct ActionDock<Actions: View>: View {
    let summary: String
    let impact: String?
    @ViewBuilder let actions: () -> Actions
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: TonicDS.Space.md) {
            Text(summary)
                .font(.system(size: 13, weight: .medium))
            if let impact {
                Text(impact)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(TonicDS.Colors.textMuted)
            }
            Spacer()
            actions()
        }
        .padding(.horizontal, TonicDS.Space.md)
        .frame(height: 52)
        .tonicSurface(.chrome,
                      in: RoundedRectangle(cornerRadius: TonicDS.Radius.lg, style: .continuous))
        .shadow(color: TonicDS.Elevation.cardLift(scheme).color,
                radius: TonicDS.Elevation.cardLift(scheme).radius,
                y: TonicDS.Elevation.cardLift(scheme).y)
    }
}

struct InspectorPanel<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(TonicDS.Space.md)
            .frame(minWidth: 280, idealWidth: 300, maxWidth: 320, maxHeight: .infinity, alignment: .topLeading)
            .background(TonicDS.Colors.canvasSoft)
            .overlay(alignment: .leading) { Rectangle().fill(TonicDS.Colors.hairline).frame(width: 1) }
    }
}
