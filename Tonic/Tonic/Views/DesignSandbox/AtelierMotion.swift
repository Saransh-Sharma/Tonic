import SwiftUI

enum AtelierMotion {
    static let micro = Animation.easeInOut(duration: 0.12)
    static let standard = Animation.easeInOut(duration: 0.24)
    static let luxurious = Animation.easeInOut(duration: 0.42)

    static let springTap = Animation.spring(response: 0.24, dampingFraction: 0.82)
    static let springPanel = Animation.spring(response: 0.48, dampingFraction: 0.84)
    static let springHero = Animation.spring(response: 0.62, dampingFraction: 0.86)

    static let ambientDuration: Double = 12.0
    static let shimmerDuration: Double = 2.8
    static let staggerStep: Double = 0.07
}
