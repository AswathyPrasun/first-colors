import SwiftUI

/// Presentation details for category tiles.
extension Category {
    var title: LocalizedStringKey {
        switch self {
        case .fruits: "Fruits"
        case .vegetables: "Veggies"
        }
    }

    /// Fallback if the apple / carrot drawing can't be loaded (Home normally shows the real drawing).
    var symbol: String {
        switch self {
        case .fruits: "🍎"
        case .vegetables: "🥕"
        }
    }

    var tileFill: Color {
        switch self {
        case .fruits: DSColor.tileFruits
        case .vegetables: DSColor.tileVeggies
        }
    }

    var tileShadow: Color {
        switch self {
        case .fruits: DSColor.tileFruitsShadow
        case .vegetables: DSColor.tileVeggiesShadow
        }
    }

    var screenBackground: Color {
        switch self {
        case .fruits: DSColor.bgFruits
        case .vegetables: DSColor.bgHome
        }
    }

    var titleResource: LocalizedStringResource {
        switch self {
        case .fruits: "Fruits"
        case .vegetables: "Veggies"
        }
    }
}
