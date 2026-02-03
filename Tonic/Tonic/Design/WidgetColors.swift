//
//  WidgetColors.swift
//  Tonic
//
//  Enhanced color system for menu bar widgets
//  Provides 30+ fixed color options matching Stats Master PRD specifications
//
//  Task ID: fn-6-i4g.19
//

import SwiftUI
import AppKit

// MARK: - Widget Color Palette

/// Complete color palette for widgets with 30+ options
/// Organized by category: automatic, system, primary, secondary, grays, special
public enum WidgetColorPalette {

    // MARK: - Automatic Colors (Calculated)

    /// Returns color based on utilization percentage (0-100)
    /// Green (0-50%) -> Yellow (50-75%) -> Orange (75-90%) -> Red (90-100%)
    public static func utilizationColor(for value: Double) -> Color {
        switch value {
        case 0..<50:
            return Color(nsColor: .systemGreen)
        case 50..<75:
            return Color(nsColor: .systemYellow)
        case 75..<90:
            return Color(nsColor: .systemOrange)
        default:
            return Color(nsColor: .systemRed)
        }
    }

    /// Returns NSColor based on utilization percentage (0-100)
    public static func utilizationNSColor(for value: Double) -> NSColor {
        switch value {
        case 0..<50:
            return .systemGreen
        case 50..<75:
            return .systemYellow
        case 75..<90:
            return .systemOrange
        default:
            return .systemRed
        }
    }

    /// Returns color based on memory pressure level
    public static func pressureColor(for pressure: MemoryPressureLevel) -> Color {
        switch pressure {
        case .nominal:
            return Color(nsColor: .systemGreen)
        case .warning:
            return Color(nsColor: .systemYellow)
        case .critical:
            return Color(nsColor: .systemRed)
        }
    }

    /// Cluster colors for CPU E-cores and P-cores
    public enum ClusterColor {
        /// Teal color for efficiency cores
        public static let eCores = Color(nsColor: .systemTeal)
        /// Indigo color for performance cores
        public static let pCores = Color(nsColor: .systemIndigo)

        public static let eCoresNS: NSColor = .systemTeal
        public static let pCoresNS: NSColor = .systemIndigo
    }

    // MARK: - System Colors

    /// System accent color (follows macOS accent color settings)
    public static let systemAccent = Color(nsColor: .controlAccentColor)

    /// Monochrome color that adapts to light/dark mode
    public static let monochrome = Color(nsColor: .textColor)

    // MARK: - Primary Colors

    public static let red = Color(nsColor: .red)
    public static let green = Color(nsColor: .green)
    public static let blue = Color(nsColor: .blue)
    public static let yellow = Color(nsColor: .yellow)
    public static let orange = Color(nsColor: .orange)
    public static let purple = Color(nsColor: .purple)
    public static let brown = Color(nsColor: .brown)
    public static let cyan = Color(nsColor: .cyan)
    public static let magenta = Color(nsColor: .magenta)
    public static let pink = Color(nsColor: .systemPink)
    public static let teal = Color(nsColor: .systemTeal)
    public static let indigo = Color(nsColor: .systemIndigo)

    // MARK: - Secondary Colors (System variants)

    public static let secondRed = Color(nsColor: .systemRed)
    public static let secondGreen = Color(nsColor: .systemGreen)
    public static let secondBlue = Color(nsColor: .systemBlue)
    public static let secondYellow = Color(nsColor: .systemYellow)
    public static let secondOrange = Color(nsColor: .systemOrange)
    public static let secondPurple = Color(nsColor: .systemPurple)
    public static let secondBrown = Color(nsColor: .systemBrown)

    // MARK: - Gray Colors

    public static let gray = Color(nsColor: .gray)
    public static let secondGray = Color(nsColor: .systemGray)
    public static let darkGray = Color(nsColor: .darkGray)
    public static let lightGray = Color(nsColor: .lightGray)

    // MARK: - Special Colors

    public static let white = Color.white
    public static let black = Color.black
    public static let clear = Color.clear
}

// MARK: - Memory Pressure Level

/// Memory pressure level for pressure-based coloring
public enum MemoryPressureLevel: String, Codable, Sendable {
    case nominal
    case warning
    case critical

    public var color: Color {
        WidgetColorPalette.pressureColor(for: self)
    }
}

// MARK: - NSColor Extensions

public extension NSColor {
    /// Returns grayscaled version of the color for monochrome mode
    func grayscaled() -> NSColor {
        guard let space = CGColorSpace(name: CGColorSpace.extendedGray),
              let cg = self.cgColor.converted(to: space, intent: .perceptual, options: nil),
              let color = NSColor(cgColor: cg) else {
            return self
        }
        return color
    }

    /// Returns color based on utilization value (0.0-1.0)
    static func utilizationColor(_ value: Double, zones: (orange: Double, red: Double) = (0.6, 0.8), reversed: Bool = false) -> NSColor {
        let firstColor: NSColor = .systemBlue
        let secondColor: NSColor = .systemOrange
        let thirdColor: NSColor = .systemRed

        if reversed {
            switch value {
            case 0...zones.orange:
                return thirdColor
            case zones.orange...zones.red:
                return secondColor
            default:
                return firstColor
            }
        } else {
            switch value {
            case 0...zones.orange:
                return firstColor
            case zones.orange...zones.red:
                return secondColor
            default:
                return thirdColor
            }
        }
    }
}
