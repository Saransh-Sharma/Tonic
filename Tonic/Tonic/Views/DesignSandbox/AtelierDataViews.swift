import SwiftUI

struct AtelierSparkline: View {
    let values: [Double]
    var color: Color = AtelierTokens.Color.champagne

    var body: some View {
        GeometryReader { proxy in
            let points = normalizedPoints(in: proxy.size)

            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(color.opacity(0.92), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: CGPoint(x: first.x, y: proxy.size.height))
                    points.forEach { path.addLine(to: $0) }
                    if let last = points.last {
                        path.addLine(to: CGPoint(x: last.x, y: proxy.size.height))
                    }
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [color.opacity(0.22), color.opacity(0.03)], startPoint: .top, endPoint: .bottom))
            }
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }

        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let range = max(maxValue - minValue, 0.0001)

        return values.enumerated().map { index, value in
            let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
            let normalized = (value - minValue) / range
            let y = size.height * (1 - CGFloat(normalized))
            return CGPoint(x: x, y: y)
        }
    }
}

struct AtelierTimelineItem: Identifiable {
    let id = UUID()
    let time: String
    let title: String
    let detail: String
    let tone: Color
}

struct AtelierTimelineRow: View {
    let item: AtelierTimelineItem
    @State private var hover = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(item.tone)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.title)
                        .font(AtelierTypography.caption)
                        .foregroundStyle(AtelierTokens.Color.porcelain)
                    Spacer()
                    Text(item.time)
                        .font(AtelierTypography.micro)
                        .foregroundStyle(AtelierTokens.Color.pearl.opacity(0.72))
                }

                Text(item.detail)
                    .font(AtelierTypography.micro)
                    .foregroundStyle(AtelierTokens.Color.pearl.opacity(0.72))
            }
        }
        .padding(.horizontal, AtelierLayout.sm)
        .padding(.vertical, AtelierLayout.xs)
        .background(hover ? Color.white.opacity(0.11) : Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: AtelierLayout.radiusSm).stroke(item.tone.opacity(0.42), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AtelierLayout.radiusSm))
        .onHover { hover in
            withAnimation(AtelierMotion.standard) {
                self.hover = hover
            }
        }
    }
}
