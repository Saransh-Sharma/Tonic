//
//  TonicEditorialChrome.swift
//  Tonic
//
//  Higher-level editorial chrome built on TonicDS + TonicEditorialComponents:
//  tab bars, bento grids, gauge/chart data cards, toasts, and sheet chrome.
//  The app shell/sidebar, console panel, and settings scaffold are built in their
//  consuming phases so they match real routing/renderer needs.
//

import SwiftUI

// MARK: - Tab bar

/// Horizontal segmented control built from FilterPills (Clean tabs, Monitor scopes).
struct TonicTabBar<Tab: Hashable>: View {
    let tabs: [Tab]
    @Binding var selection: Tab
    let title: (Tab) -> String

    var body: some View {
        HStack(spacing: TonicDS.Space.xs) {
            ForEach(tabs, id: \.self) { tab in
                FilterPill(title: title(tab), isActive: tab == selection) {
                    withAnimation(TonicDS.Motion.present) { selection = tab }
                }
            }
        }
    }
}

// MARK: - Bento grid

/// Adaptive editorial grid: 1 / 2 / 3 columns by available width. Tiles size
/// themselves (typically `DataCard`s). Children appear with a staggered reveal.
struct TonicBentoGrid<Content: View>: View {
    var minTileWidth: CGFloat = 260
    var spacing: CGFloat = TonicDS.Space.md
    @ViewBuilder var content: () -> Content

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: minTileWidth), spacing: spacing, alignment: .top)],
            alignment: .leading,
            spacing: spacing
        ) {
            content()
        }
    }
}

// MARK: - Gauge / chart data cards (wrap the kept renderers; status color = the media)

enum GaugeCardMetricMode: Equatable {
    /// Use the provided display string and optional unit.
    case preformatted
    /// Render the fraction as a rounded integer percentage.
    case percent
}

enum GaugeCardMetricFormatter {
    static func value(displayValue: String, fraction: Double, mode: GaugeCardMetricMode) -> String {
        switch mode {
        case .preformatted:
            return displayValue
        case .percent:
            let normalized = max(0, min(1, fraction))
            return "\(Int((normalized * 100).rounded()))"
        }
    }

    static func unit(providedUnit: String?, mode: GaugeCardMetricMode) -> String? {
        switch mode {
        case .preformatted:
            return providedUnit
        case .percent:
            return providedUnit ?? "%"
        }
    }
}

private struct TonicStatusBar: View {
    let fraction: Double
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didDraw = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(TonicDS.Colors.hairline)
                Capsule(style: .continuous)
                    .fill(color)
                    .frame(width: geo.size.width * max(0, min(1, reduceMotion ? fraction : (didDraw ? fraction : 0))))
            }
        }
        .frame(height: 4)
        .onAppear {
            if reduceMotion {
                didDraw = true
            } else {
                withAnimation(TonicDS.Motion.appear) { didDraw = true }
            }
        }
    }
}

/// A compact data card whose body is a single mono readout + optional sparkline +
/// thin status bar. `fraction` (0...1) drives the status color; data carries color.
struct GaugeCard: View {
    let label: String
    let fraction: Double
    let displayValue: String
    var unit: String?
    var metricMode: GaugeCardMetricMode = .preformatted
    var supportingText: String?
    var history: [Double]?
    var onTap: (() -> Void)?
    var accessibilityLabel: String?

    private var status: Color { TonicDS.status(forFraction: fraction) }
    private var normalizedFraction: Double { max(0, min(1, fraction)) }
    private var metricValue: String {
        GaugeCardMetricFormatter.value(displayValue: displayValue, fraction: fraction, mode: metricMode)
    }
    private var metricUnit: String? {
        GaugeCardMetricFormatter.unit(providedUnit: unit, mode: metricMode)
    }

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    content
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isButton)
                .tonicPointerCursor()
            } else {
                content
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel ?? "\(label), \(metricValue)\(metricUnit ?? "")")
        .accessibilityHint(onTap == nil ? "" : "Open Monitor")
    }

    private var content: some View {
        DataCard(hoverLift: onTap != nil) {
            VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                HStack(alignment: .firstTextBaseline) {
                    MonoLabel(label)
                    Spacer(minLength: TonicDS.Space.xs)
                    Metric(metricValue, unit: metricUnit, color: status)
                }
                if let supportingText {
                    Text(supportingText)
                        .tonicType(.caption)
                        .foregroundStyle(TonicDS.Colors.textMuted)
                        .lineLimit(1)
                }
                if let history, !history.isEmpty {
                    NetworkSparklineChart(data: history, color: status, height: 42, showArea: true, lineWidth: 1.5)
                        .clipShape(RoundedRectangle(cornerRadius: TonicDS.Radius.xs, style: .continuous))
                }
                TonicProgressBar(fraction: normalizedFraction, color: status, height: 4)
            }
        }
    }
}

/// A data card whose body is a full-width history sparkline + headline metric.
struct ChartCard: View {
    let label: String
    let displayValue: String
    var unit: String?
    let history: [Double]
    /// 0...1 fraction used only to pick the status color of the stroke.
    var fraction: Double = 0

    private var status: Color { TonicDS.status(forFraction: fraction) }

    var body: some View {
        DataCard {
            VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                HStack(alignment: .firstTextBaseline) {
                    MonoLabel(label)
                    Spacer(minLength: TonicDS.Space.xs)
                    Metric(displayValue, unit: unit, color: status)
                }
                NetworkSparklineChart(data: history, color: status, height: 56, showArea: true, lineWidth: 1.5)
                    .clipShape(RoundedRectangle(cornerRadius: TonicDS.Radius.xs, style: .continuous))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Toast

struct ToastData: Equatable {
    let message: String
    var actionTitle: String?
    // Note: closures aren't Equatable; identity via message + a token.
    var token: UUID = UUID()
    var action: (() -> Void)?

    static func == (lhs: ToastData, rhs: ToastData) -> Bool { lhs.token == rhs.token }
}

private struct ToastModifier: ViewModifier {
    @Binding var toast: ToastData?
    var autoDismiss: TimeInterval = 5
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var workItem: DispatchWorkItem?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let toast {
                HStack(spacing: TonicDS.Space.sm) {
                    Text(toast.message).tonicType(.body).foregroundStyle(TonicDS.Colors.onDark)
                    if let title = toast.actionTitle, let action = toast.action {
                        Button {
                            action()
                            dismiss()
                        } label: {
                            Text(title).tonicType(.button).foregroundStyle(TonicDS.Colors.onDark)
                                .underline()
                        }
                        .buttonStyle(.plain)
                        .tonicPointerCursor()
                    }
                }
                .padding(.horizontal, TonicDS.Space.lg)
                .padding(.vertical, TonicDS.Space.sm)
                .background(TonicDS.Colors.console, in: Capsule(style: .continuous))
                .padding(.bottom, TonicDS.Space.lg)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                .onAppear { schedule() }
            }
        }
        .animation(TonicDS.Motion.present, value: toast)
    }

    private func schedule() {
        workItem?.cancel()
        let item = DispatchWorkItem { dismiss() }
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismiss, execute: item)
    }

    private func dismiss() {
        withAnimation(TonicDS.Motion.present) { toast = nil }
    }
}

extension View {
    /// Present a bottom-center editorial toast (console capsule + optional undo).
    func tonicToast(_ toast: Binding<ToastData?>, autoDismiss: TimeInterval = 5) -> some View {
        modifier(ToastModifier(toast: toast, autoDismiss: autoDismiss))
    }
}

// MARK: - Sheet chrome

/// Standard modal scaffold: header (title + close), scrollable content, footer pill row.
struct SheetChrome<Content: View, Footer: View>: View {
    let title: String
    var onClose: (() -> Void)?
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).tonicType(.cardHeading).foregroundStyle(TonicDS.Colors.textPrimary)
                Spacer()
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(TonicDS.Colors.textMuted)
                    }
                    .buttonStyle(.plain)
                    .tonicPointerCursor()
                }
            }
            .padding(TonicDS.Space.lg)

            TonicHairline()

            ScrollView { content().padding(TonicDS.Space.lg) }

            let footerContent = footer()
            if !(footerContent is EmptyView) {
                TonicHairline()
                HStack(spacing: TonicDS.Space.sm) { footerContent }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(TonicDS.Space.lg)
            }
        }
        .background(TonicDS.Colors.canvas)
    }
}

extension SheetChrome where Footer == EmptyView {
    init(title: String, onClose: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, onClose: onClose, content: content, footer: { EmptyView() })
    }
}
