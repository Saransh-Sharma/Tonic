import SwiftUI

/// Compatibility namespace for legacy preference-list tests that predate `TonicDS`.
enum DesignTokens {
    enum Spacing {
        static let sm: CGFloat = 16
        static let md: CGFloat = 24
        static let sectionGap: CGFloat = 24
        static let listPadding: CGFloat = 12
    }

    enum Layout {
        static let minRowHeight: CGFloat = 44
    }

    enum Typography {
        static let body = Font.body
        static let caption = Font.caption
    }

    enum Colors {
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
    }
}
