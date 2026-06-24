import SwiftUI

struct AtelierCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    @ViewBuilder let content: () -> Content

    init(title: String? = nil, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AtelierLayout.sm) {
            if let title {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AtelierTypography.title)
                        .foregroundStyle(AtelierTokens.Color.porcelain)
                    if let subtitle {
                        Text(subtitle)
                            .font(AtelierTypography.caption)
                            .foregroundStyle(AtelierTokens.Color.pearl.opacity(0.78))
                    }
                }
            }

            content()
        }
        .padding(AtelierLayout.md)
        .atelierSurface(radius: AtelierLayout.radiusLg)
    }
}
