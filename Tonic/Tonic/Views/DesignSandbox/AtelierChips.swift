import SwiftUI

struct AtelierChip: View {
    let title: String
    var icon: String? = nil
    var tint: Color = AtelierTokens.Color.champagne

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(title)
                .font(AtelierTypography.micro)
                .tracking(0.8)
        }
        .foregroundStyle(AtelierTokens.Color.pearl)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.22))
        .overlay(Capsule().stroke(tint.opacity(0.68), lineWidth: 1))
        .clipShape(Capsule())
    }
}
