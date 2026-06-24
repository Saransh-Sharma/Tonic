import SwiftUI

struct AtelierMetricTile: View {
    let title: String
    let value: String
    let delta: String
    var accent: Color = AtelierTokens.Color.champagne

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AtelierTypography.micro)
                .foregroundStyle(AtelierTokens.Color.pearl.opacity(0.72))

            Text(value)
                .font(AtelierTypography.bodyStrong)
                .foregroundStyle(AtelierTokens.Color.porcelain)

            Text(delta)
                .font(AtelierTypography.caption)
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AtelierLayout.sm)
        .background(Color.white.opacity(0.07))
        .overlay(RoundedRectangle(cornerRadius: AtelierLayout.radiusSm).stroke(accent.opacity(0.45), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AtelierLayout.radiusSm))
    }
}

struct AtelierRingMetric: View {
    let title: String
    let value: CGFloat
    var tint: Color = AtelierTokens.Color.champagne

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: min(max(value, 0), 1))
                    .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(min(max(value, 0), 1) * 100))")
                    .font(AtelierTypography.mono)
                    .foregroundStyle(AtelierTokens.Color.porcelain)
            }
            .frame(width: 62, height: 62)

            Text(title)
                .font(AtelierTypography.caption)
                .foregroundStyle(AtelierTokens.Color.pearl)
        }
    }
}
