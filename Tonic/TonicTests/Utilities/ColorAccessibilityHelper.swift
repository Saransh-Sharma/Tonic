//
//  ColorAccessibilityHelper.swift
//  TonicTests
//
//  Helper for testing WCAG color contrast compliance
//

import Foundation
import SwiftUI

/// Helper for calculating and verifying color contrast ratios (WCAG 2.0)
struct ColorAccessibilityHelper {
    /// Calculate relative luminance of a color per WCAG 2.0
    /// - Parameter color: NSColor to calculate luminance for
    /// - Returns: Luminance value between 0 and 1
    static func relativeLuminance(of color: NSColor) -> Double {
        let red = linearize(color.redComponent)
        let green = linearize(color.greenComponent)
        let blue = linearize(color.blueComponent)
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    /// Calculate contrast ratio between two colors per WCAG 2.0
    /// - Parameters:
    ///   - foreground: Foreground color
    ///   - background: Background color
    /// - Returns: Contrast ratio (typically 1 to 21)
    static func contrastRatio(foreground: NSColor, background: NSColor) -> Double {
        let l1 = relativeLuminance(of: foreground)
        let l2 = relativeLuminance(of: background)
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Check if contrast ratio meets WCAG AA standard (4.5:1 for normal text)
    static func meetsWCAG_AA_Text(foreground: NSColor, background: NSColor) -> Bool {
        return contrastRatio(foreground: foreground, background: background) >= 4.5
    }

    /// Check if contrast ratio meets WCAG AA standard (3:1 for large text/UI)
    static func meetsWCAG_AA_LargeText(foreground: NSColor, background: NSColor) -> Bool {
        return contrastRatio(foreground: foreground, background: background) >= 3.0
    }

    /// Check if contrast ratio meets WCAG AAA standard (7:1 for normal text)
    static func meetsWCAG_AAA_Text(foreground: NSColor, background: NSColor) -> Bool {
        return contrastRatio(foreground: foreground, background: background) >= 7.0
    }

    /// Check if contrast ratio meets WCAG AAA standard (4.5:1 for large text/UI)
    static func meetsWCAG_AAA_LargeText(foreground: NSColor, background: NSColor) -> Bool {
        return contrastRatio(foreground: foreground, background: background) >= 4.5
    }

    // MARK: - Private Helpers

    /// Linearize RGB component per WCAG 2.0
    private static func linearize(_ component: CGFloat) -> Double {
        let c = Double(component)
        if c <= 0.03928 {
            return c / 12.92
        } else {
            return pow((c + 0.055) / 1.055, 2.4)
        }
    }
}

/// Test assertion helpers for color accessibility
extension ColorAccessibilityHelper {
    /// Assert foreground color passes WCAG AA contrast with background
    static func assertWCAG_AA(
        foreground: NSColor,
        background: NSColor,
        context: String = ""
    ) -> (passes: Bool, ratio: Double) {
        let ratio = contrastRatio(foreground: foreground, background: background)
        let passes = ratio >= 4.5
        return (passes, ratio)
    }

    /// Assert foreground color passes WCAG AAA contrast with background
    static func assertWCAG_AAA(
        foreground: NSColor,
        background: NSColor,
        context: String = ""
    ) -> (passes: Bool, ratio: Double) {
        let ratio = contrastRatio(foreground: foreground, background: background)
        let passes = ratio >= 7.0
        return (passes, ratio)
    }
}
