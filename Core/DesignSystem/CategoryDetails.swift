import SwiftUI

/// Everything the app shows or says for a category, in one place.
/// This is the only `switch` over `Category`: adding a case without an entry doesn't compile.
/// (Category voice-file names live in `content.json`, read as `CategoryInfo`.)
struct CategoryDetails: Sendable {
    /// Shown on Home tiles and the picker header (grown-ups and VoiceOver; kids use the picture).
    let title: LocalizedStringResource
    /// Spoken by the system voice in debug builds when the recording is missing.
    let spokenName: LocalizedText
    /// The drawing on the Home tile, colored with its suggested colors.
    let coverItemId: String
    /// Shown on the Home tile if the cover drawing can't be loaded.
    let symbol: String
    let tileFill: Color
    let tileShadow: Color
    /// Picker screen background.
    let screenBackground: Color
    /// The 8 swatches offered while coloring a picture from this category.
    let palette: [PaletteColor]
    /// Big word on the celebration screen ("Yummy!" only fits food).
    var cheer: LocalizedStringResource = "Yummy!"
    /// Extra sound with the cheer when a picture is finished (nil: the cheer alone).
    var finishSound: SoundEffect? = nil

    static func of(_ category: Category) -> CategoryDetails {
        typealias P = KidPalette
        switch category {
        case .fruits:
            return CategoryDetails(
                title: "Fruits", spokenName: LocalizedText(en: "Fruits", ar: "فواكه"),
                coverItemId: "apple", symbol: "🍎",
                tileFill: DSColor.tileFruits, tileShadow: DSColor.tileFruitsShadow,
                screenBackground: DSColor.bgFruits, palette: P.colors)
        case .vegetables:
            return CategoryDetails(
                title: "Veggies", spokenName: LocalizedText(en: "Veggies", ar: "خضروات"),
                coverItemId: "carrot", symbol: "🥕",
                tileFill: DSColor.tileVeggies, tileShadow: DSColor.tileVeggiesShadow,
                screenBackground: DSColor.bgHome, palette: P.colors)
        case .vehicles:
            return CategoryDetails(
                title: "Vehicles", spokenName: LocalizedText(en: "Vehicles", ar: "مركبات"),
                coverItemId: "car", symbol: "🚗",
                tileFill: DSColor.tileVehicles, tileShadow: DSColor.tileVehiclesShadow,
                screenBackground: DSColor.bgVehicles,
                palette: [P.red, P.orange, P.yellow, P.green, P.blue, P.sky, P.gray, P.brown],
                cheer: "Vroom!", finishSound: .vroom)
        case .rescuePups:
            return CategoryDetails(
                title: "Rescue Pups", spokenName: LocalizedText(en: "Rescue Pups", ar: "جراء الإنقاذ"),
                coverItemId: "fire_pup", symbol: "🐶",
                tileFill: DSColor.tilePups, tileShadow: DSColor.tilePupsShadow,
                screenBackground: DSColor.bgPups,
                palette: [P.red, P.orange, P.yellow, P.green, P.blue, P.purple, P.gray, P.brown],
                cheer: "Woof woof!", finishSound: .woof)
        case .superKids:
            return CategoryDetails(
                title: "Super Kids", spokenName: LocalizedText(en: "Super Kids", ar: "الأبطال الصغار"),
                coverItemId: "little_star", symbol: "⭐️",
                tileFill: DSColor.tileSuper, tileShadow: DSColor.tileSuperShadow,
                screenBackground: DSColor.bgSuper,
                // Brown is needed for skin tones, so the heroes use the original 8.
                palette: P.colors,
                cheer: "Super!", finishSound: .whoosh)
        }
    }
}

extension Category {
    var details: CategoryDetails { CategoryDetails.of(self) }
}
