import SwiftUI
import UIKit

/// Typography tokens for kid-facing screens (Fredoka).
/// The parent area uses the system font with Dynamic Type instead.
enum DSFont {
    case display   // 52 bold — celebration
    case title     // 36 bold — screen titles, category tiles
    case heading   // 26 semibold — buttons, My Art
    case label     // 20 semibold — picker tile names
    case body      // 24 medium — celebration message

    var size: CGFloat {
        switch self {
        case .display: 52
        case .title: 36
        case .heading: 26
        case .label: 20
        case .body: 24
        }
    }

    var weight: Font.Weight {
        switch self {
        case .display, .title: .bold
        case .heading, .label: .semibold
        case .body: .medium
        }
    }

    /// PostScript name of the bundled static Fredoka face for this weight.
    var fredokaName: String {
        switch self {
        case .display, .title: "Fredoka-Bold"
        case .heading, .label: "Fredoka-SemiBold"
        case .body: "Fredoka-Medium"
        }
    }

    /// True once the Fredoka TTFs are bundled (Resources/Fonts) and registered via `UIAppFonts`.
    /// Until then we fall back to the rounded system font, which is visually close.
    static let isFredokaAvailable: Bool = UIFont(name: "Fredoka-Bold", size: 12) != nil
}

extension Font {
    static func kid(_ style: DSFont) -> Font {
        if DSFont.isFredokaAvailable {
            return .custom(style.fredokaName, fixedSize: style.size)
        }
        return .system(size: style.size, weight: style.weight, design: .rounded)
    }
}

/// Spacing, radii and size tokens.
enum DSMetrics {
    /// Minimum kid-facing touch target (CLAUDE.md §2.3: 60–80pt).
    static let minTouch: CGFloat = 60
    static let screenPadding: CGFloat = 16
    static let spacing: CGFloat = 16
    static let smallSpacing: CGFloat = 10

    static let tileRadius: CGFloat = 34
    static let tileShadow: CGFloat = 6
    static let cardRadius: CGFloat = 32
    static let pickerTileRadius: CGFloat = 28
    static let toolRadius: CGFloat = 16
    static let primaryRadius: CGFloat = 24
    static let buttonShadow: CGFloat = 3

    static let roundIconSize: CGFloat = 60
    static let toolSize: CGFloat = 60
    static let swatchSize: CGFloat = 60
    static let swatchSelectedSize: CGFloat = 68
    static let primaryButtonHeight: CGFloat = 66
}
