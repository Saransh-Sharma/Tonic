import SwiftUI

enum AtelierControlState {
    case normal
    case hover
    case pressed
    case disabled
}

struct AtelierControlStyleToken {
    let scale: CGFloat
    let brightness: Double
    let opacity: Double
}

enum AtelierStateStyles {
    static func button(for state: AtelierControlState) -> AtelierControlStyleToken {
        switch state {
        case .normal:
            return .init(scale: 1, brightness: 0, opacity: 1)
        case .hover:
            return .init(scale: 1.01, brightness: 0.04, opacity: 1)
        case .pressed:
            return .init(scale: 0.98, brightness: -0.04, opacity: 1)
        case .disabled:
            return .init(scale: 1, brightness: 0, opacity: 0.55)
        }
    }
}
