//
//  PopoverTemplate.swift
//  Tonic
//
//  Standardized template view for widget popovers
//  Task ID: fn-6-i4g.18
//

import SwiftUI

// MARK: - Popover Template

/// A standardized template view for all widget popovers
/// Provides consistent header, sections, and footer styling
///
/// Usage:
/// ```swift
/// PopoverTemplate(
///     icon: "cpu.fill",
///     title: "CPU Usage",
///     value: "45%",
///     valueColor: .blue,
///     content: {
///         // Your widget content here
///     }
/// )
/// ```
struct PopoverTemplate<Content: View>: View {

    // MARK: - Properties

    /// SF Symbol icon for the widget
    let icon: String

    /// Widget title
    let title: String

    /// Primary value to display in header (optional)
    var headerValue: String?

    /// Color for the icon and header value
    var headerColor: Color = DesignTokens.Colors.accent

    /// Optional action button in header (e.g., settings gear)
    var headerAction: (() -> Void)?

    /// Main content of the popover
    let content: Content

    // MARK: - Initialization

    /// Initialize a standardized popover template
    /// - Parameters:
    ///   - icon: SF Symbol name for the widget icon
    ///   - title: Widget title
    ///   - headerValue: Optional primary value to show in header
    ///   - headerColor: Color for icon and header value
    ///   - headerAction: Optional action when header gear is tapped
    ///   - content: Main popover content
    init(
        icon: String,
        title: String,
        headerValue: String? = nil,
        headerColor: Color = DesignTokens.Colors.accent,
        headerAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.headerValue = headerValue
        self.headerColor = headerColor
        self.headerAction = headerAction
        self.content = content()
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            ScrollView {
                VStack(spacing: PopoverConstants.sectionSpacing) {
                    content
                }
                .padding(PopoverConstants.horizontalPadding)
                .padding(.vertical, PopoverConstants.verticalPadding)
            }
        }
        .frame(width: PopoverConstants.width, height: PopoverConstants.maxHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(PopoverConstants.cornerRadius)
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(headerColor)

            // Title
            Text(title)
                .font(PopoverConstants.headerTitleFont)

            Spacer()

            // Primary value (if provided)
            if let value = headerValue {
                Text(value)
                    .font(PopoverConstants.headerValueFont)
                    .foregroundColor(headerColor)
            }

            // Settings/action button (if provided)
            if let action = headerAction {
                Button {
                    action()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Standard Sections

/// A standardized section container for popover content
/// Provides consistent background, padding, and styling
struct PopoverSection<Content: View>: View {

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, PopoverConstants.horizontalPadding)
            .padding(.vertical, PopoverConstants.itemSpacing)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(PopoverConstants.innerCornerRadius)
    }
}

/// A section with a title label
struct TitledPopoverSection<Content: View>: View {

    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            Text(title)
                .font(PopoverConstants.sectionTitleFont)
                .foregroundColor(.secondary)

            content
        }
        .padding(PopoverConstants.horizontalPadding)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(PopoverConstants.innerCornerRadius)
    }
}

// MARK: - Detail Row

/// A standardized two-column row for displaying key-value pairs
/// Used in detail grids across all widget popovers
struct PopoverDetailRow: View {

    let label: String
    let value: String
    var icon: String?
    var valueColor: Color = DesignTokens.Colors.textPrimary

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 16)
            }

            Text(label)
                .font(PopoverConstants.detailLabelFont)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(PopoverConstants.detailValueFont)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - Detail Grid

/// A two-column grid for displaying multiple key-value pairs
/// Automatically arranges rows in two columns for compact display
struct PopoverDetailGrid: View {

    let items: [DetailItem]

    struct DetailItem: Identifiable {
        let id = UUID()
        let label: String
        let value: String
        var icon: String?
        var valueColor: Color = DesignTokens.Colors.textPrimary
    }

    init(items: [DetailItem]) {
        self.items = items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PopoverConstants.itemSpacing) {
            // Arrange items in two columns
            let halfCount = (items.count + 1) / 2

            ForEach(0..<halfCount, id: \.self) { index in
                HStack(spacing: DesignTokens.Spacing.md) {
                    // Left column item
                    if index < items.count {
                        detailRow(for: items[index])
                    }

                    Spacer()

                    // Right column item
                    if index + halfCount < items.count {
                        detailRow(for: items[index + halfCount])
                    }
                }
            }
        }
    }

    private func detailRow(for item: DetailItem) -> some View {
        HStack(spacing: 4) {
            if let icon = item.icon {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(item.label)
                .font(PopoverConstants.detailLabelFont)
                .foregroundColor(.secondary)

            Text(item.value)
                .font(PopoverConstants.detailValueFont)
                .fontWeight(.medium)
                .foregroundColor(item.valueColor)
        }
    }
}

// MARK: - Activity Monitor Button

/// A standardized button to open Activity Monitor
/// Used in CPU, Memory, and Disk widgets
struct ActivityMonitorButton: View {

    var body: some View {
        Button {
            NSWorkspace.shared.launchApplication("Activity Monitor")
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 14))

                Text("Open Activity Monitor")
                    .font(.subheadline)

                Spacer()

                Image(systemName: "arrow.up.forward.square")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(PopoverConstants.innerCornerRadius)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Metric Display

/// A large metric display with optional subtitle
/// Used for primary metrics in dashboards
struct MetricDisplay: View {

    let value: String
    let subtitle: String
    var color: Color = DesignTokens.Colors.accent
    var icon: String?

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(color)
                }

                Text(value)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Circular Progress

/// A circular progress indicator for percentage display
struct CircularProgress: View {

    let percentage: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let color: Color

    init(percentage: Double, size: CGFloat = 80, lineWidth: CGFloat = 10, color: Color) {
        self.percentage = percentage
        self.size = size
        self.lineWidth = lineWidth
        self.color = color
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(nsColor: .controlBackgroundColor), lineWidth: lineWidth)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: percentage / 100)
                .stroke(
                    color.gradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: percentage)
        }
    }
}

// MARK: - Usage Bar

/// A horizontal usage bar for percentage display
struct UsageBar: View {

    let percentage: Double
    let color: Color
    var height: CGFloat = 8

    init(percentage: Double, color: Color, height: CGFloat = 8) {
        self.percentage = percentage
        self.color = color
        self.height = height
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(height: height)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: max(0, geometry.size.width * (percentage / 100)), height: height)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Previews

#if DEBUG
struct PopoverTemplate_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Basic template
            PopoverTemplate(
                icon: "cpu.fill",
                title: "CPU Usage",
                headerValue: "45%",
                headerColor: .blue
            ) {
                VStack(spacing: 12) {
                    MetricDisplay(
                        value: "45%",
                        subtitle: "of 8 cores",
                        color: .blue,
                        icon: "cpu.fill"
                    )

                    TitledPopoverSection(title: "Per-Core Usage") {
                        VStack(spacing: 8) {
                            ForEach(0..<4) { i in
                                PopoverDetailRow(
                                    label: "Core \(i + 1)",
                                    value: "\(30 + i * 10)%"
                                )
                            }
                        }
                    }
                }
            }
            .previewDisplayName("Popover Template")

            // Detail grid
            PopoverDetailGrid(items: [
                .init(label: "Used", value: "8.2 GB", icon: "memorychip", valueColor: .blue),
                .init(label: "Wired", value: "2.1 GB"),
                .init(label: "Active", value: "4.8 GB"),
                .init(label: "Compressed", value: "1.3 GB", valueColor: .purple),
                .init(label: "Free", value: "7.8 GB", valueColor: .gray),
                .init(label: "Total", value: "16 GB"),
            ])
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            .previewDisplayName("Detail Grid")
        }
    }
}
#endif
