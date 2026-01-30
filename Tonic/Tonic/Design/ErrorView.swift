//
//  ErrorView.swift
//  Tonic
//
//  Reusable error display component for all views
//

import SwiftUI

// MARK: - Error Display View

/// A reusable error view that displays error messages and recovery actions
struct ErrorView: View {
    let error: TonicError
    let action: (() -> Void)?
    let dismissAction: (() -> Void)?

    init(error: TonicError, action: (() -> Void)? = nil, dismiss: (() -> Void)? = nil) {
        self.error = error
        self.action = action
        self.dismissAction = dismiss
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Error icon and message
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: iconName)
                    .font(.system(size: 24))
                    .foregroundColor(error.severity.color)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text("Error")
                        .font(DesignTokens.Typography.bodyEmphasized)
                        .foregroundColor(DesignTokens.Colors.textPrimary)

                    Text(error.errorDescription ?? "An error occurred")
                        .font(DesignTokens.Typography.subhead)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .lineLimit(3)
                }

                Spacer()
            }

            // Recovery suggestion
            if let suggestion = error.recoverySuggestion {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("What to try:")
                        .font(DesignTokens.Typography.captionEmphasized)
                        .foregroundColor(DesignTokens.Colors.textSecondary)

                    Text(suggestion)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
                .padding(DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.backgroundSecondary)
                .cornerRadius(DesignTokens.CornerRadius.medium)
            }

            // Action buttons
            HStack(spacing: DesignTokens.Spacing.sm) {
                if let action = action {
                    Button(action: action) {
                        Label("Try Again", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(error.severity.color)
                }

                if let dismissAction = dismissAction {
                    Button(action: dismissAction) {
                        Label("Dismiss", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Error code for support
            HStack {
                Text("Error ID: \(error.errorCode)")
                    .font(DesignTokens.Typography.monoCaption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)

                Spacer()

                Button(action: copyErrorCode) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Copy error code")
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large)
                .stroke(error.severity.borderColor, lineWidth: 1)
        )
    }

    private var iconName: String {
        switch error.severity {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.circle"
        case .critical:
            return "exclamationmark.circle.fill"
        }
    }

    private func copyErrorCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(error.errorCode, forType: .string)
    }
}

// MARK: - Error Severity Colors

extension ErrorSeverity {
    var color: Color {
        switch self {
        case .info:
            return DesignTokens.Colors.info
        case .warning:
            return DesignTokens.Colors.warning
        case .error:
            return DesignTokens.Colors.error
        case .critical:
            return DesignTokens.Colors.destructive
        }
    }

    var borderColor: Color {
        color.opacity(0.5)
    }
}

// MARK: - Error State View Wrapper

/// Wrapper for views that can display errors
struct ErrorStateView<Content: View>: View {
    @State private var error: TonicError?
    let content: Content
    let onRetry: (() -> Void)?

    init(
        content: Content,
        error: TonicError? = nil,
        onRetry: (() -> Void)? = nil
    ) {
        self.content = content
        self._error = State(initialValue: error)
        self.onRetry = onRetry
    }

    var body: some View {
        if let error = error {
            VStack(spacing: DesignTokens.Spacing.lg) {
                ErrorView(
                    error: error,
                    action: onRetry,
                    dismiss: { self.error = nil }
                )

                Spacer()
            }
            .padding(DesignTokens.Spacing.lg)
        } else {
            content
        }
    }

    func setError(_ error: TonicError?) {
        self.error = error
    }
}

// MARK: - Error Sheet

/// Error display in a modal sheet
struct ErrorSheet: View {
    let error: TonicError
    @Environment(\.dismiss) var dismiss
    let onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            HStack {
                Text("Error")
                    .font(DesignTokens.Typography.h2)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                .buttonStyle(.borderless)
            }

            ErrorView(
                error: error,
                action: onRetry,
                dismiss: { dismiss() }
            )

            Spacer()
        }
        .padding(DesignTokens.Spacing.lg)
    }
}

// MARK: - Inline Error Messages

/// Inline error message for forms
struct InlineErrorMessage: View {
    let message: String
    let isVisible: Bool

    var body: some View {
        if isVisible {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.error)

                Text(message)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.error)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }
}

// MARK: - Loading with Error Fallback

/// Shows loading state or error
struct LoadingOrError<Content: View>: View {
    @State var isLoading: Bool
    @State var error: TonicError?
    let content: Content
    let onRetry: (() -> Void)?

    var body: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = error {
            ErrorView(
                error: error,
                action: onRetry,
                dismiss: { self.error = nil }
            )
        } else {
            content
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ErrorView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Info error
            ErrorView(
                error: TonicError.featureNotAvailable(feature: "Dark Mode"),
                action: { print("Retry") },
                dismiss: { }
            )

            // Warning error
            ErrorView(
                error: TonicError.insufficientDiskSpace(required: 1_000_000_000, available: 500_000_000),
                action: { print("Retry") },
                dismiss: { }
            )

            // Critical error
            ErrorView(
                error: TonicError.authorizationFailed,
                action: { print("Retry") },
                dismiss: { }
            )
        }
        .padding(DesignTokens.Spacing.lg)
        .background(DesignTokens.Colors.background)
    }
}
#endif
