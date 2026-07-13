//
//  MenuBarStyleOverlayView.swift
//  Tonic
//
//  Renders the menu bar tint/gradient overlay. Click-through by virtue of the
//  hosting window's `ignoresMouseEvents`.
//

import AppKit
import SwiftUI

struct MenuBarStyleOverlayView: View {
    let styling: MenuBarStyling

    private var tint: Color {
        if let hex = styling.tintHex, let color = Color(menuBarHex: hex) {
            return color
        }
        return TonicDS.Colors.darkNavy
    }

    private var gradientEnd: Color {
        styling.gradientEndHex.flatMap { Color(menuBarHex: $0) } ?? tint.opacity(0.55)
    }

    var body: some View {
        Group {
            if styling.usesGradient {
                LinearGradient(
                    colors: [tint.opacity(styling.opacity), gradientEnd.opacity(styling.opacity)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                tint.opacity(styling.opacity)
            }
        }
        .clipShape(
            RoundedRectangle(cornerRadius: styling.cornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: styling.cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.28), lineWidth: styling.borderWidth)
        }
        .shadow(color: Color.black.opacity(styling.shadowStrength), radius: styling.shadowStrength * 8, y: 2)
        .padding(.horizontal, styling.isFullWidth ? 0 : 8)
        .ignoresSafeArea()
    }
}

extension Color {
    /// Parses `#RRGGBB` / `RRGGBB` for the menu bar tint picker.
    init?(menuBarHex hex: String) {
        var string = hex.trimmingCharacters(in: .whitespaces)
        if string.hasPrefix("#") { string.removeFirst() }
        guard string.count == 6, let value = UInt32(string, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// `#RRGGBB` string for persisting the picked tint.
    var menuBarHexString: String {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? .black
        return String(format: "#%02X%02X%02X",
                      Int(round(nsColor.redComponent * 255)),
                      Int(round(nsColor.greenComponent * 255)),
                      Int(round(nsColor.blueComponent * 255)))
    }
}
