import SwiftUI

struct AtelierSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search"

    var body: some View {
        HStack(spacing: AtelierLayout.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AtelierTokens.Color.graphite)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(AtelierTypography.caption)
                .foregroundStyle(AtelierTokens.Color.porcelain)
        }
        .padding(.horizontal, AtelierLayout.sm)
        .padding(.vertical, AtelierLayout.xs)
        .background(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: AtelierLayout.radiusSm).stroke(Color.white.opacity(0.20), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AtelierLayout.radiusSm))
    }
}

struct AtelierSegmented<Option: Hashable & CaseIterable & RawRepresentable>: View where Option.RawValue == String {
    @Binding var selected: Option

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(Option.allCases), id: \.self) { option in
                Button {
                    withAnimation(AtelierMotion.springTap) {
                        selected = option
                    }
                } label: {
                    Text(option.rawValue)
                        .font(AtelierTypography.micro)
                        .foregroundStyle(selected == option ? AtelierTokens.Color.porcelain : AtelierTokens.Color.pearl.opacity(0.76))
                        .padding(.horizontal, AtelierLayout.xs)
                        .padding(.vertical, 6)
                        .background(selected == option ? Color.white.opacity(0.16) : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.07))
        .clipShape(Capsule())
    }
}
