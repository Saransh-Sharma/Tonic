import SwiftUI

struct AtelierPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AtelierLayout.xs) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(AtelierTypography.bodyStrong)
            }
            .foregroundStyle(AtelierTokens.Color.porcelain)
            .padding(.horizontal, AtelierLayout.md)
            .padding(.vertical, AtelierLayout.xs)
            .background(
                LinearGradient(
                    colors: [AtelierTokens.Color.gold.opacity(0.40), AtelierTokens.Color.champagne.opacity(0.24)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(Capsule().stroke(AtelierTokens.Color.champagne.opacity(0.75), lineWidth: 1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
        .atelierHoverLift()
    }
}

struct AtelierSecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AtelierLayout.xs) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(AtelierTypography.caption)
            }
            .foregroundStyle(AtelierTokens.Color.pearl)
            .padding(.horizontal, AtelierLayout.sm)
            .padding(.vertical, AtelierLayout.xs)
            .background(Color.white.opacity(0.08))
            .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .atelierHoverLift()
    }
}

struct AtelierIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AtelierTokens.Color.pearl)
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: AtelierLayout.radiusSm).stroke(Color.white.opacity(0.24), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: AtelierLayout.radiusSm))
        }
        .buttonStyle(.plain)
        .atelierHoverLift()
    }
}
