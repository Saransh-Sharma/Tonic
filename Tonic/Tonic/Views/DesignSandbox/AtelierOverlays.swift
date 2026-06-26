import SwiftUI

struct AtelierTicker: View {
    let message: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: reduceMotion ? 1.2 : 0.05)) { timeline in
                let speed: Double = reduceMotion ? 0 : 42
                let shift = CGFloat((timeline.date.timeIntervalSinceReferenceDate * speed).truncatingRemainder(dividingBy: Double(proxy.size.width + 320)))

                HStack(spacing: 42) {
                    ForEach(0 ..< 4, id: \.self) { _ in
                        Text(message)
                            .font(AtelierTypography.micro)
                            .tracking(1.8)
                            .foregroundStyle(AtelierTokens.Color.pearl.opacity(0.72))
                    }
                }
                .offset(x: -shift)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, AtelierLayout.sm)
        .background(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: AtelierLayout.radiusSm).stroke(Color.white.opacity(0.26), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AtelierLayout.radiusSm))
    }
}

struct AtelierShimmerBorder: View {
    let radius: CGFloat

    @State private var xOffset: CGFloat = -1.2

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(Color.white.opacity(0.10), lineWidth: 1)
            .overlay {
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [.clear, AtelierTokens.Color.champagne.opacity(0.75), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: max(120, proxy.size.width * 0.25))
                    .rotationEffect(.degrees(20))
                    .offset(x: proxy.size.width * xOffset)
                }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
            .onAppear {
                withAnimation(.linear(duration: AtelierMotion.shimmerDuration).repeatForever(autoreverses: false)) {
                    xOffset = 1.2
                }
            }
    }
}
