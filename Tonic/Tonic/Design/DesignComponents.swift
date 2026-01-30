//
//  DesignComponents.swift
//  Tonic
//
//  Reusable SwiftUI components built on design tokens
//

import SwiftUI

// MARK: - Card Component

/// A flexible card component with 3 semantic variants.
/// Uses semantic colors from DesignTokens for proper light/dark mode support.
///
/// Variants:
/// - **elevated**: Shadow for depth (primary content containers)
/// - **flat**: No shadow, border only (secondary content)
/// - **inset**: Inset border for grouped/nested content
///
/// Usage:
/// ```swift
/// Card(variant: .elevated) {
///     Text("Primary Content")
/// }
/// ```
struct Card<Content: View>: View {
    let content: Content
    let variant: CardVariant
    var padding: CGFloat = DesignTokens.Spacing.cardPadding
    var cornerRadius: CGFloat = DesignTokens.CornerRadius.large

    /// Card style variants
    enum CardVariant {
        /// Elevated card with shadow - use for primary content containers
        case elevated
        /// Flat card with border - use for secondary content
        case flat
        /// Inset card with inset border - use for grouped/nested content
        case inset
    }

    /// Initialize a Card with optional variant specification
    /// - Parameters:
    ///   - variant: Card style variant (defaults to elevated for backward compatibility)
    ///   - padding: Inner padding (defaults to 16pt)
    ///   - cornerRadius: Corner radius (defaults to 12pt)
    ///   - content: The card content
    init(
        variant: CardVariant = .elevated,
        padding: CGFloat = DesignTokens.Spacing.cardPadding,
        cornerRadius: CGFloat = DesignTokens.CornerRadius.large,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.variant = variant
        self.padding = padding
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            switch variant {
            case .elevated:
                // Elevated: Shadow for depth
                content
                    .padding(padding)
                    .background(DesignTokens.Colors.backgroundSecondary)
                    .cornerRadius(cornerRadius)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

            case .flat:
                // Flat: Border only, no shadow
                content
                    .padding(padding)
                    .background(DesignTokens.Colors.backgroundSecondary)
                    .cornerRadius(cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(DesignTokens.Colors.separator, lineWidth: 1)
                    )

            case .inset:
                // Inset: Inset border for nested content
                content
                    .padding(padding)
                    .background(DesignTokens.Colors.backgroundSecondary)
                    .cornerRadius(cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                DesignTokens.Colors.separator.opacity(0.5),
                                lineWidth: 0.5
                            )
                    )
            }
        }
    }
}

// MARK: - Card Component Previews

#if DEBUG
struct Card_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Elevated variant
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Elevated Card")
                    .font(DesignTokens.Typography.bodyEmphasized)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Card(variant: .elevated) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Primary Content")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Colors.textPrimary)

                        Text("Elevated cards use shadow for depth - perfect for main content containers.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }
            }

            // Flat variant
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Flat Card")
                    .font(DesignTokens.Typography.bodyEmphasized)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Card(variant: .flat) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Secondary Content")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Colors.textPrimary)

                        Text("Flat cards use only a border - for secondary content without emphasis.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }
            }

            // Inset variant
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Inset Card")
                    .font(DesignTokens.Typography.bodyEmphasized)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Card(variant: .inset) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Nested Content")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Colors.textPrimary)

                        Text("Inset cards use an inset border - ideal for grouped or nested content.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.lg)
        .background(DesignTokens.Colors.background)
        .previewDisplayName("Card Variants")
    }
}
#endif

// MARK: - Primary Button

struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(DesignTokens.Typography.headlineSmall)
            }
            .frame(minWidth: DesignTokens.Layout.minButtonHeight)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(isPressed ? DesignTokens.Colors.accent.opacity(0.8) :
                          isHovered ? DesignTokens.Colors.accent : DesignTokens.Colors.accent.opacity(0.9))
            .foregroundColor(.white)
            .cornerRadius(DesignTokens.CornerRadius.medium)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Secondary Button

struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    @State private var isHovered = false

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(DesignTokens.Typography.headlineSmall)
            }
            .frame(minWidth: DesignTokens.Layout.minButtonHeight)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(isHovered ? DesignTokens.Colors.surfaceHovered : DesignTokens.Colors.surface)
            .foregroundColor(DesignTokens.Colors.text)
            .cornerRadius(DesignTokens.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                    .stroke(DesignTokens.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(DesignTokens.Animation.fast) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let value: Double // 0-1
    let total: Double
    var color: Color? = nil
    var height: CGFloat = 8
    var showPercentage: Bool = true

    init(value: Double, total: Double = 1.0, color: Color? = nil, height: CGFloat = 8, showPercentage: Bool = true) {
        self.value = min(max(value / total, 0), 1)
        self.total = total
        self.color = color
        self.height = height
        self.showPercentage = showPercentage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            if showPercentage {
                HStack {
                    Text("\(Int(value * 100))%")
                        .font(DesignTokens.Typography.captionLarge)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    Spacer()
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(DesignTokens.Colors.backgroundSecondary)

                    // Progress fill
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(color ?? progressColor)
                        .frame(width: geometry.size.width * value)
                        .animation(.easeInOut(duration: 0.3), value: value)
                }
            }
            .frame(height: height)
        }
    }

    private var progressColor: Color {
        switch value {
        case 0..<0.5: return DesignTokens.Colors.progressLow
        case 0.5..<0.8: return DesignTokens.Colors.progressMedium
        default: return DesignTokens.Colors.progressHigh
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = DesignTokens.Colors.accent
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(DesignTokens.Typography.headlineSmall)
                Spacer()
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(value)
                    .font(DesignTokens.Typography.displaySmall)

                Text(title)
                    .font(DesignTokens.Typography.bodySmall)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.captionSmall)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.surface)
        .cornerRadius(DesignTokens.CornerRadius.large)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    var icon: String? = nil

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .frame(width: 20)
            }
            Text(label)
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundColor(DesignTokens.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundColor(DesignTokens.Colors.text)
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(title)
                    .font(DesignTokens.Typography.headlineMedium)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }

            Spacer()

            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(DesignTokens.Typography.bodySmall)
                }
                .buttonStyle(.link)
            }
        }
    }
}

// MARK: - Badge

struct Badge: View {
    let text: String
    var color: Color = DesignTokens.Colors.accent
    var size: BadgeSize = .medium

    enum BadgeSize {
        case small, medium, large

        var padding: (horizontal: CGFloat, vertical: CGFloat) {
            switch self {
            case .small: return (6, 2)
            case .medium: return (8, 4)
            case .large: return (12, 6)
            }
        }

        var font: Font {
            switch self {
            case .small: return DesignTokens.Typography.captionSmall
            case .medium: return DesignTokens.Typography.captionMedium
            case .large: return DesignTokens.Typography.captionLarge
            }
        }
    }

    var body: some View {
        Text(text)
            .font(size.font)
            .foregroundColor(.white)
            .padding(.horizontal, size.padding.horizontal)
            .padding(.vertical, size.padding.vertical)
            .background(color)
            .cornerRadius(DesignTokens.CornerRadius.round)
    }
}

// MARK: - Loading Indicator

struct LoadingIndicator: View {
    @State private var isRotating = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                DesignTokens.Colors.accent,
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .frame(width: 24, height: 24)
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isRotating)
            .onAppear {
                isRotating = true
            }
    }
}

// MARK: - Empty State

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(DesignTokens.Colors.textTertiary)

            VStack(spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.headlineMedium)
                    .foregroundColor(DesignTokens.Colors.text)

                Text(message)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let action = action, let actionTitle = actionTitle {
                PrimaryButton(actionTitle, action: action)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.Spacing.xxl)
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(DesignTokens.Colors.textSecondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(DesignTokens.Typography.bodyMedium)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.surface)
        .cornerRadius(DesignTokens.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                .stroke(DesignTokens.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - Toggle Row

struct ToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(title)
                    .font(DesignTokens.Typography.bodyMedium)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.bodySmall)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.surface)
        .cornerRadius(DesignTokens.CornerRadius.medium)
    }
}

// MARK: - RAG Status Indicators

/// Status level for RAG (Red-Amber-Green) indicators
enum StatusLevel: Sendable {
    case healthy   // Green - all good
    case warning   // Amber - partial/not optimal
    case critical  // Red - missing/error
    case unknown   // Gray - not checked

    var color: Color {
        switch self {
        case .healthy: return TonicColors.success
        case .warning: return TonicColors.warning
        case .critical: return TonicColors.error
        case .unknown: return .gray
        }
    }

    var icon: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .healthy: return "Good"
        case .warning: return "Warning"
        case .critical: return "Issue"
        case .unknown: return "Unknown"
        }
    }
}

/// RAG status indicator component - shows colored dot with label
struct StatusIndicator: View {
    let level: StatusLevel
    let size: CGFloat

    init(level: StatusLevel, size: CGFloat = 12) {
        self.level = level
        self.size = size
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(level.color)
                .frame(width: size, height: size)

            Text(level.label)
                .font(.caption)
                .foregroundColor(level.color)
        }
    }
}

/// Status card with icon, title, description, and RAG indicator
struct StatusCard: View {
    let icon: String
    let title: String
    let description: String
    let status: StatusLevel
    let action: (() -> Void)?

    init(icon: String, title: String, description: String, status: StatusLevel, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.description = description
        self.status = status
        self.action = action
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(status.color)
                .frame(width: 32)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status indicator
            StatusIndicator(level: status)

            // Action button if provided
            if let action = action {
                Button(action: action) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.callout)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(DesignTokens.CornerRadius.medium)
    }
}

// MARK: - MetricRow Component

/// A reusable row for displaying metrics with icon, title, value, and optional sparkline.
/// Used in Dashboard and Live Monitoring views.
///
/// Layout: HStack with Icon | Title+Value (VStack) | Sparkline (optional)
/// Fixed height: 44pt (DesignTokens.Layout.minRowHeight)
/// Typography: Title uses subhead (14pt), Value uses monoBody (16pt monospaced)
struct MetricRow: View {
    let icon: String
    let title: String
    let value: String
    var iconColor: Color = DesignTokens.Colors.accent
    var sparklineData: [Double]? = nil
    var sparklineColor: Color? = nil

    /// Initialize a MetricRow
    /// - Parameters:
    ///   - icon: SF Symbol name for the icon
    ///   - title: The metric label (e.g., "CPU Usage")
    ///   - value: The metric value (e.g., "45%")
    ///   - iconColor: Color for the icon (defaults to accent)
    ///   - sparklineData: Optional array of values (0-1) for the sparkline
    ///   - sparklineColor: Color for the sparkline (defaults to accent if data provided)
    init(
        icon: String,
        title: String,
        value: String,
        iconColor: Color = DesignTokens.Colors.accent,
        sparklineData: [Double]? = nil,
        sparklineColor: Color? = nil
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.iconColor = iconColor
        self.sparklineData = sparklineData
        self.sparklineColor = sparklineColor
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 24, alignment: .center)

            // Title + Value stack
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                Text(title)
                    .font(DesignTokens.Typography.subhead)
                    .foregroundColor(DesignTokens.Colors.textSecondary)

                Text(value)
                    .font(DesignTokens.Typography.monoBody)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
            }

            Spacer()

            // Optional sparkline
            if let data = sparklineData, !data.isEmpty {
                MetricSparkline(
                    data: data,
                    color: sparklineColor ?? DesignTokens.Colors.accent
                )
                .frame(width: 60, height: 24)
            }
        }
        .frame(height: DesignTokens.Layout.minRowHeight)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - MetricSparkline Component

/// A mini sparkline graph for displaying metric history
/// Used internally by MetricRow
struct MetricSparkline: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let stepX = data.count > 1 ? width / CGFloat(data.count - 1) : width

            // Normalize data to 0-1 range
            let minValue = data.min() ?? 0
            let maxValue = data.max() ?? 1
            let range = maxValue - minValue
            let normalizedData = data.map { value -> Double in
                range > 0 ? (value - minValue) / range : 0.5
            }

            Path { path in
                guard !normalizedData.isEmpty else { return }

                let firstY = height - (CGFloat(normalizedData[0]) * height)
                path.move(to: CGPoint(x: 0, y: firstY))

                for index in 1..<normalizedData.count {
                    let x = CGFloat(index) * stepX
                    let y = height - (CGFloat(normalizedData[index]) * height)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - MetricRow Previews

#if DEBUG
struct MetricRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            MetricRow(
                icon: "cpu",
                title: "CPU Usage",
                value: "45%",
                iconColor: DesignTokens.Colors.accent
            )
            Divider()
            MetricRow(
                icon: "memorychip",
                title: "Memory",
                value: "8.2 GB / 16 GB",
                iconColor: DesignTokens.Colors.info,
                sparklineData: [0.3, 0.4, 0.35, 0.5, 0.45, 0.52, 0.51],
                sparklineColor: DesignTokens.Colors.info
            )
            Divider()
            MetricRow(
                icon: "internaldrive",
                title: "Disk Usage",
                value: "234 GB free",
                iconColor: DesignTokens.Colors.warning,
                sparklineData: [0.6, 0.62, 0.65, 0.7, 0.72, 0.75, 0.78]
            )
            Divider()
            MetricRow(
                icon: "network",
                title: "Network",
                value: "12.5 MB/s",
                iconColor: DesignTokens.Colors.success,
                sparklineData: [0.1, 0.2, 0.15, 0.8, 0.3, 0.25, 0.4]
            )
        }
        .padding()
        .background(DesignTokens.Colors.background)
        .previewLayout(.sizeThatFits)
        .previewDisplayName("MetricRow Examples")
    }
}
#endif

// MARK: - PreferenceList Component

/// A grouped list component for settings screens with Label + Control rows.
/// Supports grouped sections with headers, consistent padding, and various control types.
///
/// Usage:
/// ```swift
/// PreferenceList {
///     PreferenceSection(header: "General") {
///         PreferenceRow(title: "Launch at Login") {
///             Toggle("", isOn: $launchAtLogin)
///         }
///         PreferenceRow(title: "Theme", subtitle: "Choose appearance") {
///             Picker("", selection: $theme) { ... }
///         }
///     }
///     PreferenceSection(header: "Advanced") {
///         PreferenceRow(title: "Clear Cache") {
///             Button("Clear") { ... }
///         }
///     }
/// }
/// ```
struct PreferenceList<Content: View>: View {
    let content: Content

    /// Initialize a PreferenceList with grouped sections
    /// - Parameter content: The sections to display (use PreferenceSection)
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            content
        }
    }
}

// MARK: - PreferenceSection Component

/// A section within a PreferenceList with an optional header.
/// Groups related preference rows together with consistent styling.
struct PreferenceSection<Content: View>: View {
    let header: String?
    let footer: String?
    let content: Content

    /// Initialize a preference section
    /// - Parameters:
    ///   - header: Optional section header text (displayed in caption style)
    ///   - footer: Optional footer text for additional context
    ///   - content: The rows in this section (use PreferenceRow)
    init(
        header: String? = nil,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.header = header
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            // Section header
            if let header = header {
                Text(header.uppercased())
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.bottom, DesignTokens.Spacing.xxxs)
            }

            // Section content with background
            VStack(spacing: 0) {
                content
            }
            .background(DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.medium)

            // Section footer
            if let footer = footer {
                Text(footer)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.top, DesignTokens.Spacing.xxxs)
            }
        }
    }
}

// MARK: - PreferenceRow Component

/// A single row in a PreferenceSection with label on the left and control on the right.
/// Consistent padding: sm vertical, md horizontal.
struct PreferenceRow<Control: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let iconColor: Color
    let control: Control
    let showDivider: Bool

    @State private var isHovered = false

    /// Initialize a preference row
    /// - Parameters:
    ///   - title: The main label text
    ///   - subtitle: Optional secondary description text
    ///   - icon: Optional SF Symbol name for an icon
    ///   - iconColor: Color for the icon (defaults to accent)
    ///   - showDivider: Whether to show a divider below this row (defaults to true)
    ///   - control: The control view (Toggle, Picker, Button, etc.)
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color = DesignTokens.Colors.accent,
        showDivider: Bool = true,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.showDivider = showDivider
        self.control = control()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Optional icon
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(iconColor)
                        .frame(width: 24, alignment: .center)
                }

                // Label stack
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                    Text(title)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }

                Spacer()

                // Control
                control
            }
            .padding(.vertical, DesignTokens.Spacing.sm)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .background(isHovered ? DesignTokens.Colors.unemphasizedSelectedContentBackground.opacity(0.5) : Color.clear)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(DesignTokens.Animation.fast) {
                    isHovered = hovering
                }
            }

            // Divider
            if showDivider {
                Divider()
                    .padding(.leading, icon != nil ? DesignTokens.Spacing.md + 24 + DesignTokens.Spacing.sm : DesignTokens.Spacing.md)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(subtitle != nil ? "\(title), \(subtitle!)" : title)
    }
}

// MARK: - PreferenceToggleRow

/// A convenience wrapper for PreferenceRow with a Toggle control.
struct PreferenceToggleRow: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let iconColor: Color
    let showDivider: Bool
    @Binding var isOn: Bool

    /// Initialize a toggle preference row
    /// - Parameters:
    ///   - title: The main label text
    ///   - subtitle: Optional secondary description text
    ///   - icon: Optional SF Symbol name for an icon
    ///   - iconColor: Color for the icon (defaults to accent)
    ///   - showDivider: Whether to show a divider below this row
    ///   - isOn: Binding to the toggle state
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color = DesignTokens.Colors.accent,
        showDivider: Bool = true,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.showDivider = showDivider
        self._isOn = isOn
    }

    var body: some View {
        PreferenceRow(
            title: title,
            subtitle: subtitle,
            icon: icon,
            iconColor: iconColor,
            showDivider: showDivider
        ) {
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
}

// MARK: - PreferencePickerRow

/// A convenience wrapper for PreferenceRow with a Picker control.
struct PreferencePickerRow<SelectionValue: Hashable, PickerContent: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let iconColor: Color
    let showDivider: Bool
    @Binding var selection: SelectionValue
    let pickerContent: PickerContent

    /// Initialize a picker preference row
    /// - Parameters:
    ///   - title: The main label text
    ///   - subtitle: Optional secondary description text
    ///   - icon: Optional SF Symbol name for an icon
    ///   - iconColor: Color for the icon (defaults to accent)
    ///   - showDivider: Whether to show a divider below this row
    ///   - selection: Binding to the selected value
    ///   - content: The picker options
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color = DesignTokens.Colors.accent,
        showDivider: Bool = true,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> PickerContent
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.showDivider = showDivider
        self._selection = selection
        self.pickerContent = content()
    }

    var body: some View {
        PreferenceRow(
            title: title,
            subtitle: subtitle,
            icon: icon,
            iconColor: iconColor,
            showDivider: showDivider
        ) {
            Picker("", selection: $selection) {
                pickerContent
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }
}

// MARK: - PreferenceButtonRow

/// A convenience wrapper for PreferenceRow with a Button control.
struct PreferenceButtonRow: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let iconColor: Color
    let showDivider: Bool
    let buttonTitle: String
    let buttonStyle: PreferenceButtonStyle
    let action: () -> Void

    /// Button style options for PreferenceButtonRow
    enum PreferenceButtonStyle {
        case primary
        case secondary
        case destructive

        var tint: Color? {
            switch self {
            case .primary: return nil
            case .secondary: return nil
            case .destructive: return DesignTokens.Colors.destructive
            }
        }
    }

    /// Initialize a button preference row
    /// - Parameters:
    ///   - title: The main label text
    ///   - subtitle: Optional secondary description text
    ///   - icon: Optional SF Symbol name for an icon
    ///   - iconColor: Color for the icon (defaults to accent)
    ///   - showDivider: Whether to show a divider below this row
    ///   - buttonTitle: The button text
    ///   - buttonStyle: The button style (primary, secondary, destructive)
    ///   - action: The button action
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color = DesignTokens.Colors.accent,
        showDivider: Bool = true,
        buttonTitle: String,
        buttonStyle: PreferenceButtonStyle = .secondary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.showDivider = showDivider
        self.buttonTitle = buttonTitle
        self.buttonStyle = buttonStyle
        self.action = action
    }

    var body: some View {
        PreferenceRow(
            title: title,
            subtitle: subtitle,
            icon: icon,
            iconColor: iconColor,
            showDivider: showDivider
        ) {
            Group {
                switch buttonStyle {
                case .primary:
                    Button(buttonTitle, action: action)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                case .secondary:
                    Button(buttonTitle, action: action)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                case .destructive:
                    Button(buttonTitle, action: action)
                        .buttonStyle(.bordered)
                        .tint(DesignTokens.Colors.destructive)
                        .controlSize(.small)
                }
            }
        }
    }
}

// MARK: - PreferenceStatusRow

/// A convenience wrapper for PreferenceRow with a Status indicator control.
struct PreferenceStatusRow: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let iconColor: Color
    let showDivider: Bool
    let status: StatusLevel
    let statusText: String?

    /// Initialize a status preference row
    /// - Parameters:
    ///   - title: The main label text
    ///   - subtitle: Optional secondary description text
    ///   - icon: Optional SF Symbol name for an icon
    ///   - iconColor: Color for the icon (defaults to accent)
    ///   - showDivider: Whether to show a divider below this row
    ///   - status: The status level (healthy, warning, critical, unknown)
    ///   - statusText: Optional custom status text (defaults to status label)
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color = DesignTokens.Colors.accent,
        showDivider: Bool = true,
        status: StatusLevel,
        statusText: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.showDivider = showDivider
        self.status = status
        self.statusText = statusText
    }

    var body: some View {
        PreferenceRow(
            title: title,
            subtitle: subtitle,
            icon: icon,
            iconColor: iconColor,
            showDivider: showDivider
        ) {
            HStack(spacing: DesignTokens.Spacing.xxs) {
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)

                Text(statusText ?? status.label)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(status.color)
            }
        }
    }
}

// MARK: - PermissionStatusRow

/// A preference row for displaying permission status with grant button.
struct PermissionStatusRow: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let status: PermissionStatus
    let iconColor: Color?
    let showDivider: Bool
    let onGrantTapped: (() -> Void)?

    /// Initialize a permission status row
    /// - Parameters:
    ///   - title: The permission name
    ///   - subtitle: Description of what the permission enables
    ///   - icon: SF Symbol name for the icon
    ///   - status: The current permission status
    ///   - iconColor: Color for the icon (defaults to status color)
    ///   - showDivider: Whether to show a divider below
    ///   - onGrantTapped: Optional callback when Grant button is tapped
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        status: PermissionStatus,
        iconColor: Color? = nil,
        showDivider: Bool = true,
        onGrantTapped: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.status = status
        self.iconColor = iconColor
        self.showDivider = showDivider
        self.onGrantTapped = onGrantTapped
    }

    private var computedIconColor: Color {
        iconColor ?? statusColor
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                // Optional icon
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(computedIconColor)
                        .frame(width: 24, alignment: .center)
                }

                // Label stack
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxxs) {
                    Text(title)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }

                Spacer()

                // Status badge and button
                HStack(spacing: DesignTokens.Spacing.sm) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)

                        Text(statusLabel)
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(statusColor)
                    }

                    if status != .authorized {
                        Button("Grant") {
                            onGrantTapped?()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(statusColor)
                    }
                }
            }
            .padding(.vertical, DesignTokens.Spacing.sm)
            .padding(.horizontal, DesignTokens.Spacing.md)

            // Divider
            if showDivider {
                Divider()
                    .padding(.leading, icon != nil ? DesignTokens.Spacing.md + 24 + DesignTokens.Spacing.sm : DesignTokens.Spacing.md)
            }
        }
    }

    private var statusColor: Color {
        switch status {
        case .authorized: return DesignTokens.Colors.success
        case .denied: return DesignTokens.Colors.destructive
        case .notDetermined: return DesignTokens.Colors.textTertiary
        }
    }

    private var statusLabel: String {
        switch status {
        case .authorized: return "Granted"
        case .denied: return "Denied"
        case .notDetermined: return "Not Set"
        }
    }
}

// MARK: - PreferenceList Previews

#if DEBUG
struct PreferenceList_Previews: PreviewProvider {
    static var previews: some View {
        PreferenceListPreviewWrapper()
            .padding()
            .background(DesignTokens.Colors.background)
            .previewLayout(.sizeThatFits)
            .previewDisplayName("PreferenceList Examples")
    }
}

private struct PreferenceListPreviewWrapper: View {
    @State private var launchAtLogin = true
    @State private var automaticUpdates = false
    @State private var selectedTheme = "System"

    var body: some View {
        PreferenceList {
            PreferenceSection(header: "General", footer: "These settings control app behavior at startup.") {
                PreferenceToggleRow(
                    title: "Launch at Login",
                    subtitle: "Start Tonic when you log in",
                    icon: "power",
                    isOn: $launchAtLogin
                )
                PreferenceToggleRow(
                    title: "Automatic Updates",
                    subtitle: "Check for updates automatically",
                    icon: "arrow.triangle.2.circlepath",
                    showDivider: false,
                    isOn: $automaticUpdates
                )
            }

            PreferenceSection(header: "Appearance") {
                PreferencePickerRow(
                    title: "Theme",
                    subtitle: "Choose your preferred appearance",
                    icon: "paintbrush",
                    selection: $selectedTheme
                ) {
                    Text("System").tag("System")
                    Text("Light").tag("Light")
                    Text("Dark").tag("Dark")
                }
                PreferenceStatusRow(
                    title: "Full Disk Access",
                    subtitle: "Required for complete scanning",
                    icon: "externaldrive",
                    iconColor: DesignTokens.Colors.success,
                    showDivider: false,
                    status: .healthy,
                    statusText: "Granted"
                )
            }

            PreferenceSection(header: "Data") {
                PreferenceButtonRow(
                    title: "Clear Cache",
                    subtitle: "Remove temporary files",
                    icon: "trash",
                    iconColor: DesignTokens.Colors.warning,
                    buttonTitle: "Clear",
                    buttonStyle: .secondary
                ) {
                    print("Clear cache tapped")
                }
                PreferenceButtonRow(
                    title: "Reset All Settings",
                    subtitle: "Restore default configuration",
                    icon: "arrow.counterclockwise",
                    iconColor: DesignTokens.Colors.destructive,
                    showDivider: false,
                    buttonTitle: "Reset",
                    buttonStyle: .destructive
                ) {
                    print("Reset tapped")
                }
            }
        }
        .frame(width: 400)
    }
}
#endif
