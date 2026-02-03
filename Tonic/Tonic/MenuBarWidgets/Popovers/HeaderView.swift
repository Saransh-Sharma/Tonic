//
//  HeaderView.swift
//  Tonic
//
//  Reusable header component for widget popovers matching Stats Master's header design
//  Task ID: fn-6-i4g.45
//

import SwiftUI

// MARK: - Header View

/// Reusable header component for widget popovers
///
/// Features:
/// - Widget icon on left
/// - Widget title
/// - Activity Monitor toggle button (becomes "Close" when active)
/// - Settings button (gear icon)
/// - Separator line below
public struct HeaderView: View {

    // MARK: - Properties

    /// Widget title (e.g., "CPU", "Memory")
    let title: String

    /// SF Symbol icon name for the widget
    let icon: String

    /// Binding for Activity Monitor mode state
    @Binding var isActivityMonitorMode: Bool

    /// Optional callback when settings button is tapped
    var onSettingsTap: (() -> Void)?

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header content row
            HStack(spacing: 12) {
                // Widget icon
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignTokens.Colors.accent)
                    .frame(width: 24)

                // Widget title
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Spacer()

                // Activity Monitor / Close button
                Button(action: {
                    isActivityMonitorMode.toggle()
                }) {
                    Text(isActivityMonitorMode ? "Close" : "Activity Monitor")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isActivityMonitorMode ? DesignTokens.Colors.destructive : DesignTokens.Colors.accent)
                }
                .buttonStyle(.plain)
                .help(isActivityMonitorMode ? "Close (drag to keep open)" : "Keep window open when dragging")

                // Settings button
                Button(action: {
                    onSettingsTap?()
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Widget settings")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(DesignTokens.Colors.backgroundSecondary)

            // Separator line
            Rectangle()
                .fill(DesignTokens.Colors.separator)
                .frame(height: 1)
        }
    }
}

// MARK: - Convenience Initializers

extension HeaderView {

    /// Creates a header without Activity Monitor mode or settings callback
    /// - Parameters:
    ///   - title: Widget title
    ///   - icon: SF Symbol icon name
    ///   - showActivityMonitor: Whether to show Activity Monitor button (defaults to false)
    public init(
        title: String,
        icon: String,
        showActivityMonitor: Bool = false
    ) {
        self.title = title
        self.icon = icon
        self._isActivityMonitorMode = .constant(false)
        self.onSettingsTap = nil
    }

    /// Creates a header with Activity Monitor binding but no settings callback
    /// - Parameters:
    ///   - title: Widget title
    ///   - icon: SF Symbol icon name
    ///   - isActivityMonitorMode: Binding for Activity Monitor mode state
    public init(
        title: String,
        icon: String,
        isActivityMonitorMode: Binding<Bool>
    ) {
        self.title = title
        self.icon = icon
        self._isActivityMonitorMode = isActivityMonitorMode
        self.onSettingsTap = nil
    }

    /// Creates a header with Activity Monitor binding and settings callback
    /// - Parameters:
    ///   - title: Widget title
    ///   - icon: SF Symbol icon name
    ///   - isActivityMonitorMode: Binding for Activity Monitor mode state
    ///   - onSettingsTap: Callback when settings button is tapped
    public init(
        title: String,
        icon: String,
        isActivityMonitorMode: Binding<Bool>,
        onSettingsTap: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self._isActivityMonitorMode = isActivityMonitorMode
        self.onSettingsTap = onSettingsTap
    }
}

// MARK: - Preview

#Preview("Header with Activity Monitor") {
    @Previewable @State var isActivityMonitorMode = false

    VStack {
        HeaderView(
            title: "CPU",
            icon: "cpu.fill",
            isActivityMonitorMode: $isActivityMonitorMode,
            onSettingsTap: {
                print("Settings tapped")
            }
        )

        Text("Content Area")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.Colors.background)
    }
    .frame(width: 280, height: 200)
}

#Preview("Header without Activity Monitor") {
    VStack {
        HeaderView(
            title: "Memory",
            icon: "memorychip.fill"
        )

        Text("Content Area")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.Colors.background)
    }
    .frame(width: 280, height: 200)
}

#Preview("Header - Activity Monitor Active") {
    @Previewable @State var isActivityMonitorMode = true

    VStack {
        HeaderView(
            title: "GPU",
            icon: "video.bubble.left.fill",
            isActivityMonitorMode: $isActivityMonitorMode
        )

        Text("Content Area")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.Colors.background)
    }
    .frame(width: 280, height: 200)
}
