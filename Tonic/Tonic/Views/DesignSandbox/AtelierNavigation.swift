import SwiftUI

struct AtelierTabItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
}

struct AtelierTabRail: View {
    let items: [AtelierTabItem]
    @Binding var selectedID: String
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items) { item in
                Button {
                    withAnimation(AtelierMotion.springPanel) {
                        selectedID = item.id
                    }
                } label: {
                    ZStack {
                        if selectedID == item.id {
                            RoundedRectangle(cornerRadius: AtelierLayout.radiusSm, style: .continuous)
                                .fill(LinearGradient(colors: [AtelierTokens.Color.gold.opacity(0.34), AtelierTokens.Color.champagne.opacity(0.20)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay(RoundedRectangle(cornerRadius: AtelierLayout.radiusSm, style: .continuous).stroke(AtelierTokens.Color.champagne.opacity(0.7), lineWidth: 1))
                                .matchedGeometryEffect(id: "atelier-tab-selection", in: namespace)
                        }

                        HStack(spacing: 8) {
                            Image(systemName: item.systemImage)
                                .font(.system(size: 12, weight: .semibold))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title)
                                    .font(AtelierTypography.caption)
                                Text(item.subtitle)
                                    .font(AtelierTypography.micro)
                            }
                        }
                        .foregroundStyle(selectedID == item.id ? AtelierTokens.Color.porcelain : AtelierTokens.Color.pearl.opacity(0.70))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: AtelierLayout.radiusMd).stroke(Color.white.opacity(0.22), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AtelierLayout.radiusMd))
    }
}
